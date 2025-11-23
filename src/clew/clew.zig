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
                    .source = .{
                        .llm_analysis = .{
                            .provider = "claude",
                            .prompt = "code_analysis",
                            .confidence = claude_constraint.confidence,
                        },
                    },
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
                    .source = .{
                        .llm_analysis = .{
                            .provider = "claude",
                            .prompt = "test_intent_analysis",
                            .confidence = claude_constraint.confidence,
                        },
                    },
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
                    .source = .{ .telemetry = .{
                        .metric_name = "latency_p99",
                        .threshold = 100.0,
                    }},
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
                    .source = .{ .telemetry = .{
                        .metric_name = "error_rate",
                        .threshold = 0.01,
                    }},
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
        _ = language;

        var constraints = std.ArrayList(Constraint){};

        // Simple pattern matching for now
        // TODO: Integrate Tree-sitter for proper parsing

        // Check for function signatures
        if (std.mem.indexOf(u8, source, "function") != null or
            std.mem.indexOf(u8, source, "fn") != null or
            std.mem.indexOf(u8, source, "def") != null)
        {
            const constraint = Constraint{
                .kind = .syntactic,
                .severity = .info,
                .name = "has_functions",
                .description = "Code contains function definitions",
                .source = .{ .static_analysis = {} },
            };
            try constraints.append(self.allocator, constraint);
        }

        // Check for explicit return types
        if (std.mem.indexOf(u8, source, "->") != null or
            std.mem.indexOf(u8, source, ": ") != null)
        {
            const constraint = Constraint{
                .kind = .syntactic,
                .severity = .info,
                .name = "explicit_returns",
                .description = "Functions have explicit return types",
                .source = .{ .static_analysis = {} },
            };
            try constraints.append(self.allocator, constraint);
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
                .source = .{ .static_analysis = {} },
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
                .source = .{ .static_analysis = {} },
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

