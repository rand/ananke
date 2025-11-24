// Pattern Extraction Tests
// Tests comprehensive pattern-based constraint extraction for 4 languages

const std = @import("std");
const testing = std.testing;

// Import Clew and related types
const clew = @import("clew");
const Clew = clew.Clew;

// ============================================================================
// TypeScript Pattern Extraction Tests
// ============================================================================

test "TypeScript: Extract function declarations" {
    const allocator = testing.allocator;

    // Read TypeScript sample file
    const ts_source = @embedFile("fixtures/sample.ts");

    var engine = try Clew.init(allocator);
    defer engine.deinit();

    var constraint_set = try engine.extractFromCode(ts_source, "typescript");
    defer constraint_set.deinit();

    // Verify we found function-related constraints
    var found_function = false;
    var found_async = false;

    for (constraint_set.constraints.items) |constraint| {
        if (std.mem.indexOf(u8, constraint.name, "function") != null) {
            found_function = true;
        }
        if (std.mem.indexOf(u8, constraint.name, "async") != null or
            std.mem.indexOf(u8, constraint.name, "Async") != null)
        {
            found_async = true;
        }
    }

    try testing.expect(found_function);
    try testing.expect(found_async);

    // Should have extracted multiple constraints (aiming for 80% coverage)
    try testing.expect(constraint_set.constraints.items.len >= 5);
}

test "TypeScript: Extract type annotations" {
    const allocator = testing.allocator;

    const ts_source = @embedFile("fixtures/sample.ts");

    var engine = try Clew.init(allocator);
    defer engine.deinit();

    var constraint_set = try engine.extractFromCode(ts_source, "typescript");
    defer constraint_set.deinit();

    // Verify we found type-related constraints
    var found_type = false;
    var found_interface = false;

    for (constraint_set.constraints.items) |constraint| {
        if (std.mem.indexOf(u8, constraint.name, "type") != null or
            std.mem.indexOf(u8, constraint.name, "Type") != null)
        {
            found_type = true;
        }
        if (std.mem.indexOf(u8, constraint.name, "Interface") != null or
            std.mem.indexOf(u8, constraint.name, "interface") != null)
        {
            found_interface = true;
        }
    }

    try testing.expect(found_type);
    try testing.expect(found_interface);
}

test "TypeScript: Extract async patterns" {
    const allocator = testing.allocator;

    const ts_source = @embedFile("fixtures/sample.ts");

    var engine = try Clew.init(allocator);
    defer engine.deinit();

    var constraint_set = try engine.extractFromCode(ts_source, "typescript");
    defer constraint_set.deinit();

    // Verify async patterns were detected
    var found_async_pattern = false;

    for (constraint_set.constraints.items) |constraint| {
        if (constraint.kind == .semantic and
            (std.mem.indexOf(u8, constraint.name, "async") != null or
                std.mem.indexOf(u8, constraint.name, "Async") != null))
        {
            found_async_pattern = true;
            break;
        }
    }

    try testing.expect(found_async_pattern);
}

// ============================================================================
// Python Pattern Extraction Tests
// ============================================================================

test "Python: Extract function declarations" {
    const allocator = testing.allocator;

    const py_source = @embedFile("fixtures/sample.py");

    var engine = try Clew.init(allocator);
    defer engine.deinit();

    var constraint_set = try engine.extractFromCode(py_source, "python");
    defer constraint_set.deinit();

    // Verify we found function-related constraints
    var found_function = false;
    var found_async_def = false;

    for (constraint_set.constraints.items) |constraint| {
        if (std.mem.indexOf(u8, constraint.name, "function") != null or
            std.mem.indexOf(u8, constraint.name, "Function") != null)
        {
            found_function = true;
        }
        if (std.mem.indexOf(u8, constraint.name, "Async") != null or
            std.mem.indexOf(u8, constraint.name, "async") != null)
        {
            found_async_def = true;
        }
    }

    try testing.expect(found_function);
    try testing.expect(found_async_def);

    // Should have extracted multiple constraints
    try testing.expect(constraint_set.constraints.items.len >= 5);
}

test "Python: Extract type hints" {
    const allocator = testing.allocator;

    const py_source = @embedFile("fixtures/sample.py");

    var engine = try Clew.init(allocator);
    defer engine.deinit();

    var constraint_set = try engine.extractFromCode(py_source, "python");
    defer constraint_set.deinit();

    // Verify type hints were detected
    var found_type = false;

    for (constraint_set.constraints.items) |constraint| {
        if (constraint.kind == .type_safety) {
            found_type = true;
            break;
        }
    }

    try testing.expect(found_type);
}

