// Swift extractor using line-by-line parsing
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
        // Parse struct definitions
        else if (std.mem.indexOf(u8, trimmed, "struct ") != null) {
            if (try parseTypeByKeyword(allocator, trimmed, "struct ", line_num, .struct_type)) |type_decl| {
                try structure.types.append(allocator, type_decl);
            }
        }
        // Parse enum definitions
        else if (std.mem.indexOf(u8, trimmed, "enum ") != null) {
            if (try parseTypeByKeyword(allocator, trimmed, "enum ", line_num, .enum_type)) |type_decl| {
                try structure.types.append(allocator, type_decl);
            }
        }
        // Parse protocol definitions
        else if (std.mem.indexOf(u8, trimmed, "protocol ") != null) {
            if (try parseTypeByKeyword(allocator, trimmed, "protocol ", line_num, .interface_type)) |type_decl| {
                try structure.types.append(allocator, type_decl);
            }
        }
        // Parse actor definitions
        else if (std.mem.indexOf(u8, trimmed, "actor ") != null) {
            if (try parseTypeByKeyword(allocator, trimmed, "actor ", line_num, .class_type)) |type_decl| {
                try structure.types.append(allocator, type_decl);
            }
        }
        // Parse function definitions
        else if (std.mem.indexOf(u8, trimmed, "func ") != null) {
            if (try parseFunction(allocator, trimmed, line_num)) |func_decl| {
                try structure.functions.append(allocator, func_decl);
            }
        }
    }

    return structure;
}

