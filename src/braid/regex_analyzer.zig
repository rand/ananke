// Regex Pathology Analyzer
// Detects problematic regex patterns that can cause catastrophic backtracking,
// excessive DFA state explosion, or trivial matches.
const std = @import("std");

/// Types of pathological patterns that can cause performance issues
pub const PathologyType = enum {
    /// (a|a)*b patterns - nested quantifiers on overlapping alternatives
    catastrophic_backtracking,
    /// .*, \w*, empty-matching patterns - match trivially/immediately
    trivial_match,
    /// Results in DFA state explosion (>10k states)
    exponential_states,
    /// a|ab|abc - overlapping prefixes in alternatives
    ambiguous_alternatives,
    /// Pattern is likely to cause slow generation due to tight constraints
    overly_restrictive,
};

/// Result of analyzing a regex pattern for potential issues
pub const AnalysisResult = struct {
    is_safe: bool,
    pathologies: []PathologyType,
    estimated_dfa_states: usize,
    complexity_class: ComplexityClass,
    recommendation: []const u8,
    confidence: f32, // 0.0 to 1.0
};

pub const ComplexityClass = enum {
    linear, // O(n) - safe
    polynomial, // O(n^k) - may be slow for long inputs
    exponential, // O(2^n) - dangerous, likely to timeout
};

