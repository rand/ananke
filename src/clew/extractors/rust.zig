// Rust extractor using line-by-line parsing
const std = @import("std");
const base = @import("base.zig");

pub fn parse(allocator: std.mem.Allocator, source: []const u8) !base.SyntaxStructure {
    var structure = base.SyntaxStructure.init(allocator);
    errdefer structure.deinit();

    var line_num: u32 = 1;
    var lines = std.mem.splitScalar(u8, source, '\n');

    while (lines.next()) |line| : (line_num += 1) {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0 or std.mem.startsWith(u8, trimmed, "//")) continue;

        // Parse use statements
        if (std.mem.startsWith(u8, trimmed, "use ")) {
            if (try parseUse(allocator, trimmed, line_num)) |import_decl| {
                try structure.imports.append(allocator, import_decl);
            }
        }
        // Parse extern crate
        else if (std.mem.startsWith(u8, trimmed, "extern crate ")) {
            if (try parseExternCrate(allocator, trimmed, line_num)) |import_decl| {
                try structure.imports.append(allocator, import_decl);
            }
        }
        // Parse struct definitions
        else if (std.mem.indexOf(u8, trimmed, "struct ") != null) {
            if (try parseStruct(allocator, trimmed, line_num)) |type_decl| {
                try structure.types.append(allocator, type_decl);
            }
        }
        // Parse enum definitions
        else if (std.mem.indexOf(u8, trimmed, "enum ") != null) {
            if (try parseEnum(allocator, trimmed, line_num)) |type_decl| {
                try structure.types.append(allocator, type_decl);
            }
        }
        // Parse trait definitions
        else if (std.mem.indexOf(u8, trimmed, "trait ") != null) {
            if (try parseTrait(allocator, trimmed, line_num)) |type_decl| {
                try structure.types.append(allocator, type_decl);
            }
        }
        // Parse functions (fn, async fn, pub fn, pub async fn)
        else if (std.mem.indexOf(u8, trimmed, "fn ") != null) {
            if (try parseFunction(allocator, trimmed, line_num)) |func_decl| {
                try structure.functions.append(allocator, func_decl);
            }
        }
    }

    return structure;
}

fn parseUse(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.ImportDecl {
    if (!std.mem.startsWith(u8, line, "use ")) return null;

    const name_start: usize = 4;
    var name_end = name_start;

    // Find end of path (until ; or {)
    while (name_end < line.len and line[name_end] != ';' and line[name_end] != '{' and line[name_end] != '\n') {
        name_end += 1;
    }

    if (name_end <= name_start) return null;

    const module_name = std.mem.trim(u8, line[name_start..name_end], " \t");
    if (module_name.len == 0) return null;

    const is_wildcard = std.mem.indexOf(u8, module_name, "::*") != null;

    return base.ImportDecl{
        .module = try allocator.dupe(u8, module_name),
        .line = line_num,
        .is_wildcard = is_wildcard,
        .items = &.{},
    };
}

fn parseExternCrate(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.ImportDecl {
    if (!std.mem.startsWith(u8, line, "extern crate ")) return null;

    const name_start: usize = 13;
    var name_end = name_start;

    while (name_end < line.len and (std.ascii.isAlphanumeric(line[name_end]) or line[name_end] == '_')) {
        name_end += 1;
    }

    if (name_end <= name_start) return null;

    return base.ImportDecl{
        .module = try allocator.dupe(u8, line[name_start..name_end]),
        .line = line_num,
        .items = &.{},
    };
}

fn parseStruct(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.TypeDecl {
    const struct_pos = std.mem.indexOf(u8, line, "struct ") orelse return null;
    const name_start = struct_pos + 7;

    var name_end = name_start;
    while (name_end < line.len and (std.ascii.isAlphanumeric(line[name_end]) or line[name_end] == '_')) {
        name_end += 1;
    }

    if (name_end <= name_start) return null;

    return base.TypeDecl{
        .name = try allocator.dupe(u8, line[name_start..name_end]),
        .line = line_num,
        .kind = .struct_type,
    };
}

fn parseEnum(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.TypeDecl {
    const enum_pos = std.mem.indexOf(u8, line, "enum ") orelse return null;
    const name_start = enum_pos + 5;

    var name_end = name_start;
    while (name_end < line.len and (std.ascii.isAlphanumeric(line[name_end]) or line[name_end] == '_')) {
        name_end += 1;
    }

    if (name_end <= name_start) return null;

    return base.TypeDecl{
        .name = try allocator.dupe(u8, line[name_start..name_end]),
        .line = line_num,
        .kind = .enum_type,
    };
}

fn parseTrait(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.TypeDecl {
    const trait_pos = std.mem.indexOf(u8, line, "trait ") orelse return null;
    const name_start = trait_pos + 6;

    var name_end = name_start;
    while (name_end < line.len and (std.ascii.isAlphanumeric(line[name_end]) or line[name_end] == '_')) {
        name_end += 1;
    }

    if (name_end <= name_start) return null;

    return base.TypeDecl{
        .name = try allocator.dupe(u8, line[name_start..name_end]),
        .line = line_num,
        .kind = .interface_type, // Traits are similar to interfaces
    };
}

fn parseFunction(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.FunctionDecl {
    const fn_pos = std.mem.indexOf(u8, line, "fn ") orelse return null;

    const is_async = fn_pos >= 6 and std.mem.indexOf(u8, line[0..fn_pos], "async ") != null;
    const is_public = std.mem.indexOf(u8, line[0..fn_pos], "pub ") != null;

    var name_start = fn_pos + 3;
    while (name_start < line.len and line[name_start] == ' ') name_start += 1;

    var name_end = name_start;
    while (name_end < line.len and (std.ascii.isAlphanumeric(line[name_end]) or line[name_end] == '_')) {
        name_end += 1;
    }

    if (name_end <= name_start) return null;

    const name = try allocator.dupe(u8, line[name_start..name_end]);
    var return_type: ?[]const u8 = null;

    // Extract return type (look for -> TYPE)
    if (std.mem.indexOf(u8, line, ") -> ")) |arrow_pos| {
        const type_start = arrow_pos + 5;
        var type_end = type_start;

        // Handle Result<T, E> and Option<T> generics
        var angle_depth: u32 = 0;
        while (type_end < line.len) {
            if (line[type_end] == '<') angle_depth += 1;
            if (line[type_end] == '>') {
                if (angle_depth > 0) angle_depth -= 1;
            }
            if (angle_depth == 0 and (line[type_end] == '{' or line[type_end] == ';' or line[type_end] == '\n' or line[type_end] == ' ')) {
                break;
            }
            type_end += 1;
        }

        if (type_end > type_start) {
            const type_str = std.mem.trim(u8, line[type_start..type_end], " \t");
            if (type_str.len > 0) {
                return_type = try allocator.dupe(u8, type_str);
            }
        }
    }

    // Check for error handling patterns
    const has_error_handling = std.mem.indexOf(u8, line, "Result<") != null or
        std.mem.indexOf(u8, line, "-> Result") != null or
        std.mem.indexOf(u8, line, "?") != null;

    return base.FunctionDecl{
        .name = name,
        .line = line_num,
        .is_async = is_async,
        .is_public = is_public,
        .return_type = return_type,
        .has_error_handling = has_error_handling,
    };
}
