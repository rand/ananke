const std = @import("std");
const Allocator = std.mem.Allocator;
const test_runner = @import("test_runner");
const quality_scorer = @import("quality_scorer");

/// Failure mode categories for diagnostic purposes
pub const FailureMode = enum {
    /// No failure - task completed successfully
    none,

    /// Timeout truncation - generation took too long, output may be incomplete
    /// Detection: time > 50s AND output appears truncated
    timeout_truncation,

    /// Premature termination - constraint caused immediate stop
    /// Detection: time < 1s AND tokens < 50
    premature_termination,

    /// Compilation error - code doesn't compile
    /// Detection: test runner reports compilation failure
    compilation_error,

    /// Structural mismatch - code compiles but wrong structure
    /// Detection: AST doesn't match expected pattern (low pattern conformity)
    structural_mismatch,

    /// Semantic error - code compiles, structure OK, but tests fail
    /// Detection: compiles AND structure OK AND tests fail
    semantic_error,

    /// Generation failure - API error or empty response
    /// Detection: empty or null code output
    generation_failure,

    /// Constraint over-restriction - constraint too tight
    /// Detection: high constraint adherence BUT low test pass rate
    constraint_over_restriction,

    /// Weak constraint - constraint provides no guidance
    /// Detection: constraint adherence ~50% (same as baseline)
    weak_constraint,

    pub fn toString(self: FailureMode) []const u8 {
        return switch (self) {
            .none => "none",
            .timeout_truncation => "timeout_truncation",
            .premature_termination => "premature_termination",
            .compilation_error => "compilation_error",
            .structural_mismatch => "structural_mismatch",
            .semantic_error => "semantic_error",
            .generation_failure => "generation_failure",
            .constraint_over_restriction => "constraint_over_restriction",
            .weak_constraint => "weak_constraint",
        };
    }

    pub fn description(self: FailureMode) []const u8 {
        return switch (self) {
            .none => "Task completed successfully",
            .timeout_truncation => "Generation timed out, output may be incomplete",
            .premature_termination => "Constraint caused immediate termination",
            .compilation_error => "Generated code does not compile",
            .structural_mismatch => "Code structure doesn't match expected pattern",
            .semantic_error => "Code compiles but tests fail (logic error)",
            .generation_failure => "API error or empty response",
            .constraint_over_restriction => "Constraint is too restrictive",
            .weak_constraint => "Constraint provides minimal guidance",
        };
    }

    pub fn recommendation(self: FailureMode) []const u8 {
        return switch (self) {
            .none => "No action needed",
            .timeout_truncation => "Consider simplifying constraint or increasing timeout",
            .premature_termination => "Constraint regex may be too restrictive - add [\\s\\S]* suffix",
            .compilation_error => "Review generated code for syntax errors, missing imports/exports",
            .structural_mismatch => "Adjust constraint pattern to match expected code structure",
            .semantic_error => "Logic error - outside constraint scope, model limitation",
            .generation_failure => "Check API endpoint and retry",
            .constraint_over_restriction => "Loosen constraint to allow valid alternatives",
            .weak_constraint => "Strengthen constraint with more specific patterns",
        };
    }
};

/// Analysis result for a single generation attempt
pub const FailureAnalysis = struct {
    mode: FailureMode,
    confidence: f32, // 0.0-1.0 confidence in diagnosis
    details: ?[]const u8,

    pub fn toJson(self: FailureAnalysis, allocator: Allocator) ![]const u8 {
        var buf = std.ArrayList(u8).init(allocator);
        errdefer buf.deinit();
        const writer = buf.writer();

        try writer.writeAll("{");
        try writer.print("\"mode\": \"{s}\", ", .{self.mode.toString()});
        try writer.print("\"confidence\": {d:.2}, ", .{self.confidence});
        try writer.print("\"description\": \"{s}\", ", .{self.mode.description()});
        try writer.print("\"recommendation\": \"{s}\"", .{self.mode.recommendation()});
        if (self.details) |d| {
            try writer.print(", \"details\": \"{s}\"", .{d});
        }
        try writer.writeAll("}");

        return buf.toOwnedSlice();
    }
};

