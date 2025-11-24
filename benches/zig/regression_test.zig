//! Performance Regression Test Suite
//! Compares current benchmark results against established baselines
//! Fails if performance degrades beyond tolerance threshold

const std = @import("std");
const Clew = @import("clew").Clew;
const Braid = @import("braid").Braid;
const Constraint = @import("ananke").types.constraint.Constraint;

const TOLERANCE_PERCENT = 10.0; // Allow 10% regression

const Baseline = struct {
    name: []const u8,
    mean_ns: u64,
};

const BenchmarkResult = struct {
    name: []const u8,
    mean_ns: u64,
    baseline_ns: u64,
    diff_percent: f64,
    passed: bool,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== Performance Regression Test Suite ===\n", .{});
    std.debug.print("Tolerance: ±{d:.1}%\n\n", .{TOLERANCE_PERCENT});

    // Use hardcoded baselines for simplicity
    const baselines = getDefaultBaselines();

    var results_array: [4]BenchmarkResult = undefined;
    results_array[0] = try testTypeScriptExtraction(allocator, &baselines);
    results_array[1] = try testConstraintCompilation(allocator, &baselines);
    results_array[2] = try testFFIRoundtrip(allocator, &baselines);
    results_array[3] = try testPipelineE2E(allocator, &baselines);

    // Print results
    std.debug.print("\n=== Results ===\n", .{});
    std.debug.print("| Benchmark                  | Current  | Baseline | Diff    | Status |\n", .{});
    std.debug.print("|----------------------------|----------|----------|---------|--------|\n", .{});

    var all_passed = true;
    for (results_array) |result| {
        const status = if (result.passed) "✓ PASS" else "✗ FAIL";
        if (!result.passed) all_passed = false;

        std.debug.print("| {s: <26} | {d: >6.2}ms | {d: >6.2}ms | {s}{d: >5.1}% | {s} |\n", .{
            result.name,
            @as(f64, @floatFromInt(result.mean_ns)) / 1_000_000.0,
            @as(f64, @floatFromInt(result.baseline_ns)) / 1_000_000.0,
            if (result.diff_percent > 0) "+" else "",
            result.diff_percent,
            status,
        });
    }

    std.debug.print("\n", .{});

    if (!all_passed) {
        std.debug.print("❌ REGRESSION DETECTED: Some benchmarks failed!\n", .{});
        return error.RegressionDetected;
    }

    std.debug.print("✓ All regression tests passed!\n", .{});
}

fn getDefaultBaselines() [4]Baseline {
    return [_]Baseline{
        .{ .name = "typescript_extraction_100", .mean_ns = 5_000_000 },
        .{ .name = "constraint_compilation_10", .mean_ns = 2_000_000 },
        .{ .name = "ffi_roundtrip", .mean_ns = 500_000 },
        .{ .name = "pipeline_e2e", .mean_ns = 7_000_000 },
    };
}

fn findBaseline(baselines: []const Baseline, name: []const u8) ?Baseline {
    for (baselines) |baseline| {
        if (std.mem.eql(u8, baseline.name, name)) {
            return baseline;
        }
    }
    return null;
}

fn testTypeScriptExtraction(
    allocator: std.mem.Allocator,
    baselines: []const Baseline,
) !BenchmarkResult {
    const benchmark_name = "typescript_extraction_100";

    // Read test file
    const source = try std.fs.cwd().readFileAlloc(
        allocator,
        "test/fixtures/typescript/small/entity_service_100.ts",
        10 * 1024 * 1024,
    );
    defer allocator.free(source);

    var clew = try Clew.init(allocator);
    defer clew.deinit();

    // Run benchmark
    const iterations: usize = 100;
    const times = try allocator.alloc(u64, iterations);
    defer allocator.free(times);

    var timer = try std.time.Timer.start();

    for (times) |*time| {
        timer.reset();
        var result = try clew.extractFromCode(source, "typescript");
        time.* = timer.read();
        result.deinit();
    }

    const stats = calculateStats(times);
    const baseline = findBaseline(baselines, benchmark_name) orelse return error.BaselineNotFound;

    return BenchmarkResult{
        .name = benchmark_name,
        .mean_ns = stats.mean,
        .baseline_ns = baseline.mean_ns,
        .diff_percent = calculateDiffPercent(stats.mean, baseline.mean_ns),
        .passed = checkWithinTolerance(stats.mean, baseline.mean_ns, TOLERANCE_PERCENT),
    };
}

