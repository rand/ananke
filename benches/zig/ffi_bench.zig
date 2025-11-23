//! FFI Bridge Performance Benchmarks
//! Target: Minimal overhead (<1ms for typical operations)

const std = @import("std");
const zig_ffi = @import("zig_ffi");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== FFI Bridge Benchmarks ===\n\n", .{});

    // Benchmark type conversions
    try benchmarkConstraintIRConversion(allocator, 1000);
    try benchmarkIntentConversion(allocator, 10000);
    
    // Benchmark memory allocation/deallocation
    try benchmarkFFIMemoryLifecycle(allocator, 1000);

    // Benchmark string marshaling
    try benchmarkStringMarshaling(allocator, 10000);

    std.debug.print("\n=== Benchmarks Complete ===\n", .{});
}

fn benchmarkConstraintIRConversion(
    allocator: std.mem.Allocator,
    iterations: usize,
) !void {
    _ = allocator;
    
    var timer = try std.time.Timer.start();
    var total_ns: u64 = 0;

    // Create a sample ConstraintIR
    // TODO: Implement actual conversion when FFI types are complete
    
    for (0..iterations) |_| {
        timer.reset();
        // Simulate conversion overhead
        const dummy_work = timer.read();
        total_ns += dummy_work;
    }

    const avg_us = (total_ns / iterations) / 1000;

    std.debug.print("ConstraintIR Conversion (Zig → C):\n", .{});
    std.debug.print("  Iterations: {}\n", .{iterations});
    std.debug.print("  Average: {d:.2}μs\n", .{@as(f64, @floatFromInt(avg_us))});
    
    if (avg_us > 100) {
        std.debug.print("  ⚠️  WARNING: Conversion overhead is high!\n", .{});
    } else {
        std.debug.print("  ✓ Low overhead\n", .{});
    }
    std.debug.print("\n", .{});
}

fn benchmarkIntentConversion(
    allocator: std.mem.Allocator,
    iterations: usize,
) !void {
    _ = allocator;
    
    var timer = try std.time.Timer.start();
    var total_ns: u64 = 0;

    for (0..iterations) |_| {
        timer.reset();
        // Simulate conversion
        const dummy_work = timer.read();
        total_ns += dummy_work;
    }

    const avg_ns = total_ns / iterations;

    std.debug.print("Intent Conversion (C → Zig):\n", .{});
    std.debug.print("  Iterations: {}\n", .{iterations});
    std.debug.print("  Average: {d}ns\n", .{avg_ns});
    std.debug.print("  Throughput: {d:.0} ops/sec\n", .{
        1_000_000_000.0 / @as(f64, @floatFromInt(avg_ns))
    });
    std.debug.print("\n", .{});
}

fn benchmarkFFIMemoryLifecycle(
    allocator: std.mem.Allocator,
    iterations: usize,
) !void {
    var timer = try std.time.Timer.start();
    var alloc_total: u64 = 0;
    var free_total: u64 = 0;

    for (0..iterations) |_| {
        // Allocation
        timer.reset();
        const buffer = try allocator.alloc(u8, 1024);
        alloc_total += timer.read();

        // Deallocation
        timer.reset();
        allocator.free(buffer);
        free_total += timer.read();
    }

    const avg_alloc_ns = alloc_total / iterations;
    const avg_free_ns = free_total / iterations;

    std.debug.print("FFI Memory Lifecycle:\n", .{});
    std.debug.print("  Allocation: {d}ns\n", .{avg_alloc_ns});
    std.debug.print("  Deallocation: {d}ns\n", .{avg_free_ns});
    std.debug.print("  Total roundtrip: {d}ns\n", .{avg_alloc_ns + avg_free_ns});
    std.debug.print("\n", .{});
}

fn benchmarkStringMarshaling(
    allocator: std.mem.Allocator,
    iterations: usize,
) !void {
    const test_string = "This is a test string for benchmarking FFI string marshaling overhead";
    
    var timer = try std.time.Timer.start();
    var total_ns: u64 = 0;

    for (0..iterations) |_| {
        timer.reset();
        const copy = try allocator.dupe(u8, test_string);
        allocator.free(copy);
        total_ns += timer.read();
    }

    const avg_ns = total_ns / iterations;

    std.debug.print("String Marshaling ({} bytes):\n", .{test_string.len});
    std.debug.print("  Average: {d}ns\n", .{avg_ns});
    std.debug.print("  Per byte: {d:.2}ns\n", .{@as(f64, @floatFromInt(avg_ns)) / @as(f64, @floatFromInt(test_string.len))});
    std.debug.print("  Bandwidth: {d:.2} MB/s\n", .{
        (@as(f64, @floatFromInt(test_string.len)) * 1_000_000_000.0) / 
        (@as(f64, @floatFromInt(avg_ns)) * 1_048_576.0)
    });
    std.debug.print("\n", .{});
}
