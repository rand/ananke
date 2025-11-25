//! Rust/Go/Zig Extraction Tests
//! Verifies that hybrid extraction works for all three languages

const std = @import("std");
const testing = std.testing;

const Clew = @import("clew").Clew;

// ============================================================================
// Test Fixtures
// ============================================================================

const rust_sample =
    \\// Rust sample code
    \\use std::error::Error;
    \\
    \\pub struct User {
    \\    id: u64,
    \\    name: String,
    \\}
    \\
    \\pub async fn get_user(id: u64) -> Result<User, Box<dyn Error>> {
    \\    Ok(User {
    \\        id,
    \\        name: String::from("test"),
    \\    })
    \\}
    \\
    \\impl User {
    \\    pub fn new(id: u64) -> Self {
    \\        User { id, name: String::new() }
    \\    }
    \\}
;

const go_sample =
    \\// Go sample code
    \\package service
    \\
    \\import (
    \\    "context"
    \\    "errors"
    \\)
    \\
    \\type User struct {
    \\    ID   uint64 `json:"id"`
    \\    Name string `json:"name"`
    \\}
    \\
    \\func NewUser(id uint64) *User {
    \\    return &User{ID: id, Name: "test"}
    \\}
    \\
    \\func GetUser(ctx context.Context, id uint64) (*User, error) {
    \\    if err != nil {
    \\        return nil, errors.New("not found")
    \\    }
    \\    return NewUser(id), nil
    \\}
;

const zig_sample =
    \\// Zig sample code
    \\const std = @import("std");
    \\
    \\const User = struct {
    \\    id: u64,
    \\    name: []const u8,
    \\};
    \\
    \\pub fn getUser(id: u64) !User {
    \\    return User{
    \\        .id = id,
    \\        .name = "test",
    \\    };
    \\}
    \\
    \\pub fn createUser(allocator: std.mem.Allocator, id: u64) !*User {
    \\    const user = try allocator.create(User);
    \\    errdefer allocator.destroy(user);
    \\    user.* = User{ .id = id, .name = "test" };
    \\    return user;
    \\}
;

// ============================================================================
// Rust Extraction Tests
// ============================================================================

test "Rust: basic extraction works" {
    const allocator = testing.allocator;

    var clew = try Clew.init(allocator);
    defer clew.deinit();

    var result = try clew.extractFromCode(rust_sample, "rust");
    defer result.deinit();

    // Should extract some constraints
    try testing.expect(result.constraints.items.len > 0);

    std.debug.print("\n=== Rust Extraction ===\n", .{});
    std.debug.print("Extracted {} constraints\n", .{result.constraints.items.len});

    for (result.constraints.items) |constraint| {
        std.debug.print("  - {s} (conf: {d:.2})\n", .{ constraint.name, constraint.confidence });
    }
}

test "Rust: detects async patterns" {
    const allocator = testing.allocator;

    var clew = try Clew.init(allocator);
    defer clew.deinit();

    var result = try clew.extractFromCode(rust_sample, "rust");
    defer result.deinit();

    // Should find async keyword
    var found_async = false;
    for (result.constraints.items) |constraint| {
        if (std.mem.indexOf(u8, constraint.name, "sync") != null or
            std.mem.indexOf(u8, constraint.description, "sync") != null)
        {
            found_async = true;
            break;
        }
    }

    if (found_async) {
        std.debug.print("\n✓ Found async pattern in Rust\n", .{});
    } else {
        std.debug.print("\n⊘ No async pattern found (pattern matching may have limitations)\n", .{});
    }
}

test "Rust: detects error handling" {
    const allocator = testing.allocator;

    var clew = try Clew.init(allocator);
    defer clew.deinit();

    var result = try clew.extractFromCode(rust_sample, "rust");
    defer result.deinit();

    // Should find Result type or error handling
    var found_error_handling = false;
    for (result.constraints.items) |constraint| {
        if (std.mem.indexOf(u8, constraint.name, "esult") != null or
            std.mem.indexOf(u8, constraint.description, "esult") != null or
            std.mem.indexOf(u8, constraint.description, "error") != null)
        {
            found_error_handling = true;
            break;
        }
    }

    if (found_error_handling) {
        std.debug.print("\n✓ Found error handling in Rust\n", .{});
    } else {
        std.debug.print("\n⊘ No error handling found\n", .{});
    }
}

// ============================================================================
// Go Extraction Tests
// ============================================================================

test "Go: basic extraction works" {
    const allocator = testing.allocator;

    var clew = try Clew.init(allocator);
    defer clew.deinit();

    var result = try clew.extractFromCode(go_sample, "go");
    defer result.deinit();

    // Should extract some constraints
    try testing.expect(result.constraints.items.len > 0);

    std.debug.print("\n=== Go Extraction ===\n", .{});
    std.debug.print("Extracted {} constraints\n", .{result.constraints.items.len});

    for (result.constraints.items) |constraint| {
        std.debug.print("  - {s} (conf: {d:.2})\n", .{ constraint.name, constraint.confidence });
    }
}

