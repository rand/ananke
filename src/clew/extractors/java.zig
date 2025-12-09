// Java extractor using line-by-line parsing
const std = @import("std");
const base = @import("base.zig");

pub fn parse(allocator: std.mem.Allocator, source: []const u8) !base.SyntaxStructure {
    var structure = base.SyntaxStructure.init(allocator);
    errdefer structure.deinit();

    var line_num: u32 = 1;
    var lines = std.mem.splitScalar(u8, source, '\n');

    while (lines.next()) |line| : (line_num += 1) {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0 or std.mem.startsWith(u8, trimmed, "//") or std.mem.startsWith(u8, trimmed, "/*") or std.mem.startsWith(u8, trimmed, "*")) continue;

        // Parse imports
        if (std.mem.startsWith(u8, trimmed, "import ")) {
            if (try parseImport(allocator, trimmed, line_num)) |import_decl| {
                try structure.imports.append(allocator, import_decl);
            }
        }
        // Parse class definitions
        else if (std.mem.indexOf(u8, trimmed, "class ") != null) {
            if (try parseClass(allocator, trimmed, line_num)) |type_decl| {
                try structure.types.append(allocator, type_decl);
            }
        }
        // Parse interface definitions
        else if (std.mem.indexOf(u8, trimmed, "interface ") != null) {
            if (try parseInterface(allocator, trimmed, line_num)) |type_decl| {
                try structure.types.append(allocator, type_decl);
            }
        }
        // Parse enum definitions
        else if (std.mem.indexOf(u8, trimmed, "enum ") != null) {
            if (try parseEnum(allocator, trimmed, line_num)) |type_decl| {
                try structure.types.append(allocator, type_decl);
            }
        }
        // Parse methods (must have parentheses and not be control flow)
        else if (try parseMethod(allocator, trimmed, line_num)) |func_decl| {
            try structure.functions.append(allocator, func_decl);
        }
    }

    return structure;
}

fn parseImport(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.ImportDecl {
    if (!std.mem.startsWith(u8, line, "import ")) return null;

    var name_start: usize = 7;

    // Handle static imports
    if (std.mem.startsWith(u8, line[name_start..], "static ")) {
        name_start += 7;
    }

    var name_end = name_start;
    while (name_end < line.len and line[name_end] != ';' and line[name_end] != '\n') {
        name_end += 1;
    }

    if (name_end <= name_start) return null;

    const module = std.mem.trim(u8, line[name_start..name_end], " \t");
    const is_wildcard = std.mem.endsWith(u8, module, ".*");

    return base.ImportDecl{
        .module = try allocator.dupe(u8, module),
        .line = line_num,
        .is_wildcard = is_wildcard,
        .items = &.{},
    };
}

fn parseClass(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.TypeDecl {
    const class_pos = std.mem.indexOf(u8, line, "class ") orelse return null;
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

fn parseInterface(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.TypeDecl {
    const interface_pos = std.mem.indexOf(u8, line, "interface ") orelse return null;
    var name_start = interface_pos + 10;

    while (name_start < line.len and line[name_start] == ' ') name_start += 1;

    var name_end = name_start;
    while (name_end < line.len and (std.ascii.isAlphanumeric(line[name_end]) or line[name_end] == '_')) {
        name_end += 1;
    }

    if (name_end <= name_start) return null;

    return base.TypeDecl{
        .name = try allocator.dupe(u8, line[name_start..name_end]),
        .line = line_num,
        .kind = .interface_type,
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

fn parseMethod(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.FunctionDecl {
    // Must have parentheses for method declaration
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
        std.mem.indexOf(u8, line, "catch(") != null or
        std.mem.indexOf(u8, line, "new ") != null or
        std.mem.indexOf(u8, line, "@") != null) // Skip annotations
    {
        return null;
    }

    // Find method name (word before parenthesis)
    var name_end = paren_pos;
    while (name_end > 0 and line[name_end - 1] == ' ') name_end -= 1;

    var name_start = name_end;
    while (name_start > 0 and (std.ascii.isAlphanumeric(line[name_start - 1]) or line[name_start - 1] == '_')) {
        name_start -= 1;
    }

    if (name_end <= name_start) return null;

    // Skip if name is a keyword
    const name = line[name_start..name_end];
    if (std.mem.eql(u8, name, "class") or
        std.mem.eql(u8, name, "interface") or
        std.mem.eql(u8, name, "enum") or
        std.mem.eql(u8, name, "new") or
        std.mem.eql(u8, name, "super") or
        std.mem.eql(u8, name, "this"))
    {
        return null;
    }

    const allocated_name = try allocator.dupe(u8, name);

    // Check visibility and other modifiers
    const is_public = std.mem.indexOf(u8, line[0..name_start], "public ") != null;
    const is_async = std.mem.indexOf(u8, line, "CompletableFuture") != null or
        std.mem.indexOf(u8, line, "Future<") != null;

    // Extract return type (find type before method name)
    var return_type: ?[]const u8 = null;
    if (name_start > 0) {
        var type_end = name_start;
        while (type_end > 0 and line[type_end - 1] == ' ') type_end -= 1;

        var type_start = type_end;
        // Handle generics like List<String>
        var angle_depth: u32 = 0;
        while (type_start > 0) {
            if (line[type_start - 1] == '>') angle_depth += 1;
            if (line[type_start - 1] == '<') {
                if (angle_depth > 0) angle_depth -= 1;
            }
            if (angle_depth == 0 and line[type_start - 1] == ' ') break;
            type_start -= 1;
        }

        if (type_end > type_start) {
            const type_str = std.mem.trim(u8, line[type_start..type_end], " \t");
            // Skip modifiers
            if (type_str.len > 0 and
                !std.mem.eql(u8, type_str, "public") and
                !std.mem.eql(u8, type_str, "private") and
                !std.mem.eql(u8, type_str, "protected") and
                !std.mem.eql(u8, type_str, "static") and
                !std.mem.eql(u8, type_str, "final") and
                !std.mem.eql(u8, type_str, "abstract") and
                !std.mem.eql(u8, type_str, "synchronized"))
            {
                return_type = try allocator.dupe(u8, type_str);
            }
        }
    }

    // Check for error handling patterns
    const has_error_handling = std.mem.indexOf(u8, line, "throws ") != null or
        std.mem.indexOf(u8, line, "Exception") != null;

    return base.FunctionDecl{
        .name = allocated_name,
        .line = line_num,
        .is_async = is_async,
        .is_public = is_public,
        .return_type = return_type,
        .has_error_handling = has_error_handling,
    };
}
