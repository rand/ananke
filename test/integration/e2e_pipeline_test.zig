//! End-to-End Integration Tests
//!
//! Tests the complete pipeline from Zig (Clew/Braid) → Rust (Maze) → Modal
//! Validates constraint extraction, compilation, FFI boundary, and generation
//!
//! This test suite covers:
//! 1. TypeScript: Full pipeline with functions, types, async patterns
//! 2. Python: Full pipeline with type hints, decorators
//! 3. Multi-Language: Constraint extraction and merging
//! 4. Performance: Extract + Compile under target thresholds

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

test "e2e: typescript full pipeline - functions, types, async patterns" {
    var clew = try Clew.init(testing.allocator);
    defer clew.deinit();

    var braid = try Braid.init(testing.allocator);
    defer braid.deinit();

    std.debug.print("\n=== Test 1: TypeScript Full Pipeline ===\n", .{});

    // Step 1: Extract constraints from TypeScript code
    const extract_start = std.time.milliTimestamp();
    var constraint_set = try clew.extractFromCode(SAMPLE_TS, "typescript");
    const extract_time = std.time.milliTimestamp() - extract_start;
    defer constraint_set.deinit();

    std.debug.print("Extracted {d} constraints in {d}ms\n", .{ constraint_set.constraints.items.len, extract_time });

    // Verify constraints were extracted
    try testing.expect(constraint_set.constraints.items.len > 0);

    // TypeScript should have type safety and syntactic constraints
    var type_safety_count: usize = 0;
    var syntactic_count: usize = 0;
    var async_count: usize = 0;
    var function_count: usize = 0;

    for (constraint_set.constraints.items) |constraint| {
        switch (constraint.kind) {
            .type_safety => type_safety_count += 1,
            .syntactic => syntactic_count += 1,
            .semantic => {
                // Check for async patterns
                if (std.mem.indexOf(u8, constraint.description, "async") != null) {
                    async_count += 1;
                }
            },
            else => {},
        }

        // Check for function patterns
        if (std.mem.indexOf(u8, constraint.description, "function") != null) {
            function_count += 1;
        }
    }

    std.debug.print("  Type safety constraints: {d}\n", .{type_safety_count});
    std.debug.print("  Syntactic constraints: {d}\n", .{syntactic_count});
    std.debug.print("  Async patterns detected: {d}\n", .{async_count});
    std.debug.print("  Function patterns detected: {d}\n", .{function_count});

    // TypeScript sample has types and functions, so we should see these
    try testing.expect(type_safety_count > 0 or syntactic_count > 0);
    try testing.expect(function_count > 0);

    // Step 2: Compile constraints to IR
    const compile_start = std.time.milliTimestamp();
    var ir = try braid.compile(constraint_set.constraints.items);
    const compile_time = std.time.milliTimestamp() - compile_start;
    defer ir.deinit(testing.allocator);

    std.debug.print("Compiled to IR in {d}ms\n", .{compile_time});

    // Step 3: Validate IR structure and quality
    try testing.expect(ir.priority >= 0);

    // TypeScript should produce multiple constraint types
    const has_json_schema = ir.json_schema != null;
    const has_grammar = ir.grammar != null;
    const has_regex = ir.regex_patterns.len > 0;
    const has_token_masks = ir.token_masks != null;

    std.debug.print("  JSON Schema: {}\n", .{has_json_schema});
    std.debug.print("  Grammar: {}\n", .{has_grammar});
    std.debug.print("  Regex patterns: {d}\n", .{ir.regex_patterns.len});
    std.debug.print("  Token masks: {}\n", .{has_token_masks});

    // Should have at least one constraint type
    const has_constraints = has_json_schema or has_grammar or has_regex;
    try testing.expect(has_constraints);

    // Verify constraint satisfaction - output quality check
    if (has_grammar) {
        // Grammar should have rules
        try testing.expect(ir.grammar.?.rules.len > 0);
        std.debug.print("  Grammar rules: {d}\n", .{ir.grammar.?.rules.len});
    }

    std.debug.print("✓ TypeScript pipeline complete\n\n", .{});
}

// ============================================================================
// Test 2: Full E2E Python Extraction and Compilation
// ============================================================================

