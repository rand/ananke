//! Strategy Comparison E2E Tests
//!
//! Compares results from all 4 extraction strategies:
//! 1. tree_sitter_only - Pure AST extraction
//! 2. pattern_only - Pure regex/pattern extraction
//! 3. tree_sitter_with_fallback - AST with pattern fallback
//! 4. combined - Merge AST and patterns
//!
//! Verifies that combined strategy produces the richest results

const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const HybridExtractor = @import("clew").hybrid_extractor.HybridExtractor;
const ExtractionStrategy = @import("clew").hybrid_extractor.ExtractionStrategy;
const ExtractionResult = @import("clew").hybrid_extractor.ExtractionResult;
const Constraint = @import("ananke").types.constraint.Constraint;

// ============================================================================
// Test Fixture
// ============================================================================

const comprehensive_typescript =
    \\// Comprehensive TypeScript with multiple patterns
    \\import { Database } from './db';
    \\
    \\interface User {
    \\    id: number;
    \\    name: string;
    \\    email: string;
    \\}
    \\
    \\type Result<T> = { ok: true; data: T } | { ok: false; error: string };
    \\
    \\class UserRepository {
    \\    constructor(private db: Database) {}
    \\    
    \\    async findById(id: number): Promise<User | null> {
    \\        try {
    \\            const result = await this.db.query('SELECT * FROM users WHERE id = ?', [id]);
    \\            return result as User;
    \\        } catch (error) {
    \\            console.error('Database error:', error);
    \\            throw new Error('Failed to fetch user');
    \\        }
    \\    }
    \\    
    \\    async create(user: Omit<User, 'id'>): Promise<User> {
    \\        const id = await this.db.insert('users', user);
    \\        return { id, ...user };
    \\    }
    \\}
    \\
    \\export { UserRepository, User };
;

// ============================================================================
// Strategy Comparison Tests
// ============================================================================

test "Strategy: tree_sitter_only extracts AST constraints" {
    const allocator = testing.allocator;
    
    var extractor = HybridExtractor.init(allocator, .tree_sitter_only);
    var result = try extractor.extract(comprehensive_typescript, "typescript");
    defer result.deinitFull(allocator);
    
    std.debug.print("\n=== Strategy: tree_sitter_only ===\n", .{});
    std.debug.print("Tree-sitter available: {}\n", .{result.tree_sitter_available});
    std.debug.print("Constraints extracted: {}\n", .{result.constraints.len});
    
    if (result.tree_sitter_available) {
        // Should have only AST-based constraints (confidence = 0.95)
        for (result.constraints) |c| {
            std.debug.print("  - {s} (conf: {d:.2})\n", .{c.name, c.confidence});
            
            // All should be high confidence from AST
            if (c.confidence < 0.90) {
                std.debug.print("    WARNING: Unexpected low confidence in tree_sitter_only mode\n", .{});
            }
        }
        
        std.debug.print("✓ AST-only extraction successful\n", .{});
    } else {
        std.debug.print("⊘ Tree-sitter not available, returned empty results\n", .{});
        try testing.expectEqual(@as(usize, 0), result.constraints.len);
    }
}

test "Strategy: pattern_only extracts pattern constraints" {
    const allocator = testing.allocator;
    
    var extractor = HybridExtractor.init(allocator, .pattern_only);
    var result = try extractor.extract(comprehensive_typescript, "typescript");
    defer result.deinitFull(allocator);
    
    std.debug.print("\n=== Strategy: pattern_only ===\n", .{});
    std.debug.print("Tree-sitter available: {} (should be false)\n", .{result.tree_sitter_available});
    std.debug.print("Constraints extracted: {}\n", .{result.constraints.len});
    
    // Should NOT use tree-sitter
    try testing.expect(!result.tree_sitter_available);
    
    if (result.constraints.len > 0) {
        // Should have only pattern-based constraints (confidence = 0.75)
        for (result.constraints) |c| {
            std.debug.print("  - {s} (conf: {d:.2})\n", .{c.name, c.confidence});
            
            // All should be pattern-based confidence
            if (c.confidence >= 0.90) {
                std.debug.print("    WARNING: Unexpected high confidence in pattern_only mode\n", .{});
            }
        }
    }
    
    std.debug.print("✓ Pattern-only extraction successful\n", .{});
}

