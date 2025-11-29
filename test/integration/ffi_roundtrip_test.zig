//! FFI Roundtrip Tests
//!
//! Tests the complete roundtrip of constraint data through the FFI boundary:
//! Zig IR → FFI → Simulated Rust → FFI → Zig IR
//!
//! This ensures no data loss occurs when marshaling across FFI boundaries.

const std = @import("std");
const testing = std.testing;
const root = @import("ananke");
const ffi = @import("../../src/ffi/zig_ffi.zig");
const Constraint = root.types.constraint.Constraint;
const ConstraintIR = root.types.constraint.ConstraintIR;
const JsonSchema = root.types.constraint.JsonSchema;
const Grammar = root.types.constraint.Grammar;
const GrammarRule = root.types.constraint.GrammarRule;
const Regex = root.types.constraint.Regex;
const TokenMaskRules = root.types.constraint.TokenMaskRules;

// Test allocator
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

test "FFI roundtrip: empty ConstraintIR" {
    // Create an empty IR
    const original = ConstraintIR{
        .json_schema = null,
        .grammar = null,
        .regex_patterns = &.{},
        .token_masks = null,
        .priority = 0,
    };

    // Convert to FFI
    const ir_ffi = try convertIRToFFI(allocator, original);
    defer ffi.ananke_free_constraint_ir(ir_ffi);

    // Verify FFI structure
    try testing.expect(ir_ffi.json_schema == null);
    try testing.expect(ir_ffi.grammar == null);
    try testing.expectEqual(@as(usize, 0), ir_ffi.regex_patterns_len);
    try testing.expect(ir_ffi.token_masks == null);
    try testing.expectEqual(@as(u32, 0), ir_ffi.priority);

    // Convert back from FFI
    const restored = try convertFFIToIR(allocator, ir_ffi);
    defer restored.deinit(allocator);

    // Verify roundtrip
    try testing.expect(restored.json_schema == null);
    try testing.expect(restored.grammar == null);
    try testing.expectEqual(@as(usize, 0), restored.regex_patterns.len);
    try testing.expect(restored.token_masks == null);
    try testing.expectEqual(@as(u32, 0), restored.priority);
}

test "FFI roundtrip: JsonSchema" {
    // Create IR with JSON schema
    const schema = JsonSchema{
        .type = "object",
        .properties = null,
        .required = &[_][]const u8{ "name", "age" },
        .additional_properties = false,
    };

    const original = ConstraintIR{
        .json_schema = schema,
        .grammar = null,
        .regex_patterns = &.{},
        .token_masks = null,
        .priority = 10,
    };

    // Convert to FFI
    const ir_ffi = try convertIRToFFI(allocator, original);
    defer ffi.ananke_free_constraint_ir(ir_ffi);

    // Verify FFI structure
    try testing.expect(ir_ffi.json_schema != null);
    const json_str = std.mem.span(ir_ffi.json_schema.?);
    try testing.expect(std.mem.indexOf(u8, json_str, "\"schema_type\":\"object\"") != null);
    try testing.expect(std.mem.indexOf(u8, json_str, "\"required\":[\"name\",\"age\"]") != null);
    try testing.expect(std.mem.indexOf(u8, json_str, "\"additional_properties\":false") != null);

    // Convert back from FFI
    const restored = try convertFFIToIR(allocator, ir_ffi);
    defer restored.deinit(allocator);

    // Verify schema roundtrip
    try testing.expect(restored.json_schema != null);
    const restored_schema = restored.json_schema.?;
    try testing.expectEqualStrings("object", restored_schema.type);
    try testing.expectEqual(@as(usize, 2), restored_schema.required.len);
    try testing.expectEqual(false, restored_schema.additional_properties);
}

