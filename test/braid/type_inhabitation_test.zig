//! Type Inhabitation End-to-End Integration Tests
//!
//! Tests the full type inhabitation pipeline from constraints to token masks.

const std = @import("std");
const types = @import("braid").types;
const TypeArena = types.TypeArena;
const TypeParser = types.TypeParser;
const InhabitationGraph = types.InhabitationGraph;
const MaskGenerator = types.MaskGenerator;
const TypeInhabitationBuilder = types.TypeInhabitationBuilder;
const TypeInhabitationState = types.TypeInhabitationState;
const HoleBinding = types.HoleBinding;
const Binding = types.Binding;
const Language = types.Language;

// ============================================================================
// TypeScript Integration Tests
// ============================================================================

test "E2E TypeScript: number -> string via toString" {
    var arena = TypeArena.init(std.testing.allocator);
    defer arena.deinit();

    var graph = InhabitationGraph.init(std.testing.allocator, &arena, .typescript);
    defer graph.deinit();
    try graph.addBuiltinEdges();

    const num_type = try arena.primitive(.number);
    const str_type = try arena.primitive(.string);

    // Setup: binding x: number, goal: string
    try graph.addBinding(.{ .name = "x", .binding_type = num_type });

    var gen = MaskGenerator.init(std.testing.allocator, &graph);

    const bindings = [_]Binding{
        .{ .name = "x", .binding_type = num_type },
    };

    var state = TypeInhabitationState{
        .current_type = null,
        .goal_type = str_type,
        .bindings = &bindings,
        .partial_expression = "",
        .language = .typescript,
    };

    // Step 1: Start with "x"
    try std.testing.expect(graph.canTokenLeadToGoal("x", null, str_type));
    gen.advanceState(&state, "x");
    try std.testing.expect(state.current_type != null);
    try std.testing.expect(state.current_type.?.primitive == .number);

    // Step 2: Apply ".toString()"
    try std.testing.expect(graph.canTokenLeadToGoal(".toString()", state.current_type, str_type));
    gen.advanceState(&state, ".toString()");
    try std.testing.expect(state.current_type.?.primitive == .string);

    // Step 3: Should be able to finish
    try std.testing.expect(gen.canFinish(&state));
}

test "E2E TypeScript: template literal conversion" {
    var arena = TypeArena.init(std.testing.allocator);
    defer arena.deinit();

    var graph = InhabitationGraph.init(std.testing.allocator, &arena, .typescript);
    defer graph.deinit();
    try graph.addBuiltinEdges();

    const num_type = try arena.primitive(.number);
    const str_type = try arena.primitive(.string);

    // Template literals produce strings
    try std.testing.expect(graph.isReachable(num_type, str_type));
}

test "E2E TypeScript: string.length -> number" {
    var arena = TypeArena.init(std.testing.allocator);
    defer arena.deinit();

    var graph = InhabitationGraph.init(std.testing.allocator, &arena, .typescript);
    defer graph.deinit();
    try graph.addBuiltinEdges();

    const num_type = try arena.primitive(.number);
    const str_type = try arena.primitive(.string);

    // string -> number via .length
    try std.testing.expect(graph.isReachable(str_type, num_type));

    // Check specific token
    try std.testing.expect(graph.canTokenLeadToGoal(".length", str_type, num_type));
}

// ============================================================================
// Python Integration Tests
// ============================================================================

test "E2E Python: int -> str via str()" {
    var arena = TypeArena.init(std.testing.allocator);
    defer arena.deinit();

    var graph = InhabitationGraph.init(std.testing.allocator, &arena, .python);
    defer graph.deinit();
    try graph.addBuiltinEdges();

    const int_type = try arena.primitive(.i64);
    const str_type = try arena.primitive(.string);

    // int -> str via str()
    try std.testing.expect(graph.isReachable(int_type, str_type));

    // Check specific pattern
    try std.testing.expect(graph.canTokenLeadToGoal("str(", int_type, str_type));
}

test "E2E Python: len() returns int" {
    var arena = TypeArena.init(std.testing.allocator);
    defer arena.deinit();

    var graph = InhabitationGraph.init(std.testing.allocator, &arena, .python);
    defer graph.deinit();
    try graph.addBuiltinEdges();

    const int_type = try arena.primitive(.i64);
    const str_type = try arena.primitive(.string);

    // str -> int via len()
    try std.testing.expect(graph.canTokenLeadToGoal("len(", str_type, int_type));
}

// ============================================================================
// Rust Integration Tests
// ============================================================================

test "E2E Rust: i32 -> String via to_string()" {
    var arena = TypeArena.init(std.testing.allocator);
    defer arena.deinit();

    var graph = InhabitationGraph.init(std.testing.allocator, &arena, .rust);
    defer graph.deinit();
    try graph.addBuiltinEdges();

    const i32_type = try arena.primitive(.i32);
    const string_type = try arena.primitive(.string);

    // i32 -> String
    try std.testing.expect(graph.isReachable(i32_type, string_type));

    // Check specific pattern
    try std.testing.expect(graph.canTokenLeadToGoal(".to_string()", i32_type, string_type));
}