test "Python: Extract decorators and error handling" {
    const allocator = testing.allocator;

    const py_source = @embedFile("fixtures/sample.py");

    var engine = try Clew.init(allocator);
    defer engine.deinit();

    var constraint_set = try engine.extractFromCode(py_source, "python");
    defer constraint_set.deinit();

    // Verify decorator and error handling patterns
    var found_decorator = false;
    var found_error = false;

    for (constraint_set.constraints.items) |constraint| {
        if (std.mem.indexOf(u8, constraint.name, "Decorator") != null or
            std.mem.indexOf(u8, constraint.name, "decorator") != null)
        {
            found_decorator = true;
        }
        if (std.mem.indexOf(u8, constraint.name, "error") != null or
            std.mem.indexOf(u8, constraint.name, "Error") != null or
            std.mem.indexOf(u8, constraint.name, "exception") != null)
        {
            found_error = true;
        }
    }

    try testing.expect(found_decorator);
    try testing.expect(found_error);
}

// ============================================================================
// Rust Pattern Extraction Tests
// ============================================================================

test "Rust: Extract function declarations" {
    const allocator = testing.allocator;

    const rust_source = @embedFile("fixtures/sample.rs");

    var engine = try Clew.init(allocator);
    defer engine.deinit();

    var constraint_set = try engine.extractFromCode(rust_source, "rust");
    defer constraint_set.deinit();

    // Verify function patterns
    var found_function = false;
    var found_pub_fn = false;

    for (constraint_set.constraints.items) |constraint| {
        if (std.mem.indexOf(u8, constraint.name, "function") != null or
            std.mem.indexOf(u8, constraint.name, "Function") != null)
        {
            found_function = true;
        }
        if (std.mem.indexOf(u8, constraint.name, "Public function") != null) {
            found_pub_fn = true;
        }
    }

    try testing.expect(found_function);
    // Should have extracted multiple constraints
    try testing.expect(constraint_set.constraints.items.len >= 5);
}

test "Rust: Extract Result and Option types" {
    const allocator = testing.allocator;

    const rust_source = @embedFile("fixtures/sample.rs");

    var engine = try Clew.init(allocator);
    defer engine.deinit();

    var constraint_set = try engine.extractFromCode(rust_source, "rust");
    defer constraint_set.deinit();

    // Verify Result/Option type detection
    var found_result = false;
    var found_option = false;

    for (constraint_set.constraints.items) |constraint| {
        if (std.mem.indexOf(u8, constraint.name, "Result") != null) {
            found_result = true;
        }
        if (std.mem.indexOf(u8, constraint.name, "Option") != null) {
            found_option = true;
        }
    }

    try testing.expect(found_result);
    try testing.expect(found_option);
}

test "Rust: Extract ownership patterns and traits" {
    const allocator = testing.allocator;

    const rust_source = @embedFile("fixtures/sample.rs");

    var engine = try Clew.init(allocator);
    defer engine.deinit();

    var constraint_set = try engine.extractFromCode(rust_source, "rust");
    defer constraint_set.deinit();

    // Verify ownership and trait patterns
    var found_reference = false;
    var found_trait = false;

    for (constraint_set.constraints.items) |constraint| {
        if (std.mem.indexOf(u8, constraint.name, "reference") != null or
            std.mem.indexOf(u8, constraint.name, "Reference") != null)
        {
            found_reference = true;
        }
        if (std.mem.indexOf(u8, constraint.name, "Trait") != null or
            std.mem.indexOf(u8, constraint.name, "trait") != null or
            std.mem.indexOf(u8, constraint.name, "impl") != null)
        {
            found_trait = true;
        }
    }

    try testing.expect(found_reference);
    try testing.expect(found_trait);
}

// ============================================================================
// Zig Pattern Extraction Tests
// ============================================================================

test "Zig: Extract function declarations" {
    const allocator = testing.allocator;

    const zig_source = @embedFile("fixtures/sample.zig.txt");

    var engine = try Clew.init(allocator);
    defer engine.deinit();

    var constraint_set = try engine.extractFromCode(zig_source, "zig");
    defer constraint_set.deinit();

    // Verify function patterns
    var found_function = false;
    var found_pub_fn = false;

    for (constraint_set.constraints.items) |constraint| {
        if (std.mem.indexOf(u8, constraint.name, "function") != null or
            std.mem.indexOf(u8, constraint.name, "Function") != null)
        {
            found_function = true;
        }
        if (std.mem.indexOf(u8, constraint.name, "Public function") != null) {
            found_pub_fn = true;
        }
    }

    try testing.expect(found_function);
    try testing.expect(found_pub_fn);

    // Should have extracted multiple constraints
    try testing.expect(constraint_set.constraints.items.len >= 5);
}