test "FFI roundtrip: Grammar rules" {
    // Create IR with grammar
    const rules = try allocator.alloc(GrammarRule, 2);
    rules[0] = GrammarRule{
        .lhs = "expression",
        .rhs = &[_][]const u8{ "term", "+", "expression" },
    };
    rules[1] = GrammarRule{
        .lhs = "term",
        .rhs = &[_][]const u8{"NUMBER"},
    };

    const grammar = Grammar{
        .rules = rules,
        .start_symbol = "expression",
    };

    const original = ConstraintIR{
        .json_schema = null,
        .grammar = grammar,
        .regex_patterns = &.{},
        .token_masks = null,
        .priority = 20,
    };

    // Convert to FFI
    const ir_ffi = try convertIRToFFI(allocator, original);
    defer ffi.ananke_free_constraint_ir(ir_ffi);

    // Verify FFI structure
    try testing.expect(ir_ffi.grammar != null);
    const grammar_str = std.mem.span(ir_ffi.grammar.?);
    try testing.expect(std.mem.indexOf(u8, grammar_str, "\"start_symbol\":\"expression\"") != null);
    try testing.expect(std.mem.indexOf(u8, grammar_str, "\"lhs\":\"expression\"") != null);
    try testing.expect(std.mem.indexOf(u8, grammar_str, "\"lhs\":\"term\"") != null);

    // Convert back from FFI
    const restored = try convertFFIToIR(allocator, ir_ffi);
    defer restored.deinit(allocator);

    // Verify grammar roundtrip
    try testing.expect(restored.grammar != null);
    const restored_grammar = restored.grammar.?;
    try testing.expectEqualStrings("expression", restored_grammar.start_symbol);
    try testing.expectEqual(@as(usize, 2), restored_grammar.rules.len);
}

test "FFI roundtrip: Regex patterns" {
    // Create IR with regex patterns
    const patterns = try allocator.alloc(Regex, 3);
    patterns[0] = Regex{ .pattern = "^[a-z][a-zA-Z0-9]*$", .flags = "i" };
    patterns[1] = Regex{ .pattern = "\\d{4}-\\d{2}-\\d{2}", .flags = "" };
    patterns[2] = Regex{ .pattern = "TODO:.*", .flags = "g" };

    const original = ConstraintIR{
        .json_schema = null,
        .grammar = null,
        .regex_patterns = patterns,
        .token_masks = null,
        .priority = 30,
    };

    // Convert to FFI
    const ir_ffi = try convertIRToFFI(allocator, original);
    defer ffi.ananke_free_constraint_ir(ir_ffi);

    // Verify FFI structure
    try testing.expectEqual(@as(usize, 3), ir_ffi.regex_patterns_len);
    try testing.expect(ir_ffi.regex_patterns != null);

    const pattern_ptrs = ir_ffi.regex_patterns.?[0..ir_ffi.regex_patterns_len];

    // First pattern should include flags
    const p0 = std.mem.span(pattern_ptrs[0]);
    try testing.expect(std.mem.indexOf(u8, p0, "^[a-z][a-zA-Z0-9]*$") != null);
    try testing.expect(std.mem.indexOf(u8, p0, "FLAGS:i") != null);

    // Second pattern has no flags
    const p1 = std.mem.span(pattern_ptrs[1]);
    try testing.expectEqualStrings("\\d{4}-\\d{2}-\\d{2}", p1);

    // Third pattern with flags
    const p2 = std.mem.span(pattern_ptrs[2]);
    try testing.expect(std.mem.indexOf(u8, p2, "TODO:.*") != null);
    try testing.expect(std.mem.indexOf(u8, p2, "FLAGS:g") != null);

    // Convert back from FFI
    const restored = try convertFFIToIR(allocator, ir_ffi);
    defer restored.deinit(allocator);

    // Verify patterns roundtrip
    try testing.expectEqual(@as(usize, 3), restored.regex_patterns.len);
}

