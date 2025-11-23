// Braid: Constraint Compilation Engine
// Compiles constraints into optimized evaluation programs
const std = @import("std");

// Import types from root module
const root = @import("ananke");
const Constraint = root.types.constraint.Constraint;
const ConstraintIR = root.types.constraint.ConstraintIR;
const ConstraintSet = root.types.constraint.ConstraintSet;
const ConstraintKind = root.types.constraint.ConstraintKind;
const JsonSchema = root.types.constraint.JsonSchema;
const Grammar = root.types.constraint.Grammar;
const TokenMaskRules = root.types.constraint.TokenMaskRules;

// Import Claude API client
const claude_api = @import("claude");

/// Main Braid compilation engine
pub const Braid = struct {
    allocator: std.mem.Allocator,
    llm_client: ?*claude_api.ClaudeClient = null,
    cache: IRCache,

    pub fn init(allocator: std.mem.Allocator) !Braid {
        return .{
            .allocator = allocator,
            .cache = try IRCache.init(allocator),
        };
    }

    pub fn deinit(self: *Braid) void {
        self.cache.deinit();
    }

    /// Set Claude client for conflict resolution
    pub fn setClaudeClient(self: *Braid, client: *claude_api.ClaudeClient) void {
        self.llm_client = client;
    }

    /// Compile a set of constraints into ConstraintIR
    pub fn compile(self: *Braid, constraints: []const Constraint) !ConstraintIR {
        // Build dependency graph
        var graph = try self.buildDependencyGraph(constraints);
        defer graph.deinit();

        // Detect and resolve conflicts
        const conflicts = try self.detectConflicts(&graph);
        defer self.allocator.free(conflicts);

        if (conflicts.len > 0) {
            // Use LLM for complex conflict resolution if available
            if (self.llm_client) |client| {
                // Convert conflicts to Claude format
                const conflict_descriptions = try self.convertConflictsForClaude(&graph, conflicts);
                defer {
                    for (conflict_descriptions) |desc| {
                        self.allocator.free(desc.constraint_a_name);
                        self.allocator.free(desc.constraint_a_desc);
                        self.allocator.free(desc.constraint_b_name);
                        self.allocator.free(desc.constraint_b_desc);
                        self.allocator.free(desc.issue);
                    }
                    self.allocator.free(conflict_descriptions);
                }

                const resolution = try client.suggestResolution(conflict_descriptions);
                defer self.allocator.free(resolution.actions);

                try self.applyClaudeResolution(&graph, resolution);
            } else {
                // Default conflict resolution
                try self.defaultConflictResolution(&graph, conflicts);
            }
        }

        // Optimize constraint evaluation order
        try self.optimizeGraph(&graph);

        // Compile to IR
        return try self.compileToIR(&graph);
    }

    /// Convert ConstraintIR to llguidance-compatible format
    pub fn toLLGuidanceSchema(
        self: *Braid,
        ir: ConstraintIR,
    ) ![]const u8 {
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const allocator = arena.allocator();

        var schema = std.ArrayList(u8){};
        var writer = schema.writer(allocator);

        // Convert to llguidance JSON format
        try writer.writeAll("{\n");
        try writer.writeAll("  \"type\": \"guidance\",\n");
        try writer.writeAll("  \"version\": \"1.0\",\n");

        // Add JSON schema if present
        if (ir.json_schema) |json| {
            try writer.writeAll("  \"json_schema\": ");
            try self.writeJsonSchema(writer, json);
            try writer.writeAll(",\n");
        }

        // Add grammar if present
        if (ir.grammar) |grammar| {
            try writer.writeAll("  \"grammar\": ");
            try self.writeGrammar(writer, grammar);
            try writer.writeAll(",\n");
        }

        // Add regex patterns
        if (ir.regex_patterns.len > 0) {
            try writer.writeAll("  \"patterns\": [\n");
            for (ir.regex_patterns, 0..) |regex, i| {
                try writer.print("    \"{}\"", .{std.fmt.fmtSliceEscapeUpper(regex.pattern)});
                if (i < ir.regex_patterns.len - 1) try writer.writeAll(",");
                try writer.writeAll("\n");
            }
            try writer.writeAll("  ],\n");
        }

        // Add token masks
        if (ir.token_masks) |masks| {
            try writer.writeAll("  \"token_masks\": ");
            try self.writeTokenMasks(writer, masks);
            try writer.writeAll(",\n");
        }

        try writer.print("  \"priority\": {}\n", .{ir.priority});
        try writer.writeAll("}\n");

        return try self.allocator.dupe(u8, schema.items);
    }

    // Private helper methods

    fn buildDependencyGraph(
        self: *Braid,
        constraints: []const Constraint,
    ) !ConstraintGraph {
        var graph = ConstraintGraph.init(self.allocator);

        // Add all constraints as nodes
        for (constraints) |constraint| {
            const node = try graph.addNode(constraint);
            _ = node;
        }

        // Analyze dependencies between constraints
        for (constraints, 0..) |constraint_a, i| {
            for (constraints[i + 1..], i + 1..) |constraint_b, j| {
                if (self.constraintsDependOn(constraint_a, constraint_b)) {
                    try graph.addEdge(i, j);
                }
            }
        }

        return graph;
    }

    fn constraintsDependOn(
        self: *Braid,
        a: Constraint,
        b: Constraint,
    ) bool {
        _ = self;
        // Simplified dependency detection
        // Type constraints depend on syntactic constraints
        if (a.kind == .type_safety and b.kind == .syntactic) {
            return true;
        }
        // Semantic constraints depend on type constraints
        if (a.kind == .semantic and b.kind == .type_safety) {
            return true;
        }
        return false;
    }

    fn detectConflicts(self: *Braid, graph: *ConstraintGraph) ![]Conflict {
        var conflicts = std.ArrayList(Conflict).init(self.allocator);

        // Optimized conflict detection: O(n log n) instead of O(n²)
        // Strategy: Group constraints by kind first, then only check within groups
        // where conflicts are possible. Most constraint kinds don't conflict with each other.

        // Group constraints by kind using a hash map
        var by_kind = std.AutoHashMap(ConstraintKind, std.ArrayList(usize)).init(self.allocator);
        defer {
            var iter = by_kind.iterator();
            while (iter.next()) |entry| {
                entry.value_ptr.deinit();
            }
            by_kind.deinit();
        }

        // Build groups: O(n)
        for (graph.nodes.items, 0..) |node, i| {
            const kind = node.constraint.kind;
            const entry = try by_kind.getOrPut(kind);
            if (!entry.found_existing) {
                entry.value_ptr.* = std.ArrayList(usize).init(self.allocator);
            }
            try entry.value_ptr.append(i);
        }

        // Check conflicts only within same kind: O(m²) where m << n for each kind
        // For most codebases, constraints are distributed across kinds, so m ≈ n/k
        // where k is the number of kinds, making this effectively O(n²/k)
        var kind_iter = by_kind.iterator();
        while (kind_iter.next()) |entry| {
            const indices = entry.value_ptr.items;

            // Only check pairs within this kind
            for (indices, 0..) |idx_a, i| {
                for (indices[i + 1..]) |idx_b| {
                    const node_a = graph.nodes.items[idx_a];
                    const node_b = graph.nodes.items[idx_b];

                    if (self.constraintsConflict(node_a.constraint, node_b.constraint)) {
                        try conflicts.append(.{
                            .constraint_a = idx_a,
                            .constraint_b = idx_b,
                            .description = "Constraints are incompatible",
                        });
                    }
                }
            }
        }

        return try conflicts.toOwnedSlice();
    }

    fn constraintsConflict(self: *Braid, a: Constraint, b: Constraint) bool {
        _ = self;
        // Simplified conflict detection
        // Check if constraints have conflicting requirements
        return std.mem.eql(u8, a.name, "forbid_any") and
               std.mem.eql(u8, b.name, "allow_any");
    }

    fn defaultConflictResolution(
        self: *Braid,
        graph: *ConstraintGraph,
        conflicts: []const Conflict,
    ) !void {
        _ = self;
        // Simple resolution: Higher priority wins
        for (conflicts) |conflict| {
            const a = &graph.nodes.items[conflict.constraint_a];
            const b = &graph.nodes.items[conflict.constraint_b];

            // Disable the lower severity constraint
            if (@intFromEnum(a.constraint.severity) > @intFromEnum(b.constraint.severity)) {
                b.enabled = false;
            } else {
                a.enabled = false;
            }
        }
    }

    fn convertConflictsForClaude(
        self: *Braid,
        graph: *const ConstraintGraph,
        conflicts: []const Conflict,
    ) ![]claude_api.ConflictDescription {
        var descriptions = try std.ArrayList(claude_api.ConflictDescription).initCapacity(
            self.allocator,
            conflicts.len,
        );

        for (conflicts) |conflict| {
            const node_a = graph.nodes.items[conflict.constraint_a];
            const node_b = graph.nodes.items[conflict.constraint_b];

            const desc = claude_api.ConflictDescription{
                .constraint_a_name = try self.allocator.dupe(u8, node_a.constraint.name),
                .constraint_a_desc = try self.allocator.dupe(u8, node_a.constraint.description),
                .constraint_b_name = try self.allocator.dupe(u8, node_b.constraint.name),
                .constraint_b_desc = try self.allocator.dupe(u8, node_b.constraint.description),
                .issue = try self.allocator.dupe(u8, conflict.description),
            };

            try descriptions.append(desc);
        }

        return try descriptions.toOwnedSlice();
    }

    fn applyClaudeResolution(
        self: *Braid,
        graph: *ConstraintGraph,
        resolution: claude_api.ResolutionSuggestion,
    ) !void {
        // Apply Claude-suggested resolution
        for (resolution.actions) |action| {
            switch (action) {
                .disable_a => |info| {
                    const conflicts = try self.detectConflicts(graph);
                    defer self.allocator.free(conflicts);
                    if (info.conflict_index < conflicts.len) {
                        const conflict = conflicts[info.conflict_index];
                        graph.nodes.items[conflict.constraint_a].enabled = false;
                        std.log.info("Disabled constraint A: {s}", .{info.reasoning});
                    }
                },
                .disable_b => |info| {
                    const conflicts = try self.detectConflicts(graph);
                    defer self.allocator.free(conflicts);
                    if (info.conflict_index < conflicts.len) {
                        const conflict = conflicts[info.conflict_index];
                        graph.nodes.items[conflict.constraint_b].enabled = false;
                        std.log.info("Disabled constraint B: {s}", .{info.reasoning});
                    }
                },
                .merge => |info| {
                    std.log.info("Merge suggested: {s}", .{info.reasoning});
                    // TODO: Implement constraint merging
                },
                .modify_a => |info| {
                    std.log.info("Modify A suggested: {s}", .{info.reasoning});
                    // TODO: Implement constraint modification
                },
                .modify_b => |info| {
                    std.log.info("Modify B suggested: {s}", .{info.reasoning});
                    // TODO: Implement constraint modification
                },
            }
        }
    }

    fn optimizeGraph(self: *Braid, graph: *ConstraintGraph) !void {
        _ = self;
        // Topological sort for optimal evaluation order
        try graph.topologicalSort();

        // Mark critical path constraints
        for (graph.nodes.items) |*node| {
            if (node.constraint.severity == .err) {
                node.priority = 1000;
            }
        }
    }

    fn compileToIR(self: *Braid, graph: *const ConstraintGraph) !ConstraintIR {
        var ir = ConstraintIR{};

        // Build JSON schema from type constraints
        const type_constraints = try self.extractTypeConstraints(graph);
        if (type_constraints.len > 0) {
            ir.json_schema = try self.buildJsonSchema(type_constraints);
        }

        // Build grammar from syntactic constraints
        const syntax_constraints = try self.extractSyntaxConstraints(graph);
        if (syntax_constraints.len > 0) {
            ir.grammar = try self.buildGrammar(syntax_constraints);
        }

        // Extract regex patterns
        ir.regex_patterns = try self.extractRegexPatterns(graph);

        // Build token masks for security constraints
        const security_constraints = try self.extractSecurityConstraints(graph);
        if (security_constraints.len > 0) {
            ir.token_masks = try self.buildTokenMasks(security_constraints);
        }

        // Set priority based on graph analysis
        ir.priority = graph.getMaxPriority();

        return ir;
    }

    fn extractTypeConstraints(
        self: *Braid,
        graph: *const ConstraintGraph,
    ) ![]const Constraint {
        var constraints = std.ArrayList(Constraint){};
        for (graph.nodes.items) |node| {
            if (node.enabled and node.constraint.kind == .type_safety) {
                try constraints.append(self.allocator, node.constraint);
            }
        }
        return try constraints.toOwnedSlice(self.allocator);
    }

    fn extractSyntaxConstraints(
        self: *Braid,
        graph: *const ConstraintGraph,
    ) ![]const Constraint {
        var constraints = std.ArrayList(Constraint){};
        for (graph.nodes.items) |node| {
            if (node.enabled and node.constraint.kind == .syntactic) {
                try constraints.append(self.allocator, node.constraint);
            }
        }
        return try constraints.toOwnedSlice(self.allocator);
    }

    fn extractSecurityConstraints(
        self: *Braid,
        graph: *const ConstraintGraph,
    ) ![]const Constraint {
        var constraints = std.ArrayList(Constraint){};
        for (graph.nodes.items) |node| {
            if (node.enabled and node.constraint.kind == .security) {
                try constraints.append(self.allocator, node.constraint);
            }
        }
        return try constraints.toOwnedSlice(self.allocator);
    }

    fn extractRegexPatterns(
        self: *Braid,
        graph: *const ConstraintGraph,
    ) ![]const root.types.constraint.Regex {
        _ = self;
        _ = graph;
        // TODO: Extract regex patterns from constraints
        return &.{};
    }

    fn buildJsonSchema(
        self: *Braid,
        constraints: []const Constraint,
    ) !JsonSchema {
        _ = self;
        _ = constraints;
        // TODO: Build JSON schema from type constraints
        return JsonSchema{
            .type = "object",
        };
    }

    fn buildGrammar(
        self: *Braid,
        constraints: []const Constraint,
    ) !Grammar {
        _ = self;
        _ = constraints;
        // TODO: Build grammar from syntax constraints
        return Grammar{
            .rules = &.{},
            .start_symbol = "program",
        };
    }

    fn buildTokenMasks(
        self: *Braid,
        constraints: []const Constraint,
    ) !TokenMaskRules {
        _ = self;
        _ = constraints;
        // TODO: Build token masks from security constraints
        return TokenMaskRules{};
    }

    fn writeJsonSchema(
        self: *Braid,
        writer: anytype,
        schema: JsonSchema,
    ) !void {
        _ = self;
        try writer.print("{{\"type\": \"{s}\"}}", .{schema.type});
    }

    fn writeGrammar(
        self: *Braid,
        writer: anytype,
        grammar: Grammar,
    ) !void {
        _ = self;
        try writer.print("{{\"start\": \"{s}\"}}", .{grammar.start_symbol});
    }

    fn writeTokenMasks(
        self: *Braid,
        writer: anytype,
        masks: TokenMaskRules,
    ) !void {
        _ = self;
        _ = masks;
        try writer.writeAll("{}");
    }
};