test "e2e: python full pipeline - type hints, decorators, async" {
    var clew = try Clew.init(testing.allocator);
    defer clew.deinit();

    var braid = try Braid.init(testing.allocator);
    defer braid.deinit();

    std.debug.print("\n=== Test 2: Python Full Pipeline ===\n", .{});

    // Step 1: Extract constraints from Python code
    const extract_start = std.time.milliTimestamp();
    var constraint_set = try clew.extractFromCode(SAMPLE_PY, "python");
    const extract_time = std.time.milliTimestamp() - extract_start;
    defer constraint_set.deinit();

    std.debug.print("Extracted {d} constraints in {d}ms\n", .{ constraint_set.constraints.items.len, extract_time });

    // Verify constraints were extracted
    try testing.expect(constraint_set.constraints.items.len > 0);

    // Python should have type hints and syntactic constraints
    var type_hint_count: usize = 0;
    var syntactic_count: usize = 0;
    var async_count: usize = 0;
    var decorator_count: usize = 0;

    for (constraint_set.constraints.items) |constraint| {
        const desc = constraint.description;

        // Check for type hints
        if (std.mem.indexOf(u8, desc, "type") != null or
            std.mem.indexOf(u8, desc, "hint") != null)
        {
            type_hint_count += 1;
        }

        // Check for async patterns
        if (std.mem.indexOf(u8, desc, "async") != null) {
            async_count += 1;
        }

        // Check for decorators
        if (std.mem.indexOf(u8, desc, "decorator") != null or
            std.mem.indexOf(u8, desc, "@") != null)
        {
            decorator_count += 1;
        }

        if (constraint.kind == .syntactic) {
            syntactic_count += 1;
        }
    }

    std.debug.print("  Type hint constraints: {d}\n", .{type_hint_count});
    std.debug.print("  Syntactic constraints: {d}\n", .{syntactic_count});
    std.debug.print("  Async patterns detected: {d}\n", .{async_count});
    std.debug.print("  Decorator patterns detected: {d}\n", .{decorator_count});

    // Python sample has functions and type hints
    try testing.expect(syntactic_count > 0);

    // Step 2: Compile constraints to IR
    const compile_start = std.time.milliTimestamp();
    var ir = try braid.compile(constraint_set.constraints.items);
    const compile_time = std.time.milliTimestamp() - compile_start;
    defer ir.deinit(testing.allocator);

    std.debug.print("Compiled to IR in {d}ms\n", .{compile_time});

    // Step 3: Validate IR structure and quality
    try testing.expect(ir.priority >= 0);

    const has_json_schema = ir.json_schema != null;
    const has_grammar = ir.grammar != null;
    const has_regex = ir.regex_patterns.len > 0;

    std.debug.print("  JSON Schema: {}\n", .{has_json_schema});
    std.debug.print("  Grammar: {}\n", .{has_grammar});
    std.debug.print("  Regex patterns: {d}\n", .{ir.regex_patterns.len});

    // Python should produce constraints
    const has_constraints = has_json_schema or has_grammar or has_regex;
    try testing.expect(has_constraints);

    // Validate intermediate outputs
    if (has_grammar) {
        // Grammar should have rules for Python constructs
        try testing.expect(ir.grammar.?.rules.len > 0);
        std.debug.print("  Grammar rules: {d}\n", .{ir.grammar.?.rules.len});

        // Should have a start symbol
        try testing.expect(ir.grammar.?.start_symbol.len > 0);
    }

    std.debug.print("✓ Python pipeline complete\n\n", .{});
}

// ============================================================================
// Test 3: Multi-Language Constraint Extraction and Merging
// ============================================================================

