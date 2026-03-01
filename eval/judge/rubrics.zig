// LLM-as-Judge Rubric Definitions
//
// Implements evaluation rubrics following best practices from research:
// - Binary/ternary scales for consistency
// - Chain-of-thought reasoning BEFORE score
// - Multiple evaluations with majority voting
// - Clear, specific criteria for each dimension

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Evaluation score levels (ternary scale for better consistency)
pub const ScoreLevel = enum {
    /// Exceeds expectations
    excellent,
    /// Meets expectations
    satisfactory,
    /// Below expectations, needs improvement
    needs_improvement,
    /// Significantly below expectations
    unsatisfactory,

    pub fn toNumeric(self: ScoreLevel) f32 {
        return switch (self) {
            .excellent => 100.0,
            .satisfactory => 75.0,
            .needs_improvement => 50.0,
            .unsatisfactory => 25.0,
        };
    }

    pub fn fromString(s: []const u8) ?ScoreLevel {
        if (std.mem.eql(u8, s, "excellent")) return .excellent;
        if (std.mem.eql(u8, s, "satisfactory")) return .satisfactory;
        if (std.mem.eql(u8, s, "needs_improvement")) return .needs_improvement;
        if (std.mem.eql(u8, s, "unsatisfactory")) return .unsatisfactory;
        return null;
    }

    pub fn toString(self: ScoreLevel) []const u8 {
        return switch (self) {
            .excellent => "excellent",
            .satisfactory => "satisfactory",
            .needs_improvement => "needs_improvement",
            .unsatisfactory => "unsatisfactory",
        };
    }
};

/// Confidence level in the evaluation
pub const ConfidenceLevel = enum {
    high,
    medium,
    low,

    pub fn toString(self: ConfidenceLevel) []const u8 {
        return switch (self) {
            .high => "high",
            .medium => "medium",
            .low => "low",
        };
    }

    pub fn fromString(s: []const u8) ?ConfidenceLevel {
        if (std.mem.eql(u8, s, "high")) return .high;
        if (std.mem.eql(u8, s, "medium")) return .medium;
        if (std.mem.eql(u8, s, "low")) return .low;
        return null;
    }
};

/// Result from a single judge evaluation
pub const JudgeResult = struct {
    /// Which criterion was evaluated
    criterion: EvaluationCriterion,
    /// The assigned score
    score: ScoreLevel,
    /// Confidence in the score
    confidence: ConfidenceLevel,
    /// Chain-of-thought reasoning (captured before score)
    reasoning: []const u8,
    /// Specific observations that led to the score
    observations: []const []const u8,

    pub fn deinit(self: *JudgeResult, allocator: Allocator) void {
        allocator.free(self.reasoning);
        for (self.observations) |obs| {
            allocator.free(obs);
        }
        allocator.free(self.observations);
    }
};

/// Aggregated result from multiple judge evaluations
pub const AggregatedJudgeResult = struct {
    criterion: EvaluationCriterion,
    /// Majority vote score
    final_score: ScoreLevel,
    /// Agreement rate (0-1) - how many judges agreed
    agreement_rate: f32,
    /// Individual results from each evaluation
    individual_results: []JudgeResult,
    /// Whether this result is reliable (high agreement)
    is_reliable: bool,

    pub fn deinit(self: *AggregatedJudgeResult, allocator: Allocator) void {
        for (self.individual_results) |*result| {
            result.deinit(allocator);
        }
        allocator.free(self.individual_results);
    }
};

/// Evaluation criteria categories
pub const EvaluationCategory = enum {
    /// Code readability and clarity
    readability,
    /// Architectural alignment with constraints
    architecture,
    /// Language-specific style and conventions
    style,
};

/// Specific evaluation criteria
pub const EvaluationCriterion = enum {
    // Readability criteria
    naming_clarity,
    structural_clarity,
    comment_quality,

    // Architecture criteria
    constraint_alignment,
    pattern_consistency,
    error_handling_consistency,

    // Style criteria
    idiomatic_usage,
    formatting_consistency,

    pub fn category(self: EvaluationCriterion) EvaluationCategory {
        return switch (self) {
            .naming_clarity, .structural_clarity, .comment_quality => .readability,
            .constraint_alignment, .pattern_consistency, .error_handling_consistency => .architecture,
            .idiomatic_usage, .formatting_consistency => .style,
        };
    }

    pub fn toString(self: EvaluationCriterion) []const u8 {
        return switch (self) {
            .naming_clarity => "naming_clarity",
            .structural_clarity => "structural_clarity",
            .comment_quality => "comment_quality",
            .constraint_alignment => "constraint_alignment",
            .pattern_consistency => "pattern_consistency",
            .error_handling_consistency => "error_handling_consistency",
            .idiomatic_usage => "idiomatic_usage",
            .formatting_consistency => "formatting_consistency",
        };
    }

    pub fn description(self: EvaluationCriterion) []const u8 {
        return switch (self) {
            .naming_clarity => "Quality of variable, function, and type names - are they descriptive, consistent, and follow conventions?",
            .structural_clarity => "Logical organization of code - is the structure easy to follow and understand?",
            .comment_quality => "Appropriateness and quality of comments - are they helpful without being excessive?",
            .constraint_alignment => "How well does the code align with specified constraints and requirements?",
            .pattern_consistency => "Consistency in using design patterns and code organization throughout",
            .error_handling_consistency => "Consistent and appropriate error handling across the codebase",
            .idiomatic_usage => "Use of language-specific idioms and best practices",
            .formatting_consistency => "Consistent formatting, indentation, and whitespace usage",
        };
    }
};

