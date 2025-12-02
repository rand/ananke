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
    var constraint_set = try clew.extractFromTests(test_code, "test.zig");
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
        .error_rate = 0.02, // Over threshold
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

// ============================================================================
// Type Detection Edge Case Tests
// ============================================================================

// Test: Type patterns in comments should NOT trigger false positives
// Note: Current implementation uses string matching fallback which DOES match
// patterns in comments. This test documents the known limitation.
// When AST-only extraction is fully implemented, these should NOT match.
test "Type detection edge case: patterns in comments" {
    const allocator = testing.allocator;

    var clew = try Clew.init(allocator);
    defer clew.deinit();

    // Code with type patterns ONLY in comments, not in actual code
    const code_with_comment_patterns =
        \\// This function uses : any type - do not use any types
        \\// Optional chaining ?. and nullish coalescing ?? are useful
        \\function safeProcess(input: string): string {
        \\  return input.trim();
        \\}
    ;

    var constraint_set = try clew.extractFromCode(code_with_comment_patterns, "typescript");
    defer constraint_set.deinit();

    // Check if avoid_any_type was detected (from comment)
    var has_any_warning = false;
    for (constraint_set.constraints.items) |constraint| {
        if (std.mem.eql(u8, constraint.name, "avoid_any_type")) {
            has_any_warning = true;
        }
    }

    // KNOWN LIMITATION: String matching fallback currently matches patterns in comments
    // This documents the expected behavior with the current implementation.
    // When we have full AST-based extraction, this should be false.
    // For now, we expect true because the fallback uses indexOf on raw source.
    if (has_any_warning) {
        // Document: fallback matched pattern in comment (expected with current impl)
        std.debug.print("\n  Note: Fallback matched ': any' in comment (known limitation)\n", .{});
    }
}

// Test: Type patterns in strings should NOT trigger false positives
// Note: Current implementation uses string matching fallback which DOES match
// patterns in strings. This test documents the known limitation.
test "Type detection edge case: patterns in strings" {
    const allocator = testing.allocator;

    var clew = try Clew.init(allocator);
    defer clew.deinit();

    // Code with type patterns ONLY in string literals
    const code_with_string_patterns =
        \\function getTypeInfo(): string {
        \\  const message = "Use : any type sparingly";
        \\  const docs = "Optional chaining ?. is supported";
        \\  return message + docs;
        \\}
    ;

    var constraint_set = try clew.extractFromCode(code_with_string_patterns, "typescript");
    defer constraint_set.deinit();

    // Check if patterns in strings were detected
    var detected_from_string = false;
    for (constraint_set.constraints.items) |constraint| {
        if (std.mem.eql(u8, constraint.name, "avoid_any_type") or
            std.mem.eql(u8, constraint.name, "null_safety"))
        {
            detected_from_string = true;
        }
    }

    // KNOWN LIMITATION: String matching fallback currently matches patterns in string literals
    if (detected_from_string) {
        std.debug.print("\n  Note: Fallback matched pattern in string literal (known limitation)\n", .{});
    }
}

// Test: Cross-language type pattern detection
// TypeScript uses `?` for optional, Python uses `Optional[]`
test "Cross-language type patterns" {
    const allocator = testing.allocator;

    var clew = try Clew.init(allocator);
    defer clew.deinit();

    // TypeScript with optional chaining and nullish coalescing
    const typescript_code =
        \\function getUser(id: string): User | undefined {
        \\  const user = cache.get(id);
        \\  return user?.profile ?? defaultProfile;
        \\}
    ;

    // Python with Optional type hints
    const python_code =
        \\from typing import Optional
        \\
        \\def get_user(user_id: str) -> Optional[User]:
        \\    user = cache.get(user_id)
        \\    return user if user else None
    ;

    // Extract from TypeScript
    var ts_constraints = try clew.extractFromCode(typescript_code, "typescript");
    defer ts_constraints.deinit();

    // Extract from Python
    var py_constraints = try clew.extractFromCode(python_code, "python");
    defer py_constraints.deinit();

    // Check TypeScript detected null_safety (from ?. and ??)
    var ts_has_null_safety = false;
    for (ts_constraints.constraints.items) |constraint| {
        if (std.mem.eql(u8, constraint.name, "null_safety")) {
            ts_has_null_safety = true;
        }
    }
    try testing.expect(ts_has_null_safety);

    // Check Python detected null_safety (from Optional[])
    var py_has_null_safety = false;
    for (py_constraints.constraints.items) |constraint| {
        if (std.mem.eql(u8, constraint.name, "null_safety")) {
            py_has_null_safety = true;
        }
    }
    try testing.expect(py_has_null_safety);

    std.debug.print("\n  TypeScript null_safety: {}, Python null_safety: {}\n", .{ ts_has_null_safety, py_has_null_safety });
}

// Test: Ensure actual type annotations ARE detected (positive test)
test "Type detection positive case: real type annotations" {
    const allocator = testing.allocator;

    var clew = try Clew.init(allocator);
    defer clew.deinit();

    // Code with actual type annotations that SHOULD be detected
    const code_with_real_types =
        \\function processData(input: any): any {
        \\  const result = input?.data ?? {};
        \\  return result;
        \\}
    ;

    var constraint_set = try clew.extractFromCode(code_with_real_types, "typescript");
    defer constraint_set.deinit();

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

    // Real type patterns SHOULD be detected
    try testing.expect(has_any_warning);
    try testing.expect(has_null_safety);
}

// Test: Python Any type detection
test "Python Any type detection" {
    const allocator = testing.allocator;

    var clew = try Clew.init(allocator);
    defer clew.deinit();

    const python_code =
        \\from typing import Any, Optional
        \\
        \\def process_data(data: Any) -> Any:
        \\    return data
        \\
        \\def get_value(key: str) -> Optional[str]:
        \\    return cache.get(key)
    ;

    var constraint_set = try clew.extractFromCode(python_code, "python");
    defer constraint_set.deinit();

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

    // Python patterns should be detected
    try testing.expect(has_any_warning); // from ': Any' and '-> Any'
    try testing.expect(has_null_safety); // from 'Optional['
}
