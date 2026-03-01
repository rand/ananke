// Kotlin extractor using line-by-line parsing
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
        // Parse package declarations as imports
        else if (std.mem.startsWith(u8, trimmed, "package ")) {
            if (try parsePackage(allocator, trimmed, line_num)) |import_decl| {
                try structure.imports.append(allocator, import_decl);
            }
        }
        // Parse data class / sealed class / class
        else if (std.mem.indexOf(u8, trimmed, "class ") != null) {
            if (try parseClass(allocator, trimmed, line_num)) |type_decl| {
                try structure.types.append(allocator, type_decl);
            }
        }
        // Parse interface
        else if (std.mem.indexOf(u8, trimmed, "interface ") != null) {
            if (try parseInterface(allocator, trimmed, line_num)) |type_decl| {
                try structure.types.append(allocator, type_decl);
            }
        }
        // Parse enum class
        else if (std.mem.indexOf(u8, trimmed, "enum class ") != null) {
            if (try parseEnumClass(allocator, trimmed, line_num)) |type_decl| {
                try structure.types.append(allocator, type_decl);
            }
        }
        // Parse object declarations
        else if (std.mem.startsWith(u8, trimmed, "object ") or std.mem.indexOf(u8, trimmed, " object ") != null) {
            if (try parseObject(allocator, trimmed, line_num)) |type_decl| {
                try structure.types.append(allocator, type_decl);
            }
        }
        // Parse functions
        else if (std.mem.indexOf(u8, trimmed, "fun ") != null) {
            if (try parseFunction(allocator, trimmed, line_num)) |func_decl| {
                try structure.functions.append(allocator, func_decl);
            }
        }
    }

    return structure;
}

