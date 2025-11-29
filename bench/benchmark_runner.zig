//! Benchmark Runner - Orchestrates all Phase 8b benchmarks
//! Generates JSON reports with environment metadata

const std = @import("std");
const extraction = @import("extraction_benchmarks.zig");
const compilation = @import("compilation_benchmarks.zig");
const cache = @import("cache_benchmarks.zig");
const e2e = @import("e2e_benchmarks.zig");

const Allocator = std.mem.Allocator;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n" ++ "=" ** 60 ++ "\n", .{});
    std.debug.print("Ananke Performance Benchmark Suite v0.1.0\n", .{});
    std.debug.print("=" ** 60 ++ "\n", .{});

    // Run all benchmark suites
    const extraction_results = try extraction.runExtractionBenchmarks(allocator);
    defer allocator.free(extraction_results);

    const compilation_results = try compilation.runCompilationBenchmarks(allocator);
    defer allocator.free(compilation_results);

    const cache_results = try cache.runCacheBenchmarks(allocator);
    defer allocator.free(cache_results);

    const e2e_results = try e2e.runE2EBenchmarks(allocator);
    defer allocator.free(e2e_results);

    // Calculate summary
    var total_benchmarks: usize = 0;
    var passed: usize = 0;

    for (extraction_results) |result| {
        total_benchmarks += 1;
        if (result.pass) passed += 1;
    }

    for (compilation_results) |result| {
        total_benchmarks += 1;
        if (result.pass) passed += 1;
    }

    for (cache_results) |result| {
        total_benchmarks += 1;
        if (result.pass) passed += 1;
    }

    for (e2e_results) |result| {
        total_benchmarks += 1;
        if (result.pass) passed += 1;
    }

    const failed = total_benchmarks - passed;
    const pass_rate = @as(f64, @floatFromInt(passed)) / @as(f64, @floatFromInt(total_benchmarks));

    // Print summary
    std.debug.print("\n" ++ "=" ** 60 ++ "\n", .{});
    std.debug.print("Summary\n", .{});
    std.debug.print("=" ** 60 ++ "\n", .{});
    std.debug.print("Total benchmarks: {}\n", .{total_benchmarks});
    std.debug.print("Passed: {}\n", .{passed});
    std.debug.print("Failed: {}\n", .{failed});
    std.debug.print("Pass rate: {d:.1}%\n", .{pass_rate * 100.0});
    std.debug.print("\n", .{});

    // Generate JSON report
    try generateJSONReport(
        allocator,
        extraction_results,
        compilation_results,
        cache_results,
        e2e_results,
        total_benchmarks,
        passed,
        failed,
        pass_rate,
    );

    // Exit with error code if any benchmarks failed
    if (failed > 0) {
        std.process.exit(1);
    }
}

