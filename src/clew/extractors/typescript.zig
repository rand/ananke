// TypeScript extractor using line-by-line parsing
const std = @import("std");
const base = @import("base.zig");

pub fn parse(allocator: std.mem.Allocator, source: []const u8) !base.SyntaxStructure {
    var structure = base.SyntaxStructure.init(allocator);
    errdefer structure.deinit();

    var line_num: u32 = 1;
    var lines = std.mem.splitScalar(u8, source, '\n');

    while (lines.next()) |line| : (line_num += 1) {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0) continue;

        // Parse imports
        if (std.mem.startsWith(u8, trimmed, "import ")) {
            if (try parseImport(allocator, trimmed, line_num)) |import_decl| {
                try structure.imports.append(allocator, import_decl);
            }
        }
        // Parse interfaces
        else if (std.mem.indexOf(u8, trimmed, "interface ")) |_| {
            if (try parseInterface(allocator, trimmed, line_num)) |type_decl| {
                try structure.types.append(allocator, type_decl);
            }
        }
        // Parse classes
        else if (std.mem.indexOf(u8, trimmed, "class ")) |_| {
            if (try parseClass(allocator, trimmed, line_num)) |type_decl| {
                try structure.types.append(allocator, type_decl);
            }
        }
        // Parse type aliases
        else if (std.mem.startsWith(u8, trimmed, "type ")) {
            if (try parseTypeAlias(allocator, trimmed, line_num)) |type_decl| {
                try structure.types.append(allocator, type_decl);
            }
        }
        // Parse functions (async function, function, arrow functions in const/let)
        else if (std.mem.indexOf(u8, trimmed, "function ") != null or
            std.mem.indexOf(u8, trimmed, " => ") != null or
            std.mem.indexOf(u8, trimmed, "async ") != null)
        {
            if (try parseFunction(allocator, trimmed, line_num, source)) |func_decl| {
                try structure.functions.append(allocator, func_decl);
            }
        }
    }

    return structure;
}