/// Rubric definition for a specific criterion
pub const Rubric = struct {
    criterion: EvaluationCriterion,
    /// What constitutes 'excellent'
    excellent_description: []const u8,
    /// What constitutes 'satisfactory'
    satisfactory_description: []const u8,
    /// What constitutes 'needs_improvement'
    needs_improvement_description: []const u8,
    /// What constitutes 'unsatisfactory'
    unsatisfactory_description: []const u8,
    /// Specific things to look for
    evaluation_points: []const []const u8,
};

/// Get the rubric for a specific criterion
pub fn getRubric(criterion: EvaluationCriterion) Rubric {
    return switch (criterion) {
        .naming_clarity => .{
            .criterion = .naming_clarity,
            .excellent_description = "All names are descriptive, follow language conventions, and clearly convey purpose. No single-letter variables except loop counters. Types are named appropriately.",
            .satisfactory_description = "Most names are clear and follow conventions. Minor inconsistencies may exist. Purpose is generally understandable from names.",
            .needs_improvement_description = "Several unclear names or convention violations. Some effort required to understand purpose from names alone.",
            .unsatisfactory_description = "Many cryptic or misleading names. Heavy reliance on context or comments to understand variable purposes.",
            .evaluation_points = &[_][]const u8{
                "Check function names - do they describe what the function does?",
                "Check variable names - can you understand their purpose without reading surrounding code?",
                "Are naming conventions consistent (camelCase, snake_case, etc.)?",
                "Are type names descriptive?",
                "Are there any misleading names?",
            },
        },
        .structural_clarity => .{
            .criterion = .structural_clarity,
            .excellent_description = "Code is logically organized with clear separation of concerns. Functions are appropriately sized. Control flow is easy to follow.",
            .satisfactory_description = "Structure is generally clear. Some functions may be slightly long. Control flow is understandable with minor effort.",
            .needs_improvement_description = "Structure could be improved. Some deeply nested code or oversized functions. Requires effort to trace execution.",
            .unsatisfactory_description = "Poor structure with deeply nested code, very long functions, or confusing control flow. Difficult to understand overall organization.",
            .evaluation_points = &[_][]const u8{
                "Is the code organized into logical sections?",
                "Are functions/methods appropriately sized (not too long)?",
                "Is nesting depth reasonable (<4 levels)?",
                "Can you follow the control flow easily?",
                "Is there clear separation of concerns?",
            },
        },
        .comment_quality => .{
            .criterion = .comment_quality,
            .excellent_description = "Comments explain 'why' not 'what'. Complex logic is documented. No redundant comments. Documentation is helpful and current.",
            .satisfactory_description = "Key complexity is documented. Comments are generally helpful. Minor redundancy may exist.",
            .needs_improvement_description = "Missing comments on complex sections or excessive obvious comments. Documentation quality varies.",
            .unsatisfactory_description = "Missing critical documentation, misleading comments, or excessive noise. Comments don't aid understanding.",
            .evaluation_points = &[_][]const u8{
                "Do comments explain WHY, not just WHAT?",
                "Is complex logic documented?",
                "Are there redundant comments that just repeat the code?",
                "Are API/function signatures documented where needed?",
                "Are comments accurate and up-to-date with the code?",
            },
        },
        .constraint_alignment => .{
            .criterion = .constraint_alignment,
            .excellent_description = "Code fully adheres to all specified constraints. Structure matches requirements exactly. All required patterns are present.",
            .satisfactory_description = "Code meets most constraints. Minor deviations may exist but don't affect functionality.",
            .needs_improvement_description = "Several constraint violations. Code works but doesn't follow specified structure well.",
            .unsatisfactory_description = "Significant constraint violations. Code structure differs substantially from requirements.",
            .evaluation_points = &[_][]const u8{
                "Does the function signature match the specified constraint?",
                "Are required patterns (must_use) present?",
                "Are forbidden patterns (must_not_use) absent?",
                "Does the code structure match the grammar specification?",
                "Are all type constraints satisfied?",
            },
        },
        .pattern_consistency => .{
            .criterion = .pattern_consistency,
            .excellent_description = "Consistent patterns throughout. Same problems solved the same way. Clear, repeated patterns are easy to recognize.",
            .satisfactory_description = "Generally consistent. Minor variations in approach for similar problems.",
            .needs_improvement_description = "Noticeable inconsistencies. Same problems sometimes solved differently without clear reason.",
            .unsatisfactory_description = "Highly inconsistent. Different approaches for similar problems. No clear patterns.",
            .evaluation_points = &[_][]const u8{
                "Are similar operations handled consistently?",
                "Is the same error handling approach used throughout?",
                "Are data structures used consistently?",
                "Is the same coding style maintained throughout?",
                "Are there unexplained variations in approach?",
            },
        },
        .error_handling_consistency => .{
            .criterion = .error_handling_consistency,
            .excellent_description = "Comprehensive, consistent error handling. All error cases covered. Clear error messages. Appropriate recovery strategies.",
            .satisfactory_description = "Error handling present and consistent. Most error cases covered. Some minor gaps.",
            .needs_improvement_description = "Inconsistent error handling. Some operations unprotected. Error messages could be clearer.",
            .unsatisfactory_description = "Poor or missing error handling. Many unprotected operations. Errors may be silently swallowed.",
            .evaluation_points = &[_][]const u8{
                "Are all operations that can fail properly handled?",
                "Is the error handling approach consistent?",
                "Are error messages clear and helpful?",
                "Are errors propagated appropriately?",
                "Are there any silently swallowed errors?",
            },
        },
        .idiomatic_usage => .{
            .criterion = .idiomatic_usage,
            .excellent_description = "Code fully embraces language idioms. Uses modern features appropriately. Would be considered 'idiomatic' by experts.",
            .satisfactory_description = "Generally idiomatic. Uses common patterns. Minor non-idiomatic choices.",
            .needs_improvement_description = "Some non-idiomatic patterns. Could better leverage language features. Works but not elegant.",
            .unsatisfactory_description = "Largely non-idiomatic. Ignores language features. Looks like code translated from another language.",
            .evaluation_points = &[_][]const u8{
                "Are language-specific features used appropriately?",
                "Are common idioms followed?",
                "Is the code style typical for this language?",
                "Are modern language features used where beneficial?",
                "Would an expert in this language write similar code?",
            },
        },
        .formatting_consistency => .{
            .criterion = .formatting_consistency,
            .excellent_description = "Perfect formatting consistency. Consistent indentation, spacing, and style throughout.",
            .satisfactory_description = "Generally consistent formatting. Minor inconsistencies don't affect readability.",
            .needs_improvement_description = "Noticeable formatting inconsistencies. Some sections formatted differently.",
            .unsatisfactory_description = "Inconsistent formatting throughout. Makes code harder to read.",
            .evaluation_points = &[_][]const u8{
                "Is indentation consistent?",
                "Is spacing around operators consistent?",
                "Are blank lines used consistently?",
                "Is brace/bracket placement consistent?",
                "Would a formatter change much?",
            },
        },
    };
}