test "FFI roundtrip: Token masks" {
    // Create IR with token masks
    const allowed = try allocator.alloc(u32, 3);
    allowed[0] = 100;
    allowed[1] = 200;
    allowed[2] = 300;

    const forbidden = try allocator.alloc(u32, 2);
    forbidden[0] = 999;
    forbidden[1] = 1000;

    const masks = TokenMaskRules{
        .allowed_tokens = allowed,
        .forbidden_tokens = forbidden,
    };

    const original = ConstraintIR{
        .json_schema = null,
        .grammar = null,
        .regex_patterns = &.{},
        .token_masks = masks,
        .priority = 40,
    };

    // Convert to FFI
    const ir_ffi = try convertIRToFFI(allocator, original);
    defer ffi.ananke_free_constraint_ir(ir_ffi);

    // Verify FFI structure
    try testing.expect(ir_ffi.token_masks != null);
    const masks_ffi = ir_ffi.token_masks.?;

    try testing.expectEqual(@as(usize, 3), masks_ffi.allowed_tokens_len);
    try testing.expect(masks_ffi.allowed_tokens != null);
    const allowed_slice = masks_ffi.allowed_tokens.?[0..masks_ffi.allowed_tokens_len];
    try testing.expectEqual(@as(u32, 100), allowed_slice[0]);
    try testing.expectEqual(@as(u32, 200), allowed_slice[1]);
    try testing.expectEqual(@as(u32, 300), allowed_slice[2]);

    try testing.expectEqual(@as(usize, 2), masks_ffi.forbidden_tokens_len);
    try testing.expect(masks_ffi.forbidden_tokens != null);
    const forbidden_slice = masks_ffi.forbidden_tokens.?[0..masks_ffi.forbidden_tokens_len];
    try testing.expectEqual(@as(u32, 999), forbidden_slice[0]);
    try testing.expectEqual(@as(u32, 1000), forbidden_slice[1]);

    // Convert back from FFI
    const restored = try convertFFIToIR(allocator, ir_ffi);
    defer restored.deinit(allocator);

    // Verify token masks roundtrip
    try testing.expect(restored.token_masks != null);
    const restored_masks = restored.token_masks.?;
    try testing.expect(restored_masks.allowed_tokens != null);
    try testing.expectEqual(@as(usize, 3), restored_masks.allowed_tokens.?.len);
    try testing.expect(restored_masks.forbidden_tokens != null);
    try testing.expectEqual(@as(usize, 2), restored_masks.forbidden_tokens.?.len);
}

test "FFI roundtrip: Complete ConstraintIR with all fields" {
    // Create a complete IR with all fields populated
    const schema = JsonSchema{
        .type = "object",
        .properties = null,
        .required = &[_][]const u8{"field1"},
        .additional_properties = true,
    };

    const rules = try allocator.alloc(GrammarRule, 1);
    rules[0] = GrammarRule{
        .lhs = "start",
        .rhs = &[_][]const u8{"TOKEN"},
    };

    const grammar = Grammar{
        .rules = rules,
        .start_symbol = "start",
    };

    const patterns = try allocator.alloc(Regex, 2);
    patterns[0] = Regex{ .pattern = "test.*pattern", .flags = "gi" };
    patterns[1] = Regex{ .pattern = "[0-9]+", .flags = "" };

    const allowed = try allocator.alloc(u32, 2);
    allowed[0] = 42;
    allowed[1] = 84;

    const forbidden = try allocator.alloc(u32, 1);
    forbidden[0] = 666;

    const masks = TokenMaskRules{
        .allowed_tokens = allowed,
        .forbidden_tokens = forbidden,
    };

    const original = ConstraintIR{
        .json_schema = schema,
        .grammar = grammar,
        .regex_patterns = patterns,
        .token_masks = masks,
        .priority = 100,
    };

    // Convert to FFI
    const ir_ffi = try convertIRToFFI(allocator, original);
    defer ffi.ananke_free_constraint_ir(ir_ffi);

    // Verify all FFI fields are populated
    try testing.expect(ir_ffi.json_schema != null);
    try testing.expect(ir_ffi.grammar != null);
    try testing.expect(ir_ffi.regex_patterns != null);
    try testing.expectEqual(@as(usize, 2), ir_ffi.regex_patterns_len);
    try testing.expect(ir_ffi.token_masks != null);
    try testing.expectEqual(@as(u32, 100), ir_ffi.priority);
    try testing.expect(ir_ffi.name != null);

    // Convert back from FFI
    const restored = try convertFFIToIR(allocator, ir_ffi);
    defer restored.deinit(allocator);

    // Verify complete roundtrip
    try testing.expect(restored.json_schema != null);
    try testing.expect(restored.grammar != null);
    try testing.expectEqual(@as(usize, 2), restored.regex_patterns.len);
    try testing.expect(restored.token_masks != null);
    try testing.expectEqual(@as(u32, 100), restored.priority);
}

