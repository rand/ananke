//! Braid Performance Benchmarks
//! Targets:
//! - IR compilation: <50ms
//! - Constraint validation: <50μs per token

const std = @import("std");
const Braid = @import("braid").Braid;
const Constraint = @import("ananke").types.constraint.Constraint;
const ConstraintKind = @import("ananke").types.constraint.ConstraintKind;
const Severity = @import("ananke").types.constraint.Severity;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== Braid Compilation Benchmarks ===\n\n", .{});

    // Benchmark with varying constraint counts
    try benchmarkCompilation(allocator, "Single constraint", 1, 1000);
    try benchmarkCompilation(allocator, "5 constraints", 5, 500);
    try benchmarkCompilation(allocator, "10 constraints", 10, 200);
    try benchmarkCompilation(allocator, "25 constraints", 25, 100);
    try benchmarkCompilation(allocator, "50 constraints", 50, 50);

    // Benchmark conflict detection
    try benchmarkConflictDetection(allocator, 10, 100);

    // Benchmark IR compilation
    try benchmarkIRCompilation(allocator, 10, 100);

    std.debug.print("\n=== Benchmarks Complete ===\n", .{});
}

fn createTestConstraint(allocator: std.mem.Allocator, index: usize) !Constraint {
    const name = try std.fmt.allocPrint(allocator, "constraint_{}", .{index});
    const description = try std.fmt.allocPrint(allocator, "Test constraint {}", .{index});

    return Constraint{
        .kind = if (index % 3 == 0) .type_safety else if (index % 3 == 1) .syntactic else .semantic,
        .severity = if (index % 2 == 0) .err else .warning,
        .name = name,
        .description = description,
        .source = .AST_Pattern,
        .confidence = 0.9,
    };
}

fn benchmarkCompilation(
    allocator: std.mem.Allocator,
    name: []const u8,
    constraint_count: usize,
    iterations: usize,
) !void {
    var braid = try Braid.init(allocator);
    defer braid.deinit();

    // Create test constraints
    const constraints = try allocator.alloc(Constraint, constraint_count);
    defer allocator.free(constraints);

    for (constraints, 0..) |*c, i| {
        c.* = try createTestConstraint(allocator, i);
    }

    // Warmup
    _ = try braid.compile(constraints);

    var timer = try std.time.Timer.start();
    var total_ns: u64 = 0;

    for (0..iterations) |_| {
        timer.reset();
        const ir = try braid.compile(constraints);
        total_ns += timer.read();
        _ = ir; // TODO: Add IR cleanup when available
    }

    const avg_ns = total_ns / iterations;
    const avg_us = avg_ns / 1000;
    const avg_ms = avg_us / 1000;

    std.debug.print("{s}:\n", .{name});
    std.debug.print("  Iterations: {}\n", .{iterations});
    std.debug.print("  Average: {d:.2}ms ({d}μs)\n", .{@as(f64, @floatFromInt(avg_ms)), avg_us});
    std.debug.print("  Throughput: {d:.0} constraints/sec\n", .{
        @as(f64, @floatFromInt(constraint_count * iterations)) / (@as(f64, @floatFromInt(total_ns)) / 1_000_000_000.0)
    });
    
    // Check against target
    if (avg_ms > 50) {
        std.debug.print("  ⚠️  WARNING: Exceeds 50ms target!\n", .{});
    } else {
        std.debug.print("  ✓ Within target (<50ms)\n", .{});
    }
    std.debug.print("\n", .{});

    // Cleanup
    for (constraints) |c| {
        allocator.free(c.name);
        allocator.free(c.description);
    }
}

fn benchmarkConflictDetection(
    allocator: std.mem.Allocator,
    constraint_count: usize,
    iterations: usize,
) !void {
    var braid = try Braid.init(allocator);
    defer braid.deinit();

    const constraints = try allocator.alloc(Constraint, constraint_count);
    defer allocator.free(constraints);

    for (constraints, 0..) |*c, i| {
        c.* = try createTestConstraint(allocator, i);
    }

    var timer = try std.time.Timer.start();
    var total_ns: u64 = 0;

    for (0..iterations) |_| {
        timer.reset();
        _ = try braid.compile(constraints);
        total_ns += timer.read();
    }

    const avg_us = (total_ns / iterations) / 1000;

    std.debug.print("Conflict Detection ({} constraints):\n", .{constraint_count});
    std.debug.print("  Average: {d}μs\n", .{avg_us});
    std.debug.print("  O(n²) complexity check: {d} pairs\n", .{constraint_count * (constraint_count - 1) / 2});
    std.debug.print("\n", .{});

    for (constraints) |c| {
        allocator.free(c.name);
        allocator.free(c.description);
    }
}

fn benchmarkIRCompilation(
    allocator: std.mem.Allocator,
    constraint_count: usize,
    iterations: usize,
) !void {
    var braid = try Braid.init(allocator);
    defer braid.deinit();

    const constraints = try allocator.alloc(Constraint, constraint_count);
    defer allocator.free(constraints);

    for (constraints, 0..) |*c, i| {
        c.* = try createTestConstraint(allocator, i);
    }

    var timer = try std.time.Timer.start();
    var total_ns: u64 = 0;

    for (0..iterations) |_| {
        timer.reset();
        _ = try braid.compile(constraints);
        total_ns += timer.read();
    }

    const avg_us = (total_ns / iterations) / 1000;

    std.debug.print("IR Compilation ({} constraints):\n", .{constraint_count});
    std.debug.print("  Average: {d}μs\n", .{avg_us});
    std.debug.print("  Per constraint: {d:.2}μs\n", .{@as(f64, @floatFromInt(avg_us)) / @as(f64, @floatFromInt(constraint_count))});
    std.debug.print("\n", .{});

    for (constraints) |c| {
        allocator.free(c.name);
        allocator.free(c.description);
    }
}