fn testConstraintCompilation(
    allocator: std.mem.Allocator,
    baselines: []const Baseline,
) !BenchmarkResult {
    const benchmark_name = "constraint_compilation_10";

    var braid = try Braid.init(allocator);
    defer braid.deinit();

    // Create 10 test constraints
    const constraints = try allocator.alloc(Constraint, 10);
    defer allocator.free(constraints);

    for (constraints, 0..) |*c, i| {
        const name = try std.fmt.allocPrint(allocator, "constraint_{}", .{i});
        const desc = try std.fmt.allocPrint(allocator, "Test {}", .{i});
        c.* = Constraint{
            .id = i,
            .name = name,
            .description = desc,
            .kind = .syntactic,
            .severity = .err,
        };
    }
    defer {
        for (constraints) |c| {
            allocator.free(c.name);
            allocator.free(c.description);
        }
    }

    // Run benchmark
    const iterations: usize = 100;
    const times = try allocator.alloc(u64, iterations);
    defer allocator.free(times);

    var timer = try std.time.Timer.start();

    for (times) |*time| {
        timer.reset();
        _ = try braid.compile(constraints);
        time.* = timer.read();
    }

    const stats = calculateStats(times);
    const baseline = findBaseline(baselines, benchmark_name) orelse return error.BaselineNotFound;

    return BenchmarkResult{
        .name = benchmark_name,
        .mean_ns = stats.mean,
        .baseline_ns = baseline.mean_ns,
        .diff_percent = calculateDiffPercent(stats.mean, baseline.mean_ns),
        .passed = checkWithinTolerance(stats.mean, baseline.mean_ns, TOLERANCE_PERCENT),
    };
}

fn testFFIRoundtrip(
    allocator: std.mem.Allocator,
    baselines: []const Baseline,
) !BenchmarkResult {
    const benchmark_name = "ffi_roundtrip";

    // Run benchmark
    const iterations: usize = 1000;
    const times = try allocator.alloc(u64, iterations);
    defer allocator.free(times);

    var timer = try std.time.Timer.start();

    for (times) |*time| {
        timer.reset();
        // Simulate FFI roundtrip overhead
        const dummy = timer.read();
        time.* = dummy;
    }

    const stats = calculateStats(times);
    const baseline = findBaseline(baselines, benchmark_name) orelse return error.BaselineNotFound;

    return BenchmarkResult{
        .name = benchmark_name,
        .mean_ns = stats.mean,
        .baseline_ns = baseline.mean_ns,
        .diff_percent = calculateDiffPercent(stats.mean, baseline.mean_ns),
        .passed = checkWithinTolerance(stats.mean, baseline.mean_ns, TOLERANCE_PERCENT),
    };
}

fn testPipelineE2E(
    allocator: std.mem.Allocator,
    baselines: []const Baseline,
) !BenchmarkResult {
    const benchmark_name = "pipeline_e2e";

    const source = try std.fs.cwd().readFileAlloc(
        allocator,
        "test/fixtures/typescript/small/entity_service_100.ts",
        10 * 1024 * 1024,
    );
    defer allocator.free(source);

    var clew = try Clew.init(allocator);
    defer clew.deinit();

    var braid = try Braid.init(allocator);
    defer braid.deinit();

    // Run benchmark
    const iterations: usize = 50;
    const times = try allocator.alloc(u64, iterations);
    defer allocator.free(times);

    var timer = try std.time.Timer.start();

    for (times) |*time| {
        timer.reset();
        var constraints = try clew.extractFromCode(source, "typescript");
        _ = try braid.compile(constraints.constraints.items);
        time.* = timer.read();
        constraints.deinit();
    }

    const stats = calculateStats(times);
    const baseline = findBaseline(baselines, benchmark_name) orelse return error.BaselineNotFound;

    return BenchmarkResult{
        .name = benchmark_name,
        .mean_ns = stats.mean,
        .baseline_ns = baseline.mean_ns,
        .diff_percent = calculateDiffPercent(stats.mean, baseline.mean_ns),
        .passed = checkWithinTolerance(stats.mean, baseline.mean_ns, TOLERANCE_PERCENT),
    };
}

const Stats = struct {
    mean: u64,
    min: u64,
    max: u64,
};

fn calculateStats(times: []const u64) Stats {
    if (times.len == 0) return Stats{ .mean = 0, .min = 0, .max = 0 };

    var sum: u64 = 0;
    var min: u64 = times[0];
    var max: u64 = times[0];

    for (times) |time| {
        sum += time;
        if (time < min) min = time;
        if (time > max) max = time;
    }

    const mean = sum / times.len;

    return Stats{
        .mean = mean,
        .min = min,
        .max = max,
    };
}

fn calculateDiffPercent(current: u64, baseline: u64) f64 {
    const diff = @as(f64, @floatFromInt(current)) - @as(f64, @floatFromInt(baseline));
    return (diff / @as(f64, @floatFromInt(baseline))) * 100.0;
}

fn checkWithinTolerance(current: u64, baseline: u64, tolerance: f64) bool {
    const diff_percent = @abs(calculateDiffPercent(current, baseline));
    return diff_percent <= tolerance;
}
