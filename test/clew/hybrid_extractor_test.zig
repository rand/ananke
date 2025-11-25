// Hybrid Extractor Integration Tests
// Tests all 4 extraction strategies and their behavior

const std = @import("std");
const testing = std.testing;

const HybridExtractor = @import("clew").hybrid_extractor.HybridExtractor;
const ExtractionStrategy = @import("clew").hybrid_extractor.ExtractionStrategy;

// ============================================================================
// Test Data
// ============================================================================

const typescript_sample =
    \\// Simple TypeScript sample
    \\interface User {
    \\    id: number;
    \\    name: string;
    \\}
    \\
    \\async function getUser(id: number): Promise<User> {
    \\    return { id, name: "test" };
    \\}
    \\
    \\class UserService {
    \\    async fetchUser(id: number): Promise<User> {
    \\        return getUser(id);
    \\    }
    \\}
    \\
    \\export { User, UserService };
;

const python_sample =
    \\# Simple Python sample
    \\from typing import Optional
    \\
    \\class User:
    \\    def __init__(self, id: int, name: str):
    \\        self.id = id
    \\        self.name = name
    \\
    \\async def get_user(user_id: int) -> Optional[User]:
    \\    """Fetch a user by ID."""
    \\    return User(id=user_id, name="test")
    \\
    \\@dataclass
    \\class UserService:
    \\    async def fetch_user(self, user_id: int) -> User:
    \\        return await get_user(user_id)
;

const unsupported_language_sample = "let x = 42;"; // Generic code

// ============================================================================
// Strategy: tree_sitter_only
// ============================================================================

test "HybridExtractor: tree_sitter_only strategy succeeds for supported language" {
    const allocator = testing.allocator;

    var extractor = HybridExtractor.init(allocator, .tree_sitter_only);
    var result = try extractor.extract(typescript_sample, "typescript");
    defer result.deinitFull(allocator);

    // Should succeed with tree-sitter
    try testing.expect(result.tree_sitter_available);
    try testing.expectEqual(ExtractionStrategy.tree_sitter_only, result.strategy_used);
    try testing.expect(result.tree_sitter_errors == null);

    // Should have extracted constraints from AST
    try testing.expect(result.constraints.len > 0);

    // Verify AST-based constraints have higher confidence (0.95)
    var found_ast_constraint = false;
    for (result.constraints) |constraint| {
        if (constraint.confidence == 0.95) {
            found_ast_constraint = true;
            break;
        }
    }
    try testing.expect(found_ast_constraint);
}

test "HybridExtractor: tree_sitter_only strategy fails gracefully for unsupported language" {
    const allocator = testing.allocator;

    var extractor = HybridExtractor.init(allocator, .tree_sitter_only);
    var result = try extractor.extract(unsupported_language_sample, "kotlin");
    defer result.deinitFull(allocator);

    // Should report language not supported
    try testing.expect(!result.tree_sitter_available);
    try testing.expectEqual(ExtractionStrategy.tree_sitter_only, result.strategy_used);
    try testing.expect(result.tree_sitter_errors != null);

    // Should return empty constraints
    try testing.expectEqual(@as(usize, 0), result.constraints.len);
}

test "HybridExtractor: tree_sitter_only extracts functions from TypeScript" {

    const allocator = testing.allocator;

    var extractor = HybridExtractor.init(allocator, .tree_sitter_only);
    var result = try extractor.extract(typescript_sample, "typescript");
    defer result.deinitFull(allocator);

    // Should find function-related constraints
    var found_functions = false;
    for (result.constraints) |constraint| {
        if (std.mem.indexOf(u8, constraint.name, "functions") != null) {
            found_functions = true;
            // Verify it's from AST (use approximate equality for floating point)
            try testing.expectApproxEqAbs(@as(f64, 0.95), constraint.confidence, 0.001);
            break;
        }
    }
    try testing.expect(found_functions);
}

test "HybridExtractor: tree_sitter_only extracts types from TypeScript" {

    const allocator = testing.allocator;

    var extractor = HybridExtractor.init(allocator, .tree_sitter_only);
    var result = try extractor.extract(typescript_sample, "typescript");
    defer result.deinitFull(allocator);

    // Should find type-related constraints (interface, class)
    var found_types = false;
    for (result.constraints) |constraint| {
        if (std.mem.indexOf(u8, constraint.name, "types") != null) {
            found_types = true;
            try testing.expectApproxEqAbs(@as(f64, 0.95), constraint.confidence, 0.001);
            break;
        }
    }
    try testing.expect(found_types);
}

test "HybridExtractor: tree_sitter_only extracts imports from TypeScript" {

    const allocator = testing.allocator;

    const sample_with_imports =
        \\import { Database } from './database';
        \\import * as utils from './utils';
        \\
        \\function process() {}
    ;

    var extractor = HybridExtractor.init(allocator, .tree_sitter_only);
    var result = try extractor.extract(sample_with_imports, "typescript");
    defer result.deinitFull(allocator);

    // Should find import-related constraints
    var found_imports = false;
    for (result.constraints) |constraint| {
        if (std.mem.indexOf(u8, constraint.name, "imports") != null) {
            found_imports = true;
            try testing.expectApproxEqAbs(@as(f64, 0.95), constraint.confidence, 0.001);
            break;
        }
    }
    try testing.expect(found_imports);
}