fn parseImport(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.ImportDecl {
    if (!std.mem.startsWith(u8, line, "import ")) return null;

    var name_end: usize = 7;
    while (name_end < line.len and line[name_end] != '\n' and line[name_end] != ';') {
        name_end += 1;
    }
    if (name_end <= 7) return null;

    const module = std.mem.trim(u8, line[7..name_end], " \t");
    const is_wildcard = std.mem.endsWith(u8, module, ".*");

    return base.ImportDecl{
        .module = try allocator.dupe(u8, module),
        .line = line_num,
        .is_wildcard = is_wildcard,
    };
}

fn parsePackage(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.ImportDecl {
    if (!std.mem.startsWith(u8, line, "package ")) return null;

    var name_end: usize = 8;
    while (name_end < line.len and line[name_end] != '\n' and line[name_end] != ';') {
        name_end += 1;
    }
    if (name_end <= 8) return null;

    const module = std.mem.trim(u8, line[8..name_end], " \t");

    return base.ImportDecl{
        .module = try allocator.dupe(u8, module),
        .line = line_num,
    };
}

fn parseClass(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.TypeDecl {
    // Check for data class
    if (std.mem.indexOf(u8, line, "data class ")) |pos| {
        return try extractClassName(allocator, line, pos + 11, line_num, .class_type);
    }
    // Check for sealed class
    if (std.mem.indexOf(u8, line, "sealed class ")) |pos| {
        return try extractClassName(allocator, line, pos + 13, line_num, .class_type);
    }
    // Check for abstract class
    if (std.mem.indexOf(u8, line, "abstract class ")) |pos| {
        return try extractClassName(allocator, line, pos + 15, line_num, .class_type);
    }
    // Check for open class
    if (std.mem.indexOf(u8, line, "open class ")) |pos| {
        return try extractClassName(allocator, line, pos + 11, line_num, .class_type);
    }
    // Regular class
    if (std.mem.indexOf(u8, line, "class ")) |pos| {
        // Skip "enum class" (handled separately)
        if (pos >= 5 and std.mem.eql(u8, line[pos - 5 .. pos], "enum ")) return null;
        return try extractClassName(allocator, line, pos + 6, line_num, .class_type);
    }
    return null;
}

fn parseInterface(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.TypeDecl {
    const pos = std.mem.indexOf(u8, line, "interface ") orelse return null;
    return try extractClassName(allocator, line, pos + 10, line_num, .interface_type);
}

fn parseEnumClass(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.TypeDecl {
    const pos = std.mem.indexOf(u8, line, "enum class ") orelse return null;
    return try extractClassName(allocator, line, pos + 11, line_num, .enum_type);
}

fn parseObject(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.TypeDecl {
    // Skip "companion object"
    if (std.mem.indexOf(u8, line, "companion object") != null) return null;

    const pos = if (std.mem.startsWith(u8, line, "object "))
        @as(usize, 7)
    else if (std.mem.indexOf(u8, line, " object ")) |p|
        p + 8
    else
        return null;

    return try extractClassName(allocator, line, pos, line_num, .class_type);
}

fn extractClassName(allocator: std.mem.Allocator, line: []const u8, start: usize, line_num: u32, kind: base.TypeDecl.TypeKind) !?base.TypeDecl {
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
    const fun_pos = std.mem.indexOf(u8, line, "fun ") orelse return null;

    // Check for suspend fun
    const is_suspend = fun_pos >= 8 and std.mem.indexOf(u8, line[0..fun_pos], "suspend ") != null;

    var name_start = fun_pos + 4;
    // Skip generic type parameters like <T>
    while (name_start < line.len and line[name_start] == ' ') name_start += 1;
    if (name_start < line.len and line[name_start] == '<') {
        var depth: u32 = 1;
        name_start += 1;
        while (name_start < line.len and depth > 0) {
            if (line[name_start] == '<') depth += 1;
            if (line[name_start] == '>') depth -= 1;
            name_start += 1;
        }
        while (name_start < line.len and line[name_start] == ' ') name_start += 1;
    }

    // Extension function: skip receiver type before the dot
    var actual_start = name_start;
    // Look for Type.functionName pattern
    var scan = name_start;
    while (scan < line.len and line[scan] != '(' and line[scan] != ' ') {
        if (line[scan] == '.') {
            actual_start = scan + 1;
        }
        scan += 1;
    }

    var name_end = actual_start;
    while (name_end < line.len and (std.ascii.isAlphanumeric(line[name_end]) or line[name_end] == '_')) {
        name_end += 1;
    }
    if (name_end <= actual_start) return null;

    const is_public = std.mem.indexOf(u8, line[0..fun_pos], "private ") == null and
        std.mem.indexOf(u8, line[0..fun_pos], "internal ") == null and
        std.mem.indexOf(u8, line[0..fun_pos], "protected ") == null;

    // Extract return type after ): Type
    var return_type: ?[]const u8 = null;
    if (std.mem.indexOf(u8, line, "):")) |rp| {
        const type_start = rp + 2;
        var type_end = type_start;
        while (type_end < line.len and line[type_end] == ' ') type_end += 1;
        const ts = type_end;
        while (type_end < line.len and line[type_end] != '{' and line[type_end] != '=' and line[type_end] != '\n') {
            type_end += 1;
        }
        const rt = std.mem.trim(u8, line[ts..type_end], " \t");
        if (rt.len > 0 and !std.mem.eql(u8, rt, "{")) {
            return_type = try allocator.dupe(u8, rt);
        }
    } else if (std.mem.indexOf(u8, line, ") :")) |rp| {
        const type_start = rp + 3;
        var type_end = type_start;
        while (type_end < line.len and line[type_end] == ' ') type_end += 1;
        const ts = type_end;
        while (type_end < line.len and line[type_end] != '{' and line[type_end] != '=' and line[type_end] != '\n') {
            type_end += 1;
        }
        const rt = std.mem.trim(u8, line[ts..type_end], " \t");
        if (rt.len > 0 and !std.mem.eql(u8, rt, "{")) {
            return_type = try allocator.dupe(u8, rt);
        }
    }

    return base.FunctionDecl{
        .name = try allocator.dupe(u8, line[actual_start..name_end]),
        .line = line_num,
        .is_async = is_suspend or std.mem.indexOf(u8, line, "Deferred") != null or
            std.mem.indexOf(u8, line, "Flow<") != null,
        .is_public = is_public,
        .return_type = return_type,
        .has_error_handling = std.mem.indexOf(u8, line, "throws") != null or
            std.mem.indexOf(u8, line, "runCatching") != null,
    };
}

test "kotlin: parse basic class" {
    const allocator = std.testing.allocator;
    var s = try parse(allocator, "class MyClass {");
    defer s.deinit();
    try std.testing.expectEqual(@as(usize, 1), s.types.items.len);
    try std.testing.expectEqualStrings("MyClass", s.types.items[0].name);
}

test "kotlin: parse data class" {
    const allocator = std.testing.allocator;
    var s = try parse(allocator, "data class User(val name: String, val age: Int)");
    defer s.deinit();
    try std.testing.expectEqual(@as(usize, 1), s.types.items.len);
    try std.testing.expectEqualStrings("User", s.types.items[0].name);
}

test "kotlin: parse suspend fun" {
    const allocator = std.testing.allocator;
    var s = try parse(allocator, "suspend fun fetchData(): List<String> {");
    defer s.deinit();
    try std.testing.expectEqual(@as(usize, 1), s.functions.items.len);
    try std.testing.expectEqualStrings("fetchData", s.functions.items[0].name);
    try std.testing.expect(s.functions.items[0].is_async);
}

test "kotlin: parse import" {
    const allocator = std.testing.allocator;
    var s = try parse(allocator, "import kotlinx.coroutines.launch");
    defer s.deinit();
    try std.testing.expectEqual(@as(usize, 1), s.imports.items.len);
    try std.testing.expectEqualStrings("kotlinx.coroutines.launch", s.imports.items[0].module);
}

test "kotlin: parse sealed class" {
    const allocator = std.testing.allocator;
    var s = try parse(allocator,
        \\sealed class Result {
        \\    data class Success(val data: String) : Result()
        \\    data class Error(val message: String) : Result()
        \\}
    );
    defer s.deinit();
    try std.testing.expectEqual(@as(usize, 3), s.types.items.len);
    try std.testing.expectEqualStrings("Result", s.types.items[0].name);
}

test "kotlin: parse object declaration" {
    const allocator = std.testing.allocator;
    var s = try parse(allocator, "object Singleton {");
    defer s.deinit();
    try std.testing.expectEqual(@as(usize, 1), s.types.items.len);
    try std.testing.expectEqualStrings("Singleton", s.types.items[0].name);
}
