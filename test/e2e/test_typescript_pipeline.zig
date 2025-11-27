//! TypeScript E2E Pipeline Tests
//!
//! Tests the full pipeline for TypeScript code:
//! 1. Extract constraints from TypeScript source
//! 2. Compile constraints to IR
//! 3. Validate extraction quality and correctness

const std = @import("std");
const testing = std.testing;
const helpers = @import("helpers.zig");
const E2ETestContext = helpers.E2ETestContext;

// Helper for case-insensitive matching
fn containsIgnoreCase(allocator: std.mem.Allocator, haystack: []const u8, needle: []const u8) !bool {
    const haystack_lower = try std.ascii.allocLowerString(allocator, haystack);
    defer allocator.free(haystack_lower);
    const needle_lower = try std.ascii.allocLowerString(allocator, needle);
    defer allocator.free(needle_lower);
    return std.mem.indexOf(u8, haystack_lower, needle_lower) != null;
}

// ============================================================================
// Test 1: API Handler Extraction
// ============================================================================

test "E2E TypeScript: API handler constraint extraction" {
    var ctx = try E2ETestContext.init(testing.allocator);
    defer ctx.deinit();

    std.debug.print("\n=== E2E TypeScript: API Handler Extraction ===\n", .{});

    const result = try ctx.runPipeline("test/e2e/fixtures/typescript/api_handler.ts");
    defer {
        var mut_result = result;
        mut_result.deinit(testing.allocator);
    }

    // Should extract constraints from API handlers
    try testing.expect(result.constraints.constraints.items.len >= 5);

    std.debug.print("Extracted {} constraints from API handler\n", .{result.constraints.constraints.items.len});

    // Verify key constraint patterns were found
    var found_interface = false;
    var found_async = false;
    var found_validation = false;

    for (result.constraints.constraints.items) |constraint| {
        const name_lower = try std.ascii.allocLowerString(testing.allocator, constraint.name);
        defer testing.allocator.free(name_lower);

        if (std.mem.indexOf(u8, name_lower, "request") != null or
            std.mem.indexOf(u8, name_lower, "response") != null)
        {
            found_interface = true;
        }
        if (std.mem.indexOf(u8, name_lower, "handler") != null or
            std.mem.indexOf(u8, name_lower, "async") != null)
        {
            found_async = true;
        }
        if (std.mem.indexOf(u8, name_lower, "validate") != null or
            std.mem.indexOf(u8, name_lower, "schema") != null)
        {
            found_validation = true;
        }
    }

    try testing.expect(found_interface or found_async or found_validation);

    std.debug.print("✓ API handler constraints extracted successfully\n", .{});
}

// ============================================================================
// Test 2: Utility Functions Extraction
// ============================================================================

test "E2E TypeScript: Utility functions constraint extraction" {
    var ctx = try E2ETestContext.init(testing.allocator);
    defer ctx.deinit();

    std.debug.print("\n=== E2E TypeScript: Utility Functions Extraction ===\n", .{});

    const result = try ctx.runPipeline("test/e2e/fixtures/typescript/utility.ts");
    defer {
        var mut_result = result;
        mut_result.deinit(testing.allocator);
    }

    // Should extract constraints from utility functions
    try testing.expect(result.constraints.constraints.items.len >= 3);

    std.debug.print("Extracted {} constraints from utilities\n", .{result.constraints.constraints.items.len});

    // Verify type guard and generic patterns
    var found_generic = false;
    var found_type_guard = false;

    for (result.constraints.constraints.items) |constraint| {
        const name_lower = try std.ascii.allocLowerString(testing.allocator, constraint.name);
        defer testing.allocator.free(name_lower);

        if (std.mem.indexOf(u8, name_lower, "result") != null or
            std.mem.indexOf(u8, name_lower, "chunk") != null or
            std.mem.indexOf(u8, name_lower, "unique") != null)
        {
            found_generic = true;
        }
        if (std.mem.indexOf(u8, name_lower, "isstring") != null or
            std.mem.indexOf(u8, name_lower, "isnumber") != null)
        {
            found_type_guard = true;
        }
    }

    try testing.expect(found_generic or found_type_guard);

    std.debug.print("✓ Utility function constraints extracted successfully\n", .{});
}

// ============================================================================
// Test 3: Validation Schema Extraction
// ============================================================================

test "E2E TypeScript: Validation schema constraint extraction" {
    var ctx = try E2ETestContext.init(testing.allocator);
    defer ctx.deinit();

    std.debug.print("\n=== E2E TypeScript: Validation Schema Extraction ===\n", .{});

    const result = try ctx.runPipeline("test/e2e/fixtures/typescript/validation.ts");
    defer {
        var mut_result = result;
        mut_result.deinit(testing.allocator);
    }

    // Should extract validation constraints
    try testing.expect(result.constraints.constraints.items.len >= 7);

    std.debug.print("Extracted {} validation constraints\n", .{result.constraints.constraints.items.len});

    // Check for specific validators
    var found_email = false;
    var found_phone = false;
    var found_password = false;

    for (result.constraints.constraints.items) |constraint| {
        const name_lower = try std.ascii.allocLowerString(testing.allocator, constraint.name);
        defer testing.allocator.free(name_lower);

        if (std.mem.indexOf(u8, name_lower, "email") != null) {
            found_email = true;
        }
        if (std.mem.indexOf(u8, name_lower, "phone") != null) {
            found_phone = true;
        }
        if (std.mem.indexOf(u8, name_lower, "password") != null) {
            found_password = true;
        }
    }

    try testing.expect(found_email or found_phone or found_password);

    std.debug.print("✓ Validation schema constraints extracted successfully\n", .{});
}

// ============================================================================
// Test 4: IR Compilation Validation
// ============================================================================

test "E2E TypeScript: IR compilation produces valid output" {
    var ctx = try E2ETestContext.init(testing.allocator);
    defer ctx.deinit();

    std.debug.print("\n=== E2E TypeScript: IR Compilation Validation ===\n", .{});

    const result = try ctx.runPipeline("test/e2e/fixtures/typescript/auth.ts");
    defer {
        var mut_result = result;
        mut_result.deinit(testing.allocator);
    }

    // Verify IR structure
    try testing.expect(result.ir.priority >= 0);

    // IR should have valid components
    const has_schema = result.ir.json_schema != null;
    const has_grammar = result.ir.grammar != null;
    const has_regex = result.ir.regex_patterns.len > 0;

    std.debug.print("IR components - Schema: {}, Grammar: {}, Regex: {}\n", .{ has_schema, has_grammar, has_regex });
    try testing.expect(has_schema or has_grammar or has_regex);

    std.debug.print("✓ IR compilation produced valid output\n", .{});
}
