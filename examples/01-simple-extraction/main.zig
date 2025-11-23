const std = @import("std");
const ananke = @import("ananke");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== Ananke Example 01: Simple Constraint Extraction ===\n\n", .{});

    // Read the sample TypeScript file
    const file_path = "sample.ts";
    const source_code = try std.fs.cwd().readFileAlloc(allocator, file_path, 1024 * 1024);
    defer allocator.free(source_code);

    std.debug.print("Analyzing file: {s}\n", .{file_path});
    std.debug.print("File size: {} bytes\n\n", .{source_code.len});

    // Initialize Clew (constraint extraction engine)
    // No Claude client - pure static analysis
    var clew = try ananke.clew.Clew.init(allocator);
    defer clew.deinit();

    std.debug.print("Extracting constraints (without Claude)...\n\n", .{});

    // Extract constraints from the TypeScript code
    const constraints = try clew.extractFromCode(source_code, "typescript");
    defer {
        for (constraints.constraints.items) |_| {}
        // Note: Would need proper cleanup if constraints owned memory
    }

    // Display results
    std.debug.print("Found {} constraints:\n\n", .{constraints.constraints.items.len});

    for (constraints.constraints.items, 0..) |constraint, i| {
        std.debug.print("Constraint {}: {s}\n", .{ i + 1, constraint.name });
        std.debug.print("  Kind: {s}\n", .{@tagName(constraint.kind)});
        std.debug.print("  Severity: {s}\n", .{@tagName(constraint.severity)});
        std.debug.print("  Description: {s}\n", .{constraint.description});
        std.debug.print("  Source: {s}\n", .{@tagName(constraint.source)});
        std.debug.print("  Confidence: {d:.2}\n\n", .{constraint.confidence});
    }

    // Summary by kind
    std.debug.print("=== Summary by Kind ===\n", .{});
    var kind_counts = std.AutoHashMap(ananke.types.constraint.ConstraintKind, usize).init(allocator);
    defer kind_counts.deinit();

    for (constraints.constraints.items) |constraint| {
        const entry = try kind_counts.getOrPut(constraint.kind);
        if (entry.found_existing) {
            entry.value_ptr.* += 1;
        } else {
            entry.value_ptr.* = 1;
        }
    }

    var kind_iter = kind_counts.iterator();
    while (kind_iter.next()) |entry| {
        std.debug.print("  {s}: {}\n", .{ @tagName(entry.key_ptr.*), entry.value_ptr.* });
    }

    std.debug.print("\n=== Extraction Complete ===\n", .{});
    std.debug.print("\nKey Insights:\n", .{});
    std.debug.print("- Static analysis detected function signatures and return types\n", .{});
    std.debug.print("- Type safety patterns identified (explicit types, optional fields)\n", .{});
    std.debug.print("- Security patterns noted (password handling, authentication)\n", .{});
    std.debug.print("- No LLM required for basic structural constraints\n", .{});
}
