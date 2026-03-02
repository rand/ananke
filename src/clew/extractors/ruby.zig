// Ruby extractor using line-by-line parsing
const std = @import("std");
const base = @import("base.zig");

pub fn parse(allocator: std.mem.Allocator, source: []const u8) !base.SyntaxStructure {
    var structure = base.SyntaxStructure.init(allocator);
    errdefer structure.deinit();

    var line_num: u32 = 1;
    var lines = std.mem.splitScalar(u8, source, '\n');
    var visibility_private = false;

    while (lines.next()) |line| : (line_num += 1) {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0 or std.mem.startsWith(u8, trimmed, "#")) continue;

        // Track visibility modifiers
        if (std.mem.eql(u8, trimmed, "private") or std.mem.eql(u8, trimmed, "protected")) {
            visibility_private = true;
            continue;
        }
        if (std.mem.eql(u8, trimmed, "public")) {
            visibility_private = false;
            continue;
        }

        // Parse require/require_relative
        if (std.mem.startsWith(u8, trimmed, "require ") or std.mem.startsWith(u8, trimmed, "require_relative ")) {
            if (try parseRequire(allocator, trimmed, line_num)) |import_decl| {
                try structure.imports.append(allocator, import_decl);
            }
        }
        // Parse include/extend
        else if (std.mem.startsWith(u8, trimmed, "include ") or std.mem.startsWith(u8, trimmed, "extend ")) {
            if (try parseInclude(allocator, trimmed, line_num)) |import_decl| {
                try structure.imports.append(allocator, import_decl);
            }
        }
        // Parse class definitions
        else if (std.mem.startsWith(u8, trimmed, "class ")) {
            // Reset visibility on class boundary
            visibility_private = false;
            if (try parseClass(allocator, trimmed, line_num)) |type_decl| {
                try structure.types.append(allocator, type_decl);
            }
        }
        // Parse module definitions
        else if (std.mem.startsWith(u8, trimmed, "module ")) {
            // Reset visibility on module boundary
            visibility_private = false;
            if (try parseModule(allocator, trimmed, line_num)) |type_decl| {
                try structure.types.append(allocator, type_decl);
            }
        }
        // Parse attr_accessor/reader/writer
        else if (std.mem.startsWith(u8, trimmed, "attr_accessor ") or
            std.mem.startsWith(u8, trimmed, "attr_reader ") or
            std.mem.startsWith(u8, trimmed, "attr_writer "))
        {
            if (try parseAttr(allocator, trimmed, line_num)) |func_decl| {
                try structure.functions.append(allocator, func_decl);
            }
        }
        // Parse method definitions
        else if (std.mem.startsWith(u8, trimmed, "def ")) {
            if (try parseMethod(allocator, trimmed, line_num)) |func_decl_val| {
                var func_decl = func_decl_val;
                if (visibility_private) func_decl.is_public = false;
                try structure.functions.append(allocator, func_decl);
            }
        }
    }

    return structure;
}