fn parseImport(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.ImportDecl {
    // Match patterns: import { ... } from '...', import * as ... from '...'
    const from_pos = std.mem.indexOf(u8, line, "from ");
    if (from_pos == null) return null;

    const module_start = from_pos.? + 5;
    var module_end = module_start;

    // Skip whitespace and quotes
    while (module_end < line.len and (line[module_end] == ' ' or line[module_end] == '\'' or line[module_end] == '"')) {
        module_end += 1;
    }

    const quote_start = module_end;
    while (module_end < line.len and line[module_end] != '\'' and line[module_end] != '"' and line[module_end] != ';') {
        module_end += 1;
    }

    if (module_end <= quote_start) return null;

    const module_name = try allocator.dupe(u8, line[quote_start..module_end]);
    const is_wildcard = std.mem.indexOf(u8, line, "* as ") != null;

    return base.ImportDecl{
        .module = module_name,
        .line = line_num,
        .is_wildcard = is_wildcard,
        .items = &.{},
    };
}

fn parseInterface(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.TypeDecl {
    const interface_pos = std.mem.indexOf(u8, line, "interface ") orelse return null;
    const name_start = interface_pos + 10;

    var name_end = name_start;
    while (name_end < line.len and (std.ascii.isAlphanumeric(line[name_end]) or line[name_end] == '_')) {
        name_end += 1;
    }

    if (name_end <= name_start) return null;

    const name = try allocator.dupe(u8, line[name_start..name_end]);

    return base.TypeDecl{
        .name = name,
        .line = line_num,
        .kind = .interface_type,
    };
}

fn parseClass(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.TypeDecl {
    const class_pos = std.mem.indexOf(u8, line, "class ") orelse return null;
    const name_start = class_pos + 6;

    var name_end = name_start;
    while (name_end < line.len and (std.ascii.isAlphanumeric(line[name_end]) or line[name_end] == '_')) {
        name_end += 1;
    }

    if (name_end <= name_start) return null;

    const name = try allocator.dupe(u8, line[name_start..name_end]);

    return base.TypeDecl{
        .name = name,
        .line = line_num,
        .kind = .class_type,
    };
}

fn parseTypeAlias(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.TypeDecl {
    if (!std.mem.startsWith(u8, line, "type ")) return null;

    const name_start: usize = 5;
    var name_end = name_start;

    while (name_end < line.len and (std.ascii.isAlphanumeric(line[name_end]) or line[name_end] == '_')) {
        name_end += 1;
    }

    if (name_end <= name_start) return null;

    const name = try allocator.dupe(u8, line[name_start..name_end]);

    return base.TypeDecl{
        .name = name,
        .line = line_num,
        .kind = .interface_type, // Type aliases are similar to interfaces
    };
}

fn parseFunction(allocator: std.mem.Allocator, line: []const u8, line_num: u32, source: []const u8) !?base.FunctionDecl {
    _ = source; // May use for error handling detection in the future

    const is_async = std.mem.indexOf(u8, line, "async ") != null;

    // Try to extract function name
    var name: ?[]const u8 = null;
    var return_type: ?[]const u8 = null;

    // Pattern: function name(...) or async function name(...)
    if (std.mem.indexOf(u8, line, "function ")) |func_pos| {
        var name_start = func_pos + 9;
        while (name_start < line.len and line[name_start] == ' ') name_start += 1;

        var name_end = name_start;
        while (name_end < line.len and (std.ascii.isAlphanumeric(line[name_end]) or line[name_end] == '_')) {
            name_end += 1;
        }

        if (name_end > name_start) {
            name = try allocator.dupe(u8, line[name_start..name_end]);
        }
    }
    // Pattern: const name = (...) => or let name = async (...)
    else if (std.mem.indexOf(u8, line, " = ")) |eq_pos| {
        var name_start: usize = 0;
        if (std.mem.indexOf(u8, line, "const ")) |const_pos| {
            name_start = const_pos + 6;
        } else if (std.mem.indexOf(u8, line, "let ")) |let_pos| {
            name_start = let_pos + 4;
        }

        if (name_start > 0) {
            var name_end = name_start;
            while (name_end < eq_pos and (std.ascii.isAlphanumeric(line[name_end]) or line[name_end] == '_')) {
                name_end += 1;
            }

            if (name_end > name_start) {
                name = try allocator.dupe(u8, line[name_start..name_end]);
            }
        }
    }
    // Pattern: methodName(...): ReturnType {
    else {
        // Try to find method pattern
        var name_start: usize = 0;
        while (name_start < line.len and line[name_start] == ' ') name_start += 1;

        // Skip async keyword
        if (std.mem.startsWith(u8, line[name_start..], "async ")) {
            name_start += 6;
            while (name_start < line.len and line[name_start] == ' ') name_start += 1;
        }

        var name_end = name_start;
        while (name_end < line.len and (std.ascii.isAlphanumeric(line[name_end]) or line[name_end] == '_')) {
            name_end += 1;
        }

        if (name_end > name_start and name_end < line.len and line[name_end] == '(') {
            name = try allocator.dupe(u8, line[name_start..name_end]);
        }
    }

    // Extract return type (look for :TYPE before { or =>)
    if (std.mem.indexOf(u8, line, "): ")) |colon_pos| {
        const type_start = colon_pos + 3;
        var type_end = type_start;

        while (type_end < line.len and line[type_end] != '{' and line[type_end] != ';' and line[type_end] != '=' and line[type_end] != '\n') {
            type_end += 1;
        }

        if (type_end > type_start) {
            const type_str = std.mem.trim(u8, line[type_start..type_end], " \t");
            if (type_str.len > 0) {
                return_type = try allocator.dupe(u8, type_str);
            }
        }
    }

    const has_error_handling = std.mem.indexOf(u8, line, "try") != null or
        std.mem.indexOf(u8, line, "catch") != null;

    if (name) |func_name| {
        return base.FunctionDecl{
            .name = func_name,
            .line = line_num,
            .is_async = is_async,
            .return_type = return_type,
            .has_error_handling = has_error_handling,
        };
    }

    // If we allocated return_type but didn't find a name, free it
    if (return_type) |ret_type| {
        allocator.free(ret_type);
    }

    return null;
}
