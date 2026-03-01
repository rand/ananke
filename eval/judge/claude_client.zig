// Claude API Client for LLM-as-Judge
//
// Client for interacting with Claude API for code evaluation.
// Uses Claude Opus 4.5 as the primary judge model with specific settings
// optimized for consistent, reproducible evaluations.

const std = @import("std");
const Allocator = std.mem.Allocator;
const rubrics = @import("rubrics.zig");

/// Claude API configuration for judge evaluations
pub const JudgeConfig = struct {
    /// API key (from environment or direct)
    api_key: []const u8,
    /// Model to use (default: Claude Opus 4.5)
    model: []const u8 = "claude-opus-4-5-20251101",
    /// Base URL for API calls
    base_url: []const u8 = "https://api.anthropic.com",
    /// Temperature for consistent responses (low for reproducibility)
    temperature: f32 = 0.15,
    /// Max tokens for response
    max_tokens: u32 = 2048,
    /// Number of evaluations per criterion for majority voting
    num_evaluations: u32 = 3,
    /// Timeout in milliseconds
    timeout_ms: u32 = 60000,
};

/// Response from Claude API
pub const ClaudeResponse = struct {
    content: []const u8,
    model: []const u8,
    usage: UsageStats,

    pub const UsageStats = struct {
        input_tokens: u32,
        output_tokens: u32,
    };

    pub fn deinit(self: *ClaudeResponse, allocator: Allocator) void {
        allocator.free(self.content);
        allocator.free(self.model);
    }
};

/// Error types for API interactions
pub const ClientError = error{
    ApiKeyMissing,
    RequestFailed,
    ResponseParseError,
    RateLimited,
    InvalidResponse,
    Timeout,
    OutOfMemory,
    NetworkError,
};

