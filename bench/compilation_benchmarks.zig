//! Compilation Performance Benchmarks
//! Measures Braid constraint compilation latency
//!
//! Target thresholds:
//! - Single constraint: p95 < 10ms
//! - 10 constraints: p95 < 50ms
//! - 100 constraints: p95 < 500ms

const std = @import("std");
const Braid = @import("braid").Braid;
const ananke = @import("ananke");

const Allocator = std.mem.Allocator;
const Constraint = ananke.Constraint;

pub const CompilationResult = struct {
    name: []const u8,
    constraint_count: usize,
    iterations: usize,
    p50_ms: f64,
    p95_ms: f64,
    p99_ms: f64,
    max_ms: f64,
    min_ms: f64,
    mean_ms: f64,
    expected_p95_ms: u64,
    pass: bool,
};

pub fn runCompilationBenchmarks(allocator: Allocator) ![]CompilationResult {
    var results = std.ArrayList(CompilationResult){};
    errdefer results.deinit(allocator);

    const test_cases = [_]struct {
        name: []const u8,
        constraint_count: usize,
        expected_p95_ms: u64,
    }{
        .{ .name = "single_constraint", .constraint_count = 1, .expected_p95_ms = 10 },
        .{ .name = "ten_constraints", .constraint_count = 10, .expected_p95_ms = 50 },
        .{ .name = "hundred_constraints", .constraint_count = 100, .expected_p95_ms = 500 },
    };

    std.debug.print("\n=== Compilation Performance Benchmarks ===\n\n", .{});

    for (test_cases) |case| {
        const result = try benchmarkCompilation(allocator, case.name, case.constraint_count, case.expected_p95_ms);
        try results.append(allocator, result);

        std.debug.print("{s}:\n", .{case.name});
        std.debug.print("  Constraints: {}\n", .{case.constraint_count});
        std.debug.print("  Iterations: {}\n", .{result.iterations});
        std.debug.print("  p50: {d:.2}ms\n", .{result.p50_ms});
        std.debug.print("  p95: {d:.2}ms (target: {}ms)\n", .{ result.p95_ms, case.expected_p95_ms });
        std.debug.print("  p99: {d:.2}ms\n", .{result.p99_ms});
        std.debug.print("  max: {d:.2}ms\n", .{result.max_ms});
        std.debug.print("  min: {d:.2}ms\n", .{result.min_ms});
        std.debug.print("  mean: {d:.2}ms\n", .{result.mean_ms});

        if (result.pass) {
            std.debug.print("  Status: PASS ✓\n\n", .{});
        } else {
            std.debug.print("  Status: FAIL ✗\n\n", .{});
        }
    }

    return try results.toOwnedSlice(allocator);
}

fn benchmarkCompilation(
    allocator: Allocator,
    name: []const u8,
    constraint_count: usize,
    expected_p95_ms: u64,
) !CompilationResult {
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

    // Warmup: 10 iterations
    for (0..10) |_| {
        var result = try braid.compile(constraints);
        result.deinit(allocator);
    }

    // Benchmark: 100 iterations
    const iterations: usize = 100;
    var latencies = try std.ArrayList(u64).initCapacity(allocator, iterations);
    defer latencies.deinit(allocator);

    for (0..iterations) |_| {
        const start = std.time.nanoTimestamp();
        var result = try braid.compile(constraints);
        const end = std.time.nanoTimestamp();
        result.deinit(allocator);

        const latency_ns: u64 = @intCast(end - start);
        try latencies.append(allocator, latency_ns);
    }

    // Calculate statistics
    const stats = calculateStats(latencies.items);

    return CompilationResult{
        .name = name,
        .constraint_count = constraint_count,
        .iterations = iterations,
        .p50_ms = @as(f64, @floatFromInt(stats.p50)) / 1_000_000.0,
        .p95_ms = @as(f64, @floatFromInt(stats.p95)) / 1_000_000.0,
        .p99_ms = @as(f64, @floatFromInt(stats.p99)) / 1_000_000.0,
        .max_ms = @as(f64, @floatFromInt(stats.max)) / 1_000_000.0,
        .min_ms = @as(f64, @floatFromInt(stats.min)) / 1_000_000.0,
        .mean_ms = @as(f64, @floatFromInt(stats.mean)) / 1_000_000.0,
        .expected_p95_ms = expected_p95_ms,
        .pass = stats.p95 / 1_000_000 <= expected_p95_ms,
    };
}

fn generateConstraints(allocator: Allocator, count: usize) ![]Constraint {
    var constraints = try std.ArrayList(Constraint).initCapacity(allocator, count);
    errdefer constraints.deinit(allocator);

    for (0..count) |i| {
        const name = try std.fmt.allocPrint(allocator, "constraint_{}", .{i});
        const desc = try std.fmt.allocPrint(allocator, "Test constraint {}", .{i});
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

const Stats = struct {
    p50: u64,
    p95: u64,
    p99: u64,
    max: u64,
    min: u64,
    mean: u64,
};

fn calculateStats(latencies: []const u64) Stats {
    const sorted = std.heap.page_allocator.alloc(u64, latencies.len) catch unreachable;
    defer std.heap.page_allocator.free(sorted);

    @memcpy(sorted, latencies);
    std.mem.sort(u64, sorted, {}, comptime std.sort.asc(u64));

    const p50_idx = (sorted.len * 50) / 100;
    const p95_idx = (sorted.len * 95) / 100;
    const p99_idx = (sorted.len * 99) / 100;

    var sum: u64 = 0;
    for (sorted) |lat| {
        sum += lat;
    }

    return Stats{
        .p50 = sorted[p50_idx],
        .p95 = sorted[p95_idx],
        .p99 = sorted[p99_idx],
        .max = sorted[sorted.len - 1],
        .min = sorted[0],
        .mean = sum / sorted.len,
    };
}
