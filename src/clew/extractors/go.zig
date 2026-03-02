// Go extractor using line-by-line parsing
const std = @import("std");
const base = @import("base.zig");

pub fn parse(allocator: std.mem.Allocator, source: []const u8) !base.SyntaxStructure {
    var structure = base.SyntaxStructure.init(allocator);
    errdefer structure.deinit();

    var line_num: u32 = 1;
    var lines = std.mem.splitScalar(u8, source, '\n');
    var in_import_block = false;

    while (lines.next()) |line| : (line_num += 1) {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0 or std.mem.startsWith(u8, trimmed, "//")) continue;

        // Handle grouped import block lines
        if (in_import_block) {
            if (std.mem.startsWith(u8, trimmed, ")")) {
                in_import_block = false;
                continue;
            }
            // Each line in import block is a quoted package path
            if (try parseImportLine(allocator, trimmed, line_num)) |import_decl| {
                try structure.imports.append(allocator, import_decl);
            }
            continue;
        }

        // Parse imports
        if (std.mem.startsWith(u8, trimmed, "import ")) {
            if (std.mem.indexOf(u8, trimmed, "(") != null) {
                // Grouped import: import (
                in_import_block = true;
            } else if (try parseImport(allocator, trimmed, line_num)) |import_decl| {
                try structure.imports.append(allocator, import_decl);
            }
        }
        // Parse type definitions (struct, interface)
        else if (std.mem.startsWith(u8, trimmed, "type ")) {
            if (try parseType(allocator, trimmed, line_num)) |type_decl| {
                try structure.types.append(allocator, type_decl);
            }
        }
        // Parse functions (func)
        else if (std.mem.startsWith(u8, trimmed, "func ")) {
            if (try parseFunction(allocator, trimmed, line_num)) |func_decl| {
                try structure.functions.append(allocator, func_decl);
            }
        }
    }

    return structure;
}

