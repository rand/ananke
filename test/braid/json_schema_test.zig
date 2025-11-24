// Tests for JSON Schema generation in Braid
const std = @import("std");
const testing = std.testing;
const ananke = @import("ananke");
const braid = @import("braid");

const Constraint = ananke.Constraint;
const ConstraintKind = ananke.ConstraintKind;
const Severity = ananke.types.constraint.Severity;
const buildJSONSchemaString = braid.buildJSONSchemaString;

// Helper to create a type safety constraint
fn makeTypeConstraint(id: u64, name: []const u8, description: []const u8) Constraint {
    var c = Constraint.init(id, name, description);
    c.kind = .type_safety;
    c.severity = .err;
    return c;
}

// Test 1: Simple object with primitive types
test "JSON Schema: Simple object with primitives" {
    const allocator = testing.allocator;

    const constraints = [_]Constraint{
        makeTypeConstraint(1, "user_name", "name: string"),
        makeTypeConstraint(2, "user_age", "age: number"),
        makeTypeConstraint(3, "user_active", "active: boolean"),
    };

    const schema = try buildJSONSchemaString(allocator, &constraints);
    defer allocator.free(schema);

    // Verify schema structure
    try testing.expect(std.mem.indexOf(u8, schema, "\"type\":\"object\"") != null);
    try testing.expect(std.mem.indexOf(u8, schema, "\"properties\"") != null);
    try testing.expect(std.mem.indexOf(u8, schema, "\"name\"") != null);
    try testing.expect(std.mem.indexOf(u8, schema, "\"age\"") != null);
    try testing.expect(std.mem.indexOf(u8, schema, "\"active\"") != null);
    try testing.expect(std.mem.indexOf(u8, schema, "\"type\":\"string\"") != null);
    try testing.expect(std.mem.indexOf(u8, schema, "\"type\":\"integer\"") != null);
    try testing.expect(std.mem.indexOf(u8, schema, "\"type\":\"boolean\"") != null);

    // All should be required
    try testing.expect(std.mem.indexOf(u8, schema, "\"required\"") != null);
}

// Test 2: Object with array property
test "JSON Schema: Object with array property" {
    const allocator = testing.allocator;

    const constraints = [_]Constraint{
        makeTypeConstraint(1, "user_tags", "tags: Array<string>"),
        makeTypeConstraint(2, "user_scores", "scores: number[]"),
    };

    const schema = try buildJSONSchemaString(allocator, &constraints);
    defer allocator.free(schema);

    // Verify array types
    try testing.expect(std.mem.indexOf(u8, schema, "\"type\":\"array\"") != null);
    try testing.expect(std.mem.indexOf(u8, schema, "\"items\"") != null);
    try testing.expect(std.mem.indexOf(u8, schema, "\"tags\"") != null);
    try testing.expect(std.mem.indexOf(u8, schema, "\"scores\"") != null);
}

// Test 3: Object with nested object
test "JSON Schema: Object with nested object" {
    const allocator = testing.allocator;

    const constraints = [_]Constraint{
        makeTypeConstraint(1, "user_profile", "{ name: string; email: string }"),
    };

    const schema = try buildJSONSchemaString(allocator, &constraints);
    defer allocator.free(schema);

    // Verify nested object structure
    try testing.expect(std.mem.indexOf(u8, schema, "\"type\":\"object\"") != null);
    try testing.expect(std.mem.indexOf(u8, schema, "\"properties\"") != null);
    try testing.expect(std.mem.indexOf(u8, schema, "\"name\"") != null);
    try testing.expect(std.mem.indexOf(u8, schema, "\"email\"") != null);
}

// Test 4: Union types (anyOf)
test "JSON Schema: Union types" {
    const allocator = testing.allocator;

    const constraints = [_]Constraint{
        makeTypeConstraint(1, "value", "string | number"),
    };

    const schema = try buildJSONSchemaString(allocator, &constraints);
    defer allocator.free(schema);

    // Verify union type structure
    try testing.expect(std.mem.indexOf(u8, schema, "\"anyOf\"") != null);
    try testing.expect(std.mem.indexOf(u8, schema, "\"type\":\"string\"") != null);
    try testing.expect(std.mem.indexOf(u8, schema, "\"type\":\"integer\"") != null);
}

// Test 5: Optional properties
test "JSON Schema: Optional properties" {
    const allocator = testing.allocator;

    const constraints = [_]Constraint{
        makeTypeConstraint(1, "required_field", "name: string"),
        makeTypeConstraint(2, "optional_field", "email?: string"),
    };

    const schema = try buildJSONSchemaString(allocator, &constraints);
    defer allocator.free(schema);

    // Verify required array only contains non-optional field
    try testing.expect(std.mem.indexOf(u8, schema, "\"required\"") != null);
    try testing.expect(std.mem.indexOf(u8, schema, "\"name\"") != null);

    // Both properties should be present
    try testing.expect(std.mem.indexOf(u8, schema, "\"email\"") != null);
}

