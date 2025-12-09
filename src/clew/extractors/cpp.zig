// C++ extractor using line-by-line parsing
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
        // Parse using statements
        else if (std.mem.startsWith(u8, trimmed, "using ")) {
            if (try parseUsing(allocator, trimmed, line_num)) |import_decl| {
                try structure.imports.append(allocator, import_decl);
            }
        }
        // Parse class definitions
        else if (std.mem.indexOf(u8, trimmed, "class ") != null) {
            if (try parseClass(allocator, trimmed, line_num)) |type_decl| {
                try structure.types.append(allocator, type_decl);
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
        // Parse functions/methods
        else if (try parseFunction(allocator, trimmed, line_num)) |func_decl| {
            try structure.functions.append(allocator, func_decl);
        }
    }

    return structure;
}

fn parseInclude(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.ImportDecl {
    if (!std.mem.startsWith(u8, line, "#include ")) return null;

    var name_start: usize = 9;
    while (name_start < line.len and line[name_start] == ' ') name_start += 1;

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

fn parseUsing(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.ImportDecl {
    if (!std.mem.startsWith(u8, line, "using ")) return null;

    // using namespace std; or using std::vector;
    const namespace_pos = std.mem.indexOf(u8, line, "namespace ");
    var name_start: usize = if (namespace_pos) |pos| pos + 10 else 6;

    while (name_start < line.len and line[name_start] == ' ') name_start += 1;

    var name_end = name_start;
    while (name_end < line.len and line[name_end] != ';' and line[name_end] != ' ' and line[name_end] != '\n') {
        name_end += 1;
    }

    if (name_end <= name_start) return null;

    return base.ImportDecl{
        .module = try allocator.dupe(u8, line[name_start..name_end]),
        .line = line_num,
        .is_wildcard = namespace_pos != null,
        .items = &.{},
    };
}

fn parseClass(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.TypeDecl {
    const class_pos = std.mem.indexOf(u8, line, "class ") orelse return null;

    // Skip if it's a forward declaration
    if (std.mem.indexOf(u8, line, "class forward") != null) return null;

    var name_start = class_pos + 6;
    while (name_start < line.len and line[name_start] == ' ') name_start += 1;

    var name_end = name_start;
    while (name_end < line.len and (std.ascii.isAlphanumeric(line[name_end]) or line[name_end] == '_')) {
        name_end += 1;
    }

    if (name_end <= name_start) return null;

    return base.TypeDecl{
        .name = try allocator.dupe(u8, line[name_start..name_end]),
        .line = line_num,
        .kind = .class_type,
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

    // Handle enum class
    if (name_start < line.len and std.mem.startsWith(u8, line[name_start..], "class ")) {
        name_start += 6;
    }

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

fn parseFunction(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.FunctionDecl {
    // Skip preprocessor directives
    if (line.len > 0 and line[0] == '#') return null;

    // Must have parentheses for function declaration
    const paren_pos = std.mem.indexOf(u8, line, "(") orelse return null;
    if (paren_pos == 0) return null;

    // Skip control statements
    if (std.mem.indexOf(u8, line, "if ") != null or
        std.mem.indexOf(u8, line, "if(") != null or
        std.mem.indexOf(u8, line, "while ") != null or
        std.mem.indexOf(u8, line, "while(") != null or
        std.mem.indexOf(u8, line, "for ") != null or
        std.mem.indexOf(u8, line, "for(") != null or
        std.mem.indexOf(u8, line, "switch ") != null or
        std.mem.indexOf(u8, line, "return ") != null or
        std.mem.indexOf(u8, line, "catch ") != null or
        std.mem.indexOf(u8, line, "catch(") != null)
    {
        return null;
    }

    // Find function name (word before parenthesis, might have :: for methods)
    var name_end = paren_pos;
    while (name_end > 0 and line[name_end - 1] == ' ') name_end -= 1;

    var name_start = name_end;
    while (name_start > 0 and (std.ascii.isAlphanumeric(line[name_start - 1]) or
        line[name_start - 1] == '_' or
        line[name_start - 1] == ':'))
    {
        name_start -= 1;
    }

    // Skip leading ::
    while (name_start < name_end and line[name_start] == ':') name_start += 1;

    if (name_end <= name_start) return null;

    // Skip if name is a keyword
    const name = line[name_start..name_end];
    if (std.mem.eql(u8, name, "sizeof") or
        std.mem.eql(u8, name, "typeof") or
        std.mem.eql(u8, name, "decltype") or
        std.mem.eql(u8, name, "struct") or
        std.mem.eql(u8, name, "class") or
        std.mem.eql(u8, name, "enum") or
        std.mem.eql(u8, name, "union") or
        std.mem.eql(u8, name, "new") or
        std.mem.eql(u8, name, "delete"))
    {
        return null;
    }

    const allocated_name = try allocator.dupe(u8, name);

    // Check for virtual, override, const, noexcept
    const is_async = std.mem.indexOf(u8, line, " async ") != null;

    // Extract return type (everything before name, excluding keywords)
    var return_type: ?[]const u8 = null;
    if (name_start > 0) {
        var type_str = std.mem.trim(u8, line[0..name_start], " \t");
        // Remove common keywords from return type
        if (std.mem.startsWith(u8, type_str, "virtual ")) {
            type_str = std.mem.trim(u8, type_str[8..], " \t");
        }
        if (std.mem.startsWith(u8, type_str, "static ")) {
            type_str = std.mem.trim(u8, type_str[7..], " \t");
        }
        if (std.mem.startsWith(u8, type_str, "inline ")) {
            type_str = std.mem.trim(u8, type_str[7..], " \t");
        }
        if (std.mem.startsWith(u8, type_str, "constexpr ")) {
            type_str = std.mem.trim(u8, type_str[10..], " \t");
        }
        if (type_str.len > 0) {
            return_type = try allocator.dupe(u8, type_str);
        }
    }

    // Check for error handling patterns
    const has_error_handling = std.mem.indexOf(u8, line, "throw") != null or
        std.mem.indexOf(u8, line, "noexcept") != null or
        std.mem.indexOf(u8, line, "std::exception") != null;

    return base.FunctionDecl{
        .name = allocated_name,
        .line = line_num,
        .is_async = is_async,
        .is_public = true,
        .return_type = return_type,
        .has_error_handling = has_error_handling,
    };
}
