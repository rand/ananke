// Braid: Constraint Compilation Engine
// Compiles constraints into optimized evaluation programs
const std = @import("std");

// Import types from root module
const root = @import("ananke");
const Constraint = root.types.constraint.Constraint;
const ConstraintIR = root.types.constraint.ConstraintIR;
const ConstraintSet = root.types.constraint.ConstraintSet;
const ConstraintKind = root.types.constraint.ConstraintKind;
const ConstraintSource = root.types.constraint.ConstraintSource;
const ConstraintPriority = root.types.constraint.ConstraintPriority;
const JsonSchema = root.types.constraint.JsonSchema;
const Grammar = root.types.constraint.Grammar;
const GrammarRule = root.types.constraint.GrammarRule;
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
                try writer.print("    \"{s}\"", .{regex.pattern});
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
        var conflicts = std.ArrayList(Conflict){};

        // Optimized conflict detection: O(n log n) instead of O(n²)
        // Strategy: Group constraints by kind first, then only check within groups
        // where conflicts are possible. Most constraint kinds don't conflict with each other.

        // Group constraints by kind using a hash map
        var by_kind = std.AutoHashMap(ConstraintKind, std.ArrayList(usize)).init(self.allocator);
        defer {
            var iter = by_kind.iterator();
            while (iter.next()) |entry| {
                entry.value_ptr.deinit(self.allocator);
            }
            by_kind.deinit();
        }

        // Build groups: O(n)
        for (graph.nodes.items, 0..) |node, i| {
            const kind = node.constraint.kind;
            const entry = try by_kind.getOrPut(kind);
            if (!entry.found_existing) {
                entry.value_ptr.* = std.ArrayList(usize){};
            }
            try entry.value_ptr.append(self.allocator, i);
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
                        try conflicts.append(self.allocator, .{
                            .constraint_a = idx_a,
                            .constraint_b = idx_b,
                            .description = "Constraints are incompatible",
                        });
                    }
                }
            }
        }

        return try conflicts.toOwnedSlice(self.allocator);
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

            try descriptions.append(self.allocator, desc);
        }

        return try descriptions.toOwnedSlice(self.allocator);
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
        // Topological sort for optimal evaluation order
        const sorted_indices = try graph.topologicalSort();
        defer self.allocator.free(sorted_indices);

        // Mark critical path constraints
        for (graph.nodes.items) |*node| {
            if (node.constraint.severity == .err) {
                node.priority = 1000;
            }
        }

        // Update node priorities based on topological order
        for (sorted_indices, 0..) |node_idx, order| {
            if (node_idx < graph.nodes.items.len) {
                graph.nodes.items[node_idx].priority = @as(u32, @intCast(order));
            }
        }
    }

    fn compileToIR(self: *Braid, graph: *const ConstraintGraph) !ConstraintIR {
        var ir = ConstraintIR{};

        // Build JSON schema from type constraints
        const type_constraints = try self.extractTypeConstraints(graph);
        defer self.allocator.free(type_constraints);
        if (type_constraints.len > 0) {
            ir.json_schema = try self.buildJsonSchema(type_constraints);
        }

        // Build grammar from syntactic constraints
        const syntax_constraints = try self.extractSyntaxConstraints(graph);
        defer self.allocator.free(syntax_constraints);
        if (syntax_constraints.len > 0) {
            ir.grammar = try self.buildGrammar(syntax_constraints);
        }

        // Extract regex patterns
        ir.regex_patterns = try self.extractRegexPatterns(graph);

        // Build token masks for security constraints
        const security_constraints = try self.extractSecurityConstraints(graph);
        defer self.allocator.free(security_constraints);
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
        // Create an arena allocator for building the grammar
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const arena_allocator = arena.allocator();

        var rules = try std.ArrayList(GrammarRule).initCapacity(arena_allocator, 50);

        // Track which patterns we've seen to avoid duplicates
        var has_async_function = false;
        var has_function = false;
        var has_if_statement = false;
        var has_for_loop = false;
        var has_while_loop = false;
        var has_try_catch = false;
        var has_switch_statement = false;
        var has_arrow_function = false;
        var has_class_declaration = false;
        var has_return_statement = false;

        // Analyze constraints to detect patterns
        for (constraints) |constraint| {
            if (constraint.kind != .syntactic) continue;

            const desc = constraint.description;

            // Detect async functions
            if (std.mem.indexOf(u8, desc, "async") != null and
                std.mem.indexOf(u8, desc, "function") != null)
            {
                has_async_function = true;
            }

            // Detect regular functions
            if (std.mem.indexOf(u8, desc, "function") != null) {
                has_function = true;
            }

            // Detect arrow functions
            if (std.mem.indexOf(u8, desc, "=>") != null or
                std.mem.indexOf(u8, desc, "arrow") != null)
            {
                has_arrow_function = true;
            }

            // Detect if statements
            if (std.mem.indexOf(u8, desc, "if") != null and
                (std.mem.indexOf(u8, desc, "statement") != null or
                std.mem.indexOf(u8, desc, "else") != null))
            {
                has_if_statement = true;
            }

            // Detect for loops
            if (std.mem.indexOf(u8, desc, "for") != null and
                (std.mem.indexOf(u8, desc, "loop") != null or
                std.mem.indexOf(u8, desc, "iteration") != null))
            {
                has_for_loop = true;
            }

            // Detect while loops
            if (std.mem.indexOf(u8, desc, "while") != null and
                std.mem.indexOf(u8, desc, "loop") != null)
            {
                has_while_loop = true;
            }

            // Detect try/catch
            if ((std.mem.indexOf(u8, desc, "try") != null and
                std.mem.indexOf(u8, desc, "catch") != null) or
                std.mem.indexOf(u8, desc, "exception") != null)
            {
                has_try_catch = true;
            }

            // Detect switch statements
            if (std.mem.indexOf(u8, desc, "switch") != null or
                std.mem.indexOf(u8, desc, "case") != null)
            {
                has_switch_statement = true;
            }

            // Detect class declarations
            if (std.mem.indexOf(u8, desc, "class") != null) {
                has_class_declaration = true;
            }

            // Detect return statements
            if (std.mem.indexOf(u8, desc, "return") != null) {
                has_return_statement = true;
            }
        }

        // Build base grammar rules
        try rules.append(arena_allocator, GrammarRule{
            .lhs = try arena_allocator.dupe(u8, "program"),
            .rhs = try self.createRhsSlice(arena_allocator, &.{"statement_list"}),
        });

        try rules.append(arena_allocator, GrammarRule{
            .lhs = try arena_allocator.dupe(u8, "statement_list"),
            .rhs = try self.createRhsSlice(arena_allocator, &.{ "statement", "statement_list_tail" }),
        });

        try rules.append(arena_allocator, GrammarRule{
            .lhs = try arena_allocator.dupe(u8, "statement_list_tail"),
            .rhs = try self.createRhsSlice(arena_allocator, &.{ "statement", "statement_list_tail" }),
        });

        try rules.append(arena_allocator, GrammarRule{
            .lhs = try arena_allocator.dupe(u8, "statement_list_tail"),
            .rhs = try self.createRhsSlice(arena_allocator, &.{}), // epsilon
        });

        // Build statement alternatives based on detected patterns
        var statement_alternatives = try std.ArrayList([]const u8).initCapacity(arena_allocator, 10);

        if (has_function or has_async_function) {
            try statement_alternatives.append(arena_allocator, try arena_allocator.dupe(u8, "function_declaration"));
        }

        if (has_arrow_function) {
            try statement_alternatives.append(arena_allocator, try arena_allocator.dupe(u8, "arrow_function"));
        }

        if (has_class_declaration) {
            try statement_alternatives.append(arena_allocator, try arena_allocator.dupe(u8, "class_declaration"));
        }

        if (has_if_statement) {
            try statement_alternatives.append(arena_allocator, try arena_allocator.dupe(u8, "if_statement"));
        }

        if (has_for_loop) {
            try statement_alternatives.append(arena_allocator, try arena_allocator.dupe(u8, "for_statement"));
        }

        if (has_while_loop) {
            try statement_alternatives.append(arena_allocator, try arena_allocator.dupe(u8, "while_statement"));
        }

        if (has_try_catch) {
            try statement_alternatives.append(arena_allocator, try arena_allocator.dupe(u8, "try_statement"));
        }

        if (has_switch_statement) {
            try statement_alternatives.append(arena_allocator, try arena_allocator.dupe(u8, "switch_statement"));
        }

        if (has_return_statement) {
            try statement_alternatives.append(arena_allocator, try arena_allocator.dupe(u8, "return_statement"));
        }

        // Always include basic statements
        try statement_alternatives.append(arena_allocator, try arena_allocator.dupe(u8, "assignment"));
        try statement_alternatives.append(arena_allocator, try arena_allocator.dupe(u8, "expression_statement"));

        // Add statement rule with all alternatives
        try rules.append(arena_allocator, GrammarRule{
            .lhs = try arena_allocator.dupe(u8, "statement"),
            .rhs = try statement_alternatives.toOwnedSlice(arena_allocator),
        });

        // Add detailed rules for each detected pattern
        if (has_async_function) {
            try rules.append(arena_allocator, GrammarRule{
                .lhs = try arena_allocator.dupe(u8, "async_function"),
                .rhs = try self.createRhsSlice(arena_allocator, &.{ "ASYNC", "FUNCTION", "identifier", "LPAREN", "params", "RPAREN", "LBRACE", "statement_list", "RBRACE" }),
            });
        }

        if (has_function) {
            try rules.append(arena_allocator, GrammarRule{
                .lhs = try arena_allocator.dupe(u8, "function_declaration"),
                .rhs = try self.createRhsSlice(arena_allocator, &.{ "FUNCTION", "identifier", "LPAREN", "params", "RPAREN", "LBRACE", "statement_list", "RBRACE" }),
            });

            if (has_async_function) {
                // Add alternative for async function
                try rules.append(arena_allocator, GrammarRule{
                    .lhs = try arena_allocator.dupe(u8, "function_declaration"),
                    .rhs = try self.createRhsSlice(arena_allocator, &.{"async_function"}),
                });
            }
        }

        if (has_arrow_function) {
            try rules.append(arena_allocator, GrammarRule{
                .lhs = try arena_allocator.dupe(u8, "arrow_function"),
                .rhs = try self.createRhsSlice(arena_allocator, &.{ "LPAREN", "params", "RPAREN", "ARROW", "expression" }),
            });

            try rules.append(arena_allocator, GrammarRule{
                .lhs = try arena_allocator.dupe(u8, "arrow_function"),
                .rhs = try self.createRhsSlice(arena_allocator, &.{ "LPAREN", "params", "RPAREN", "ARROW", "LBRACE", "statement_list", "RBRACE" }),
            });
        }

        if (has_class_declaration) {
            try rules.append(arena_allocator, GrammarRule{
                .lhs = try arena_allocator.dupe(u8, "class_declaration"),
                .rhs = try self.createRhsSlice(arena_allocator, &.{ "CLASS", "identifier", "LBRACE", "class_body", "RBRACE" }),
            });

            try rules.append(arena_allocator, GrammarRule{
                .lhs = try arena_allocator.dupe(u8, "class_body"),
                .rhs = try self.createRhsSlice(arena_allocator, &.{"method_list"}),
            });

            try rules.append(arena_allocator, GrammarRule{
                .lhs = try arena_allocator.dupe(u8, "method_list"),
                .rhs = try self.createRhsSlice(arena_allocator, &.{ "method", "method_list" }),
            });

            try rules.append(arena_allocator, GrammarRule{
                .lhs = try arena_allocator.dupe(u8, "method_list"),
                .rhs = try self.createRhsSlice(arena_allocator, &.{}), // epsilon
            });

            try rules.append(arena_allocator, GrammarRule{
                .lhs = try arena_allocator.dupe(u8, "method"),
                .rhs = try self.createRhsSlice(arena_allocator, &.{ "identifier", "LPAREN", "params", "RPAREN", "LBRACE", "statement_list", "RBRACE" }),
            });
        }

        if (has_if_statement) {
            try rules.append(arena_allocator, GrammarRule{
                .lhs = try arena_allocator.dupe(u8, "if_statement"),
                .rhs = try self.createRhsSlice(arena_allocator, &.{ "IF", "LPAREN", "expression", "RPAREN", "LBRACE", "statement_list", "RBRACE" }),
            });

            try rules.append(arena_allocator, GrammarRule{
                .lhs = try arena_allocator.dupe(u8, "if_statement"),
                .rhs = try self.createRhsSlice(arena_allocator, &.{ "IF", "LPAREN", "expression", "RPAREN", "LBRACE", "statement_list", "RBRACE", "ELSE", "LBRACE", "statement_list", "RBRACE" }),
            });
        }

        if (has_for_loop) {
            try rules.append(arena_allocator, GrammarRule{
                .lhs = try arena_allocator.dupe(u8, "for_statement"),
                .rhs = try self.createRhsSlice(arena_allocator, &.{ "FOR", "LPAREN", "assignment", "SEMICOLON", "expression", "SEMICOLON", "assignment", "RPAREN", "LBRACE", "statement_list", "RBRACE" }),
            });
        }

        if (has_while_loop) {
            try rules.append(arena_allocator, GrammarRule{
                .lhs = try arena_allocator.dupe(u8, "while_statement"),
                .rhs = try self.createRhsSlice(arena_allocator, &.{ "WHILE", "LPAREN", "expression", "RPAREN", "LBRACE", "statement_list", "RBRACE" }),
            });
        }

        if (has_try_catch) {
            try rules.append(arena_allocator, GrammarRule{
                .lhs = try arena_allocator.dupe(u8, "try_statement"),
                .rhs = try self.createRhsSlice(arena_allocator, &.{ "TRY", "LBRACE", "statement_list", "RBRACE", "CATCH", "LPAREN", "identifier", "RPAREN", "LBRACE", "statement_list", "RBRACE" }),
            });
        }

        if (has_switch_statement) {
            try rules.append(arena_allocator, GrammarRule{
                .lhs = try arena_allocator.dupe(u8, "switch_statement"),
                .rhs = try self.createRhsSlice(arena_allocator, &.{ "SWITCH", "LPAREN", "expression", "RPAREN", "LBRACE", "case_list", "RBRACE" }),
            });

            try rules.append(arena_allocator, GrammarRule{
                .lhs = try arena_allocator.dupe(u8, "case_list"),
                .rhs = try self.createRhsSlice(arena_allocator, &.{ "case_clause", "case_list" }),
            });

            try rules.append(arena_allocator, GrammarRule{
                .lhs = try arena_allocator.dupe(u8, "case_list"),
                .rhs = try self.createRhsSlice(arena_allocator, &.{}), // epsilon
            });

            try rules.append(arena_allocator, GrammarRule{
                .lhs = try arena_allocator.dupe(u8, "case_clause"),
                .rhs = try self.createRhsSlice(arena_allocator, &.{ "CASE", "expression", "COLON", "statement_list" }),
            });
        }

        if (has_return_statement) {
            try rules.append(arena_allocator, GrammarRule{
                .lhs = try arena_allocator.dupe(u8, "return_statement"),
                .rhs = try self.createRhsSlice(arena_allocator, &.{ "RETURN", "expression", "SEMICOLON" }),
            });

            try rules.append(arena_allocator, GrammarRule{
                .lhs = try arena_allocator.dupe(u8, "return_statement"),
                .rhs = try self.createRhsSlice(arena_allocator, &.{ "RETURN", "SEMICOLON" }),
            });
        }

        // Basic expression and statement rules
        try rules.append(arena_allocator, GrammarRule{
            .lhs = try arena_allocator.dupe(u8, "assignment"),
            .rhs = try self.createRhsSlice(arena_allocator, &.{ "identifier", "EQUALS", "expression", "SEMICOLON" }),
        });

        try rules.append(arena_allocator, GrammarRule{
            .lhs = try arena_allocator.dupe(u8, "expression_statement"),
            .rhs = try self.createRhsSlice(arena_allocator, &.{ "expression", "SEMICOLON" }),
        });

        try rules.append(arena_allocator, GrammarRule{
            .lhs = try arena_allocator.dupe(u8, "expression"),
            .rhs = try self.createRhsSlice(arena_allocator, &.{"binary_expression"}),
        });

        try rules.append(arena_allocator, GrammarRule{
            .lhs = try arena_allocator.dupe(u8, "expression"),
            .rhs = try self.createRhsSlice(arena_allocator, &.{"function_call"}),
        });

        try rules.append(arena_allocator, GrammarRule{
            .lhs = try arena_allocator.dupe(u8, "expression"),
            .rhs = try self.createRhsSlice(arena_allocator, &.{"identifier"}),
        });

        try rules.append(arena_allocator, GrammarRule{
            .lhs = try arena_allocator.dupe(u8, "expression"),
            .rhs = try self.createRhsSlice(arena_allocator, &.{"literal"}),
        });

        try rules.append(arena_allocator, GrammarRule{
            .lhs = try arena_allocator.dupe(u8, "binary_expression"),
            .rhs = try self.createRhsSlice(arena_allocator, &.{ "expression", "binary_op", "expression" }),
        });

        try rules.append(arena_allocator, GrammarRule{
            .lhs = try arena_allocator.dupe(u8, "binary_op"),
            .rhs = try self.createRhsSlice(arena_allocator, &.{"PLUS"}),
        });

        try rules.append(arena_allocator, GrammarRule{
            .lhs = try arena_allocator.dupe(u8, "binary_op"),
            .rhs = try self.createRhsSlice(arena_allocator, &.{"MINUS"}),
        });

        try rules.append(arena_allocator, GrammarRule{
            .lhs = try arena_allocator.dupe(u8, "binary_op"),
            .rhs = try self.createRhsSlice(arena_allocator, &.{"STAR"}),
        });

        try rules.append(arena_allocator, GrammarRule{
            .lhs = try arena_allocator.dupe(u8, "binary_op"),
            .rhs = try self.createRhsSlice(arena_allocator, &.{"SLASH"}),
        });

        try rules.append(arena_allocator, GrammarRule{
            .lhs = try arena_allocator.dupe(u8, "function_call"),
            .rhs = try self.createRhsSlice(arena_allocator, &.{ "identifier", "LPAREN", "args", "RPAREN" }),
        });

        try rules.append(arena_allocator, GrammarRule{
            .lhs = try arena_allocator.dupe(u8, "params"),
            .rhs = try self.createRhsSlice(arena_allocator, &.{"param_list"}),
        });

        try rules.append(arena_allocator, GrammarRule{
            .lhs = try arena_allocator.dupe(u8, "params"),
            .rhs = try self.createRhsSlice(arena_allocator, &.{}), // epsilon - no params
        });

        try rules.append(arena_allocator, GrammarRule{
            .lhs = try arena_allocator.dupe(u8, "param_list"),
            .rhs = try self.createRhsSlice(arena_allocator, &.{ "identifier", "param_list_tail" }),
        });

        try rules.append(arena_allocator, GrammarRule{
            .lhs = try arena_allocator.dupe(u8, "param_list_tail"),
            .rhs = try self.createRhsSlice(arena_allocator, &.{ "COMMA", "identifier", "param_list_tail" }),
        });

        try rules.append(arena_allocator, GrammarRule{
            .lhs = try arena_allocator.dupe(u8, "param_list_tail"),
            .rhs = try self.createRhsSlice(arena_allocator, &.{}), // epsilon
        });

        try rules.append(arena_allocator, GrammarRule{
            .lhs = try arena_allocator.dupe(u8, "args"),
            .rhs = try self.createRhsSlice(arena_allocator, &.{"arg_list"}),
        });

        try rules.append(arena_allocator, GrammarRule{
            .lhs = try arena_allocator.dupe(u8, "args"),
            .rhs = try self.createRhsSlice(arena_allocator, &.{}), // epsilon - no args
        });

        try rules.append(arena_allocator, GrammarRule{
            .lhs = try arena_allocator.dupe(u8, "arg_list"),
            .rhs = try self.createRhsSlice(arena_allocator, &.{ "expression", "arg_list_tail" }),
        });

        try rules.append(arena_allocator, GrammarRule{
            .lhs = try arena_allocator.dupe(u8, "arg_list_tail"),
            .rhs = try self.createRhsSlice(arena_allocator, &.{ "COMMA", "expression", "arg_list_tail" }),
        });

        try rules.append(arena_allocator, GrammarRule{
            .lhs = try arena_allocator.dupe(u8, "arg_list_tail"),
            .rhs = try self.createRhsSlice(arena_allocator, &.{}), // epsilon
        });

        try rules.append(arena_allocator, GrammarRule{
            .lhs = try arena_allocator.dupe(u8, "identifier"),
            .rhs = try self.createRhsSlice(arena_allocator, &.{"IDENTIFIER"}),
        });

        try rules.append(arena_allocator, GrammarRule{
            .lhs = try arena_allocator.dupe(u8, "literal"),
            .rhs = try self.createRhsSlice(arena_allocator, &.{"NUMBER"}),
        });

        try rules.append(arena_allocator, GrammarRule{
            .lhs = try arena_allocator.dupe(u8, "literal"),
            .rhs = try self.createRhsSlice(arena_allocator, &.{"STRING"}),
        });

        try rules.append(arena_allocator, GrammarRule{
            .lhs = try arena_allocator.dupe(u8, "literal"),
            .rhs = try self.createRhsSlice(arena_allocator, &.{"BOOLEAN"}),
        });

        // Allocate the rules slice in the main allocator so it persists
        const owned_rules = try self.allocator.alloc(GrammarRule, rules.items.len);
        for (rules.items, 0..) |rule, i| {
            // Allocate and copy RHS items first
            const rhs_items = try self.allocator.alloc([]const u8, rule.rhs.len);
            for (rule.rhs, 0..) |rhs_item, j| {
                rhs_items[j] = try self.allocator.dupe(u8, rhs_item);
            }

            owned_rules[i] = GrammarRule{
                .lhs = try self.allocator.dupe(u8, rule.lhs),
                .rhs = rhs_items,
            };
        }

        return Grammar{
            .rules = owned_rules,
            .start_symbol = "program",
        };
    }

    // Helper function to create RHS slice from string literals
    fn createRhsSlice(
        self: *Braid,
        allocator: std.mem.Allocator,
        items: []const []const u8,
    ) ![]const []const u8 {
        _ = self;
        const slice = try allocator.alloc([]const u8, items.len);
        for (items, 0..) |item, i| {
            slice[i] = try allocator.dupe(u8, item);
        }
        return slice;
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

/// Build token mask rules from security and operational constraints
pub fn buildTokenMasks(
    allocator: std.mem.Allocator,
    constraints: []const Constraint,
) ![]root.types.constraint.TokenMaskRule {
    var rules = std.ArrayList(root.types.constraint.TokenMaskRule){};

    // Scan constraints for security or operational kinds
    for (constraints) |constraint| {
        if (constraint.kind != .security and constraint.kind != .operational) {
            continue;
        }

        const desc_lower = constraint.description;

        // Detect "no credentials" / "no secrets" pattern
        if (containsAny(desc_lower, &.{ "credential", "secret", "password", "api key", "api_key" })) {
            // Block common credential patterns
            try rules.append(allocator, .{
                .mask_type = .deny_tokens,
                .pattern = try allocator.dupe(u8, "password"),
                .description = try allocator.dupe(u8, "Blocked: password credential"),
            });
            try rules.append(allocator, .{
                .mask_type = .deny_tokens,
                .pattern = try allocator.dupe(u8, "api_key"),
                .description = try allocator.dupe(u8, "Blocked: API key credential"),
            });
            try rules.append(allocator, .{
                .mask_type = .deny_tokens,
                .pattern = try allocator.dupe(u8, "token"),
                .description = try allocator.dupe(u8, "Blocked: token credential"),
            });
            try rules.append(allocator, .{
                .mask_type = .deny_tokens,
                .pattern = try allocator.dupe(u8, "secret"),
                .description = try allocator.dupe(u8, "Blocked: secret credential"),
            });
        }

        // Detect "no external URLs" pattern
        if (containsAny(desc_lower, &.{ "external url", "url", "http" })) {
            try rules.append(allocator, .{
                .mask_type = .deny_tokens,
                .pattern = try allocator.dupe(u8, "http://"),
                .description = try allocator.dupe(u8, "Blocked: HTTP URL"),
            });
            try rules.append(allocator, .{
                .mask_type = .deny_tokens,
                .pattern = try allocator.dupe(u8, "https://"),
                .description = try allocator.dupe(u8, "Blocked: HTTPS URL"),
            });
        }

        // Detect "no file paths" pattern
        if (containsAny(desc_lower, &.{ "file path", "path", "filesystem" })) {
            try rules.append(allocator, .{
                .mask_type = .deny_tokens,
                .pattern = try allocator.dupe(u8, "/path/"),
                .description = try allocator.dupe(u8, "Blocked: Unix file path"),
            });
            try rules.append(allocator, .{
                .mask_type = .deny_tokens,
                .pattern = try allocator.dupe(u8, "C:\\"),
                .description = try allocator.dupe(u8, "Blocked: Windows file path"),
            });
        }

        // Detect "no SQL injection" pattern
        if (containsAny(desc_lower, &.{ "sql", "injection" })) {
            try rules.append(allocator, .{
                .mask_type = .deny_tokens,
                .pattern = try allocator.dupe(u8, "DROP"),
                .description = try allocator.dupe(u8, "Blocked: SQL DROP statement"),
            });
            try rules.append(allocator, .{
                .mask_type = .deny_tokens,
                .pattern = try allocator.dupe(u8, "DELETE"),
                .description = try allocator.dupe(u8, "Blocked: SQL DELETE statement"),
            });
            try rules.append(allocator, .{
                .mask_type = .deny_tokens,
                .pattern = try allocator.dupe(u8, "INSERT"),
                .description = try allocator.dupe(u8, "Blocked: SQL INSERT statement"),
            });
            try rules.append(allocator, .{
                .mask_type = .deny_tokens,
                .pattern = try allocator.dupe(u8, "UPDATE"),
                .description = try allocator.dupe(u8, "Blocked: SQL UPDATE statement"),
            });
        }

        // Detect "no code execution" pattern
        if (containsAny(desc_lower, &.{ "code execution", "exec", "eval" })) {
            try rules.append(allocator, .{
                .mask_type = .deny_tokens,
                .pattern = try allocator.dupe(u8, "eval"),
                .description = try allocator.dupe(u8, "Blocked: eval() code execution"),
            });
            try rules.append(allocator, .{
                .mask_type = .deny_tokens,
                .pattern = try allocator.dupe(u8, "exec"),
                .description = try allocator.dupe(u8, "Blocked: exec() code execution"),
            });
            try rules.append(allocator, .{
                .mask_type = .deny_tokens,
                .pattern = try allocator.dupe(u8, "system("),
                .description = try allocator.dupe(u8, "Blocked: system() code execution"),
            });
        }
    }

    return try rules.toOwnedSlice(allocator);
}

/// Helper to check if a string contains any of the given substrings (case-insensitive)
fn containsAny(haystack: []const u8, needles: []const []const u8) bool {
    for (needles) |needle| {
        if (std.ascii.indexOfIgnoreCase(haystack, needle) != null) {
            return true;
        }
    }
    return false;
}

/// Constraint dependency graph
pub const ConstraintGraph = struct {
    allocator: std.mem.Allocator,
    nodes: std.ArrayList(Node),
    edges: std.ArrayList(Edge),

    pub const Node = struct {
        constraint: Constraint,
        enabled: bool = true,
        priority: u32 = 0,
    };

    pub const Edge = struct {
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

    pub fn topologicalSort(self: *ConstraintGraph) ![]usize {
        // Kahn's algorithm for topological sorting with cycle detection
        var in_degree = std.AutoHashMap(usize, usize).init(self.allocator);
        defer in_degree.deinit();

        // Initialize in-degree map for all nodes
        for (0..self.nodes.items.len) |i| {
            try in_degree.put(i, 0);
        }

        // Calculate in-degree for each node
        for (self.edges.items) |edge| {
            const current = in_degree.get(edge.to) orelse 0;
            try in_degree.put(edge.to, current + 1);
        }

        // Find all nodes with in-degree 0
        var queue = try std.ArrayList(usize).initCapacity(self.allocator, self.nodes.items.len);
        defer queue.deinit(self.allocator);

        {
            var it = in_degree.iterator();
            while (it.next()) |entry| {
                if (entry.value_ptr.* == 0) {
                    try queue.append(self.allocator, entry.key_ptr.*);
                }
            }
        }

        // Process queue using Kahn's algorithm
        var result = try std.ArrayList(usize).initCapacity(self.allocator, self.nodes.items.len);
        var processed_count: usize = 0;

        while (queue.items.len > 0) {
            const node_id = queue.orderedRemove(0);
            try result.append(self.allocator, node_id);
            processed_count += 1;

            // Find all edges from this node
            for (self.edges.items) |edge| {
                if (edge.from == node_id) {
                    const to_degree = in_degree.get(edge.to) orelse 0;
                    if (to_degree > 0) {
                        try in_degree.put(edge.to, to_degree - 1);
                        if (to_degree - 1 == 0) {
                            try queue.append(self.allocator, edge.to);
                        }
                    }
                }
            }
        }

        // Check for cycles
        if (processed_count < self.nodes.items.len) {
            std.debug.print(
                "Warning: Cyclic dependencies detected. Processed {}/{} constraints.\n",
                .{ processed_count, self.nodes.items.len },
            );

            // Add remaining nodes to result (partial ordering)
            for (0..self.nodes.items.len) |i| {
                var found = false;
                for (result.items) |item| {
                    if (item == i) {
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    try result.append(self.allocator, i);
                }
            }
        }

        return try result.toOwnedSlice(self.allocator);
    }

    pub fn detectCycle(self: *ConstraintGraph) !bool {
        // Use DFS-based cycle detection
        var visited = try std.ArrayList(bool).initCapacity(self.allocator, self.nodes.items.len);
        defer visited.deinit(self.allocator);
        try visited.appendNTimes(self.allocator, false, self.nodes.items.len);

        var rec_stack = try std.ArrayList(bool).initCapacity(self.allocator, self.nodes.items.len);
        defer rec_stack.deinit(self.allocator);
        try rec_stack.appendNTimes(self.allocator, false, self.nodes.items.len);

        for (0..self.nodes.items.len) |node| {
            if (!visited.items[node]) {
                if (try self.hasCycleDFS(node, &visited, &rec_stack)) {
                    return true;
                }
            }
        }
        return false;
    }

    fn hasCycleDFS(
        self: *ConstraintGraph,
        node: usize,
        visited: *std.ArrayList(bool),
        rec_stack: *std.ArrayList(bool),
    ) !bool {
        visited.items[node] = true;
        rec_stack.items[node] = true;

        // Visit all neighbors
        for (self.edges.items) |edge| {
            if (edge.from == node) {
                if (!visited.items[edge.to]) {
                    if (try self.hasCycleDFS(edge.to, visited, rec_stack)) {
                        return true;
                    }
                } else if (rec_stack.items[edge.to]) {
                    return true;
                }
            }
        }

        rec_stack.items[node] = false;
        return false;
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
// Re-export JSON Schema builder functionality
pub const buildJSONSchemaString = @import("json_schema_builder.zig").buildJSONSchemaString;

// Public API for testing grammar building
pub fn buildGrammarFromConstraints(
    allocator: std.mem.Allocator,
    constraints: []const Constraint,
) !Grammar {
    var braid = try Braid.init(allocator);
    defer braid.deinit();
    return try braid.buildGrammar(constraints);
}

/// Build a combined regex pattern from constraints containing regex patterns
/// Returns null if no regex constraints found
pub fn buildRegexPattern(allocator: std.mem.Allocator, constraints: []const Constraint) !?[]const u8 {
    var patterns = std.ArrayList([]const u8){};
    defer patterns.deinit(allocator);

    // Common regex pattern delimiters and markers
    const regex_markers = [_][]const u8{
        "must match regex: ",
        "matches pattern ",
        "regex: ",
        "pattern: ",
    };

    for (constraints) |constraint| {
        const desc = constraint.description;

        // Try to find and extract regex patterns from the description
        for (regex_markers) |marker| {
            if (std.mem.indexOf(u8, desc, marker)) |marker_pos| {
                const start = marker_pos + marker.len;

                // Find the end of the regex pattern
                // End at: newline, end of string, or quote marks
                // Don't break on comma/semicolon as they're part of regex syntax
                var end = desc.len;

                for (desc[start..], 0..) |char, offset| {
                    if (char == '\n' or char == '"' or char == '\'' or char == '`') {
                        end = start + offset;
                        break;
                    }
                }

                if (end > start) {
                    const raw_pattern = desc[start..end];
                    // Trim whitespace
                    const trimmed = std.mem.trim(u8, raw_pattern, " \t\r\n");
                    if (trimmed.len > 0) {
                        const pattern_copy = try allocator.dupe(u8, trimmed);
                        try patterns.append(allocator, pattern_copy);
                    }
                }
                break; // Found pattern in this constraint, move to next
            }
        }
    }

    if (patterns.items.len == 0) {
        return null;
    }

    // Combine multiple patterns with | (OR operator)
    var combined = std.ArrayList(u8){};
    for (patterns.items, 0..) |pattern, i| {
        try combined.appendSlice(allocator, pattern);
        if (i < patterns.items.len - 1) {
            try combined.append(allocator, '|');
        }
        allocator.free(pattern);
    }

    return try combined.toOwnedSlice(allocator);
}

// ============================================================================
// Constraint Manipulation Functions
// ============================================================================

/// Merge two constraint sets into a new combined set
pub fn mergeConstraints(
    allocator: std.mem.Allocator,
    set1: ConstraintSet,
    set2: ConstraintSet,
) !ConstraintSet {
    // Create new set with combined name
    var merged_name = std.ArrayList(u8){};
    defer merged_name.deinit(allocator);
    try merged_name.writer(allocator).print("{s}_merged_{s}", .{ set1.name, set2.name });

    const combined_name = try allocator.dupe(u8, merged_name.items);
    var merged = ConstraintSet.init(allocator, combined_name);

    // Add all constraints from set1
    for (set1.constraints.items) |constraint| {
        try merged.add(constraint);
    }

    // Add all constraints from set2 (ConstraintSet.add() handles deduplication)
    for (set2.constraints.items) |constraint| {
        try merged.add(constraint);
    }

    return merged;
}

/// Remove duplicate/redundant constraints from an array
pub fn deduplicateConstraints(
    allocator: std.mem.Allocator,
    constraints: []const Constraint,
) ![]Constraint {
    // Use a struct to represent constraint key for hashing
    const ConstraintKey = struct {
        kind: ConstraintKind,
        description: []const u8,
        source: ConstraintSource,

        pub fn hash(self: @This()) u64 {
            var hasher = std.hash.Wyhash.init(0);
            hasher.update(@tagName(self.kind));
            hasher.update(self.description);
            hasher.update(@tagName(self.source));
            return hasher.final();
        }

        pub fn eql(self: @This(), other: @This()) bool {
            return self.kind == other.kind and
                   std.mem.eql(u8, self.description, other.description) and
                   self.source == other.source;
        }
    };

    // Track seen constraints using a HashMap
    var seen = std.AutoHashMap(u64, void).init(allocator);
    defer seen.deinit();

    var unique = std.ArrayList(Constraint){};

    for (constraints) |constraint| {
        const key = ConstraintKey{
            .kind = constraint.kind,
            .description = constraint.description,
            .source = constraint.source,
        };

        const hash_value = key.hash();

        // Only add if we haven't seen this constraint before
        if (!seen.contains(hash_value)) {
            try seen.put(hash_value, {});
            try unique.append(allocator, constraint);
        }
    }

    return try unique.toOwnedSlice(allocator);
}

/// Update constraint priority (setter function for clarity)
pub fn updatePriority(constraint: *Constraint, new_priority: ConstraintPriority) void {
    constraint.priority = new_priority;
}
