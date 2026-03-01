//! Token Mask Generator for Type Inhabitation
//!
//! Converts inhabitation analysis into token masks that can be applied
//! during constrained generation. The masks restrict tokens to only those
//! that can lead to valid typed expressions.

const std = @import("std");
const type_system = @import("type_system.zig");
const inhabitation = @import("inhabitation.zig");
const Type = type_system.Type;
const TypeArena = type_system.TypeArena;
const Language = type_system.Language;
const InhabitationGraph = inhabitation.InhabitationGraph;
const Binding = inhabitation.Binding;

/// Token mask data for ZML consumption
pub const TokenMaskData = struct {
    allowed_tokens: ?[]const u32,
    forbidden_tokens: ?[]const u32,

    pub fn deinit(self: *TokenMaskData, allocator: std.mem.Allocator) void {
        if (self.allowed_tokens) |tokens| {
            allocator.free(tokens);
        }
        if (self.forbidden_tokens) |tokens| {
            allocator.free(tokens);
        }
    }
};

/// Type inhabitation state for progressive generation
pub const TypeInhabitationState = struct {
    current_type: ?*const Type,
    goal_type: *const Type,
    bindings: []const Binding,
    partial_expression: []const u8,
    language: Language,

    /// Serialize to JSON for transmission to ZML
    pub fn toJson(self: *const TypeInhabitationState, allocator: std.mem.Allocator) ![]u8 {
        var json = std.ArrayList(u8){};
        const writer = json.writer(allocator);

        try writer.writeAll("{");

        // current_type
        try writer.writeAll("\"current_type\":");
        if (self.current_type) |ct| {
            try writer.print("\"{s}\"", .{self.typeToString(ct)});
        } else {
            try writer.writeAll("null");
        }

        // goal_type
        try writer.print(",\"goal_type\":\"{s}\"", .{self.typeToString(self.goal_type)});

        // bindings
        try writer.writeAll(",\"bindings\":[");
        for (self.bindings, 0..) |binding, i| {
            if (i > 0) try writer.writeAll(",");
            try writer.print("{{\"name\":\"{s}\",\"type\":\"{s}\"}}", .{
                binding.name,
                self.typeToString(binding.binding_type),
            });
        }
        try writer.writeAll("]");

        // language
        try writer.print(",\"language\":\"{s}\"", .{@tagName(self.language)});

        try writer.writeAll("}");

        return json.toOwnedSlice(allocator);
    }

    fn typeToString(self: *const TypeInhabitationState, t: *const Type) []const u8 {
        _ = self;
        return switch (t.*) {
            .primitive => |p| @tagName(p),
            .named => |n| n.name,
            .array => "array",
            .optional => "optional",
            else => "unknown",
        };
    }
};

/// Interface for tokenizer operations
pub const TokenizerInterface = struct {
    vocab_size: usize,
    decode_fn: *const fn (token_id: u32, ctx: *anyopaque) []const u8,
    encode_fn: *const fn (text: []const u8, ctx: *anyopaque) ?u32,
    ctx: *anyopaque,

    pub fn decode(self: *const TokenizerInterface, token_id: u32) []const u8 {
        return self.decode_fn(token_id, self.ctx);
    }

    pub fn encode(self: *const TokenizerInterface, text: []const u8) ?u32 {
        return self.encode_fn(text, self.ctx);
    }
};