/// Claude API client for judge evaluations
pub const ClaudeJudgeClient = struct {
    allocator: Allocator,
    config: JudgeConfig,

    pub fn init(allocator: Allocator, config: JudgeConfig) ClaudeJudgeClient {
        return .{
            .allocator = allocator,
            .config = config,
        };
    }

    /// Evaluate code against a specific criterion
    pub fn evaluate(
        self: *ClaudeJudgeClient,
        code: []const u8,
        criterion: rubrics.EvaluationCriterion,
        context: ?EvaluationContext,
    ) ClientError!rubrics.JudgeResult {
        const prompt = try self.buildEvaluationPrompt(code, criterion, context);
        defer self.allocator.free(prompt);

        const response = try self.callApi(prompt);
        defer {
            var mut_response = response;
            mut_response.deinit(self.allocator);
        }

        return try self.parseEvaluationResponse(response.content, criterion);
    }

    /// Evaluate with multiple rounds for majority voting
    pub fn evaluateWithConsensus(
        self: *ClaudeJudgeClient,
        code: []const u8,
        criterion: rubrics.EvaluationCriterion,
        context: ?EvaluationContext,
    ) ClientError!rubrics.AggregatedJudgeResult {
        var results = try self.allocator.alloc(rubrics.JudgeResult, self.config.num_evaluations);
        errdefer self.allocator.free(results);

        var successful: u32 = 0;
        for (0..self.config.num_evaluations) |i| {
            results[i] = self.evaluate(code, criterion, context) catch |err| {
                // If we fail some evaluations but have at least 2, we can still compute consensus
                std.log.warn("Evaluation {d} failed: {any}", .{ i, err });
                continue;
            };
            successful += 1;
        }

        if (successful < 2) {
            return ClientError.RequestFailed;
        }

        // Compute majority vote
        var score_counts = [_]u32{ 0, 0, 0, 0 };
        for (results[0..successful]) |result| {
            const idx: usize = switch (result.score) {
                .excellent => 0,
                .satisfactory => 1,
                .needs_improvement => 2,
                .unsatisfactory => 3,
            };
            score_counts[idx] += 1;
        }

        // Find majority
        var max_count: u32 = 0;
        var max_idx: usize = 0;
        for (score_counts, 0..) |count, idx| {
            if (count > max_count) {
                max_count = count;
                max_idx = idx;
            }
        }

        const final_score: rubrics.ScoreLevel = switch (max_idx) {
            0 => .excellent,
            1 => .satisfactory,
            2 => .needs_improvement,
            else => .unsatisfactory,
        };

        const agreement_rate = @as(f32, @floatFromInt(max_count)) / @as(f32, @floatFromInt(successful));

        return rubrics.AggregatedJudgeResult{
            .criterion = criterion,
            .final_score = final_score,
            .agreement_rate = agreement_rate,
            .individual_results = results[0..successful],
            .is_reliable = agreement_rate >= 0.67, // At least 2/3 agreement
        };
    }

    /// Build the evaluation prompt for a criterion
    fn buildEvaluationPrompt(
        self: *ClaudeJudgeClient,
        code: []const u8,
        criterion: rubrics.EvaluationCriterion,
        context: ?EvaluationContext,
    ) ClientError![]const u8 {
        const rubric = rubrics.getRubric(criterion);

        var buf = std.ArrayList(u8).init(self.allocator);
        errdefer buf.deinit();

        const writer = buf.writer();

        // System context
        writer.writeAll(
            \\You are an expert code reviewer evaluating generated code quality.
            \\Your task is to evaluate the code against a specific criterion and provide a structured assessment.
            \\
            \\IMPORTANT: You must think through your evaluation BEFORE giving a score.
            \\
        ) catch return ClientError.OutOfMemory;

        // Criterion description
        writer.print(
            \\
            \\## Evaluation Criterion: {s}
            \\
            \\{s}
            \\
            \\## Scoring Rubric:
            \\
            \\- **Excellent**: {s}
            \\- **Satisfactory**: {s}
            \\- **Needs Improvement**: {s}
            \\- **Unsatisfactory**: {s}
            \\
            \\## Evaluation Points:
            \\
        , .{
            criterion.toString(),
            criterion.description(),
            rubric.excellent_description,
            rubric.satisfactory_description,
            rubric.needs_improvement_description,
            rubric.unsatisfactory_description,
        }) catch return ClientError.OutOfMemory;

        for (rubric.evaluation_points) |point| {
            writer.print("- {s}\n", .{point}) catch return ClientError.OutOfMemory;
        }

        // Context (constraints, reference, etc.)
        if (context) |ctx| {
            writer.writeAll(
                \\
                \\## Context:
                \\
            ) catch return ClientError.OutOfMemory;

            if (ctx.constraints) |constraints| {
                writer.print("Constraints: {s}\n", .{constraints}) catch return ClientError.OutOfMemory;
            }
            if (ctx.reference_code) |ref| {
                writer.print("Reference implementation:\n```\n{s}\n```\n", .{ref}) catch return ClientError.OutOfMemory;
            }
            if (ctx.language) |lang| {
                writer.print("Language: {s}\n", .{lang}) catch return ClientError.OutOfMemory;
            }
        }

        // Code to evaluate
        writer.print(
            \\
            \\## Code to Evaluate:
            \\
            \\```
            \\{s}
            \\```
            \\
            \\## Your Evaluation:
            \\
            \\Provide your analysis in the following format:
            \\
            \\### Observations:
            \\1. [First observation about the code]
            \\2. [Second observation]
            \\3. [Third observation]
            \\
            \\### Analysis:
            \\[Your reasoning about how the observations map to the rubric]
            \\
            \\### Score: [excellent|satisfactory|needs_improvement|unsatisfactory]
            \\### Confidence: [high|medium|low]
            \\### Justification: [One sentence summary of why this score]
            \\
        , .{code}) catch return ClientError.OutOfMemory;

        return buf.toOwnedSlice() catch return ClientError.OutOfMemory;
    }

    /// Parse the evaluation response into a JudgeResult
    fn parseEvaluationResponse(
        self: *ClaudeJudgeClient,
        response: []const u8,
        criterion: rubrics.EvaluationCriterion,
    ) ClientError!rubrics.JudgeResult {
        // Extract score
        var score: rubrics.ScoreLevel = .satisfactory; // Default
        if (std.mem.indexOf(u8, response, "### Score:")) |idx| {
            const after_score = response[idx + 10 ..];
            const score_line = if (std.mem.indexOf(u8, after_score, "\n")) |end|
                after_score[0..end]
            else
                after_score;

            const trimmed = std.mem.trim(u8, score_line, " \t\r\n");
            if (rubrics.ScoreLevel.fromString(trimmed)) |s| {
                score = s;
            }
        }

        // Extract confidence
        var confidence: rubrics.ConfidenceLevel = .medium; // Default
        if (std.mem.indexOf(u8, response, "### Confidence:")) |idx| {
            const after_conf = response[idx + 15 ..];
            const conf_line = if (std.mem.indexOf(u8, after_conf, "\n")) |end|
                after_conf[0..end]
            else
                after_conf;

            const trimmed = std.mem.trim(u8, conf_line, " \t\r\n");
            if (rubrics.ConfidenceLevel.fromString(trimmed)) |c| {
                confidence = c;
            }
        }

        // Extract reasoning (everything in Analysis section)
        var reasoning: []const u8 = "";
        if (std.mem.indexOf(u8, response, "### Analysis:")) |start| {
            const after_analysis = response[start + 13 ..];
            if (std.mem.indexOf(u8, after_analysis, "### Score:")) |end| {
                reasoning = std.mem.trim(u8, after_analysis[0..end], " \t\r\n");
            }
        }

        // Duplicate reasoning for ownership
        const owned_reasoning = self.allocator.dupe(u8, reasoning) catch return ClientError.OutOfMemory;

        // Extract observations
        var observations_list = std.ArrayList([]const u8).init(self.allocator);
        errdefer {
            for (observations_list.items) |obs| self.allocator.free(obs);
            observations_list.deinit();
        }

        if (std.mem.indexOf(u8, response, "### Observations:")) |start| {
            const after_obs = response[start + 17 ..];
            const end_idx = std.mem.indexOf(u8, after_obs, "### Analysis:") orelse after_obs.len;
            const obs_section = after_obs[0..end_idx];

            var lines = std.mem.splitSequence(u8, obs_section, "\n");
            while (lines.next()) |line| {
                const trimmed = std.mem.trim(u8, line, " \t\r\n");
                if (trimmed.len > 2 and (trimmed[0] == '-' or (trimmed[0] >= '1' and trimmed[0] <= '9'))) {
                    // Skip the bullet/number prefix
                    var content = trimmed[2..];
                    if (content.len > 0 and content[0] == '.') content = content[1..];
                    content = std.mem.trim(u8, content, " ");
                    if (content.len > 0) {
                        const owned = self.allocator.dupe(u8, content) catch return ClientError.OutOfMemory;
                        observations_list.append(owned) catch return ClientError.OutOfMemory;
                    }
                }
            }
        }

        return rubrics.JudgeResult{
            .criterion = criterion,
            .score = score,
            .confidence = confidence,
            .reasoning = owned_reasoning,
            .observations = observations_list.toOwnedSlice() catch return ClientError.OutOfMemory,
        };
    }

    /// Make API call to Claude
    fn callApi(self: *ClaudeJudgeClient, prompt: []const u8) ClientError!ClaudeResponse {
        // Note: This is a placeholder implementation.
        // In a real implementation, this would:
        // 1. Build the HTTP request with proper headers
        // 2. Make the POST request to /v1/messages
        // 3. Parse the JSON response
        // 4. Handle rate limiting and retries
        //
        // For now, we return a mock response for testing structure

        _ = self;
        _ = prompt;

        // This would be replaced with actual HTTP client code
        return ClientError.RequestFailed;
    }
};