fn parseImport(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.ImportDecl {
    if (!std.mem.startsWith(u8, line, "import ")) return null;

    var end: usize = 7;
    while (end < line.len and line[end] != '\n' and line[end] != ';') end += 1;
    if (end <= 7) return null;

    const module = std.mem.trim(u8, line[7..end], " \t");
    if (module.len == 0) return null;

    return base.ImportDecl{
        .module = try allocator.dupe(u8, module),
        .line = line_num,
    };
}

fn parseClass(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.TypeDecl {
    // Check for "final class"
    if (std.mem.indexOf(u8, line, "final class ")) |pos| {
        return try extractName(allocator, line, pos + 12, line_num, .class_type);
    }
    // Regular class
    if (std.mem.indexOf(u8, line, "class ")) |pos| {
        // Skip "enum class" — not valid Swift, but guard
        if (pos >= 5 and std.mem.eql(u8, line[pos - 5 .. pos], "enum ")) return null;
        // Skip "func" before "class" (e.g. "class func")
        if (pos >= 5 and std.mem.eql(u8, line[pos - 5 .. pos], "func ")) return null;
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
    const func_pos = std.mem.indexOf(u8, line, "func ") orelse return null;

    var name_start = func_pos + 5;
    while (name_start < line.len and line[name_start] == ' ') name_start += 1;

    var name_end = name_start;
    while (name_end < line.len and (std.ascii.isAlphanumeric(line[name_end]) or line[name_end] == '_')) {
        name_end += 1;
    }
    if (name_end <= name_start) return null;

    const name = line[name_start..name_end];
    // Skip Swift keywords
    if (std.mem.eql(u8, name, "class") or std.mem.eql(u8, name, "struct") or
        std.mem.eql(u8, name, "enum") or std.mem.eql(u8, name, "protocol"))
    {
        return null;
    }

    const before_func = line[0..func_pos];

    // Determine visibility
    const is_public = std.mem.indexOf(u8, before_func, "public ") != null or
        std.mem.indexOf(u8, before_func, "open ") != null;

    // Detect async
    const is_async = std.mem.indexOf(u8, line, "async ") != null or
        std.mem.indexOf(u8, line, " async") != null;

    // Extract return type after ->
    var return_type: ?[]const u8 = null;
    if (std.mem.indexOf(u8, line, "->")) |arrow_pos| {
        var type_start = arrow_pos + 2;
        while (type_start < line.len and line[type_start] == ' ') type_start += 1;
        const ts = type_start;
        var type_end = ts;
        var angle_depth: u32 = 0;
        while (type_end < line.len) {
            if (line[type_end] == '<') angle_depth += 1;
            if (line[type_end] == '>') {
                if (angle_depth > 0) angle_depth -= 1;
            }
            if (angle_depth == 0 and (line[type_end] == '{' or line[type_end] == '\n' or line[type_end] == ' ')) break;
            type_end += 1;
        }
        if (type_end > ts) {
            const rt = std.mem.trim(u8, line[ts..type_end], " \t");
            if (rt.len > 0) {
                return_type = try allocator.dupe(u8, rt);
            }
        }
    }

    // Check for throws
    const has_error_handling = std.mem.indexOf(u8, line, "throws") != null or
        std.mem.indexOf(u8, line, "rethrows") != null;

    return base.FunctionDecl{
        .name = try allocator.dupe(u8, name),
        .line = line_num,
        .is_async = is_async,
        .is_public = is_public,
        .return_type = return_type,
        .has_error_handling = has_error_handling,
    };
}

test "swift: parse class" {
    const allocator = std.testing.allocator;
    var s = try parse(allocator, "class ViewController: UIViewController {");
    defer s.deinit();
    try std.testing.expectEqual(@as(usize, 1), s.types.items.len);
    try std.testing.expectEqualStrings("ViewController", s.types.items[0].name);
}

test "swift: parse struct" {
    const allocator = std.testing.allocator;
    var s = try parse(allocator, "struct Point {");
    defer s.deinit();
    try std.testing.expectEqual(@as(usize, 1), s.types.items.len);
    try std.testing.expectEqualStrings("Point", s.types.items[0].name);
    try std.testing.expectEqual(base.TypeDecl.TypeKind.struct_type, s.types.items[0].kind);
}

test "swift: parse protocol" {
    const allocator = std.testing.allocator;
    var s = try parse(allocator, "protocol Drawable {");
    defer s.deinit();
    try std.testing.expectEqual(@as(usize, 1), s.types.items.len);
    try std.testing.expectEqualStrings("Drawable", s.types.items[0].name);
    try std.testing.expectEqual(base.TypeDecl.TypeKind.interface_type, s.types.items[0].kind);
}

test "swift: parse import" {
    const allocator = std.testing.allocator;
    var s = try parse(allocator, "import Foundation");
    defer s.deinit();
    try std.testing.expectEqual(@as(usize, 1), s.imports.items.len);
    try std.testing.expectEqualStrings("Foundation", s.imports.items[0].module);
}

test "swift: parse async func" {
    const allocator = std.testing.allocator;
    var s = try parse(allocator, "    func fetchData() async throws -> [String] {");
    defer s.deinit();
    try std.testing.expectEqual(@as(usize, 1), s.functions.items.len);
    try std.testing.expectEqualStrings("fetchData", s.functions.items[0].name);
    try std.testing.expect(s.functions.items[0].is_async);
    try std.testing.expect(s.functions.items[0].has_error_handling);
}

test "swift: parse enum" {
    const allocator = std.testing.allocator;
    var s = try parse(allocator, "enum Direction: CaseIterable {");
    defer s.deinit();
    try std.testing.expectEqual(@as(usize, 1), s.types.items.len);
    try std.testing.expectEqualStrings("Direction", s.types.items[0].name);
    try std.testing.expectEqual(base.TypeDecl.TypeKind.enum_type, s.types.items[0].kind);
}

test "swift: parse actor" {
    const allocator = std.testing.allocator;
    var s = try parse(allocator, "actor ImageDownloader {");
    defer s.deinit();
    try std.testing.expectEqual(@as(usize, 1), s.types.items.len);
    try std.testing.expectEqualStrings("ImageDownloader", s.types.items[0].name);
}