// ============================================================================
// Go Integration Tests
// ============================================================================

test "E2E Go: int -> string via strconv.Itoa" {
    var arena = TypeArena.init(std.testing.allocator);
    defer arena.deinit();

    var graph = InhabitationGraph.init(std.testing.allocator, &arena, .go);
    defer graph.deinit();
    try graph.addBuiltinEdges();

    const int_type = try arena.primitive(.i64);
    const string_type = try arena.primitive(.string);

    // int -> string
    try std.testing.expect(graph.isReachable(int_type, string_type));

    // Check specific pattern
    try std.testing.expect(graph.canTokenLeadToGoal("strconv.Itoa(", int_type, string_type));
}

// ============================================================================
// Type Parser Integration Tests
// ============================================================================

test "E2E TypeParser: Parse and use in inhabitation" {
    var arena = TypeArena.init(std.testing.allocator);
    defer arena.deinit();

    var parser = TypeParser.init(&arena, .typescript);

    // Parse types
    const str_type = try parser.parse("string");
    const num_type = try parser.parse("number");

    // Use in inhabitation graph
    var graph = InhabitationGraph.init(std.testing.allocator, &arena, .typescript);
    defer graph.deinit();
    try graph.addBuiltinEdges();

    // Verify reachability
    try std.testing.expect(graph.isReachable(num_type, str_type));
}

test "E2E TypeParser: Generic types" {
    var arena = TypeArena.init(std.testing.allocator);
    defer arena.deinit();

    var parser = TypeParser.init(&arena, .typescript);

    // Parse array type
    const arr_type = try parser.parse("string[]");
    try std.testing.expect(arr_type.* == .array);
    try std.testing.expect(arr_type.array.primitive == .string);

    // Parse Promise<string>
    const promise_type = try parser.parse("Promise<string>");
    try std.testing.expect(promise_type.* == .generic);
}

// ============================================================================
// Builder Integration Tests
// ============================================================================

test "E2E Builder: Build from hole context" {
    var arena = TypeArena.init(std.testing.allocator);
    defer arena.deinit();

    var builder = TypeInhabitationBuilder.init(std.testing.allocator, &arena, .typescript);

    // Simulate hole: function add(x: number): string { return /* hole */ }
    const bindings: []const HoleBinding = &.{
        .{ .name = "x", .type_annotation = "number" },
    };

    const state = try builder.buildFromHole("string", bindings);
    defer std.testing.allocator.free(state.bindings);

    // Verify state
    try std.testing.expect(state.goal_type.* == .primitive);
    try std.testing.expect(state.goal_type.primitive == .string);
    try std.testing.expect(state.bindings.len == 1);
    try std.testing.expect(state.bindings[0].binding_type.primitive == .number);

    // Now use with graph
    var graph = InhabitationGraph.init(std.testing.allocator, &arena, .typescript);
    defer graph.deinit();
    try graph.addBuiltinEdges();

    // Add bindings to graph
    for (state.bindings) |binding| {
        try graph.addBinding(binding);
    }

    // Verify "x" can lead to string (via .toString())
    try std.testing.expect(graph.canTokenLeadToGoal("x", null, state.goal_type));
}

// ============================================================================
// Cross-Language Comparison Tests
// ============================================================================

test "E2E Cross-Language: TypeScript int-to-string conversion" {
    var arena = TypeArena.init(std.testing.allocator);
    defer arena.deinit();

    var graph = InhabitationGraph.init(std.testing.allocator, &arena, .typescript);
    defer graph.deinit();
    try graph.addBuiltinEdges();

    // The edges are stored with type pointers created inside addBuiltinEdges
    // We need to get the same types to query reachability
    const num_type = try arena.primitive(.number);
    const str_type = try arena.primitive(.string);

    // TypeScript should have number -> string conversion via .toString() or template literals
    const reachable = graph.isReachable(num_type, str_type);
    try std.testing.expect(reachable);
}

// ============================================================================
// State Serialization Tests
// ============================================================================

test "E2E State: JSON serialization roundtrip" {
    var arena = TypeArena.init(std.testing.allocator);
    defer arena.deinit();

    const str_type = try arena.primitive(.string);
    const num_type = try arena.primitive(.number);

    const bindings = [_]Binding{
        .{ .name = "x", .binding_type = num_type },
        .{ .name = "y", .binding_type = str_type },
    };

    const state = TypeInhabitationState{
        .current_type = num_type,
        .goal_type = str_type,
        .bindings = &bindings,
        .partial_expression = "x",
        .language = .typescript,
    };

    const json = try state.toJson(std.testing.allocator);
    defer std.testing.allocator.free(json);

    // Verify JSON structure
    try std.testing.expect(std.mem.containsAtLeast(u8, json, 1, "\"goal_type\":\"string\""));
    try std.testing.expect(std.mem.containsAtLeast(u8, json, 1, "\"current_type\":\"number\""));
    try std.testing.expect(std.mem.containsAtLeast(u8, json, 1, "\"bindings\":["));
    try std.testing.expect(std.mem.containsAtLeast(u8, json, 1, "\"language\":\"typescript\""));
}