test "Zig: Extract error union types" {
    const allocator = testing.allocator;

    const zig_source = @embedFile("fixtures/sample.zig.txt");

    var engine = try Clew.init(allocator);
    defer engine.deinit();

    var constraint_set = try engine.extractFromCode(zig_source, "zig");
    defer constraint_set.deinit();

    // Verify error union and try/catch patterns
    var found_error_union = false;
    var found_try = false;

    for (constraint_set.constraints.items) |constraint| {
        if (std.mem.indexOf(u8, constraint.name, "Error") != null or
            std.mem.indexOf(u8, constraint.name, "error") != null)
        {
            found_error_union = true;
        }
        if (std.mem.indexOf(u8, constraint.name, "Try") != null or
            std.mem.indexOf(u8, constraint.name, "try") != null)
        {
            found_try = true;
        }
    }

    try testing.expect(found_error_union);
    try testing.expect(found_try);
}

test "Zig: Extract memory management patterns" {
    const allocator = testing.allocator;

    const zig_source = @embedFile("fixtures/sample.zig.txt");

    var engine = try Clew.init(allocator);
    defer engine.deinit();

    var constraint_set = try engine.extractFromCode(zig_source, "zig");
    defer constraint_set.deinit();

    // Verify memory management patterns
    var found_allocator = false;
    var found_defer = false;

    for (constraint_set.constraints.items) |constraint| {
        if (std.mem.indexOf(u8, constraint.name, "Allocator") != null or
            std.mem.indexOf(u8, constraint.name, "allocator") != null or
            std.mem.indexOf(u8, constraint.name, "alloc") != null)
        {
            found_allocator = true;
        }
        if (std.mem.indexOf(u8, constraint.name, "Defer") != null or
            std.mem.indexOf(u8, constraint.name, "defer") != null)
        {
            found_defer = true;
        }
    }

    try testing.expect(found_allocator);
    try testing.expect(found_defer);
}

// ============================================================================
// Cross-Language Pattern Tests
// ============================================================================

test "Pattern coverage: TypeScript achieves 80% constraint extraction" {
    const allocator = testing.allocator;

    const ts_source = @embedFile("fixtures/sample.ts");

    // Count expected patterns in the source manually
    // Expected: async, function, import, interface, class, Promise, try/catch, decorators
    const expected_pattern_categories: u32 = 8;

    var engine = try Clew.init(allocator);
    defer engine.deinit();

    var constraint_set = try engine.extractFromCode(ts_source, "typescript");
    defer constraint_set.deinit();

    // Count unique constraint kinds found
    var kinds_found = std.StringHashMap(void).init(allocator);
    defer kinds_found.deinit();

    for (constraint_set.constraints.items) |constraint| {
        try kinds_found.put(constraint.name, {});
    }

    const coverage_ratio = @as(f32, @floatFromInt(kinds_found.count())) /
        @as(f32, @floatFromInt(expected_pattern_categories));

    // Should achieve at least 80% coverage
    try testing.expect(coverage_ratio >= 0.8);
}

test "Pattern coverage: All languages extract similar constraint counts" {
    const allocator = testing.allocator;

    const ts_source = @embedFile("fixtures/sample.ts");
    const py_source = @embedFile("fixtures/sample.py");
    const rust_source = @embedFile("fixtures/sample.rs");
    const zig_source = @embedFile("fixtures/sample.zig.txt");

    var engine = try Clew.init(allocator);
    defer engine.deinit();

    var ts_set = try engine.extractFromCode(ts_source, "typescript");
    defer ts_set.deinit();

    var py_set = try engine.extractFromCode(py_source, "python");
    defer py_set.deinit();

    var rust_set = try engine.extractFromCode(rust_source, "rust");
    defer rust_set.deinit();

    var zig_set = try engine.extractFromCode(zig_source, "zig");
    defer zig_set.deinit();

    // Each language should extract at least 5 constraints
    try testing.expect(ts_set.constraints.items.len >= 5);
    try testing.expect(py_set.constraints.items.len >= 5);
    try testing.expect(rust_set.constraints.items.len >= 5);
    try testing.expect(zig_set.constraints.items.len >= 5);
}