/// Regex pattern analyzer for detecting pathological patterns
pub const RegexAnalyzer = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) RegexAnalyzer {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *RegexAnalyzer) void {
        _ = self;
    }

    /// Analyze a regex pattern for potential issues
    pub fn analyze(self: *RegexAnalyzer, pattern: []const u8) AnalysisResult {
        var pathologies_buf: [8]PathologyType = undefined;
        var pathology_count: usize = 0;

        var result = AnalysisResult{
            .is_safe = true,
            .pathologies = &.{},
            .estimated_dfa_states = 1,
            .complexity_class = .linear,
            .recommendation = "",
            .confidence = 0.9,
        };

        // Check for empty or trivial patterns
        if (pattern.len == 0) {
            result.is_safe = false;
            result.recommendation = "Empty pattern matches nothing";
            return result;
        }

        // Check for catastrophic backtracking patterns
        if (self.hasCatastrophicBacktracking(pattern)) {
            result.is_safe = false;
            result.complexity_class = .exponential;
            if (pathology_count < pathologies_buf.len) {
                pathologies_buf[pathology_count] = .catastrophic_backtracking;
                pathology_count += 1;
            }
            result.recommendation = "Pattern may cause catastrophic backtracking";
        }

        // Check for trivial match patterns
        if (self.isTrivialPattern(pattern)) {
            result.is_safe = false;
            if (pathology_count < pathologies_buf.len) {
                pathologies_buf[pathology_count] = .trivial_match;
                pathology_count += 1;
            }
            result.recommendation = "Pattern matches too easily (trivial)";
        }

        // Check for ambiguous alternatives
        if (self.hasAmbiguousAlternatives(pattern)) {
            if (pathology_count < pathologies_buf.len) {
                pathologies_buf[pathology_count] = .ambiguous_alternatives;
                pathology_count += 1;
            }
            // Upgrade complexity to at least polynomial
            if (@intFromEnum(ComplexityClass.polynomial) > @intFromEnum(result.complexity_class)) {
                result.complexity_class = .polynomial;
            }
            result.recommendation = "Pattern has ambiguous alternatives that may slow matching";
        }

        // Estimate DFA state count
        result.estimated_dfa_states = self.estimateDFAStates(pattern);
        if (result.estimated_dfa_states > 10000) {
            result.is_safe = false;
            result.complexity_class = .exponential;
            if (pathology_count < pathologies_buf.len) {
                pathologies_buf[pathology_count] = .exponential_states;
                pathology_count += 1;
            }
            result.recommendation = "Pattern may cause DFA state explosion";
        } else if (result.estimated_dfa_states > 1000) {
            // Upgrade complexity to at least polynomial
            if (@intFromEnum(ComplexityClass.polynomial) > @intFromEnum(result.complexity_class)) {
                result.complexity_class = .polynomial;
            }
        }

        // Check for overly restrictive patterns
        if (self.isOverlyRestrictive(pattern)) {
            if (pathology_count < pathologies_buf.len) {
                pathologies_buf[pathology_count] = .overly_restrictive;
                pathology_count += 1;
            }
            result.confidence = 0.7; // Lower confidence in pattern quality
        }

        // Store pathologies slice
        result.pathologies = pathologies_buf[0..pathology_count];

        return result;
    }

    /// Check if pattern is trivial (matches almost anything or nothing useful)
    pub fn isTrivialPattern(self: *RegexAnalyzer, pattern: []const u8) bool {
        _ = self;

        // Patterns that match too easily
        const trivial_patterns = [_][]const u8{
            ".*", // Matches anything (including empty)
            ".+", // Matches any non-empty
            "\\w*", // Matches words or empty
            "\\W*", // Matches non-words or empty
            "\\s*", // Matches whitespace or empty
            "\\S*", // Matches non-whitespace or empty
            "[a-z]*", // Matches lowercase or empty
            "[A-Z]*", // Matches uppercase or empty
            "[a-zA-Z]*", // Matches letters or empty
            "[0-9]*", // Matches digits or empty
            "\\d*", // Matches digits or empty
            "^$", // Matches only empty string
            "^.*$", // Matches any single line
            ".{0,}", // Same as .*
        };

        for (trivial_patterns) |trivial| {
            if (std.mem.eql(u8, pattern, trivial)) return true;
        }

        // Also check if pattern is just a quantifier without anchor
        if (pattern.len >= 1 and pattern[pattern.len - 1] == '*') {
            // Pattern ending in * with no anchors is likely to match trivially
            const has_start_anchor = pattern.len > 0 and pattern[0] == '^';
            const has_end_anchor = pattern.len > 1 and std.mem.endsWith(u8, pattern, "$");
            if (!has_start_anchor and !has_end_anchor) {
                // No anchors - could match at any position
                return true;
            }
        }

        return false;
    }

    /// Check for catastrophic backtracking patterns
    fn hasCatastrophicBacktracking(self: *RegexAnalyzer, pattern: []const u8) bool {
        _ = self;

        // Known dangerous patterns that cause exponential backtracking
        const dangerous_patterns = [_][]const u8{
            "(.*)+", // Nested quantifiers on greedy match
            "(.+)+", // Nested quantifiers
            "(\\w*)*", // Nested word quantifiers
            "(a|a)*", // Alternation of identical patterns
            "(.*?)+", // Nested non-greedy
            "(.+?)+", // Nested non-greedy
            "(a+)+", // Nested plus quantifiers
            "([a-z]+)+", // Character class with nested quantifiers
            "(\\d+)+", // Digit with nested quantifiers
            ".*.*.*", // Multiple greedy quantifiers
            ".+.+.+", // Multiple greedy plus
            "(x+x+)+", // Classic ReDoS pattern
            "([^\\n]+)+", // Negated class with nested quantifier
        };

        for (dangerous_patterns) |dangerous| {
            if (std.mem.indexOf(u8, pattern, dangerous) != null) return true;
        }

        // Heuristic: count nested quantifiers
        var nested_depth: u32 = 0;
        var max_nested_depth: u32 = 0;
        var in_group: bool = false;

        for (pattern) |c| {
            if (c == '(') {
                in_group = true;
                nested_depth += 1;
            } else if (c == ')') {
                if (nested_depth > 0) nested_depth -= 1;
                in_group = false;
            } else if ((c == '*' or c == '+' or c == '?') and in_group) {
                max_nested_depth = @max(max_nested_depth, nested_depth);
            }
        }

        // More than 2 levels of nested quantifiers is dangerous
        return max_nested_depth > 2;
    }

    /// Check for ambiguous alternatives (overlapping prefixes)
    fn hasAmbiguousAlternatives(self: *RegexAnalyzer, pattern: []const u8) bool {
        _ = self;

        // Find alternatives separated by |
        var alt_start: usize = 0;
        var alternatives: [32][]const u8 = undefined;
        var alt_count: usize = 0;
        var paren_depth: u32 = 0;

        for (pattern, 0..) |c, i| {
            if (c == '(') {
                paren_depth += 1;
            } else if (c == ')') {
                if (paren_depth > 0) paren_depth -= 1;
            } else if (c == '|' and paren_depth == 0) {
                if (alt_count < alternatives.len) {
                    alternatives[alt_count] = pattern[alt_start..i];
                    alt_count += 1;
                }
                alt_start = i + 1;
            }
        }

        // Add last alternative
        if (alt_count < alternatives.len and alt_start < pattern.len) {
            alternatives[alt_count] = pattern[alt_start..];
            alt_count += 1;
        }

        // Check for overlapping prefixes
        if (alt_count > 1) {
            for (0..alt_count) |i| {
                for (i + 1..alt_count) |j| {
                    const a = alternatives[i];
                    const b = alternatives[j];

                    // Check if one is prefix of another
                    if (a.len > 0 and b.len > 0) {
                        const min_len = @min(a.len, b.len);
                        const common_prefix = std.mem.eql(u8, a[0..min_len], b[0..min_len]);
                        if (common_prefix) {
                            return true;
                        }
                    }
                }
            }
        }

        return false;
    }

    /// Estimate number of DFA states (heuristic)
    fn estimateDFAStates(self: *RegexAnalyzer, pattern: []const u8) usize {
        _ = self;

        var count: usize = 1;
        var char_class_size: usize = 0;
        var in_char_class = false;

        for (pattern) |c| {
            if (c == '[') {
                in_char_class = true;
                char_class_size = 0;
            } else if (c == ']') {
                in_char_class = false;
                count += char_class_size;
            } else if (in_char_class) {
                char_class_size += 1;
            } else if (c == '|') {
                count *= 2; // Alternations can double states
            } else if (c == '*') {
                count *= 2; // Kleene star adds loop states
            } else if (c == '+') {
                count += 1; // Plus adds one state
            } else if (c == '?') {
                count += 1; // Optional adds one state
            } else if (c == '(') {
                count += 1; // Groups add states
            } else if (c == '.') {
                count += 256; // Dot matches any character
            } else {
                count += 1;
            }
        }

        // Cap at reasonable maximum
        return @min(count, 1000000);
    }

    /// Check if pattern is overly restrictive (may never match)
    fn isOverlyRestrictive(self: *RegexAnalyzer, pattern: []const u8) bool {
        _ = self;

        // Count constraints
        var anchor_count: u32 = 0;
        var lookahead_count: u32 = 0;
        var negation_count: u32 = 0;

        var i: usize = 0;
        while (i < pattern.len) : (i += 1) {
            const c = pattern[i];
            if (c == '^' or c == '$') anchor_count += 1;
            if (c == '(' and i + 1 < pattern.len and pattern[i + 1] == '?') {
                if (i + 2 < pattern.len and (pattern[i + 2] == '=' or pattern[i + 2] == '!')) {
                    lookahead_count += 1;
                }
            }
            if (c == '[' and i + 1 < pattern.len and pattern[i + 1] == '^') {
                negation_count += 1;
            }
        }

        // Too many constraints suggests overly restrictive pattern
        return (anchor_count > 4) or (lookahead_count > 2) or (negation_count > 3);
    }

    /// Suggest a safer alternative for problematic patterns
    pub fn suggestSaferAlternative(self: *RegexAnalyzer, pattern: []const u8) ?[]const u8 {
        _ = self;

        // Common problematic patterns and their safer alternatives
        if (std.mem.eql(u8, pattern, ".*")) {
            return "[\\s\\S]*"; // More explicit but same meaning
        }
        if (std.mem.eql(u8, pattern, "(.*)+")) {
            return ".*"; // Remove nested quantifier
        }
        if (std.mem.eql(u8, pattern, "(.+)+")) {
            return ".+"; // Remove nested quantifier
        }

        return null;
    }
};

