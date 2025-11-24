// Integration Tests: Extract → Compile Pipeline
// Tests end-to-end workflow from Clew extraction to Braid compilation

const std = @import("std");
const testing = std.testing;
const ananke = @import("ananke");
const Clew = @import("clew").Clew;
const Braid = @import("braid").Braid;

// Import constraint types
const Constraint = ananke.Constraint;
const ConstraintSet = ananke.ConstraintSet;
const ConstraintIR = ananke.ConstraintIR;

// Embedded test fixtures
const SAMPLE_TS = @embedFile("fixtures/sample.ts");
const SAMPLE_PY = @embedFile("fixtures/sample.py");
const SAMPLE_RS = @embedFile("fixtures/sample.rs");
const SAMPLE_ZIG = @embedFile("fixtures/sample.zig.txt");

// ============================================================================
// Test 1: TypeScript extraction + compilation
// ============================================================================

test "integration: typescript extraction and compilation" {
    var clew = try Clew.init(testing.allocator);
    defer clew.deinit();

    var braid = try Braid.init(testing.allocator);
    defer braid.deinit();

    // Step 1: Extract constraints from TypeScript code
    var constraint_set = try clew.extractFromCode(SAMPLE_TS, "typescript");
    defer constraint_set.deinit();

    // Verify constraints were extracted
    try testing.expect(constraint_set.constraints.items.len > 0);

    // Step 2: Compile constraints to IR
    var ir = try braid.compile(constraint_set.constraints.items);
    defer ir.deinit(testing.allocator);

    // Step 3: Validate IR structure
    try testing.expect(ir.priority >= 0);

    // TypeScript should produce type safety constraints
    var has_type_constraint = false;
    for (constraint_set.constraints.items) |constraint| {
        if (constraint.kind == .type_safety) {
            has_type_constraint = true;
            break;
        }
    }
    try testing.expect(has_type_constraint);
}

// ============================================================================
// Test 2: Python extraction + compilation
// ============================================================================

test "integration: python extraction and compilation" {
    var clew = try Clew.init(testing.allocator);
    defer clew.deinit();

    var braid = try Braid.init(testing.allocator);
    defer braid.deinit();

    // Step 1: Extract constraints from Python code
    var constraint_set = try clew.extractFromCode(SAMPLE_PY, "python");
    defer constraint_set.deinit();

    // Verify constraints were extracted
    try testing.expect(constraint_set.constraints.items.len > 0);

    // Step 2: Compile constraints to IR
    var ir = try braid.compile(constraint_set.constraints.items);
    defer ir.deinit(testing.allocator);

    // Step 3: Validate IR structure
    try testing.expect(ir.priority >= 0);

    // Verify at least one syntactic constraint exists
    var has_syntactic = false;
    for (constraint_set.constraints.items) |constraint| {
        if (constraint.kind == .syntactic) {
            has_syntactic = true;
            break;
        }
    }
    try testing.expect(has_syntactic);
}

// ============================================================================
// Test 3: Rust extraction + compilation
// ============================================================================

test "integration: rust extraction and compilation" {
    var clew = try Clew.init(testing.allocator);
    defer clew.deinit();

    var braid = try Braid.init(testing.allocator);
    defer braid.deinit();

    // Step 1: Extract constraints from Rust code
    var constraint_set = try clew.extractFromCode(SAMPLE_RS, "rust");
    defer constraint_set.deinit();

    // Verify constraints were extracted
    try testing.expect(constraint_set.constraints.items.len > 0);

    // Step 2: Compile constraints to IR
    var ir = try braid.compile(constraint_set.constraints.items);
    defer ir.deinit(testing.allocator);

    // Step 3: Validate IR structure
    try testing.expect(ir.priority >= 0);

    // Rust typically has strong type annotations
    var type_annotation_count: usize = 0;
    for (constraint_set.constraints.items) |constraint| {
        if (constraint.kind == .type_safety) {
            type_annotation_count += 1;
        }
    }
    // At least one type safety constraint expected
    try testing.expect(type_annotation_count > 0);
}

