//! Multi-Language Extraction Benchmarks
//! Tests constraint extraction across TypeScript, Python, Rust, Zig, and Go

const std = @import("std");
const Clew = @import("clew").Clew;

const BenchResult = struct {
    language: []const u8,
    size_name: []const u8,
    line_count: usize,
    avg_time_ns: u64,
    avg_time_ms: f64,
    throughput_lines_per_sec: f64,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== Multi-Language Extraction Benchmarks ===\n", .{});
    std.debug.print("Target: TypeScript (75 lines) in 4-7ms\n\n", .{});

    var results = std.ArrayList(BenchResult).initCapacity(allocator, 10) catch unreachable;
    defer results.deinit(allocator);

    // Test all languages at different sizes
    const languages = [_]struct { name: []const u8, ext: []const u8 }{
        .{ .name = "typescript", .ext = "ts" },
        .{ .name = "python", .ext = "py" },
        .{ .name = "rust", .ext = "rs" },
        .{ .name = "zig", .ext = "zig" },
        .{ .name = "go", .ext = "go" },
    };

    const sizes = [_]struct { name: []const u8, target_lines: usize, iterations: usize }{
        .{ .name = "small", .target_lines = 100, .iterations = 500 },
        .{ .name = "medium", .target_lines = 500, .iterations = 200 },
        .{ .name = "large", .target_lines = 1000, .iterations = 100 },
        .{ .name = "xlarge", .target_lines = 5000, .iterations = 20 },
    };

    for (languages) |lang| {
        for (sizes) |size| {
            const result = try benchmarkLanguage(
                allocator,
                lang.name,
                lang.ext,
                size.name,
                size.target_lines,
                size.iterations,
            );
            try results.append(allocator, result);
        }
    }

    // Print summary table
    std.debug.print("\n=== Summary Table ===\n", .{});
    std.debug.print("| Language   | Size   | Lines | Avg Time   | Throughput    | Status |\n", .{});
    std.debug.print("|------------|--------|-------|------------|---------------|--------|\n", .{});

    for (results.items) |result| {
        const status = if (result.avg_time_ms < 10.0) "✓ OK" else "⚠ SLOW";
        std.debug.print("| {s: <10} | {s: <6} | {d: <5} | {d: >6.2}ms | {d: >9.0} l/s | {s} |\n", .{
            result.language,
            result.size_name,
            result.line_count,
            result.avg_time_ms,
            result.throughput_lines_per_sec,
            status,
        });
    }

    std.debug.print("\n=== Benchmarks Complete ===\n", .{});
}

fn benchmarkLanguage(
    allocator: std.mem.Allocator,
    language: []const u8,
    ext: []const u8,
    size_name: []const u8,
    target_lines: usize,
    iterations: usize,
) !BenchResult {
    // Construct file path
    const filepath = try std.fmt.allocPrint(
        allocator,
        "test/fixtures/{s}/{s}/entity_service_{d}.{s}",
        .{ language, size_name, target_lines, ext },
    );
    defer allocator.free(filepath);

    // Read source file
    const source = std.fs.cwd().readFileAlloc(allocator, filepath, 10 * 1024 * 1024) catch |err| {
        std.debug.print("Error reading {s}: {}\n", .{ filepath, err });
        return error.FileNotFound;
    };
    defer allocator.free(source);

    const actual_lines = std.mem.count(u8, source, "\n");

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
    const avg_ms = @as(f64, @floatFromInt(avg_ns)) / 1_000_000.0;
    const throughput = @as(f64, @floatFromInt(actual_lines)) / (@as(f64, @floatFromInt(avg_ns)) / 1_000_000_000.0);

    std.debug.print("{s} ({s}, {d} lines): {d:.2}ms ({d:.0} lines/s)\n", .{
        language,
        size_name,
        actual_lines,
        avg_ms,
        throughput,
    });

    return BenchResult{
        .language = language,
        .size_name = size_name,
        .line_count = actual_lines,
        .avg_time_ns = avg_ns,
        .avg_time_ms = avg_ms,
        .throughput_lines_per_sec = throughput,
    };
}
