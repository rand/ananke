// JavaScript extractor using line-by-line parsing
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

        // Parse imports (ES6 import and CommonJS require)
        if (std.mem.startsWith(u8, trimmed, "import ") or
            std.mem.indexOf(u8, trimmed, "require(") != null)
        {
            if (try parseImport(allocator, trimmed, line_num)) |import_decl| {
                try structure.imports.append(allocator, import_decl);
            }
        }
        // Parse classes
        else if (std.mem.indexOf(u8, trimmed, "class ") != null) {
            if (try parseClass(allocator, trimmed, line_num)) |type_decl| {
                try structure.types.append(allocator, type_decl);
            }
        }
        // Parse functions (function, async function, arrow functions in const/let/var)
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
    // ES6 import: import { ... } from '...' or import * as ... from '...'
    if (std.mem.indexOf(u8, line, "from ")) |from_pos| {
        const module_start = from_pos + 5;
        var module_end = module_start;

        // Skip whitespace and quotes
        while (module_end < line.len and (line[module_end] == ' ' or line[module_end] == '\'' or line[module_end] == '"')) {
            module_end += 1;
        }

        const quote_start = module_end;
        while (module_end < line.len and line[module_end] != '\'' and line[module_end] != '"' and line[module_end] != ';') {
            module_end += 1;
        }

        if (module_end > quote_start) {
            const module_name = try allocator.dupe(u8, line[quote_start..module_end]);
            const is_wildcard = std.mem.indexOf(u8, line, "* as ") != null;

            return base.ImportDecl{
                .module = module_name,
                .line = line_num,
                .is_wildcard = is_wildcard,
                .items = &.{},
            };
        }
    }

    // CommonJS require: const/let/var name = require('...')
    if (std.mem.indexOf(u8, line, "require(")) |require_pos| {
        var module_start = require_pos + 8;

        // Skip quote
        while (module_start < line.len and (line[module_start] == '\'' or line[module_start] == '"')) {
            module_start += 1;
        }

        var module_end = module_start;
        while (module_end < line.len and line[module_end] != '\'' and line[module_end] != '"' and line[module_end] != ')') {
            module_end += 1;
        }

        if (module_end > module_start) {
            const module_name = try allocator.dupe(u8, line[module_start..module_end]);

            return base.ImportDecl{
                .module = module_name,
                .line = line_num,
                .items = &.{},
            };
        }
    }

    return null;
}

fn parseClass(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.TypeDecl {
    const class_pos = std.mem.indexOf(u8, line, "class ") orelse return null;
    const name_start = class_pos + 6;

    var name_end = name_start;
    while (name_end < line.len and (std.ascii.isAlphanumeric(line[name_end]) or line[name_end] == '_' or line[name_end] == '$')) {
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

fn parseFunction(allocator: std.mem.Allocator, line: []const u8, line_num: u32, source: []const u8) !?base.FunctionDecl {
    _ = source;

    const is_async = std.mem.indexOf(u8, line, "async ") != null;
    var name: ?[]const u8 = null;

    // Pattern: function name(...) or async function name(...)
    if (std.mem.indexOf(u8, line, "function ")) |func_pos| {
        var name_start = func_pos + 9;
        while (name_start < line.len and line[name_start] == ' ') name_start += 1;

        // Check for generator function*
        if (name_start < line.len and line[name_start] == '*') {
            name_start += 1;
            while (name_start < line.len and line[name_start] == ' ') name_start += 1;
        }

        var name_end = name_start;
        while (name_end < line.len and (std.ascii.isAlphanumeric(line[name_end]) or line[name_end] == '_' or line[name_end] == '$')) {
            name_end += 1;
        }

        if (name_end > name_start) {
            name = try allocator.dupe(u8, line[name_start..name_end]);
        }
    }
    // Pattern: const/let/var name = (...) => or const name = async (...)
    else if (std.mem.indexOf(u8, line, " = ")) |eq_pos| {
        var name_start: usize = 0;
        if (std.mem.indexOf(u8, line, "const ")) |const_pos| {
            name_start = const_pos + 6;
        } else if (std.mem.indexOf(u8, line, "let ")) |let_pos| {
            name_start = let_pos + 4;
        } else if (std.mem.indexOf(u8, line, "var ")) |var_pos| {
            name_start = var_pos + 4;
        }

        if (name_start > 0) {
            var name_end = name_start;
            while (name_end < eq_pos and (std.ascii.isAlphanumeric(line[name_end]) or line[name_end] == '_' or line[name_end] == '$')) {
                name_end += 1;
            }

            if (name_end > name_start) {
                name = try allocator.dupe(u8, line[name_start..name_end]);
            }
        }
    }
    // Pattern: methodName(...) { - class method without function keyword
    else {
        var name_start: usize = 0;
        while (name_start < line.len and line[name_start] == ' ') name_start += 1;

        // Skip async keyword
        if (std.mem.startsWith(u8, line[name_start..], "async ")) {
            name_start += 6;
            while (name_start < line.len and line[name_start] == ' ') name_start += 1;
        }

        // Skip static keyword
        if (std.mem.startsWith(u8, line[name_start..], "static ")) {
            name_start += 7;
            while (name_start < line.len and line[name_start] == ' ') name_start += 1;
        }

        // Skip get/set keyword
        if (std.mem.startsWith(u8, line[name_start..], "get ") or std.mem.startsWith(u8, line[name_start..], "set ")) {
            name_start += 4;
            while (name_start < line.len and line[name_start] == ' ') name_start += 1;
        }

        var name_end = name_start;
        while (name_end < line.len and (std.ascii.isAlphanumeric(line[name_end]) or line[name_end] == '_' or line[name_end] == '$')) {
            name_end += 1;
        }

        if (name_end > name_start and name_end < line.len and line[name_end] == '(') {
            name = try allocator.dupe(u8, line[name_start..name_end]);
        }
    }

    const has_error_handling = std.mem.indexOf(u8, line, "try") != null or
        std.mem.indexOf(u8, line, "catch") != null;

    if (name) |func_name| {
        return base.FunctionDecl{
            .name = func_name,
            .line = line_num,
            .is_async = is_async,
            .return_type = null, // JavaScript doesn't have type annotations
            .has_error_handling = has_error_handling,
        };
    }

    return null;
}
