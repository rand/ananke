const std = @import("std");
const Allocator = std.mem.Allocator;
const Constraint = @import("ananke").types.constraint.Constraint;
const ConstraintKind = @import("ananke").types.constraint.ConstraintKind;
const Severity = @import("ananke").types.constraint.Severity;
const StringInterner = @import("ananke").utils.StringInterner;

// Import tree-sitter components
const tree_sitter = @import("tree_sitter");
const TreeSitterParser = tree_sitter.TreeSitterParser;
const Language = tree_sitter.Language;
const Traversal = tree_sitter.Traversal;

// Import pattern-based extractors
const patterns = @import("patterns.zig");

/// Extraction strategy for hybrid approach
pub const ExtractionStrategy = enum {
    tree_sitter_only, // Only use tree-sitter, fail if unavailable
    pattern_only, // Only use pattern-based extraction
    tree_sitter_with_fallback, // Try tree-sitter, fall back to patterns
    combined, // Use both and merge results
};

/// Extraction result with metadata
pub const ExtractionResult = struct {
    constraints: []Constraint,
    strategy_used: ExtractionStrategy,
    tree_sitter_available: bool,
    tree_sitter_errors: ?[]const u8 = null,

    pub fn deinit(self: *ExtractionResult, allocator: Allocator) void {
        // Note: Caller is responsible for freeing constraint strings (name, description)
        // if they take ownership of the constraints. This method only frees the slice itself.
        allocator.free(self.constraints);
        if (self.tree_sitter_errors) |errors| {
            allocator.free(errors);
        }
    }

    /// Free all constraint strings and the slice (use when not transferring ownership)
    /// NOTE: With string interning, individual strings are NOT freed here
    /// The StringInterner owns all interned strings
    pub fn deinitFull(self: *ExtractionResult, allocator: Allocator) void {
        // When using string interning, we DON'T free individual strings
        // They're owned by the interner and freed in its deinit()
        allocator.free(self.constraints);
        if (self.tree_sitter_errors) |errors| {
            allocator.free(errors);
        }
    }
};

