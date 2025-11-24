// Tests for Braid constraint manipulation operations
const std = @import("std");
const testing = std.testing;
const ananke = @import("ananke");
const braid = @import("braid");

// Import types
const Constraint = ananke.Constraint;
const ConstraintSet = ananke.ConstraintSet;
const ConstraintKind = ananke.ConstraintKind;
const ConstraintSource = ananke.ConstraintSource;
const ConstraintPriority = ananke.ConstraintPriority;
const Severity = ananke.Severity;

test "mergeConstraints: merge two sets with no overlap" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create first set
    var set1 = ConstraintSet.init(allocator, "set1");
    defer set1.deinit();

    var c1 = Constraint.init(1, "constraint_1", "First constraint");
    c1.kind = .syntactic;
    c1.severity = .err;
    try set1.add(c1);

    var c2 = Constraint.init(2, "constraint_2", "Second constraint");
    c2.kind = .type_safety;
    c2.severity = .warning;
    try set1.add(c2);

    // Create second set
    var set2 = ConstraintSet.init(allocator, "set2");
    defer set2.deinit();

    var c3 = Constraint.init(3, "constraint_3", "Third constraint");
    c3.kind = .semantic;
    c3.severity = .err;
    try set2.add(c3);

    // Merge sets
    var merged = try braid.mergeConstraints(allocator, set1, set2);
    defer {
        allocator.free(merged.name);
        merged.deinit();
    }

    // Verify merged set
    try testing.expectEqualStrings("set1_merged_set2", merged.name);
    try testing.expectEqual(@as(usize, 3), merged.constraints.items.len);

    // Verify all constraints are present
    var found_1 = false;
    var found_2 = false;
    var found_3 = false;

    for (merged.constraints.items) |constraint| {
        if (constraint.id == 1) found_1 = true;
        if (constraint.id == 2) found_2 = true;
        if (constraint.id == 3) found_3 = true;
    }

    try testing.expect(found_1);
    try testing.expect(found_2);
    try testing.expect(found_3);
}

test "mergeConstraints: merge two sets with duplicates" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create first set
    var set1 = ConstraintSet.init(allocator, "setA");
    defer set1.deinit();

    var c1 = Constraint.init(1, "constraint_1", "First constraint");
    c1.kind = .syntactic;
    c1.severity = .err;
    try set1.add(c1);

    var c2 = Constraint.init(2, "constraint_2", "Second constraint");
    c2.kind = .type_safety;
    c2.severity = .warning;
    try set1.add(c2);

    // Create second set with overlapping constraint
    var set2 = ConstraintSet.init(allocator, "setB");
    defer set2.deinit();

    // Add same constraint (c1)
    try set2.add(c1);

    var c3 = Constraint.init(3, "constraint_3", "Third constraint");
    c3.kind = .semantic;
    c3.severity = .err;
    try set2.add(c3);

    // Merge sets
    var merged = try braid.mergeConstraints(allocator, set1, set2);
    defer {
        allocator.free(merged.name);
        merged.deinit();
    }

    // Verify merged set - should have 4 items (no deduplication in this simple add)
    try testing.expectEqualStrings("setA_merged_setB", merged.name);
    try testing.expectEqual(@as(usize, 4), merged.constraints.items.len);
}

test "mergeConstraints: merge with empty set" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create non-empty set
    var set1 = ConstraintSet.init(allocator, "full");
    defer set1.deinit();

    var c1 = Constraint.init(1, "constraint_1", "First constraint");
    c1.kind = .syntactic;
    c1.severity = .err;
    try set1.add(c1);

    // Create empty set
    var set2 = ConstraintSet.init(allocator, "empty");
    defer set2.deinit();

    // Merge sets
    var merged = try braid.mergeConstraints(allocator, set1, set2);
    defer {
        allocator.free(merged.name);
        merged.deinit();
    }

    // Verify merged set
    try testing.expectEqualStrings("full_merged_empty", merged.name);
    try testing.expectEqual(@as(usize, 1), merged.constraints.items.len);
    try testing.expectEqual(@as(u64, 1), merged.constraints.items[0].id);
}

test "mergeConstraints: merge two empty sets" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var set1 = ConstraintSet.init(allocator, "empty1");
    defer set1.deinit();

    var set2 = ConstraintSet.init(allocator, "empty2");
    defer set2.deinit();

    var merged = try braid.mergeConstraints(allocator, set1, set2);
    defer {
        allocator.free(merged.name);
        merged.deinit();
    }

    try testing.expectEqualStrings("empty1_merged_empty2", merged.name);
    try testing.expectEqual(@as(usize, 0), merged.constraints.items.len);
}

