//! Type Inhabitation Graph
//!
//! Implements reachability analysis for type-constrained code generation.
//! The graph represents how expressions of one type can be transformed into
//! expressions of another type through various operations (method calls,
//! property access, operators, etc.).

const std = @import("std");
const type_system = @import("type_system.zig");
const Type = type_system.Type;
const TypeArena = type_system.TypeArena;
const PrimitiveKind = type_system.PrimitiveKind;
const Language = type_system.Language;

/// Kinds of edges in the inhabitation graph
pub const EdgeKind = enum {
    /// Implicit type conversion (e.g., int -> float)
    coercion,
    /// Binary operator (e.g., number + number -> number)
    binary_op,
    /// Property access (e.g., string.length -> number)
    property,
    /// Method call (e.g., number.toString() -> string)
    method,
    /// Function application
    application,
    /// Array/object indexing (e.g., array[0] -> element)
    indexing,
    /// Literal construction (e.g., "..." -> string)
    construction,
    /// Template literal (e.g., `${x}` -> string)
    template,
    /// Type assertion/cast
    assertion,
};

/// An edge in the inhabitation graph
pub const Edge = struct {
    kind: EdgeKind,
    target_type: *const Type,
    /// Token pattern that triggers this edge (regex or literal)
    token_pattern: []const u8,
    /// Optional description for debugging
    description: []const u8 = "",
    /// Priority for conflict resolution (higher = preferred)
    priority: u8 = 0,
};

/// A binding available in scope
pub const Binding = struct {
    name: []const u8,
    binding_type: *const Type,
};

