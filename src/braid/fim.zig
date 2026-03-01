// Fill-in-the-Middle (FIM) Constrained Decoding
//
// Supports IDE-quality fill-in-the-middle generation with constraint enforcement.
//
// Based on: FIM Constrained Decoding (Ugare et al. 2024)
//   - Left-quotient the syntax grammar by the prefix
//   - Right-quotient by the suffix
//   - The resulting grammar constrains generation to code that is
//     syntactically valid in context, not just in isolation
//
// This module defines the FIM context types and constraint derivation.
// The actual grammar quotienting happens at the sglang backend.
// What we provide is the structured context that enables it.
//
// Data flow:
//   (prefix, suffix, language) → FimContext → constraint derivation
//     → FimConstraintSpec JSON → sglang backend
//     → left/right-quotiented grammar masks per token

const std = @import("std");
const salience = @import("salience.zig");

/// Scale of the hole being filled.
/// Determines constraint intensity (from CLaSH adaptive intensity).
pub const HoleScale = enum {
    /// Single expression (e.g., function argument, return value)
    expression,
    /// One or more statements within a block
    statement,
    /// A full block (if-else, loop body, match arm)
    block,
    /// An entire function body
    function,
    /// A complete type or module section
    module,

    /// Map to appropriate constraint intensity
    pub fn defaultIntensity(self: HoleScale) salience.IntensityLevel {
        return switch (self) {
            .expression => .syntax_only,
            .statement => .standard,
            .block => .standard,
            .function => .full_hard,
            .module => .full,
        };
    }
};

/// Context for a fill-in-the-middle generation request.
pub const FimContext = struct {
    /// Code before the hole (the prefix to left-quotient by)
    prefix: []const u8,
    /// Code after the hole (the suffix to right-quotient by)
    suffix: []const u8,
    /// Language of the source code
    language: []const u8,
    /// Scale of the hole
    hole_scale: HoleScale = .statement,
    /// File path (for scope resolution)
    file_path: ?[]const u8 = null,
    /// Cursor position (line, column) in the original file
    cursor_line: ?u32 = null,
    cursor_column: ?u32 = null,
};

/// Syntactic context derived from analyzing the prefix.
pub const PrefixAnalysis = struct {
    /// Number of unclosed braces/brackets/parens at end of prefix
    open_delimiters: u32 = 0,
    /// Whether the prefix ends mid-expression
    ends_mid_expression: bool = false,
    /// Whether the prefix ends inside a string literal
    ends_in_string: bool = false,
    /// Whether the prefix ends inside a comment
    ends_in_comment: bool = false,
    /// Indentation level at the hole position
    indent_level: u32 = 0,
    /// The indent unit used (spaces or tab)
    indent_char: u8 = ' ',
    /// Number of indent chars per level
    indent_width: u32 = 4,
};

/// Syntactic context derived from analyzing the suffix.
pub const SuffixAnalysis = struct {
    /// Number of close-delimiters at start of suffix (must be matched)
    close_delimiters: u32 = 0,
    /// Whether the suffix starts with a specific token (e.g., '}', ')')
    starts_with: ?[]const u8 = null,
    /// Whether the infill must end with a newline
    requires_trailing_newline: bool = false,
};

/// Constraints derived from FIM context analysis.
pub const FimConstraints = struct {
    /// Prefix analysis results
    prefix: PrefixAnalysis,
    /// Suffix analysis results
    suffix: SuffixAnalysis,
    /// Inferred hole scale
    hole_scale: HoleScale,
    /// Recommended constraint intensity
    intensity: salience.IntensityLevel,
    /// Whether the infill must be a complete syntactic unit
    requires_complete_unit: bool = true,
};

/// Analyze a FIM context to derive constraints.
/// This is a lightweight analysis — the full grammar quotienting
/// happens at the sglang backend.
pub fn analyzeContext(ctx: FimContext) FimConstraints {
    const prefix_analysis = analyzePrefix(ctx.prefix);
    const suffix_analysis = analyzeSuffix(ctx.suffix);

    // If prefix ends in a string or comment, the infill
    // doesn't need to be a complete syntactic unit
    const requires_complete = !prefix_analysis.ends_in_string and
        !prefix_analysis.ends_in_comment;

    return .{
        .prefix = prefix_analysis,
        .suffix = suffix_analysis,
        .hole_scale = ctx.hole_scale,
        .intensity = ctx.hole_scale.defaultIntensity(),
        .requires_complete_unit = requires_complete,
    };
}

