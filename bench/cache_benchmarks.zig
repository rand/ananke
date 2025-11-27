//! Cache Effectiveness Benchmarks
//! Measures cache performance and speedup
//!
//! Target: >10x speedup on cache hit

const std = @import("std");
const Braid = @import("braid").Braid;
const ananke = @import("ananke");

const Allocator = std.mem.Allocator;
const Constraint = ananke.Constraint;

pub const CacheResult = struct {
    name: []const u8,
    cold_latency_us: u64,
    warm_latency_us: u64,
    speedup: f64,
    iterations: usize,
    pass: bool,
};

pub fn runCacheBenchmarks(allocator: Allocator) ![]CacheResult {
    var results = std.ArrayList(CacheResult){};
    errdefer results.deinit(allocator);

    std.debug.print("\n=== Cache Effectiveness Benchmarks ===\n\n", .{});

    // Test cache with different constraint counts
    const test_cases = [_]struct {
        name: []const u8,
        constraint_count: usize,
    }{
        .{ .name = "cache_10_constraints", .constraint_count = 10 },
        .{ .name = "cache_50_constraints", .constraint_count = 50 },
        .{ .name = "cache_100_constraints", .constraint_count = 100 },
    };

    for (test_cases) |case| {
        const result = try benchmarkCache(allocator, case.name, case.constraint_count);
        try results.append(allocator, result);

        std.debug.print("{s}:\n", .{case.name});
        std.debug.print("  Constraints: {}\n", .{case.constraint_count});
        std.debug.print("  Cold (first compilation): {d:.2}μs\n", .{@as(f64, @floatFromInt(result.cold_latency_us))});
        std.debug.print("  Warm (cached): {d:.2}μs (avg over {} iterations)\n", .{ @as(f64, @floatFromInt(result.warm_latency_us)), result.iterations });
        std.debug.print("  Speedup: {d:.1}x (target: >10x)\n", .{result.speedup});

        if (result.pass) {
            std.debug.print("  Status: PASS ✓\n\n", .{});
        } else {
            std.debug.print("  Status: FAIL ✗ (speedup below 10x target)\n\n", .{});
        }
    }

    return try results.toOwnedSlice(allocator);
}

fn benchmarkCache(
    allocator: Allocator,
    name: []const u8,
    constraint_count: usize,
) !CacheResult {
    // Generate test constraints
    const constraints = try generateConstraints(allocator, constraint_count);
    defer {
        for (constraints) |*c| {
            allocator.free(c.description);
        }
        allocator.free(constraints);
    }

    var braid = try Braid.init(allocator);
    defer braid.deinit();

    // Cold cache: first compilation
    const cold_start = std.time.nanoTimestamp();
    var compiled1 = try braid.compile(constraints);
    const cold_end = std.time.nanoTimestamp();
    compiled1.deinit(allocator);

    const cold_latency_ns: u64 = @intCast(cold_end - cold_start);

    // Warm cache: repeated compilations
    const iterations: usize = 100;
    var total_warm_ns: u64 = 0;

    for (0..iterations) |_| {
        const warm_start = std.time.nanoTimestamp();
        var compiled2 = try braid.compile(constraints);
        const warm_end = std.time.nanoTimestamp();
        compiled2.deinit(allocator);

        total_warm_ns += @as(u64, @intCast(warm_end - warm_start));
    }

    const avg_warm_ns = total_warm_ns / iterations;
    const speedup = @as(f64, @floatFromInt(cold_latency_ns)) / @as(f64, @floatFromInt(avg_warm_ns));

    return CacheResult{
        .name = name,
        .cold_latency_us = cold_latency_ns / 1000,
        .warm_latency_us = avg_warm_ns / 1000,
        .speedup = speedup,
        .iterations = iterations,
        .pass = speedup >= 10.0,
    };
}

fn generateConstraints(allocator: Allocator, count: usize) ![]Constraint {
    var constraints = try std.ArrayList(Constraint).initCapacity(allocator, count);
    errdefer constraints.deinit(allocator);

    for (0..count) |i| {
        const name = try std.fmt.allocPrint(allocator, "cache_constraint_{}", .{i});
        const desc = try std.fmt.allocPrint(allocator, "Cache test constraint {}", .{i});
        const constraint = Constraint{
            .name = name,
            .description = desc,
            .kind = .syntactic,
            .priority = .Medium,
            .severity = .err,
        };
        try constraints.append(allocator, constraint);
    }

    return try constraints.toOwnedSlice(allocator);
}
