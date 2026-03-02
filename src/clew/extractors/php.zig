// PHP extractor using line-by-line parsing
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
        // Skip PHP open/close tags
        if (std.mem.startsWith(u8, trimmed, "<?") or std.mem.startsWith(u8, trimmed, "?>")) continue;

        // Parse use statements
        if (std.mem.startsWith(u8, trimmed, "use ")) {
            if (try parseUse(allocator, trimmed, line_num)) |import_decl| {
                try structure.imports.append(allocator, import_decl);
            }
        }
        // Parse namespace
        else if (std.mem.startsWith(u8, trimmed, "namespace ")) {
            if (try parseNamespace(allocator, trimmed, line_num)) |import_decl| {
                try structure.imports.append(allocator, import_decl);
            }
        }
        // Parse require/include
        else if (std.mem.startsWith(u8, trimmed, "require ") or std.mem.startsWith(u8, trimmed, "require_once ") or
            std.mem.startsWith(u8, trimmed, "include ") or std.mem.startsWith(u8, trimmed, "include_once "))
        {
            if (try parseRequire(allocator, trimmed, line_num)) |import_decl| {
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
            if (try parseTypeByKeyword(allocator, trimmed, "interface ", line_num, .interface_type)) |type_decl| {
                try structure.types.append(allocator, type_decl);
            }
        }
        // Parse trait definitions
        else if (std.mem.indexOf(u8, trimmed, "trait ") != null) {
            if (try parseTypeByKeyword(allocator, trimmed, "trait ", line_num, .class_type)) |type_decl| {
                try structure.types.append(allocator, type_decl);
            }
        }
        // Parse enum definitions (PHP 8.1+)
        else if (std.mem.indexOf(u8, trimmed, "enum ") != null) {
            if (try parseTypeByKeyword(allocator, trimmed, "enum ", line_num, .enum_type)) |type_decl| {
                try structure.types.append(allocator, type_decl);
            }
        }
        // Parse function definitions
        else if (std.mem.indexOf(u8, trimmed, "function ") != null) {
            if (try parseFunction(allocator, trimmed, line_num)) |func_decl| {
                try structure.functions.append(allocator, func_decl);
            }
        }
    }

    return structure;
}

