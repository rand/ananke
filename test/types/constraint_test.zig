// Tests for constraint types
const std = @import("std");
const testing = std.testing;
const ananke = @import("ananke");

// Import constraint types
const Constraint = ananke.Constraint;
const ConstraintID = ananke.ConstraintID;
const ConstraintKind = ananke.ConstraintKind;
const ConstraintSource = ananke.ConstraintSource;
const EnforcementType = ananke.EnforcementType;
const ConstraintPriority = ananke.ConstraintPriority;
const ConstraintSet = ananke.ConstraintSet;
const ConstraintIR = ananke.ConstraintIR;
const Severity = ananke.types.constraint.Severity;

test "ConstraintID is u64" {
    const id: ConstraintID = 12345;
    try testing.expectEqual(@as(u64, 12345), id);
}

test "Constraint creation with init" {
    const constraint = Constraint.init(
        1,
        "test_constraint",
        "A test constraint for validation",
    );

    try testing.expectEqual(@as(ConstraintID, 1), constraint.id);
    try testing.expectEqualStrings("test_constraint", constraint.name);
    try testing.expectEqualStrings("A test constraint for validation", constraint.description);
    try testing.expectEqual(ConstraintKind.syntactic, constraint.kind);
    try testing.expectEqual(ConstraintSource.AST_Pattern, constraint.source);
    try testing.expectEqual(EnforcementType.Syntactic, constraint.enforcement);
    try testing.expectEqual(ConstraintPriority.Medium, constraint.priority);
    try testing.expectEqual(@as(f32, 1.0), constraint.confidence);
    try testing.expectEqual(@as(u32, 1), constraint.frequency);
    try testing.expectEqual(Severity.err, constraint.severity);
}

test "Constraint validation - valid constraint" {
    var constraint = Constraint.init(
        2,
        "valid_constraint",
        "This is a valid constraint",
    );
    constraint.confidence = 0.95;

    try testing.expect(constraint.isValid());
}

test "Constraint validation - invalid confidence too low" {
    var constraint = Constraint.init(
        3,
        "invalid_confidence_low",
        "Constraint with confidence < 0",
    );
    constraint.confidence = -0.1;

    try testing.expect(!constraint.isValid());
}

test "Constraint validation - invalid confidence too high" {
    var constraint = Constraint.init(
        4,
        "invalid_confidence_high",
        "Constraint with confidence > 1",
    );
    constraint.confidence = 1.5;

    try testing.expect(!constraint.isValid());
}

test "Constraint validation - empty name" {
    var constraint = Constraint.init(
        5,
        "",
        "Constraint with empty name",
    );

    try testing.expect(!constraint.isValid());
}

test "Constraint validation - enforcement type matches kind" {
    // Syntactic kind should have Syntactic enforcement
    var constraint1 = Constraint.init(6, "syntactic_test", "test");
    constraint1.kind = .syntactic;
    constraint1.enforcement = .Syntactic;
    try testing.expect(constraint1.isValid());

    // Type safety can have Structural or Semantic enforcement
    var constraint2 = Constraint.init(7, "type_test", "test");
    constraint2.kind = .type_safety;
    constraint2.enforcement = .Structural;
    try testing.expect(constraint2.isValid());

    var constraint3 = Constraint.init(8, "type_test2", "test");
    constraint3.kind = .type_safety;
    constraint3.enforcement = .Semantic;
    try testing.expect(constraint3.isValid());

    // Semantic kind should have Semantic enforcement
    var constraint4 = Constraint.init(9, "semantic_test", "test");
    constraint4.kind = .semantic;
    constraint4.enforcement = .Semantic;
    try testing.expect(constraint4.isValid());

    // Operational kind should have Performance enforcement
    var constraint5 = Constraint.init(10, "performance_test", "test");
    constraint5.kind = .operational;
    constraint5.enforcement = .Performance;
    try testing.expect(constraint5.isValid());

    // Security kind should have Security enforcement
    var constraint6 = Constraint.init(11, "security_test", "test");
    constraint6.kind = .security;
    constraint6.enforcement = .Security;
    try testing.expect(constraint6.isValid());

    // Architectural kind should have Structural enforcement
    var constraint7 = Constraint.init(12, "arch_test", "test");
    constraint7.kind = .architectural;
    constraint7.enforcement = .Structural;
    try testing.expect(constraint7.isValid());
}

test "Constraint validation - mismatched enforcement type" {
    var constraint = Constraint.init(13, "mismatched", "test");
    constraint.kind = .syntactic;
    constraint.enforcement = .Performance; // Wrong enforcement for syntactic

    try testing.expect(!constraint.isValid());
}

test "ConstraintPriority numeric conversion" {
    try testing.expectEqual(@as(u32, 0), ConstraintPriority.Low.toNumeric());
    try testing.expectEqual(@as(u32, 1), ConstraintPriority.Medium.toNumeric());
    try testing.expectEqual(@as(u32, 2), ConstraintPriority.High.toNumeric());
    try testing.expectEqual(@as(u32, 3), ConstraintPriority.Critical.toNumeric());
}