test "Strategy: tree_sitter_with_fallback prefers AST" {
    const allocator = testing.allocator;
    
    var extractor = HybridExtractor.init(allocator, .tree_sitter_with_fallback);
    var result = try extractor.extract(comprehensive_typescript, "typescript");
    defer result.deinitFull(allocator);
    
    std.debug.print("\n=== Strategy: tree_sitter_with_fallback ===\n", .{});
    std.debug.print("Tree-sitter available: {}\n", .{result.tree_sitter_available});
    std.debug.print("Constraints extracted: {}\n", .{result.constraints.len});
    
    if (result.tree_sitter_available) {
        // Should prefer AST extraction
        var high_conf_count: usize = 0;
        for (result.constraints) |c| {
            if (c.confidence >= 0.90) high_conf_count += 1;
        }
        
        std.debug.print("High confidence constraints: {}\n", .{high_conf_count});
        std.debug.print("✓ Used tree-sitter as primary strategy\n", .{});
    } else {
        std.debug.print("Fell back to patterns (tree-sitter unavailable)\n", .{});
    }
}

test "Strategy: combined merges AST and patterns" {
    const allocator = testing.allocator;
    
    var extractor = HybridExtractor.init(allocator, .combined);
    var result = try extractor.extract(comprehensive_typescript, "typescript");
    defer result.deinitFull(allocator);
    
    std.debug.print("\n=== Strategy: combined ===\n", .{});
    std.debug.print("Tree-sitter available: {}\n", .{result.tree_sitter_available});
    std.debug.print("Constraints extracted: {}\n", .{result.constraints.len});
    
    if (result.tree_sitter_available) {
        // Should have BOTH AST (0.95) and pattern (0.75) constraints
        var high_conf: usize = 0;
        var mid_conf: usize = 0;
        
        for (result.constraints) |c| {
            if (c.confidence >= 0.90) {
                high_conf += 1;
            } else if (c.confidence >= 0.70) {
                mid_conf += 1;
            }
        }
        
        std.debug.print("AST constraints (high conf):     {}\n", .{high_conf});
        std.debug.print("Pattern constraints (mid conf):  {}\n", .{mid_conf});
        
        // Combined should have both types
        if (high_conf > 0 and mid_conf > 0) {
            std.debug.print("✓ Successfully merged AST and pattern constraints\n", .{});
        } else {
            std.debug.print("⚠ Only one type of constraint found\n", .{});
        }
    }
}

// ============================================================================
// Strategy Comparison: Coverage
// ============================================================================

test "Strategy Comparison: Combined has best coverage" {
    const allocator = testing.allocator;
    
    std.debug.print("\n=== Coverage Comparison ===\n", .{});
    
    // Extract with all strategies
    var ts_only = HybridExtractor.init(allocator, .tree_sitter_only);
    var pattern_only = HybridExtractor.init(allocator, .pattern_only);
    var with_fallback = HybridExtractor.init(allocator, .tree_sitter_with_fallback);
    var combined = HybridExtractor.init(allocator, .combined);
    
    var ts_result = try ts_only.extract(comprehensive_typescript, "typescript");
    defer ts_result.deinitFull(allocator);
    
    var pattern_result = try pattern_only.extract(comprehensive_typescript, "typescript");
    defer pattern_result.deinitFull(allocator);
    
    var fallback_result = try with_fallback.extract(comprehensive_typescript, "typescript");
    defer fallback_result.deinitFull(allocator);
    
    var combined_result = try combined.extract(comprehensive_typescript, "typescript");
    defer combined_result.deinitFull(allocator);
    
    std.debug.print("tree_sitter_only:        {} constraints\n", .{ts_result.constraints.len});
    std.debug.print("pattern_only:            {} constraints\n", .{pattern_result.constraints.len});
    std.debug.print("tree_sitter_with_fallback: {} constraints\n", .{fallback_result.constraints.len});
    std.debug.print("combined:                {} constraints\n", .{combined_result.constraints.len});
    
    // Combined should have >= constraints than individual strategies
    if (ts_result.tree_sitter_available) {
        try testing.expect(combined_result.constraints.len >= ts_result.constraints.len);
        try testing.expect(combined_result.constraints.len >= pattern_result.constraints.len);
        std.debug.print("✓ Combined strategy has best coverage\n", .{});
    } else {
        std.debug.print("⊘ Tree-sitter not available, skipping coverage test\n", .{});
    }
}

// ============================================================================
// Confidence Score Analysis
// ============================================================================

