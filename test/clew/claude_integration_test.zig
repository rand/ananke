// Tests for Claude API integration in Clew constraint extraction
const std = @import("std");
const testing = std.testing;
const Clew = @import("clew").Clew;

// Test extraction without Claude client (baseline functionality)
test "Clew extraction without Claude client" {
    const allocator = testing.allocator;

    // Create Clew instance without setting Claude client
    var clew = try Clew.init(allocator);
    defer clew.deinit();

    const test_code =
        \\function processUser(input: any) {
        \\  return input.name;
        \\}
    ;

    // Extract constraints (should work with syntactic analysis only)
    var constraint_set = try clew.extractFromCode(test_code, "typescript");
    defer constraint_set.deinit();

    // Should have some syntactic constraints
    try testing.expect(constraint_set.constraints.items.len > 0);

    // Should not have any LLM_Analysis constraints (no Claude client)
    for (constraint_set.constraints.items) |constraint| {
        try testing.expect(constraint.source != .LLM_Analysis);
    }
}

// Test extraction from simple code produces constraints
test "Clew extracts type safety constraints" {
    const allocator = testing.allocator;

    var clew = try Clew.init(allocator);
    defer clew.deinit();

    const test_code =
        \\function processUser(input: any) {
        \\  return input?.name ?? "unknown";
        \\}
    ;

    var constraint_set = try clew.extractFromCode(test_code, "typescript");
    defer constraint_set.deinit();

    // Should detect 'any' type usage
    var has_any_warning = false;
    var has_null_safety = false;

    for (constraint_set.constraints.items) |constraint| {
        if (std.mem.eql(u8, constraint.name, "avoid_any_type")) {
            has_any_warning = true;
        }
        if (std.mem.eql(u8, constraint.name, "null_safety")) {
            has_null_safety = true;
        }
    }

    try testing.expect(has_any_warning);
    try testing.expect(has_null_safety);
}

// Test extraction from tests works
test "Clew extraction from test code" {
    const allocator = testing.allocator;

    var clew = try Clew.init(allocator);
    defer clew.deinit();

    const test_code =
        \\test "array access is bounds checked" {
        \\  const arr = [1, 2, 3];
        \\  try testing.expectError(error.IndexOutOfBounds, arr[10]);
        \\}
    ;

    // Should not fail even with no assertions parser yet
    var constraint_set = try clew.extractFromTests(test_code);
    defer constraint_set.deinit();

    // Currently returns empty set since parseTestAssertions is stubbed
    // This test just verifies the code path works
}

// Test multiple extractions produce consistent results
test "Multiple extractions are consistent" {
    const allocator = testing.allocator;

    var clew = try Clew.init(allocator);
    defer clew.deinit();

    const test_code = "function foo() {}";

    // Extract twice
    var result1 = try clew.extractFromCode(test_code, "typescript");
    defer result1.deinit();

    var result2 = try clew.extractFromCode(test_code, "typescript");
    defer result2.deinit();

    // Both should have constraints
    try testing.expect(result1.constraints.items.len > 0);
    try testing.expect(result2.constraints.items.len > 0);

    // Should have same number of constraints (consistent extraction)
    try testing.expectEqual(result1.constraints.items.len, result2.constraints.items.len);
}

// Test telemetry extraction
test "Clew extraction from telemetry" {
    const allocator = testing.allocator;

    var clew = try Clew.init(allocator);
    defer clew.deinit();

    const telemetry = @import("clew").Telemetry{
        .latency_p99 = 150.0, // Over threshold
        .error_rate = 0.02,   // Over threshold
    };

    var constraint_set = try clew.extractFromTelemetry(telemetry);
    defer constraint_set.deinit();

    // Should have constraints for both violations
    try testing.expect(constraint_set.constraints.items.len >= 2);

    var has_latency_constraint = false;
    var has_error_rate_constraint = false;

    for (constraint_set.constraints.items) |constraint| {
        if (std.mem.eql(u8, constraint.name, "latency_bound")) {
            has_latency_constraint = true;
        }
        if (std.mem.eql(u8, constraint.name, "error_rate")) {
            has_error_rate_constraint = true;
        }
    }

    try testing.expect(has_latency_constraint);
    try testing.expect(has_error_rate_constraint);
}

// Test constraint sources are properly set
test "Constraints have correct source attribution" {
    const allocator = testing.allocator;

    var clew = try Clew.init(allocator);
    defer clew.deinit();

    const test_code =
        \\function hello(name: string): void {
        \\  console.log("Hello " + name);
        \\}
    ;

    var constraint_set = try clew.extractFromCode(test_code, "typescript");
    defer constraint_set.deinit();

    // All constraints should have valid sources
    for (constraint_set.constraints.items) |constraint| {
        // Source should be one of the expected types
        const valid_source = constraint.source == .AST_Pattern or
            constraint.source == .Type_System or
            constraint.source == .Control_Flow or
            constraint.source == .Data_Flow;
        try testing.expect(valid_source);
    }
}

// Test different languages are handled
test "Clew handles multiple languages" {
    const allocator = testing.allocator;

    var clew = try Clew.init(allocator);
    defer clew.deinit();

    const test_cases = [_]struct {
        code: []const u8,
        lang: []const u8,
    }{
        .{ .code = "function foo() {}", .lang = "javascript" },
        .{ .code = "fn main() {}", .lang = "rust" },
        .{ .code = "def hello():", .lang = "python" },
        .{ .code = "pub fn init() void {}", .lang = "zig" },
    };

    for (test_cases) |test_case| {
        var constraint_set = try clew.extractFromCode(test_case.code, test_case.lang);
        defer constraint_set.deinit();

        // Should extract at least some constraints for each language
        try testing.expect(constraint_set.constraints.items.len > 0);
    }
}
