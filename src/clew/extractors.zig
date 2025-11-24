// Unified extractor interface
const std = @import("std");

pub const base = @import("extractors/base.zig");
pub const typescript = @import("extractors/typescript.zig");
pub const python = @import("extractors/python.zig");

/// Extract structural constraints from source code
pub fn extract(
    allocator: std.mem.Allocator,
    constraint_allocator: std.mem.Allocator,
    source: []const u8,
    language: []const u8,
) ![]@import("ananke").types.constraint.Constraint {
    // Parse source into syntax structure based on language
    var structure = if (std.mem.eql(u8, language, "typescript") or std.mem.eql(u8, language, "ts"))
        try typescript.parse(allocator, source)
    else if (std.mem.eql(u8, language, "python") or std.mem.eql(u8, language, "py"))
        try python.parse(allocator, source)
    else if (std.mem.eql(u8, language, "rust") or std.mem.eql(u8, language, "rs"))
        // Fallback to pattern matching for Rust until extractor is implemented
        return &.{}
    else if (std.mem.eql(u8, language, "zig"))
        // Fallback to pattern matching for Zig until extractor is implemented
        return &.{}
    else if (std.mem.eql(u8, language, "go"))
        // Fallback to pattern matching for Go until extractor is implemented
        return &.{}
    else
        return &.{};
    
    defer structure.deinit();
    
    // Convert syntax structure to constraints
    return try structure.toConstraints(constraint_allocator);
}
