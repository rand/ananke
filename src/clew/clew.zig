// Clew: Constraint Extraction Engine
// Mines constraints from code, tests, telemetry, and documentation
const std = @import("std");

// Import types from root module
const root = @import("ananke");
const Constraint = root.types.constraint.Constraint;
const ConstraintKind = root.types.constraint.ConstraintKind;
const ConstraintSet = root.types.constraint.ConstraintSet;
const Severity = root.types.constraint.Severity;

// Import Claude API client
const claude_api = @import("claude");

// Tree-sitter support disabled pending Zig 0.15.x compatibility
// TODO: Re-enable when z-tree-sitter upstream is fixed
// const zts = @import("zts");
const tree_sitter_enabled = false;

/// Main Clew extraction engine
pub const Clew = struct {
    allocator: std.mem.Allocator,
    claude_client: ?*claude_api.ClaudeClient = null,
    cache: ConstraintCache,

    pub fn init(allocator: std.mem.Allocator) !Clew {
        return .{
            .allocator = allocator,
            .cache = try ConstraintCache.init(allocator),
        };
    }

    pub fn deinit(self: *Clew) void {
        self.cache.deinit();
    }

    /// Set Claude client for semantic analysis
    pub fn setClaudeClient(self: *Clew, client: *claude_api.ClaudeClient) void {
        self.claude_client = client;
    }

    /// Extract constraints from source code
    pub fn extractFromCode(
        self: *Clew,
        source: []const u8,
        language: []const u8,
    ) !ConstraintSet {
        var constraint_set = ConstraintSet.init(self.allocator, "code_constraints");

        // Check cache first
        if (self.cache.get(source)) |cached| {
            return cached;
        }

        // 1. Tree-sitter parsing for syntactic constraints
        const syntax_constraints = try self.extractSyntacticConstraints(source, language);
        for (syntax_constraints) |constraint| {
            try constraint_set.add(constraint);
        }

        // 2. Type-level constraint discovery
        const type_constraints = try self.extractTypeConstraints(source, language);
        for (type_constraints) |constraint| {
            try constraint_set.add(constraint);
        }

        // 3. Optional: Use Claude for semantic understanding
        if (self.claude_client) |client| {
            const claude_constraints = try client.analyzeCode(source, language);
            defer self.allocator.free(claude_constraints);

            for (claude_constraints) |claude_constraint| {
                // Convert Claude constraint to Ananke constraint
                const ananke_constraint = Constraint{
                    .kind = convertConstraintKind(claude_constraint.kind),
                    .severity = convertSeverity(claude_constraint.severity),
                    .name = claude_constraint.name,
                    .description = claude_constraint.description,
                    .source = .LLM_Analysis,
                    .confidence = claude_constraint.confidence,
                };
                try constraint_set.add(ananke_constraint);
            }
        }

        // Cache the result
        try self.cache.put(source, constraint_set);

        return constraint_set;
    }

    /// Extract constraints from test files
    pub fn extractFromTests(self: *Clew, test_source: []const u8) !ConstraintSet {
        var constraint_set = ConstraintSet.init(self.allocator, "test_constraints");

        // Parse test assertions to infer constraints
        const assertions = try self.parseTestAssertions(test_source);

        for (assertions) |assertion| {
            const constraint = try self.assertionToConstraint(assertion);
            try constraint_set.add(constraint);
        }

        // Use Claude to understand test intent if available
        if (self.claude_client) |client| {
            const analysis = try client.analyzeTestIntent(test_source);
            defer self.allocator.free(analysis.constraints);
            defer self.allocator.free(analysis.intent_description);

            for (analysis.constraints) |claude_constraint| {
                const ananke_constraint = Constraint{
                    .kind = convertConstraintKind(claude_constraint.kind),
                    .severity = convertSeverity(claude_constraint.severity),
                    .name = claude_constraint.name,
                    .description = claude_constraint.description,
                    .source = .LLM_Analysis,
                    .confidence = claude_constraint.confidence,
                };
                try constraint_set.add(ananke_constraint);
            }
        }

        return constraint_set;
    }

    /// Extract constraints from telemetry data
    pub fn extractFromTelemetry(self: *Clew, telemetry: Telemetry) !ConstraintSet {
        var constraint_set = ConstraintSet.init(self.allocator, "telemetry_constraints");

        // Analyze performance metrics
        if (telemetry.latency_p99) |latency| {
            if (latency > 100) {
                const constraint = Constraint{
                    .kind = .operational,
                    .severity = .warning,
                    .name = "latency_bound",
                    .description = "P99 latency should be under 100ms",
                    .source = .Telemetry,
                };
                try constraint_set.add(constraint);
            }
        }

        // Analyze error patterns
        if (telemetry.error_rate) |error_rate| {
            if (error_rate > 0.01) {
                const constraint = Constraint{
                    .kind = .operational,
                    .severity = .err,
                    .name = "error_rate",
                    .description = "Error rate should be under 1%",
                    .source = .Telemetry,
                };
                try constraint_set.add(constraint);
            }
        }

        return constraint_set;
    }

    // Private helper methods

    fn extractSyntacticConstraints(
        self: *Clew,
        source: []const u8,
        language: []const u8,
    ) ![]Constraint {
        // Tree-sitter integration disabled pending Zig 0.15.x compatibility
        // Using fallback pattern matching for now
        _ = language;
        return try self.extractSyntacticConstraintsFallback(source);

        // TODO: Re-enable when z-tree-sitter is Zig 0.15.x compatible
        // var constraints = std.ArrayList(Constraint){};
        //
        // // Get the appropriate language parser
        // const lang = try self.getLanguageParser(language);
        // if (lang == null) {
        //     // Fall back to pattern matching for unsupported languages
        //     return try self.extractSyntacticConstraintsFallback(source);
        // }
        //
        // // Create parser and parse the source
        // var parser = try zts.Parser.init();
        // defer parser.deinit();
        //
        // try parser.setLanguage(lang.?);
        // const tree = try parser.parseString(null, source);
        // defer tree.deinit();
        //
        // const root_node = tree.rootNode();
        //
        // // Extract constraints from the syntax tree
        // var func_count: u32 = 0;
        // var typed_func_count: u32 = 0;
        //
        // try self.walkTreeForConstraints(
        //     root_node,
        //     &constraints,
        //     &func_count,
        //     &typed_func_count,
        //     language,
        // );
        //
        // // Generate high-level constraints based on analysis
        // if (func_count > 0) {
        //     const typed_ratio = @as(f32, @floatFromInt(typed_func_count)) / @as(f32, @floatFromInt(func_count));
        //
        //     if (typed_ratio > 0.8) {
        //         try constraints.append(self.allocator, Constraint{
        //             .kind = .type_safety,
        //             .severity = .info,
        //             .name = "explicit_function_types",
        //             .description = "Most functions have explicit type annotations",
        //             .source = .{ .static_analysis = {} },
        //             .confidence = typed_ratio,
        //         });
        //     }
        //
        //     try constraints.append(self.allocator, Constraint{
        //         .kind = .syntactic,
        //         .severity = .info,
        //         .name = "function_structure",
        //         .description = std.fmt.allocPrint(
        //             self.allocator,
        //             "Code contains {d} function definitions",
        //             .{func_count},
        //         ) catch "Code contains function definitions",
        //         .source = .{ .static_analysis = {} },
        //     });
        // }
        //
        // return try constraints.toOwnedSlice(self.allocator);
    }

    // TODO: Re-enable when z-tree-sitter is Zig 0.15.x compatible
    // fn getLanguageParser(self: *Clew, language: []const u8) !?*const anyopaque {
    //     _ = self;
    //
    //     // Map language names to Tree-sitter parsers
    //     if (std.mem.eql(u8, language, "typescript")) {
    //         return zts.loadLanguage("typescript");
    //     } else if (std.mem.eql(u8, language, "python")) {
    //         return zts.loadLanguage("python");
    //     } else if (std.mem.eql(u8, language, "javascript")) {
    //         return zts.loadLanguage("javascript");
    //     } else if (std.mem.eql(u8, language, "rust")) {
    //         return zts.loadLanguage("rust");
    //     } else if (std.mem.eql(u8, language, "go")) {
    //         return zts.loadLanguage("go");
    //     } else if (std.mem.eql(u8, language, "java")) {
    //         return zts.loadLanguage("java");
    //     } else if (std.mem.eql(u8, language, "zig")) {
    //         return zts.loadLanguage("zig");
    //     }
    //
    //     return null;
    // }
    //
    // fn walkTreeForConstraints(
    //     self: *Clew,
    //     node: zts.Node,
    //     constraints: *std.ArrayList(Constraint),
    //     func_count: *u32,
    //     typed_func_count: *u32,
    //     language: []const u8,
    // ) !void {
    //     _ = self;
    //     _ = constraints;
    //     _ = language;
    //
    //     // Get node type to identify syntactic constructs
    //     const node_type = node.type();
    //
    //     // Identify function definitions (language-specific node types)
    //     if (std.mem.eql(u8, node_type, "function_declaration") or
    //         std.mem.eql(u8, node_type, "method_definition") or
    //         std.mem.eql(u8, node_type, "function_definition") or
    //         std.mem.eql(u8, node_type, "fn_item"))
    //     {
    //         func_count.* += 1;
    //
    //         // Check if function has explicit type annotations
    //         var cursor = node.walk();
    //         defer cursor.deinit();
    //
    //         if (cursor.gotoFirstChild()) {
    //             while (true) {
    //                 const child = cursor.node();
    //                 const child_type = child.type();
    //
    //                 if (std.mem.indexOf(u8, child_type, "type") != null) {
    //                     typed_func_count.* += 1;
    //                     break;
    //                 }
    //
    //                 if (!cursor.gotoNextSibling()) break;
    //             }
    //         }
    //     }
    //
    //     // Recursively walk children
    //     var cursor = node.walk();
    //     defer cursor.deinit();
    //
    //     if (cursor.gotoFirstChild()) {
    //         while (true) {
    //             try self.walkTreeForConstraints(
    //                 cursor.node(),
    //                 constraints,
    //                 func_count,
    //                 typed_func_count,
    //                 language,
    //             );
    //
    //             if (!cursor.gotoNextSibling()) break;
    //         }
    //     }
    // }

    fn extractSyntacticConstraintsFallback(
        self: *Clew,
        source: []const u8,
    ) ![]Constraint {
        var constraints = std.ArrayList(Constraint){};

        // Simple pattern matching for unsupported languages
        if (std.mem.indexOf(u8, source, "function") != null or
            std.mem.indexOf(u8, source, "fn") != null or
            std.mem.indexOf(u8, source, "def") != null)
        {
            try constraints.append(self.allocator, Constraint{
                .kind = .syntactic,
                .severity = .info,
                .name = "has_functions",
                .description = "Code contains function definitions",
                .source = .AST_Pattern,
            });
        }

        return try constraints.toOwnedSlice(self.allocator);
    }

    fn extractTypeConstraints(
        self: *Clew,
        source: []const u8,
        language: []const u8,
    ) ![]Constraint {
        _ = language;

        var constraints = std.ArrayList(Constraint){};

        // Check for any/unknown types (TypeScript specific)
        if (std.mem.indexOf(u8, source, ": any") != null or
            std.mem.indexOf(u8, source, ": unknown") != null)
        {
            const constraint = Constraint{
                .kind = .type_safety,
                .severity = .warning,
                .name = "avoid_any_type",
                .description = "Avoid using 'any' or 'unknown' types",
                .source = .Type_System,
            };
            try constraints.append(self.allocator, constraint);
        }

        // Check for null safety
        if (std.mem.indexOf(u8, source, "?") != null or
            std.mem.indexOf(u8, source, "null") != null or
            std.mem.indexOf(u8, source, "undefined") != null)
        {
            const constraint = Constraint{
                .kind = .type_safety,
                .severity = .info,
                .name = "null_safety",
                .description = "Handle null/undefined values properly",
                .source = .Type_System,
            };
            try constraints.append(self.allocator, constraint);
        }

        return try constraints.toOwnedSlice(self.allocator);
    }

    fn parseTestAssertions(self: *Clew, test_source: []const u8) ![]TestAssertion {
        _ = self;
        _ = test_source;
        // TODO: Implement test assertion parsing
        return &.{};
    }

    fn assertionToConstraint(self: *Clew, assertion: TestAssertion) !Constraint {
        _ = self;
        _ = assertion;
        // TODO: Convert test assertions to constraints
        return Constraint.init(.semantic, "test_derived");
    }
};

