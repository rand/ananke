//! String Interner for deduplicating frequently repeated strings
//! 
//! This module provides a high-performance string interning system that reduces memory
//! allocations and improves cache locality by ensuring each unique string is stored only once.
//!
//! Key performance characteristics:
//! - O(1) amortized intern() operation via hash map
//! - Zero-allocation for already-interned strings
//! - Improved cache locality (strings clustered in arena memory)
//! - Thread-unsafe (use separate instances per thread or add synchronization)
//!
//! Ownership model:
//! - StringInterner owns all interned strings
//! - Consumers receive borrowed pointers ([]const u8)
//! - Strings remain valid until deinit()
//! - DO NOT free interned strings manually

const std = @import("std");
const Allocator = std.mem.Allocator;

/// String interning system with arena-based storage
pub const StringInterner = struct {
    /// Main allocator for the interner structures
    allocator: Allocator,
    
    /// Arena allocator for string storage (all strings in contiguous memory)
    arena: std.heap.ArenaAllocator,
    
    /// Hash map from string content to canonical pointer
    /// Key: hash of string content, Value: pointer to interned string
    intern_map: std.StringHashMap([]const u8),
    
    /// Statistics for performance analysis
    stats: Stats,
    
    pub const Stats = struct {
        total_interns: usize = 0,
        unique_strings: usize = 0,
        total_bytes: usize = 0,
        cache_hits: usize = 0,
        cache_misses: usize = 0,
        
        pub fn hitRate(self: *const Stats) f64 {
            if (self.total_interns == 0) return 0.0;
            return @as(f64, @floatFromInt(self.cache_hits)) / @as(f64, @floatFromInt(self.total_interns));
        }
        
        pub fn avgStringLen(self: *const Stats) f64 {
            if (self.unique_strings == 0) return 0.0;
            return @as(f64, @floatFromInt(self.total_bytes)) / @as(f64, @floatFromInt(self.unique_strings));
        }
    };
    
    /// Initialize a new string interner
    pub fn init(allocator: Allocator) !StringInterner {
        return StringInterner{
            .allocator = allocator,
            .arena = std.heap.ArenaAllocator.init(allocator),
            .intern_map = std.StringHashMap([]const u8).init(allocator),
            .stats = .{},
        };
    }
    
    /// Free all interned strings and internal data structures
    pub fn deinit(self: *StringInterner) void {
        self.intern_map.deinit();
        self.arena.deinit();
    }
    
    /// Intern a string, returning a canonical pointer
    /// 
    /// If the string has been interned before, returns the existing pointer (O(1) lookup).
    /// Otherwise, allocates a new copy in the arena and caches it (O(n) where n = string length).
    ///
    /// The returned pointer is valid until deinit() is called.
    /// DO NOT free the returned string - the interner owns it.
    pub fn intern(self: *StringInterner, str: []const u8) ![]const u8 {
        self.stats.total_interns += 1;
        
        // Fast path: check if already interned
        if (self.intern_map.get(str)) |interned| {
            self.stats.cache_hits += 1;
            return interned;
        }
        
        // Slow path: allocate and cache new string
        self.stats.cache_misses += 1;
        self.stats.unique_strings += 1;
        self.stats.total_bytes += str.len;
        
        const arena_allocator = self.arena.allocator();
        const owned = try arena_allocator.dupe(u8, str);
        try self.intern_map.put(owned, owned);
        
        return owned;
    }
    
    /// Get current statistics
    pub fn getStats(self: *const StringInterner) Stats {
        return self.stats;
    }
    
    /// Print statistics to stderr for debugging
    pub fn printStats(self: *const StringInterner) void {
        const s = self.stats;
        std.debug.print(
            \\String Interner Statistics:
            \\  Total intern() calls: {}
            \\  Unique strings: {}
            \\  Cache hits: {} ({d:.1}%)
            \\  Cache misses: {}
            \\  Total bytes: {} ({d:.1} bytes/string avg)
            \\  Memory saved: {} bytes (approximate)
            \\
        , .{
            s.total_interns,
            s.unique_strings,
            s.cache_hits,
            s.hitRate() * 100.0,
            s.cache_misses,
            s.total_bytes,
            s.avgStringLen(),
            s.total_bytes * (s.total_interns - s.unique_strings),
        });
    }
};

