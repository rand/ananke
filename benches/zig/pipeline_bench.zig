//! End-to-End Pipeline Benchmarks
//! Tests full extract→compile workflow
//! Target: 6-9ms for TypeScript (75 lines) + 10 constraints

const std = @import("std");
const Clew = @import("clew").Clew;
const Braid = @import("braid").Braid;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== End-to-End Pipeline Benchmarks ===\n", .{});
    std.debug.print("Target: 6-9ms for TypeScript (75 lines) + 10 constraints\n\n", .{});

    // Test full pipeline for each language
    const test_cases = [_]struct {
        name: []const u8,
        language: []const u8,
        filepath: []const u8,
        iterations: usize,
    }{
        .{ .name = "TS Small", .language = "typescript", .filepath = "test/fixtures/typescript/small/entity_service_100.ts", .iterations = 200 },
        .{ .name = "TS Medium", .language = "typescript", .filepath = "test/fixtures/typescript/medium/entity_service_500.ts", .iterations = 100 },
        .{ .name = "Python Small", .language = "python", .filepath = "test/fixtures/python/small/entity_service_100.py", .iterations = 200 },
        .{ .name = "Rust Small", .language = "rust", .filepath = "test/fixtures/rust/small/entity_service_100.rs", .iterations = 200 },
        .{ .name = "Zig Small", .language = "zig", .filepath = "test/fixtures/zig/small/entity_service_100.zig", .iterations = 200 },
        .{ .name = "Go Small", .language = "go", .filepath = "test/fixtures/go/small/entity_service_100.go", .iterations = 200 },
    };

    std.debug.print("| Test Case      | Extract | Compile | Total   | Status |\n", .{});
    std.debug.print("|----------------|---------|---------|---------|--------|\n", .{});

    for (test_cases) |tc| {
        const result = try benchmarkPipeline(allocator, tc.language, tc.filepath, tc.iterations);

        const status = if (result.total_ms < 10.0) "✓ OK" else "⚠ SLOW";
        std.debug.print("| {s: <14} | {d: >5.2}ms | {d: >5.2}ms | {d: >5.2}ms | {s} |\n", .{
            tc.name,
            result.extract_ms,
            result.compile_ms,
            result.total_ms,
            status,
        });
    }

    std.debug.print("\n=== Benchmarks Complete ===\n", .{});
}

const PipelineResult = struct {
    extract_ms: f64,
    compile_ms: f64,
    total_ms: f64,
};

fn benchmarkPipeline(
    allocator: std.mem.Allocator,
    language: []const u8,
    filepath: []const u8,
    iterations: usize,
) !PipelineResult {
    // Read source file
    const source = try std.fs.cwd().readFileAlloc(allocator, filepath, 10 * 1024 * 1024);
    defer allocator.free(source);

    var clew = try Clew.init(allocator);
    defer clew.deinit();

    var braid = try Braid.init(allocator);
    defer braid.deinit();

    var timer = try std.time.Timer.start();
    var extract_total: u64 = 0;
    var compile_total: u64 = 0;

    for (0..iterations) |_| {
        // Extract phase
        timer.reset();
        var constraints = try clew.extractFromCode(source, language);
        extract_total += timer.read();

        // Compile phase
        timer.reset();
        _ = try braid.compile(constraints.constraints.items);
        compile_total += timer.read();

        constraints.deinit();
    }

    const avg_extract_ns = extract_total / iterations;
    const avg_compile_ns = compile_total / iterations;
    const avg_total_ns = avg_extract_ns + avg_compile_ns;

    return PipelineResult{
        .extract_ms = @as(f64, @floatFromInt(avg_extract_ns)) / 1_000_000.0,
        .compile_ms = @as(f64, @floatFromInt(avg_compile_ns)) / 1_000_000.0,
        .total_ms = @as(f64, @floatFromInt(avg_total_ns)) / 1_000_000.0,
    };
}