fn parseRequire(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.ImportDecl {
    var start: usize = 0;
    if (std.mem.startsWith(u8, line, "require_relative ")) {
        start = 17;
    } else if (std.mem.startsWith(u8, line, "require ")) {
        start = 8;
    } else {
        return null;
    }

    // Skip quotes
    if (start < line.len and (line[start] == '\'' or line[start] == '"')) start += 1;

    var end = start;
    while (end < line.len and line[end] != '\'' and line[end] != '"' and line[end] != '\n') end += 1;
    if (end <= start) return null;

    const module = std.mem.trim(u8, line[start..end], " \t");
    if (module.len == 0) return null;

    return base.ImportDecl{
        .module = try allocator.dupe(u8, module),
        .line = line_num,
    };
}

fn parseInclude(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.ImportDecl {
    var start: usize = 0;
    if (std.mem.startsWith(u8, line, "include ")) {
        start = 8;
    } else if (std.mem.startsWith(u8, line, "extend ")) {
        start = 7;
    } else {
        return null;
    }

    var end = start;
    while (end < line.len and line[end] != '\n' and line[end] != '#') end += 1;

    const module = std.mem.trim(u8, line[start..end], " \t");
    if (module.len == 0) return null;

    return base.ImportDecl{
        .module = try allocator.dupe(u8, module),
        .line = line_num,
    };
}

fn parseClass(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.TypeDecl {
    if (!std.mem.startsWith(u8, line, "class ")) return null;

    var name_start: usize = 6;
    while (name_start < line.len and line[name_start] == ' ') name_start += 1;

    var name_end = name_start;
    while (name_end < line.len and (std.ascii.isAlphanumeric(line[name_end]) or line[name_end] == '_')) {
        name_end += 1;
    }
    if (name_end <= name_start) return null;

    // Skip if keyword "end" or "self"
    const name = line[name_start..name_end];
    if (std.mem.eql(u8, name, "end") or std.mem.eql(u8, name, "self")) return null;

    return base.TypeDecl{
        .name = try allocator.dupe(u8, name),
        .line = line_num,
        .kind = .class_type,
    };
}

fn parseModule(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.TypeDecl {
    if (!std.mem.startsWith(u8, line, "module ")) return null;

    var name_start: usize = 7;
    while (name_start < line.len and line[name_start] == ' ') name_start += 1;

    var name_end = name_start;
    while (name_end < line.len and (std.ascii.isAlphanumeric(line[name_end]) or line[name_end] == '_')) {
        name_end += 1;
    }
    if (name_end <= name_start) return null;

    return base.TypeDecl{
        .name = try allocator.dupe(u8, line[name_start..name_end]),
        .line = line_num,
        .kind = .class_type, // Ruby modules are closest to class_type
    };
}

fn parseMethod(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.FunctionDecl {
    if (!std.mem.startsWith(u8, line, "def ")) return null;

    var name_start: usize = 4;
    while (name_start < line.len and line[name_start] == ' ') name_start += 1;

    // Check for self. prefix (class method)
    const is_class_method = name_start + 5 <= line.len and std.mem.eql(u8, line[name_start .. name_start + 5], "self.");
    if (is_class_method) name_start += 5;

    var name_end = name_start;
    while (name_end < line.len and (std.ascii.isAlphanumeric(line[name_end]) or line[name_end] == '_' or line[name_end] == '?' or line[name_end] == '!' or line[name_end] == '=')) {
        name_end += 1;
    }
    if (name_end <= name_start) return null;

    const name = line[name_start..name_end];
    if (std.mem.eql(u8, name, "end")) return null;

    return base.FunctionDecl{
        .name = try allocator.dupe(u8, name),
        .line = line_num,
        .is_public = !std.mem.startsWith(u8, line, "def _"), // Convention: _ prefix is private
        .is_async = false, // Ruby doesn't have native async keyword
        .return_type = null, // Ruby is dynamically typed
        .has_error_handling = false,
    };
}

fn parseAttr(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.FunctionDecl {
    var start: usize = 0;
    if (std.mem.startsWith(u8, line, "attr_accessor ")) {
        start = 14;
    } else if (std.mem.startsWith(u8, line, "attr_reader ")) {
        start = 12;
    } else if (std.mem.startsWith(u8, line, "attr_writer ")) {
        start = 12;
    } else {
        return null;
    }
    // Skip the colon prefix
    if (start < line.len and line[start] == ':') start += 1;

    var name_end = start;
    while (name_end < line.len and (std.ascii.isAlphanumeric(line[name_end]) or line[name_end] == '_')) {
        name_end += 1;
    }
    if (name_end <= start) return null;

    return base.FunctionDecl{
        .name = try allocator.dupe(u8, line[start..name_end]),
        .line = line_num,
        .is_public = true,
        .is_async = false,
        .return_type = null,
        .has_error_handling = false,
    };
}

test "ruby: parse class" {
    const allocator = std.testing.allocator;
    var s = try parse(allocator, "class UserService");
    defer s.deinit();
    try std.testing.expectEqual(@as(usize, 1), s.types.items.len);
    try std.testing.expectEqualStrings("UserService", s.types.items[0].name);
}

test "ruby: parse module" {
    const allocator = std.testing.allocator;
    var s = try parse(allocator, "module Authentication");
    defer s.deinit();
    try std.testing.expectEqual(@as(usize, 1), s.types.items.len);
    try std.testing.expectEqualStrings("Authentication", s.types.items[0].name);
}

test "ruby: parse require" {
    const allocator = std.testing.allocator;
    var s = try parse(allocator, "require 'json'");
    defer s.deinit();
    try std.testing.expectEqual(@as(usize, 1), s.imports.items.len);
    try std.testing.expectEqualStrings("json", s.imports.items[0].module);
}

test "ruby: parse def method" {
    const allocator = std.testing.allocator;
    var s = try parse(allocator, "def calculate_total(items)");
    defer s.deinit();
    try std.testing.expectEqual(@as(usize, 1), s.functions.items.len);
    try std.testing.expectEqualStrings("calculate_total", s.functions.items[0].name);
}

test "ruby: parse class method" {
    const allocator = std.testing.allocator;
    var s = try parse(allocator, "def self.find_by_name(name)");
    defer s.deinit();
    try std.testing.expectEqual(@as(usize, 1), s.functions.items.len);
    try std.testing.expectEqualStrings("find_by_name", s.functions.items[0].name);
}

test "ruby: parse class with inheritance" {
    const allocator = std.testing.allocator;
    var s = try parse(allocator,
        \\class Admin < User
        \\  def permissions
        \\  end
        \\end
    );
    defer s.deinit();
    try std.testing.expectEqual(@as(usize, 1), s.types.items.len);
    try std.testing.expectEqualStrings("Admin", s.types.items[0].name);
    try std.testing.expectEqual(@as(usize, 1), s.functions.items.len);
    try std.testing.expectEqualStrings("permissions", s.functions.items[0].name);
}

test "ruby: parse require_relative" {
    const allocator = std.testing.allocator;
    var s = try parse(allocator, "require_relative 'helpers/auth'");
    defer s.deinit();
    try std.testing.expectEqual(@as(usize, 1), s.imports.items.len);
    try std.testing.expectEqualStrings("helpers/auth", s.imports.items[0].module);
}

test "ruby: parse include" {
    const allocator = std.testing.allocator;
    var s = try parse(allocator, "include Comparable");
    defer s.deinit();
    try std.testing.expectEqual(@as(usize, 1), s.imports.items.len);
    try std.testing.expectEqualStrings("Comparable", s.imports.items[0].module);
}

test "ruby: parse attr_accessor" {
    const allocator = std.testing.allocator;
    var s = try parse(allocator, "attr_accessor :name");
    defer s.deinit();
    try std.testing.expectEqual(@as(usize, 1), s.functions.items.len);
    try std.testing.expectEqualStrings("name", s.functions.items[0].name);
}

test "ruby: parse private method" {
    const allocator = std.testing.allocator;
    var s = try parse(allocator,
        \\private
        \\def secret
    );
    defer s.deinit();
    try std.testing.expectEqual(@as(usize, 1), s.functions.items.len);
    try std.testing.expectEqualStrings("secret", s.functions.items[0].name);
    try std.testing.expect(!s.functions.items[0].is_public);
}

test "ruby: parse method with special chars" {
    const allocator = std.testing.allocator;
    var s = try parse(allocator, "def valid?");
    defer s.deinit();
    try std.testing.expectEqual(@as(usize, 1), s.functions.items.len);
    try std.testing.expectEqualStrings("valid?", s.functions.items[0].name);
}

test "ruby: skip comment" {
    const allocator = std.testing.allocator;
    var s = try parse(allocator, "# def not_real");
    defer s.deinit();
    try std.testing.expectEqual(@as(usize, 0), s.functions.items.len);
}
