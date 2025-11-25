// Unified extractor interface with hybrid AST+pattern extraction
const std = @import("std");

pub const base = @import("extractors/base.zig");
pub const typescript = @import("extractors/typescript.zig");
pub const python = @import("extractors/python.zig");

const HybridExtractor = @import("hybrid_extractor.zig").HybridExtractor;
const ExtractionStrategy = @import("hybrid_extractor.zig").ExtractionStrategy;

/// Extract structural constraints from source code using hybrid AST+pattern approach
pub fn extract(
    allocator: std.mem.Allocator,
    constraint_allocator: std.mem.Allocator,
    source: []const u8,
    language: []const u8,
) ![]@import("ananke").types.constraint.Constraint {
    // Use tree-sitter with fallback for all supported languages
    const use_hybrid = std.mem.eql(u8, language, "typescript") or
                       std.mem.eql(u8, language, "ts") or
                       std.mem.eql(u8, language, "python") or
                       std.mem.eql(u8, language, "py") or
                       std.mem.eql(u8, language, "rust") or
                       std.mem.eql(u8, language, "rs") or
                       std.mem.eql(u8, language, "go") or
                       std.mem.eql(u8, language, "zig");

    if (use_hybrid) {
        return try extractHybrid(allocator, constraint_allocator, source, language);
    }

    // For unsupported languages, return empty constraints
    return &.{};
}

/// Extract using hybrid approach: combine AST-based and pattern-based extraction
fn extractHybrid(
    allocator: std.mem.Allocator,
    constraint_allocator: std.mem.Allocator,
    source: []const u8,
    language: []const u8,
) ![]@import("ananke").types.constraint.Constraint {
    var all_constraints = std.ArrayList(@import("ananke").types.constraint.Constraint){};
    // Note: constraint strings are allocated with constraint_allocator (arena)
    // On error, the arena will be freed by Clew, so we only need to free the ArrayList
    errdefer all_constraints.deinit(constraint_allocator);

    // 1. Extract AST-based constraints using HybridExtractor
    var hybrid_extractor = HybridExtractor.init(allocator, .tree_sitter_with_fallback);

    // Normalize language name for tree-sitter
    const ts_language = if (std.mem.eql(u8, language, "ts"))
        "typescript"
    else if (std.mem.eql(u8, language, "py"))
        "python"
    else
        language;

    var ast_result = try hybrid_extractor.extract(source, ts_language);
    // Note: ast_result owns its constraint strings (allocated with allocator)
    // We'll transfer ownership by duplicating to constraint_allocator, then clean up originals
    defer {
        // Free the AST constraint strings (allocated with regular allocator)
        for (ast_result.constraints) |constraint| {
            allocator.free(constraint.name);
            allocator.free(constraint.description);
        }
        // Free the constraints slice
        ast_result.deinit(allocator);
    }

    // Add AST constraints to our collection (duplicate strings for ownership)
    for (ast_result.constraints) |ast_constraint| {
        const new_constraint = @import("ananke").types.constraint.Constraint{
            .kind = ast_constraint.kind,
            .severity = ast_constraint.severity,
            .name = try constraint_allocator.dupe(u8, ast_constraint.name),
            .description = try constraint_allocator.dupe(u8, ast_constraint.description),
            .source = ast_constraint.source,
            .confidence = ast_constraint.confidence,
            .frequency = ast_constraint.frequency,
            .origin_line = ast_constraint.origin_line,
        };
        try all_constraints.append(constraint_allocator, new_constraint);
    }

    // 2. Extract pattern-based constraints using existing extractors
    var structure = if (std.mem.eql(u8, language, "typescript") or std.mem.eql(u8, language, "ts"))
        try typescript.parse(allocator, source)
    else if (std.mem.eql(u8, language, "python") or std.mem.eql(u8, language, "py"))
        try python.parse(allocator, source)
    else
        base.SyntaxStructure.init(allocator);

    defer structure.deinit();

    // Convert syntax structure to constraints
    // Note: pattern_constraints are allocated with constraint_allocator (arena)
    // The arena will be freed when Clew.deinit() is called, so we don't manually free
    const pattern_constraints = try structure.toConstraints(constraint_allocator);

    // 3. Merge pattern constraints, avoiding duplicates
    for (pattern_constraints) |pattern_constraint| {
        var is_duplicate = false;

        // Check for duplicates based on name and kind
        for (all_constraints.items) |existing| {
            if (std.mem.eql(u8, existing.name, pattern_constraint.name) and
                existing.kind == pattern_constraint.kind) {
                is_duplicate = true;
                break;
            }
        }

        if (!is_duplicate) {
            // Duplicate the constraint for our collection
            const new_constraint = @import("ananke").types.constraint.Constraint{
                .kind = pattern_constraint.kind,
                .severity = pattern_constraint.severity,
                .name = try constraint_allocator.dupe(u8, pattern_constraint.name),
                .description = try constraint_allocator.dupe(u8, pattern_constraint.description),
                .source = pattern_constraint.source,
                .confidence = pattern_constraint.confidence,
                .frequency = pattern_constraint.frequency,
                .origin_line = pattern_constraint.origin_line,
            };
            try all_constraints.append(constraint_allocator, new_constraint);
        }
    }

    return try all_constraints.toOwnedSlice(constraint_allocator);
}