/// Token mask generator using inhabitation analysis
pub const MaskGenerator = struct {
    allocator: std.mem.Allocator,
    graph: *InhabitationGraph,
    tokenizer: ?TokenizerInterface,

    pub fn init(
        allocator: std.mem.Allocator,
        graph: *InhabitationGraph,
    ) MaskGenerator {
        return .{
            .allocator = allocator,
            .graph = graph,
            .tokenizer = null,
        };
    }

    pub fn setTokenizer(self: *MaskGenerator, tokenizer: TokenizerInterface) void {
        self.tokenizer = tokenizer;
    }

    /// Generate a token mask for the given type inhabitation state
    pub fn generateMask(
        self: *MaskGenerator,
        current_type: ?*const Type,
        goal_type: *const Type,
        bindings: []const Binding,
    ) !TokenMaskData {
        // Add bindings to graph
        self.graph.clearBindings();
        for (bindings) |binding| {
            try self.graph.addBinding(binding);
        }

        if (self.tokenizer) |tokenizer| {
            return self.generateMaskWithTokenizer(current_type, goal_type, tokenizer);
        } else {
            // Without tokenizer, return pattern-based hints
            return self.generatePatternBasedMask(current_type, goal_type);
        }
    }

    fn generateMaskWithTokenizer(
        self: *MaskGenerator,
        current_type: ?*const Type,
        goal_type: *const Type,
        tokenizer: TokenizerInterface,
    ) !TokenMaskData {
        var allowed = std.ArrayList(u32).init(self.allocator);
        errdefer allowed.deinit();

        // Iterate through vocabulary
        for (0..tokenizer.vocab_size) |token_id| {
            const token_str = tokenizer.decode(@intCast(token_id));

            if (self.canTokenLeadToGoal(token_str, current_type, goal_type)) {
                try allowed.append(@intCast(token_id));
            }
        }

        return TokenMaskData{
            .allowed_tokens = if (allowed.items.len > 0)
                try allowed.toOwnedSlice()
            else
                null,
            .forbidden_tokens = null,
        };
    }

    fn generatePatternBasedMask(
        self: *MaskGenerator,
        current_type: ?*const Type,
        goal_type: *const Type,
    ) !TokenMaskData {
        // Get valid transitions
        const transitions = self.graph.getValidTransitions(current_type, goal_type);
        defer self.allocator.free(transitions);

        // Collect unique patterns that could be token IDs
        var patterns = std.ArrayList(u32).init(self.allocator);
        defer patterns.deinit();

        // Add special tokens based on language
        const language = self.graph.language;

        // String literal starters
        if (goal_type.* == .primitive and goal_type.primitive == .string) {
            try self.addTokenPatterns(&patterns, "\"'`", language);
        }

        // Number literal starters
        if (goal_type.* == .primitive and goal_type.primitive.isNumeric()) {
            try self.addTokenPatterns(&patterns, "0123456789", language);
        }

        // Boolean literals
        if (goal_type.* == .primitive and goal_type.primitive == .boolean) {
            // Language-specific boolean tokens would be added here
        }

        // Add binding names
        for (self.graph.bindings.items) |binding| {
            if (self.graph.isReachable(binding.binding_type, goal_type)) {
                // Binding name could lead to goal - would need tokenizer to get ID
            }
        }

        // Return patterns as hints (actual token IDs need tokenizer)
        return TokenMaskData{
            .allowed_tokens = null, // Patterns, not actual token IDs
            .forbidden_tokens = null,
        };
    }

    fn addTokenPatterns(
        self: *MaskGenerator,
        patterns: *std.ArrayList(u32),
        chars: []const u8,
        language: Language,
    ) !void {
        _ = self;
        _ = patterns;
        _ = chars;
        _ = language;
        // Would need tokenizer to convert patterns to token IDs
    }

    fn canTokenLeadToGoal(
        self: *MaskGenerator,
        token: []const u8,
        current_type: ?*const Type,
        goal_type: *const Type,
    ) bool {
        // Skip empty or whitespace-only tokens
        if (token.len == 0) return true; // Allow whitespace
        var all_whitespace = true;
        for (token) |c| {
            if (!std.ascii.isWhitespace(c)) {
                all_whitespace = false;
                break;
            }
        }
        if (all_whitespace) return true;

        // Check via inhabitation graph
        return self.graph.canTokenLeadToGoal(token, current_type, goal_type);
    }

    /// Update state after a token is consumed.
    /// This method updates the current_type based on what the token does:
    /// - Identifier: Look up binding type
    /// - Method/property access: Apply transition from graph
    /// - Operator: Apply binary operation rules
    /// - Literal start: Set construction type
    pub fn advanceState(
        self: *MaskGenerator,
        state: *TypeInhabitationState,
        token: []const u8,
    ) void {
        // Skip whitespace tokens
        if (token.len == 0) return;
        var all_whitespace = true;
        for (token) |c| {
            if (!std.ascii.isWhitespace(c)) {
                all_whitespace = false;
                break;
            }
        }
        if (all_whitespace) return;

        // Check if token is a binding name (identifier at start)
        if (state.current_type == null) {
            for (self.graph.bindings.items) |binding| {
                if (std.mem.eql(u8, token, binding.name)) {
                    state.current_type = binding.binding_type;
                    return;
                }
            }

            // Check if token starts a literal
            if (isStringLiteralStart(token, self.graph.language)) {
                state.current_type = self.graph.arena.primitive(.string) catch return;
                return;
            }
            if (isNumberLiteralStart(token)) {
                state.current_type = self.graph.arena.primitive(.number) catch return;
                return;
            }
            if (isBooleanLiteral(token, self.graph.language)) {
                state.current_type = self.graph.arena.primitive(.boolean) catch return;
                return;
            }
        }

        // If we have a current type, check if token triggers a transition
        if (state.current_type) |current| {
            const current_hash = current.hash();
            if (self.graph.edges.get(current_hash)) |edge_list| {
                for (edge_list.items) |edge| {
                    if (self.graph.matchesPattern(token, edge.token_pattern)) {
                        state.current_type = edge.target_type;
                        return;
                    }
                }
            }
        }
    }

    fn isStringLiteralStart(token: []const u8, lang: Language) bool {
        if (token.len == 0) return false;
        const c = token[0];
        return switch (lang) {
            .typescript, .javascript, .rust, .go, .java, .cpp, .csharp, .kotlin, .zig_lang => c == '"' or c == '\'' or c == '`',
            .python => c == '"' or c == '\'' or (token.len >= 2 and token[0] == 'f' and token[1] == '"'),
        };
    }

    fn isNumberLiteralStart(token: []const u8) bool {
        if (token.len == 0) return false;
        const c = token[0];
        return c >= '0' and c <= '9';
    }

    fn isBooleanLiteral(token: []const u8, lang: Language) bool {
        return switch (lang) {
            .python => std.mem.eql(u8, token, "True") or std.mem.eql(u8, token, "False"),
            else => std.mem.eql(u8, token, "true") or std.mem.eql(u8, token, "false"),
        };
    }

    /// Check if the current state can finish (goal type reached)
    pub fn canFinish(_: *MaskGenerator, state: *const TypeInhabitationState) bool {
        if (state.current_type) |ct| {
            return ct.isAssignableTo(state.goal_type, state.language);
        }
        // No current type means we're at the start - can only finish if goal is void/unit
        return state.goal_type.* == .primitive and
            state.goal_type.primitive == .void_type;
    }
};