// ============================================================================
// Test 4: Zig extraction + compilation
// ============================================================================

test "integration: zig extraction and compilation" {
    var clew = try Clew.init(testing.allocator);
    defer clew.deinit();

    var braid = try Braid.init(testing.allocator);
    defer braid.deinit();

    // Step 1: Extract constraints from Zig code
    var constraint_set = try clew.extractFromCode(SAMPLE_ZIG, "zig");
    defer constraint_set.deinit();

    // Verify constraints were extracted
    try testing.expect(constraint_set.constraints.items.len > 0);

    // Step 2: Compile constraints to IR
    var ir = try braid.compile(constraint_set.constraints.items);
    defer ir.deinit(testing.allocator);

    // Step 3: Validate IR structure
    try testing.expect(ir.priority >= 0);

    // Zig has explicit error handling patterns
    var error_pattern_found = false;
    for (constraint_set.constraints.items) |constraint| {
        if (std.mem.indexOf(u8, constraint.description, "error") != null) {
            error_pattern_found = true;
            break;
        }
    }
    try testing.expect(error_pattern_found);
}

// ============================================================================
// Test 5: Invalid code handling
// ============================================================================

test "integration: invalid code error propagation" {
    var clew = try Clew.init(testing.allocator);
    defer clew.deinit();

    var braid = try Braid.init(testing.allocator);
    defer braid.deinit();

    const invalid_code = "function broken(: { })";

    // Clew should handle malformed input gracefully
    var constraint_set = try clew.extractFromCode(invalid_code, "typescript");
    defer constraint_set.deinit();

    // Even with invalid code, we should get some constraints (or none)
    // The key is that it doesn't crash
    try testing.expect(constraint_set.constraints.items.len >= 0);

    // Compile whatever constraints we got (even if empty)
    var ir = try braid.compile(constraint_set.constraints.items);
    defer ir.deinit(testing.allocator);
    try testing.expect(ir.priority >= 0);
}

// ============================================================================
// Test 6: Empty constraint set handling
// ============================================================================

test "integration: empty constraint set compilation" {
    var braid = try Braid.init(testing.allocator);
    defer braid.deinit();

    // Create empty constraint array
    const empty_constraints: []const Constraint = &.{};

    // Braid should handle empty constraint sets gracefully
    var ir = try braid.compile(empty_constraints);
    defer ir.deinit(testing.allocator);

    // Verify IR is in valid state
    try testing.expect(ir.priority == 0);
    try testing.expect(ir.json_schema == null);
    try testing.expect(ir.grammar == null);
    try testing.expectEqual(@as(usize, 0), ir.regex_patterns.len);
    try testing.expect(ir.token_masks == null);
}

// ============================================================================
// Test 7: Multi-language constraint merging
// ============================================================================

test "integration: multi-language constraint extraction and merging" {
    var clew = try Clew.init(testing.allocator);
    defer clew.deinit();

    var braid = try Braid.init(testing.allocator);
    defer braid.deinit();

    // Extract from multiple languages
    var ts_set = try clew.extractFromCode(SAMPLE_TS, "typescript");
    defer ts_set.deinit();

    var py_set = try clew.extractFromCode(SAMPLE_PY, "python");
    defer py_set.deinit();

    // Merge constraint sets
    var combined = std.ArrayList(Constraint){};
    defer combined.deinit(testing.allocator);

    for (ts_set.constraints.items) |constraint| {
        try combined.append(testing.allocator, constraint);
    }

    for (py_set.constraints.items) |constraint| {
        try combined.append(testing.allocator, constraint);
    }

    // Compile merged constraints
    var ir = try braid.compile(combined.items);
    defer ir.deinit(testing.allocator);

    // Verify combined IR
    try testing.expect(ir.priority >= 0);
    try testing.expect(combined.items.len > ts_set.constraints.items.len);
    try testing.expect(combined.items.len > py_set.constraints.items.len);
}

// ============================================================================
// Test 8: llguidance schema generation
// ============================================================================

