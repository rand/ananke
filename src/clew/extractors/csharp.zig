// C# extractor using line-by-line parsing
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

        // Parse using directives
        if (std.mem.startsWith(u8, trimmed, "using ")) {
            if (try parseUsing(allocator, trimmed, line_num)) |import_decl| {
                try structure.imports.append(allocator, import_decl);
            }
        }
        // Parse namespace as import context
        else if (std.mem.startsWith(u8, trimmed, "namespace ")) {
            if (try parseNamespace(allocator, trimmed, line_num)) |import_decl| {
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
        // Parse interface definitions
        else if (std.mem.indexOf(u8, trimmed, "interface ") != null) {
            if (try parseTypeByKeyword(allocator, trimmed, "interface ", line_num, .interface_type)) |type_decl| {
                try structure.types.append(allocator, type_decl);
            }
        }
        // Parse enum definitions
        else if (std.mem.indexOf(u8, trimmed, "enum ") != null) {
            if (try parseTypeByKeyword(allocator, trimmed, "enum ", line_num, .enum_type)) |type_decl| {
                try structure.types.append(allocator, type_decl);
            }
        }
        // Parse record definitions
        else if (std.mem.indexOf(u8, trimmed, "record ") != null) {
            if (try parseTypeByKeyword(allocator, trimmed, "record ", line_num, .struct_type)) |type_decl| {
                try structure.types.append(allocator, type_decl);
            }
        }
        // Parse methods
        else if (try parseMethod(allocator, trimmed, line_num)) |func_decl| {
            try structure.functions.append(allocator, func_decl);
        }
    }

    return structure;
}

