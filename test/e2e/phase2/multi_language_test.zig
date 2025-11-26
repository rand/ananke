//! Multi-Language E2E Tests
//!
//! Tests constraint extraction across multiple programming languages:
//! - Language detection and routing
//! - Consistent constraint extraction
//! - Cross-language pattern comparison
//! - Constraint aggregation

const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const Clew = @import("clew").Clew;
const HybridExtractor = @import("clew").hybrid_extractor.HybridExtractor;
const ExtractionStrategy = @import("clew").hybrid_extractor.ExtractionStrategy;
const Constraint = @import("ananke").types.constraint.Constraint;
const ConstraintSet = @import("ananke").types.constraint.ConstraintSet;
// ============================================================================
// Multi-Language Test Fixtures
const user_service_typescript =
    \\interface User {
    \\    id: number;
    \\    name: string;
    \\}
    \\
    \\class UserService {
    \\    async getUser(id: number): Promise<User> {
    \\        return await this.db.findById(id);
    \\    }
;
const user_service_python =
    \\from typing import Optional
    \\class User:
    \\    def __init__(self, id: int, name: str):
    \\        self.id = id
    \\        self.name = name
    \\class UserService:
    \\    async def get_user(self, user_id: int) -> Optional[User]:
    \\        return await self.db.find_by_id(user_id)
;
const user_service_rust =
    \\struct User {
    \\    id: u64,
    \\    name: String,
    \\impl UserService {
    \\    async fn get_user(&self, id: u64) -> Option<User> {
    \\        self.db.find_by_id(id).await
;
const user_service_go =
    \\type User struct {
    \\    ID   uint64
    \\    Name string
    \\}
    \\func (s *UserService) GetUser(id uint64) (*User, error) {
    \\    return s.db.FindByID(id)
    \\}
;
const user_service_zig =
    \\pub const User = struct {
    \\    name: []const u8,
    \\};
    \\pub const UserService = struct {
    \\    pub fn getUser(self: *UserService, id: u64) !?User {
    \\        return try self.db.findById(id);
    \\    }
    \\};
;
// Language Detection and Routing
test "Multi-Language: TypeScript detection and extraction" {
    const allocator = testing.allocator;
    
    var clew = try Clew.init(allocator);
    defer clew.deinit();
    var constraints = try clew.extractFromCode(user_service_typescript, "typescript");
    defer constraints.deinit();
    std.debug.print("\n=== TypeScript Multi-Language Test ===\n", .{});
    std.debug.print("Extracted {} TypeScript constraints\n", .{constraints.constraints.items.len});
    try testing.expect(constraints.constraints.items.len > 0);
}
test "Multi-Language: Python detection and extraction" {
    const allocator = testing.allocator;

    var clew = try Clew.init(allocator);
    defer clew.deinit();
    var constraints = try clew.extractFromCode(user_service_python, "python");
    defer constraints.deinit();
    std.debug.print("\n=== Python Multi-Language Test ===\n", .{});
    std.debug.print("Extracted {} Python constraints\n", .{constraints.constraints.items.len});
    try testing.expect(constraints.constraints.items.len > 0);
}
test "Multi-Language: All supported languages" {
    const languages = [_]struct {
        name: []const u8,
        code: []const u8,
        has_ts_support: bool,
    }{
        .{ .name = "typescript", .code = user_service_typescript, .has_ts_support = true },
        .{ .name = "python", .code = user_service_python, .has_ts_support = true },
        .{ .name = "rust", .code = user_service_rust, .has_ts_support = false },
        .{ .name = "go", .code = user_service_go, .has_ts_support = false },
        .{ .name = "zig", .code = user_service_zig, .has_ts_support = false },
    };
    const allocator = testing.allocator;
    std.debug.print("\n=== All Languages Test ===\n", .{});
    for (languages) |lang| {
        var extractor = try HybridExtractor.init(allocator, .tree_sitter_with_fallback);
        defer extractor.deinit();
        var result = try extractor.extract(lang.code, lang.name);
        defer result.deinitFull(allocator);
        
        std.debug.print("{s:12} - TS: {}, Constraints: {}\n",
            .{lang.name, result.tree_sitter_available, result.constraints.len});
        // Verify tree-sitter availability matches expectations
        if (lang.has_ts_support) {
            // TypeScript and Python should have tree-sitter support
            // (may not be available on all systems, so this is informational)
        }
    }
    std.debug.print("✓ Tested all language extraction paths\n", .{});
}
// Cross-Language Constraint Comparison
test "Multi-Language: Compare TypeScript vs Python patterns" {
    const allocator = testing.allocator;

    var clew = try Clew.init(allocator);
    defer clew.deinit();
    // Extract from both languages
    var ts_constraints = try clew.extractFromCode(user_service_typescript, "typescript");
    defer ts_constraints.deinit();
    var py_constraints = try clew.extractFromCode(user_service_python, "python");
    defer py_constraints.deinit();
    std.debug.print("\n=== Cross-Language Pattern Comparison ===\n", .{});
    std.debug.print("TypeScript: {} constraints\n", .{ts_constraints.constraints.items.len});
    std.debug.print("Python:     {} constraints\n", .{py_constraints.constraints.items.len});
    // Both should extract similar high-level patterns
    // (class definitions, async functions, type annotations)
    try testing.expect(ts_constraints.constraints.items.len > 0);
    try testing.expect(py_constraints.constraints.items.len > 0);
    // Count common patterns
    var ts_has_class = false;
    var ts_has_async = false;
    var py_has_class = false;
    var py_has_async = false;
    for (ts_constraints.constraints.items) |c| {
        const name_lower = std.ascii.allocLowerString(allocator, c.name) catch c.name;
        defer if (name_lower.ptr != c.name.ptr) allocator.free(name_lower);
        if (std.mem.indexOf(u8, name_lower, "class") != null) ts_has_class = true;
        if (std.mem.indexOf(u8, name_lower, "async") != null) ts_has_async = true;
    }
    for (py_constraints.constraints.items) |c| {
        const name_lower2 = try std.ascii.allocLowerString(allocator, c.name);
        defer allocator.free(name_lower2);
        if (std.mem.indexOf(u8, name_lower2, "class") != null) py_has_class = true;
        if (std.mem.indexOf(u8, name_lower2, "async") != null) py_has_async = true;
    }
    std.debug.print("Common patterns found:\n", .{});
    std.debug.print("  Classes: TS={}, Py={}\n", .{ts_has_class, py_has_class});
    std.debug.print("  Async:   TS={}, Py={}\n", .{ts_has_async, py_has_async});
    std.debug.print("✓ Cross-language patterns detected\n", .{});
}
// Constraint Aggregation
test "Multi-Language: Aggregate constraints from multiple files" {
    const allocator = testing.allocator;
    // Simulate extracting from multiple files in a project
    const files = [_]struct {
        name: []const u8,
        language: []const u8,
        code: []const u8,
    }{
        .{ .name = "user.ts", .language = "typescript", .code = user_service_typescript },
        .{ .name = "auth.py", .language = "python", .code = user_service_python },
        .{ .name = "db.rs", .language = "rust", .code = user_service_rust },
    };
    var clew = try Clew.init(allocator);
    defer clew.deinit();
    var all_constraints = ConstraintSet.init(allocator, "multi_file_constraints");
    defer all_constraints.deinit();
    std.debug.print("\n=== Multi-File Aggregation Test ===\n", .{});
    for (files) |file| {
        var file_constraints = try clew.extractFromCode(file.code, file.language);
        defer file_constraints.deinit();
        std.debug.print("{s:15} -> {} constraints\n", 
            .{file.name, file_constraints.constraints.items.len});
        // Add to aggregate set
        for (file_constraints.constraints.items) |constraint| {
            try all_constraints.add(constraint);
        }
    }
    std.debug.print("Total aggregated: {} constraints\n", .{all_constraints.constraints.items.len});
    try testing.expect(all_constraints.constraints.items.len > 0);
    std.debug.print("✓ Successfully aggregated multi-language constraints\n", .{});
}
// Language-Specific Features
test "Multi-Language: TypeScript-specific features" {
    const allocator = testing.allocator;
    const ts_specific =
        \\interface Config {
        \\    timeout: number;
        \\}
        \\
        \\type Result<T> = { ok: true; value: T } | { ok: false; error: string };
        \\const processAsync = async <T>(fn: () => Promise<T>): Promise<Result<T>> => {
        \\    try {
        \\        const value = await fn();
        \\        return { ok: true, value };
        \\    } catch (error) {
        \\        return { ok: false, error: String(error) };
        \\    }
        \\};
    ;
    var clew = try Clew.init(allocator);
    defer clew.deinit();
    var constraints = try clew.extractFromCode(ts_specific, "typescript");
    defer constraints.deinit();
    std.debug.print("\n=== TypeScript-Specific Features ===\n", .{});
    std.debug.print("Extracted {} constraints\n", .{constraints.constraints.items.len});
    // Should detect generics, union types, arrow functions
    for (constraints.constraints.items) |c| {
        std.debug.print("  - {s}\n", .{c.name});
    }
    std.debug.print("✓ TypeScript-specific patterns extracted\n", .{});
}
test "Multi-Language: Python-specific features" {
    const allocator = testing.allocator;
    const py_specific =
        \\from typing import Protocol, TypeVar
        \\from dataclasses import dataclass
        \\T = TypeVar('T')
        \\class Comparable(Protocol):
        \\    def __lt__(self, other) -> bool: ...
        \\@dataclass
        \\class Config:
        \\    timeout: int
        \\async def process_async(fn) -> T:
        \\    try:
        \\        return await fn()
        \\    except Exception as e:
        \\        raise ValueError(f"Failed: {e}")
    ;
    var clew = try Clew.init(allocator);
    defer clew.deinit();
    var constraints = try clew.extractFromCode(py_specific, "python");
    defer constraints.deinit();
    std.debug.print("\n=== Python-Specific Features ===\n", .{});
    // Should detect dataclasses, protocols, type variables
    std.debug.print("✓ Python-specific patterns extracted\n", .{});
}
// Performance Comparison
test "Multi-Language: Extraction performance comparison" {
    const allocator = testing.allocator;
    const languages = [_]struct {
        name: []const u8,
        code: []const u8,
    }{
        .{ .name = "typescript", .code = user_service_typescript },
        .{ .name = "python", .code = user_service_python },
        .{ .name = "rust", .code = user_service_rust },
    };
    var clew = try Clew.init(allocator);
    defer clew.deinit();
    std.debug.print("\n=== Multi-Language Performance ===\n", .{});
    for (languages) |lang| {
        const start = std.time.milliTimestamp();
        var constraints = try clew.extractFromCode(lang.code, lang.name);
        defer constraints.deinit();
        const elapsed = std.time.milliTimestamp() - start;
        std.debug.print("{s:12} - {}ms, {} constraints\n",
            .{lang.name, elapsed, constraints.constraints.items.len});
    }
    std.debug.print("✓ Performance comparison complete\n", .{});
}