/// Input binding for buildFromHole
pub const HoleBinding = struct {
    name: []const u8,
    type_annotation: ?[]const u8,
};

/// Builder for creating type inhabitation data from hole information
pub const TypeInhabitationBuilder = struct {
    allocator: std.mem.Allocator,
    arena: *TypeArena,
    language: Language,

    pub fn init(
        allocator: std.mem.Allocator,
        arena: *TypeArena,
        language: Language,
    ) TypeInhabitationBuilder {
        return .{
            .allocator = allocator,
            .arena = arena,
            .language = language,
        };
    }

    /// Build inhabitation data from hole context
    pub fn buildFromHole(
        self: *TypeInhabitationBuilder,
        expected_type: ?[]const u8,
        bindings: []const HoleBinding,
    ) !TypeInhabitationState {
        const parser = @import("parser.zig");

        // Parse goal type
        var type_parser = parser.TypeParser.init(self.arena, self.language);
        const goal = if (expected_type) |et|
            try type_parser.parse(et)
        else
            try self.arena.primitive(.any);

        // Parse bindings
        var parsed_bindings = std.ArrayList(Binding){};
        errdefer parsed_bindings.deinit(self.allocator);

        for (bindings) |binding| {
            const binding_type = if (binding.type_annotation) |ta|
                type_parser.parse(ta) catch try self.arena.primitive(.any)
            else
                try self.arena.primitive(.any);

            try parsed_bindings.append(self.allocator, .{
                .name = binding.name,
                .binding_type = binding_type,
            });
        }

        return TypeInhabitationState{
            .current_type = null,
            .goal_type = goal,
            .bindings = try parsed_bindings.toOwnedSlice(self.allocator),
            .partial_expression = "",
            .language = self.language,
        };
    }
};

// ============================================================================
// Tests
// ============================================================================

test "MaskGenerator - basic creation" {
    var arena = TypeArena.init(std.testing.allocator);
    defer arena.deinit();

    var graph = InhabitationGraph.init(std.testing.allocator, &arena, .typescript);
    defer graph.deinit();
    try graph.addBuiltinEdges();

    const gen = MaskGenerator.init(std.testing.allocator, &graph);
    _ = gen;
}

test "TypeInhabitationState - toJson" {
    var arena = TypeArena.init(std.testing.allocator);
    defer arena.deinit();

    const str_type = try arena.primitive(.string);
    const num_type = try arena.primitive(.number);

    const bindings = [_]Binding{
        .{ .name = "x", .binding_type = num_type },
    };

    const state = TypeInhabitationState{
        .current_type = num_type,
        .goal_type = str_type,
        .bindings = &bindings,
        .partial_expression = "",
        .language = .typescript,
    };

    const json = try state.toJson(std.testing.allocator);
    defer std.testing.allocator.free(json);

    // Verify JSON contains expected fields
    try std.testing.expect(std.mem.containsAtLeast(u8, json, 1, "\"goal_type\""));
    try std.testing.expect(std.mem.containsAtLeast(u8, json, 1, "\"bindings\""));
}

test "TypeInhabitationBuilder - buildFromHole" {
    var arena = TypeArena.init(std.testing.allocator);
    defer arena.deinit();

    var builder = TypeInhabitationBuilder.init(std.testing.allocator, &arena, .typescript);

    const bindings = [_]struct { name: []const u8, type_annotation: ?[]const u8 }{
        .{ .name = "x", .type_annotation = "number" },
    };

    const state = try builder.buildFromHole("string", &bindings);
    defer std.testing.allocator.free(state.bindings);

    try std.testing.expect(state.goal_type.* == .primitive);
    try std.testing.expect(state.goal_type.primitive == .string);
    try std.testing.expect(state.bindings.len == 1);
}

