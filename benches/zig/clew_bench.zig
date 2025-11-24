//! Clew Performance Benchmarks
//! Target: <10ms constraint extraction for typical files

const std = @import("std");
const Clew = @import("clew").Clew;

// Benchmark sample code of various sizes
const SMALL_CODE =
    \\pub fn main() !void {
    \\    const x = 42;
    \\    std.debug.print("{}\n", .{x});
    \\}
;

const MEDIUM_CODE =
    \\pub fn fib(n: usize) usize {
    \\    if (n <= 1) return n;
    \\    return fib(n - 1) + fib(n - 2);
    \\}
    \\
    \\pub fn factorial(n: usize) usize {
    \\    if (n == 0) return 1;
    \\    return n * factorial(n - 1);
    \\}
    \\
    \\pub fn gcd(a: usize, b: usize) usize {
    \\    if (b == 0) return a;
    \\    return gcd(b, a % b);
    \\}
;

const LARGE_CODE = MEDIUM_CODE ++ MEDIUM_CODE ++ MEDIUM_CODE ++ MEDIUM_CODE;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== Clew Extraction Benchmarks ===\n\n", .{});

    // Benchmark small file extraction
    try benchmarkExtraction(allocator, "Small file (50 bytes)", SMALL_CODE, "zig", 1000);

    // Benchmark medium file extraction
    try benchmarkExtraction(allocator, "Medium file (200 bytes)", MEDIUM_CODE, "zig", 500);

    // Benchmark large file extraction
    try benchmarkExtraction(allocator, "Large file (800 bytes)", LARGE_CODE, "zig", 100);

    // Benchmark cache performance
    try benchmarkCacheHit(allocator, MEDIUM_CODE, "zig", 10000);

    // Benchmark memory allocation patterns
    try benchmarkMemoryUsage(allocator, LARGE_CODE, "zig");

    std.debug.print("\n=== Benchmarks Complete ===\n", .{});
}

fn benchmarkExtraction(
    allocator: std.mem.Allocator,
    name: []const u8,
    source: []const u8,
    language: []const u8,
    iterations: usize,
) !void {
    var clew = try Clew.init(allocator);
    defer clew.deinit();

    // Warmup
    _ = try clew.extractFromCode(source, language);

    var timer = try std.time.Timer.start();
    var total_ns: u64 = 0;

    for (0..iterations) |_| {
        timer.reset();
        var result = try clew.extractFromCode(source, language);
        total_ns += timer.read();
        result.deinit();
    }

    const avg_ns = total_ns / iterations;
    const avg_us = avg_ns / 1000;
    const avg_ms = avg_us / 1000;

    std.debug.print("{s}:\n", .{name});
    std.debug.print("  Iterations: {}\n", .{iterations});
    std.debug.print("  Average: {d:.2}ms ({d}μs)\n", .{ @as(f64, @floatFromInt(avg_ms)), avg_us });
    std.debug.print("  Total: {d:.2}ms\n", .{@as(f64, @floatFromInt(total_ns)) / 1_000_000.0});

    // Check against target
    if (avg_ms > 10) {
        std.debug.print("  ⚠️  WARNING: Exceeds 10ms target!\n", .{});
    } else {
        std.debug.print("  ✓ Within target (<10ms)\n", .{});
    }
    std.debug.print("\n", .{});
}

fn benchmarkCacheHit(
    allocator: std.mem.Allocator,
    source: []const u8,
    language: []const u8,
    iterations: usize,
) !void {
    var clew = try Clew.init(allocator);
    defer clew.deinit();

    // First extraction (cache miss)
    var timer = try std.time.Timer.start();
    _ = try clew.extractFromCode(source, language);
    const miss_time = timer.read();

    // Subsequent extractions (cache hits)
    timer.reset();
    var total_ns: u64 = 0;
    for (0..iterations) |_| {
        timer.reset();
        _ = try clew.extractFromCode(source, language);
        total_ns += timer.read();
    }

    const avg_hit_ns = total_ns / iterations;
    const avg_hit_us = avg_hit_ns / 1000;

    std.debug.print("Cache Performance:\n", .{});
    std.debug.print("  Cache miss: {d:.2}ms\n", .{@as(f64, @floatFromInt(miss_time)) / 1_000_000.0});
    std.debug.print("  Cache hit: {d:.2}μs\n", .{@as(f64, @floatFromInt(avg_hit_us))});
    std.debug.print("  Speedup: {d:.1}x\n", .{@as(f64, @floatFromInt(miss_time)) / @as(f64, @floatFromInt(avg_hit_ns))});
    std.debug.print("\n", .{});
}

fn benchmarkMemoryUsage(
    allocator: std.mem.Allocator,
    source: []const u8,
    language: []const u8,
) !void {
    // Note: Memory tracking removed in Zig 0.15.x
    // Use profiling tools like valgrind or heaptrack for memory analysis

    var clew = try Clew.init(allocator);
    defer clew.deinit();

    var result = try clew.extractFromCode(source, language);
    defer result.deinit();

    std.debug.print("Memory tracking not available in Zig 0.15.x\n", .{});
    std.debug.print("Use external profiling tools (valgrind, heaptrack) for memory analysis\n", .{});
    std.debug.print("\n", .{});
}
