//! Extraction Performance Benchmarks
//! Measures Clew extraction latency across different file sizes
//!
//! Target thresholds:
//! - Small (<100 LOC): p95 < 50ms
//! - Medium (100-1000 LOC): p95 < 150ms
//! - Large (>1000 LOC): p95 < 500ms

const std = @import("std");
const Clew = @import("clew").Clew;
const ananke = @import("ananke");

const Allocator = std.mem.Allocator;

pub const BenchmarkResult = struct {
    name: []const u8,
    file_path: []const u8,
    language: []const u8,
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

pub fn runExtractionBenchmarks(allocator: Allocator) ![]BenchmarkResult {
    var results = std.ArrayList(BenchmarkResult){};
    errdefer results.deinit(allocator);

    // Define test cases
    const test_cases = [_]struct {
        name: []const u8,
        file: []const u8,
        language: []const u8,
        expected_p95_ms: u64,
    }{
        .{ .name = "small_ts", .file = "bench/fixtures/small/simple.ts", .language = "typescript", .expected_p95_ms = 50 },
        .{ .name = "medium_ts", .file = "bench/fixtures/medium/api.ts", .language = "typescript", .expected_p95_ms = 150 },
        .{ .name = "large_ts", .file = "bench/fixtures/large/app.ts", .language = "typescript", .expected_p95_ms = 500 },
        .{ .name = "small_py", .file = "bench/fixtures/small/simple.py", .language = "python", .expected_p95_ms = 50 },
        .{ .name = "medium_py", .file = "bench/fixtures/medium/service.py", .language = "python", .expected_p95_ms = 150 },
        .{ .name = "large_py", .file = "bench/fixtures/large/app.py", .language = "python", .expected_p95_ms = 500 },
    };

    std.debug.print("\n=== Extraction Latency Benchmarks ===\n\n", .{});

    for (test_cases) |case| {
        const result = try benchmarkExtraction(allocator, case.name, case.file, case.language, case.expected_p95_ms);
        try results.append(allocator, result);

        // Print result
        std.debug.print("{s}:\n", .{case.name});
        std.debug.print("  File: {s}\n", .{case.file});
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
            std.debug.print("  Status: FAIL ✗ (p95 exceeds target by {d:.1}ms)\n\n", .{result.p95_ms - @as(f64, @floatFromInt(case.expected_p95_ms))});
        }
    }

    return try results.toOwnedSlice(allocator);
}

fn benchmarkExtraction(
    allocator: Allocator,
    name: []const u8,
    file_path: []const u8,
    language: []const u8,
    expected_p95_ms: u64,
) !BenchmarkResult {
    // Read source file
    const source = try std.fs.cwd().readFileAlloc(
        allocator,
        file_path,
        10 * 1024 * 1024,
    );
    defer allocator.free(source);

    var clew = try Clew.init(allocator);
    defer clew.deinit();

    // Warmup: 10 iterations
    for (0..10) |_| {
        var result = try clew.extractFromCode(source, language);
        result.deinit();
    }

    // Benchmark: 100 iterations
    const iterations: usize = 100;
    var latencies = try std.ArrayList(u64).initCapacity(allocator, iterations);
    defer latencies.deinit(allocator);

    for (0..iterations) |_| {
        const start = std.time.nanoTimestamp();
        var result = try clew.extractFromCode(source, language);
        const end = std.time.nanoTimestamp();
        result.deinit();

        const latency_ns: u64 = @intCast(end - start);
        try latencies.append(allocator, latency_ns);
    }

    // Calculate statistics
    const stats = calculateStats(latencies.items);

    return BenchmarkResult{
        .name = name,
        .file_path = file_path,
        .language = language,
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