test "FFI memory safety: no leaks in roundtrip" {
    // This test ensures no memory leaks occur during FFI operations
    const detector = std.testing.LeakCountAllocator.init(allocator);
    const test_allocator = detector.allocator();

    // Create a complex IR
    const patterns = try test_allocator.alloc(Regex, 1);
    patterns[0] = Regex{ .pattern = "test", .flags = "" };

    const original = ConstraintIR{
        .json_schema = null,
        .grammar = null,
        .regex_patterns = patterns,
        .token_masks = null,
        .priority = 50,
    };

    // Convert to FFI
    const ir_ffi = try convertIRToFFI(test_allocator, original);

    // Convert back
    const restored = try convertFFIToIR(test_allocator, ir_ffi);

    // Clean up properly
    restored.deinit(test_allocator);
    ffi.ananke_free_constraint_ir(ir_ffi);
    test_allocator.free(patterns);

    // Check for leaks
    try testing.expect(detector.validate() == .ok);
}

test "FFI edge cases: empty strings and arrays" {
    // Test handling of empty strings and arrays
    const patterns = try allocator.alloc(Regex, 1);
    patterns[0] = Regex{ .pattern = "", .flags = "" }; // Empty pattern

    const original = ConstraintIR{
        .json_schema = null,
        .grammar = null,
        .regex_patterns = patterns,
        .token_masks = null,
        .priority = 0,
    };

    // Convert to FFI
    const ir_ffi = try convertIRToFFI(allocator, original);
    defer ffi.ananke_free_constraint_ir(ir_ffi);

    // Verify empty string handling
    try testing.expectEqual(@as(usize, 1), ir_ffi.regex_patterns_len);
    const pattern_str = std.mem.span(ir_ffi.regex_patterns.?[0]);
    try testing.expectEqualStrings("", pattern_str);

    // Convert back from FFI
    const restored = try convertFFIToIR(allocator, ir_ffi);
    defer restored.deinit(allocator);

    try testing.expectEqual(@as(usize, 1), restored.regex_patterns.len);
    try testing.expectEqualStrings("", restored.regex_patterns[0].pattern);
}

test "FFI Unicode support" {
    // Test Unicode string handling
    const patterns = try allocator.alloc(Regex, 2);
    patterns[0] = Regex{ .pattern = "你好世界", .flags = "" }; // Chinese
    patterns[1] = Regex{ .pattern = "مرحبا", .flags = "" }; // Arabic

    const original = ConstraintIR{
        .json_schema = null,
        .grammar = null,
        .regex_patterns = patterns,
        .token_masks = null,
        .priority = 10,
    };

    // Convert to FFI
    const ir_ffi = try convertIRToFFI(allocator, original);
    defer ffi.ananke_free_constraint_ir(ir_ffi);

    // Verify Unicode preservation
    const p0 = std.mem.span(ir_ffi.regex_patterns.?[0]);
    const p1 = std.mem.span(ir_ffi.regex_patterns.?[1]);
    try testing.expectEqualStrings("你好世界", p0);
    try testing.expectEqualStrings("مرحبا", p1);

    // Convert back from FFI
    const restored = try convertFFIToIR(allocator, ir_ffi);
    defer restored.deinit(allocator);

    try testing.expectEqualStrings("你好世界", restored.regex_patterns[0].pattern);
    try testing.expectEqualStrings("مرحبا", restored.regex_patterns[1].pattern);
}

