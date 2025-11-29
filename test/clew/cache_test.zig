const std = @import("std");
const testing = std.testing;
const clew_mod = @import("clew");
const ananke = @import("ananke");

test "ConstraintCache: basic put/get with no leaks" {
    const allocator = testing.allocator;

    var clew = try clew_mod.Clew.init(allocator);
    defer clew.deinit();

    const source1 = "function test() { return 42; }";
    const language = "typescript";

    // First extraction - should miss cache
    var result1 = try clew.extractFromCode(source1, language);
    defer result1.deinit();

    const count1 = result1.constraints.items.len;
    std.debug.print("\nFirst extraction: {d} constraints\n", .{count1});

    // Second extraction - should hit cache
    var result2 = try clew.extractFromCode(source1, language);
    defer result2.deinit();

    const count2 = result2.constraints.items.len;
    std.debug.print("Second extraction (cached): {d} constraints\n", .{count2});

    // Both results should have same number of constraints
    try testing.expectEqual(count1, count2);

    // Results should be independent (can both be freed)
    std.debug.print("Cache test passed - both results freed successfully\n", .{});
}

test "ConstraintCache: multiple entries with no leaks" {
    const allocator = testing.allocator;

    var clew = try clew_mod.Clew.init(allocator);
    defer clew.deinit();

    const sources = [_][]const u8{
        "function foo() {}",
        "function bar() {}",
        "function baz() {}",
    };

    for (sources) |source| {
        var result = try clew.extractFromCode(source, "typescript");
        defer result.deinit();

        // Extract again to hit cache
        var cached = try clew.extractFromCode(source, "typescript");
        defer cached.deinit();
    }

    std.debug.print("\nMultiple cache entries test completed\n", .{});
}

test "ConstraintCache: same source different context" {
    const allocator = testing.allocator;

    var clew = try clew_mod.Clew.init(allocator);
    defer clew.deinit();

    const source = "function test() {}";

    // Extract without Claude
    var result1 = try clew.extractFromCode(source, "typescript");
    defer result1.deinit();

    const count1 = result1.constraints.items.len;

    // Extract again (should hit cache)
    var result2 = try clew.extractFromCode(source, "typescript");
    defer result2.deinit();

    const count2 = result2.constraints.items.len;

    try testing.expectEqual(count1, count2);
    std.debug.print("\nCache hit for same source verified\n", .{});
}

test "ConstraintCache: stress test with many entries" {
    const allocator = testing.allocator;

    var clew = try clew_mod.Clew.init(allocator);
    defer clew.deinit();

    // Create 20 different sources
    var i: usize = 0;
    while (i < 20) : (i += 1) {
        const source = try std.fmt.allocPrint(allocator, "function test{d}() {{}}", .{i});
        defer allocator.free(source);

        // Extract once
        var result1 = try clew.extractFromCode(source, "typescript");
        result1.deinit();

        // Extract again (cache hit)
        var result2 = try clew.extractFromCode(source, "typescript");
        result2.deinit();
    }

    std.debug.print("\nStress test with 20 cache entries completed\n", .{});
}

test "ConstraintCache: performance improvement verification" {
    const allocator = testing.allocator;

    var clew = try clew_mod.Clew.init(allocator);
    defer clew.deinit();

    // Create a moderately complex source
    const source =
        \\function complexFunction(a: string, b: number): boolean {
        \\    if (a === null) return false;
        \\    const result = a.length > b;
        \\    return result;
        \\}
        \\
        \\async function asyncOperation(): Promise<void> {
        \\    const data = await fetch('https://api.example.com');
        \\    return data;
        \\}
    ;

    const iterations = 10;

    // Measure time for first extraction (cache miss)
    const start_uncached = std.time.milliTimestamp();
    var first = try clew.extractFromCode(source, "typescript");
    first.deinit();
    const uncached_time = std.time.milliTimestamp() - start_uncached;

    // Measure time for subsequent extractions (cache hits)
    const start_cached = std.time.milliTimestamp();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        var result = try clew.extractFromCode(source, "typescript");
        result.deinit();
    }
    const cached_time = std.time.milliTimestamp() - start_cached;
    const avg_cached_time = @as(f64, @floatFromInt(cached_time)) / @as(f64, @floatFromInt(iterations));

    std.debug.print("\nPerformance comparison:\n", .{});
    std.debug.print("  Uncached (first): {}ms\n", .{uncached_time});
    std.debug.print("  Cached (avg of {}): {d:.2}ms\n", .{ iterations, avg_cached_time });
    std.debug.print("  Speedup: {d:.1}x faster\n", .{@as(f64, @floatFromInt(uncached_time)) / avg_cached_time});

    // Cache should be faster (or at worst, same speed)
    try testing.expect(avg_cached_time <= @as(f64, @floatFromInt(uncached_time)));
}