/// Analyze the prefix to determine syntactic state at the hole.
fn analyzePrefix(prefix: []const u8) PrefixAnalysis {
    var result = PrefixAnalysis{};
    var open_parens: u32 = 0;
    var open_brackets: u32 = 0;
    var open_braces: u32 = 0;
    var in_string_single = false;
    var in_string_double = false;
    var in_line_comment = false;
    var prev_char: u8 = 0;

    // Track indentation from the last line
    var current_indent: u32 = 0;
    var counting_indent = true;
    var indent_char: u8 = ' ';

    for (prefix) |c| {
        if (c == '\n') {
            in_line_comment = false;
            current_indent = 0;
            counting_indent = true;
            prev_char = c;
            continue;
        }

        if (counting_indent) {
            if (c == ' ' or c == '\t') {
                if (current_indent == 0) indent_char = c;
                current_indent += 1;
            } else {
                counting_indent = false;
            }
        }

        if (in_line_comment) {
            prev_char = c;
            continue;
        }

        // Track string state
        if (c == '\'' and !in_string_double and prev_char != '\\') {
            in_string_single = !in_string_single;
        } else if (c == '"' and !in_string_single and prev_char != '\\') {
            in_string_double = !in_string_double;
        }

        if (in_string_single or in_string_double) {
            prev_char = c;
            continue;
        }

        // Track comment state
        if (c == '/' and prev_char == '/') {
            in_line_comment = true;
            prev_char = c;
            continue;
        }

        // Track delimiter balance
        switch (c) {
            '(' => open_parens += 1,
            ')' => if (open_parens > 0) {
                open_parens -= 1;
            },
            '[' => open_brackets += 1,
            ']' => if (open_brackets > 0) {
                open_brackets -= 1;
            },
            '{' => open_braces += 1,
            '}' => if (open_braces > 0) {
                open_braces -= 1;
            },
            else => {},
        }

        prev_char = c;
    }

    result.open_delimiters = open_parens + open_brackets + open_braces;
    result.ends_in_string = in_string_single or in_string_double;
    result.ends_in_comment = in_line_comment;
    result.ends_mid_expression = open_parens > 0 or open_brackets > 0;
    result.indent_level = current_indent;
    result.indent_char = indent_char;

    return result;
}

/// Analyze the suffix to determine what constraints the infill must satisfy.
fn analyzeSuffix(suffix: []const u8) SuffixAnalysis {
    var result = SuffixAnalysis{};

    // Find the first non-whitespace content
    var first_nonws: ?usize = null;
    for (suffix, 0..) |c, i| {
        if (c != ' ' and c != '\t' and c != '\n' and c != '\r') {
            first_nonws = i;
            break;
        }
    }

    if (first_nonws) |idx| {
        // Count leading close delimiters
        var close_count: u32 = 0;
        var pos = idx;
        while (pos < suffix.len) {
            const c = suffix[pos];
            if (c == ')' or c == ']' or c == '}') {
                close_count += 1;
                pos += 1;
            } else {
                break;
            }
        }
        result.close_delimiters = close_count;

        // Set starts_with for the first token
        if (idx < suffix.len) {
            // Find end of first token (up to next whitespace or end)
            var end = idx + 1;
            while (end < suffix.len and
                suffix[end] != ' ' and
                suffix[end] != '\t' and
                suffix[end] != '\n')
            {
                end += 1;
            }
            result.starts_with = suffix[idx..end];
        }
    }

    // Check if infill needs trailing newline
    if (suffix.len > 0 and suffix[0] == '\n') {
        result.requires_trailing_newline = true;
    }

    return result;
}

/// Serialize FIM constraints to JSON for the sglang constraint_spec.
pub fn serializeToJson(
    allocator: std.mem.Allocator,
    ctx: FimContext,
    constraints: FimConstraints,
) ![]u8 {
    var buf = std.ArrayList(u8){};
    errdefer buf.deinit(allocator);
    const writer = buf.writer(allocator);

    try writer.writeAll("{");

    // FIM mode indicator
    try writer.writeAll("\"mode\": \"fim\"");

    // Language
    try writer.print(", \"language\": \"{s}\"", .{ctx.language});

    // Hole scale and intensity
    try writer.print(", \"hole_scale\": \"{s}\"", .{@tagName(constraints.hole_scale)});
    try writer.print(", \"intensity\": \"{s}\"", .{@tagName(constraints.intensity)});

    // Prefix/suffix lengths (not the actual content — that goes in the prompt)
    try writer.print(", \"prefix_length\": {d}", .{ctx.prefix.len});
    try writer.print(", \"suffix_length\": {d}", .{ctx.suffix.len});

    // Syntactic context
    try writer.print(", \"open_delimiters\": {d}", .{constraints.prefix.open_delimiters});
    try writer.print(", \"close_delimiters\": {d}", .{constraints.suffix.close_delimiters});
    try writer.print(", \"indent_level\": {d}", .{constraints.prefix.indent_level});
    try writer.print(", \"requires_complete_unit\": {}", .{constraints.requires_complete_unit});
    try writer.print(", \"ends_mid_expression\": {}", .{constraints.prefix.ends_mid_expression});

    // File context
    if (ctx.file_path) |fp| {
        try writer.print(", \"file_path\": \"{s}\"", .{fp});
    }
    if (ctx.cursor_line) |line| {
        try writer.print(", \"cursor_line\": {d}", .{line});
    }

    try writer.writeAll("}");

    return try buf.toOwnedSlice(allocator);
}