fn parseUse(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.ImportDecl {
    if (!std.mem.startsWith(u8, line, "use ")) return null;

    var end: usize = 4;
    while (end < line.len and line[end] != ';' and line[end] != '\n') end += 1;
    if (end <= 4) return null;

    const module = std.mem.trim(u8, line[4..end], " \t");
    if (module.len == 0) return null;

    return base.ImportDecl{
        .module = try allocator.dupe(u8, module),
        .line = line_num,
    };
}

fn parseNamespace(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.ImportDecl {
    if (!std.mem.startsWith(u8, line, "namespace ")) return null;

    var end: usize = 10;
    while (end < line.len and line[end] != ';' and line[end] != '{' and line[end] != '\n') end += 1;
    if (end <= 10) return null;

    const module = std.mem.trim(u8, line[10..end], " \t");
    if (module.len == 0) return null;

    return base.ImportDecl{
        .module = try allocator.dupe(u8, module),
        .line = line_num,
    };
}

fn parseRequire(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.ImportDecl {
    var start: usize = 0;
    if (std.mem.startsWith(u8, line, "require_once ")) {
        start = 13;
    } else if (std.mem.startsWith(u8, line, "require ")) {
        start = 8;
    } else if (std.mem.startsWith(u8, line, "include_once ")) {
        start = 13;
    } else if (std.mem.startsWith(u8, line, "include ")) {
        start = 8;
    } else {
        return null;
    }

    // Skip quotes and parentheses
    while (start < line.len and (line[start] == '\'' or line[start] == '"' or line[start] == '(' or line[start] == ' ')) start += 1;

    var end = start;
    while (end < line.len and line[end] != '\'' and line[end] != '"' and line[end] != ')' and line[end] != ';' and line[end] != '\n') end += 1;
    if (end <= start) return null;

    const module = std.mem.trim(u8, line[start..end], " \t");
    if (module.len == 0) return null;

    return base.ImportDecl{
        .module = try allocator.dupe(u8, module),
        .line = line_num,
    };
}

fn parseClass(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.TypeDecl {
    // Check for abstract class
    if (std.mem.indexOf(u8, line, "abstract class ")) |pos| {
        return try extractName(allocator, line, pos + 15, line_num, .class_type);
    }
    // Check for final class
    if (std.mem.indexOf(u8, line, "final class ")) |pos| {
        return try extractName(allocator, line, pos + 12, line_num, .class_type);
    }
    // Check for readonly class (PHP 8.2+)
    if (std.mem.indexOf(u8, line, "readonly class ")) |pos| {
        return try extractName(allocator, line, pos + 15, line_num, .class_type);
    }
    // Regular class
    if (std.mem.indexOf(u8, line, "class ")) |pos| {
        // Skip "enum class" which isn't valid PHP
        if (pos >= 5 and std.mem.eql(u8, line[pos - 5 .. pos], "enum ")) return null;
        return try extractName(allocator, line, pos + 6, line_num, .class_type);
    }
    return null;
}

fn parseTypeByKeyword(allocator: std.mem.Allocator, line: []const u8, keyword: []const u8, line_num: u32, kind: base.TypeDecl.TypeKind) !?base.TypeDecl {
    const pos = std.mem.indexOf(u8, line, keyword) orelse return null;
    return try extractName(allocator, line, pos + keyword.len, line_num, kind);
}

fn extractName(allocator: std.mem.Allocator, line: []const u8, start: usize, line_num: u32, kind: base.TypeDecl.TypeKind) !?base.TypeDecl {
    var name_start = start;
    while (name_start < line.len and line[name_start] == ' ') name_start += 1;

    var name_end = name_start;
    while (name_end < line.len and (std.ascii.isAlphanumeric(line[name_end]) or line[name_end] == '_')) {
        name_end += 1;
    }
    if (name_end <= name_start) return null;

    return base.TypeDecl{
        .name = try allocator.dupe(u8, line[name_start..name_end]),
        .line = line_num,
        .kind = kind,
    };
}

fn parseFunction(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.FunctionDecl {
    const func_pos = std.mem.indexOf(u8, line, "function ") orelse return null;

    // Skip anonymous functions (closures): "function (" or "function("
    const after_keyword = func_pos + 9;
    if (after_keyword < line.len and line[after_keyword] == '(') return null;

    var name_start = after_keyword;
    while (name_start < line.len and line[name_start] == ' ') name_start += 1;

    // Check if next char is '(' — anonymous function
    if (name_start < line.len and line[name_start] == '(') return null;

    var name_end = name_start;
    while (name_end < line.len and (std.ascii.isAlphanumeric(line[name_end]) or line[name_end] == '_')) {
        name_end += 1;
    }
    if (name_end <= name_start) return null;

    const name = line[name_start..name_end];
    // Skip PHP keywords
    if (std.mem.eql(u8, name, "class") or std.mem.eql(u8, name, "interface") or
        std.mem.eql(u8, name, "trait") or std.mem.eql(u8, name, "enum"))
    {
        return null;
    }

    const is_public = std.mem.indexOf(u8, line[0..func_pos], "public ") != null or
        (std.mem.indexOf(u8, line[0..func_pos], "private ") == null and
            std.mem.indexOf(u8, line[0..func_pos], "protected ") == null);

    const is_static = std.mem.indexOf(u8, line[0..func_pos], "static ") != null;
    _ = is_static;

    // Extract return type after ): type
    var return_type: ?[]const u8 = null;
    if (std.mem.indexOf(u8, line, "):")) |rp| {
        var type_start = rp + 2;
        while (type_start < line.len and line[type_start] == ' ') type_start += 1;
        // Skip nullable marker
        if (type_start < line.len and line[type_start] == '?') type_start += 1;
        const ts = type_start;
        var type_end = ts;
        while (type_end < line.len and (std.ascii.isAlphanumeric(line[type_end]) or line[type_end] == '_' or line[type_end] == '\\' or line[type_end] == '|')) {
            type_end += 1;
        }
        if (type_end > ts) {
            return_type = try allocator.dupe(u8, line[ts..type_end]);
        }
    } else if (std.mem.indexOf(u8, line, ") :")) |rp| {
        var type_start = rp + 3;
        while (type_start < line.len and line[type_start] == ' ') type_start += 1;
        if (type_start < line.len and line[type_start] == '?') type_start += 1;
        const ts = type_start;
        var type_end = ts;
        while (type_end < line.len and (std.ascii.isAlphanumeric(line[type_end]) or line[type_end] == '_' or line[type_end] == '\\' or line[type_end] == '|')) {
            type_end += 1;
        }
        if (type_end > ts) {
            return_type = try allocator.dupe(u8, line[ts..type_end]);
        }
    }

    return base.FunctionDecl{
        .name = try allocator.dupe(u8, name),
        .line = line_num,
        .is_async = false, // PHP doesn't have native async keyword on functions
        .is_public = is_public,
        .return_type = return_type,
        .has_error_handling = false,
    };
}

test "php: parse class" {
    const allocator = std.testing.allocator;
    var s = try parse(allocator, "class UserController {");
    defer s.deinit();
    try std.testing.expectEqual(@as(usize, 1), s.types.items.len);
    try std.testing.expectEqualStrings("UserController", s.types.items[0].name);
}

test "php: parse interface" {
    const allocator = std.testing.allocator;
    var s = try parse(allocator, "interface RepositoryInterface {");
    defer s.deinit();
    try std.testing.expectEqual(@as(usize, 1), s.types.items.len);
    try std.testing.expectEqualStrings("RepositoryInterface", s.types.items[0].name);
    try std.testing.expectEqual(base.TypeDecl.TypeKind.interface_type, s.types.items[0].kind);
}

test "php: parse trait" {
    const allocator = std.testing.allocator;
    var s = try parse(allocator, "trait Timestampable {");
    defer s.deinit();
    try std.testing.expectEqual(@as(usize, 1), s.types.items.len);
    try std.testing.expectEqualStrings("Timestampable", s.types.items[0].name);
}

test "php: parse use statement" {
    const allocator = std.testing.allocator;
    var s = try parse(allocator, "use App\\Models\\User;");
    defer s.deinit();
    try std.testing.expectEqual(@as(usize, 1), s.imports.items.len);
    try std.testing.expectEqualStrings("App\\Models\\User", s.imports.items[0].module);
}

test "php: parse function" {
    const allocator = std.testing.allocator;
    var s = try parse(allocator, "    public function getUser(int $id): User {");
    defer s.deinit();
    try std.testing.expectEqual(@as(usize, 1), s.functions.items.len);
    try std.testing.expectEqualStrings("getUser", s.functions.items[0].name);
}

test "php: parse namespace" {
    const allocator = std.testing.allocator;
    var s = try parse(allocator, "namespace App\\Http\\Controllers;");
    defer s.deinit();
    try std.testing.expectEqual(@as(usize, 1), s.imports.items.len);
    try std.testing.expectEqualStrings("App\\Http\\Controllers", s.imports.items[0].module);
}

test "php: skip php tag" {
    const allocator = std.testing.allocator;
    var s = try parse(allocator,
        \\<?php
        \\class Foo {
        \\}
    );
    defer s.deinit();
    try std.testing.expectEqual(@as(usize, 1), s.types.items.len);
    try std.testing.expectEqualStrings("Foo", s.types.items[0].name);
}

test "php: parse abstract class" {
    const allocator = std.testing.allocator;
    var s = try parse(allocator, "abstract class BaseController {");
    defer s.deinit();
    try std.testing.expectEqual(@as(usize, 1), s.types.items.len);
    try std.testing.expectEqualStrings("BaseController", s.types.items[0].name);
    try std.testing.expectEqual(base.TypeDecl.TypeKind.class_type, s.types.items[0].kind);
}

test "php: parse enum" {
    const allocator = std.testing.allocator;
    var s = try parse(allocator, "enum Suit: string {");
    defer s.deinit();
    try std.testing.expectEqual(@as(usize, 1), s.types.items.len);
    try std.testing.expectEqualStrings("Suit", s.types.items[0].name);
    try std.testing.expectEqual(base.TypeDecl.TypeKind.enum_type, s.types.items[0].kind);
}

test "php: parse function with union return type" {
    const allocator = std.testing.allocator;
    var s = try parse(allocator, "    public function getValue(): int|string {");
    defer s.deinit();
    try std.testing.expectEqual(@as(usize, 1), s.functions.items.len);
    try std.testing.expectEqualStrings("getValue", s.functions.items[0].name);
    try std.testing.expectEqualStrings("int|string", s.functions.items[0].return_type.?);
}

test "php: parse require_once" {
    const allocator = std.testing.allocator;
    var s = try parse(allocator, "require_once 'config.php';");
    defer s.deinit();
    try std.testing.expectEqual(@as(usize, 1), s.imports.items.len);
    try std.testing.expectEqualStrings("config.php", s.imports.items[0].module);
}

test "php: skip comment" {
    const allocator = std.testing.allocator;
    var s = try parse(allocator, "// function notReal() {");
    defer s.deinit();
    try std.testing.expectEqual(@as(usize, 0), s.functions.items.len);
}
