//! Constraint Density Benchmarks
//! Tests compilation performance with varying constraint counts

const std = @import("std");
const Braid = @import("braid").Braid;
const Constraint = @import("ananke").types.constraint.Constraint;
const ConstraintKind = @import("ananke").types.constraint.ConstraintKind;
const Severity = @import("ananke").types.constraint.Severity;
const ConstraintSource = @import("ananke").types.constraint.ConstraintSource;

const DensityResult = struct {
    constraint_count: usize,
    avg_time_ns: u64,
    avg_time_ms: f64,
    per_constraint_us: f64,
    throughput_constraints_per_sec: f64,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== Constraint Density Benchmarks ===\n", .{});
    std.debug.print("Target: 10 constraints in <2ms\n\n", .{});

    var results = std.ArrayList(DensityResult).initCapacity(allocator, 10) catch unreachable;
    defer results.deinit(allocator);

    // Test different constraint densities
    const densities = [_]struct { name: []const u8, count: usize, iterations: usize }{
        .{ .name = "Low (5)", .count = 5, .iterations = 1000 },
        .{ .name = "Medium (20)", .count = 20, .iterations = 500 },
        .{ .name = "High (50)", .count = 50, .iterations = 200 },
        .{ .name = "Very High (100)", .count = 100, .iterations = 100 },
        .{ .name = "Extreme (250)", .count = 250, .iterations = 50 },
    };

    for (densities) |density| {
        std.debug.print("Testing {s} constraints...\n", .{density.name});
        const result = try benchmarkDensity(
            allocator,
            density.count,
            density.iterations,
        );
        try results.append(allocator, result);
    }

    // Print summary
    std.debug.print("\n=== Summary Table ===\n", .{});
    std.debug.print("| Count | Avg Time  | Per Constraint | Throughput      | Status |\n", .{});
    std.debug.print("|-------|-----------|----------------|-----------------|--------|\n", .{});

    for (results.items) |result| {
        const status = if (result.avg_time_ms < 50.0) "✓ OK" else "⚠ SLOW";
        std.debug.print("| {d: >5} | {d: >6.2}ms | {d: >11.2}μs | {d: >10.0} c/s | {s} |\n", .{
            result.constraint_count,
            result.avg_time_ms,
            result.per_constraint_us,
            result.throughput_constraints_per_sec,
            status,
        });
    }

    std.debug.print("\n=== Benchmarks Complete ===\n", .{});
}

fn createTestConstraint(allocator: std.mem.Allocator, index: usize) !Constraint {
    const name = try std.fmt.allocPrint(allocator, "constraint_{}", .{index});
    const description = try std.fmt.allocPrint(
        allocator,
        "Test constraint {} for density benchmarking",
        .{index},
    );

    return Constraint{
        .id = index,
        .name = name,
        .description = description,
        .kind = switch (index % 6) {
            0 => .syntactic,
            1 => .type_safety,
            2 => .semantic,
            3 => .architectural,
            4 => .operational,
            5 => .security,
            else => .syntactic,
        },
        .source = .AST_Pattern,
        .severity = if (index % 3 == 0) .err else if (index % 3 == 1) .warning else .info,
        .confidence = 0.8 + (@as(f32, @floatFromInt(index % 20)) / 100.0),
        .frequency = @as(u32, @intCast(index % 10 + 1)),
    };
}

fn benchmarkDensity(
    allocator: std.mem.Allocator,
    constraint_count: usize,
    iterations: usize,
) !DensityResult {
    var braid = try Braid.init(allocator);
    defer braid.deinit();

    // Create test constraints
    const constraints = try allocator.alloc(Constraint, constraint_count);
    defer allocator.free(constraints);

    for (constraints, 0..) |*c, i| {
        c.* = try createTestConstraint(allocator, i);
    }
    defer {
        for (constraints) |c| {
            allocator.free(c.name);
            allocator.free(c.description);
        }
    }

    // Warmup
    _ = try braid.compile(constraints);

    var timer = try std.time.Timer.start();
    var total_ns: u64 = 0;

    for (0..iterations) |_| {
        timer.reset();
        const ir = try braid.compile(constraints);
        total_ns += timer.read();
        _ = ir;
    }

    const avg_ns = total_ns / iterations;
    const avg_ms = @as(f64, @floatFromInt(avg_ns)) / 1_000_000.0;
    const per_constraint_us = @as(f64, @floatFromInt(avg_ns)) / (@as(f64, @floatFromInt(constraint_count)) * 1000.0);
    const throughput = @as(f64, @floatFromInt(constraint_count)) / (@as(f64, @floatFromInt(avg_ns)) / 1_000_000_000.0);

    return DensityResult{
        .constraint_count = constraint_count,
        .avg_time_ns = avg_ns,
        .avg_time_ms = avg_ms,
        .per_constraint_us = per_constraint_us,
        .throughput_constraints_per_sec = throughput,
    };
}
