// LLM-as-Judge Main Orchestrator
//
// Coordinates the evaluation of generated code using LLM judges.
// Implements best practices from research:
// - Multiple evaluations with majority voting
// - Category-based scoring (readability, architecture, style)
// - Comparison mode for constrained vs unconstrained
// - Human review queue for low-confidence results

const std = @import("std");
const Allocator = std.mem.Allocator;
const rubrics = @import("rubrics.zig");
const claude_client = @import("claude_client.zig");

/// Configuration for the judge orchestrator
pub const JudgeOrchestratorConfig = struct {
    /// Claude API configuration
    claude_config: claude_client.JudgeConfig,
    /// Minimum agreement rate to consider result reliable
    min_agreement_rate: f32 = 0.67,
    /// Categories to evaluate
    categories: []const rubrics.EvaluationCategory = &[_]rubrics.EvaluationCategory{
        .readability,
        .architecture,
        .style,
    },
    /// Whether to queue low-confidence results for human review
    enable_human_review_queue: bool = true,
};

/// Result of evaluating a single piece of code
pub const CodeEvaluationResult = struct {
    /// Evaluated code (reference kept, not owned)
    code_hash: u64,
    /// Results per category
    category_results: []CategoryResult,
    /// Overall score (weighted average)
    overall_score: f32,
    /// Results that need human review (low confidence)
    needs_review: []rubrics.EvaluationCriterion,
    /// Total API cost estimate (tokens)
    total_tokens_used: u64,

    pub fn deinit(self: *CodeEvaluationResult, allocator: Allocator) void {
        for (self.category_results) |*cat| {
            cat.deinit(allocator);
        }
        allocator.free(self.category_results);
        allocator.free(self.needs_review);
    }
};

/// Results for a single evaluation category
pub const CategoryResult = struct {
    category: rubrics.EvaluationCategory,
    criterion_results: []rubrics.AggregatedJudgeResult,
    category_score: f32,

    pub fn deinit(self: *CategoryResult, allocator: Allocator) void {
        for (self.criterion_results) |*result| {
            result.deinit(allocator);
        }
        allocator.free(self.criterion_results);
    }
};

/// Comparison result between two code samples
pub const ComparisonResult = struct {
    /// Constrained code evaluation
    constrained: CodeEvaluationResult,
    /// Unconstrained (baseline) code evaluation
    unconstrained: CodeEvaluationResult,
    /// Per-criterion deltas (positive = constrained better)
    criterion_deltas: []CriterionDelta,
    /// Overall winner
    overall_winner: Winner,
    /// Category winners
    category_winners: []CategoryWinner,

    pub const Winner = enum {
        constrained,
        unconstrained,
        tie,
    };

    pub const CriterionDelta = struct {
        criterion: rubrics.EvaluationCriterion,
        delta: f32, // positive = constrained better
        is_significant: bool, // > 10 points difference
    };

    pub const CategoryWinner = struct {
        category: rubrics.EvaluationCategory,
        winner: Winner,
        delta: f32,
    };

    pub fn deinit(self: *ComparisonResult, allocator: Allocator) void {
        self.constrained.deinit(allocator);
        self.unconstrained.deinit(allocator);
        allocator.free(self.criterion_deltas);
        allocator.free(self.category_winners);
    }
};

