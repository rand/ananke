// Zig Sample File
// This file tests various Zig patterns for constraint extraction

const std = @import("std");
const testing = std.testing;

// Struct definition with fields
pub const User = struct {
    id: u64,
    name: []const u8,
    email: []const u8,
    is_active: bool,
};

// Error set definition
pub const UserError = error{
    NotFound,
    DatabaseError,
    InvalidInput,
};

// Function with error union return type
pub fn getUser(allocator: std.mem.Allocator, id: u64) UserError!User {
    _ = allocator;
    
    if (id == 0) {
        return UserError.InvalidInput;
    }
    
    // Simulate database lookup
    return User{
        .id = id,
        .name = "Test User",
        .email = "test@example.com",
        .is_active = true,
    };
}

// Async function equivalent (Zig uses comptime for compile-time execution)
pub fn createUser(
    allocator: std.mem.Allocator,
    name: []const u8,
    email: []const u8,
) !User {
    if (name.len == 0 or email.len == 0) {
        return UserError.InvalidInput;
    }
    
    _ = allocator;
    
    return User{
        .id = 1,
        .name = name,
        .email = email,
        .is_active = true,
    };
}

// Generic function
pub fn findById(comptime T: type, items: []const T, id: u64) ?T {
    for (items) |item| {
        if (item.id == id) {
            return item;
        }
    }
    return null;
}

// Test block
test "getUser returns valid user" {
    const allocator = testing.allocator;
    const user = try getUser(allocator, 42);
    
    try testing.expectEqual(@as(u64, 42), user.id);
    try testing.expect(user.is_active);
}

test "getUser rejects zero ID" {
    const allocator = testing.allocator;
    try testing.expectError(UserError.InvalidInput, getUser(allocator, 0));
}
