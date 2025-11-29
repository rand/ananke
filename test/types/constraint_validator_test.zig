const std = @import("std");
const testing = std.testing;
const Constraint = @import("../../src/types/constraint.zig").Constraint;
const ConstraintSet = @import("../../src/types/constraint.zig").ConstraintSet;
const validator = @import("../../src/types/constraint_validator.zig");

test "validateConstraint - accepts valid constraint" {
    const allocator = testing.allocator;

    const valid = Constraint{
        .name = "valid_name",
        .description = "Valid description",
        .kind = .syntactic,
        .severity = .err,
        .confidence = 0.85,
    };

    try validator.validateConstraint(valid);
    try testing.expect(validator.isValidConstraint(valid));
}

test "validateConstraint - rejects empty name" {
    const constraint = Constraint{
        .name = "",
        .description = "Has description",
        .kind = .syntactic,
        .severity = .err,
    };

    try testing.expectError(validator.ValidationError.EmptyName, validator.validateConstraint(constraint));
    try testing.expect(!validator.isValidConstraint(constraint));
}

test "validateConstraint - rejects empty description" {
    const constraint = Constraint{
        .name = "has_name",
        .description = "",
        .kind = .syntactic,
        .severity = .err,
    };

    try testing.expectError(validator.ValidationError.EmptyDescription, validator.validateConstraint(constraint));
    try testing.expect(!validator.isValidConstraint(constraint));
}

test "validateConstraint - rejects confidence < 0" {
    const constraint = Constraint{
        .name = "test",
        .description = "Test",
        .kind = .syntactic,
        .severity = .err,
        .confidence = -0.5,
    };

    try testing.expectError(validator.ValidationError.InvalidConfidence, validator.validateConstraint(constraint));
}

test "validateConstraint - rejects confidence > 1" {
    const constraint = Constraint{
        .name = "test",
        .description = "Test",
        .kind = .syntactic,
        .severity = .err,
        .confidence = 1.5,
    };

    try testing.expectError(validator.ValidationError.InvalidConfidence, validator.validateConstraint(constraint));
}

test "validateConstraintSet - accepts valid set" {
    const allocator = testing.allocator;

    var set = ConstraintSet.init(allocator, try allocator.dupe(u8, "test_set"));
    defer set.deinit();

    try set.add(Constraint{
        .name = try allocator.dupe(u8, "constraint1"),
        .description = try allocator.dupe(u8, "Description 1"),
        .kind = .syntactic,
        .severity = .err,
    });

    try validator.validateConstraintSet(set);
    try testing.expect(validator.isValidConstraintSet(set));
}

test "validateConstraintSet - rejects empty set" {
    const allocator = testing.allocator;

    var set = ConstraintSet.init(allocator, try allocator.dupe(u8, "empty_set"));
    defer set.deinit();

    try testing.expectError(validator.ValidationError.EmptyConstraintSet, validator.validateConstraintSet(set));
    try testing.expect(!validator.isValidConstraintSet(set));
}

test "validateConstraintSet - rejects set with invalid constraint" {
    const allocator = testing.allocator;

    var set = ConstraintSet.init(allocator, try allocator.dupe(u8, "test_set"));
    defer set.deinit();

    // Add invalid constraint (empty name)
    try set.add(Constraint{
        .name = try allocator.dupe(u8, ""),
        .description = try allocator.dupe(u8, "Description"),
        .kind = .syntactic,
        .severity = .err,
    });

    try testing.expectError(validator.ValidationError.EmptyName, validator.validateConstraintSet(set));
}

test "safeGet - returns constraint when in bounds" {
    const allocator = testing.allocator;

    var set = ConstraintSet.init(allocator, try allocator.dupe(u8, "test_set"));
    defer set.deinit();

    try set.add(Constraint{
        .name = try allocator.dupe(u8, "test"),
        .description = try allocator.dupe(u8, "Test constraint"),
        .kind = .syntactic,
        .severity = .err,
    });

    const result = validator.safeGet(&set, 0);
    try testing.expect(result != null);
    try testing.expectEqualStrings("test", result.?.name);
}

test "safeGet - returns null when out of bounds" {
    const allocator = testing.allocator;

    var set = ConstraintSet.init(allocator, try allocator.dupe(u8, "test_set"));
    defer set.deinit();

    const result = validator.safeGet(&set, 0);
    try testing.expect(result == null);

    const result2 = validator.safeGet(&set, 100);
    try testing.expect(result2 == null);
}

test "isEmpty - detects empty set" {
    const allocator = testing.allocator;

    var set = ConstraintSet.init(allocator, try allocator.dupe(u8, "test_set"));
    defer set.deinit();

    try testing.expect(validator.isEmpty(&set));
}