/// Context for evaluation (constraints, reference code, etc.)
pub const EvaluationContext = struct {
    /// Constraint specification (JSON)
    constraints: ?[]const u8 = null,
    /// Reference implementation for comparison
    reference_code: ?[]const u8 = null,
    /// Programming language
    language: ?[]const u8 = null,
    /// Task description
    task_description: ?[]const u8 = null,
};

// Tests

test "build evaluation prompt" {
    const allocator = std.testing.allocator;
    var client = ClaudeJudgeClient.init(allocator, .{
        .api_key = "test-key",
    });

    const code = "function add(a, b) { return a + b; }";
    const prompt = try client.buildEvaluationPrompt(code, .naming_clarity, null);
    defer allocator.free(prompt);

    try std.testing.expect(std.mem.indexOf(u8, prompt, "naming_clarity") != null);
    try std.testing.expect(std.mem.indexOf(u8, prompt, "function add") != null);
}

test "parse evaluation response" {
    const allocator = std.testing.allocator;
    var client = ClaudeJudgeClient.init(allocator, .{
        .api_key = "test-key",
    });

    const mock_response =
        \\### Observations:
        \\1. Function name 'add' is clear
        \\2. Parameters 'a' and 'b' could be more descriptive
        \\3. No type annotations present
        \\
        \\### Analysis:
        \\The code uses reasonable naming but could be improved with more descriptive parameter names.
        \\
        \\### Score: satisfactory
        \\### Confidence: high
        \\### Justification: Basic naming is clear but lacks detail.
    ;

    var result = try client.parseEvaluationResponse(mock_response, .naming_clarity);
    defer result.deinit(allocator);

    try std.testing.expectEqual(rubrics.ScoreLevel.satisfactory, result.score);
    try std.testing.expectEqual(rubrics.ConfidenceLevel.high, result.confidence);
    try std.testing.expect(result.observations.len >= 2);
}