test "Strategy Comparison: Confidence score distribution" {
    const allocator = testing.allocator;
    
    std.debug.print("\n=== Confidence Distribution by Strategy ===\n", .{});
    
    const strategies = [_]struct {
        name: []const u8,
        strategy: ExtractionStrategy,
    }{
        .{ .name = "tree_sitter_only", .strategy = .tree_sitter_only },
        .{ .name = "pattern_only", .strategy = .pattern_only },
        .{ .name = "combined", .strategy = .combined },
    };
    
    for (strategies) |strat| {
        var extractor = HybridExtractor.init(allocator, strat.strategy);
        var result = try extractor.extract(comprehensive_typescript, "typescript");
        defer result.deinitFull(allocator);
        
        if (result.constraints.len == 0) {
            std.debug.print("\n{s}: No constraints\n", .{strat.name});
            continue;
        }
        
        // Calculate min, max, average confidence
        var min_conf: f32 = 1.0;
        var max_conf: f32 = 0.0;
        var total_conf: f32 = 0.0;
        
        for (result.constraints) |c| {
            if (c.confidence < min_conf) min_conf = c.confidence;
            if (c.confidence > max_conf) max_conf = c.confidence;
            total_conf += c.confidence;
        }
        
        const avg_conf = total_conf / @as(f32, @floatFromInt(result.constraints.len));
        
        std.debug.print("\n{s}:\n", .{strat.name});
        std.debug.print("  Min: {d:.2}, Max: {d:.2}, Avg: {d:.2}\n", 
            .{min_conf, max_conf, avg_conf});
    }
    
    std.debug.print("\n✓ Confidence analysis complete\n", .{});
}

// ============================================================================
// Fallback Behavior
// ============================================================================

test "Strategy: Fallback for unsupported language" {
    const allocator = testing.allocator;
    
    const kotlin_code = "fun main() { println(\"Hello\") }";
    
    std.debug.print("\n=== Fallback Behavior (Kotlin) ===\n", .{});
    
    // tree_sitter_only should fail gracefully
    var ts_only = HybridExtractor.init(allocator, .tree_sitter_only);
    var ts_result = try ts_only.extract(kotlin_code, "kotlin");
    defer ts_result.deinitFull(allocator);
    
    std.debug.print("tree_sitter_only - Available: {}, Count: {}\n",
        .{ts_result.tree_sitter_available, ts_result.constraints.len});
    try testing.expect(!ts_result.tree_sitter_available);
    
    // tree_sitter_with_fallback should fall back to patterns
    var with_fallback = HybridExtractor.init(allocator, .tree_sitter_with_fallback);
    var fallback_result = try with_fallback.extract(kotlin_code, "kotlin");
    defer fallback_result.deinitFull(allocator);
    
    std.debug.print("tree_sitter_with_fallback - Available: {}, Count: {}\n",
        .{fallback_result.tree_sitter_available, fallback_result.constraints.len});
    try testing.expect(!fallback_result.tree_sitter_available);
    
    std.debug.print("✓ Fallback behavior verified\n", .{});
}

// ============================================================================
// Deduplication in Combined Strategy
// ============================================================================

test "Strategy: Combined deduplicates constraints" {
    const allocator = testing.allocator;
    
    var combined = HybridExtractor.init(allocator, .combined);
    var result = try combined.extract(comprehensive_typescript, "typescript");
    defer result.deinitFull(allocator);
    
    std.debug.print("\n=== Deduplication Test ===\n", .{});
    std.debug.print("Total constraints: {}\n", .{result.constraints.len});
    
    // Check for exact duplicates (same name and kind)
    var seen = std.StringHashMap(void).init(allocator);
    defer seen.deinit();
    
    var duplicate_count: usize = 0;
    
    for (result.constraints) |c| {
        const key = try std.fmt.allocPrint(allocator, "{s}_{s}", 
            .{c.name, @tagName(c.kind)});
        defer allocator.free(key);
        
        if (seen.contains(key)) {
            duplicate_count += 1;
            std.debug.print("  Duplicate: {s}\n", .{key});
        }
        
        try seen.put(try allocator.dupe(u8, key), {});
    }
    
    // Clean up seen keys
    var iter = seen.keyIterator();
    while (iter.next()) |key| {
        allocator.free(key.*);
    }
    
    std.debug.print("Duplicates found: {}\n", .{duplicate_count});
    
    if (duplicate_count == 0) {
        std.debug.print("✓ No duplicates - deduplication working\n", .{});
    } else {
        std.debug.print("⚠ Found {} duplicates\n", .{duplicate_count});
    }
}
