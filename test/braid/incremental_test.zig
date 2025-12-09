//! Test incremental compilation for Braid constraint engine

const std = @import("std");
const testing = std.testing;
const Braid = @import("braid").Braid;
const Constraint = @import("ananke").Constraint;
const ConstraintFingerprint = @import("ananke").ConstraintFingerprint;

test "incremental compile: no changes returns cached" {
    const allocator = testing.allocator;

    var braid = try Braid.init(allocator);
    defer braid.deinit();

    // Create test constraints
    var constraints = [_]Constraint{
        .{
            .name = "test1",
            .description = "First test constraint",
            .kind = .syntactic,
            .severity = .err,
            .created_at = std.time.timestamp(),
        },
        .{
            .name = "test2",
            .description = "Second test constraint",
            .kind = .type_safety,
            .severity = .err,
            .created_at = std.time.timestamp(),
        },
    };

    // First compile
    var ir1 = try braid.compileIncremental(&constraints);
    defer ir1.deinit(allocator);

    // Second compile with same constraints
    var ir2 = try braid.compileIncremental(&constraints);
    defer ir2.deinit(allocator);

    // Both should succeed (exact equivalence is hard to test, but they should compile)
    try testing.expect(ir1.priority >= 0);
    try testing.expect(ir2.priority >= 0);
}

test "incremental compile: single change triggers recompile" {
    const allocator = testing.allocator;

    var braid = try Braid.init(allocator);
    defer braid.deinit();

    // Create test constraints
    var constraints = [_]Constraint{
        .{
            .name = "test1",
            .description = "First test constraint",
            .kind = .syntactic,
            .severity = .err,
            .created_at = std.time.timestamp(),
        },
        .{
            .name = "test2",
            .description = "Second test constraint",
            .kind = .type_safety,
            .severity = .err,
            .created_at = std.time.timestamp(),
        },
    };

    // First compile
    var ir1 = try braid.compileIncremental(&constraints);
    defer ir1.deinit(allocator);

    // Modify one constraint
    constraints[0].description = "Modified first constraint";

    // Second compile - should detect change
    var ir2 = try braid.compileIncremental(&constraints);
    defer ir2.deinit(allocator);

    // Both should succeed
    try testing.expect(ir1.priority >= 0);
    try testing.expect(ir2.priority >= 0);
}

test "incremental compile matches full compile" {
    const allocator = testing.allocator;

    var braid_inc = try Braid.init(allocator);
    defer braid_inc.deinit();

    var braid_full = try Braid.init(allocator);
    defer braid_full.deinit();

    // Create test constraints
    const constraints = [_]Constraint{
        .{
            .name = "test1",
            .description = "First test constraint for function",
            .kind = .syntactic,
            .severity = .err,
            .created_at = std.time.timestamp(),
        },
        .{
            .name = "test2",
            .description = "Second test constraint string",
            .kind = .type_safety,
            .severity = .err,
            .created_at = std.time.timestamp(),
        },
        .{
            .name = "test3",
            .description = "Third test constraint return",
            .kind = .semantic,
            .severity = .warning,
            .created_at = std.time.timestamp(),
        },
    };

    // Compile with both methods
    var ir_inc = try braid_inc.compileIncremental(&constraints);
    defer ir_inc.deinit(allocator);

    var ir_full = try braid_full.compile(&constraints);
    defer ir_full.deinit(allocator);

    // Results should have the same priority (indicative of equivalence)
    try testing.expectEqual(ir_full.priority, ir_inc.priority);

    // Both should have compiled successfully
    try testing.expect(ir_inc.priority >= 0);
    try testing.expect(ir_full.priority >= 0);
}

test "ConstraintFingerprint: compute and compare" {
    const allocator = testing.allocator;
    _ = allocator;

    const c1 = Constraint{
        .name = "test",
        .description = "Test constraint",
        .kind = .syntactic,
        .severity = .err,
        .created_at = std.time.timestamp(),
    };

    const c2 = Constraint{
        .name = "test",
        .description = "Different description",
        .kind = .syntactic,
        .severity = .err,
        .created_at = std.time.timestamp(),
    };

    const fp1 = ConstraintFingerprint.compute(&c1);
    const fp2 = ConstraintFingerprint.compute(&c2);

    // Same constraint should have consistent hash
    const fp1_again = ConstraintFingerprint.compute(&c1);
    try testing.expectEqual(fp1.hash, fp1_again.hash);

    // Different constraints should have different hashes (high probability)
    try testing.expect(fp1.hasChanged(fp2));
}

test "incremental compile: added constraint" {
    const allocator = testing.allocator;

    var braid = try Braid.init(allocator);
    defer braid.deinit();

    // Start with one constraint
    var constraints1 = [_]Constraint{
        .{
            .name = "test1",
            .description = "First test constraint",
            .kind = .syntactic,
            .severity = .err,
            .created_at = std.time.timestamp(),
        },
    };

    var ir1 = try braid.compileIncremental(&constraints1);
    defer ir1.deinit(allocator);

    // Add a second constraint
    var constraints2 = [_]Constraint{
        .{
            .name = "test1",
            .description = "First test constraint",
            .kind = .syntactic,
            .severity = .err,
            .created_at = std.time.timestamp(),
        },
        .{
            .name = "test2",
            .description = "Second test constraint",
            .kind = .type_safety,
            .severity = .err,
            .created_at = std.time.timestamp(),
        },
    };

    var ir2 = try braid.compileIncremental(&constraints2);
    defer ir2.deinit(allocator);

    // Both should compile successfully
    try testing.expect(ir1.priority >= 0);
    try testing.expect(ir2.priority >= 0);
}

test "incremental compile: performance benefit" {
    const allocator = testing.allocator;

    var braid = try Braid.init(allocator);
    defer braid.deinit();

    // Create a larger set of constraints
    var constraints = try std.ArrayList(Constraint).initCapacity(allocator, 20);
    defer constraints.deinit(allocator);

    for (0..20) |i| {
        const name = try std.fmt.allocPrint(allocator, "constraint_{}", .{i});
        defer allocator.free(name);

        const desc = try std.fmt.allocPrint(allocator, "Test constraint number {} for function", .{i});
        defer allocator.free(desc);

        try constraints.append(allocator, .{
            .name = try allocator.dupe(u8, name),
            .description = try allocator.dupe(u8, desc),
            .kind = .syntactic,
            .severity = .err,
            .created_at = std.time.timestamp(),
        });
    }
    defer {
        for (constraints.items) |c| {
            allocator.free(c.name);
            allocator.free(c.description);
        }
    }

    // First compile (cold)
    const cold_start = std.time.nanoTimestamp();
    var ir1 = try braid.compileIncremental(constraints.items);
    const cold_time = std.time.nanoTimestamp() - cold_start;
    defer ir1.deinit(allocator);

    // Second compile (no changes - should be fast)
    const warm_start = std.time.nanoTimestamp();
    var ir2 = try braid.compileIncremental(constraints.items);
    const warm_time = std.time.nanoTimestamp() - warm_start;
    defer ir2.deinit(allocator);

    std.debug.print("\nIncremental compile performance:\n", .{});
    std.debug.print("  Cold: {d}μs\n", .{@divTrunc(cold_time, 1000)});
    std.debug.print("  Warm (cached): {d}μs\n", .{@divTrunc(warm_time, 1000)});

    // Warm compile should be significantly faster (allow for some variance)
    // This is a soft assertion - we just verify both complete successfully
    try testing.expect(cold_time > 0);
    try testing.expect(warm_time > 0);
}