/// Parse a single line within a grouped import block.
/// Each line is a quoted path, optionally preceded by an alias.
fn parseImportLine(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.ImportDecl {
    // Find the quoted string
    const quote_start = std.mem.indexOf(u8, line, "\"") orelse return null;
    const name_start = quote_start + 1;
    const quote_end = std.mem.indexOfScalarPos(u8, line, name_start, '"') orelse return null;
    if (quote_end <= name_start) return null;

    return base.ImportDecl{
        .module = try allocator.dupe(u8, line[name_start..quote_end]),
        .line = line_num,
        .items = &.{},
    };
}

fn parseImport(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.ImportDecl {
    if (!std.mem.startsWith(u8, line, "import ")) return null;

    var name_start: usize = 7;

    // Skip parenthesis for grouped imports
    if (name_start < line.len and line[name_start] == '(') {
        return null; // Multi-line import, skip for now
    }

    // Skip quotes
    while (name_start < line.len and (line[name_start] == '"' or line[name_start] == ' ')) {
        name_start += 1;
    }

    var name_end = name_start;
    while (name_end < line.len and line[name_end] != '"' and line[name_end] != '\n') {
        name_end += 1;
    }

    if (name_end <= name_start) return null;

    return base.ImportDecl{
        .module = try allocator.dupe(u8, line[name_start..name_end]),
        .line = line_num,
        .items = &.{},
    };
}

fn parseType(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.TypeDecl {
    if (!std.mem.startsWith(u8, line, "type ")) return null;

    const name_start: usize = 5;
    var name_end = name_start;

    while (name_end < line.len and (std.ascii.isAlphanumeric(line[name_end]) or line[name_end] == '_')) {
        name_end += 1;
    }

    if (name_end <= name_start) return null;

    const name = try allocator.dupe(u8, line[name_start..name_end]);

    // Determine type kind
    var kind: base.TypeDecl.TypeKind = .struct_type;
    if (std.mem.indexOf(u8, line, " interface ") != null or std.mem.indexOf(u8, line, " interface{") != null) {
        kind = .interface_type;
    }

    return base.TypeDecl{
        .name = name,
        .line = line_num,
        .kind = kind,
    };
}

fn parseFunction(allocator: std.mem.Allocator, line: []const u8, line_num: u32) !?base.FunctionDecl {
    if (!std.mem.startsWith(u8, line, "func ")) return null;

    var name_start: usize = 5;

    // Check for method receiver: func (r *Receiver) MethodName(...)
    if (name_start < line.len and line[name_start] == '(') {
        // Skip to after the receiver
        if (std.mem.indexOf(u8, line[name_start..], ") ")) |paren_end| {
            name_start += paren_end + 2;
        } else {
            return null;
        }
    }

    var name_end = name_start;
    while (name_end < line.len and (std.ascii.isAlphanumeric(line[name_end]) or line[name_end] == '_')) {
        name_end += 1;
    }

    if (name_end <= name_start) return null;

    const name = try allocator.dupe(u8, line[name_start..name_end]);
    var return_type: ?[]const u8 = null;

    // Extract return type (after parameters, before {)
    // Pattern: func name(params) ReturnType { or func name(params) (Type, error) {
    if (std.mem.lastIndexOf(u8, line, ")")) |last_paren| {
        var type_start = last_paren + 1;
        while (type_start < line.len and line[type_start] == ' ') type_start += 1;

        // Check if there's a return type before {
        if (type_start < line.len and line[type_start] != '{') {
            var type_end = type_start;

            // Handle tuple return (T, error)
            if (line[type_start] == '(') {
                if (std.mem.indexOf(u8, line[type_start..], ")")) |close_paren| {
                    type_end = type_start + close_paren + 1;
                }
            } else {
                while (type_end < line.len and line[type_end] != '{' and line[type_end] != ' ' and line[type_end] != '\n') {
                    type_end += 1;
                }
            }

            if (type_end > type_start) {
                const type_str = std.mem.trim(u8, line[type_start..type_end], " \t");
                if (type_str.len > 0 and !std.mem.eql(u8, type_str, "{")) {
                    return_type = try allocator.dupe(u8, type_str);
                }
            }
        }
    }

    // Check for error handling patterns
    const has_error_handling = std.mem.indexOf(u8, line, ", error)") != null or
        std.mem.indexOf(u8, line, ", error ") != null or
        std.mem.indexOf(u8, line, "error)") != null;

    // Check if this is a public function (starts with uppercase in Go)
    const is_public = name.len > 0 and std.ascii.isUpper(name[0]);

    return base.FunctionDecl{
        .name = name,
        .line = line_num,
        .is_async = false, // Go uses goroutines, not async/await
        .is_public = is_public,
        .return_type = return_type,
        .has_error_handling = has_error_handling,
    };
}

test "go: parse function" {
    const allocator = std.testing.allocator;
    var s = try parse(allocator, "func main() {");
    defer s.deinit();
    try std.testing.expectEqual(@as(usize, 1), s.functions.items.len);
    try std.testing.expectEqualStrings("main", s.functions.items[0].name);
}

test "go: parse function with return type" {
    const allocator = std.testing.allocator;
    var s = try parse(allocator, "func GetName() string {");
    defer s.deinit();
    try std.testing.expectEqual(@as(usize, 1), s.functions.items.len);
    try std.testing.expectEqualStrings("GetName", s.functions.items[0].name);
}

test "go: parse struct" {
    const allocator = std.testing.allocator;
    var s = try parse(allocator, "type Config struct {");
    defer s.deinit();
    try std.testing.expectEqual(@as(usize, 1), s.types.items.len);
    try std.testing.expectEqualStrings("Config", s.types.items[0].name);
}

test "go: parse interface" {
    const allocator = std.testing.allocator;
    var s = try parse(allocator, "type Reader interface {");
    defer s.deinit();
    try std.testing.expectEqual(@as(usize, 1), s.types.items.len);
    try std.testing.expectEqualStrings("Reader", s.types.items[0].name);
}

test "go: parse single import" {
    const allocator = std.testing.allocator;
    var s = try parse(allocator, "import \"fmt\"");
    defer s.deinit();
    try std.testing.expectEqual(@as(usize, 1), s.imports.items.len);
    try std.testing.expectEqualStrings("fmt", s.imports.items[0].module);
}

test "go: skip comment" {
    const allocator = std.testing.allocator;
    var s = try parse(allocator, "// func commented() {}");
    defer s.deinit();
    try std.testing.expectEqual(@as(usize, 0), s.functions.items.len);
}

test "go: parse grouped imports" {
    const allocator = std.testing.allocator;
    var s = try parse(allocator,
        \\import (
        \\    "fmt"
        \\    "os"
        \\    "strings"
        \\)
    );
    defer s.deinit();
    try std.testing.expectEqual(@as(usize, 3), s.imports.items.len);
    try std.testing.expectEqualStrings("fmt", s.imports.items[0].module);
    try std.testing.expectEqualStrings("os", s.imports.items[1].module);
    try std.testing.expectEqualStrings("strings", s.imports.items[2].module);
}

test "go: parse aliased grouped import" {
    const allocator = std.testing.allocator;
    var s = try parse(allocator,
        \\import (
        \\    myfmt "fmt"
        \\)
    );
    defer s.deinit();
    try std.testing.expectEqual(@as(usize, 1), s.imports.items.len);
    try std.testing.expectEqualStrings("fmt", s.imports.items[0].module);
}
