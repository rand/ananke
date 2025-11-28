// Tests for Braid IR caching functionality
const std = @import("std");
const testing = std.testing;
const ananke = @import("ananke");
const braid = @import("braid");

// Import types
const Constraint = ananke.Constraint;
const ConstraintKind = ananke.ConstraintKind;
const ConstraintSource = ananke.ConstraintSource;
const ConstraintPriority = ananke.ConstraintPriority;
const Severity = ananke.Severity;
const ConstraintIR = ananke.ConstraintIR;
const Regex = ananke.Regex;
const Braid = braid.Braid;

test "ConstraintIR.clone: deep clones regex patterns independently" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create original ConstraintIR with regex patterns
    var patterns = try allocator.alloc(Regex, 2);
    patterns[0] = .{
        .pattern = try allocator.dupe(u8, "test_pattern_1"),
        .flags = try allocator.dupe(u8, "i"),
    };
    patterns[1] = .{
        .pattern = try allocator.dupe(u8, "test_pattern_2"),
        .flags = try allocator.dupe(u8, "g"),
    };

    var original = ConstraintIR{
        .regex_patterns = patterns,
        .priority = 10,
    };

    // Clone the IR
    var cloned = try original.clone(allocator);
    defer cloned.deinit(allocator);

    // Verify the clone has same data
    try testing.expectEqual(original.priority, cloned.priority);
    try testing.expectEqual(original.regex_patterns.len, cloned.regex_patterns.len);
    try testing.expectEqualStrings(original.regex_patterns[0].pattern, cloned.regex_patterns[0].pattern);
    try testing.expectEqualStrings(original.regex_patterns[1].pattern, cloned.regex_patterns[1].pattern);

    // Verify independence: modifying original doesn't affect clone
    // (We can't actually modify strings in-place safely, but we can verify different pointers)
    try testing.expect(original.regex_patterns.ptr != cloned.regex_patterns.ptr);
    try testing.expect(original.regex_patterns[0].pattern.ptr != cloned.regex_patterns[0].pattern.ptr);

    // Clean up original
    original.deinit(allocator);
}

test "ConstraintIR.clone: handles empty ConstraintIR correctly" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create empty ConstraintIR
    const original = ConstraintIR{
        .priority = 5,
    };

    // Clone should succeed
    var cloned = try original.clone(allocator);
    defer cloned.deinit(allocator);

    try testing.expectEqual(original.priority, cloned.priority);
    try testing.expectEqual(@as(usize, 0), cloned.regex_patterns.len);
}

test "Braid.computeCacheKey: same constraints produce same key" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var braid_instance = try Braid.init(allocator);
    defer braid_instance.deinit();

    // Create identical constraints
    const c1 = Constraint{
        .id = 1,
        .name = "test_constraint",
        .description = "Test description",
        .kind = .syntactic,
        .source = .AST_Pattern,
        .severity = .err,
    };

    const c2 = Constraint{
        .id = 2, // Different ID
        .name = "test_constraint",
        .description = "Test description",
        .kind = .syntactic,
        .source = .AST_Pattern,
        .severity = .err,
    };

    const constraints1 = [_]Constraint{c1};
    const constraints2 = [_]Constraint{c2};

    // Same content should produce same key (ID not included in hash)
    const key1 = try braid_instance.computeCacheKey(&constraints1);
    const key2 = try braid_instance.computeCacheKey(&constraints2);

    try testing.expectEqual(key1, key2);
}