fn parseUsing(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.ImportDecl {
    if (!std.mem.startsWith(u8, line, "using ")) return null;
    // Skip "using static" and "using var" (disposable pattern)
    var start: usize = 6;
    if (std.mem.startsWith(u8, line[start..], "static ")) start += 7;

    var end = start;
    while (end < line.len and line[end] != ';' and line[end] != '\n') end += 1;
    if (end <= start) return null;

    const module = std.mem.trim(u8, line[start..end], " \t");
    // Skip alias usings like "using Alias = Namespace"
    if (std.mem.indexOf(u8, module, " = ") != null) return null;
    if (module.len == 0) return null;

    return base.ImportDecl{
        .module = try allocator.dupe(u8, module),
        .line = line_num,
    };
}

fn parseNamespace(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.ImportDecl {
    if (!std.mem.startsWith(u8, line, "namespace ")) return null;

    var end: usize = 10;
    while (end < line.len and line[end] != '{' and line[end] != ';' and line[end] != '\n') end += 1;
    if (end <= 10) return null;

    const module = std.mem.trim(u8, line[10..end], " \t");
    if (module.len == 0) return null;

    return base.ImportDecl{
        .module = try allocator.dupe(u8, module),
        .line = line_num,
    };
}

fn parseClass(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.TypeDecl {
    const pos = std.mem.indexOf(u8, line, "class ") orelse return null;
    // Avoid matching "enum class" — not valid in C#, but guard anyway
    return try extractName(allocator, line, pos + 6, line_num, .class_type);
}

fn parseStruct(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.TypeDecl {
    const pos = std.mem.indexOf(u8, line, "struct ") orelse return null;
    return try extractName(allocator, line, pos + 7, line_num, .struct_type);
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

fn parseMethod(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.FunctionDecl {
    const paren_pos = std.mem.indexOf(u8, line, "(") orelse return null;
    if (paren_pos == 0) return null;

    // Skip control flow, attributes, constructors
    if (std.mem.indexOf(u8, line, "if ") != null or
        std.mem.indexOf(u8, line, "if(") != null or
        std.mem.indexOf(u8, line, "while ") != null or
        std.mem.indexOf(u8, line, "for ") != null or
        std.mem.indexOf(u8, line, "foreach ") != null or
        std.mem.indexOf(u8, line, "switch ") != null or
        std.mem.indexOf(u8, line, "return ") != null or
        std.mem.indexOf(u8, line, "catch ") != null or
        std.mem.indexOf(u8, line, "new ") != null or
        std.mem.startsWith(u8, line, "["))
    {
        return null;
    }

    // Find method name (word before parenthesis)
    var name_end = paren_pos;
    while (name_end > 0 and line[name_end - 1] == ' ') name_end -= 1;
    // Skip generic parameters
    if (name_end > 0 and line[name_end - 1] == '>') {
        var depth: u32 = 1;
        name_end -= 1;
        while (name_end > 0 and depth > 0) {
            name_end -= 1;
            if (line[name_end] == '>') depth += 1;
            if (line[name_end] == '<') depth -= 1;
        }
    }

    var name_start = name_end;
    while (name_start > 0 and (std.ascii.isAlphanumeric(line[name_start - 1]) or line[name_start - 1] == '_')) {
        name_start -= 1;
    }
    if (name_end <= name_start) return null;

    const name = line[name_start..name_end];
    // Skip C# keywords
    if (std.mem.eql(u8, name, "class") or
        std.mem.eql(u8, name, "struct") or
        std.mem.eql(u8, name, "interface") or
        std.mem.eql(u8, name, "enum") or
        std.mem.eql(u8, name, "record") or
        std.mem.eql(u8, name, "new") or
        std.mem.eql(u8, name, "base") or
        std.mem.eql(u8, name, "this") or
        std.mem.eql(u8, name, "namespace") or
        std.mem.eql(u8, name, "using"))
    {
        return null;
    }

    const is_public = std.mem.indexOf(u8, line[0..name_start], "public ") != null;
    const is_async = std.mem.indexOf(u8, line, "async ") != null or
        std.mem.indexOf(u8, line, "Task<") != null or
        std.mem.indexOf(u8, line, "Task ") != null or
        std.mem.indexOf(u8, line, "ValueTask") != null;

    // Extract return type
    var return_type: ?[]const u8 = null;
    if (name_start > 0) {
        var type_end = name_start;
        while (type_end > 0 and line[type_end - 1] == ' ') type_end -= 1;

        var type_start = type_end;
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
            if (type_str.len > 0 and
                !std.mem.eql(u8, type_str, "public") and
                !std.mem.eql(u8, type_str, "private") and
                !std.mem.eql(u8, type_str, "protected") and
                !std.mem.eql(u8, type_str, "internal") and
                !std.mem.eql(u8, type_str, "static") and
                !std.mem.eql(u8, type_str, "virtual") and
                !std.mem.eql(u8, type_str, "override") and
                !std.mem.eql(u8, type_str, "abstract") and
                !std.mem.eql(u8, type_str, "async") and
                !std.mem.eql(u8, type_str, "sealed"))
            {
                return_type = try allocator.dupe(u8, type_str);
            }
        }
    }

    const has_error_handling = std.mem.indexOf(u8, line, "throws ") != null or
        std.mem.indexOf(u8, line, "Exception") != null;

    return base.FunctionDecl{
        .name = try allocator.dupe(u8, name),
        .line = line_num,
        .is_async = is_async,
        .is_public = is_public,
        .return_type = return_type,
        .has_error_handling = has_error_handling,
    };
}

test "csharp: parse class" {
    const allocator = std.testing.allocator;
    var s = try parse(allocator, "public class UserService {");
    defer s.deinit();
    try std.testing.expectEqual(@as(usize, 1), s.types.items.len);
    try std.testing.expectEqualStrings("UserService", s.types.items[0].name);
}

test "csharp: parse interface" {
    const allocator = std.testing.allocator;
    var s = try parse(allocator, "public interface IRepository<T> {");
    defer s.deinit();
    try std.testing.expectEqual(@as(usize, 1), s.types.items.len);
    try std.testing.expectEqualStrings("IRepository", s.types.items[0].name);
}

test "csharp: parse using" {
    const allocator = std.testing.allocator;
    var s = try parse(allocator, "using System.Collections.Generic;");
    defer s.deinit();
    try std.testing.expectEqual(@as(usize, 1), s.imports.items.len);
    try std.testing.expectEqualStrings("System.Collections.Generic", s.imports.items[0].module);
}

test "csharp: parse async method" {
    const allocator = std.testing.allocator;
    var s = try parse(allocator, "    public async Task<string> GetDataAsync(int id) {");
    defer s.deinit();
    try std.testing.expectEqual(@as(usize, 1), s.functions.items.len);
    try std.testing.expectEqualStrings("GetDataAsync", s.functions.items[0].name);
    try std.testing.expect(s.functions.items[0].is_async);
}

test "csharp: parse record" {
    const allocator = std.testing.allocator;
    var s = try parse(allocator, "public record Person(string Name, int Age);");
    defer s.deinit();
    try std.testing.expectEqual(@as(usize, 1), s.types.items.len);
    try std.testing.expectEqualStrings("Person", s.types.items[0].name);
}

test "csharp: parse struct" {
    const allocator = std.testing.allocator;
    var s = try parse(allocator, "public struct Point {");
    defer s.deinit();
    try std.testing.expectEqual(@as(usize, 1), s.types.items.len);
    try std.testing.expectEqualStrings("Point", s.types.items[0].name);
    try std.testing.expectEqual(base.TypeDecl.TypeKind.struct_type, s.types.items[0].kind);
}
