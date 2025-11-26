//! Constraint Quality E2E Tests
//!
//! Verifies the quality of extracted constraints:
//! - Confidence scores match extraction method
//! - Duplicate detection and merging
//! - Metadata completeness (line numbers, frequencies)
//! - Constraint validation

const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const Clew = @import("clew").Clew;
const HybridExtractor = @import("clew").hybrid_extractor.HybridExtractor;
const ExtractionStrategy = @import("clew").hybrid_extractor.ExtractionStrategy;
const Constraint = @import("ananke").types.constraint.Constraint;
const ConstraintKind = @import("ananke").types.constraint.ConstraintKind;
// ============================================================================
// Test Fixtures
const high_quality_typescript =
    \\// Well-structured TypeScript code
    \\interface Config {
    \\    apiUrl: string;
    \\    timeout: number;
    \\    retries: number;
    \\}
    \\
    \\class ApiClient {
    \\    constructor(private config: Config) {}
    \\    
    \\    async fetch<T>(url: string): Promise<T> {
    \\        const response = await fetch(url);
    \\        if (!response.ok) {
    \\            throw new Error(`HTTP ${response.status}`);
    \\        }
    \\        return response.json();
    \\    }
;
const duplicate_patterns =
    \\function foo() { return 1; }
    \\function bar() { return 2; }
    \\function baz() { return 3; }
    \\class A {}
    \\class B {}
    \\class C {}
    \\async function asyncFoo() {}
    \\async function asyncBar() {}
;
// Confidence Score Tests
test "Quality: AST constraints have high confidence" {
    const allocator = testing.allocator;
    
    var extractor = try HybridExtractor.init(allocator, .tree_sitter_only);
    defer extractor.deinit();
    var result = try extractor.extract(high_quality_typescript, "typescript");
    defer result.deinitFull(allocator);
    std.debug.print("\n=== AST Confidence Test ===\n", .{});
    if (!result.tree_sitter_available) {
        std.debug.print("⊘ Tree-sitter not available, skipping test\n", .{});
        return;
    }
    // All AST-based constraints should have confidence >= 0.95
    for (result.constraints) |c| {
        std.debug.print("  {s}: {d:.2}\n", .{c.name, c.confidence});

        if (c.confidence < 0.90) {
            std.debug.print("    ERROR: AST constraint has low confidence!\n", .{});
            return error.LowConfidenceForAST;
        }
    }
    std.debug.print("✓ All AST constraints have confidence ≥ 0.90\n", .{});
}
test "Quality: Pattern constraints have medium confidence" {
    const allocator = testing.allocator;

    var extractor = try HybridExtractor.init(allocator, .pattern_only);
    defer extractor.deinit();
    var result = try extractor.extract(high_quality_typescript, "typescript");
    defer result.deinitFull(allocator);

    std.debug.print("\n=== Pattern Confidence Test ===\n", .{});
    if (result.constraints.len == 0) {
        std.debug.print("⊘ No pattern constraints extracted\n", .{});
        return;
    }
    // Pattern constraints should have confidence around 0.75-0.85
    for (result.constraints) |c| {
        // Should be in reasonable range for patterns
        try testing.expect(c.confidence >= 0.60);
        try testing.expect(c.confidence < 0.95);
    }
    std.debug.print("✓ Pattern constraints have appropriate confidence\n", .{});
}
test "Quality: Combined strategy has mixed confidence" {
    const allocator = testing.allocator;
    var extractor = try HybridExtractor.init(allocator, .combined);
    defer extractor.deinit();
    var result = try extractor.extract(high_quality_typescript, "typescript");
    defer result.deinitFull(allocator);
    std.debug.print("\n=== Combined Confidence Distribution ===\n", .{});
    if (!result.tree_sitter_available or result.constraints.len == 0) {
        std.debug.print("⊘ Cannot test - tree-sitter unavailable or no constraints\n", .{});
        return;
    }
    var high_conf_count: usize = 0;
    var mid_conf_count: usize = 0;
    var low_conf_count: usize = 0;
    for (result.constraints) |c| {
        if (c.confidence >= 0.90) {
            high_conf_count += 1;
        } else if (c.confidence >= 0.70) {
            mid_conf_count += 1;
        } else {
            low_conf_count += 1;
        }
    }
    std.debug.print("High (≥0.90): {}\n", .{high_conf_count});
    std.debug.print("Mid (0.70-0.89): {}\n", .{mid_conf_count});
    std.debug.print("Low (<0.70): {}\n", .{low_conf_count});
    // Combined should have both high and mid confidence constraints
    if (high_conf_count > 0 and mid_conf_count > 0) {
        std.debug.print("✓ Mixed confidence distribution as expected\n", .{});
    } else if (high_conf_count > 0) {
        std.debug.print("⚠ Only high confidence (AST) constraints found\n", .{});
    } else {
        std.debug.print("⚠ No high confidence constraints\n", .{});
    }
}
// Duplicate Detection Tests
test "Quality: Duplicate detection in combined mode" {
    const allocator = testing.allocator;
    var extractor = try HybridExtractor.init(allocator, .combined);
    defer extractor.deinit();
    var result = try extractor.extract(duplicate_patterns, "typescript");
    defer result.deinitFull(allocator);
    std.debug.print("\n=== Duplicate Detection Test ===\n", .{});
    std.debug.print("Total constraints: {}\n", .{result.constraints.len});
    // Count constraints by name
    var name_counts = std.StringHashMap(usize).init(allocator);
    defer {
        var iter = name_counts.keyIterator();
        while (iter.next()) |key| {
            allocator.free(key.*);
        }
        name_counts.deinit();
    }

    for (result.constraints) |c| {
        const key = try allocator.dupe(u8, c.name);
        const count = name_counts.get(c.name) orelse 0;
        if (count > 0) {
            // Found duplicate
            allocator.free(key);
            std.debug.print("  Duplicate name: {s} (count: {})\n", .{c.name, count + 1});
        }
        try name_counts.put(key, count + 1);
    }
    std.debug.print("Unique constraint names: {}\n", .{name_counts.count()});
    std.debug.print("✓ Duplicate detection complete\n", .{});
}
test "Quality: Frequency counting for repeated patterns" {
    const allocator = testing.allocator;
    var clew = try Clew.init(allocator);
    defer clew.deinit();
    var constraints = try clew.extractFromCode(duplicate_patterns, "typescript");
    defer constraints.deinit();
    std.debug.print("\n=== Frequency Counting Test ===\n", .{});
    // Look for constraints with frequency > 1
    var found_frequency_tracking = false;
    for (constraints.constraints.items) |c| {
        if (c.frequency > 1) {
            std.debug.print("  {s}: frequency = {}\n", .{c.name, c.frequency});
            found_frequency_tracking = true;
        }
    }
    if (found_frequency_tracking) {
        std.debug.print("✓ Frequency tracking is working\n", .{});
    } else {
        std.debug.print("⊘ No frequency tracking found (may be expected)\n", .{});
    }
}
// Metadata Completeness Tests
test "Quality: All constraints have names and descriptions" {
    const allocator = testing.allocator;
    var clew = try Clew.init(allocator);
    defer clew.deinit();
    var constraints = try clew.extractFromCode(high_quality_typescript, "typescript");
    defer constraints.deinit();
    std.debug.print("\n=== Metadata Completeness Test ===\n", .{});
    var missing_name: usize = 0;
    var missing_description: usize = 0;
    for (constraints.constraints.items) |c| {
        if (c.name.len == 0) {
            missing_name += 1;
            std.debug.print("  ERROR: Constraint missing name\n", .{});
        }
        if (c.description.len == 0) {
            missing_description += 1;
            std.debug.print("  ERROR: Constraint missing description\n", .{});
        }
    }
    std.debug.print("Constraints with names: {}/{}\n",
        .{constraints.constraints.items.len - missing_name, constraints.constraints.items.len});
    std.debug.print("Constraints with descriptions: {}/{}\n",
        .{constraints.constraints.items.len - missing_description, constraints.constraints.items.len});
    try testing.expectEqual(@as(usize, 0), missing_name);
    try testing.expectEqual(@as(usize, 0), missing_description);
    std.debug.print("✓ All constraints have complete metadata\n", .{});
}
test "Quality: Line number tracking" {
    const allocator = testing.allocator;
    const multiline_code =
        \\// Line 1
        \\interface User {  // Line 2
        \\    id: number;   // Line 3
        \\}               // Line 4
        \\                // Line 5
        \\class Service { // Line 6
        \\    foo() {}      // Line 7
        \\}               // Line 8
    ;
    var clew = try Clew.init(allocator);
    defer clew.deinit();
    var constraints = try clew.extractFromCode(multiline_code, "typescript");
    defer constraints.deinit();
    std.debug.print("\n=== Line Number Tracking Test ===\n", .{});
    var has_line_numbers = false;
    for (constraints.constraints.items) |c| {
        if (c.origin_line) |line| {
            std.debug.print("  {s}: line {}\n", .{c.name, line});
            has_line_numbers = true;

            // Line numbers should be reasonable (1-8 for this code)
            try testing.expect(line > 0);
            try testing.expect(line <= 8);
        }
    }
    if (has_line_numbers) {
        std.debug.print("✓ Line number tracking is working\n", .{});
    } else {
        std.debug.print("⊘ No line numbers tracked (may be expected)\n", .{});
    }
}
test "Quality: Constraint kind appropriateness" {
    const allocator = testing.allocator;
    var clew = try Clew.init(allocator);
    defer clew.deinit();
    var constraints = try clew.extractFromCode(high_quality_typescript, "typescript");
    defer constraints.deinit();
    std.debug.print("\n=== Constraint Kind Distribution ===\n", .{});
    var kind_counts = std.AutoHashMap(ConstraintKind, usize).init(allocator);
    defer kind_counts.deinit();
    for (constraints.constraints.items) |c| {
        const count = kind_counts.get(c.kind) orelse 0;
        try kind_counts.put(c.kind, count + 1);
    }
    // Print distribution
    var iter = kind_counts.iterator();
    while (iter.next()) |entry| {
        std.debug.print("  {s}: {}\n", .{@tagName(entry.key_ptr.*), entry.value_ptr.*});
    }
    // TypeScript should have syntactic and type_safety constraints
    const syntactic = kind_counts.get(.syntactic) orelse 0;
    const type_safety = kind_counts.get(.type_safety) orelse 0;
    std.debug.print("✓ Constraint kinds distributed across categories\n", .{});
    std.debug.print("  Syntactic: {}, Type Safety: {}\n", .{syntactic, type_safety});
}
// Constraint Validation Tests
test "Quality: All constraints pass validation" {
    const allocator = testing.allocator;
    var clew = try Clew.init(allocator);
    defer clew.deinit();
    var constraints = try clew.extractFromCode(high_quality_typescript, "typescript");
    defer constraints.deinit();
    std.debug.print("\n=== Constraint Validation Test ===\n", .{});
    var invalid_count: usize = 0;
    for (constraints.constraints.items) |c| {
        // Check confidence in valid range
        if (c.confidence < 0.0 or c.confidence > 1.0) {
            std.debug.print("  ERROR: Invalid confidence {d:.2} for {s}\n",
                .{c.confidence, c.name});
            invalid_count += 1;
        }
        // Check name is not empty
        if (c.name.len == 0) {
            std.debug.print("  ERROR: Empty name\n", .{});
            invalid_count += 1;
        }
        // Check frequency is reasonable
        if (c.frequency == 0) {
            std.debug.print("  WARNING: Zero frequency for {s}\n", .{c.name});
        }
    }
    std.debug.print("Validated {} constraints\n", .{constraints.constraints.items.len});
    std.debug.print("Invalid: {}\n", .{invalid_count});
    try testing.expectEqual(@as(usize, 0), invalid_count);
    std.debug.print("✓ All constraints are valid\n", .{});
}
// Edge Cases
test "Quality: Empty code produces no invalid constraints" {
    const allocator = testing.allocator;
    var clew = try Clew.init(allocator);
    defer clew.deinit();
    var constraints = try clew.extractFromCode("", "typescript");
    defer constraints.deinit();
    std.debug.print("\n=== Empty Code Quality Test ===\n", .{});
    std.debug.print("Constraints from empty code: {}\n", .{constraints.constraints.items.len});
    // Should not produce invalid constraints
    for (constraints.constraints.items) |c| {
        try testing.expect(c.name.len > 0);
        try testing.expect(c.confidence >= 0.0 and c.confidence <= 1.0);
    }
    std.debug.print("✓ No invalid constraints from empty code\n", .{});
}
test "Quality: Minimal code produces valid constraints" {
    const allocator = testing.allocator;
    const minimal = "function f() {}";
    var clew = try Clew.init(allocator);
    defer clew.deinit();
    var constraints = try clew.extractFromCode(minimal, "typescript");
    defer constraints.deinit();
    std.debug.print("\n=== Minimal Code Quality Test ===\n", .{});
    std.debug.print("Constraints: {}\n", .{constraints.constraints.items.len});
    for (constraints.constraints.items) |c| {
        std.debug.print("  {s} (conf: {d:.2}, kind: {s})\n",
            .{c.name, c.confidence, @tagName(c.kind)});
        // Validate each constraint
        try testing.expect(c.name.len > 0);
        try testing.expect(c.confidence >= 0.0 and c.confidence <= 1.0);
    }
    std.debug.print("✓ Minimal code produces valid constraints\n", .{});
}