/// Failure analyzer for diagnostic purposes
pub const FailureAnalyzer = struct {
    allocator: Allocator,

    // Thresholds for detection
    timeout_threshold_ms: u64 = 50000, // 50 seconds
    premature_threshold_ms: u64 = 1000, // 1 second
    min_tokens_threshold: usize = 50,
    weak_constraint_threshold: f32 = 55.0, // ~50% adherence
    over_restriction_adherence_threshold: f32 = 80.0,
    over_restriction_test_threshold: f32 = 30.0,

    pub fn init(allocator: Allocator) FailureAnalyzer {
        return .{ .allocator = allocator };
    }

    /// Analyze a generation result to determine failure mode
    pub fn analyze(
        self: *FailureAnalyzer,
        code: ?[]const u8,
        generation_time_ms: u64,
        test_result: test_runner.TestResult,
        quality_score: quality_scorer.QualityScore,
    ) FailureAnalysis {
        // Check for generation failure first
        if (code == null or code.?.len == 0) {
            return .{
                .mode = .generation_failure,
                .confidence = 1.0,
                .details = "Empty or null code output",
            };
        }

        const code_len = code.?.len;

        // Check for premature termination
        if (generation_time_ms < self.premature_threshold_ms and code_len < self.min_tokens_threshold) {
            return .{
                .mode = .premature_termination,
                .confidence = 0.9,
                .details = "Very short generation time and output length",
            };
        }

        // Check for timeout truncation
        if (generation_time_ms > self.timeout_threshold_ms) {
            // Look for signs of truncation
            const appears_truncated = self.checkTruncation(code.?);
            if (appears_truncated) {
                return .{
                    .mode = .timeout_truncation,
                    .confidence = 0.85,
                    .details = "Generation exceeded timeout and output appears incomplete",
                };
            }
        }

        // Check for compilation error
        if (!test_result.success and !quality_score.correctness.compiles) {
            return .{
                .mode = .compilation_error,
                .confidence = 0.95,
                .details = "Code failed to compile",
            };
        }

        // Check for structural mismatch (compiles but wrong structure)
        if (quality_score.correctness.compiles and quality_score.pattern_conformity.score < 40.0) {
            return .{
                .mode = .structural_mismatch,
                .confidence = 0.75,
                .details = "Code structure doesn't match expected patterns",
            };
        }

        // Check for semantic error (compiles, structure OK, but tests fail)
        if (quality_score.correctness.compiles and
            quality_score.pattern_conformity.score >= 40.0 and
            test_result.total_tests > 0 and
            test_result.passed_tests < test_result.total_tests)
        {
            return .{
                .mode = .semantic_error,
                .confidence = 0.9,
                .details = "Code compiles but tests fail - logic error",
            };
        }

        // Check for constraint over-restriction
        if (quality_score.constraint_adherence.score > self.over_restriction_adherence_threshold and
            quality_score.correctness.test_pass_rate < self.over_restriction_test_threshold)
        {
            return .{
                .mode = .constraint_over_restriction,
                .confidence = 0.7,
                .details = "High constraint adherence but low test pass rate",
            };
        }

        // Check for weak constraint
        if (quality_score.constraint_adherence.score < self.weak_constraint_threshold) {
            return .{
                .mode = .weak_constraint,
                .confidence = 0.6,
                .details = "Constraint adherence near baseline level",
            };
        }

        // No failure detected
        return .{
            .mode = .none,
            .confidence = 1.0,
            .details = null,
        };
    }

    /// Check if output appears truncated
    fn checkTruncation(self: *FailureAnalyzer, code: []const u8) bool {
        _ = self;
        if (code.len == 0) return true;

        // Check for common truncation indicators
        // 1. Ends mid-string
        var in_string = false;
        var i = code.len;
        while (i > 0) {
            i -= 1;
            const c = code[i];
            if (c == '"' or c == '\'') {
                in_string = !in_string;
                break;
            }
            if (c != ' ' and c != '\n' and c != '\t') break;
        }
        if (in_string) return true;

        // 2. Unbalanced braces
        var brace_count: i32 = 0;
        var paren_count: i32 = 0;
        for (code) |c| {
            switch (c) {
                '{' => brace_count += 1,
                '}' => brace_count -= 1,
                '(' => paren_count += 1,
                ')' => paren_count -= 1,
                else => {},
            }
        }
        if (brace_count > 0 or paren_count > 0) return true;

        // 3. Ends with incomplete statement
        var trimmed = code;
        while (trimmed.len > 0 and (trimmed[trimmed.len - 1] == ' ' or
            trimmed[trimmed.len - 1] == '\n' or
            trimmed[trimmed.len - 1] == '\t'))
        {
            trimmed = trimmed[0 .. trimmed.len - 1];
        }
        if (trimmed.len > 0) {
            const last = trimmed[trimmed.len - 1];
            // Suspicious endings
            if (last == ',' or last == ':' or last == '=' or last == '+' or last == '-') {
                return true;
            }
        }

        return false;
    }

    /// Analyze comparative results between constrained and baseline
    pub fn analyzeComparative(
        self: *FailureAnalyzer,
        constrained_code: ?[]const u8,
        baseline_code: ?[]const u8,
        constrained_time_ms: u64,
        baseline_time_ms: u64,
        constrained_test: test_runner.TestResult,
        baseline_test: test_runner.TestResult,
        quality_comparison: quality_scorer.ComparativeAnalysis,
    ) ComparativeFailureAnalysis {
        const constrained_analysis = self.analyze(
            constrained_code,
            constrained_time_ms,
            constrained_test,
            quality_comparison.constrained_score,
        );

        const baseline_analysis = self.analyze(
            baseline_code,
            baseline_time_ms,
            baseline_test,
            quality_comparison.baseline_score,
        );

        // Determine if constraint was beneficial or harmful
        const constraint_impact = blk: {
            if (constrained_analysis.mode == .none and baseline_analysis.mode != .none) {
                break :blk ConstraintImpact.beneficial;
            } else if (constrained_analysis.mode != .none and baseline_analysis.mode == .none) {
                break :blk ConstraintImpact.harmful;
            } else if (constrained_analysis.mode == .none and baseline_analysis.mode == .none) {
                // Both succeeded - check scores
                if (quality_comparison.constrained_score.overall > quality_comparison.baseline_score.overall + 5.0) {
                    break :blk ConstraintImpact.beneficial;
                } else if (quality_comparison.baseline_score.overall > quality_comparison.constrained_score.overall + 5.0) {
                    break :blk ConstraintImpact.harmful;
                }
                break :blk ConstraintImpact.neutral;
            } else {
                // Both failed - constraint didn't help
                break :blk ConstraintImpact.neutral;
            }
        };

        return .{
            .constrained_analysis = constrained_analysis,
            .baseline_analysis = baseline_analysis,
            .constraint_impact = constraint_impact,
        };
    }
};