test "deduplicateConstraints: array with duplicates" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create array with duplicates
    var c1 = Constraint.init(1, "constraint_1", "Description A");
    c1.kind = .syntactic;
    c1.source = .AST_Pattern;
    c1.severity = .err;

    var c2 = Constraint.init(2, "constraint_2", "Description B");
    c2.kind = .type_safety;
    c2.source = .Type_System;
    c2.severity = .warning;

    // Duplicate of c1 (same kind, description, source)
    var c3 = Constraint.init(3, "constraint_3", "Description A");
    c3.kind = .syntactic;
    c3.source = .AST_Pattern;
    c3.severity = .err;

    const constraints = [_]Constraint{ c1, c2, c3 };

    // Deduplicate
    const unique = try braid.deduplicateConstraints(allocator, &constraints);
    defer allocator.free(unique);

    // Should have 2 unique constraints (c1 and c2, c3 is duplicate of c1)
    try testing.expectEqual(@as(usize, 2), unique.len);

    // Verify we kept the first occurrence
    try testing.expectEqual(@as(u64, 1), unique[0].id);
    try testing.expectEqual(@as(u64, 2), unique[1].id);
}

test "deduplicateConstraints: array with no duplicates" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create array with all unique constraints
    var c1 = Constraint.init(1, "constraint_1", "Description A");
    c1.kind = .syntactic;
    c1.source = .AST_Pattern;
    c1.severity = .err;

    var c2 = Constraint.init(2, "constraint_2", "Description B");
    c2.kind = .type_safety;
    c2.source = .Type_System;
    c2.severity = .warning;

    var c3 = Constraint.init(3, "constraint_3", "Description C");
    c3.kind = .semantic;
    c3.source = .Control_Flow;
    c3.severity = .info;

    const constraints = [_]Constraint{ c1, c2, c3 };

    // Deduplicate
    const unique = try braid.deduplicateConstraints(allocator, &constraints);
    defer allocator.free(unique);

    // Should have all 3 constraints
    try testing.expectEqual(@as(usize, 3), unique.len);
}

test "deduplicateConstraints: empty array" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const constraints: []const Constraint = &.{};

    const unique = try braid.deduplicateConstraints(allocator, constraints);
    defer allocator.free(unique);

    try testing.expectEqual(@as(usize, 0), unique.len);
}

test "deduplicateConstraints: all duplicates of same constraint" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create 5 identical constraints (same kind, description, source)
    var c1 = Constraint.init(1, "c1", "Same description");
    c1.kind = .syntactic;
    c1.source = .AST_Pattern;
    c1.severity = .err;

    var c2 = Constraint.init(2, "c2", "Same description");
    c2.kind = .syntactic;
    c2.source = .AST_Pattern;
    c2.severity = .err;

    var c3 = Constraint.init(3, "c3", "Same description");
    c3.kind = .syntactic;
    c3.source = .AST_Pattern;
    c3.severity = .err;

    var c4 = Constraint.init(4, "c4", "Same description");
    c4.kind = .syntactic;
    c4.source = .AST_Pattern;
    c4.severity = .err;

    var c5 = Constraint.init(5, "c5", "Same description");
    c5.kind = .syntactic;
    c5.source = .AST_Pattern;
    c5.severity = .err;

    const constraints = [_]Constraint{ c1, c2, c3, c4, c5 };

    const unique = try braid.deduplicateConstraints(allocator, &constraints);
    defer allocator.free(unique);

    // Should only keep first occurrence
    try testing.expectEqual(@as(usize, 1), unique.len);
    try testing.expectEqual(@as(u64, 1), unique[0].id);
}

test "updatePriority: update from Medium to High" {
    var constraint = Constraint.init(1, "test", "Test constraint");
    constraint.priority = .Medium;
    constraint.severity = .err;

    try testing.expectEqual(ConstraintPriority.Medium, constraint.priority);

    braid.updatePriority(&constraint, .High);

    try testing.expectEqual(ConstraintPriority.High, constraint.priority);
}

test "updatePriority: update from Low to Critical" {
    var constraint = Constraint.init(1, "test", "Test constraint");
    constraint.priority = .Low;
    constraint.severity = .err;

    try testing.expectEqual(ConstraintPriority.Low, constraint.priority);

    braid.updatePriority(&constraint, .Critical);

    try testing.expectEqual(ConstraintPriority.Critical, constraint.priority);
}

test "updatePriority: multiple updates" {
    var constraint = Constraint.init(1, "test", "Test constraint");
    constraint.priority = .Medium;
    constraint.severity = .err;

    braid.updatePriority(&constraint, .High);
    try testing.expectEqual(ConstraintPriority.High, constraint.priority);

    braid.updatePriority(&constraint, .Low);
    try testing.expectEqual(ConstraintPriority.Low, constraint.priority);

    braid.updatePriority(&constraint, .Critical);
    try testing.expectEqual(ConstraintPriority.Critical, constraint.priority);
}
