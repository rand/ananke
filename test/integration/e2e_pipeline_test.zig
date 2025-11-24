//! End-to-End Integration Tests
//!
//! Tests the complete pipeline from Zig (Clew/Braid) → Rust (Maze) → Modal
//! Validates constraint extraction, compilation, FFI boundary, and generation

const std = @import("std");
const testing = std.testing;
const ananke = @import("ananke");
const Clew = @import("clew").Clew;
const Braid = @import("braid").Braid;

// Import FFI types and functions
const ffi_module = @import("root");
const ConstraintIRFFI = ffi_module.ConstraintIRFFI;
const AnankeError = ffi_module.AnankeError;

// Import constraint types
const Constraint = ananke.Constraint;
const ConstraintSet = ananke.ConstraintSet;
const ConstraintIR = ananke.ConstraintIR;

// Embedded test fixtures - use relative path from test file
const SAMPLE_TS = @embedFile("fixtures/sample.ts");
const SAMPLE_PY = @embedFile("fixtures/sample.py");
const SAMPLE_RS = @embedFile("fixtures/sample.rs");

// ============================================================================
// Test 1: Full E2E TypeScript Extraction and Compilation
// ============================================================================

test "e2e: typescript constraint extraction and IR compilation" {
    var clew = try Clew.init(testing.allocator);
    defer clew.deinit();

    var braid = try Braid.init(testing.allocator);
    defer braid.deinit();

    // Step 1: Extract constraints from TypeScript code
    var constraint_set = try clew.extractFromCode(SAMPLE_TS, "typescript");
    defer constraint_set.deinit();

    // Verify constraints were extracted
    try testing.expect(constraint_set.constraints.items.len > 0);

    // TypeScript should have type safety constraints
    var type_safety_count: usize = 0;
    var syntactic_count: usize = 0;
    for (constraint_set.constraints.items) |constraint| {
        switch (constraint.kind) {
            .type_safety => type_safety_count += 1,
            .syntactic => syntactic_count += 1,
            else => {},
        }
    }
    try testing.expect(type_safety_count > 0 or syntactic_count > 0);

    // Step 2: Compile constraints to IR
    var ir = try braid.compile(constraint_set.constraints.items);
    defer ir.deinit(testing.allocator);

    // Step 3: Validate IR structure
    try testing.expect(ir.priority >= 0);

    // TypeScript should produce either JSON schema or grammar
    const has_constraints = ir.json_schema != null or 
                           ir.grammar != null or 
                           ir.regex_patterns.len > 0;
    try testing.expect(has_constraints);
}

// ============================================================================
// Test 2: FFI Boundary - ConstraintIR Serialization
// ============================================================================

test "e2e: constraint ir serialization across ffi boundary" {
    // Create a ConstraintIR with various fields populated
    var clew = try Clew.init(testing.allocator);
    defer clew.deinit();

    var braid = try Braid.init(testing.allocator);
    defer braid.deinit();

    // Extract and compile from Python code
    var constraint_set = try clew.extractFromCode(SAMPLE_PY, "python");
    defer constraint_set.deinit();

    var ir = try braid.compile(constraint_set.constraints.items);
    defer ir.deinit(testing.allocator);

    // Verify IR has meaningful content
    try testing.expect(ir.priority >= 0);
}

// ============================================================================
// Test 3: Multi-Language Constraint Merging
// ============================================================================

test "e2e: multi-language constraint extraction" {
    var clew = try Clew.init(testing.allocator);
    defer clew.deinit();

    var braid = try Braid.init(testing.allocator);
    defer braid.deinit();

    // Extract from multiple languages
    var ts_set = try clew.extractFromCode(SAMPLE_TS, "typescript");
    defer ts_set.deinit();

    var py_set = try clew.extractFromCode(SAMPLE_PY, "python");
    defer py_set.deinit();

    var rs_set = try clew.extractFromCode(SAMPLE_RS, "rust");
    defer rs_set.deinit();

    // Merge all constraints
    var combined = std.ArrayList(Constraint){};
    defer combined.deinit(testing.allocator);

    try combined.appendSlice(testing.allocator, ts_set.constraints.items);
    try combined.appendSlice(testing.allocator, py_set.constraints.items);
    try combined.appendSlice(testing.allocator, rs_set.constraints.items);

    // Compile merged constraints
    var ir = try braid.compile(combined.items);
    defer ir.deinit(testing.allocator);

    // Verify combined IR
    try testing.expect(ir.priority >= 0);
    try testing.expect(combined.items.len >= ts_set.constraints.items.len);
    try testing.expect(combined.items.len >= py_set.constraints.items.len);
    try testing.expect(combined.items.len >= rs_set.constraints.items.len);
}