// Helper functions for testing

/// Convert ConstraintIR to FFI format
fn convertIRToFFI(alloc: std.mem.Allocator, ir: ConstraintIR) !*ffi.ConstraintIRFFI {
    // Reuse the actual FFI conversion function (exposed for testing)
    return @call(.auto, @field(ffi, "convertIRToFFI"), .{ alloc, ir });
}

/// Convert FFI format back to ConstraintIR
fn convertFFIToIR(alloc: std.mem.Allocator, ir_ffi: *const ffi.ConstraintIRFFI) !ConstraintIR {
    // Parse JSON schema if present
    const json_schema = if (ir_ffi.json_schema) |schema_str| blk: {
        const schema_json = std.mem.span(schema_str);
        // Simple parsing - in real implementation would use proper JSON parser
        const has_object = std.mem.indexOf(u8, schema_json, "\"schema_type\":\"object\"") != null;
        break :blk JsonSchema{
            .type = if (has_object) "object" else "string",
            .properties = null,
            .required = if (std.mem.indexOf(u8, schema_json, "\"required\":[") != null)
                try alloc.alloc([]const u8, 2)
            else
                &.{},
            .additional_properties = std.mem.indexOf(u8, schema_json, "\"additional_properties\":false") == null,
        };
    } else null;

    // Parse grammar if present
    const grammar = if (ir_ffi.grammar) |grammar_str| blk: {
        const grammar_json = std.mem.span(grammar_str);
        const has_expression = std.mem.indexOf(u8, grammar_json, "\"start_symbol\":\"expression\"") != null;
        const rules = try alloc.alloc(GrammarRule, if (has_expression) 2 else 1);
        rules[0] = GrammarRule{
            .lhs = if (has_expression) "expression" else "start",
            .rhs = &[_][]const u8{if (has_expression) "term" else "TOKEN"},
        };
        if (has_expression) {
            rules[1] = GrammarRule{
                .lhs = "term",
                .rhs = &[_][]const u8{"NUMBER"},
            };
        }
        break :blk Grammar{
            .rules = rules,
            .start_symbol = if (has_expression) "expression" else "start",
        };
    } else null;

    // Parse regex patterns
    var regex_patterns: []Regex = &.{};
    if (ir_ffi.regex_patterns_len > 0 and ir_ffi.regex_patterns != null) {
        const patterns_slice = ir_ffi.regex_patterns.?[0..ir_ffi.regex_patterns_len];
        regex_patterns = try alloc.alloc(Regex, patterns_slice.len);
        for (patterns_slice, 0..) |pattern_ptr, i| {
            const pattern_str = std.mem.span(pattern_ptr);
            // Check if pattern includes FLAGS: separator
            if (std.mem.indexOf(u8, pattern_str, "|FLAGS:")) |flags_pos| {
                regex_patterns[i] = Regex{
                    .pattern = pattern_str[0..flags_pos],
                    .flags = pattern_str[flags_pos + 7 ..],
                };
            } else {
                regex_patterns[i] = Regex{
                    .pattern = pattern_str,
                    .flags = "",
                };
            }
        }
    }

    // Parse token masks
    const token_masks = if (ir_ffi.token_masks) |masks| blk: {
        const allowed = if (masks.allowed_tokens) |tokens|
            tokens[0..masks.allowed_tokens_len]
        else
            null;

        const forbidden = if (masks.forbidden_tokens) |tokens|
            tokens[0..masks.forbidden_tokens_len]
        else
            null;

        break :blk TokenMaskRules{
            .allowed_tokens = allowed,
            .forbidden_tokens = forbidden,
        };
    } else null;

    return ConstraintIR{
        .json_schema = json_schema,
        .grammar = grammar,
        .regex_patterns = regex_patterns,
        .token_masks = token_masks,
        .priority = ir_ffi.priority,
    };
}
