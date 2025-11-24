//! Memory Usage Benchmarks
//! Note: Detailed memory tracking removed in Zig 0.15.x
//! Use external profilers (valgrind, heaptrack) for comprehensive memory analysis

const std = @import("std");
const Clew = @import("clew").Clew;
const Braid = @import("braid").Braid;
const Constraint = @import("ananke").types.constraint.Constraint;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== Memory Usage Benchmarks ===\n\n", .{});

    // Test extraction memory usage
    try benchmarkExtractionMemory(allocator);

    // Test compilation memory usage
    try benchmarkCompilationMemory(allocator);

    std.debug.print("\nNote: For detailed memory analysis, use external profilers:\n", .{});
    std.debug.print("  - valgrind --tool=massif ./zig-out/bin/memory_bench\n", .{});
    std.debug.print("  - heaptrack ./zig-out/bin/memory_bench\n", .{});
    std.debug.print("\n=== Benchmarks Complete ===\n", .{});
}

fn benchmarkExtractionMemory(allocator: std.mem.Allocator) !void {
    std.debug.print("Extraction Memory Usage:\n", .{});

    const test_cases = [_]struct {
        name: []const u8,
        filepath: []const u8,
        language: []const u8,
    }{
        .{ .name = "Small TS", .filepath = "test/fixtures/typescript/small/entity_service_100.ts", .language = "typescript" },
        .{ .name = "Medium TS", .filepath = "test/fixtures/typescript/medium/entity_service_500.ts", .language = "typescript" },
        .{ .name = "Large TS", .filepath = "test/fixtures/typescript/large/entity_service_1000.ts", .language = "typescript" },
    };

    for (test_cases) |tc| {
        const source = std.fs.cwd().readFileAlloc(allocator, tc.filepath, 10 * 1024 * 1024) catch |err| {
            std.debug.print("  {s}: Error reading file: {}\n", .{ tc.name, err });
            continue;
        };
        defer allocator.free(source);

        var clew = try Clew.init(allocator);
        defer clew.deinit();

        var result = try clew.extractFromCode(source, tc.language);
        result.deinit();

        const lines = std.mem.count(u8, source, "\n");
        std.debug.print("  {s: <12}: {d} lines extracted\n", .{ tc.name, lines });
    }
    std.debug.print("\n", .{});
}

fn benchmarkCompilationMemory(allocator: std.mem.Allocator) !void {
    std.debug.print("Compilation Memory Usage:\n", .{});

    const constraint_counts = [_]usize{ 5, 20, 50, 100 };

    for (constraint_counts) |count| {
        var braid = try Braid.init(allocator);
        defer braid.deinit();

        const constraints = try allocator.alloc(Constraint, count);
        defer allocator.free(constraints);

        for (constraints, 0..) |*c, i| {
            const name = try std.fmt.allocPrint(allocator, "constraint_{}", .{i});
            const desc = try std.fmt.allocPrint(allocator, "Test constraint {}", .{i});
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

        _ = try braid.compile(constraints);

        std.debug.print("  {d: >3} constraints compiled successfully\n", .{count});
    }
    std.debug.print("\n", .{});
}