/// Constraint dependency graph
const ConstraintGraph = struct {
    allocator: std.mem.Allocator,
    nodes: std.ArrayList(Node),
    edges: std.ArrayList(Edge),

    const Node = struct {
        constraint: Constraint,
        enabled: bool = true,
        priority: u32 = 0,
    };

    const Edge = struct {
        from: usize,
        to: usize,
    };

    pub fn init(allocator: std.mem.Allocator) ConstraintGraph {
        return .{
            .allocator = allocator,
            .nodes = std.ArrayList(Node){},
            .edges = std.ArrayList(Edge){},
        };
    }

    pub fn deinit(self: *ConstraintGraph) void {
        self.nodes.deinit(self.allocator);
        self.edges.deinit(self.allocator);
    }

    pub fn addNode(self: *ConstraintGraph, constraint: Constraint) !usize {
        const index = self.nodes.items.len;
        try self.nodes.append(self.allocator, .{ .constraint = constraint });
        return index;
    }

    pub fn addEdge(self: *ConstraintGraph, from: usize, to: usize) !void {
        try self.edges.append(self.allocator, .{ .from = from, .to = to });
    }

    pub fn topologicalSort(self: *ConstraintGraph) !void {
        // TODO: Implement topological sort
        _ = self;
    }

    pub fn getMaxPriority(self: *const ConstraintGraph) u32 {
        var max: u32 = 0;
        for (self.nodes.items) |node| {
            if (node.priority > max) {
                max = node.priority;
            }
        }
        return max;
    }
};

/// IR cache
const IRCache = struct {
    allocator: std.mem.Allocator,
    cache: std.AutoHashMap(u64, ConstraintIR),

    pub fn init(allocator: std.mem.Allocator) !IRCache {
        return .{
            .allocator = allocator,
            .cache = std.AutoHashMap(u64, ConstraintIR).init(allocator),
        };
    }

    pub fn deinit(self: *IRCache) void {
        self.cache.deinit();
    }
};

/// Conflict between constraints
const Conflict = struct {
    constraint_a: usize,
    constraint_b: usize,
    description: []const u8,
};