// ============================================================================
// Strategy: pattern_only
// ============================================================================

test "HybridExtractor: pattern_only strategy works for supported language" {
    const allocator = testing.allocator;

    var extractor = HybridExtractor.init(allocator, .pattern_only);
    var result = try extractor.extract(typescript_sample, "typescript");
    defer result.deinitFull(allocator);

    // Should not use tree-sitter
    try testing.expect(!result.tree_sitter_available);
    try testing.expectEqual(ExtractionStrategy.pattern_only, result.strategy_used);

    // Should have extracted constraints from patterns
    try testing.expect(result.constraints.len > 0);

    // Verify pattern-based constraints have lower confidence (0.75)
    for (result.constraints) |constraint| {
        try testing.expectEqual(@as(f64, 0.75), constraint.confidence);
    }
}

test "HybridExtractor: pattern_only strategy works for unsupported language" {
    const allocator = testing.allocator;

    var extractor = HybridExtractor.init(allocator, .pattern_only);
    var result = try extractor.extract(unsupported_language_sample, "kotlin");
    defer result.deinitFull(allocator);

    // Should work even without tree-sitter support
    try testing.expect(!result.tree_sitter_available);
    try testing.expectEqual(ExtractionStrategy.pattern_only, result.strategy_used);

    // May return empty constraints if no patterns match
    // (this is expected behavior)
}

test "HybridExtractor: pattern_only extracts from Python" {
    const allocator = testing.allocator;

    var extractor = HybridExtractor.init(allocator, .pattern_only);
    var result = try extractor.extract(python_sample, "python");
    defer result.deinitFull(allocator);

    // Should extract pattern-based constraints
    try testing.expect(result.constraints.len > 0);

    // All should be pattern-based (confidence 0.75)
    for (result.constraints) |constraint| {
        try testing.expectEqual(@as(f64, 0.75), constraint.confidence);
    }
}

// ============================================================================
// Strategy: tree_sitter_with_fallback
// ============================================================================

test "HybridExtractor: tree_sitter_with_fallback prefers tree-sitter for supported language" {

    const allocator = testing.allocator;

    var extractor = HybridExtractor.init(allocator, .tree_sitter_with_fallback);
    var result = try extractor.extract(typescript_sample, "typescript");
    defer result.deinitFull(allocator);

    // Should use tree-sitter
    try testing.expect(result.tree_sitter_available);
    try testing.expectEqual(ExtractionStrategy.tree_sitter_with_fallback, result.strategy_used);

    // Should have AST-based constraints (confidence 0.95)
    var found_ast = false;
    for (result.constraints) |constraint| {
        if (constraint.confidence == 0.95) {
            found_ast = true;
            break;
        }
    }
    try testing.expect(found_ast);
}

test "HybridExtractor: tree_sitter_with_fallback falls back to patterns for unsupported language" {
    const allocator = testing.allocator;

    var extractor = HybridExtractor.init(allocator, .tree_sitter_with_fallback);
    var result = try extractor.extract(unsupported_language_sample, "kotlin");
    defer result.deinitFull(allocator);

    // Should report language not available but still succeed
    try testing.expect(!result.tree_sitter_available);
    try testing.expectEqual(ExtractionStrategy.tree_sitter_with_fallback, result.strategy_used);

    // Should fall back to patterns (may have constraints depending on pattern matches)
}

test "HybridExtractor: tree_sitter_with_fallback handles Python" {

    const allocator = testing.allocator;

    var extractor = HybridExtractor.init(allocator, .tree_sitter_with_fallback);
    var result = try extractor.extract(python_sample, "python");
    defer result.deinitFull(allocator);

    // Should use tree-sitter for Python
    try testing.expect(result.tree_sitter_available);
    try testing.expect(result.constraints.len > 0);

    // Should have AST constraints
    var found_ast = false;
    for (result.constraints) |constraint| {
        if (constraint.confidence == 0.95) {
            found_ast = true;
            break;
        }
    }
    try testing.expect(found_ast);
}

// ============================================================================
// Strategy: combined
// ============================================================================

test "HybridExtractor: combined strategy merges AST and pattern results" {

    const allocator = testing.allocator;

    var extractor = HybridExtractor.init(allocator, .combined);
    var result = try extractor.extract(typescript_sample, "typescript");
    defer result.deinitFull(allocator);

    // Should use tree-sitter and patterns
    try testing.expect(result.tree_sitter_available);
    try testing.expectEqual(ExtractionStrategy.combined, result.strategy_used);

    // Should have both AST (0.95) and pattern (0.75) constraints
    var found_ast = false;
    var found_pattern = false;

    for (result.constraints) |constraint| {
        if (constraint.confidence == 0.95) {
            found_ast = true;
        }
        if (constraint.confidence == 0.75) {
            found_pattern = true;
        }
    }

    try testing.expect(found_ast);
    try testing.expect(found_pattern);
}