/// Cache for extracted constraints
const ConstraintCache = struct {
    allocator: std.mem.Allocator,
    cache: std.StringHashMap(ConstraintSet),

    pub fn init(allocator: std.mem.Allocator) !ConstraintCache {
        return .{
            .allocator = allocator,
            .cache = std.StringHashMap(ConstraintSet).init(allocator),
        };
    }

    pub fn deinit(self: *ConstraintCache) void {
        var iter = self.cache.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.cache.deinit();
    }

    pub fn get(self: *ConstraintCache, key: []const u8) ?ConstraintSet {
        return self.cache.get(key);
    }

    pub fn put(self: *ConstraintCache, key: []const u8, value: ConstraintSet) !void {
        try self.cache.put(key, value);
    }
};

// Helper functions to convert between Claude and Ananke types

fn convertConstraintKind(claude_kind: claude_api.ConstraintKind) ConstraintKind {
    return switch (claude_kind) {
        .syntactic => .syntactic,
        .type_safety => .type_safety,
        .semantic => .semantic,
        .architectural => .architectural,
        .operational => .operational,
        .security => .security,
    };
}

fn convertSeverity(claude_severity: claude_api.Severity) Severity {
    return switch (claude_severity) {
        .err => .err,
        .warning => .warning,
        .info => .info,
        .hint => .hint,
    };
}

/// Telemetry data structure
pub const Telemetry = struct {
    latency_p50: ?f64 = null,
    latency_p99: ?f64 = null,
    error_rate: ?f64 = null,
    memory_usage: ?u64 = null,
    cpu_usage: ?f64 = null,
};

/// Test assertion structure
const TestAssertion = struct {
    name: []const u8,
    condition: []const u8,
    expected: []const u8,
};

