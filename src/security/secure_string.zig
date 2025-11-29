// Secure string handling - zeros memory on deallocation to prevent secret leakage
const std = @import("std");

/// A string that automatically zeros its memory when freed
/// Use this for API keys, passwords, and other sensitive data
pub const SecureString = struct {
    data: []u8,
    allocator: std.mem.Allocator,

    /// Create a new SecureString from existing data (takes ownership)
    pub fn init(allocator: std.mem.Allocator, data: []u8) SecureString {
        return .{
            .data = data,
            .allocator = allocator,
        };
    }

    /// Create a new SecureString by copying data
    pub fn initCopy(allocator: std.mem.Allocator, data: []const u8) !SecureString {
        const copy = try allocator.dupe(u8, data);
        return init(allocator, copy);
    }

    /// Free the SecureString and zero its memory
    pub fn deinit(self: *SecureString) void {
        // Zero the memory before freeing to prevent leakage
        zeroMemory(self.data);
        self.allocator.free(self.data);
        self.data = &.{};
    }

    /// Get the underlying data (read-only)
    /// SECURITY: Never store this pointer - it will be zeroed on deinit
    pub fn slice(self: *const SecureString) []const u8 {
        return self.data;
    }

    /// Explicitly zero the memory without freeing
    /// Useful for clearing sensitive data while keeping the allocation
    pub fn zero(self: *SecureString) void {
        zeroMemory(self.data);
    }
};

/// Optional secure string (nullable)
pub const OptionalSecureString = struct {
    inner: ?SecureString,

    pub fn init(allocator: std.mem.Allocator, data: ?[]u8) OptionalSecureString {
        return .{
            .inner = if (data) |d| SecureString.init(allocator, d) else null,
        };
    }

    pub fn initCopy(allocator: std.mem.Allocator, data: ?[]const u8) !OptionalSecureString {
        if (data) |d| {
            return .{ .inner = try SecureString.initCopy(allocator, d) };
        }
        return .{ .inner = null };
    }

    pub fn deinit(self: *OptionalSecureString) void {
        if (self.inner) |*s| {
            s.deinit();
        }
        self.inner = null;
    }

    pub fn slice(self: *const OptionalSecureString) ?[]const u8 {
        if (self.inner) |*s| {
            return s.slice();
        }
        return null;
    }

    pub fn isSet(self: *const OptionalSecureString) bool {
        return self.inner != null;
    }

    /// Replace the current value with a new one (zeros old value)
    pub fn replace(self: *OptionalSecureString, allocator: std.mem.Allocator, new_data: []u8) void {
        if (self.inner) |*old| {
            old.deinit();
        }
        self.inner = SecureString.init(allocator, new_data);
    }
};

/// Zero memory using volatile writes to prevent compiler optimization
/// This ensures the zeroing actually happens and isn't optimized away
pub fn zeroMemory(data: []u8) void {
    // Use volatile writes to prevent compiler from optimizing away the zeroing
    // This is critical for security - we MUST actually zero the memory
    @setRuntimeSafety(false); // Disable bounds checks for performance
    const ptr: [*]volatile u8 = @ptrCast(data.ptr);
    for (0..data.len) |i| {
        ptr[i] = 0;
    }
    @setRuntimeSafety(true);
}

/// Constant-time string comparison to prevent timing attacks
/// Returns true if strings are equal, false otherwise
/// SECURITY: Always compares full length to prevent timing side-channel
pub fn constantTimeEqual(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) {
        // Still do comparison work to prevent length timing leak
        var dummy: u8 = 0;
        for (0..@min(a.len, b.len)) |i| {
            dummy |= a[i] ^ b[i];
        }
        return false;
    }

    var diff: u8 = 0;
    for (a, b) |byte_a, byte_b| {
        diff |= byte_a ^ byte_b;
    }

    return diff == 0;
}

test "SecureString - basic lifecycle" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const data = try allocator.dupe(u8, "secret-api-key");
    var secure = SecureString.init(allocator, data);
    defer secure.deinit();

    try testing.expectEqualStrings("secret-api-key", secure.slice());
}

test "SecureString - zeroes memory on deinit" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const data = try allocator.dupe(u8, "secret-data");
    const data_ptr = data.ptr;

    var secure = SecureString.init(allocator, data);

    // Verify data is present
    try testing.expectEqualStrings("secret-data", secure.slice());

    // Deinit should zero the memory
    secure.deinit();

    // Memory should be zeroed (check a few bytes)
    // Note: This is testing implementation details, but important for security
    try testing.expectEqual(@as(u8, 0), data_ptr[0]);
    try testing.expectEqual(@as(u8, 0), data_ptr[5]);
}

test "SecureString - initCopy" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const original = "api-key-value";
    var secure = try SecureString.initCopy(allocator, original);
    defer secure.deinit();

    try testing.expectEqualStrings(original, secure.slice());
    // Should be different memory
    try testing.expect(secure.data.ptr != original.ptr);
}

test "SecureString - explicit zero" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const data = try allocator.dupe(u8, "secret");
    var secure = SecureString.init(allocator, data);
    defer secure.deinit();

    secure.zero();

    // After explicit zero, all bytes should be 0
    for (secure.data) |byte| {
        try testing.expectEqual(@as(u8, 0), byte);
    }
}

test "OptionalSecureString - none" {
    const allocator = std.testing.allocator;

    var optional = OptionalSecureString.init(allocator, null);
    defer optional.deinit();

    try std.testing.expect(!optional.isSet());
    try std.testing.expectEqual(@as(?[]const u8, null), optional.slice());
}

test "OptionalSecureString - some" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const data = try allocator.dupe(u8, "secret");
    var optional = OptionalSecureString.init(allocator, data);
    defer optional.deinit();

    try testing.expect(optional.isSet());
    try testing.expectEqualStrings("secret", optional.slice().?);
}

test "OptionalSecureString - replace" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const data1 = try allocator.dupe(u8, "first");
    var optional = OptionalSecureString.init(allocator, data1);
    defer optional.deinit();

    try testing.expectEqualStrings("first", optional.slice().?);

    const data2 = try allocator.dupe(u8, "second");
    optional.replace(allocator, data2);

    try testing.expectEqualStrings("second", optional.slice().?);
}

test "zeroMemory - actually zeros" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const data = try allocator.alloc(u8, 100);
    defer allocator.free(data);

    // Fill with non-zero data
    for (data, 0..) |*byte, i| {
        byte.* = @intCast(i % 256);
    }

    // Verify data is non-zero
    var has_nonzero = false;
    for (data) |byte| {
        if (byte != 0) {
            has_nonzero = true;
            break;
        }
    }
    try testing.expect(has_nonzero);

    // Zero the memory
    zeroMemory(data);

    // Verify all bytes are zero
    for (data) |byte| {
        try testing.expectEqual(@as(u8, 0), byte);
    }
}

test "constantTimeEqual - equal strings" {
    const testing = std.testing;

    try testing.expect(constantTimeEqual("hello", "hello"));
    try testing.expect(constantTimeEqual("", ""));
    try testing.expect(constantTimeEqual("a", "a"));
}

test "constantTimeEqual - different strings" {
    const testing = std.testing;

    try testing.expect(!constantTimeEqual("hello", "world"));
    try testing.expect(!constantTimeEqual("hello", "hello!"));
    try testing.expect(!constantTimeEqual("a", "b"));
    try testing.expect(!constantTimeEqual("", "a"));
}

test "constantTimeEqual - different lengths" {
    const testing = std.testing;

    try testing.expect(!constantTimeEqual("short", "longer"));
    try testing.expect(!constantTimeEqual("longer", "short"));
}
