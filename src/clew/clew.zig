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

// Import pattern matching module
const patterns = @import("patterns.zig");

// Import structural extractors (pure Zig AST-like parsing)
const extractors = @import("extractors.zig");

// Structural parsing enabled (pure Zig implementation, no tree-sitter dependency)
const structural_parsing_enabled = true;

/// Main Clew extraction engine
pub const Clew = struct {
    allocator: std.mem.Allocator,
    arena: std.heap.ArenaAllocator,
    claude_client: ?*claude_api.ClaudeClient = null,
    cache: ConstraintCache,

    pub fn init(allocator: std.mem.Allocator) !Clew {
        return .{
            .allocator = allocator,
            .arena = std.heap.ArenaAllocator.init(allocator),
            .cache = try ConstraintCache.init(allocator),
        };
    }

    pub fn deinit(self: *Clew) void {
        self.cache.deinit();
        self.arena.deinit(); // Frees all arena allocations
    }

    /// Get allocator for temporary constraint strings
    fn constraintAllocator(self: *Clew) std.mem.Allocator {
        return self.arena.allocator();
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
        // Check cache first
        const cache_key = try self.buildCacheKey(source, self.claude_client != null);
        defer self.allocator.free(cache_key);

        if (try self.cache.get(cache_key)) |cached| {
            // Cache hit - return cloned copy (caller owns it)
            return cached;
        }

        // Cache miss - extract constraints
        var constraint_set = ConstraintSet.init(self.allocator, "code_constraints");

        // 1. Tree-sitter parsing for syntactic constraints
        const syntax_constraints = try self.extractSyntacticConstraints(source, language);
        defer self.allocator.free(syntax_constraints);
        for (syntax_constraints) |constraint| {
            try constraint_set.add(constraint);
        }

        // 2. Type-level constraint discovery
        const type_constraints = try self.extractTypeConstraints(source, language);
        defer self.allocator.free(type_constraints);
        for (type_constraints) |constraint| {
            try constraint_set.add(constraint);
        }

        // 3. Optional: Use Claude for semantic understanding
        if (self.claude_client) |client| {
            const claude_constraints = client.analyzeCode(source, language) catch |err| {
                // Log warning but continue with pattern-based extraction
                std.log.warn("Claude analysis failed: {}, continuing with syntactic constraints only", .{err});
                // Return without Claude constraints
                return constraint_set;
            };
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

        // Cache the result for future lookups
        // Note: put() clones the constraint_set, so we still own the original
        try self.cache.put(cache_key, constraint_set);

        return constraint_set;
    }

    /// Extract constraints from test files
    pub fn extractFromTests(self: *Clew, test_source: []const u8) !ConstraintSet {
        var constraint_set = ConstraintSet.init(self.allocator, "test_constraints");

        // Parse test assertions to infer constraints (syntactic extraction)
        const assertions = try self.parseTestAssertions(test_source);
        defer self.allocator.free(assertions);

        for (assertions) |assertion| {
            const constraint = try self.assertionToConstraint(assertion);
            try constraint_set.add(constraint);
        }

        // Use Claude to understand test intent if available (semantic extraction)
        if (self.claude_client) |client| {
            const analysis = client.analyzeTestIntent(test_source) catch |err| {
                // Log warning but continue with pattern-based extraction
                std.log.warn("Claude test analysis failed: {}, continuing with assertion-based constraints only", .{err});
                return constraint_set;
            };
            defer self.allocator.free(analysis.constraints);
            defer self.allocator.free(analysis.intent_description);

            std.log.info("Test intent from Claude: {s}", .{analysis.intent_description});

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
        // Use structural extractors for supported languages (TypeScript, Python)
        // Falls back to pattern matching for other languages
        if (structural_parsing_enabled) {
            const structural_constraints = extractors.extract(
                self.allocator,
                self.constraintAllocator(),
                source,
                language,
            ) catch |err| {
                std.log.warn("Structural extraction failed: {}, falling back to pattern matching", .{err});
                return try self.extractSyntacticConstraintsFallback(source, language);
            };

            // If we got structural constraints, combine with pattern-based ones for completeness
            if (structural_constraints.len > 0) {
                const pattern_constraints = try self.extractSyntacticConstraintsFallback(source, language);
                defer self.allocator.free(pattern_constraints);

                // Merge both sets (structural parsing + pattern matching)
                var combined = std.ArrayList(Constraint){};
                defer combined.deinit(self.allocator);

                try combined.appendSlice(self.allocator, structural_constraints);
                try combined.appendSlice(self.allocator, pattern_constraints);

                return try combined.toOwnedSlice(self.allocator);
            }
        }

        // Fallback to pattern-based extraction
        return try self.extractSyntacticConstraintsFallback(source, language);
    }


    fn extractSyntacticConstraintsFallback(
        self: *Clew,
        source: []const u8,
        language: []const u8,
    ) ![]Constraint {
        var constraints = std.ArrayList(Constraint){};
        defer constraints.deinit(self.allocator);

        // Get patterns for the specified language
        const lang_patterns = patterns.getPatternsForLanguage(language);
        if (lang_patterns == null) {
            // Fallback to simple detection for unsupported languages
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

        // Find all pattern matches
        const matches = try patterns.findPatternMatches(
            self.allocator,
            source,
            lang_patterns.?,
        );
        defer self.allocator.free(matches);

        // Track unique constraint types to avoid duplicates
        var seen_patterns = std.StringHashMap(void).init(self.allocator);
        defer seen_patterns.deinit();

        // Track allocated keys to free them later
        var pattern_keys = std.ArrayList([]const u8){};
        defer {
            for (pattern_keys.items) |key| {
                self.allocator.free(key);
            }
            pattern_keys.deinit(self.allocator);
        }

        // Convert matches to constraints
        for (matches) |match| {
            // Create unique key for this pattern
            const key = try std.fmt.allocPrint(
                self.allocator,
                "{s}_{s}",
                .{ match.rule.description, @tagName(match.rule.constraint_kind) },
            );

            // Skip if we've already seen this pattern type
            if (seen_patterns.contains(key)) {
                self.allocator.free(key); // Free immediately if duplicate
                continue;
            }
            try seen_patterns.put(key, {});
            try pattern_keys.append(self.allocator, key); // Track for later cleanup

            // Create constraint from pattern match
            const name = try self.constraintAllocator().dupe(u8, match.rule.description);
            const description = try std.fmt.allocPrint(
                self.constraintAllocator(),
                "{s} detected at line {d} in {s} code",
                .{ match.rule.description, match.line, language },
            );

            const constraint = Constraint{
                .kind = match.rule.constraint_kind,
                .severity = .info,
                .name = name,
                .description = description,
                .source = .AST_Pattern,
                .origin_line = match.line,
                .confidence = 0.85, // Pattern-based matching has good but not perfect confidence
            };

            try constraints.append(self.allocator, constraint);
        }

        // Generate summary constraints based on pattern frequency
        const function_count = countPatternOccurrences(matches, "function");
        const type_count = countPatternOccurrences(matches, "type");
        const async_count = countPatternOccurrences(matches, "async");
        const error_count = countPatternOccurrences(matches, "error");

        // Add high-level constraints based on analysis
        if (function_count > 0) {
            const func_desc = try std.fmt.allocPrint(
                self.constraintAllocator(),
                "Code contains {d} function-related constructs",
                .{function_count},
            );
            try constraints.append(self.allocator, Constraint{
                .kind = .syntactic,
                .severity = .info,
                .name = "function_structure",
                .description = func_desc,
                .source = .AST_Pattern,
                .frequency = function_count,
            });
        }

        if (type_count > 0) {
            const type_desc = try std.fmt.allocPrint(
                self.constraintAllocator(),
                "Strong type safety with {d} type annotations",
                .{type_count},
            );
            try constraints.append(self.allocator, Constraint{
                .kind = .type_safety,
                .severity = .info,
                .name = "type_annotations",
                .description = type_desc,
                .source = .Type_System,
                .frequency = type_count,
                .confidence = if (type_count > 5) 0.9 else 0.7,
            });
        }

        if (async_count > 0) {
            const async_desc = try std.fmt.allocPrint(
                self.constraintAllocator(),
                "Asynchronous code with {d} async patterns",
                .{async_count},
            );
            try constraints.append(self.allocator, Constraint{
                .kind = .semantic,
                .severity = .info,
                .name = "async_patterns",
                .description = async_desc,
                .source = .Control_Flow,
                .frequency = async_count,
            });
        }

        if (error_count > 0) {
            const error_desc = try std.fmt.allocPrint(
                self.constraintAllocator(),
                "Explicit error handling with {d} error patterns",
                .{error_count},
            );
            try constraints.append(self.allocator, Constraint{
                .kind = .semantic,
                .severity = .info,
                .name = "error_handling",
                .description = error_desc,
                .source = .Control_Flow,
                .frequency = error_count,
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
        defer constraints.deinit(self.allocator);

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

    /// Build cache key that includes source content and Claude availability
    fn buildCacheKey(self: *Clew, source: []const u8, claude_enabled: bool) ![]const u8 {
        // Create a hash-based key to handle large source files efficiently
        var hasher = std.hash.Wyhash.init(0);
        hasher.update(source);
        const source_hash = hasher.final();

        // Include Claude availability in key to separate cached results
        const prefix = if (claude_enabled) "claude_" else "syntactic_";

        return try std.fmt.allocPrint(
            self.allocator,
            "{s}{x:0>16}",
            .{ prefix, source_hash },
        );
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
        // TODO: Implement proper assertion-to-constraint conversion
        return Constraint.init(0, "test_derived", "Constraint derived from test assertion");
    }
};

/// Cache for extracted constraints with clone-on-get semantics.
///
/// Ownership model:
/// - Cache owns all stored ConstraintSets
/// - get() returns a cloned copy (caller owns it and must call deinit())
/// - put() clones the input before storing (caller still owns original)
/// - Cache's deinit() frees all owned ConstraintSets
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
        // Free all owned ConstraintSets and keys
        var iter = self.cache.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.deinit();
            self.allocator.free(entry.key_ptr.*);
        }
        self.cache.deinit();
    }

    /// Get a cached ConstraintSet by key.
    /// Returns a CLONED copy if found - caller owns it and must call deinit().
    /// Returns null if not found.
    pub fn get(self: *ConstraintCache, key: []const u8) !?ConstraintSet {
        if (self.cache.get(key)) |cached_set| {
            // Return a clone so caller owns independent copy
            return try cached_set.clone(self.allocator);
        }
        return null;
    }

    /// Store a ConstraintSet in the cache.
    /// The input is CLONED before storing - caller still owns the original.
    /// Key is also duplicated for cache ownership.
    pub fn put(self: *ConstraintCache, key: []const u8, value: ConstraintSet) !void {
        // Check if key already exists and free old value/key if so
        if (self.cache.getKey(key)) |existing_key| {
            if (self.cache.getPtr(key)) |old_value| {
                old_value.deinit();
            }
            self.allocator.free(existing_key);
        }

        // Clone the value so cache owns independent copy
        var cloned_value = try value.clone(self.allocator);
        errdefer cloned_value.deinit();

        // Duplicate the key for cache ownership
        const owned_key = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(owned_key);

        try self.cache.put(owned_key, cloned_value);
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

/// Count how many pattern matches contain a keyword in their description
fn countPatternOccurrences(matches: []const patterns.PatternMatch, keyword: []const u8) u32 {
    var count: u32 = 0;
    for (matches) |match| {
        if (std.mem.indexOf(u8, match.rule.description, keyword) != null) {
            count += 1;
        }
    }
    return count;
}