test "integration: llguidance schema generation from constraints" {
    var clew = try Clew.init(testing.allocator);
    defer clew.deinit();

    var braid = try Braid.init(testing.allocator);
    defer braid.deinit();

    // Extract constraints
    var constraint_set = try clew.extractFromCode(SAMPLE_TS, "typescript");
    defer constraint_set.deinit();

    // Compile to IR
    var ir = try braid.compile(constraint_set.constraints.items);
    defer ir.deinit(testing.allocator);

    // Generate llguidance schema
    const schema = try braid.toLLGuidanceSchema(ir);
    defer testing.allocator.free(schema);

    // Verify schema is valid JSON-like format
    try testing.expect(schema.len > 0);
    try testing.expect(std.mem.indexOf(u8, schema, "\"type\"") != null);
    try testing.expect(std.mem.indexOf(u8, schema, "guidance") != null);
}

// ============================================================================
// Test 9: Constraint priority propagation
// ============================================================================

test "integration: constraint priority affects IR priority" {
    var braid = try Braid.init(testing.allocator);
    defer braid.deinit();

    // Create constraints with different severities
    var constraints = std.ArrayList(Constraint){};
    defer constraints.deinit(testing.allocator);

    const critical_constraint = Constraint{
        .id = 1,
        .kind = .security,
        .severity = .err, // Critical severity
        .name = "critical_security",
        .description = "Critical security constraint",
        .source = .User_Defined,
        .enforcement = .Security,
        .priority = .Critical,
        .confidence = 1.0,
        .frequency = 1,
        .created_at = 0,
        .origin_file = null,
        .origin_line = null,
        .validate = null,
        .compile_fn = null,
    };

    try constraints.append(testing.allocator, critical_constraint);

    // Compile
    var ir = try braid.compile(constraints.items);
    defer ir.deinit(testing.allocator);

    // IR priority should reflect critical constraint
    try testing.expect(ir.priority > 0);
}

// ============================================================================
// Test 10: Memory safety across pipeline
// ============================================================================

test "integration: no memory leaks in full pipeline" {
    // Use GPA to detect leaks
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked == .leak) {
            @panic("Memory leak detected!");
        }
    }
    const allocator = gpa.allocator();

    var clew = try Clew.init(allocator);
    defer clew.deinit();

    var braid = try Braid.init(allocator);
    defer braid.deinit();

    // Run extraction and compilation multiple times
    var i: usize = 0;
    while (i < 3) : (i += 1) {
        var constraint_set = try clew.extractFromCode(SAMPLE_TS, "typescript");
        defer constraint_set.deinit();

        var ir = try braid.compile(constraint_set.constraints.items);
        defer ir.deinit(allocator);
    }

    // If we reach here without panic, no leaks detected
}

// ============================================================================
// Test 11: Constraint frequency aggregation
// ============================================================================

test "integration: constraint frequency is tracked during extraction" {
    var clew = try Clew.init(testing.allocator);
    defer clew.deinit();

    // Extract from TypeScript with multiple function patterns
    var constraint_set = try clew.extractFromCode(SAMPLE_TS, "typescript");
    defer constraint_set.deinit();

    // Find function-related constraints
    for (constraint_set.constraints.items) |constraint| {
        if (std.mem.indexOf(u8, constraint.name, "function") != null) {
            // Function constraints should have frequency > 0
            try testing.expect(constraint.frequency > 0);
        }
    }
}

// ============================================================================
// Test 12: Constraint source tracking
// ============================================================================

test "integration: constraint sources are properly tracked" {
    var clew = try Clew.init(testing.allocator);
    defer clew.deinit();

    var constraint_set = try clew.extractFromCode(SAMPLE_ZIG, "zig");
    defer constraint_set.deinit();

    // All extracted constraints should have a valid source
    for (constraint_set.constraints.items) |constraint| {
        // Source should be one of the extraction sources
        const is_valid_source =
            constraint.source == .AST_Pattern or
            constraint.source == .Type_System or
            constraint.source == .Control_Flow or
            constraint.source == .LLM_Analysis;

        try testing.expect(is_valid_source);
    }
}