test "isEmpty - detects non-empty set" {
    const allocator = testing.allocator;

    var set = ConstraintSet.init(allocator, try allocator.dupe(u8, "test_set"));
    defer set.deinit();

    try set.add(Constraint{
        .name = try allocator.dupe(u8, "test"),
        .description = try allocator.dupe(u8, "Test"),
        .kind = .syntactic,
        .severity = .err,
    });

    try testing.expect(!validator.isEmpty(&set));
}

test "count - returns correct count" {
    const allocator = testing.allocator;

    var set = ConstraintSet.init(allocator, try allocator.dupe(u8, "test_set"));
    defer set.deinit();

    try testing.expectEqual(@as(usize, 0), validator.count(&set));

    try set.add(Constraint{
        .name = try allocator.dupe(u8, "test1"),
        .description = try allocator.dupe(u8, "Test 1"),
        .kind = .syntactic,
        .severity = .err,
    });

    try testing.expectEqual(@as(usize, 1), validator.count(&set));

    try set.add(Constraint{
        .name = try allocator.dupe(u8, "test2"),
        .description = try allocator.dupe(u8, "Test 2"),
        .kind = .syntactic,
        .severity = .err,
    });

    try testing.expectEqual(@as(usize, 2), validator.count(&set));
}

test "removeInvalid - removes invalid constraints" {
    const allocator = testing.allocator;

    var set = ConstraintSet.init(allocator, try allocator.dupe(u8, "test_set"));
    defer set.deinit();

    // Add valid constraint
    try set.add(Constraint{
        .name = try allocator.dupe(u8, "valid"),
        .description = try allocator.dupe(u8, "Valid constraint"),
        .kind = .syntactic,
        .severity = .err,
    });

    // Add invalid constraint (empty name)
    try set.add(Constraint{
        .name = try allocator.dupe(u8, ""),
        .description = try allocator.dupe(u8, "Invalid - empty name"),
        .kind = .syntactic,
        .severity = .err,
    });

    // Add invalid constraint (empty description)
    try set.add(Constraint{
        .name = try allocator.dupe(u8, "invalid2"),
        .description = try allocator.dupe(u8, ""),
        .kind = .syntactic,
        .severity = .err,
    });

    // Add another valid constraint
    try set.add(Constraint{
        .name = try allocator.dupe(u8, "valid2"),
        .description = try allocator.dupe(u8, "Another valid constraint"),
        .kind = .type_safety,
        .severity = .warning,
    });

    try testing.expectEqual(@as(usize, 4), set.constraints.items.len);

    const removed = try validator.removeInvalid(allocator, &set);
    try testing.expectEqual(@as(usize, 2), removed);
    try testing.expectEqual(@as(usize, 2), set.constraints.items.len);

    // Verify remaining constraints are valid
    for (set.constraints.items) |constraint| {
        try testing.expect(validator.isValidConstraint(constraint));
    }
}

test "createDefaultConstraint - creates valid constraint" {
    const allocator = testing.allocator;

    const default = try validator.createDefaultConstraint(allocator);
    defer {
        allocator.free(default.name);
        allocator.free(default.description);
    }

    try validator.validateConstraint(default);
    try testing.expect(validator.isValidConstraint(default));
    try testing.expectEqualStrings("default_constraint", default.name);
}

test "removeInvalid - handles all valid constraints" {
    const allocator = testing.allocator;

    var set = ConstraintSet.init(allocator, try allocator.dupe(u8, "test_set"));
    defer set.deinit();

    try set.add(Constraint{
        .name = try allocator.dupe(u8, "valid1"),
        .description = try allocator.dupe(u8, "Valid 1"),
        .kind = .syntactic,
        .severity = .err,
    });

    try set.add(Constraint{
        .name = try allocator.dupe(u8, "valid2"),
        .description = try allocator.dupe(u8, "Valid 2"),
        .kind = .semantic,
        .severity = .warning,
    });

    const removed = try validator.removeInvalid(allocator, &set);
    try testing.expectEqual(@as(usize, 0), removed);
    try testing.expectEqual(@as(usize, 2), set.constraints.items.len);
}

test "removeInvalid - handles all invalid constraints" {
    const allocator = testing.allocator;

    var set = ConstraintSet.init(allocator, try allocator.dupe(u8, "test_set"));
    defer set.deinit();

    try set.add(Constraint{
        .name = try allocator.dupe(u8, ""),
        .description = try allocator.dupe(u8, "Invalid 1"),
        .kind = .syntactic,
        .severity = .err,
    });

    try set.add(Constraint{
        .name = try allocator.dupe(u8, "invalid2"),
        .description = try allocator.dupe(u8, ""),
        .kind = .semantic,
        .severity = .warning,
    });

    const removed = try validator.removeInvalid(allocator, &set);
    try testing.expectEqual(@as(usize, 2), removed);
    try testing.expectEqual(@as(usize, 0), set.constraints.items.len);
}
