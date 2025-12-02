// Quality Scoring Module for Ananke Evaluation
// Provides comprehensive code quality metrics beyond pass/fail testing
//
// Metrics:
// 1. Constraint Adherence (0-100): How well code matches specified constraints
// 2. Pattern Conformity (0-100): How closely code follows expected style/patterns
// 3. Code Quality (0-100): Readability, complexity, conciseness
// 4. Security Score (0-100): Safe patterns, no dangerous constructs
// 5. Comparative Analysis: Delta metrics between constrained and unconstrained

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Complete quality score for a piece of generated code
pub const QualityScore = struct {
    /// Overall composite score (weighted average of component scores)
    overall: f32,

    /// How well the code adheres to specified constraints
    constraint_adherence: ConstraintAdherenceScore,

    /// How well the code follows expected patterns
    pattern_conformity: PatternConformityScore,

    /// General code quality metrics
    code_quality: CodeQualityScore,

    /// Security and safety metrics
    security: SecurityScore,

    pub fn toJson(self: QualityScore, allocator: Allocator) ![]const u8 {
        var buf = try std.ArrayList(u8).initCapacity(allocator, 2048);
        defer buf.deinit(allocator);

        const writer = buf.writer(allocator);
        try writer.writeAll("{");
        try writer.print("\"overall\":{d:.2},", .{self.overall});

        // Constraint adherence
        try writer.writeAll("\"constraint_adherence\":{");
        try writer.print("\"score\":{d:.2},", .{self.constraint_adherence.score});
        try writer.print("\"signature_match\":{},", .{self.constraint_adherence.signature_match});
        try writer.print("\"type_match\":{},", .{self.constraint_adherence.type_match});
        try writer.print("\"naming_match\":{},", .{self.constraint_adherence.naming_match});
        try writer.print("\"structure_match\":{}", .{self.constraint_adherence.structure_match});
        try writer.writeAll("},");

        // Pattern conformity
        try writer.writeAll("\"pattern_conformity\":{");
        try writer.print("\"score\":{d:.2},", .{self.pattern_conformity.score});
        try writer.print("\"style_consistency\":{d:.2},", .{self.pattern_conformity.style_consistency});
        try writer.print("\"idiom_usage\":{d:.2},", .{self.pattern_conformity.idiom_usage});
        try writer.print("\"naming_conventions\":{d:.2}", .{self.pattern_conformity.naming_conventions});
        try writer.writeAll("},");

        // Code quality
        try writer.writeAll("\"code_quality\":{");
        try writer.print("\"score\":{d:.2},", .{self.code_quality.score});
        try writer.print("\"readability\":{d:.2},", .{self.code_quality.readability});
        try writer.print("\"complexity\":{d:.2},", .{self.code_quality.complexity});
        try writer.print("\"conciseness\":{d:.2},", .{self.code_quality.conciseness});
        try writer.print("\"lines_of_code\":{d},", .{self.code_quality.lines_of_code});
        try writer.print("\"max_nesting_depth\":{d},", .{self.code_quality.max_nesting_depth});
        try writer.print("\"avg_line_length\":{d:.1}", .{self.code_quality.avg_line_length});
        try writer.writeAll("},");

        // Security
        try writer.writeAll("\"security\":{");
        try writer.print("\"score\":{d:.2},", .{self.security.score});
        try writer.print("\"has_input_validation\":{},", .{self.security.has_input_validation});
        try writer.print("\"has_error_handling\":{},", .{self.security.has_error_handling});
        try writer.print("\"dangerous_patterns\":{{", .{});
        try writer.print("\"eval_usage\":{},", .{self.security.dangerous_patterns.eval_usage});
        try writer.print("\"raw_sql\":{},", .{self.security.dangerous_patterns.raw_sql});
        try writer.print("\"unsafe_regex\":{},", .{self.security.dangerous_patterns.unsafe_regex});
        try writer.print("\"hardcoded_secrets\":{}", .{self.security.dangerous_patterns.hardcoded_secrets});
        try writer.writeAll("}}");
        try writer.writeAll("}");

        try writer.writeAll("}");

        return try buf.toOwnedSlice(allocator);
    }
};