/// Main judge orchestrator
pub const JudgeOrchestrator = struct {
    allocator: Allocator,
    config: JudgeOrchestratorConfig,
    client: claude_client.ClaudeJudgeClient,
    /// Queue of results needing human review
    review_queue: std.ArrayList(ReviewItem),

    pub const ReviewItem = struct {
        code_hash: u64,
        criterion: rubrics.EvaluationCriterion,
        result: rubrics.AggregatedJudgeResult,
    };

    pub fn init(allocator: Allocator, config: JudgeOrchestratorConfig) JudgeOrchestrator {
        return .{
            .allocator = allocator,
            .config = config,
            .client = claude_client.ClaudeJudgeClient.init(allocator, config.claude_config),
            .review_queue = std.ArrayList(ReviewItem).init(allocator),
        };
    }

    pub fn deinit(self: *JudgeOrchestrator) void {
        self.review_queue.deinit();
    }

    /// Evaluate a single piece of code
    pub fn evaluateCode(
        self: *JudgeOrchestrator,
        code: []const u8,
        context: ?claude_client.EvaluationContext,
    ) !CodeEvaluationResult {
        const code_hash = std.hash.Wyhash.hash(0, code);

        var category_results = std.ArrayList(CategoryResult).init(self.allocator);
        errdefer {
            for (category_results.items) |*cat| cat.deinit(self.allocator);
            category_results.deinit();
        }

        var needs_review = std.ArrayList(rubrics.EvaluationCriterion).init(self.allocator);
        errdefer needs_review.deinit();

        var total_tokens: u64 = 0;
        var weighted_score_sum: f32 = 0;
        var total_weight: f32 = 0;

        // Evaluate each category
        for (self.config.categories) |category| {
            const criteria = rubrics.getRubricsForCategory(category);

            var criterion_results = std.ArrayList(rubrics.AggregatedJudgeResult).init(self.allocator);
            errdefer {
                for (criterion_results.items) |*res| res.deinit(self.allocator);
                criterion_results.deinit();
            }

            var category_score_sum: f32 = 0;

            for (criteria) |criterion| {
                const result = self.client.evaluateWithConsensus(code, criterion, context) catch |err| {
                    std.log.warn("Failed to evaluate {s}: {any}", .{ criterion.toString(), err });
                    continue;
                };

                // Track low-confidence results
                if (!result.is_reliable and self.config.enable_human_review_queue) {
                    try needs_review.append(criterion);
                    try self.review_queue.append(.{
                        .code_hash = code_hash,
                        .criterion = criterion,
                        .result = result,
                    });
                }

                category_score_sum += result.final_score.toNumeric();
                // Estimate tokens (would be tracked from actual API calls)
                total_tokens += 2000; // Rough estimate per evaluation

                try criterion_results.append(result);
            }

            const category_score = if (criterion_results.items.len > 0)
                category_score_sum / @as(f32, @floatFromInt(criterion_results.items.len))
            else
                0;

            try category_results.append(.{
                .category = category,
                .criterion_results = try criterion_results.toOwnedSlice(),
                .category_score = category_score,
            });

            // Weight categories equally for now
            weighted_score_sum += category_score;
            total_weight += 1;
        }

        const overall_score = if (total_weight > 0) weighted_score_sum / total_weight else 0;

        return CodeEvaluationResult{
            .code_hash = code_hash,
            .category_results = try category_results.toOwnedSlice(),
            .overall_score = overall_score,
            .needs_review = try needs_review.toOwnedSlice(),
            .total_tokens_used = total_tokens,
        };
    }

    /// Compare constrained vs unconstrained code
    pub fn compareCode(
        self: *JudgeOrchestrator,
        constrained_code: []const u8,
        unconstrained_code: []const u8,
        context: ?claude_client.EvaluationContext,
    ) !ComparisonResult {
        // Evaluate both
        var constrained_result = try self.evaluateCode(constrained_code, context);
        errdefer constrained_result.deinit(self.allocator);

        var unconstrained_result = try self.evaluateCode(unconstrained_code, context);
        errdefer unconstrained_result.deinit(self.allocator);

        // Calculate deltas
        var criterion_deltas = std.ArrayList(ComparisonResult.CriterionDelta).init(self.allocator);
        errdefer criterion_deltas.deinit();

        var category_winners = std.ArrayList(ComparisonResult.CategoryWinner).init(self.allocator);
        errdefer category_winners.deinit();

        // Match up criterion results and calculate deltas
        for (constrained_result.category_results) |const_cat| {
            var category_delta: f32 = 0;
            var category_count: u32 = 0;

            // Find matching unconstrained category
            for (unconstrained_result.category_results) |unconst_cat| {
                if (const_cat.category == unconst_cat.category) {
                    category_delta = const_cat.category_score - unconst_cat.category_score;

                    // Match criteria within category
                    for (const_cat.criterion_results) |const_crit| {
                        for (unconst_cat.criterion_results) |unconst_crit| {
                            if (const_crit.criterion == unconst_crit.criterion) {
                                const delta = const_crit.final_score.toNumeric() - unconst_crit.final_score.toNumeric();
                                try criterion_deltas.append(.{
                                    .criterion = const_crit.criterion,
                                    .delta = delta,
                                    .is_significant = @abs(delta) > 10,
                                });
                                category_count += 1;
                            }
                        }
                    }
                    break;
                }
            }

            const cat_winner: ComparisonResult.Winner = if (category_delta > 5)
                .constrained
            else if (category_delta < -5)
                .unconstrained
            else
                .tie;

            try category_winners.append(.{
                .category = const_cat.category,
                .winner = cat_winner,
                .delta = category_delta,
            });
        }

        // Determine overall winner
        const overall_delta = constrained_result.overall_score - unconstrained_result.overall_score;
        const overall_winner: ComparisonResult.Winner = if (overall_delta > 5)
            .constrained
        else if (overall_delta < -5)
            .unconstrained
        else
            .tie;

        return ComparisonResult{
            .constrained = constrained_result,
            .unconstrained = unconstrained_result,
            .criterion_deltas = try criterion_deltas.toOwnedSlice(),
            .overall_winner = overall_winner,
            .category_winners = try category_winners.toOwnedSlice(),
        };
    }

    /// Get items pending human review
    pub fn getReviewQueue(self: *JudgeOrchestrator) []const ReviewItem {
        return self.review_queue.items;
    }

    /// Clear a review item (after human review)
    pub fn markReviewed(self: *JudgeOrchestrator, code_hash: u64, criterion: rubrics.EvaluationCriterion) void {
        var i: usize = 0;
        while (i < self.review_queue.items.len) {
            const item = self.review_queue.items[i];
            if (item.code_hash == code_hash and item.criterion == criterion) {
                _ = self.review_queue.orderedRemove(i);
            } else {
                i += 1;
            }
        }
    }
};