test "Braid.computeCacheKey: order independence" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var braid_instance = try Braid.init(allocator);
    defer braid_instance.deinit();

    // Create two constraints
    const c1 = Constraint{
        .id = 1,
        .name = "constraint_a",
        .description = "First constraint",
        .kind = .syntactic,
        .source = .AST_Pattern,
        .severity = .err,
    };

    const c2 = Constraint{
        .id = 2,
        .name = "constraint_b",
        .description = "Second constraint",
        .kind = .type_safety,
        .source = .Type_System,
        .severity = .warning,
    };

    // Create arrays in different orders
    const constraints_ab = [_]Constraint{ c1, c2 };
    const constraints_ba = [_]Constraint{ c2, c1 };

    // Keys should be identical regardless of order
    const key_ab = try braid_instance.computeCacheKey(&constraints_ab);
    const key_ba = try braid_instance.computeCacheKey(&constraints_ba);

    try testing.expectEqual(key_ab, key_ba);
}

test "Braid.computeCacheKey: different constraints produce different keys" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var braid_instance = try Braid.init(allocator);
    defer braid_instance.deinit();

    const c1 = Constraint{
        .id = 1,
        .name = "constraint_a",
        .description = "First constraint",
        .kind = .syntactic,
        .source = .AST_Pattern,
        .severity = .err,
    };

    const c2 = Constraint{
        .id = 2,
        .name = "constraint_b",
        .description = "Different constraint",
        .kind = .security,
        .source = .User_Defined,
        .severity = .warning,
    };

    const constraints1 = [_]Constraint{c1};
    const constraints2 = [_]Constraint{c2};

    const key1 = try braid_instance.computeCacheKey(&constraints1);
    const key2 = try braid_instance.computeCacheKey(&constraints2);

    // Different constraints should produce different keys
    try testing.expect(key1 != key2);
}

test "IRCache: basic get/put operations" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var braid_instance = try Braid.init(allocator);
    defer braid_instance.deinit();

    // Create a test ConstraintIR
    var patterns = try allocator.alloc(Regex, 1);
    patterns[0] = .{
        .pattern = try allocator.dupe(u8, "test"),
        .flags = try allocator.dupe(u8, ""),
    };

    const ir = ConstraintIR{
        .regex_patterns = patterns,
        .priority = 42,
    };

    const test_key: u64 = 12345;

    // Initially should be a miss
    const miss = try braid_instance.cache.get(test_key);
    try testing.expect(miss == null);

    // Put IR in cache
    const ir_for_cache = try ir.clone(allocator);
    try braid_instance.cache.put(test_key, ir_for_cache);

    // Now should be a hit
    var hit = try braid_instance.cache.get(test_key);
    try testing.expect(hit != null);
    defer hit.?.deinit(allocator);

    // Verify the cached data
    try testing.expectEqual(ir.priority, hit.?.priority);
    try testing.expectEqual(ir.regex_patterns.len, hit.?.regex_patterns.len);

    // Clean up original
    var ir_mut = ir;
    ir_mut.deinit(allocator);
}

test "IRCache: stats tracking" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var braid_instance = try Braid.init(allocator);
    defer braid_instance.deinit();

    // Initial stats should be empty
    var stats = braid_instance.cache.stats();
    try testing.expectEqual(@as(usize, 0), stats.entry_count);
    try testing.expectEqual(@as(u64, 0), stats.total_hits);

    // Add an entry
    const ir = ConstraintIR{ .priority = 1 };
    const ir_for_cache = try ir.clone(allocator);
    try braid_instance.cache.put(123, ir_for_cache);

    stats = braid_instance.cache.stats();
    try testing.expectEqual(@as(usize, 1), stats.entry_count);
    try testing.expectEqual(@as(u64, 0), stats.total_hits); // No hits yet

    // Access the entry multiple times
    var hit1 = try braid_instance.cache.get(123);
    try testing.expect(hit1 != null);
    if (hit1) |h| h.deinit(allocator);

    var hit2 = try braid_instance.cache.get(123);
    try testing.expect(hit2 != null);
    if (hit2) |h| h.deinit(allocator);

    var hit3 = try braid_instance.cache.get(123);
    try testing.expect(hit3 != null);
    if (hit3) |h| h.deinit(allocator);

    // Should now have 3 hits
    stats = braid_instance.cache.stats();
    try testing.expectEqual(@as(usize, 1), stats.entry_count);
    try testing.expectEqual(@as(u64, 3), stats.total_hits);
}

