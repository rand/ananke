// Zig extractor using line-by-line parsing
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

        // Parse imports
        if (std.mem.indexOf(u8, trimmed, "@import(") != null) {
            if (try parseImport(allocator, trimmed, line_num)) |import_decl| {
                try structure.imports.append(allocator, import_decl);
            }
        }
        // Parse struct/union/enum definitions
        else if (std.mem.indexOf(u8, trimmed, " = struct") != null or
            std.mem.indexOf(u8, trimmed, " = union") != null or
            std.mem.indexOf(u8, trimmed, " = enum") != null)
        {
            if (try parseType(allocator, trimmed, line_num)) |type_decl| {
                try structure.types.append(allocator, type_decl);
            }
        }
        // Parse functions (pub fn, fn)
        else if (std.mem.indexOf(u8, trimmed, "fn ") != null) {
            if (try parseFunction(allocator, trimmed, line_num)) |func_decl| {
                try structure.functions.append(allocator, func_decl);
            }
        }
    }

    return structure;
}

fn parseImport(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.ImportDecl {
    const import_pos = std.mem.indexOf(u8, line, "@import(") orelse return null;
    var name_start = import_pos + 8;

    // Skip quotes
    while (name_start < line.len and (line[name_start] == '"' or line[name_start] == ' ')) {
        name_start += 1;
    }

    var name_end = name_start;
    while (name_end < line.len and line[name_end] != '"' and line[name_end] != ')') {
        name_end += 1;
    }

    if (name_end <= name_start) return null;

    return base.ImportDecl{
        .module = try allocator.dupe(u8, line[name_start..name_end]),
        .line = line_num,
        .items = &.{},
    };
}

fn parseType(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.TypeDecl {
    // Pattern: const/pub const Name = struct/union/enum
    var kind: base.TypeDecl.TypeKind = .struct_type;

    var name_start: usize = 0;

    // Skip pub
    if (std.mem.startsWith(u8, line, "pub ")) {
        name_start = 4;
    }

    // Skip const
    if (name_start < line.len) {
        if (std.mem.startsWith(u8, line[name_start..], "const ")) {
            name_start += 6;
        }
    }

    var name_end = name_start;
    while (name_end < line.len and (std.ascii.isAlphanumeric(line[name_end]) or line[name_end] == '_')) {
        name_end += 1;
    }

    if (name_end <= name_start) return null;

    // Determine type kind
    if (std.mem.indexOf(u8, line, " = enum") != null) {
        kind = .enum_type;
    } else if (std.mem.indexOf(u8, line, " = union") != null) {
        kind = .union_type;
    }

    return base.TypeDecl{
        .name = try allocator.dupe(u8, line[name_start..name_end]),
        .line = line_num,
        .kind = kind,
    };
}

fn parseFunction(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.FunctionDecl {
    const fn_pos = std.mem.indexOf(u8, line, "fn ") orelse return null;

    const is_public = fn_pos >= 4 and std.mem.indexOf(u8, line[0..fn_pos], "pub ") != null;

    var name_start = fn_pos + 3;
    while (name_start < line.len and line[name_start] == ' ') name_start += 1;

    var name_end = name_start;
    while (name_end < line.len and (std.ascii.isAlphanumeric(line[name_end]) or line[name_end] == '_')) {
        name_end += 1;
    }

    if (name_end <= name_start) return null;

    const name = try allocator.dupe(u8, line[name_start..name_end]);
    var return_type: ?[]const u8 = null;

    // Extract return type (after ) and before {)
    // Pattern: fn name(params) ReturnType { or fn name(params) ReturnType!Error {
    if (std.mem.lastIndexOf(u8, line, ")")) |last_paren| {
        var type_start = last_paren + 1;
        while (type_start < line.len and line[type_start] == ' ') type_start += 1;

        if (type_start < line.len and line[type_start] != '{') {
            var type_end = type_start;

            while (type_end < line.len and line[type_end] != '{' and line[type_end] != '\n') {
                type_end += 1;
            }

            if (type_end > type_start) {
                const type_str = std.mem.trim(u8, line[type_start..type_end], " \t");
                if (type_str.len > 0) {
                    return_type = try allocator.dupe(u8, type_str);
                }
            }
        }
    }

    // Check for error handling patterns
    const has_error_handling = std.mem.indexOf(u8, line, "!") != null or
        std.mem.indexOf(u8, line, "anyerror") != null or
        std.mem.indexOf(u8, line, "error.") != null;

    return base.FunctionDecl{
        .name = name,
        .line = line_num,
        .is_async = false,
        .is_public = is_public,
        .return_type = return_type,
        .has_error_handling = has_error_handling,
    };
}
