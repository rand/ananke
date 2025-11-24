// Tests for regex pattern extraction in Braid
const std = @import("std");
const testing = std.testing;
const ananke = @import("ananke");
const braid = @import("braid");

// Import constraint types
const Constraint = ananke.Constraint;
const ConstraintKind = ananke.ConstraintKind;
const buildRegexPattern = braid.buildRegexPattern;

test "buildRegexPattern - single regex constraint with 'must match regex:'" {
    const allocator = testing.allocator;

    var constraints = [_]Constraint{
        Constraint.init(1, "email_format", "must match regex: [a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}"),
    };
    constraints[0].kind = .type_safety;

    const result = try buildRegexPattern(allocator, &constraints);
    defer if (result) |pattern| allocator.free(pattern);

    try testing.expect(result != null);
    if (result) |pattern| {
        try testing.expect(std.mem.indexOf(u8, pattern, "[a-zA-Z0-9._%+-]+@") != null);
        try testing.expect(std.mem.indexOf(u8, pattern, "|") == null); // No OR operator for single pattern
    }
}

test "buildRegexPattern - single regex constraint with 'regex:' marker" {
    const allocator = testing.allocator;

    var constraints = [_]Constraint{
        Constraint.init(1, "url_pattern", "regex: https?://[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}"),
    };
    constraints[0].kind = .syntactic;

    const result = try buildRegexPattern(allocator, &constraints);
    defer if (result) |pattern| allocator.free(pattern);

    try testing.expect(result != null);
    if (result) |pattern| {
        try testing.expect(std.mem.indexOf(u8, pattern, "https?://") != null);
    }
}

test "buildRegexPattern - single regex constraint with 'pattern:' marker" {
    const allocator = testing.allocator;

    var constraints = [_]Constraint{
        Constraint.init(1, "uuid", "pattern: [0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"),
    };
    constraints[0].kind = .type_safety;

    const result = try buildRegexPattern(allocator, &constraints);
    defer if (result) |pattern| allocator.free(pattern);

    try testing.expect(result != null);
    if (result) |pattern| {
        try testing.expect(std.mem.indexOf(u8, pattern, "[0-9a-f]") != null);
    }
}

test "buildRegexPattern - multiple regex constraints combined with OR" {
    const allocator = testing.allocator;

    var constraints = [_]Constraint{
        Constraint.init(1, "first_pattern", "must match regex: \\d{3}-\\d{3}-\\d{4}"),
        Constraint.init(2, "second_pattern", "regex: \\(\\d{3}\\) \\d{3}-\\d{4}"),
    };
    constraints[0].kind = .type_safety;
    constraints[1].kind = .type_safety;

    const result = try buildRegexPattern(allocator, &constraints);
    defer if (result) |pattern| allocator.free(pattern);

    try testing.expect(result != null);
    if (result) |pattern| {
        // Should contain both patterns
        try testing.expect(std.mem.indexOf(u8, pattern, "\\d{3}-\\d{3}-\\d{4}") != null);
        try testing.expect(std.mem.indexOf(u8, pattern, "\\(\\d{3}\\) \\d{3}-\\d{4}") != null);
        // Should have OR operator between them
        try testing.expect(std.mem.indexOf(u8, pattern, "|") != null);
    }
}

test "buildRegexPattern - no regex constraints returns null" {
    const allocator = testing.allocator;

    var constraints = [_]Constraint{
        Constraint.init(1, "type_check", "must be a valid integer"),
        Constraint.init(2, "length_check", "must be less than 100 characters"),
    };
    constraints[0].kind = .type_safety;
    constraints[1].kind = .semantic;

    const result = try buildRegexPattern(allocator, &constraints);

    try testing.expect(result == null);
}

test "buildRegexPattern - empty constraint array returns null" {
    const allocator = testing.allocator;

    const constraints = [_]Constraint{};

    const result = try buildRegexPattern(allocator, &constraints);

    try testing.expect(result == null);
}

test "buildRegexPattern - mixed constraints with only some having regex" {
    const allocator = testing.allocator;

    var constraints = [_]Constraint{
        Constraint.init(1, "non_regex", "must be positive"),
        Constraint.init(2, "has_regex", "regex: [0-9]{1,5}"),
        Constraint.init(3, "another_non_regex", "must be sorted"),
        Constraint.init(4, "another_regex", "must match regex: [A-Z]{2}-\\d{4}"),
    };

    const result = try buildRegexPattern(allocator, &constraints);
    defer if (result) |pattern| allocator.free(pattern);

    try testing.expect(result != null);
    if (result) |pattern| {
        // Should contain only the regex patterns
        try testing.expect(std.mem.indexOf(u8, pattern, "[0-9]{1,5}") != null);
        try testing.expect(std.mem.indexOf(u8, pattern, "[A-Z]{2}-\\d{4}") != null);
        try testing.expect(std.mem.indexOf(u8, pattern, "|") != null);
    }
}

test "buildRegexPattern - malformed regex (missing pattern) handled gracefully" {
    const allocator = testing.allocator;

    var constraints = [_]Constraint{
        Constraint.init(1, "malformed", "regex: "),
        Constraint.init(2, "valid", "regex: [0-9]+"),
    };
    constraints[0].kind = .type_safety;
    constraints[1].kind = .type_safety;

    const result = try buildRegexPattern(allocator, &constraints);
    defer if (result) |pattern| allocator.free(pattern);

    try testing.expect(result != null);
    if (result) |pattern| {
        // Should only include the valid pattern
        try testing.expect(std.mem.indexOf(u8, pattern, "[0-9]+") != null);
        // Should not have leading OR operator
        try testing.expect(pattern[0] != '|');
    }
}

test "buildRegexPattern - pattern with trailing whitespace trimmed" {
    const allocator = testing.allocator;

    var constraints = [_]Constraint{
        Constraint.init(1, "whitespace", "regex: [a-z]+   "),
    };
    constraints[0].kind = .type_safety;

    const result = try buildRegexPattern(allocator, &constraints);
    defer if (result) |pattern| allocator.free(pattern);

    try testing.expect(result != null);
    if (result) |pattern| {
        // Pattern should be trimmed
        try testing.expectEqualStrings("[a-z]+", pattern);
    }
}

test "buildRegexPattern - pattern extraction with end-of-string" {
    const allocator = testing.allocator;

    var constraints = [_]Constraint{
        Constraint.init(1, "pattern1", "regex: [0-9]+"),
        Constraint.init(2, "pattern2", "pattern: [a-z]+"),
    };
    constraints[0].kind = .type_safety;
    constraints[1].kind = .type_safety;

    const result = try buildRegexPattern(allocator, &constraints);
    defer if (result) |pattern| allocator.free(pattern);

    try testing.expect(result != null);
    if (result) |pattern| {
        // Should extract the full patterns
        try testing.expect(std.mem.indexOf(u8, pattern, "[0-9]+") != null);
        try testing.expect(std.mem.indexOf(u8, pattern, "[a-z]+") != null);
        // Should have OR operator between them
        try testing.expect(std.mem.indexOf(u8, pattern, "|") != null);
    }
}