/// Batch evaluation results
pub const BatchJudgeResult = struct {
    /// Individual code evaluations
    code_results: []CodeEvaluationResult,
    /// Aggregate statistics
    aggregate: AggregateStats,
    /// Items needing human review
    review_queue_size: u32,

    pub const AggregateStats = struct {
        mean_overall_score: f32,
        mean_readability: f32,
        mean_architecture: f32,
        mean_style: f32,
        reliable_count: u32,
        total_count: u32,
    };

    pub fn deinit(self: *BatchJudgeResult, allocator: Allocator) void {
        for (self.code_results) |*result| {
            result.deinit(allocator);
        }
        allocator.free(self.code_results);
    }
};

// Utility function to generate JSON report
pub fn generateJudgeReport(
    allocator: Allocator,
    result: ComparisonResult,
) ![]const u8 {
    var buf = std.ArrayList(u8).init(allocator);
    errdefer buf.deinit();

    const writer = buf.writer();

    try writer.writeAll("{\n");
    try writer.print("  \"overall_winner\": \"{s}\",\n", .{@tagName(result.overall_winner)});
    try writer.print("  \"constrained_score\": {d:.1},\n", .{result.constrained.overall_score});
    try writer.print("  \"unconstrained_score\": {d:.1},\n", .{result.unconstrained.overall_score});

    try writer.writeAll("  \"category_winners\": {\n");
    for (result.category_winners, 0..) |cat, i| {
        try writer.print("    \"{s}\": {{\"winner\": \"{s}\", \"delta\": {d:.1}}}", .{
            @tagName(cat.category),
            @tagName(cat.winner),
            cat.delta,
        });
        if (i < result.category_winners.len - 1) try writer.writeAll(",");
        try writer.writeAll("\n");
    }
    try writer.writeAll("  },\n");

    try writer.writeAll("  \"criterion_deltas\": [\n");
    for (result.criterion_deltas, 0..) |crit, i| {
        try writer.print("    {{\"criterion\": \"{s}\", \"delta\": {d:.1}, \"significant\": {}}}", .{
            crit.criterion.toString(),
            crit.delta,
            crit.is_significant,
        });
        if (i < result.criterion_deltas.len - 1) try writer.writeAll(",");
        try writer.writeAll("\n");
    }
    try writer.writeAll("  ],\n");

    try writer.print("  \"needs_review_constrained\": {d},\n", .{result.constrained.needs_review.len});
    try writer.print("  \"needs_review_unconstrained\": {d}\n", .{result.unconstrained.needs_review.len});
    try writer.writeAll("}\n");

    return buf.toOwnedSlice();
}

// Tests

test "judge orchestrator initialization" {
    const allocator = std.testing.allocator;
    var orchestrator = JudgeOrchestrator.init(allocator, .{
        .claude_config = .{ .api_key = "test-key" },
    });
    defer orchestrator.deinit();

    try std.testing.expectEqual(@as(usize, 0), orchestrator.review_queue.items.len);
}

test "comparison result winner calculation" {
    // Test that winner is determined correctly based on score differences
    // This would be a more complete test with actual evaluation data

    // Score > 5 higher = winner
    const delta: f32 = 10.0;
    const winner: ComparisonResult.Winner = if (delta > 5) .constrained else if (delta < -5) .unconstrained else .tie;
    try std.testing.expectEqual(ComparisonResult.Winner.constrained, winner);

    // Tie for small differences
    const small_delta: f32 = 3.0;
    const tie_result: ComparisonResult.Winner = if (small_delta > 5) .constrained else if (small_delta < -5) .unconstrained else .tie;
    try std.testing.expectEqual(ComparisonResult.Winner.tie, tie_result);
}