test "Braid.compile: cache hit provides significant speedup" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var braid_instance = try Braid.init(allocator);
    defer braid_instance.deinit();

    // Create test constraints
    var constraints = try allocator.alloc(Constraint, 10);
    defer allocator.free(constraints);

    for (constraints, 0..) |*c, i| {
        const name = try std.fmt.allocPrint(allocator, "constraint_{d}", .{i});
        defer allocator.free(name);
        const desc = try std.fmt.allocPrint(allocator, "Description {d}", .{i});
        defer allocator.free(desc);

        c.* = Constraint{
            .id = @intCast(i),
            .name = try allocator.dupe(u8, name),
            .description = try allocator.dupe(u8, desc),
            .kind = .syntactic,
            .source = .AST_Pattern,
            .severity = .err,
        };
    }

    // First compilation (cache miss)
    const start_cold = std.time.nanoTimestamp();
    var ir1 = try braid_instance.compile(constraints);
    const end_cold = std.time.nanoTimestamp();
    defer ir1.deinit(allocator);

    const cold_time = end_cold - start_cold;

    // Second compilation (cache hit)
    const start_warm = std.time.nanoTimestamp();
    var ir2 = try braid_instance.compile(constraints);
    const end_warm = std.time.nanoTimestamp();
    defer ir2.deinit(allocator);

    const warm_time = end_warm - start_warm;

    // Cache hit should be significantly faster (at least 2x)
    const speedup = @as(f64, @floatFromInt(cold_time)) / @as(f64, @floatFromInt(warm_time));

    // Print for debugging
    std.debug.print("\nCache performance: cold={d}ns, warm={d}ns, speedup={d:.1}x\n", .{ cold_time, warm_time, speedup });

    // Expect at least 2x speedup (conservative, benchmarks show >10x)
    try testing.expect(speedup >= 2.0);

    // Verify cache stats
    const stats = braid_instance.cache.stats();
    try testing.expectEqual(@as(usize, 1), stats.entry_count);
    try testing.expectEqual(@as(u64, 1), stats.total_hits);

    // Clean up constraint strings
    for (constraints) |c| {
        allocator.free(c.name);
        allocator.free(c.description);
    }
}

test "Braid.compile: multiple distinct constraint sets cached independently" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var braid_instance = try Braid.init(allocator);
    defer braid_instance.deinit();

    // Create first constraint set
    const c1 = Constraint{
        .id = 1,
        .name = "constraint_set_1",
        .description = "First set",
        .kind = .syntactic,
        .source = .AST_Pattern,
        .severity = .err,
    };
    const constraints1 = [_]Constraint{c1};

    // Create second constraint set (different)
    const c2 = Constraint{
        .id = 2,
        .name = "constraint_set_2",
        .description = "Second set",
        .kind = .security,
        .source = .User_Defined,
        .severity = .warning,
    };
    const constraints2 = [_]Constraint{c2};

    // Compile both sets
    var ir1 = try braid_instance.compile(&constraints1);
    defer ir1.deinit(allocator);

    var ir2 = try braid_instance.compile(&constraints2);
    defer ir2.deinit(allocator);

    // Should have 2 cached entries
    const stats = braid_instance.cache.stats();
    try testing.expectEqual(@as(usize, 2), stats.entry_count);

    // Compile again - both should hit cache
    var ir1_cached = try braid_instance.compile(&constraints1);
    defer ir1_cached.deinit(allocator);

    var ir2_cached = try braid_instance.compile(&constraints2);
    defer ir2_cached.deinit(allocator);

    // Still 2 entries, but 2 hits
    const stats_after = braid_instance.cache.stats();
    try testing.expectEqual(@as(usize, 2), stats_after.entry_count);
    try testing.expectEqual(@as(u64, 2), stats_after.total_hits);
}