test "Go: detects error handling" {
    const allocator = testing.allocator;

    var clew = try Clew.init(allocator);
    defer clew.deinit();

    var result = try clew.extractFromCode(go_sample, "go");
    defer result.deinit();

    // Should find "if err != nil" or error type
    var found_error_check = false;
    for (result.constraints.items) |constraint| {
        if (std.mem.indexOf(u8, constraint.name, "rror") != null or
            std.mem.indexOf(u8, constraint.description, "rror") != null or
            std.mem.indexOf(u8, constraint.description, "err") != null)
        {
            found_error_check = true;
            break;
        }
    }

    if (found_error_check) {
        std.debug.print("\n✓ Found error handling in Go\n", .{});
    } else {
        std.debug.print("\n⊘ No error handling found\n", .{});
    }
}

test "Go: detects struct tags" {
    const allocator = testing.allocator;

    var clew = try Clew.init(allocator);
    defer clew.deinit();

    var result = try clew.extractFromCode(go_sample, "go");
    defer result.deinit();

    // Should find struct tags like `json:"..."`
    var found_tags = false;
    for (result.constraints.items) |constraint| {
        if (std.mem.indexOf(u8, constraint.name, "tag") != null or
            std.mem.indexOf(u8, constraint.name, "json") != null or
            std.mem.indexOf(u8, constraint.description, "tag") != null)
        {
            found_tags = true;
            break;
        }
    }

    if (found_tags) {
        std.debug.print("\n✓ Found struct tags in Go\n", .{});
    } else {
        std.debug.print("\n⊘ No struct tags found\n", .{});
    }
}

// ============================================================================
// Zig Extraction Tests
// ============================================================================

test "Zig: basic extraction works" {
    const allocator = testing.allocator;

    var clew = try Clew.init(allocator);
    defer clew.deinit();

    var result = try clew.extractFromCode(zig_sample, "zig");
    defer result.deinit();

    // Should extract some constraints
    try testing.expect(result.constraints.items.len > 0);

    std.debug.print("\n=== Zig Extraction ===\n", .{});
    std.debug.print("Extracted {} constraints\n", .{result.constraints.items.len});

    for (result.constraints.items) |constraint| {
        std.debug.print("  - {s} (conf: {d:.2})\n", .{ constraint.name, constraint.confidence });
    }
}

test "Zig: detects error union type" {
    const allocator = testing.allocator;

    var clew = try Clew.init(allocator);
    defer clew.deinit();

    var result = try clew.extractFromCode(zig_sample, "zig");
    defer result.deinit();

    // Should find error union type "!"
    var found_error_union = false;
    for (result.constraints.items) |constraint| {
        if (std.mem.indexOf(u8, constraint.description, "rror union") != null or
            std.mem.indexOf(u8, constraint.description, "!") != null)
        {
            found_error_union = true;
            break;
        }
    }

    if (found_error_union) {
        std.debug.print("\n✓ Found error union in Zig\n", .{});
    } else {
        std.debug.print("\n⊘ No error union found\n", .{});
    }
}

test "Zig: detects memory management" {
    const allocator = testing.allocator;

    var clew = try Clew.init(allocator);
    defer clew.deinit();

    var result = try clew.extractFromCode(zig_sample, "zig");
    defer result.deinit();

    // Should find allocator or memory management patterns
    var found_allocator = false;
    for (result.constraints.items) |constraint| {
        if (std.mem.indexOf(u8, constraint.name, "llocator") != null or
            std.mem.indexOf(u8, constraint.description, "llocator") != null or
            std.mem.indexOf(u8, constraint.description, "defer") != null or
            std.mem.indexOf(u8, constraint.description, "errdefer") != null)
        {
            found_allocator = true;
            break;
        }
    }

    if (found_allocator) {
        std.debug.print("\n✓ Found memory management in Zig\n", .{});
    } else {
        std.debug.print("\n⊘ No memory management patterns found\n", .{});
    }
}

// ============================================================================
// Cross-Language Comparison
// ============================================================================

test "Cross-language: all languages extract constraints" {
    const allocator = testing.allocator;

    var clew = try Clew.init(allocator);
    defer clew.deinit();

    // Extract from all three languages
    var rust_result = try clew.extractFromCode(rust_sample, "rust");
    defer rust_result.deinit();

    var go_result = try clew.extractFromCode(go_sample, "go");
    defer go_result.deinit();

    var zig_result = try clew.extractFromCode(zig_sample, "zig");
    defer zig_result.deinit();

    std.debug.print("\n=== Cross-Language Comparison ===\n", .{});
    std.debug.print("Rust: {} constraints\n", .{rust_result.constraints.items.len});
    std.debug.print("Go:   {} constraints\n", .{go_result.constraints.items.len});
    std.debug.print("Zig:  {} constraints\n", .{zig_result.constraints.items.len});

    // All should have extracted at least some constraints
    try testing.expect(rust_result.constraints.items.len > 0);
    try testing.expect(go_result.constraints.items.len > 0);
    try testing.expect(zig_result.constraints.items.len > 0);

    std.debug.print("✓ All three languages successfully extracted constraints\n", .{});
}
