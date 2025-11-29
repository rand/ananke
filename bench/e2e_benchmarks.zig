//! End-to-End Latency Breakdown Benchmarks
//! Measures the full pipeline with stage-by-stage timing
//!
//! Target: Total p95 < 5000ms for medium files

const std = @import("std");
const Clew = @import("clew").Clew;
const Braid = @import("braid").Braid;
const ananke = @import("ananke");

const Allocator = std.mem.Allocator;

pub const E2EResult = struct {
    name: []const u8,
    file_path: []const u8,
    extraction_ms: u64,
    compilation_ms: u64,
    total_ms: u64,
    extraction_pct: f64,
    compilation_pct: f64,
    pass: bool,
};

pub fn runE2EBenchmarks(allocator: Allocator) ![]E2EResult {
    var results = std.ArrayList(E2EResult){};
    errdefer results.deinit(allocator);

    const test_cases = [_]struct {
        name: []const u8,
        file: []const u8,
        language: []const u8,
        expected_total_ms: u64,
    }{
        .{ .name = "e2e_small_ts", .file = "bench/fixtures/small/simple.ts", .language = "typescript", .expected_total_ms = 100 },
        .{ .name = "e2e_medium_ts", .file = "bench/fixtures/medium/api.ts", .language = "typescript", .expected_total_ms = 200 },
        .{ .name = "e2e_large_ts", .file = "bench/fixtures/large/app.ts", .language = "typescript", .expected_total_ms = 600 },
        .{ .name = "e2e_small_py", .file = "bench/fixtures/small/simple.py", .language = "python", .expected_total_ms = 100 },
        .{ .name = "e2e_medium_py", .file = "bench/fixtures/medium/service.py", .language = "python", .expected_total_ms = 200 },
        .{ .name = "e2e_large_py", .file = "bench/fixtures/large/app.py", .language = "python", .expected_total_ms = 600 },
    };

    std.debug.print("\n=== E2E Latency Breakdown Benchmarks ===\n\n", .{});

    for (test_cases) |case| {
        const result = try benchmarkE2E(allocator, case.name, case.file, case.language, case.expected_total_ms);
        try results.append(allocator, result);

        std.debug.print("{s}:\n", .{case.name});
        std.debug.print("  File: {s}\n", .{case.file});
        std.debug.print("  Extraction: {}ms ({d:.1}%)\n", .{ result.extraction_ms, result.extraction_pct });
        std.debug.print("  Compilation: {}ms ({d:.1}%)\n", .{ result.compilation_ms, result.compilation_pct });
        std.debug.print("  Total: {}ms (target: {}ms)\n", .{ result.total_ms, case.expected_total_ms });

        if (result.pass) {
            std.debug.print("  Status: PASS ✓\n\n", .{});
        } else {
            std.debug.print("  Status: FAIL ✗\n\n", .{});
        }
    }

    return try results.toOwnedSlice(allocator);
}

fn benchmarkE2E(
    allocator: Allocator,
    name: []const u8,
    file_path: []const u8,
    language: []const u8,
    expected_total_ms: u64,
) !E2EResult {
    // Read source file
    const source = try std.fs.cwd().readFileAlloc(
        allocator,
        file_path,
        10 * 1024 * 1024,
    );
    defer allocator.free(source);

    var clew = try Clew.init(allocator);
    defer clew.deinit();

    var braid = try Braid.init(allocator);
    defer braid.deinit();

    // Run the pipeline with timing

    // Stage 1: Extraction
    const extraction_start = std.time.nanoTimestamp();
    var constraints = try clew.extractFromCode(source, language);
    const extraction_end = std.time.nanoTimestamp();
    defer constraints.deinit();

    // Stage 2: Compilation
    const compilation_start = std.time.nanoTimestamp();
    var compiled = try braid.compile(constraints.constraints.items);
    const compilation_end = std.time.nanoTimestamp();
    defer compiled.deinit(allocator);

    // Calculate timings
    const extraction_ns: u64 = @intCast(extraction_end - extraction_start);
    const compilation_ns: u64 = @intCast(compilation_end - compilation_start);
    const total_ns = extraction_ns + compilation_ns;

    const extraction_ms = extraction_ns / 1_000_000;
    const compilation_ms = compilation_ns / 1_000_000;
    const total_ms = total_ns / 1_000_000;

    const extraction_pct = @as(f64, @floatFromInt(extraction_ns)) / @as(f64, @floatFromInt(total_ns)) * 100.0;
    const compilation_pct = @as(f64, @floatFromInt(compilation_ns)) / @as(f64, @floatFromInt(total_ns)) * 100.0;

    return E2EResult{
        .name = name,
        .file_path = file_path,
        .extraction_ms = extraction_ms,
        .compilation_ms = compilation_ms,
        .total_ms = total_ms,
        .extraction_pct = extraction_pct,
        .compilation_pct = compilation_pct,
        .pass = total_ms <= expected_total_ms,
    };
}
