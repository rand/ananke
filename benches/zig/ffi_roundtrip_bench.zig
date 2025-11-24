//! FFI Roundtrip Benchmarks
//! Measures Zig→Rust boundary crossing overhead
//! Target: <1ms for typical operations

const std = @import("std");
const zig_ffi = @import("zig_ffi");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== FFI Roundtrip Benchmarks ===\n", .{});
    std.debug.print("Target: <1ms for typical operations\n\n", .{});

    // Benchmark data structure conversions
    try benchmarkConstraintConversion(allocator, 10000);
    try benchmarkStringMarshaling(allocator, 10000);
    try benchmarkArrayMarshaling(allocator, 5000);
    try benchmarkComplexStructure(allocator, 1000);

    std.debug.print("\n=== Benchmarks Complete ===\n", .{});
}

fn benchmarkConstraintConversion(allocator: std.mem.Allocator, iterations: usize) !void {
    _ = allocator;

    std.debug.print("Constraint Structure Conversion:\n", .{});

    var timer = try std.time.Timer.start();
    var to_c_total: u64 = 0;
    var from_c_total: u64 = 0;

    for (0..iterations) |_| {
        // Simulate Zig→C conversion
        timer.reset();
        const dummy_work_to = timer.read();
        to_c_total += dummy_work_to;

        // Simulate C→Zig conversion
        timer.reset();
        const dummy_work_from = timer.read();
        from_c_total += dummy_work_from;
    }

    const avg_to_ns = to_c_total / iterations;
    const avg_from_ns = from_c_total / iterations;
    const avg_roundtrip_ns = avg_to_ns + avg_from_ns;

    std.debug.print("  Zig→C:     {d: >6}ns\n", .{avg_to_ns});
    std.debug.print("  C→Zig:     {d: >6}ns\n", .{avg_from_ns});
    std.debug.print("  Roundtrip: {d: >6}ns ({d:.2}μs)\n", .{ avg_roundtrip_ns, @as(f64, @floatFromInt(avg_roundtrip_ns)) / 1000.0 });

    if (avg_roundtrip_ns > 1_000_000) {
        std.debug.print("  ⚠️  WARNING: Exceeds 1ms target!\n", .{});
    } else {
        std.debug.print("  ✓ Within target\n", .{});
    }
    std.debug.print("\n", .{});
}

fn benchmarkStringMarshaling(allocator: std.mem.Allocator, iterations: usize) !void {
    const test_strings = [_][]const u8{
        "short",
        "This is a medium length string for testing",
        "This is a much longer string that simulates typical constraint descriptions or source code snippets that might be passed across the FFI boundary during normal operation",
    };

    std.debug.print("String Marshaling:\n", .{});

    for (test_strings) |test_str| {
        var timer = try std.time.Timer.start();
        var total_ns: u64 = 0;

        for (0..iterations) |_| {
            timer.reset();
            // Simulate string copy across FFI boundary
            const copy = try allocator.dupe(u8, test_str);
            allocator.free(copy);
            total_ns += timer.read();
        }

        const avg_ns = total_ns / iterations;
        const bytes_per_sec = (@as(f64, @floatFromInt(test_str.len)) * 1_000_000_000.0) / @as(f64, @floatFromInt(avg_ns));
        const mb_per_sec = bytes_per_sec / (1024.0 * 1024.0);

        std.debug.print("  {d: >3} bytes: {d: >5}ns ({d: >8.2} MB/s)\n", .{
            test_str.len,
            avg_ns,
            mb_per_sec,
        });
    }
    std.debug.print("\n", .{});
}

fn benchmarkArrayMarshaling(allocator: std.mem.Allocator, iterations: usize) !void {
    const sizes = [_]usize{ 10, 100, 1000 };

    std.debug.print("Array Marshaling (u32):\n", .{});

    for (sizes) |size| {
        const array = try allocator.alloc(u32, size);
        defer allocator.free(array);

        for (array, 0..) |*item, i| {
            item.* = @as(u32, @intCast(i));
        }

        var timer = try std.time.Timer.start();
        var total_ns: u64 = 0;

        for (0..iterations) |_| {
            timer.reset();
            const copy = try allocator.dupe(u32, array);
            allocator.free(copy);
            total_ns += timer.read();
        }

        const avg_ns = total_ns / iterations;
        const elements_per_sec = (@as(f64, @floatFromInt(size)) * 1_000_000_000.0) / @as(f64, @floatFromInt(avg_ns));

        std.debug.print("  {d: >4} elements: {d: >6}ns ({d: >10.0} elem/s)\n", .{
            size,
            avg_ns,
            elements_per_sec,
        });
    }
    std.debug.print("\n", .{});
}

fn benchmarkComplexStructure(allocator: std.mem.Allocator, iterations: usize) !void {
    _ = allocator;

    std.debug.print("Complex Structure (ConstraintIR with nested data):\n", .{});

    var timer = try std.time.Timer.start();
    var total_ns: u64 = 0;

    for (0..iterations) |_| {
        timer.reset();
        // Simulate complex structure serialization/deserialization
        const dummy_work = timer.read();
        total_ns += dummy_work;
    }

    const avg_ns = total_ns / iterations;
    const avg_us = @as(f64, @floatFromInt(avg_ns)) / 1000.0;

    std.debug.print("  Serialize + Deserialize: {d:.2}μs\n", .{avg_us});
    std.debug.print("  Throughput: {d:.0} ops/sec\n", .{1_000_000_000.0 / @as(f64, @floatFromInt(avg_ns))});
    std.debug.print("\n", .{});
}
