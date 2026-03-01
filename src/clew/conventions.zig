// Convention Mining → Soft Constraints
//
// Transforms Homer's empirically derived coding conventions into
// soft-tier constraints that guide generation without blocking it.
//
// Convention sources (from Homer's convention analysis):
//   - Naming patterns → regex patterns (Syntax domain enrichment)
//   - Import ordering → ImportDomain ordering rules
//   - Error handling → ControlFlow soft constraints
//   - Documentation style → Semantics soft constraints
//
// CLaSH invariant: All convention-derived constraints are ALWAYS soft-tier.
// They reweight the distribution within the feasible set defined by hard
// constraints. They never cause generation failure.

const std = @import("std");

/// A coding convention empirically derived from repository analysis.
pub const Convention = struct {
    /// Category of the convention
    kind: ConventionKind,
    /// Human-readable description
    description: []const u8,
    /// Confidence that this convention is real (0.0–1.0)
    /// Based on how consistently the pattern appears in the codebase.
    confidence: f32,
    /// Number of instances supporting this convention
    support_count: u32,
    /// Regex pattern for naming conventions (only for .naming kind)
    pattern: ?[]const u8 = null,
    /// Style value for import/error/doc conventions
    style: ?[]const u8 = null,
};

/// Categories of conventions that Homer can detect.
pub const ConventionKind = enum {
    /// Naming patterns (camelCase, snake_case, prefixes, suffixes)
    naming,
    /// Import organization (grouping, ordering, alias patterns)
    import_ordering,
    /// Error handling patterns (try/catch style, Result types, error codes)
    error_handling,
    /// Documentation style (docstring format, comment conventions)
    documentation,
    /// Code organization (file structure, module patterns)
    code_organization,
};

/// Result of convention analysis for a file or module.
pub const ConventionSet = struct {
    /// Language of the analyzed code
    language: []const u8,
    /// All detected conventions
    conventions: []const Convention,
    /// Overall convention adherence in the codebase (0.0–1.0)
    adherence_score: f32,
};

/// A soft constraint derived from a convention.
/// These are always soft-tier (CLaSH invariant).
pub const SoftConstraint = struct {
    /// Which CLaSH domain this constraint belongs to
    domain: SoftDomain,
    /// Human-readable description of the constraint
    description: []const u8,
    /// Weight for distribution reweighting (0.0–1.0)
    /// Higher = stronger preference. Never blocks — only biases.
    weight: f32,
    /// Regex pattern (for naming conventions)
    pattern: ?[]const u8 = null,
    /// Style identifier (for error handling, imports)
    style: ?[]const u8 = null,
};

/// CLaSH soft-tier domains that conventions can target.
pub const SoftDomain = enum {
    /// ControlFlow domain (error handling patterns, async/await, loop structure)
    control_flow,
    /// Semantics domain (behavioral intent, documentation expectations)
    semantics,
    /// Syntax domain enrichment (naming conventions as soft guidance)
    syntax_guidance,
};

/// Convert conventions into soft constraints.
/// Respects the CLaSH invariant: all outputs are soft-tier.
pub fn toSoftConstraints(
    allocator: std.mem.Allocator,
    conventions: []const Convention,
) ![]SoftConstraint {
    var constraints = std.ArrayList(SoftConstraint){};

    for (conventions) |conv| {
        // Only convert high-confidence conventions (>= 0.6)
        if (conv.confidence < 0.6) continue;

        const sc = switch (conv.kind) {
            .naming => SoftConstraint{
                .domain = .syntax_guidance,
                .description = conv.description,
                .weight = conv.confidence * 0.7, // Naming is suggestive, not critical
                .pattern = conv.pattern,
            },
            .import_ordering => SoftConstraint{
                .domain = .syntax_guidance,
                .description = conv.description,
                .weight = conv.confidence * 0.5, // Import ordering is cosmetic
                .style = conv.style,
            },
            .error_handling => SoftConstraint{
                .domain = .control_flow,
                .description = conv.description,
                .weight = conv.confidence * 0.8, // Error handling conventions matter
                .style = conv.style,
            },
            .documentation => SoftConstraint{
                .domain = .semantics,
                .description = conv.description,
                .weight = conv.confidence * 0.4, // Doc style is least critical
                .style = conv.style,
            },
            .code_organization => SoftConstraint{
                .domain = .semantics,
                .description = conv.description,
                .weight = conv.confidence * 0.6,
                .style = conv.style,
            },
        };

        try constraints.append(allocator, sc);
    }

    return try constraints.toOwnedSlice(allocator);
}

