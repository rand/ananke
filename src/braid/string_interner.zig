// String interner for grammar literals and common patterns
// Reduces memory allocations by storing commonly used strings once
const std = @import("std");

/// String interner for grammar literals
/// Deduplicates commonly used grammar strings to reduce memory usage
/// Note: The interner does NOT own the strings - they are owned by the Grammar/IR
/// structures. The interner just ensures that duplicate strings share the same allocation.
pub const GrammarInterner = struct {
    allocator: std.mem.Allocator,
    // Maps string content to the canonical allocated copy
    // Keys are owned by the Grammar/IR, not by this interner
    strings: std.StringHashMapUnmanaged([]const u8),

    pub fn init(allocator: std.mem.Allocator) GrammarInterner {
        return .{
            .allocator = allocator,
            .strings = std.StringHashMapUnmanaged([]const u8){},
        };
    }

    pub fn deinit(self: *GrammarInterner) void {
        // Don't free the strings - they are owned by Grammar/IR
        // Just clean up the HashMap structure
        self.strings.deinit(self.allocator);
    }

    /// Intern a literal string, returning a stable pointer
    /// If the string is already interned, returns the existing pointer
    /// Otherwise, allocates a new copy and tracks it for future deduplication
    pub fn intern(self: *GrammarInterner, str: []const u8) ![]const u8 {
        // Check if we already have this string
        const gop = try self.strings.getOrPut(self.allocator, str);

        if (gop.found_existing) {
            // Return the existing interned string
            return gop.value_ptr.*;
        } else {
            // Allocate a new copy
            const owned = try self.allocator.dupe(u8, str);
            // Update the key to point to the owned string (for proper hashing)
            gop.key_ptr.* = owned;
            gop.value_ptr.* = owned;
            return owned;
        }
    }
};

/// Static pool of common regex patterns
/// These patterns are never freed and live for the entire program lifetime
pub const RegexPatternPool = struct {
    // Case style patterns
    pub const CAMEL_CASE = "^[a-z][a-zA-Z0-9]*$";
    pub const PASCAL_CASE = "^[A-Z][a-zA-Z0-9]*$";
    pub const SNAKE_CASE = "^[a-z][a-z0-9_]*$";
    pub const SCREAMING_SNAKE_CASE = "^[A-Z][A-Z0-9_]*$";
    pub const KEBAB_CASE = "^[a-z][a-z0-9-]*$";

    // Validation patterns
    pub const EMAIL = "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$";
    pub const URL = "^https?://[a-zA-Z0-9.-]+(?:/[^\\s]*)?$";
    pub const UUID = "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$";

    pub const EMPTY_FLAGS = "";

    /// Get a pattern by description keyword
    pub fn getPatternForKeyword(keyword: []const u8) ?[]const u8 {
        if (std.mem.eql(u8, keyword, "camelCase")) return CAMEL_CASE;
        if (std.mem.eql(u8, keyword, "PascalCase")) return PASCAL_CASE;
        if (std.mem.eql(u8, keyword, "snake_case")) return SNAKE_CASE;
        if (std.mem.eql(u8, keyword, "SCREAMING_SNAKE_CASE")) return SCREAMING_SNAKE_CASE;
        if (std.mem.eql(u8, keyword, "UPPER_CASE")) return SCREAMING_SNAKE_CASE;
        if (std.mem.eql(u8, keyword, "kebab-case")) return KEBAB_CASE;
        if (std.mem.eql(u8, keyword, "email")) return EMAIL;
        if (std.mem.eql(u8, keyword, "URL") or std.mem.eql(u8, keyword, "url")) return URL;
        if (std.mem.eql(u8, keyword, "UUID") or std.mem.eql(u8, keyword, "uuid")) return UUID;
        return null;
    }
};

test "grammar interner basic" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var interner = GrammarInterner.init(allocator);
    defer interner.deinit();

    // First intern allocates
    const prog1 = try interner.intern("program");
    // Second intern returns same pointer
    const prog2 = try interner.intern("program");

    // Same pointer for same string
    try testing.expectEqual(prog1.ptr, prog2.ptr);

    // New string gets interned
    const custom = try interner.intern("custom_rule");
    const custom2 = try interner.intern("custom_rule");
    try testing.expectEqual(custom.ptr, custom2.ptr);

    // Different strings have different pointers
    try testing.expect(prog1.ptr != custom.ptr);

    // Cleanup: free the interned strings (simulating Grammar cleanup)
    allocator.free(prog1);
    allocator.free(custom);
}

test "regex pattern pool" {
    const testing = std.testing;

    // Static patterns should be available
    try testing.expectEqualStrings("^[a-z][a-zA-Z0-9]*$", RegexPatternPool.CAMEL_CASE);
    try testing.expectEqualStrings("^[A-Z][a-zA-Z0-9]*$", RegexPatternPool.PASCAL_CASE);

    // Lookup by keyword
    const camel = RegexPatternPool.getPatternForKeyword("camelCase");
    try testing.expect(camel != null);
    try testing.expectEqualStrings(RegexPatternPool.CAMEL_CASE, camel.?);

    const email = RegexPatternPool.getPatternForKeyword("email");
    try testing.expect(email != null);
    try testing.expectEqualStrings(RegexPatternPool.EMAIL, email.?);

    // Unknown keyword returns null
    const unknown = RegexPatternPool.getPatternForKeyword("unknown");
    try testing.expectEqual(@as(?[]const u8, null), unknown);
}