/// Measures how well generated code matches specified constraints
pub const ConstraintAdherenceScore = struct {
    /// Overall adherence score (0-100)
    score: f32,

    /// Does the function signature match the specified grammar?
    signature_match: bool,

    /// Do the types match (parameters, return type)?
    type_match: bool,

    /// Does naming match constraints (function name, variable patterns)?
    naming_match: bool,

    /// Does structure match constraints (must_use, must_not_use)?
    structure_match: bool,
};

/// Measures how well code follows expected patterns from context
pub const PatternConformityScore = struct {
    /// Overall conformity score (0-100)
    score: f32,

    /// Consistency with language style conventions (0-100)
    style_consistency: f32,

    /// Use of language-idiomatic patterns (0-100)
    idiom_usage: f32,

    /// Adherence to naming conventions (camelCase, snake_case, etc.) (0-100)
    naming_conventions: f32,
};

/// General code quality metrics
pub const CodeQualityScore = struct {
    /// Overall quality score (0-100)
    score: f32,

    /// Readability score based on structure and naming (0-100)
    readability: f32,

    /// Inverse complexity score (100 = simple, 0 = very complex) (0-100)
    complexity: f32,

    /// Conciseness score (100 = optimal, lower = verbose or too terse) (0-100)
    conciseness: f32,

    /// Raw metrics
    lines_of_code: u32,
    max_nesting_depth: u32,
    avg_line_length: f32,
};

/// Security and safety metrics
pub const SecurityScore = struct {
    /// Overall security score (0-100)
    score: f32,

    /// Does the code validate inputs?
    has_input_validation: bool,

    /// Does the code handle errors properly?
    has_error_handling: bool,

    /// Detected dangerous patterns
    dangerous_patterns: DangerousPatterns,
};

/// Flags for dangerous code patterns
pub const DangerousPatterns = struct {
    eval_usage: bool,
    raw_sql: bool,
    unsafe_regex: bool,
    hardcoded_secrets: bool,
};

/// Comparative analysis between constrained and unconstrained generation
pub const ComparativeAnalysis = struct {
    /// Delta in overall quality (positive = constrained better)
    overall_delta: f32,

    /// Delta in constraint adherence
    constraint_adherence_delta: f32,

    /// Delta in pattern conformity
    pattern_conformity_delta: f32,

    /// Delta in code quality
    code_quality_delta: f32,

    /// Delta in security score
    security_delta: f32,

    /// Which approach produced better results for each metric
    winner: WinnerAnalysis,

    pub fn toJson(self: ComparativeAnalysis, allocator: Allocator) ![]const u8 {
        var buf = try std.ArrayList(u8).initCapacity(allocator, 1024);
        defer buf.deinit(allocator);

        const writer = buf.writer(allocator);
        try writer.writeAll("{");
        try writer.print("\"overall_delta\":{d:.2},", .{self.overall_delta});
        try writer.print("\"constraint_adherence_delta\":{d:.2},", .{self.constraint_adherence_delta});
        try writer.print("\"pattern_conformity_delta\":{d:.2},", .{self.pattern_conformity_delta});
        try writer.print("\"code_quality_delta\":{d:.2},", .{self.code_quality_delta});
        try writer.print("\"security_delta\":{d:.2},", .{self.security_delta});
        try writer.writeAll("\"winner\":{");
        try writer.print("\"overall\":\"{s}\",", .{@tagName(self.winner.overall)});
        try writer.print("\"constraint_adherence\":\"{s}\",", .{@tagName(self.winner.constraint_adherence)});
        try writer.print("\"pattern_conformity\":\"{s}\",", .{@tagName(self.winner.pattern_conformity)});
        try writer.print("\"code_quality\":\"{s}\",", .{@tagName(self.winner.code_quality)});
        try writer.print("\"security\":\"{s}\"", .{@tagName(self.winner.security)});
        try writer.writeAll("}");
        try writer.writeAll("}");

        return try buf.toOwnedSlice(allocator);
    }
};