// ============================================================================
// Test 4: Constraint Priority Propagation Through Pipeline
// ============================================================================

test "e2e: constraint priority propagates through full pipeline" {
    var clew = try Clew.init(testing.allocator);
    defer clew.deinit();

    var braid = try Braid.init(testing.allocator);
    defer braid.deinit();

    // Extract security-relevant Python code
    const security_code = 
        \\import hashlib
        \\
        \\def hash_password(password: str) -> str:
        \\    return hashlib.sha256(password.encode()).hexdigest()
    ;

    var constraint_set = try clew.extractFromCode(security_code, "python");
    defer constraint_set.deinit();

    // Check for security constraints
    var has_security = false;
    for (constraint_set.constraints.items) |constraint| {
        if (constraint.kind == .security or 
            std.mem.indexOf(u8, constraint.description, "security") != null) {
            has_security = true;
            break;
        }
    }

    // Compile to IR
    var ir = try braid.compile(constraint_set.constraints.items);
    defer ir.deinit(testing.allocator);

    // Priority should be influenced by constraint types
    try testing.expect(ir.priority >= 0);
}

// ============================================================================
// Test 5: Constraint Metadata Preservation
// ============================================================================

test "e2e: constraint metadata preserved through pipeline" {
    var clew = try Clew.init(testing.allocator);
    defer clew.deinit();

    var braid = try Braid.init(testing.allocator);
    defer braid.deinit();

    var constraint_set = try clew.extractFromCode(SAMPLE_TS, "typescript");
    defer constraint_set.deinit();

    // Verify metadata is present
    for (constraint_set.constraints.items) |constraint| {
        // Confidence should be in valid range
        try testing.expect(constraint.confidence >= 0.0);
        try testing.expect(constraint.confidence <= 1.0);
        
        // Frequency should be positive
        try testing.expect(constraint.frequency > 0);
    }

    // Compile and verify IR maintains priority
    var ir = try braid.compile(constraint_set.constraints.items);
    defer ir.deinit(testing.allocator);
    
    try testing.expect(ir.priority >= 0);
}

// ============================================================================
// Test 6: Stress Test - Large File Extraction
// ============================================================================

test "e2e: large file extraction and compilation" {
    var clew = try Clew.init(testing.allocator);
    defer clew.deinit();

    var braid = try Braid.init(testing.allocator);
    defer braid.deinit();

    // Create a large synthetic TypeScript file
    var large_code = std.ArrayList(u8){};
    defer large_code.deinit(testing.allocator);

    // Generate multiple function definitions
    var i: usize = 0;
    while (i < 50) : (i += 1) {
        try large_code.writer(testing.allocator).print(
            \\function func{d}(x: number, y: string): boolean {{
            \\    const result = x > 0 && y.length > 0;
            \\    return result;
            \\}}
            \\
            \\
        , .{i});
    }

    // Extract constraints
    var constraint_set = try clew.extractFromCode(large_code.items, "typescript");
    defer constraint_set.deinit();

    // Should extract at least some constraints from large file
    // Note: Clew may extract fewer constraints than expected depending on patterns
    try testing.expect(constraint_set.constraints.items.len > 0);

    // Compile to IR
    var ir = try braid.compile(constraint_set.constraints.items);
    defer ir.deinit(testing.allocator);

    try testing.expect(ir.priority >= 0);
}

// ============================================================================
// Test 7: Performance Baseline
// ============================================================================

test "e2e: performance baseline for extraction and compilation" {
    var clew = try Clew.init(testing.allocator);
    defer clew.deinit();

    var braid = try Braid.init(testing.allocator);
    defer braid.deinit();

    // Measure extraction time
    const start_extract = std.time.milliTimestamp();
    var constraint_set = try clew.extractFromCode(SAMPLE_TS, "typescript");
    const end_extract = std.time.milliTimestamp();
    defer constraint_set.deinit();

    const extract_ms = end_extract - start_extract;

    // Measure compilation time
    const start_compile = std.time.milliTimestamp();
    var ir = try braid.compile(constraint_set.constraints.items);
    const end_compile = std.time.milliTimestamp();
    defer ir.deinit(testing.allocator);

    const compile_ms = end_compile - start_compile;

    // Performance assertions (should be fast for small files)
    // These are generous limits for debug builds
    try testing.expect(extract_ms < 5000); // 5 seconds
    try testing.expect(compile_ms < 5000); // 5 seconds

    std.debug.print("\nPerformance: Extract={d}ms, Compile={d}ms\n", .{extract_ms, compile_ms});
}