/// Serialize soft constraints to JSON for inclusion in RichContext.
/// Output format matches ConstraintSpec's semantic_constraints field.
pub fn serializeToJson(
    allocator: std.mem.Allocator,
    constraints: []const SoftConstraint,
) ![]u8 {
    var buf = std.ArrayList(u8){};
    const writer = buf.writer(allocator);

    try writer.writeAll("[");
    for (constraints, 0..) |sc, i| {
        try writer.writeAll("{");
        try writer.print("\"domain\": \"{s}\"", .{@tagName(sc.domain)});
        try writer.print(", \"description\": \"{s}\"", .{sc.description});
        try writer.print(", \"weight\": {d:.2}", .{sc.weight});
        try writer.writeAll(", \"tier\": \"soft\""); // CLaSH invariant
        if (sc.pattern) |p| {
            try writer.print(", \"pattern\": \"{s}\"", .{p});
        }
        if (sc.style) |s| {
            try writer.print(", \"style\": \"{s}\"", .{s});
        }
        try writer.writeAll("}");
        if (i + 1 < constraints.len) try writer.writeAll(", ");
    }
    try writer.writeAll("]");

    return try buf.toOwnedSlice(allocator);
}

/// Filter conventions relevant to a specific language.
pub fn filterByLanguage(
    conventions: []const Convention,
    language: []const u8,
    convention_set_language: []const u8,
) bool {
    // If the convention set is for the same language, all conventions apply
    _ = conventions;
    return std.mem.eql(u8, language, convention_set_language);
}

// ---------- Tests ----------

test "convert naming convention to soft constraint" {
    const conventions = [_]Convention{
        .{
            .kind = .naming,
            .description = "Functions use camelCase",
            .confidence = 0.9,
            .support_count = 150,
            .pattern = "^[a-z][a-zA-Z0-9]*$",
        },
    };

    const constraints = try toSoftConstraints(std.testing.allocator, &conventions);
    defer std.testing.allocator.free(constraints);

    try std.testing.expect(constraints.len == 1);
    try std.testing.expectEqual(SoftDomain.syntax_guidance, constraints[0].domain);
    try std.testing.expect(constraints[0].weight > 0.0);
    try std.testing.expect(constraints[0].weight <= 1.0);
    try std.testing.expect(constraints[0].pattern != null);
}

test "error handling convention gets higher weight" {
    const conventions = [_]Convention{
        .{
            .kind = .naming,
            .description = "Functions use camelCase",
            .confidence = 0.9,
            .support_count = 150,
            .pattern = "^[a-z][a-zA-Z0-9]*$",
        },
        .{
            .kind = .error_handling,
            .description = "Use Result types for error handling",
            .confidence = 0.9,
            .support_count = 80,
            .style = "result_based",
        },
    };

    const constraints = try toSoftConstraints(std.testing.allocator, &conventions);
    defer std.testing.allocator.free(constraints);

    try std.testing.expect(constraints.len == 2);
    // Error handling (0.9 * 0.8 = 0.72) > naming (0.9 * 0.7 = 0.63)
    try std.testing.expect(constraints[1].weight > constraints[0].weight);
}

test "low confidence conventions are filtered out" {
    const conventions = [_]Convention{
        .{
            .kind = .naming,
            .description = "Uncertain pattern",
            .confidence = 0.3, // Below 0.6 threshold
            .support_count = 5,
        },
        .{
            .kind = .naming,
            .description = "Confident pattern",
            .confidence = 0.8,
            .support_count = 100,
            .pattern = "^[A-Z][a-zA-Z]*$",
        },
    };

    const constraints = try toSoftConstraints(std.testing.allocator, &conventions);
    defer std.testing.allocator.free(constraints);

    try std.testing.expect(constraints.len == 1);
    try std.testing.expect(std.mem.eql(u8, constraints[0].description, "Confident pattern"));
}

test "serialization includes soft tier" {
    const constraints = [_]SoftConstraint{
        .{
            .domain = .control_flow,
            .description = "Use Result types",
            .weight = 0.72,
            .style = "result_based",
        },
    };

    const json = try serializeToJson(std.testing.allocator, &constraints);
    defer std.testing.allocator.free(json);

    // Verify CLaSH invariant: tier is always "soft"
    try std.testing.expect(std.mem.indexOf(u8, json, "\"tier\": \"soft\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"domain\": \"control_flow\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"style\": \"result_based\"") != null);
}

test "empty conventions produce empty constraints" {
    const constraints = try toSoftConstraints(std.testing.allocator, &.{});
    defer std.testing.allocator.free(constraints);
    try std.testing.expect(constraints.len == 0);
}