/// Analyze a pattern and log warnings if problematic
pub fn analyzeAndWarn(allocator: std.mem.Allocator, pattern: []const u8) AnalysisResult {
    var analyzer = RegexAnalyzer.init(allocator);
    defer analyzer.deinit();

    const result = analyzer.analyze(pattern);

    if (!result.is_safe) {
        std.log.warn("Regex pathology detected in pattern: {s}", .{pattern});
        std.log.warn("  Recommendation: {s}", .{result.recommendation});
        std.log.warn("  Estimated DFA states: {d}", .{result.estimated_dfa_states});
        std.log.warn("  Complexity class: {s}", .{@tagName(result.complexity_class)});
    }

    return result;
}

test "trivial patterns" {
    var analyzer = RegexAnalyzer.init(std.testing.allocator);
    defer analyzer.deinit();

    try std.testing.expect(analyzer.isTrivialPattern(".*"));
    try std.testing.expect(analyzer.isTrivialPattern(".+"));
    try std.testing.expect(analyzer.isTrivialPattern("\\w*"));
    try std.testing.expect(analyzer.isTrivialPattern("^$"));
    try std.testing.expect(!analyzer.isTrivialPattern("function\\s+\\w+"));
}

test "catastrophic backtracking" {
    var analyzer = RegexAnalyzer.init(std.testing.allocator);
    defer analyzer.deinit();

    const result1 = analyzer.analyze("(.*)+");
    try std.testing.expect(!result1.is_safe);
    try std.testing.expect(result1.complexity_class == .exponential);

    const result2 = analyzer.analyze("(x+x+)+");
    try std.testing.expect(!result2.is_safe);

    const result3 = analyzer.analyze("function\\s+\\w+");
    try std.testing.expect(result3.is_safe);
}

test "DFA state estimation" {
    var analyzer = RegexAnalyzer.init(std.testing.allocator);
    defer analyzer.deinit();

    const simple_states = analyzer.estimateDFAStates("abc");
    try std.testing.expect(simple_states < 10);

    const alternation_states = analyzer.estimateDFAStates("a|b|c|d");
    try std.testing.expect(alternation_states > simple_states);

    const dot_states = analyzer.estimateDFAStates(".*");
    try std.testing.expect(dot_states > 256); // At least one dot
}