fn generateJSONReport(
    allocator: Allocator,
    extraction_results: []const extraction.BenchmarkResult,
    compilation_results: []const compilation.CompilationResult,
    cache_results: []const cache.CacheResult,
    e2e_results: []const e2e.E2EResult,
    total_benchmarks: usize,
    passed: usize,
    failed: usize,
    pass_rate: f64,
) !void {
    // Create results directory if it doesn't exist
    std.fs.cwd().makeDir("bench/results") catch |err| {
        if (err != error.PathAlreadyExists) return err;
    };

    // Get environment info
    const env = try getEnvironmentInfo(allocator);
    defer {
        allocator.free(env.os);
        allocator.free(env.cpu);
        allocator.free(env.zig_version);
    }

    // Get timestamp
    const timestamp = std.time.timestamp();

    // Build JSON manually (since we don't have std.json.stringify yet in Zig 0.15)
    var report = std.ArrayList(u8){};
    defer report.deinit(allocator);
    const writer = report.writer(allocator);

    try writer.writeAll("{\n");
    try writer.print("  \"benchmark_suite\": \"ananke_v0.1.0\",\n", .{});
    try writer.print("  \"timestamp\": {},\n", .{timestamp});
    try writer.writeAll("  \"environment\": {\n");
    try writer.print("    \"os\": \"{s}\",\n", .{env.os});
    try writer.print("    \"cpu\": \"{s}\",\n", .{env.cpu});
    try writer.print("    \"ram_gb\": {},\n", .{env.ram_gb});
    try writer.print("    \"zig_version\": \"{s}\"\n", .{env.zig_version});
    try writer.writeAll("  },\n");

    // Results section
    try writer.writeAll("  \"results\": {\n");

    // Extraction results
    try writer.writeAll("    \"extraction\": {\n");
    for (extraction_results, 0..) |result, i| {
        try writer.print("      \"{s}\": {{\n", .{result.name});
        try writer.print("        \"p50_ms\": {d:.2},\n", .{result.p50_ms});
        try writer.print("        \"p95_ms\": {d:.2},\n", .{result.p95_ms});
        try writer.print("        \"p99_ms\": {d:.2},\n", .{result.p99_ms});
        try writer.print("        \"max_ms\": {d:.2},\n", .{result.max_ms});
        try writer.print("        \"pass\": {}\n", .{result.pass});
        if (i < extraction_results.len - 1) {
            try writer.writeAll("      },\n");
        } else {
            try writer.writeAll("      }\n");
        }
    }
    try writer.writeAll("    },\n");

    // Compilation results
    try writer.writeAll("    \"compilation\": {\n");
    for (compilation_results, 0..) |result, i| {
        try writer.print("      \"{s}\": {{\n", .{result.name});
        try writer.print("        \"p50_ms\": {d:.2},\n", .{result.p50_ms});
        try writer.print("        \"p95_ms\": {d:.2},\n", .{result.p95_ms});
        try writer.print("        \"p99_ms\": {d:.2},\n", .{result.p99_ms});
        try writer.print("        \"pass\": {}\n", .{result.pass});
        if (i < compilation_results.len - 1) {
            try writer.writeAll("      },\n");
        } else {
            try writer.writeAll("      }\n");
        }
    }
    try writer.writeAll("    },\n");

    // Cache results
    try writer.writeAll("    \"cache\": {\n");
    for (cache_results, 0..) |result, i| {
        try writer.print("      \"{s}\": {{\n", .{result.name});
        try writer.print("        \"speedup\": {d:.1},\n", .{result.speedup});
        try writer.print("        \"cold_us\": {},\n", .{result.cold_latency_us});
        try writer.print("        \"warm_us\": {},\n", .{result.warm_latency_us});
        try writer.print("        \"pass\": {}\n", .{result.pass});
        if (i < cache_results.len - 1) {
            try writer.writeAll("      },\n");
        } else {
            try writer.writeAll("      }\n");
        }
    }
    try writer.writeAll("    },\n");

    // E2E results
    try writer.writeAll("    \"e2e\": {\n");
    for (e2e_results, 0..) |result, i| {
        try writer.print("      \"{s}\": {{\n", .{result.name});
        try writer.print("        \"extraction_ms\": {},\n", .{result.extraction_ms});
        try writer.print("        \"compilation_ms\": {},\n", .{result.compilation_ms});
        try writer.print("        \"total_ms\": {},\n", .{result.total_ms});
        try writer.print("        \"pass\": {}\n", .{result.pass});
        if (i < e2e_results.len - 1) {
            try writer.writeAll("      },\n");
        } else {
            try writer.writeAll("      }\n");
        }
    }
    try writer.writeAll("    }\n");

    try writer.writeAll("  },\n");

    // Summary
    try writer.writeAll("  \"summary\": {\n");
    try writer.print("    \"total_benchmarks\": {},\n", .{total_benchmarks});
    try writer.print("    \"passed\": {},\n", .{passed});
    try writer.print("    \"failed\": {},\n", .{failed});
    try writer.print("    \"pass_rate\": {d:.2}\n", .{pass_rate});
    try writer.writeAll("  }\n");

    try writer.writeAll("}\n");

    // Write to files
    const latest_path = "bench/results/latest.json";
    const baseline_path = "bench/results/baseline_v0.1.0.json";

    try std.fs.cwd().writeFile(.{ .sub_path = latest_path, .data = report.items });

    // Only write baseline if it doesn't exist
    std.fs.cwd().access(baseline_path, .{}) catch {
        try std.fs.cwd().writeFile(.{ .sub_path = baseline_path, .data = report.items });
    };

    std.debug.print("JSON report written to: {s}\n", .{latest_path});
}

const EnvironmentInfo = struct {
    os: []const u8,
    cpu: []const u8,
    ram_gb: usize,
    zig_version: []const u8,
};

fn getEnvironmentInfo(allocator: Allocator) !EnvironmentInfo {
    const builtin = @import("builtin");

    const os = try std.fmt.allocPrint(allocator, "{s}", .{@tagName(builtin.os.tag)});
    const cpu = try std.fmt.allocPrint(allocator, "{s}", .{@tagName(builtin.cpu.arch)});
    const zig_version = try std.fmt.allocPrint(allocator, "{s}", .{builtin.zig_version_string});

    return EnvironmentInfo{
        .os = os,
        .cpu = cpu,
        .ram_gb = 16, // Default, could be detected via sysinfo
        .zig_version = zig_version,
    };
}