/// Impact of constraint on generation
pub const ConstraintImpact = enum {
    beneficial, // Constraint helped
    harmful, // Constraint hurt
    neutral, // No significant difference

    pub fn toString(self: ConstraintImpact) []const u8 {
        return switch (self) {
            .beneficial => "beneficial",
            .harmful => "harmful",
            .neutral => "neutral",
        };
    }
};

/// Comparative failure analysis
pub const ComparativeFailureAnalysis = struct {
    constrained_analysis: FailureAnalysis,
    baseline_analysis: FailureAnalysis,
    constraint_impact: ConstraintImpact,

    pub fn toJson(self: ComparativeFailureAnalysis, allocator: Allocator) ![]const u8 {
        var buf = std.ArrayList(u8).init(allocator);
        errdefer buf.deinit();
        const writer = buf.writer();

        const constrained_json = try self.constrained_analysis.toJson(allocator);
        defer allocator.free(constrained_json);
        const baseline_json = try self.baseline_analysis.toJson(allocator);
        defer allocator.free(baseline_json);

        try writer.writeAll("{");
        try writer.print("\"constrained\": {s}, ", .{constrained_json});
        try writer.print("\"baseline\": {s}, ", .{baseline_json});
        try writer.print("\"constraint_impact\": \"{s}\"", .{self.constraint_impact.toString()});
        try writer.writeAll("}");

        return buf.toOwnedSlice();
    }
};

test "failure analyzer - generation failure" {
    var analyzer = FailureAnalyzer.init(std.testing.allocator);
    const result = analyzer.analyze(
        null,
        1000,
        .{ .success = false, .total_tests = 0, .passed_tests = 0, .failed_tests = 0, .duration_ms = 0, .output = "" },
        quality_scorer.QualityScore.placeholder(),
    );
    try std.testing.expectEqual(FailureMode.generation_failure, result.mode);
}

test "failure analyzer - premature termination" {
    var analyzer = FailureAnalyzer.init(std.testing.allocator);
    const result = analyzer.analyze(
        "x",
        500, // < 1000ms
        .{ .success = false, .total_tests = 0, .passed_tests = 0, .failed_tests = 0, .duration_ms = 500, .output = "" },
        quality_scorer.QualityScore.placeholder(),
    );
    try std.testing.expectEqual(FailureMode.premature_termination, result.mode);
}

test "truncation detection - unbalanced braces" {
    var analyzer = FailureAnalyzer.init(std.testing.allocator);
    try std.testing.expect(analyzer.checkTruncation("function foo() {"));
    try std.testing.expect(!analyzer.checkTruncation("function foo() {}"));
}
