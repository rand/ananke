//! Python E2E Pipeline Tests
//!
//! Tests the full pipeline for Python code:
//! 1. Extract constraints from Python source
//! 2. Compile constraints to IR
//! 3. Validate extraction quality and correctness

const std = @import("std");
const testing = std.testing;
const helpers = @import("helpers.zig");
const E2ETestContext = helpers.E2ETestContext;

// ============================================================================
// Test 1: API Handler Extraction
// ============================================================================

test "E2E Python: API handler constraint extraction" {
    var ctx = try E2ETestContext.init(testing.allocator);
    defer ctx.deinit();

    std.debug.print("\n=== E2E Python: API Handler Extraction ===\n", .{});

    const result = try ctx.runPipeline("test/e2e/fixtures/python/api_handler.py");
    defer {
        var mut_result = result;
        mut_result.deinit(testing.allocator);
    }

    // Should extract constraints from API handlers
    try testing.expect(result.constraints.constraints.items.len >= 5);

    std.debug.print("Extracted {} constraints from API handler\n", .{result.constraints.constraints.items.len});

    // Verify key constraint patterns
    var found_dataclass = false;
    var found_handler = false;
    var found_service = false;

    for (result.constraints.constraints.items) |constraint| {
        const name_lower = try std.ascii.allocLowerString(testing.allocator, constraint.name);
        defer testing.allocator.free(name_lower);

        if (std.mem.indexOf(u8, name_lower, "request") != null or
            std.mem.indexOf(u8, name_lower, "response") != null)
        {
            found_dataclass = true;
        }
        if (std.mem.indexOf(u8, name_lower, "handler") != null) {
            found_handler = true;
        }
        if (std.mem.indexOf(u8, name_lower, "service") != null or
            std.mem.indexOf(u8, name_lower, "user") != null)
        {
            found_service = true;
        }
    }

    try testing.expect(found_dataclass or found_handler or found_service);

    std.debug.print("✓ API handler constraints extracted successfully\n", .{});
}

// ============================================================================
// Test 2: Data Model Extraction
// ============================================================================

test "E2E Python: Data model constraint extraction" {
    var ctx = try E2ETestContext.init(testing.allocator);
    defer ctx.deinit();

    std.debug.print("\n=== E2E Python: Data Model Extraction ===\n", .{});

    const result = try ctx.runPipeline("test/e2e/fixtures/python/model.py");
    defer {
        var mut_result = result;
        mut_result.deinit(testing.allocator);
    }

    // Should extract model constraints
    try testing.expect(result.constraints.constraints.items.len >= 5);

    std.debug.print("Extracted {} constraints from models\n", .{result.constraints.constraints.items.len});

    // Verify model patterns
    var found_address = false;
    var found_user = false;
    var found_product = false;

    for (result.constraints.constraints.items) |constraint| {
        const name_lower = try std.ascii.allocLowerString(testing.allocator, constraint.name);
        defer testing.allocator.free(name_lower);

        if (std.mem.indexOf(u8, name_lower, "address") != null) {
            found_address = true;
        }
        if (std.mem.indexOf(u8, name_lower, "user") != null or
            std.mem.indexOf(u8, name_lower, "profile") != null)
        {
            found_user = true;
        }
        if (std.mem.indexOf(u8, name_lower, "product") != null or
            std.mem.indexOf(u8, name_lower, "order") != null)
        {
            found_product = true;
        }
    }

    try testing.expect(found_address or found_user or found_product);

    std.debug.print("✓ Data model constraints extracted successfully\n", .{});
}

// ============================================================================
// Test 3: Validation Extraction
// ============================================================================

test "E2E Python: Validation constraint extraction" {
    var ctx = try E2ETestContext.init(testing.allocator);
    defer ctx.deinit();

    std.debug.print("\n=== E2E Python: Validation Extraction ===\n", .{});

    const result = try ctx.runPipeline("test/e2e/fixtures/python/validation.py");
    defer {
        var mut_result = result;
        mut_result.deinit(testing.allocator);
    }

    // Should extract validation constraints
    try testing.expect(result.constraints.constraints.items.len >= 5);

    std.debug.print("Extracted {} validation constraints\n", .{result.constraints.constraints.items.len});

    // Check for validators
    var found_email = false;
    var found_phone = false;
    var found_date = false;

    for (result.constraints.constraints.items) |constraint| {
        const name_lower = try std.ascii.allocLowerString(testing.allocator, constraint.name);
        defer testing.allocator.free(name_lower);

        if (std.mem.indexOf(u8, name_lower, "email") != null) {
            found_email = true;
        }
        if (std.mem.indexOf(u8, name_lower, "phone") != null) {
            found_phone = true;
        }
        if (std.mem.indexOf(u8, name_lower, "date") != null or
            std.mem.indexOf(u8, name_lower, "range") != null)
        {
            found_date = true;
        }
    }

    try testing.expect(found_email or found_phone or found_date);

    std.debug.print("✓ Validation constraints extracted successfully\n", .{});
}

// ============================================================================
// Test 4: IR Compilation Validation
// ============================================================================

test "E2E Python: IR compilation produces valid output" {
    var ctx = try E2ETestContext.init(testing.allocator);
    defer ctx.deinit();

    std.debug.print("\n=== E2E Python: IR Compilation Validation ===\n", .{});

    const result = try ctx.runPipeline("test/e2e/fixtures/python/auth.py");
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