/// Hybrid extractor that intelligently combines tree-sitter and pattern-based extraction
pub const HybridExtractor = struct {
    allocator: Allocator,
    strategy: ExtractionStrategy,
    interner: StringInterner,

    pub fn init(allocator: Allocator, strategy: ExtractionStrategy) !HybridExtractor {
        return .{
            .allocator = allocator,
            .strategy = strategy,
            .interner = try StringInterner.init(allocator),
        };
    }

    pub fn deinit(self: *HybridExtractor) void {
        self.interner.deinit();
    }

    /// Extract constraints using the configured strategy
    pub fn extract(
        self: *HybridExtractor,
        source: []const u8,
        language_name: []const u8,
    ) !ExtractionResult {
        switch (self.strategy) {
            .tree_sitter_only => return try self.extractTreeSitterOnly(source, language_name),
            .pattern_only => return try self.extractPatternOnly(source, language_name),
            .tree_sitter_with_fallback => return try self.extractWithFallback(source, language_name),
            .combined => return try self.extractCombined(source, language_name),
        }
    }

    /// Extract using only tree-sitter (fail if unavailable)
    fn extractTreeSitterOnly(
        self: *HybridExtractor,
        source: []const u8,
        language_name: []const u8,
    ) !ExtractionResult {
        const lang = languageFromName(language_name) orelse {
            return ExtractionResult{
                .constraints = &[_]Constraint{},
                .strategy_used = .tree_sitter_only,
                .tree_sitter_available = false,
                .tree_sitter_errors = try self.allocator.dupe(u8, "Language not supported"),
            };
        };

        const constraints = self.extractWithTreeSitter(source, lang) catch |err| {
            const error_msg = try std.fmt.allocPrint(
                self.allocator,
                "Tree-sitter extraction failed: {}",
                .{err},
            );
            return ExtractionResult{
                .constraints = &[_]Constraint{},
                .strategy_used = .tree_sitter_only,
                .tree_sitter_available = true,
                .tree_sitter_errors = error_msg,
            };
        };

        return ExtractionResult{
            .constraints = constraints,
            .strategy_used = .tree_sitter_only,
            .tree_sitter_available = true,
        };
    }

    /// Extract using only pattern-based approach
    fn extractPatternOnly(
        self: *HybridExtractor,
        source: []const u8,
        language_name: []const u8,
    ) !ExtractionResult {
        const constraints = try self.extractWithPatterns(source, language_name);

        return ExtractionResult{
            .constraints = constraints,
            .strategy_used = .pattern_only,
            .tree_sitter_available = false,
        };
    }

    /// Try tree-sitter first, fall back to patterns if it fails
    fn extractWithFallback(
        self: *HybridExtractor,
        source: []const u8,
        language_name: []const u8,
    ) !ExtractionResult {
        // Try tree-sitter first
        if (languageFromName(language_name)) |lang| {
            if (self.extractWithTreeSitter(source, lang)) |constraints| {
                return ExtractionResult{
                    .constraints = constraints,
                    .strategy_used = .tree_sitter_with_fallback,
                    .tree_sitter_available = true,
                };
            } else |err| {
                // Log the tree-sitter error but continue with fallback
                std.log.debug("Tree-sitter extraction failed ({}), falling back to patterns", .{err});
            }
        }

        // Fall back to pattern-based extraction
        const constraints = try self.extractWithPatterns(source, language_name);

        return ExtractionResult{
            .constraints = constraints,
            .strategy_used = .tree_sitter_with_fallback,
            .tree_sitter_available = languageFromName(language_name) != null,
        };
    }

    /// Use both approaches and merge results
    fn extractCombined(
        self: *HybridExtractor,
        source: []const u8,
        language_name: []const u8,
    ) !ExtractionResult {
        var all_constraints = std.ArrayList(Constraint){};
        defer all_constraints.deinit(self.allocator);

        var tree_sitter_available = false;
        var tree_sitter_errors: ?[]const u8 = null;

        // Try tree-sitter extraction
        if (languageFromName(language_name)) |lang| {
            tree_sitter_available = true;

            if (self.extractWithTreeSitter(source, lang)) |ts_constraints| {
                defer self.allocator.free(ts_constraints);
                try all_constraints.appendSlice(self.allocator, ts_constraints);
            } else |err| {
                tree_sitter_errors = try std.fmt.allocPrint(
                    self.allocator,
                    "Tree-sitter extraction failed: {}",
                    .{err},
                );
            }
        }

        // Always run pattern-based extraction for additional coverage
        const pattern_constraints = try self.extractWithPatterns(source, language_name);
        defer {
            // Free the pattern constraints slice (strings are owned by interner)
            self.allocator.free(pattern_constraints);
        }

        // Track which pattern constraints are used to avoid memory leaks
        var pattern_constraints_used = try std.ArrayList(bool).initCapacity(
            self.allocator,
            pattern_constraints.len,
        );
        defer pattern_constraints_used.deinit(self.allocator);
        for (pattern_constraints) |_| {
            try pattern_constraints_used.append(self.allocator, false);
        }

        // Merge pattern constraints, avoiding duplicates
        for (pattern_constraints, 0..) |pattern_constraint, idx| {
            // Simple duplicate check based on name and kind
            var is_duplicate = false;
            for (all_constraints.items) |existing| {
                if (std.mem.eql(u8, existing.name, pattern_constraint.name) and
                    existing.kind == pattern_constraint.kind)
                {
                    is_duplicate = true;
                    break;
                }
            }

            if (!is_duplicate) {
                try all_constraints.append(self.allocator, pattern_constraint);
                pattern_constraints_used.items[idx] = true;
            }
        }

        // NOTE: With string interning, we don't free unused constraint strings
        // The interner owns all strings and will free them in its deinit()

        return ExtractionResult{
            .constraints = try all_constraints.toOwnedSlice(self.allocator),
            .strategy_used = .combined,
            .tree_sitter_available = tree_sitter_available,
            .tree_sitter_errors = tree_sitter_errors,
        };
    }

    /// Extract constraints using tree-sitter AST
    fn extractWithTreeSitter(
        self: *HybridExtractor,
        source: []const u8,
        language: Language,
    ) ![]Constraint {
        var parser = try TreeSitterParser.init(self.allocator, language);
        defer parser.deinit();

        var tree = try parser.parse(source);
        defer tree.deinit();

        const root = tree.rootNode();

        // Check for parse errors
        if (root.hasError()) {
            return error.ParseError;
        }

        var constraints = std.ArrayList(Constraint){};
        errdefer {
            for (constraints.items) |*constraint| {
                _ = constraint;
            }
            constraints.deinit(self.allocator);
        }

        // Extract individual function identifiers
        const func_ids = try tree_sitter.traversal.extractFunctionIdentifiers(self.allocator, root, source);
        defer {
            for (func_ids) |*func_id| {
                var mut_func_id = func_id.*;
                mut_func_id.deinit(self.allocator);
            }
            self.allocator.free(func_ids);
        }

        for (func_ids) |func_id| {
            // OPTIMIZATION: Intern both name and description template
            const interned_name = try self.interner.intern(func_id.name);
            const description = try std.fmt.allocPrint(
                self.allocator,
                "Function declaration: {s}",
                .{func_id.name},
            );
            defer self.allocator.free(description);
            const interned_desc = try self.interner.intern(description);

            const constraint = Constraint{
                .kind = .syntactic,
                .severity = .info,
                .name = interned_name,
                .description = interned_desc,
                .source = .AST_Pattern,
                .confidence = 0.95, // Tree-sitter AST has higher confidence
                .frequency = 1,
            };
            try constraints.append(self.allocator, constraint);
        }

        // Extract individual type identifiers (classes, interfaces, etc.)
        const type_ids = try tree_sitter.traversal.extractTypeIdentifiers(self.allocator, root, source);
        defer {
            for (type_ids) |*type_id| {
                var mut_type_id = type_id.*;
                mut_type_id.deinit(self.allocator);
            }
            self.allocator.free(type_ids);
        }

        for (type_ids) |type_id| {
            // OPTIMIZATION: Intern type names and descriptions
            const interned_name = try self.interner.intern(type_id.name);
            const description = try std.fmt.allocPrint(
                self.allocator,
                "Type declaration: {s}",
                .{type_id.name},
            );
            defer self.allocator.free(description);
            const interned_desc = try self.interner.intern(description);

            const constraint = Constraint{
                .kind = .type_safety,
                .severity = .info,
                .name = interned_name,
                .description = interned_desc,
                .source = .Type_System,
                .confidence = 0.95,
                .frequency = 1,
            };
            try constraints.append(self.allocator, constraint);
        }

        // Extract import-related constraints (keep aggregate count for backward compatibility)
        const imports = try tree_sitter.traversal.extractImports(self.allocator, root);
        defer self.allocator.free(imports);

        if (imports.len > 0) {
            // OPTIMIZATION: Intern common constraint name
            const interned_name = try self.interner.intern("ast_imports");
            const description = try std.fmt.allocPrint(
                self.allocator,
                "Code has {} import statements (AST)",
                .{imports.len},
            );
            defer self.allocator.free(description);
            const interned_desc = try self.interner.intern(description);

            const constraint = Constraint{
                .kind = .syntactic,
                .severity = .info,
                .name = interned_name,
                .description = interned_desc,
                .source = .AST_Pattern,
                .confidence = 0.95,
                .frequency = @intCast(imports.len),
            };
            try constraints.append(self.allocator, constraint);
        }

        return try constraints.toOwnedSlice(self.allocator);
    }

    /// Extract constraints using pattern-based approach
    fn extractWithPatterns(
        self: *HybridExtractor,
        source: []const u8,
        language_name: []const u8,
    ) ![]Constraint {
        var constraints = std.ArrayList(Constraint){};
        errdefer {
            // With string interning, we DON'T free individual strings
            constraints.deinit(self.allocator);
        }

        // Get patterns for the specified language
        const lang_patterns = patterns.getPatternsForLanguage(language_name) orelse {
            // Return empty constraints for unsupported languages
            return try constraints.toOwnedSlice(self.allocator);
        };

        // Find all pattern matches
        const matches = try patterns.findPatternMatches(
            self.allocator,
            source,
            lang_patterns,
        );
        defer self.allocator.free(matches);

        // Track unique constraint types to avoid duplicates
        var seen_patterns = std.StringHashMap(void).init(self.allocator);
        defer {
            // Clean up seen_patterns keys
            var iter = seen_patterns.keyIterator();
            while (iter.next()) |key| {
                self.allocator.free(key.*);
            }
            seen_patterns.deinit();
        }

        // Convert matches to constraints
        for (matches) |match| {
            const key = try std.fmt.allocPrint(
                self.allocator,
                "{s}_{s}",
                .{ match.rule.description, @tagName(match.rule.constraint_kind) },
            );
            defer self.allocator.free(key);

            // Skip if we've already seen this pattern type
            if (seen_patterns.contains(key)) {
                continue;
            }
            try seen_patterns.put(try self.allocator.dupe(u8, key), {});

            // OPTIMIZATION: Intern constraint name and description
            const interned_name = try self.interner.intern(match.rule.description);
            const description = try std.fmt.allocPrint(
                self.allocator,
                "{s} detected at line {} (pattern)",
                .{ match.rule.description, match.line },
            );
            defer self.allocator.free(description);
            const interned_desc = try self.interner.intern(description);

            // Create constraint from pattern match
            const constraint = Constraint{
                .kind = match.rule.constraint_kind,
                .severity = .info,
                .name = interned_name,
                .description = interned_desc,
                .source = .AST_Pattern,
                .origin_line = match.line,
                .confidence = 0.75, // Pattern matching has lower confidence than AST
            };

            try constraints.append(self.allocator, constraint);
        }

        return try constraints.toOwnedSlice(self.allocator);
    }

    /// Print string interning statistics for performance analysis
    pub fn printInternerStats(self: *const HybridExtractor) void {
        self.interner.printStats();
    }
};

/// Map language name string to tree-sitter Language enum
fn languageFromName(name: []const u8) ?Language {
    if (std.mem.eql(u8, name, "typescript")) return .typescript;
    if (std.mem.eql(u8, name, "javascript")) return .javascript;
    if (std.mem.eql(u8, name, "python")) return .python;
    if (std.mem.eql(u8, name, "rust")) return .rust;
    if (std.mem.eql(u8, name, "go")) return .go;
    if (std.mem.eql(u8, name, "zig")) return .zig;
    if (std.mem.eql(u8, name, "c")) return .c;
    if (std.mem.eql(u8, name, "cpp")) return .cpp;
    if (std.mem.eql(u8, name, "java")) return .java;
    return null;
}