test "HybridExtractor: combined strategy deduplicates constraints" {

    const allocator = testing.allocator;

    var extractor = HybridExtractor.init(allocator, .combined);
    var result = try extractor.extract(typescript_sample, "typescript");
    defer result.deinitFull(allocator);

    // Count constraints by name to verify no exact duplicates
    var seen = std.StringHashMap(u32).init(allocator);
    defer seen.deinit();

    for (result.constraints) |constraint| {
        const key = try std.fmt.allocPrint(allocator, "{s}_{s}", .{
            constraint.name,
            @tagName(constraint.kind),
        });
        defer allocator.free(key);

        const count = seen.get(key) orelse 0;
        try seen.put(try allocator.dupe(u8, key), count + 1);
    }

    // Verify no duplicates (all counts should be 1)
    var iter = seen.iterator();
    while (iter.next()) |entry| {
        defer allocator.free(entry.key_ptr.*);
        try testing.expectEqual(@as(u32, 1), entry.value_ptr.*);
    }
}

test "HybridExtractor: combined strategy provides maximum coverage" {

    const allocator = testing.allocator;

    var extractor_combined = HybridExtractor.init(allocator, .combined);
    var result_combined = try extractor_combined.extract(typescript_sample, "typescript");
    defer result_combined.deinitFull(allocator);

    var extractor_ts_only = HybridExtractor.init(allocator, .tree_sitter_only);
    var result_ts_only = try extractor_ts_only.extract(typescript_sample, "typescript");
    defer result_ts_only.deinitFull(allocator);

    var extractor_pattern_only = HybridExtractor.init(allocator, .pattern_only);
    var result_pattern_only = try extractor_pattern_only.extract(typescript_sample, "typescript");
    defer result_pattern_only.deinitFull(allocator);

    // Combined should have >= constraints than either individual strategy
    try testing.expect(result_combined.constraints.len >= result_ts_only.constraints.len);
    try testing.expect(result_combined.constraints.len >= result_pattern_only.constraints.len);
}

test "HybridExtractor: combined strategy works for unsupported language" {
    const allocator = testing.allocator;

    var extractor = HybridExtractor.init(allocator, .combined);
    var result = try extractor.extract(unsupported_language_sample, "kotlin");
    defer result.deinitFull(allocator);

    // Should fall back to patterns only
    try testing.expect(!result.tree_sitter_available);
    try testing.expectEqual(ExtractionStrategy.combined, result.strategy_used);

    // May have pattern-based constraints
    for (result.constraints) |constraint| {
        // If there are any constraints, they should be pattern-based
        try testing.expectEqual(@as(f64, 0.75), constraint.confidence);
    }
}

// ============================================================================
// Cross-Language Tests
// ============================================================================

test "HybridExtractor: handles multiple languages with same strategy" {
    const allocator = testing.allocator;

    var extractor = HybridExtractor.init(allocator, .combined);

    // TypeScript
    var ts_result = try extractor.extract(typescript_sample, "typescript");
    defer ts_result.deinitFull(allocator);
    try testing.expect(ts_result.constraints.len > 0);

    // Python
    var py_result = try extractor.extract(python_sample, "python");
    defer py_result.deinitFull(allocator);
    try testing.expect(py_result.constraints.len > 0);

    // Both should have used tree-sitter
    try testing.expect(ts_result.tree_sitter_available);
    try testing.expect(py_result.tree_sitter_available);
}

// ============================================================================
// Edge Cases and Error Handling
// ============================================================================

test "HybridExtractor: handles empty source code" {
    const allocator = testing.allocator;

    var extractor = HybridExtractor.init(allocator, .combined);
    var result = try extractor.extract("", "typescript");
    defer result.deinitFull(allocator);

    // Should succeed but return minimal or no constraints
    try testing.expect(result.tree_sitter_available);
}

test "HybridExtractor: handles malformed source code" {
    const allocator = testing.allocator;

    const malformed = "function foo( { // incomplete";

    var extractor = HybridExtractor.init(allocator, .tree_sitter_only);
    var result = try extractor.extract(malformed, "typescript");
    defer result.deinitFull(allocator);

    // Tree-sitter should report parse error
    try testing.expect(result.tree_sitter_available);
    // Should have errors reported
    try testing.expect(result.tree_sitter_errors != null);
}

test "HybridExtractor: handles very large source files" {
    const allocator = testing.allocator;

    // Generate a large source file
    var large_source = std.ArrayList(u8){};
    defer large_source.deinit(allocator);

    var i: usize = 0;
    while (i < 100) : (i += 1) {
        try large_source.appendSlice(allocator, typescript_sample);
        try large_source.append(allocator, '\n');
    }

    var extractor = HybridExtractor.init(allocator, .combined);
    var result = try extractor.extract(large_source.items, "typescript");
    defer result.deinitFull(allocator);

    // Should handle large files successfully
    try testing.expect(result.constraints.len > 0);
}