test "MaskGenerator - advanceState with binding" {
    var arena = TypeArena.init(std.testing.allocator);
    defer arena.deinit();

    var graph = InhabitationGraph.init(std.testing.allocator, &arena, .typescript);
    defer graph.deinit();
    try graph.addBuiltinEdges();

    const num_type = try arena.primitive(.number);
    const str_type = try arena.primitive(.string);

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

    // Advance with binding name "x"
    gen.advanceState(&state, "x");

    // State should now have current_type = number
    try std.testing.expect(state.current_type != null);
    try std.testing.expect(state.current_type.?.* == .primitive);
    try std.testing.expect(state.current_type.?.primitive == .number);
}

test "MaskGenerator - advanceState with method call" {
    var arena = TypeArena.init(std.testing.allocator);
    defer arena.deinit();

    var graph = InhabitationGraph.init(std.testing.allocator, &arena, .typescript);
    defer graph.deinit();
    try graph.addBuiltinEdges();

    const num_type = try arena.primitive(.number);
    const str_type = try arena.primitive(.string);

    try graph.addBinding(.{ .name = "x", .binding_type = num_type });

    var gen = MaskGenerator.init(std.testing.allocator, &graph);

    const bindings = [_]Binding{
        .{ .name = "x", .binding_type = num_type },
    };

    var state = TypeInhabitationState{
        .current_type = num_type,
        .goal_type = str_type,
        .bindings = &bindings,
        .partial_expression = "x",
        .language = .typescript,
    };

    // Advance with toString method
    gen.advanceState(&state, ".toString()");

    // State should now have current_type = string
    try std.testing.expect(state.current_type != null);
    try std.testing.expect(state.current_type.?.* == .primitive);
    try std.testing.expect(state.current_type.?.primitive == .string);
}

test "MaskGenerator - advanceState with literal" {
    var arena = TypeArena.init(std.testing.allocator);
    defer arena.deinit();

    var graph = InhabitationGraph.init(std.testing.allocator, &arena, .typescript);
    defer graph.deinit();
    try graph.addBuiltinEdges();

    const str_type = try arena.primitive(.string);

    var gen = MaskGenerator.init(std.testing.allocator, &graph);

    var state = TypeInhabitationState{
        .current_type = null,
        .goal_type = str_type,
        .bindings = &.{},
        .partial_expression = "",
        .language = .typescript,
    };

    // Advance with string literal start
    gen.advanceState(&state, "\"");

    // State should now have current_type = string
    try std.testing.expect(state.current_type != null);
    try std.testing.expect(state.current_type.?.* == .primitive);
    try std.testing.expect(state.current_type.?.primitive == .string);
}

test "MaskGenerator - canFinish" {
    var arena = TypeArena.init(std.testing.allocator);
    defer arena.deinit();

    var graph = InhabitationGraph.init(std.testing.allocator, &arena, .typescript);
    defer graph.deinit();
    try graph.addBuiltinEdges();

    const num_type = try arena.primitive(.number);
    const str_type = try arena.primitive(.string);

    var gen = MaskGenerator.init(std.testing.allocator, &graph);

    // Can't finish when current doesn't match goal
    const state_not_finished = TypeInhabitationState{
        .current_type = num_type,
        .goal_type = str_type,
        .bindings = &.{},
        .partial_expression = "x",
        .language = .typescript,
    };
    try std.testing.expect(!gen.canFinish(&state_not_finished));

    // Can finish when current matches goal
    const state_finished = TypeInhabitationState{
        .current_type = str_type,
        .goal_type = str_type,
        .bindings = &.{},
        .partial_expression = "x.toString()",
        .language = .typescript,
    };
    try std.testing.expect(gen.canFinish(&state_finished));
}

test "MaskGenerator - generateMask with bindings" {
    var arena = TypeArena.init(std.testing.allocator);
    defer arena.deinit();

    var graph = InhabitationGraph.init(std.testing.allocator, &arena, .typescript);
    defer graph.deinit();
    try graph.addBuiltinEdges();

    const num_type = try arena.primitive(.number);
    const str_type = try arena.primitive(.string);

    var gen = MaskGenerator.init(std.testing.allocator, &graph);

    const bindings = [_]Binding{
        .{ .name = "x", .binding_type = num_type },
    };

    // Generate mask for getting string from number binding
    const mask = try gen.generateMask(null, str_type, &bindings);

    // Without tokenizer, mask is pattern-based (null allowed/forbidden)
    // Just verify no error
    _ = mask;
}
