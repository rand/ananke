// C extractor using line-by-line parsing
const std = @import("std");
const base = @import("base.zig");

pub fn parse(allocator: std.mem.Allocator, source: []const u8) !base.SyntaxStructure {
    var structure = base.SyntaxStructure.init(allocator);
    errdefer structure.deinit();

    var line_num: u32 = 1;
    var lines = std.mem.splitScalar(u8, source, '\n');

    while (lines.next()) |line| : (line_num += 1) {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0 or std.mem.startsWith(u8, trimmed, "//") or std.mem.startsWith(u8, trimmed, "/*")) continue;

        // Parse includes
        if (std.mem.startsWith(u8, trimmed, "#include ")) {
            if (try parseInclude(allocator, trimmed, line_num)) |import_decl| {
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
        // Parse typedef
        else if (std.mem.startsWith(u8, trimmed, "typedef ")) {
            if (try parseTypedef(allocator, trimmed, line_num)) |type_decl| {
                try structure.types.append(allocator, type_decl);
            }
        }
        // Parse functions (return_type name(...))
        else if (try parseFunction(allocator, trimmed, line_num)) |func_decl| {
            try structure.functions.append(allocator, func_decl);
        }
    }

    return structure;
}

fn parseInclude(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.ImportDecl {
    if (!std.mem.startsWith(u8, line, "#include ")) return null;

    var name_start: usize = 9;

    // Skip whitespace
    while (name_start < line.len and line[name_start] == ' ') name_start += 1;

    // Get start delimiter
    if (name_start >= line.len) return null;
    const start_delim = line[name_start];
    if (start_delim != '<' and start_delim != '"') return null;

    name_start += 1;
    var name_end = name_start;

    const end_delim: u8 = if (start_delim == '<') '>' else '"';
    while (name_end < line.len and line[name_end] != end_delim) {
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
    var name_start = struct_pos + 7;

    while (name_start < line.len and line[name_start] == ' ') name_start += 1;

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
    var name_start = enum_pos + 5;

    while (name_start < line.len and line[name_start] == ' ') name_start += 1;

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

fn parseTypedef(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.TypeDecl {
    if (!std.mem.startsWith(u8, line, "typedef ")) return null;

    // Get the last identifier before ; (that's the typedef name)
    const semicolon_pos = std.mem.indexOf(u8, line, ";") orelse line.len;
    if (semicolon_pos <= 8) return null;

    var name_end = semicolon_pos;
    while (name_end > 8 and line[name_end - 1] == ' ') name_end -= 1;

    var name_start = name_end;
    while (name_start > 8 and (std.ascii.isAlphanumeric(line[name_start - 1]) or line[name_start - 1] == '_')) {
        name_start -= 1;
    }

    if (name_end <= name_start) return null;

    var kind: base.TypeDecl.TypeKind = .struct_type;
    if (std.mem.indexOf(u8, line, " struct ") != null) {
        kind = .struct_type;
    } else if (std.mem.indexOf(u8, line, " enum ") != null) {
        kind = .enum_type;
    } else if (std.mem.indexOf(u8, line, " union ") != null) {
        kind = .union_type;
    }

    return base.TypeDecl{
        .name = try allocator.dupe(u8, line[name_start..name_end]),
        .line = line_num,
        .kind = kind,
    };
}

fn parseFunction(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.FunctionDecl {
    // Skip preprocessor directives
    if (line.len > 0 and line[0] == '#') return null;

    // Must have parentheses for function declaration
    const paren_pos = std.mem.indexOf(u8, line, "(") orelse return null;
    if (paren_pos == 0) return null;

    // Skip control statements
    if (std.mem.indexOf(u8, line, "if ") != null or
        std.mem.indexOf(u8, line, "while ") != null or
        std.mem.indexOf(u8, line, "for ") != null or
        std.mem.indexOf(u8, line, "switch ") != null or
        std.mem.indexOf(u8, line, "return ") != null)
    {
        return null;
    }

    // Find function name (word before parenthesis)
    var name_end = paren_pos;
    while (name_end > 0 and line[name_end - 1] == ' ') name_end -= 1;

    var name_start = name_end;
    while (name_start > 0 and (std.ascii.isAlphanumeric(line[name_start - 1]) or line[name_start - 1] == '_')) {
        name_start -= 1;
    }

    if (name_end <= name_start) return null;

    // Skip if name is a type keyword
    const name = line[name_start..name_end];
    if (std.mem.eql(u8, name, "sizeof") or
        std.mem.eql(u8, name, "typeof") or
        std.mem.eql(u8, name, "struct") or
        std.mem.eql(u8, name, "enum") or
        std.mem.eql(u8, name, "union"))
    {
        return null;
    }

    const allocated_name = try allocator.dupe(u8, name);

    // Extract return type (everything before name)
    var return_type: ?[]const u8 = null;
    if (name_start > 0) {
        const type_str = std.mem.trim(u8, line[0..name_start], " \t");
        if (type_str.len > 0 and !std.mem.eql(u8, type_str, "static") and !std.mem.eql(u8, type_str, "extern")) {
            return_type = try allocator.dupe(u8, type_str);
        }
    }

    return base.FunctionDecl{
        .name = allocated_name,
        .line = line_num,
        .is_async = false,
        .is_public = true, // C functions are public by default
        .return_type = return_type,
        .has_error_handling = false,
    };
}