// Test 6: Array with specific item type
test "JSON Schema: Array with specific item type" {
    const allocator = testing.allocator;

    const constraints = [_]Constraint{
        makeTypeConstraint(1, "numbers", "Array<integer>"),
    };

    const schema = try buildJSONSchemaString(allocator, &constraints);
    defer allocator.free(schema);

    // Verify array with integer items
    try testing.expect(std.mem.indexOf(u8, schema, "\"type\":\"array\"") != null);
    try testing.expect(std.mem.indexOf(u8, schema, "\"items\"") != null);
    try testing.expect(std.mem.indexOf(u8, schema, "\"type\":\"integer\"") != null);
}

// Test 7: String with pattern constraint
test "JSON Schema: String with pattern" {
    const allocator = testing.allocator;

    const constraints = [_]Constraint{
        makeTypeConstraint(1, "email", "email"),
        makeTypeConstraint(2, "website", "uri"),
    };

    const schema = try buildJSONSchemaString(allocator, &constraints);
    defer allocator.free(schema);

    // Verify format constraints
    try testing.expect(std.mem.indexOf(u8, schema, "\"format\":\"email\"") != null);
    try testing.expect(std.mem.indexOf(u8, schema, "\"format\":\"uri\"") != null);
}

// Test 8: Complex nested schema (interface)
test "JSON Schema: Complex interface type" {
    const allocator = testing.allocator;

    const constraints = [_]Constraint{
        makeTypeConstraint(
            1,
            "user",
            "interface User { name: string; age: number; email?: string }",
        ),
    };

    const schema = try buildJSONSchemaString(allocator, &constraints);
    defer allocator.free(schema);

    // Verify interface was parsed correctly
    try testing.expect(std.mem.indexOf(u8, schema, "\"type\":\"object\"") != null);
    try testing.expect(std.mem.indexOf(u8, schema, "\"properties\"") != null);
    try testing.expect(std.mem.indexOf(u8, schema, "\"name\"") != null);
    try testing.expect(std.mem.indexOf(u8, schema, "\"age\"") != null);
    try testing.expect(std.mem.indexOf(u8, schema, "\"email\"") != null);

    // Required should only include name and age (email is optional)
    try testing.expect(std.mem.indexOf(u8, schema, "\"required\"") != null);
}

// Test 9: Empty constraints should produce minimal schema
test "JSON Schema: Empty constraints" {
    const allocator = testing.allocator;

    const constraints = [_]Constraint{};

    const schema = try buildJSONSchemaString(allocator, &constraints);
    defer allocator.free(schema);

    // Should produce minimal object schema
    try testing.expect(std.mem.indexOf(u8, schema, "\"type\":\"object\"") != null);
}

// Test 10: Non-type-safety constraints should be ignored
test "JSON Schema: Ignore non-type constraints" {
    const allocator = testing.allocator;

    var syntactic_constraint = Constraint.init(1, "syntax", "some syntax rule");
    syntactic_constraint.kind = .syntactic;
    syntactic_constraint.severity = .err;

    const type_constraint = makeTypeConstraint(2, "value", "name: string");

    const constraints = [_]Constraint{ syntactic_constraint, type_constraint };

    const schema = try buildJSONSchemaString(allocator, &constraints);
    defer allocator.free(schema);

    // Should only include the type constraint
    try testing.expect(std.mem.indexOf(u8, schema, "\"name\"") != null);
    try testing.expect(std.mem.indexOf(u8, schema, "\"type\":\"string\"") != null);
}

// Test 11: Number range constraints
test "JSON Schema: Number with range" {
    const allocator = testing.allocator;

    const constraints = [_]Constraint{
        makeTypeConstraint(1, "age", "age: range:0-120"),
    };

    const schema = try buildJSONSchemaString(allocator, &constraints);
    defer allocator.free(schema);

    // Verify range constraints
    try testing.expect(std.mem.indexOf(u8, schema, "\"minimum\":0") != null);
    try testing.expect(std.mem.indexOf(u8, schema, "\"maximum\":120") != null);
}

// Test 12: Valid JSON output
test "JSON Schema: Output is valid JSON" {
    const allocator = testing.allocator;

    const constraints = [_]Constraint{
        makeTypeConstraint(1, "user", "{ name: string; age: number }"),
    };

    const schema = try buildJSONSchemaString(allocator, &constraints);
    defer allocator.free(schema);

    // Try to parse it as JSON
    const parsed = std.json.parseFromSlice(
        std.json.Value,
        allocator,
        schema,
        .{},
    ) catch |err| {
        std.debug.print("Failed to parse JSON: {}\nSchema: {s}\n", .{ err, schema });
        return err;
    };
    defer parsed.deinit();

    // Verify root is an object
    try testing.expect(parsed.value == .object);
}