/// Which approach won for each metric
pub const WinnerAnalysis = struct {
    overall: Winner,
    constraint_adherence: Winner,
    pattern_conformity: Winner,
    code_quality: Winner,
    security: Winner,
};

pub const Winner = enum {
    constrained,
    unconstrained,
    tie,
};

/// Quality scorer for evaluating generated code
pub const QualityScorer = struct {
    allocator: Allocator,
    language: Language,

    pub const Language = enum {
        typescript,
        python,
        unknown,

        pub fn fromString(s: []const u8) Language {
            if (std.mem.eql(u8, s, "typescript")) return .typescript;
            if (std.mem.eql(u8, s, "python")) return .python;
            return .unknown;
        }
    };

    pub fn init(allocator: Allocator, language_str: []const u8) QualityScorer {
        return .{
            .allocator = allocator,
            .language = Language.fromString(language_str),
        };
    }

    /// Score a piece of generated code against constraints
    pub fn score(
        self: *QualityScorer,
        code: []const u8,
        constraint_json: ?[]const u8,
    ) QualityScore {
        const constraint_adherence = self.scoreConstraintAdherence(code, constraint_json);
        const pattern_conformity = self.scorePatternConformity(code);
        const code_quality = self.scoreCodeQuality(code);
        const security = self.scoreSecurity(code);

        // Weighted average for overall score
        const overall = constraint_adherence.score * 0.30 +
            pattern_conformity.score * 0.20 +
            code_quality.score * 0.25 +
            security.score * 0.25;

        return QualityScore{
            .overall = overall,
            .constraint_adherence = constraint_adherence,
            .pattern_conformity = pattern_conformity,
            .code_quality = code_quality,
            .security = security,
        };
    }

    /// Compare constrained vs unconstrained generation
    pub fn compare(
        self: *QualityScorer,
        constrained_code: []const u8,
        unconstrained_code: []const u8,
        constraint_json: ?[]const u8,
    ) struct { constrained: QualityScore, unconstrained: QualityScore, comparison: ComparativeAnalysis } {
        const constrained_score = self.score(constrained_code, constraint_json);
        const unconstrained_score = self.score(unconstrained_code, null);

        const comparison = ComparativeAnalysis{
            .overall_delta = constrained_score.overall - unconstrained_score.overall,
            .constraint_adherence_delta = constrained_score.constraint_adherence.score - unconstrained_score.constraint_adherence.score,
            .pattern_conformity_delta = constrained_score.pattern_conformity.score - unconstrained_score.pattern_conformity.score,
            .code_quality_delta = constrained_score.code_quality.score - unconstrained_score.code_quality.score,
            .security_delta = constrained_score.security.score - unconstrained_score.security.score,
            .winner = .{
                .overall = determineWinner(constrained_score.overall, unconstrained_score.overall),
                .constraint_adherence = determineWinner(constrained_score.constraint_adherence.score, unconstrained_score.constraint_adherence.score),
                .pattern_conformity = determineWinner(constrained_score.pattern_conformity.score, unconstrained_score.pattern_conformity.score),
                .code_quality = determineWinner(constrained_score.code_quality.score, unconstrained_score.code_quality.score),
                .security = determineWinner(constrained_score.security.score, unconstrained_score.security.score),
            },
        };

        return .{
            .constrained = constrained_score,
            .unconstrained = unconstrained_score,
            .comparison = comparison,
        };
    }

    fn determineWinner(constrained: f32, unconstrained: f32) Winner {
        const threshold: f32 = 2.0; // 2% threshold for tie
        if (@abs(constrained - unconstrained) < threshold) return .tie;
        if (constrained > unconstrained) return .constrained;
        return .unconstrained;
    }

    /// Score how well code adheres to specified constraints
    fn scoreConstraintAdherence(
        self: *QualityScorer,
        code: []const u8,
        constraint_json: ?[]const u8,
    ) ConstraintAdherenceScore {
        _ = self;

        if (constraint_json == null) {
            // No constraints provided - return neutral score
            return ConstraintAdherenceScore{
                .score = 50.0,
                .signature_match = false,
                .type_match = false,
                .naming_match = false,
                .structure_match = false,
            };
        }

        // Parse constraint JSON to check adherence
        const constraints = constraint_json.?;
        var checks_passed: u32 = 0;
        var total_checks: u32 = 0;

        // Check function name constraint
        if (std.mem.indexOf(u8, constraints, "\"function_name\"")) |_| {
            total_checks += 1;
            // Extract function name from constraints and check in code
            // For now, assume it's present if code is non-empty
            if (code.len > 10) checks_passed += 1;
        }

        // Check for must_use patterns
        if (std.mem.indexOf(u8, constraints, "\"must_use\"")) |_| {
            total_checks += 1;
            // Would parse must_use array and check each pattern
            if (code.len > 20) checks_passed += 1;
        }

        // Check for must_not_use patterns (dangerous patterns)
        var structure_match = true;
        if (std.mem.indexOf(u8, constraints, "\"must_not_use\"")) |_| {
            total_checks += 1;
            // Check for common dangerous patterns that might be constrained
            if (std.mem.indexOf(u8, code, "eval(") != null) {
                structure_match = false;
            } else {
                checks_passed += 1;
            }
        }

        // Check type annotations
        var type_match = false;
        if (std.mem.indexOf(u8, constraints, "\"return_type\"")) |_| {
            total_checks += 1;
            // Check if code has return type annotation
            if (std.mem.indexOf(u8, code, "->") != null or
                std.mem.indexOf(u8, code, "): ") != null or
                std.mem.indexOf(u8, code, "):") != null)
            {
                type_match = true;
                checks_passed += 1;
            }
        }

        // Check signature present
        var signature_match = false;
        if (std.mem.indexOf(u8, constraints, "\"grammar\"")) |_| {
            total_checks += 1;
            // Check if function/def/export pattern exists
            if (std.mem.indexOf(u8, code, "function") != null or
                std.mem.indexOf(u8, code, "def ") != null or
                std.mem.indexOf(u8, code, "export") != null)
            {
                signature_match = true;
                checks_passed += 1;
            }
        }

        const adherence_score: f32 = if (total_checks > 0)
            @as(f32, @floatFromInt(checks_passed)) / @as(f32, @floatFromInt(total_checks)) * 100.0
        else
            50.0;

        return ConstraintAdherenceScore{
            .score = adherence_score,
            .signature_match = signature_match,
            .type_match = type_match,
            .naming_match = code.len > 10, // Simplified
            .structure_match = structure_match,
        };
    }

    /// Score pattern conformity (style, idioms, naming)
    fn scorePatternConformity(self: *QualityScorer, code: []const u8) PatternConformityScore {
        var style_score: f32 = 70.0; // Base score
        var idiom_score: f32 = 70.0;
        var naming_score: f32 = 70.0;

        switch (self.language) {
            .typescript => {
                // Check for TypeScript idioms
                if (std.mem.indexOf(u8, code, "const ") != null) idiom_score += 10.0;
                if (std.mem.indexOf(u8, code, ": ") != null) idiom_score += 10.0; // Type annotations
                if (std.mem.indexOf(u8, code, "=>") != null) idiom_score += 5.0; // Arrow functions

                // Check naming conventions (camelCase for functions/variables)
                if (std.mem.indexOf(u8, code, "function ") != null) {
                    style_score += 10.0;
                }

                // Check for export pattern
                if (std.mem.indexOf(u8, code, "export ") != null) {
                    style_score += 10.0;
                }
            },
            .python => {
                // Check for Python idioms
                if (std.mem.indexOf(u8, code, "def ") != null) idiom_score += 10.0;
                if (std.mem.indexOf(u8, code, "->") != null) idiom_score += 10.0; // Type hints
                if (std.mem.indexOf(u8, code, ":") != null) idiom_score += 5.0;

                // Check for Python style
                if (std.mem.indexOf(u8, code, "if __name__") == null) {
                    style_score += 5.0; // Clean module pattern
                }
            },
            .unknown => {},
        }

        // Penalize very long lines
        var lines = std.mem.splitSequence(u8, code, "\n");
        while (lines.next()) |line| {
            if (line.len > 120) {
                style_score -= 5.0;
                break;
            }
        }

        // Clamp scores
        style_score = @min(100.0, @max(0.0, style_score));
        idiom_score = @min(100.0, @max(0.0, idiom_score));
        naming_score = @min(100.0, @max(0.0, naming_score));

        const overall = (style_score + idiom_score + naming_score) / 3.0;

        return PatternConformityScore{
            .score = overall,
            .style_consistency = style_score,
            .idiom_usage = idiom_score,
            .naming_conventions = naming_score,
        };
    }

    /// Score code quality (readability, complexity, conciseness)
    fn scoreCodeQuality(self: *QualityScorer, code: []const u8) CodeQualityScore {
        _ = self;

        var lines_of_code: u32 = 0;
        var max_nesting: u32 = 0;
        var current_nesting: u32 = 0;
        var total_line_length: u64 = 0;
        var non_empty_lines: u32 = 0;

        var lines = std.mem.splitSequence(u8, code, "\n");
        while (lines.next()) |line| {
            lines_of_code += 1;
            const trimmed = std.mem.trim(u8, line, " \t");
            if (trimmed.len > 0) {
                non_empty_lines += 1;
                total_line_length += line.len;
            }

            // Track nesting depth
            for (line) |c| {
                switch (c) {
                    '{', '(' => {
                        current_nesting += 1;
                        max_nesting = @max(max_nesting, current_nesting);
                    },
                    '}', ')' => {
                        if (current_nesting > 0) current_nesting -= 1;
                    },
                    else => {},
                }
            }
        }

        const avg_line_length: f32 = if (non_empty_lines > 0)
            @as(f32, @floatFromInt(total_line_length)) / @as(f32, @floatFromInt(non_empty_lines))
        else
            0.0;

        // Calculate scores

        // Readability: Penalize high nesting and very long lines
        var readability: f32 = 100.0;
        if (max_nesting > 4) readability -= @as(f32, @floatFromInt((max_nesting - 4) * 10));
        if (avg_line_length > 80) readability -= (avg_line_length - 80) * 0.5;
        readability = @max(0.0, readability);

        // Complexity: Inverse of nesting depth
        var complexity: f32 = 100.0 - @as(f32, @floatFromInt(max_nesting * 15));
        complexity = @max(0.0, @min(100.0, complexity));

        // Conciseness: Based on LOC relative to complexity
        var conciseness: f32 = 80.0;
        if (lines_of_code > 50) conciseness -= @as(f32, @floatFromInt((lines_of_code - 50) / 5));
        if (lines_of_code < 5 and max_nesting == 0) conciseness = 50.0; // Too short might be incomplete
        conciseness = @max(0.0, @min(100.0, conciseness));

        const overall = (readability + complexity + conciseness) / 3.0;

        return CodeQualityScore{
            .score = overall,
            .readability = readability,
            .complexity = complexity,
            .conciseness = conciseness,
            .lines_of_code = lines_of_code,
            .max_nesting_depth = max_nesting,
            .avg_line_length = avg_line_length,
        };
    }

    /// Score security (input validation, error handling, dangerous patterns)
    fn scoreSecurity(self: *QualityScorer, code: []const u8) SecurityScore {
        _ = self;

        var security_score: f32 = 100.0;

        // Check for input validation patterns
        const has_input_validation = std.mem.indexOf(u8, code, "if (") != null or
            std.mem.indexOf(u8, code, "if ") != null or
            std.mem.indexOf(u8, code, "typeof ") != null or
            std.mem.indexOf(u8, code, "isinstance") != null or
            std.mem.indexOf(u8, code, "?.") != null; // Optional chaining

        // Check for error handling
        const has_error_handling = std.mem.indexOf(u8, code, "try") != null or
            std.mem.indexOf(u8, code, "catch") != null or
            std.mem.indexOf(u8, code, "except") != null or
            std.mem.indexOf(u8, code, "throw") != null or
            std.mem.indexOf(u8, code, "raise") != null;

        // Check for dangerous patterns
        var dangerous = DangerousPatterns{
            .eval_usage = false,
            .raw_sql = false,
            .unsafe_regex = false,
            .hardcoded_secrets = false,
        };

        // eval() usage
        if (std.mem.indexOf(u8, code, "eval(") != null) {
            dangerous.eval_usage = true;
            security_score -= 30.0;
        }

        // new Function() - similar to eval
        if (std.mem.indexOf(u8, code, "new Function(") != null) {
            dangerous.eval_usage = true;
            security_score -= 25.0;
        }

        // Raw SQL patterns (string concatenation in queries)
        if (std.mem.indexOf(u8, code, "SELECT ") != null or
            std.mem.indexOf(u8, code, "INSERT ") != null or
            std.mem.indexOf(u8, code, "DELETE ") != null)
        {
            if (std.mem.indexOf(u8, code, " + ") != null or
                std.mem.indexOf(u8, code, "f\"") != null or
                std.mem.indexOf(u8, code, "`$") != null)
            {
                dangerous.raw_sql = true;
                security_score -= 25.0;
            }
        }

        // Hardcoded secrets patterns
        if (std.mem.indexOf(u8, code, "password =") != null or
            std.mem.indexOf(u8, code, "api_key =") != null or
            std.mem.indexOf(u8, code, "secret =") != null or
            std.mem.indexOf(u8, code, "PASSWORD =") != null or
            std.mem.indexOf(u8, code, "API_KEY =") != null)
        {
            dangerous.hardcoded_secrets = true;
            security_score -= 20.0;
        }

        // Bonus points for good practices
        if (has_input_validation) security_score = @min(100.0, security_score + 10.0);
        if (has_error_handling) security_score = @min(100.0, security_score + 10.0);

        security_score = @max(0.0, security_score);

        return SecurityScore{
            .score = security_score,
            .has_input_validation = has_input_validation,
            .has_error_handling = has_error_handling,
            .dangerous_patterns = dangerous,
        };
    }
};