/// Type inhabitation graph for reachability analysis
pub const InhabitationGraph = struct {
    allocator: std.mem.Allocator,
    arena: *TypeArena,
    language: Language,
    /// Edges from source type hash to list of edges
    edges: std.AutoHashMap(u64, std.ArrayList(Edge)),
    /// Cache for reachability queries
    reachability_cache: std.AutoHashMap(TypePair, bool),
    /// Bindings available in current scope
    bindings: std.ArrayList(Binding),

    const TypePair = struct {
        source_hash: u64,
        target_hash: u64,
    };

    pub fn init(allocator: std.mem.Allocator, arena: *TypeArena, language: Language) InhabitationGraph {
        return .{
            .allocator = allocator,
            .arena = arena,
            .language = language,
            .edges = std.AutoHashMap(u64, std.ArrayList(Edge)).init(allocator),
            .reachability_cache = std.AutoHashMap(TypePair, bool).init(allocator),
            .bindings = std.ArrayList(Binding){},
        };
    }

    pub fn deinit(self: *InhabitationGraph) void {
        var edge_iter = self.edges.valueIterator();
        while (edge_iter.next()) |edge_list| {
            edge_list.deinit(self.allocator);
        }
        self.edges.deinit();
        self.reachability_cache.deinit();
        self.bindings.deinit(self.allocator);
    }

    /// Add built-in type conversion edges for the current language
    pub fn addBuiltinEdges(self: *InhabitationGraph) !void {
        switch (self.language) {
            .typescript, .javascript => try self.addTypeScriptEdges(),
            .python => try self.addPythonEdges(),
            .rust => try self.addRustEdges(),
            .go => try self.addGoEdges(),
            .java => try self.addJavaEdges(),
            .cpp => try self.addCppEdges(),
            .csharp => try self.addCSharpEdges(),
            .kotlin => try self.addKotlinEdges(),
            .zig_lang => try self.addZigEdges(),
        }
    }

    fn addTypeScriptEdges(self: *InhabitationGraph) !void {
        const str_type = try self.arena.primitive(.string);
        const num_type = try self.arena.primitive(.number);
        const bool_type = try self.arena.primitive(.boolean);

        // number -> string conversions
        try self.addEdge(num_type, .{
            .kind = .method,
            .target_type = str_type,
            .token_pattern = ".toString()",
            .description = "number.toString()",
        });
        try self.addEdge(num_type, .{
            .kind = .method,
            .target_type = str_type,
            .token_pattern = ".toFixed(",
            .description = "number.toFixed()",
        });
        try self.addEdge(num_type, .{
            .kind = .application,
            .target_type = str_type,
            .token_pattern = "String(",
            .description = "String(number)",
        });
        try self.addEdge(num_type, .{
            .kind = .template,
            .target_type = str_type,
            .token_pattern = "`${",
            .description = "template literal",
        });

        // string -> number conversions
        try self.addEdge(str_type, .{
            .kind = .property,
            .target_type = num_type,
            .token_pattern = ".length",
            .description = "string.length",
        });
        try self.addEdge(str_type, .{
            .kind = .application,
            .target_type = num_type,
            .token_pattern = "parseInt(",
            .description = "parseInt(string)",
        });
        try self.addEdge(str_type, .{
            .kind = .application,
            .target_type = num_type,
            .token_pattern = "parseFloat(",
            .description = "parseFloat(string)",
        });
        try self.addEdge(str_type, .{
            .kind = .application,
            .target_type = num_type,
            .token_pattern = "Number(",
            .description = "Number(string)",
        });

        // boolean -> string
        try self.addEdge(bool_type, .{
            .kind = .method,
            .target_type = str_type,
            .token_pattern = ".toString()",
            .description = "boolean.toString()",
        });
        try self.addEdge(bool_type, .{
            .kind = .application,
            .target_type = str_type,
            .token_pattern = "String(",
            .description = "String(boolean)",
        });

        // any -> number (unary +)
        try self.addEdge(str_type, .{
            .kind = .coercion,
            .target_type = num_type,
            .token_pattern = "+",
            .description = "unary + coercion",
        });

        // Binary operators
        try self.addEdge(num_type, .{
            .kind = .binary_op,
            .target_type = num_type,
            .token_pattern = " + ",
            .description = "number + number",
        });
        try self.addEdge(num_type, .{
            .kind = .binary_op,
            .target_type = num_type,
            .token_pattern = " - ",
            .description = "number - number",
        });
        try self.addEdge(num_type, .{
            .kind = .binary_op,
            .target_type = num_type,
            .token_pattern = " * ",
            .description = "number * number",
        });
        try self.addEdge(num_type, .{
            .kind = .binary_op,
            .target_type = num_type,
            .token_pattern = " / ",
            .description = "number / number",
        });

        // Comparisons -> boolean
        try self.addEdge(num_type, .{
            .kind = .binary_op,
            .target_type = bool_type,
            .token_pattern = " > ",
            .description = "comparison",
        });
        try self.addEdge(num_type, .{
            .kind = .binary_op,
            .target_type = bool_type,
            .token_pattern = " < ",
            .description = "comparison",
        });
        try self.addEdge(num_type, .{
            .kind = .binary_op,
            .target_type = bool_type,
            .token_pattern = " === ",
            .description = "strict equality",
        });

        // String concatenation
        try self.addEdge(str_type, .{
            .kind = .binary_op,
            .target_type = str_type,
            .token_pattern = " + ",
            .description = "string concatenation",
            .priority = 1,
        });

        // Literal constructions
        try self.addConstructionEdges(str_type, "\"");
        try self.addConstructionEdges(str_type, "'");
        try self.addConstructionEdges(str_type, "`");
        try self.addConstructionEdges(num_type, "0123456789");
        try self.addConstructionEdges(bool_type, "true");
        try self.addConstructionEdges(bool_type, "false");
    }

    fn addPythonEdges(self: *InhabitationGraph) !void {
        const str_type = try self.arena.primitive(.string);
        const int_type = try self.arena.primitive(.i64);
        const float_type = try self.arena.primitive(.f64);
        const bool_type = try self.arena.primitive(.boolean);

        // int -> str
        try self.addEdge(int_type, .{
            .kind = .application,
            .target_type = str_type,
            .token_pattern = "str(",
            .description = "str(int)",
        });

        // float -> str
        try self.addEdge(float_type, .{
            .kind = .application,
            .target_type = str_type,
            .token_pattern = "str(",
            .description = "str(float)",
        });

        // str -> int
        try self.addEdge(str_type, .{
            .kind = .application,
            .target_type = int_type,
            .token_pattern = "int(",
            .description = "int(str)",
        });

        // str -> float
        try self.addEdge(str_type, .{
            .kind = .application,
            .target_type = float_type,
            .token_pattern = "float(",
            .description = "float(str)",
        });

        // str.len
        try self.addEdge(str_type, .{
            .kind = .application,
            .target_type = int_type,
            .token_pattern = "len(",
            .description = "len(str)",
        });

        // f-strings
        try self.addEdge(int_type, .{
            .kind = .template,
            .target_type = str_type,
            .token_pattern = "f\"{",
            .description = "f-string",
        });

        // Literals
        try self.addConstructionEdges(str_type, "\"");
        try self.addConstructionEdges(str_type, "'");
        try self.addConstructionEdges(int_type, "0123456789");
        try self.addConstructionEdges(bool_type, "True");
        try self.addConstructionEdges(bool_type, "False");
    }

    fn addRustEdges(self: *InhabitationGraph) !void {
        const string_type = try self.arena.primitive(.string);
        const i32_type = try self.arena.primitive(.i32);
        const f64_type = try self.arena.primitive(.f64);
        const bool_type = try self.arena.primitive(.boolean);

        // i32 -> String
        try self.addEdge(i32_type, .{
            .kind = .method,
            .target_type = string_type,
            .token_pattern = ".to_string()",
            .description = "i32.to_string()",
        });

        // String -> i32
        try self.addEdge(string_type, .{
            .kind = .method,
            .target_type = i32_type,
            .token_pattern = ".parse()",
            .description = "str.parse::<i32>()",
        });

        // String.len()
        try self.addEdge(string_type, .{
            .kind = .method,
            .target_type = try self.arena.primitive(.u64),
            .token_pattern = ".len()",
            .description = "String.len()",
        });

        // format! macro
        try self.addEdge(i32_type, .{
            .kind = .application,
            .target_type = string_type,
            .token_pattern = "format!(",
            .description = "format! macro",
        });

        // Literals
        try self.addConstructionEdges(string_type, "\"");
        try self.addConstructionEdges(i32_type, "0123456789");
        try self.addConstructionEdges(f64_type, "0123456789.");
        try self.addConstructionEdges(bool_type, "true");
        try self.addConstructionEdges(bool_type, "false");
    }

    fn addGoEdges(self: *InhabitationGraph) !void {
        const string_type = try self.arena.primitive(.string);
        const int_type = try self.arena.primitive(.i64);
        const float_type = try self.arena.primitive(.f64);
        const bool_type = try self.arena.primitive(.boolean);

        // int -> string
        try self.addEdge(int_type, .{
            .kind = .application,
            .target_type = string_type,
            .token_pattern = "strconv.Itoa(",
            .description = "strconv.Itoa",
        });
        try self.addEdge(int_type, .{
            .kind = .application,
            .target_type = string_type,
            .token_pattern = "fmt.Sprintf(",
            .description = "fmt.Sprintf",
        });

        // string -> int
        try self.addEdge(string_type, .{
            .kind = .application,
            .target_type = int_type,
            .token_pattern = "strconv.Atoi(",
            .description = "strconv.Atoi",
        });

        // len()
        try self.addEdge(string_type, .{
            .kind = .application,
            .target_type = int_type,
            .token_pattern = "len(",
            .description = "len(string)",
        });

        // Literals
        try self.addConstructionEdges(string_type, "\"");
        try self.addConstructionEdges(int_type, "0123456789");
        try self.addConstructionEdges(float_type, "0123456789.");
        try self.addConstructionEdges(bool_type, "true");
        try self.addConstructionEdges(bool_type, "false");
    }

    fn addJavaEdges(self: *InhabitationGraph) !void {
        const string_type = try self.arena.primitive(.string);
        const int_type = try self.arena.primitive(.i32);
        const double_type = try self.arena.primitive(.f64);
        const bool_type = try self.arena.primitive(.boolean);

        // int -> String
        try self.addEdge(int_type, .{
            .kind = .application,
            .target_type = string_type,
            .token_pattern = "String.valueOf(",
            .description = "String.valueOf(int)",
        });
        try self.addEdge(int_type, .{
            .kind = .application,
            .target_type = string_type,
            .token_pattern = "Integer.toString(",
            .description = "Integer.toString",
        });

        // String -> int
        try self.addEdge(string_type, .{
            .kind = .application,
            .target_type = int_type,
            .token_pattern = "Integer.parseInt(",
            .description = "Integer.parseInt",
        });

        // String.length()
        try self.addEdge(string_type, .{
            .kind = .method,
            .target_type = int_type,
            .token_pattern = ".length()",
            .description = "String.length()",
        });

        // Literals
        try self.addConstructionEdges(string_type, "\"");
        try self.addConstructionEdges(int_type, "0123456789");
        try self.addConstructionEdges(double_type, "0123456789.");
        try self.addConstructionEdges(bool_type, "true");
        try self.addConstructionEdges(bool_type, "false");
    }

    fn addCppEdges(self: *InhabitationGraph) !void {
        const string_type = try self.arena.primitive(.string);
        const int_type = try self.arena.primitive(.i32);
        const double_type = try self.arena.primitive(.f64);
        const bool_type = try self.arena.primitive(.boolean);

        // int -> string
        try self.addEdge(int_type, .{
            .kind = .application,
            .target_type = string_type,
            .token_pattern = "std::to_string(",
            .description = "std::to_string",
        });

        // string -> int
        try self.addEdge(string_type, .{
            .kind = .application,
            .target_type = int_type,
            .token_pattern = "std::stoi(",
            .description = "std::stoi",
        });

        // string.length()
        try self.addEdge(string_type, .{
            .kind = .method,
            .target_type = try self.arena.primitive(.u64),
            .token_pattern = ".length()",
            .description = "string.length()",
        });

        // Literals
        try self.addConstructionEdges(string_type, "\"");
        try self.addConstructionEdges(int_type, "0123456789");
        try self.addConstructionEdges(double_type, "0123456789.");
        try self.addConstructionEdges(bool_type, "true");
        try self.addConstructionEdges(bool_type, "false");
    }

    fn addCSharpEdges(self: *InhabitationGraph) !void {
        const string_type = try self.arena.primitive(.string);
        const int_type = try self.arena.primitive(.i32);
        const double_type = try self.arena.primitive(.f64);
        const bool_type = try self.arena.primitive(.boolean);

        // int -> string
        try self.addEdge(int_type, .{
            .kind = .method,
            .target_type = string_type,
            .token_pattern = ".ToString()",
            .description = "int.ToString()",
        });

        // string -> int
        try self.addEdge(string_type, .{
            .kind = .application,
            .target_type = int_type,
            .token_pattern = "int.Parse(",
            .description = "int.Parse",
        });

        // string.Length
        try self.addEdge(string_type, .{
            .kind = .property,
            .target_type = int_type,
            .token_pattern = ".Length",
            .description = "string.Length",
        });

        // String interpolation
        try self.addEdge(int_type, .{
            .kind = .template,
            .target_type = string_type,
            .token_pattern = "$\"{",
            .description = "string interpolation",
        });

        // Literals
        try self.addConstructionEdges(string_type, "\"");
        try self.addConstructionEdges(int_type, "0123456789");
        try self.addConstructionEdges(double_type, "0123456789.");
        try self.addConstructionEdges(bool_type, "true");
        try self.addConstructionEdges(bool_type, "false");
    }

    fn addKotlinEdges(self: *InhabitationGraph) !void {
        const string_type = try self.arena.primitive(.string);
        const int_type = try self.arena.primitive(.i32);
        const double_type = try self.arena.primitive(.f64);
        const bool_type = try self.arena.primitive(.boolean);

        // Int -> String
        try self.addEdge(int_type, .{
            .kind = .method,
            .target_type = string_type,
            .token_pattern = ".toString()",
            .description = "Int.toString()",
        });

        // String -> Int
        try self.addEdge(string_type, .{
            .kind = .method,
            .target_type = int_type,
            .token_pattern = ".toInt()",
            .description = "String.toInt()",
        });

        // String.length
        try self.addEdge(string_type, .{
            .kind = .property,
            .target_type = int_type,
            .token_pattern = ".length",
            .description = "String.length",
        });

        // String templates
        try self.addEdge(int_type, .{
            .kind = .template,
            .target_type = string_type,
            .token_pattern = "\"$",
            .description = "string template",
        });

        // Literals
        try self.addConstructionEdges(string_type, "\"");
        try self.addConstructionEdges(int_type, "0123456789");
        try self.addConstructionEdges(double_type, "0123456789.");
        try self.addConstructionEdges(bool_type, "true");
        try self.addConstructionEdges(bool_type, "false");
    }

    fn addZigEdges(self: *InhabitationGraph) !void {
        const string_type = try self.arena.primitive(.string);
        const i32_type = try self.arena.primitive(.i32);
        const f64_type = try self.arena.primitive(.f64);
        const bool_type = try self.arena.primitive(.boolean);

        // int -> string via std.fmt
        try self.addEdge(i32_type, .{
            .kind = .application,
            .target_type = string_type,
            .token_pattern = "std.fmt.allocPrint(",
            .description = "std.fmt.allocPrint",
        });

        // string -> int via std.fmt
        try self.addEdge(string_type, .{
            .kind = .application,
            .target_type = i32_type,
            .token_pattern = "std.fmt.parseInt(",
            .description = "std.fmt.parseInt",
        });

        // .len
        try self.addEdge(string_type, .{
            .kind = .property,
            .target_type = try self.arena.primitive(.u64),
            .token_pattern = ".len",
            .description = "slice.len",
        });

        // Literals
        try self.addConstructionEdges(string_type, "\"");
        try self.addConstructionEdges(i32_type, "0123456789");
        try self.addConstructionEdges(f64_type, "0123456789.");
        try self.addConstructionEdges(bool_type, "true");
        try self.addConstructionEdges(bool_type, "false");
    }

    fn addConstructionEdges(self: *InhabitationGraph, target: *const Type, pattern: []const u8) !void {
        // Construction from "any" or "start" position
        const any_type = try self.arena.primitive(.any);
        try self.addEdge(any_type, .{
            .kind = .construction,
            .target_type = target,
            .token_pattern = pattern,
            .description = "literal construction",
        });
    }

    /// Add an edge from source type to a transition
    pub fn addEdge(self: *InhabitationGraph, source: *const Type, edge: Edge) !void {
        const source_hash = source.hash();

        var edge_list = self.edges.getPtr(source_hash) orelse blk: {
            try self.edges.put(source_hash, std.ArrayList(Edge){});
            break :blk self.edges.getPtr(source_hash).?;
        };

        try edge_list.append(self.allocator, edge);

        // Invalidate cache
        self.reachability_cache.clearRetainingCapacity();
    }

    /// Add a binding to the scope
    pub fn addBinding(self: *InhabitationGraph, binding: Binding) !void {
        try self.bindings.append(self.allocator, binding);
    }

    /// Clear all bindings
    pub fn clearBindings(self: *InhabitationGraph) void {
        self.bindings.clearRetainingCapacity();
    }

    /// Check if target type is reachable from source type
    pub fn isReachable(self: *InhabitationGraph, source: *const Type, target: *const Type) bool {
        // Same type is always reachable
        if (source.eql(target)) return true;

        // Check cache
        const pair = TypePair{
            .source_hash = source.hash(),
            .target_hash = target.hash(),
        };
        if (self.reachability_cache.get(pair)) |cached| {
            return cached;
        }

        // BFS to find path
        var visited = std.AutoHashMap(u64, void).init(self.allocator);
        defer visited.deinit();

        var queue = std.ArrayList(*const Type){};
        defer queue.deinit(self.allocator);

        queue.append(self.allocator, source) catch return false;
        visited.put(source.hash(), {}) catch return false;

        while (queue.items.len > 0) {
            const current = queue.orderedRemove(0);

            // Check direct assignability
            if (current.isAssignableTo(target, self.language)) {
                self.reachability_cache.put(pair, true) catch {};
                return true;
            }

            // Explore edges
            if (self.edges.get(current.hash())) |edge_list| {
                for (edge_list.items) |edge| {
                    const next_hash = edge.target_type.hash();
                    if (!visited.contains(next_hash)) {
                        visited.put(next_hash, {}) catch continue;
                        queue.append(self.allocator, edge.target_type) catch continue;
                    }
                }
            }
        }

        self.reachability_cache.put(pair, false) catch {};
        return false;
    }

    /// Get all valid transitions from current type toward goal type
    pub fn getValidTransitions(
        self: *InhabitationGraph,
        current: ?*const Type,
        goal: *const Type,
    ) []const Edge {
        // If no current type, return construction edges
        if (current == null) {
            const any_type = self.arena.primitive(.any) catch return &.{};
            if (self.edges.get(any_type.hash())) |edge_list| {
                // Filter to edges that can lead to goal
                var valid = std.ArrayList(Edge){};
                for (edge_list.items) |edge| {
                    if (self.isReachable(edge.target_type, goal)) {
                        valid.append(self.allocator, edge) catch continue;
                    }
                }
                return valid.toOwnedSlice(self.allocator) catch return &.{};
            }
            return &.{};
        }

        const current_hash = current.?.hash();
        if (self.edges.get(current_hash)) |edge_list| {
            // Filter to edges that can lead to goal
            var valid = std.ArrayList(Edge){};
            for (edge_list.items) |edge| {
                if (edge.target_type.eql(goal) or self.isReachable(edge.target_type, goal)) {
                    valid.append(self.allocator, edge) catch continue;
                }
            }
            return valid.toOwnedSlice(self.allocator) catch return &.{};
        }

        return &.{};
    }

    /// Check if a token can lead to the goal type given current state
    pub fn canTokenLeadToGoal(
        self: *InhabitationGraph,
        token: []const u8,
        current_type: ?*const Type,
        goal_type: *const Type,
    ) bool {
        // Check if token is a binding name
        for (self.bindings.items) |binding| {
            if (std.mem.eql(u8, token, binding.name)) {
                return self.isReachable(binding.binding_type, goal_type);
            }
        }

        // Check if token matches any transition pattern
        const transitions = self.getValidTransitions(current_type, goal_type);
        defer self.allocator.free(transitions);

        for (transitions) |edge| {
            if (self.matchesPattern(token, edge.token_pattern)) {
                return true;
            }
        }

        return false;
    }

    pub fn matchesPattern(self: *InhabitationGraph, token: []const u8, pattern: []const u8) bool {
        _ = self;
        // Simple prefix match for now
        // Could be extended to regex matching
        if (pattern.len == 0) return false;

        // For single-character patterns, check if token starts with any of them
        if (pattern.len == 1 or !std.mem.containsAtLeast(u8, pattern, 1, " ")) {
            for (pattern) |c| {
                if (token.len > 0 and token[0] == c) return true;
            }
            return false;
        }

        // For multi-character patterns, check prefix
        return std.mem.startsWith(u8, token, pattern) or
            std.mem.eql(u8, token, pattern);
    }
};