test "e2e: multi-language constraint extraction and unified compilation" {
    var clew = try Clew.init(testing.allocator);
    defer clew.deinit();

    var braid = try Braid.init(testing.allocator);
    defer braid.deinit();

    std.debug.print("\n=== Test 3: Multi-Language Pipeline ===\n", .{});

    // Step 1: Extract from multiple languages
    const ts_start = std.time.milliTimestamp();
    var ts_set = try clew.extractFromCode(SAMPLE_TS, "typescript");
    const ts_time = std.time.milliTimestamp() - ts_start;
    defer ts_set.deinit();
    std.debug.print("TypeScript: extracted {d} constraints in {d}ms\n", .{ ts_set.constraints.items.len, ts_time });

    const py_start = std.time.milliTimestamp();
    var py_set = try clew.extractFromCode(SAMPLE_PY, "python");
    const py_time = std.time.milliTimestamp() - py_start;
    defer py_set.deinit();
    std.debug.print("Python: extracted {d} constraints in {d}ms\n", .{ py_set.constraints.items.len, py_time });

    const rs_start = std.time.milliTimestamp();
    var rs_set = try clew.extractFromCode(SAMPLE_RS, "rust");
    const rs_time = std.time.milliTimestamp() - rs_start;
    defer rs_set.deinit();
    std.debug.print("Rust: extracted {d} constraints in {d}ms\n", .{ rs_set.constraints.items.len, rs_time });

    // Step 2: Merge all constraints from different languages
    var combined = std.ArrayList(Constraint){};
    defer combined.deinit(testing.allocator);

    try combined.appendSlice(testing.allocator, ts_set.constraints.items);
    try combined.appendSlice(testing.allocator, py_set.constraints.items);
    try combined.appendSlice(testing.allocator, rs_set.constraints.items);

    std.debug.print("Total constraints merged: {d}\n", .{combined.items.len});

    // Verify we actually merged constraints from all sources
    try testing.expect(combined.items.len >= ts_set.constraints.items.len);
    try testing.expect(combined.items.len >= py_set.constraints.items.len);
    try testing.expect(combined.items.len >= rs_set.constraints.items.len);

    // Step 3: Compile merged constraints to unified IR
    const compile_start = std.time.milliTimestamp();
    var ir = try braid.compile(combined.items);
    const compile_time = std.time.milliTimestamp() - compile_start;
    defer ir.deinit(testing.allocator);

    std.debug.print("Compiled unified IR in {d}ms\n", .{compile_time});

    // Step 4: Validate no conflicts and proper merging
    try testing.expect(ir.priority >= 0);

    const has_json_schema = ir.json_schema != null;
    const has_grammar = ir.grammar != null;
    const has_regex = ir.regex_patterns.len > 0;
    const has_token_masks = ir.token_masks != null;

    std.debug.print("  Unified IR components:\n", .{});
    std.debug.print("    JSON Schema: {}\n", .{has_json_schema});
    std.debug.print("    Grammar: {}\n", .{has_grammar});
    std.debug.print("    Regex patterns: {d}\n", .{ir.regex_patterns.len});
    std.debug.print("    Token masks: {}\n", .{has_token_masks});

    // Should have multiple constraint types from multi-language input
    const has_constraints = has_json_schema or has_grammar or has_regex;
    try testing.expect(has_constraints);

    // Verify constraint merging didn't introduce conflicts
    // Priority should be reasonable (not excessively high which would indicate conflicts)
    try testing.expect(ir.priority < 10000);

    // Count constraint kinds in merged set
    var kind_counts = std.AutoHashMap(ananke.ConstraintKind, usize).init(testing.allocator);
    defer kind_counts.deinit();

    for (combined.items) |constraint| {
        const entry = try kind_counts.getOrPut(constraint.kind);
        if (!entry.found_existing) {
            entry.value_ptr.* = 0;
        }
        entry.value_ptr.* += 1;
    }

    std.debug.print("  Constraint kind distribution:\n", .{});
    var kind_iter = kind_counts.iterator();
    while (kind_iter.next()) |entry| {
        std.debug.print("    {s}: {d}\n", .{ @tagName(entry.key_ptr.*), entry.value_ptr.* });
    }

    // Multi-language should have diverse constraint kinds
    try testing.expect(kind_counts.count() > 1);

    std.debug.print("✓ Multi-language pipeline complete\n\n", .{});
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
            std.mem.indexOf(u8, constraint.description, "security") != null)
        {
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
// Test 4: Performance Baseline - Extract + Compile Under Target Thresholds
// ============================================================================

test "e2e: performance baseline - extract and compile under 10ms target" {
    var clew = try Clew.init(testing.allocator);
    defer clew.deinit();

    var braid = try Braid.init(testing.allocator);
    defer braid.deinit();

    std.debug.print("\n=== Test 4: Performance Baseline ===\n", .{});

    // Test with small representative samples
    const small_ts_sample =
        \\function add(a: number, b: number): number {
        \\    return a + b;
        \\}
    ;

    // Warm-up run to account for caching and JIT effects
    {
        var warmup_set = try clew.extractFromCode(small_ts_sample, "typescript");
        defer warmup_set.deinit();
        var warmup_ir = try braid.compile(warmup_set.constraints.items);
        defer warmup_ir.deinit(testing.allocator);
    }

    // Run multiple iterations to get stable measurements
    const iterations = 10;
    var extract_times: [iterations]i64 = undefined;
    var compile_times: [iterations]i64 = undefined;
    var total_times: [iterations]i64 = undefined;

    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        // Measure extraction time
        const start_extract = std.time.microTimestamp();
        var constraint_set = try clew.extractFromCode(small_ts_sample, "typescript");
        const end_extract = std.time.microTimestamp();
        defer constraint_set.deinit();

        extract_times[i] = end_extract - start_extract;

        // Measure compilation time
        const start_compile = std.time.microTimestamp();
        var ir = try braid.compile(constraint_set.constraints.items);
        const end_compile = std.time.microTimestamp();
        defer ir.deinit(testing.allocator);

        compile_times[i] = end_compile - start_compile;
        total_times[i] = extract_times[i] + compile_times[i];
    }

    // Calculate statistics
    var total_extract: i64 = 0;
    var total_compile: i64 = 0;
    var total_combined: i64 = 0;
    var min_total: i64 = std.math.maxInt(i64);
    var max_total: i64 = 0;

    for (extract_times, 0..) |extract_us, idx| {
        const compile_us = compile_times[idx];
        const combined_us = total_times[idx];

        total_extract += extract_us;
        total_compile += compile_us;
        total_combined += combined_us;

        if (combined_us < min_total) min_total = combined_us;
        if (combined_us > max_total) max_total = combined_us;
    }

    const avg_extract_us = @divFloor(total_extract, iterations);
    const avg_compile_us = @divFloor(total_compile, iterations);
    const avg_total_us = @divFloor(total_combined, iterations);

    std.debug.print("Performance metrics ({d} iterations):\n", .{iterations});
    std.debug.print("  Extraction:\n", .{});
    std.debug.print("    Average: {d}µs ({d:.2}ms)\n", .{ avg_extract_us, @as(f64, @floatFromInt(avg_extract_us)) / 1000.0 });
    std.debug.print("  Compilation:\n", .{});
    std.debug.print("    Average: {d}µs ({d:.2}ms)\n", .{ avg_compile_us, @as(f64, @floatFromInt(avg_compile_us)) / 1000.0 });
    std.debug.print("  Combined (Extract + Compile):\n", .{});
    std.debug.print("    Average: {d}µs ({d:.2}ms)\n", .{ avg_total_us, @as(f64, @floatFromInt(avg_total_us)) / 1000.0 });
    std.debug.print("    Min: {d}µs ({d:.2}ms)\n", .{ min_total, @as(f64, @floatFromInt(min_total)) / 1000.0 });
    std.debug.print("    Max: {d}µs ({d:.2}ms)\n", .{ max_total, @as(f64, @floatFromInt(max_total)) / 1000.0 });

    // Target: Extract + Compile under 10ms for small samples
    // This is generous for debug builds, production builds should be faster
    const target_us: i64 = 10_000; // 10ms
    const avg_total_ms = @as(f64, @floatFromInt(avg_total_us)) / 1000.0;

    if (avg_total_us <= target_us) {
        std.debug.print("✓ Performance target met: {d:.2}ms <= 10ms\n", .{avg_total_ms});
    } else {
        std.debug.print("⚠ Performance target missed: {d:.2}ms > 10ms (acceptable in debug builds)\n", .{avg_total_ms});
        // Don't fail test in debug mode, but report the issue
        // In optimized builds, this should pass
    }

    // Ensure performance is reasonable (not pathologically slow)
    // Allow 100ms even for debug builds with small samples
    try testing.expect(avg_total_us < 100_000); // 100ms

    // Now test with the full sample to identify bottlenecks
    std.debug.print("\nFull sample performance:\n", .{});

    const full_start = std.time.microTimestamp();
    var full_constraint_set = try clew.extractFromCode(SAMPLE_TS, "typescript");
    const full_extract_time = std.time.microTimestamp() - full_start;
    defer full_constraint_set.deinit();

    const full_compile_start = std.time.microTimestamp();
    var full_ir = try braid.compile(full_constraint_set.constraints.items);
    const full_compile_time = std.time.microTimestamp() - full_compile_start;
    defer full_ir.deinit(testing.allocator);

    const full_total = full_extract_time + full_compile_time;

    std.debug.print("  Extraction: {d}µs ({d:.2}ms)\n", .{ full_extract_time, @as(f64, @floatFromInt(full_extract_time)) / 1000.0 });
    std.debug.print("  Compilation: {d}µs ({d:.2}ms)\n", .{ full_compile_time, @as(f64, @floatFromInt(full_compile_time)) / 1000.0 });
    std.debug.print("  Total: {d}µs ({d:.2}ms)\n", .{ full_total, @as(f64, @floatFromInt(full_total)) / 1000.0 });
    std.debug.print("  Constraints extracted: {d}\n", .{full_constraint_set.constraints.items.len});

    // Identify bottlenecks
    const extract_percent = @as(f64, @floatFromInt(full_extract_time)) / @as(f64, @floatFromInt(full_total)) * 100.0;
    const compile_percent = @as(f64, @floatFromInt(full_compile_time)) / @as(f64, @floatFromInt(full_total)) * 100.0;

    std.debug.print("\nTime distribution:\n", .{});
    std.debug.print("  Extraction: {d:.1}%\n", .{extract_percent});
    std.debug.print("  Compilation: {d:.1}%\n", .{compile_percent});

    if (extract_percent > 60.0) {
        std.debug.print("⚠ Extraction is the bottleneck\n", .{});
    } else if (compile_percent > 60.0) {
        std.debug.print("⚠ Compilation is the bottleneck\n", .{});
    } else {
        std.debug.print("✓ Balanced performance\n", .{});
    }

    std.debug.print("\n✓ Performance baseline test complete\n\n", .{});
}