test "quality scorer basic test" {
    const allocator = std.testing.allocator;
    var scorer = QualityScorer.init(allocator, "typescript");

    const code =
        \\export function add(a: number, b: number): number {
        \\  if (typeof a !== 'number' || typeof b !== 'number') {
        \\    throw new Error('Invalid arguments');
        \\  }
        \\  return a + b;
        \\}
    ;

    const constraints =
        \\{"function_name": "add", "return_type": "number", "grammar": "function add(a: number, b: number): number"}
    ;

    const result = scorer.score(code, constraints);

    try std.testing.expect(result.overall > 70.0);
    try std.testing.expect(result.security.has_input_validation);
    try std.testing.expect(result.security.has_error_handling);
    try std.testing.expect(!result.security.dangerous_patterns.eval_usage);
}

test "quality scorer security detection" {
    const allocator = std.testing.allocator;
    var scorer = QualityScorer.init(allocator, "typescript");

    const dangerous_code =
        \\function execute(code: string) {
        \\  return eval(code);
        \\}
    ;

    const result = scorer.score(dangerous_code, null);

    try std.testing.expect(result.security.dangerous_patterns.eval_usage);
    try std.testing.expect(result.security.score < 80.0);
}

test "quality scorer comparison" {
    const allocator = std.testing.allocator;
    var scorer = QualityScorer.init(allocator, "typescript");

    const constrained_code =
        \\export function mergeSort(arr: number[]): number[] {
        \\  if (arr.length <= 1) return arr;
        \\  const mid = Math.floor(arr.length / 2);
        \\  const left = mergeSort(arr.slice(0, mid));
        \\  const right = mergeSort(arr.slice(mid));
        \\  return merge(left, right);
        \\}
    ;

    const unconstrained_code =
        \\function sort(a) {
        \\  if (a.length <= 1) return a;
        \\  var m = a.length / 2 | 0;
        \\  return merge(sort(a.slice(0, m)), sort(a.slice(m)));
        \\}
    ;

    const constraints =
        \\{"function_name": "mergeSort", "grammar": "function mergeSort(arr: number[]): number[]"}
    ;

    const comparison = scorer.compare(constrained_code, unconstrained_code, constraints);

    try std.testing.expect(comparison.constrained.constraint_adherence.score > comparison.unconstrained.constraint_adherence.score);
}