// ============================================================================
// Tests
// ============================================================================

test "InhabitationGraph - basic setup" {
    var arena = TypeArena.init(std.testing.allocator);
    defer arena.deinit();

    var graph = InhabitationGraph.init(std.testing.allocator, &arena, .typescript);
    defer graph.deinit();

    try graph.addBuiltinEdges();

    // number should be reachable from number
    const num_type = try arena.primitive(.number);
    try std.testing.expect(graph.isReachable(num_type, num_type));
}

test "InhabitationGraph - type conversion" {
    var arena = TypeArena.init(std.testing.allocator);
    defer arena.deinit();

    var graph = InhabitationGraph.init(std.testing.allocator, &arena, .typescript);
    defer graph.deinit();

    try graph.addBuiltinEdges();

    const num_type = try arena.primitive(.number);
    const str_type = try arena.primitive(.string);

    // string should be reachable from number (via .toString())
    try std.testing.expect(graph.isReachable(num_type, str_type));
}

test "InhabitationGraph - bindings" {
    var arena = TypeArena.init(std.testing.allocator);
    defer arena.deinit();

    var graph = InhabitationGraph.init(std.testing.allocator, &arena, .typescript);
    defer graph.deinit();

    try graph.addBuiltinEdges();

    const num_type = try arena.primitive(.number);
    const str_type = try arena.primitive(.string);

    try graph.addBinding(.{ .name = "x", .binding_type = num_type });

    // "x" should be able to lead to string (via toString)
    try std.testing.expect(graph.canTokenLeadToGoal("x", null, str_type));
}

test "InhabitationGraph - Python edges" {
    var arena = TypeArena.init(std.testing.allocator);
    defer arena.deinit();

    var graph = InhabitationGraph.init(std.testing.allocator, &arena, .python);
    defer graph.deinit();

    try graph.addBuiltinEdges();

    const int_type = try arena.primitive(.i64);
    const str_type = try arena.primitive(.string);

    // str should be reachable from int (via str())
    try std.testing.expect(graph.isReachable(int_type, str_type));
}