/// Get all rubrics for a category
pub fn getRubricsForCategory(category: EvaluationCategory) []const EvaluationCriterion {
    return switch (category) {
        .readability => &[_]EvaluationCriterion{ .naming_clarity, .structural_clarity, .comment_quality },
        .architecture => &[_]EvaluationCriterion{ .constraint_alignment, .pattern_consistency, .error_handling_consistency },
        .style => &[_]EvaluationCriterion{ .idiomatic_usage, .formatting_consistency },
    };
}

/// Get all criteria for evaluation
pub fn getAllCriteria() []const EvaluationCriterion {
    return &[_]EvaluationCriterion{
        .naming_clarity,
        .structural_clarity,
        .comment_quality,
        .constraint_alignment,
        .pattern_consistency,
        .error_handling_consistency,
        .idiomatic_usage,
        .formatting_consistency,
    };
}

// Tests

test "score level conversions" {
    try std.testing.expectEqual(@as(f32, 100.0), ScoreLevel.excellent.toNumeric());
    try std.testing.expectEqual(@as(f32, 75.0), ScoreLevel.satisfactory.toNumeric());
    try std.testing.expectEqual(ScoreLevel.excellent, ScoreLevel.fromString("excellent").?);
}

test "criterion category mapping" {
    try std.testing.expectEqual(EvaluationCategory.readability, EvaluationCriterion.naming_clarity.category());
    try std.testing.expectEqual(EvaluationCategory.architecture, EvaluationCriterion.constraint_alignment.category());
    try std.testing.expectEqual(EvaluationCategory.style, EvaluationCriterion.idiomatic_usage.category());
}

test "get rubric" {
    const rubric = getRubric(.naming_clarity);
    try std.testing.expectEqual(EvaluationCriterion.naming_clarity, rubric.criterion);
    try std.testing.expect(rubric.evaluation_points.len > 0);
}
