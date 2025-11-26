//! Benchmark demonstrating string interner performance improvements

const std = @import("std");
const StringInterner = @import("ananke").utils.StringInterner;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== String Interner Performance Benchmark ===\n\n", .{});

    // Simulate typical constraint extraction workload
    const typical_constraint_names = [_][]const u8{
        "async_function",
        "error_handling",
        "type_annotation",
        "function_declaration",
        "class_declaration",
        "import_statement",
        "export_statement",
        "interface_definition",
        "type_alias",
        "async_await",
    };

    const iterations = 1000;

    // Benchmark WITHOUT string interning (baseline)
    {
        var timer = try std.time.Timer.start();
        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        const arena_alloc = arena.allocator();

        var i: usize = 0;
        while (i < iterations) : (i += 1) {
            for (typical_constraint_names) |name| {
                _ = try arena_alloc.dupe(u8, name);
            }
        }

        const elapsed_ns = timer.read();
        const elapsed_ms = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0;
        std.debug.print("WITHOUT interning (baseline):\n", .{});
        std.debug.print("  Time: {d:.2}ms\n", .{elapsed_ms});
        std.debug.print("  {} allocations ({} iterations x {} strings)\n", .{
            iterations * typical_constraint_names.len,
            iterations,
            typical_constraint_names.len,
        });
        std.debug.print("\n", .{});
    }

    // Benchmark WITH string interning
    {
        var timer = try std.time.Timer.start();
        var interner = try StringInterner.init(allocator);
        defer interner.deinit();

        var i: usize = 0;
        while (i < iterations) : (i += 1) {
            for (typical_constraint_names) |name| {
                _ = try interner.intern(name);
            }
        }

        const elapsed_ns = timer.read();
        const elapsed_ms = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0;
        const stats = interner.getStats();

        std.debug.print("WITH string interning:\n", .{});
        std.debug.print("  Time: {d:.2}ms\n", .{elapsed_ms});
        std.debug.print("  Total intern() calls: {}\n", .{stats.total_interns});
        std.debug.print("  Unique strings: {}\n", .{stats.unique_strings});
        std.debug.print("  Cache hits: {} ({d:.1}%)\n", .{
            stats.cache_hits,
            stats.hitRate() * 100.0,
        });
        std.debug.print("  Memory saved: ~{} bytes\n", .{
            stats.total_bytes * (stats.total_interns - stats.unique_strings),
        });
        std.debug.print("\n", .{});
    }

    // Realistic constraint extraction simulation
    std.debug.print("=== Realistic Constraint Extraction Simulation ===\n\n", .{});

    const realistic_iterations = 100;
    const files_per_iteration = 10;

    // WITHOUT interning
    {
        var timer = try std.time.Timer.start();
        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        const arena_alloc = arena.allocator();

        var total_allocs: usize = 0;
        var iter: usize = 0;
        while (iter < realistic_iterations) : (iter += 1) {
            var file: usize = 0;
            while (file < files_per_iteration) : (file += 1) {
                // Simulate extracting constraints (20 per file)
                var constraint_idx: usize = 0;
                while (constraint_idx < 20) : (constraint_idx += 1) {
                    const name_idx = constraint_idx % typical_constraint_names.len;
                    _ = try arena_alloc.dupe(u8, typical_constraint_names[name_idx]);
                    const desc = try std.fmt.allocPrint(
                        arena_alloc,
                        "{s} detected at line {}",
                        .{ typical_constraint_names[name_idx], constraint_idx },
                    );
                    _ = desc;
                    total_allocs += 2; // name + description
                }
            }
        }

        const elapsed_ns = timer.read();
        const elapsed_ms = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0;
        std.debug.print("WITHOUT interning (realistic workload):\n", .{});
        std.debug.print("  Files processed: {}\n", .{realistic_iterations * files_per_iteration});
        std.debug.print("  Total allocations: {}\n", .{total_allocs});
        std.debug.print("  Time: {d:.2}ms\n", .{elapsed_ms});
        std.debug.print("\n", .{});
    }

    // WITH interning
    {
        var timer = try std.time.Timer.start();
        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        const arena_alloc = arena.allocator();

        var interner = try StringInterner.init(allocator);
        defer interner.deinit();

        var iter: usize = 0;
        while (iter < realistic_iterations) : (iter += 1) {
            var file: usize = 0;
            while (file < files_per_iteration) : (file += 1) {
                // Simulate extracting constraints (20 per file)
                var constraint_idx: usize = 0;
                while (constraint_idx < 20) : (constraint_idx += 1) {
                    const name_idx = constraint_idx % typical_constraint_names.len;
                    _ = try interner.intern(typical_constraint_names[name_idx]);
                    const desc = try std.fmt.allocPrint(
                        arena_alloc,
                        "{s} detected at line {}",
                        .{ typical_constraint_names[name_idx], constraint_idx },
                    );
                    _ = try interner.intern(desc);
                }
            }
        }

        const elapsed_ns = timer.read();
        const elapsed_ms = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0;
        const stats = interner.getStats();

        std.debug.print("WITH string interning (realistic workload):\n", .{});
        std.debug.print("  Files processed: {}\n", .{realistic_iterations * files_per_iteration});
        std.debug.print("  Total intern() calls: {}\n", .{stats.total_interns});
        std.debug.print("  Unique strings: {}\n", .{stats.unique_strings});
        std.debug.print("  Cache hit rate: {d:.1}%\n", .{stats.hitRate() * 100.0});
        std.debug.print("  Time: {d:.2}ms\n", .{elapsed_ms});
        std.debug.print("  Estimated memory saved: ~{} KB\n", .{
            (stats.total_bytes * (stats.total_interns - stats.unique_strings)) / 1024,
        });
        std.debug.print("\n", .{});
    }

    std.debug.print("=== Summary ===\n", .{});
    std.debug.print("String interning provides:\n", .{});
    std.debug.print("  - O(1) lookup for duplicate strings\n", .{});
    std.debug.print("  - Reduced memory allocations (10-30%% reduction expected)\n", .{});
    std.debug.print("  - Better cache locality (strings clustered in arena)\n", .{});
    std.debug.print("  - 10-12%% performance improvement target\n", .{});
    std.debug.print("\n", .{});
}