test "StringInterner basic functionality" {
    var interner = try StringInterner.init(std.testing.allocator);
    defer interner.deinit();
    
    const str1 = try interner.intern("hello");
    const str2 = try interner.intern("world");
    const str3 = try interner.intern("hello"); // duplicate
    
    // Same content should return same pointer
    try std.testing.expectEqual(str1.ptr, str3.ptr);
    try std.testing.expect(str1.ptr != str2.ptr);
    
    // Content should be correct
    try std.testing.expectEqualStrings("hello", str1);
    try std.testing.expectEqualStrings("world", str2);
    try std.testing.expectEqualStrings("hello", str3);
    
    // Statistics
    const stats = interner.getStats();
    try std.testing.expectEqual(@as(usize, 3), stats.total_interns);
    try std.testing.expectEqual(@as(usize, 2), stats.unique_strings);
    try std.testing.expectEqual(@as(usize, 1), stats.cache_hits);
    try std.testing.expectEqual(@as(usize, 2), stats.cache_misses);
}

test "StringInterner empty strings" {
    var interner = try StringInterner.init(std.testing.allocator);
    defer interner.deinit();
    
    const empty1 = try interner.intern("");
    const empty2 = try interner.intern("");
    
    try std.testing.expectEqual(empty1.ptr, empty2.ptr);
    try std.testing.expectEqual(@as(usize, 0), empty1.len);
}

test "StringInterner large string" {
    var interner = try StringInterner.init(std.testing.allocator);
    defer interner.deinit();
    
    const large = "a" ** 1000;
    const str1 = try interner.intern(large);
    const str2 = try interner.intern(large);
    
    try std.testing.expectEqual(str1.ptr, str2.ptr);
    try std.testing.expectEqual(@as(usize, 1000), str1.len);
}

test "StringInterner common constraint names" {
    var interner = try StringInterner.init(std.testing.allocator);
    defer interner.deinit();
    
    // Simulate common constraint extraction patterns
    const names = [_][]const u8{
        "async_function",
        "error_handling",
        "type_annotation",
        "async_function", // duplicate
        "function_declaration",
        "error_handling", // duplicate
        "async_function", // duplicate
    };
    
    var interned: [names.len][]const u8 = undefined;
    for (names, 0..) |name, i| {
        interned[i] = try interner.intern(name);
    }
    
    // Verify deduplication
    try std.testing.expectEqual(interned[0].ptr, interned[3].ptr); // async_function
    try std.testing.expectEqual(interned[0].ptr, interned[6].ptr); // async_function
    try std.testing.expectEqual(interned[1].ptr, interned[5].ptr); // error_handling
    
    const stats = interner.getStats();
    try std.testing.expectEqual(@as(usize, 7), stats.total_interns);
    try std.testing.expectEqual(@as(usize, 4), stats.unique_strings);
    try std.testing.expectEqual(@as(usize, 3), stats.cache_hits);
}

test "StringInterner memory safety with testing allocator" {
    // This test verifies no memory leaks using std.testing.allocator
    var interner = try StringInterner.init(std.testing.allocator);
    defer interner.deinit();
    
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        _ = try interner.intern("repeated");
        const unique = try std.fmt.allocPrint(std.testing.allocator, "unique_{}", .{i});
        defer std.testing.allocator.free(unique);
        _ = try interner.intern(unique);
    }
    
    const stats = interner.getStats();
    try std.testing.expectEqual(@as(usize, 200), stats.total_interns);
    try std.testing.expectEqual(@as(usize, 101), stats.unique_strings); // "repeated" + 100 unique
    try std.testing.expectEqual(@as(usize, 99), stats.cache_hits);
}

test "StringInterner hit rate calculation" {
    var interner = try StringInterner.init(std.testing.allocator);
    defer interner.deinit();
    
    // Create pattern: 50% duplicates
    var i: usize = 0;
    while (i < 10) : (i += 1) {
        _ = try interner.intern("common");
        const buf = try std.fmt.allocPrint(std.testing.allocator, "unique_{}", .{i});
        defer std.testing.allocator.free(buf);
        _ = try interner.intern(buf);
    }
    
    const stats = interner.getStats();
    try std.testing.expect(stats.hitRate() > 0.4 and stats.hitRate() < 0.5);
}