// ---------- Tests ----------

test "hole scale to intensity mapping" {
    try std.testing.expectEqual(salience.IntensityLevel.syntax_only, HoleScale.expression.defaultIntensity());
    try std.testing.expectEqual(salience.IntensityLevel.standard, HoleScale.statement.defaultIntensity());
    try std.testing.expectEqual(salience.IntensityLevel.full_hard, HoleScale.function.defaultIntensity());
    try std.testing.expectEqual(salience.IntensityLevel.full, HoleScale.module.defaultIntensity());
}

test "prefix analysis: balanced delimiters" {
    const result = analyzePrefix("function foo() {\n    if (x) {\n        ");
    try std.testing.expectEqual(@as(u32, 2), result.open_delimiters);
    try std.testing.expect(!result.ends_in_string);
    try std.testing.expect(!result.ends_in_comment);
}

test "prefix analysis: mid-expression" {
    const result = analyzePrefix("const x = foo(bar, ");
    try std.testing.expect(result.ends_mid_expression);
    try std.testing.expectEqual(@as(u32, 1), result.open_delimiters);
}

test "prefix analysis: string context" {
    const result = analyzePrefix("const msg = \"hello ");
    try std.testing.expect(result.ends_in_string);
}

test "prefix analysis: comment context" {
    const result = analyzePrefix("// TODO: implement ");
    try std.testing.expect(result.ends_in_comment);
}

test "prefix analysis: indentation tracking" {
    const result = analyzePrefix("function foo() {\n    return ");
    try std.testing.expectEqual(@as(u32, 4), result.indent_level);
    try std.testing.expectEqual(@as(u8, ' '), result.indent_char);
}

test "suffix analysis: close delimiters" {
    const result = analyzeSuffix("}\n}");
    try std.testing.expectEqual(@as(u32, 1), result.close_delimiters);
    try std.testing.expect(result.starts_with != null);
}

test "suffix analysis: trailing newline" {
    const result = analyzeSuffix("\n    return null;");
    try std.testing.expect(result.requires_trailing_newline);
}

test "suffix analysis: empty suffix" {
    const result = analyzeSuffix("");
    try std.testing.expectEqual(@as(u32, 0), result.close_delimiters);
    try std.testing.expect(result.starts_with == null);
}

test "full FIM analysis" {
    const ctx = FimContext{
        .prefix = "function validate(input: string): boolean {\n    ",
        .suffix = "\n    return true;\n}",
        .language = "typescript",
        .hole_scale = .statement,
        .file_path = "src/validators.ts",
        .cursor_line = 5,
    };

    const constraints = analyzeContext(ctx);
    try std.testing.expectEqual(HoleScale.statement, constraints.hole_scale);
    try std.testing.expectEqual(salience.IntensityLevel.standard, constraints.intensity);
    try std.testing.expect(constraints.requires_complete_unit);
    try std.testing.expectEqual(@as(u32, 1), constraints.prefix.open_delimiters);
}

test "FIM analysis: string context disables complete unit requirement" {
    const ctx = FimContext{
        .prefix = "const msg = \"hello ",
        .suffix = " world\";",
        .language = "javascript",
        .hole_scale = .expression,
    };

    const constraints = analyzeContext(ctx);
    try std.testing.expect(!constraints.requires_complete_unit);
}

test "FIM serialization" {
    const ctx = FimContext{
        .prefix = "fn foo() {\n    ",
        .suffix = "\n}",
        .language = "zig",
        .hole_scale = .block,
        .file_path = "src/main.zig",
        .cursor_line = 10,
    };

    const constraints = analyzeContext(ctx);
    const json = try serializeToJson(std.testing.allocator, ctx, constraints);
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"mode\": \"fim\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"language\": \"zig\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"hole_scale\": \"block\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"file_path\": \"src/main.zig\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"cursor_line\": 10") != null);
}