test "Constraint getPriorityValue" {
    var constraint = Constraint.init(14, "priority_test", "test");

    constraint.priority = .Low;
    try testing.expectEqual(@as(u32, 0), constraint.getPriorityValue());

    constraint.priority = .Medium;
    try testing.expectEqual(@as(u32, 1), constraint.getPriorityValue());

    constraint.priority = .High;
    try testing.expectEqual(@as(u32, 2), constraint.getPriorityValue());

    constraint.priority = .Critical;
    try testing.expectEqual(@as(u32, 3), constraint.getPriorityValue());
}

test "Constraint with all fields set" {
    var constraint = Constraint.init(15, "full_constraint", "Fully specified constraint");
    constraint.kind = .security;
    constraint.source = .LLM_Analysis;
    constraint.enforcement = .Security;
    constraint.priority = .Critical;
    constraint.confidence = 0.85;
    constraint.frequency = 42;
    constraint.severity = .warning;
    constraint.origin_file = "test.zig";
    constraint.origin_line = 123;

    try testing.expectEqual(@as(ConstraintID, 15), constraint.id);
    try testing.expectEqualStrings("full_constraint", constraint.name);
    try testing.expectEqual(ConstraintKind.security, constraint.kind);
    try testing.expectEqual(ConstraintSource.LLM_Analysis, constraint.source);
    try testing.expectEqual(EnforcementType.Security, constraint.enforcement);
    try testing.expectEqual(ConstraintPriority.Critical, constraint.priority);
    try testing.expectEqual(@as(f32, 0.85), constraint.confidence);
    try testing.expectEqual(@as(u32, 42), constraint.frequency);
    try testing.expectEqual(Severity.warning, constraint.severity);
    try testing.expectEqualStrings("test.zig", constraint.origin_file.?);
    try testing.expectEqual(@as(u32, 123), constraint.origin_line.?);
}

test "ConstraintSource enum values" {
    const sources = [_]ConstraintSource{
        .AST_Pattern,
        .Type_System,
        .Control_Flow,
        .Data_Flow,
        .Test_Mining,
        .Documentation,
        .Telemetry,
        .User_Defined,
        .LLM_Analysis,
    };

    // Ensure all enum values are accessible
    for (sources) |source| {
        _ = source;
    }
}

test "EnforcementType enum values" {
    const types = [_]EnforcementType{
        .Syntactic,
        .Structural,
        .Semantic,
        .Performance,
        .Security,
    };

    // Ensure all enum values are accessible
    for (types) |enforcement_type| {
        _ = enforcement_type;
    }
}

test "ConstraintKind enum values" {
    const kinds = [_]ConstraintKind{
        .syntactic,
        .type_safety,
        .semantic,
        .architectural,
        .operational,
        .security,
    };

    // Ensure all enum values are accessible
    for (kinds) |kind| {
        _ = kind;
    }
}

test "ConstraintSet creation and operations" {
    const allocator = testing.allocator;

    var set = ConstraintSet.init(allocator, "test_set");
    defer set.deinit();

    try testing.expectEqualStrings("test_set", set.name);
    try testing.expectEqual(@as(usize, 0), set.constraints.items.len);

    // Add a constraint
    const constraint = Constraint.init(20, "test_constraint", "Test");
    try set.add(constraint);

    try testing.expectEqual(@as(usize, 1), set.constraints.items.len);
    try testing.expectEqualStrings("test_constraint", set.constraints.items[0].name);
}

test "ConstraintSet multiple constraints" {
    const allocator = testing.allocator;

    var set = ConstraintSet.init(allocator, "multi_set");
    defer set.deinit();

    // Add multiple constraints
    var i: u64 = 0;
    while (i < 5) : (i += 1) {
        const constraint = Constraint.init(i, "constraint", "test");
        try set.add(constraint);
    }

    try testing.expectEqual(@as(usize, 5), set.constraints.items.len);

    // Verify IDs
    for (set.constraints.items, 0..) |constraint, idx| {
        try testing.expectEqual(@as(ConstraintID, idx), constraint.id);
    }
}

test "ConstraintIR basic structure" {
    const ir = ConstraintIR{};

    try testing.expect(ir.json_schema == null);
    try testing.expect(ir.grammar == null);
    try testing.expectEqual(@as(usize, 0), ir.regex_patterns.len);
    try testing.expect(ir.token_masks == null);
    try testing.expectEqual(@as(u32, 0), ir.priority);
}

test "Constraint timestamp is set" {
    const constraint = Constraint.init(100, "timestamp_test", "test");

    // Timestamp should be set and be a reasonable value (not 0)
    try testing.expect(constraint.created_at > 0);
}

test "Constraint optional fields default to null" {
    const constraint = Constraint.init(101, "optional_test", "test");

    try testing.expect(constraint.origin_file == null);
    try testing.expect(constraint.origin_line == null);
    try testing.expect(constraint.validate == null);
    try testing.expect(constraint.compile_fn == null);
}
