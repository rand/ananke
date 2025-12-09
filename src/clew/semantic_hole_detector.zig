const std = @import("std");
const tree_sitter = @import("tree_sitter");
const parser = tree_sitter.parser;
const traversal = tree_sitter.traversal;
const Node = parser.Node;
const Language = parser.Language;
const Allocator = std.mem.Allocator;

// Import hole types
const ananke = @import("ananke");
const hole_types = ananke.types.hole;
const Hole = hole_types.Hole;
const HoleScale = hole_types.HoleScale;
const HoleOrigin = hole_types.HoleOrigin;
const Location = hole_types.Location;
const Provenance = hole_types.Provenance;

/// Semantic hole detector using tree-sitter AST analysis
pub const SemanticHoleDetector = struct {
    allocator: Allocator,

    pub const SemanticHole = struct {
        kind: SemanticHoleKind,
        location: Location,
        expected_type: ?[]const u8,
        context: []const u8,
        confidence: f32,

        pub fn deinit(self: *SemanticHole, allocator: Allocator) void {
            if (self.expected_type) |et| {
                allocator.free(et);
            }
            allocator.free(self.context);
        }
    };

    pub const SemanticHoleKind = enum {
        empty_function_body,
        unimplemented_method,
        incomplete_match,
        missing_type_annotation,
        missing_await,
        unhandled_error,
    };

    pub fn init(allocator: Allocator) SemanticHoleDetector {
        return .{
            .allocator = allocator,
        };
    }

    /// Detect all semantic holes in the AST
    pub fn detectAll(
        self: *SemanticHoleDetector,
        root: Node,
        source: []const u8,
        language: Language,
    ) ![]SemanticHole {
        var holes = std.ArrayList(SemanticHole){};
        errdefer {
            for (holes.items) |*h| {
                h.deinit(self.allocator);
            }
            holes.deinit(self.allocator);
        }

        // Detect empty function bodies
        const empty_body_holes = try self.detectEmptyBodies(root, source, language);
        defer self.allocator.free(empty_body_holes);
        try holes.appendSlice(self.allocator, empty_body_holes);

        // Detect unimplemented methods
        const unimpl_holes = try self.detectUnimplementedMethods(root, source, language);
        defer self.allocator.free(unimpl_holes);
        try holes.appendSlice(self.allocator, unimpl_holes);

        // Detect incomplete match/switch expressions
        const incomplete_match_holes = try self.detectIncompleteMatches(root, source, language);
        defer self.allocator.free(incomplete_match_holes);
        try holes.appendSlice(self.allocator, incomplete_match_holes);

        // Detect missing type annotations
        const missing_type_holes = try self.detectMissingTypeAnnotations(root, source, language);
        defer self.allocator.free(missing_type_holes);
        try holes.appendSlice(self.allocator, missing_type_holes);

        return try holes.toOwnedSlice(self.allocator);
    }

    /// Detect empty function bodies (high confidence semantic holes)
    pub fn detectEmptyBodies(
        self: *SemanticHoleDetector,
        root: Node,
        source: []const u8,
        language: Language,
    ) ![]SemanticHole {
        var holes = std.ArrayList(SemanticHole){};
        errdefer {
            for (holes.items) |*h| {
                h.deinit(self.allocator);
            }
            holes.deinit(self.allocator);
        }

        const t = traversal.Traversal.init(self.allocator);

        // Get function node types based on language
        const func_types = getFunctionNodeTypes(language);

        for (func_types) |func_type| {
            const functions = try t.findByType(root, func_type);
            defer self.allocator.free(functions);

            for (functions) |func_node| {
                if (try self.isFunctionBodyEmpty(func_node, source, language, t)) {
                    const location = nodeToLocation(func_node, "");
                    const context = try std.fmt.allocPrint(
                        self.allocator,
                        "Empty {s}",
                        .{func_type},
                    );

                    try holes.append(self.allocator, .{
                        .kind = .empty_function_body,
                        .location = location,
                        .expected_type = null,
                        .context = context,
                        .confidence = 0.95,
                    });
                }
            }
        }

        return try holes.toOwnedSlice(self.allocator);
    }

    /// Detect unimplemented methods (raise NotImplementedError, throw, unimplemented!(), etc.)
    pub fn detectUnimplementedMethods(
        self: *SemanticHoleDetector,
        root: Node,
        source: []const u8,
        language: Language,
    ) ![]SemanticHole {
        var holes = std.ArrayList(SemanticHole){};
        errdefer {
            for (holes.items) |*h| {
                h.deinit(self.allocator);
            }
            holes.deinit(self.allocator);
        }

        const t = traversal.Traversal.init(self.allocator);

        switch (language) {
            .python => {
                // Look for raise NotImplementedError
                const raise_stmts = try t.findByType(root, "raise_statement");
                defer self.allocator.free(raise_stmts);

                for (raise_stmts) |raise_node| {
                    const raise_text = t.getNodeText(raise_node, source);
                    if (std.mem.indexOf(u8, raise_text, "NotImplementedError") != null) {
                        const location = nodeToLocation(raise_node, "");
                        const context = try self.allocator.dupe(u8, "Raises NotImplementedError");

                        try holes.append(self.allocator, .{
                            .kind = .unimplemented_method,
                            .location = location,
                            .expected_type = null,
                            .context = context,
                            .confidence = 0.98,
                        });
                    }
                }
            },
            .rust => {
                // Look for unimplemented!() or todo!()
                const macro_calls = try t.findByType(root, "macro_invocation");
                defer self.allocator.free(macro_calls);

                for (macro_calls) |macro_node| {
                    const macro_text = t.getNodeText(macro_node, source);
                    if (std.mem.indexOf(u8, macro_text, "unimplemented!") != null or
                        std.mem.indexOf(u8, macro_text, "todo!") != null)
                    {
                        const location = nodeToLocation(macro_node, "");
                        const context = try self.allocator.dupe(u8, "Unimplemented macro");

                        try holes.append(self.allocator, .{
                            .kind = .unimplemented_method,
                            .location = location,
                            .expected_type = null,
                            .context = context,
                            .confidence = 0.98,
                        });
                    }
                }
            },
            .typescript, .javascript => {
                // Look for throw new Error('TODO') or throw new Error('Not implemented')
                const throw_stmts = try t.findByType(root, "throw_statement");
                defer self.allocator.free(throw_stmts);

                for (throw_stmts) |throw_node| {
                    const throw_text = t.getNodeText(throw_node, source);
                    if (std.mem.indexOf(u8, throw_text, "TODO") != null or
                        std.mem.indexOf(u8, throw_text, "Not implemented") != null or
                        std.mem.indexOf(u8, throw_text, "NotImplementedError") != null)
                    {
                        const location = nodeToLocation(throw_node, "");
                        const context = try self.allocator.dupe(u8, "Throws unimplemented error");

                        try holes.append(self.allocator, .{
                            .kind = .unimplemented_method,
                            .location = location,
                            .expected_type = null,
                            .context = context,
                            .confidence = 0.90,
                        });
                    }
                }
            },
            .zig => {
                // Look for @panic("TODO") or unreachable
                const panic_calls = try t.findByType(root, "builtin_call_expr");
                defer self.allocator.free(panic_calls);

                for (panic_calls) |panic_node| {
                    const panic_text = t.getNodeText(panic_node, source);
                    if (std.mem.indexOf(u8, panic_text, "@panic") != null and
                        (std.mem.indexOf(u8, panic_text, "TODO") != null or
                        std.mem.indexOf(u8, panic_text, "not implemented") != null))
                    {
                        const location = nodeToLocation(panic_node, "");
                        const context = try self.allocator.dupe(u8, "Panic TODO");

                        try holes.append(self.allocator, .{
                            .kind = .unimplemented_method,
                            .location = location,
                            .expected_type = null,
                            .context = context,
                            .confidence = 0.95,
                        });
                    }
                }
            },
            else => {},
        }

        return try holes.toOwnedSlice(self.allocator);
    }

    /// Detect incomplete match/switch expressions (missing default/wildcard)
    pub fn detectIncompleteMatches(
        self: *SemanticHoleDetector,
        root: Node,
        source: []const u8,
        language: Language,
    ) ![]SemanticHole {
        var holes = std.ArrayList(SemanticHole){};
        errdefer {
            for (holes.items) |*h| {
                h.deinit(self.allocator);
            }
            holes.deinit(self.allocator);
        }

        const t = traversal.Traversal.init(self.allocator);

        switch (language) {
            .python => {
                // Python's match statement (3.10+)
                const match_stmts = try t.findByType(root, "match_statement");
                defer self.allocator.free(match_stmts);

                for (match_stmts) |match_node| {
                    const match_text = t.getNodeText(match_node, source);
                    // Look for wildcard pattern '_'
                    if (std.mem.indexOf(u8, match_text, "case _:") == null) {
                        const location = nodeToLocation(match_node, "");
                        const context = try self.allocator.dupe(u8, "Match without wildcard case");

                        try holes.append(self.allocator, .{
                            .kind = .incomplete_match,
                            .location = location,
                            .expected_type = null,
                            .context = context,
                            .confidence = 0.70,
                        });
                    }
                }
            },
            .rust => {
                // Rust match expressions
                const match_exprs = try t.findByType(root, "match_expression");
                defer self.allocator.free(match_exprs);

                for (match_exprs) |match_node| {
                    const match_text = t.getNodeText(match_node, source);
                    // Check for _ => or contains todo!()
                    const has_wildcard = std.mem.indexOf(u8, match_text, "_ =>") != null;
                    const has_todo = std.mem.indexOf(u8, match_text, "todo!()") != null;

                    if (has_wildcard and has_todo) {
                        const location = nodeToLocation(match_node, "");
                        const context = try self.allocator.dupe(u8, "Match with todo!() wildcard");

                        try holes.append(self.allocator, .{
                            .kind = .incomplete_match,
                            .location = location,
                            .expected_type = null,
                            .context = context,
                            .confidence = 0.95,
                        });
                    }
                }
            },
            .typescript, .javascript => {
                // TypeScript switch expressions
                const switch_stmts = try t.findByType(root, "switch_statement");
                defer self.allocator.free(switch_stmts);

                for (switch_stmts) |switch_node| {
                    const switch_text = t.getNodeText(switch_node, source);
                    // Check for default case
                    if (std.mem.indexOf(u8, switch_text, "default:") == null) {
                        const location = nodeToLocation(switch_node, "");
                        const context = try self.allocator.dupe(u8, "Switch without default case");

                        try holes.append(self.allocator, .{
                            .kind = .incomplete_match,
                            .location = location,
                            .expected_type = null,
                            .context = context,
                            .confidence = 0.65,
                        });
                    }
                }
            },
            .zig => {
                // Zig switch expressions
                const switch_exprs = try t.findByType(root, "switch_expr");
                defer self.allocator.free(switch_exprs);

                for (switch_exprs) |switch_node| {
                    const switch_text = t.getNodeText(switch_node, source);
                    // Check for else => unreachable
                    const has_else = std.mem.indexOf(u8, switch_text, "else =>") != null;
                    const has_unreachable = std.mem.indexOf(u8, switch_text, "unreachable") != null;

                    if (has_else and has_unreachable) {
                        const location = nodeToLocation(switch_node, "");
                        const context = try self.allocator.dupe(u8, "Switch with unreachable else");

                        try holes.append(self.allocator, .{
                            .kind = .incomplete_match,
                            .location = location,
                            .expected_type = null,
                            .context = context,
                            .confidence = 0.90,
                        });
                    }
                }
            },
            else => {},
        }

        return try holes.toOwnedSlice(self.allocator);
    }

    /// Detect missing type annotations in typed contexts
    pub fn detectMissingTypeAnnotations(
        self: *SemanticHoleDetector,
        root: Node,
        source: []const u8,
        language: Language,
    ) ![]SemanticHole {
        var holes = std.ArrayList(SemanticHole){};
        errdefer {
            for (holes.items) |*h| {
                h.deinit(self.allocator);
            }
            holes.deinit(self.allocator);
        }

        const t = traversal.Traversal.init(self.allocator);

        switch (language) {
            .zig => {
                // Look for anytype parameters
                // Zig uses "ParamDecl" node type
                const params = try t.findByType(root, "ParamDecl");
                defer self.allocator.free(params);

                for (params) |param_node| {
                    const param_text = t.getNodeText(param_node, source);
                    if (std.mem.indexOf(u8, param_text, "anytype") != null) {
                        const location = nodeToLocation(param_node, "");
                        const context = try self.allocator.dupe(u8, "Parameter with anytype");

                        try holes.append(self.allocator, .{
                            .kind = .missing_type_annotation,
                            .location = location,
                            .expected_type = try self.allocator.dupe(u8, "specific type"),
                            .context = context,
                            .confidence = 0.75,
                        });
                    }
                }
            },
            .rust => {
                // Look for _ type placeholders
                const params = try t.findByType(root, "parameter");
                defer self.allocator.free(params);

                for (params) |param_node| {
                    const param_text = t.getNodeText(param_node, source);
                    // Check for _ type in parameter
                    if (std.mem.indexOf(u8, param_text, ": _") != null) {
                        const location = nodeToLocation(param_node, "");
                        const context = try self.allocator.dupe(u8, "Parameter with inferred type");

                        try holes.append(self.allocator, .{
                            .kind = .missing_type_annotation,
                            .location = location,
                            .expected_type = try self.allocator.dupe(u8, "explicit type"),
                            .context = context,
                            .confidence = 0.80,
                        });
                    }
                }
            },
            else => {},
        }

        return try holes.toOwnedSlice(self.allocator);
    }

    // Helper methods

    /// Check if a function body is empty (contains only pass, unreachable, etc.)
    fn isFunctionBodyEmpty(
        self: *SemanticHoleDetector,
        func_node: Node,
        source: []const u8,
        language: Language,
        t: traversal.Traversal,
    ) !bool {
        _ = self;

        // Get the body node - try field name first, then look for Block child
        var body_node = func_node.childByFieldName("body");

        // For Zig, the body might be a Block node child
        if (body_node == null and language == .zig) {
            const children_count = func_node.namedChildCount();
            var i: u32 = 0;
            while (i < children_count) : (i += 1) {
                if (func_node.namedChild(i)) |child| {
                    const node_type = child.nodeType();
                    if (std.mem.eql(u8, node_type, "Block")) {
                        body_node = child;
                        break;
                    }
                }
            }
        }

        if (body_node == null) return false;

        const body_text = t.getNodeText(body_node.?, source);

        // Trim whitespace for accurate checking
        var trimmed = std.mem.trim(u8, body_text, &std.ascii.whitespace);

        switch (language) {
            .python => {
                // Check for block that only contains 'pass' or '...'
                // Remove braces/brackets and check content
                if (std.mem.startsWith(u8, trimmed, "{") or std.mem.startsWith(u8, trimmed, ":")) {
                    trimmed = std.mem.trim(u8, trimmed[1..], &std.ascii.whitespace);
                }
                return std.mem.eql(u8, trimmed, "pass") or
                    std.mem.eql(u8, trimmed, "...") or
                    std.mem.eql(u8, trimmed, "");
            },
            .typescript, .javascript => {
                // Check for empty block {}
                if (std.mem.startsWith(u8, trimmed, "{")) {
                    trimmed = std.mem.trim(u8, trimmed[1..], &std.ascii.whitespace);
                    if (std.mem.endsWith(u8, trimmed, "}")) {
                        trimmed = std.mem.trim(u8, trimmed[0 .. trimmed.len - 1], &std.ascii.whitespace);
                    }
                }
                return trimmed.len == 0;
            },
            .rust => {
                // Check for empty block or block with only unimplemented!()
                if (std.mem.startsWith(u8, trimmed, "{")) {
                    trimmed = std.mem.trim(u8, trimmed[1..], &std.ascii.whitespace);
                    if (std.mem.endsWith(u8, trimmed, "}")) {
                        trimmed = std.mem.trim(u8, trimmed[0 .. trimmed.len - 1], &std.ascii.whitespace);
                    }
                }
                return trimmed.len == 0 or
                    std.mem.indexOf(u8, trimmed, "unimplemented!()") != null or
                    std.mem.indexOf(u8, trimmed, "todo!()") != null;
            },
            .zig => {
                // Check for unreachable or empty block
                if (std.mem.startsWith(u8, trimmed, "{")) {
                    trimmed = std.mem.trim(u8, trimmed[1..], &std.ascii.whitespace);
                    if (std.mem.endsWith(u8, trimmed, "}")) {
                        trimmed = std.mem.trim(u8, trimmed[0 .. trimmed.len - 1], &std.ascii.whitespace);
                    }
                }
                return trimmed.len == 0 or std.mem.eql(u8, trimmed, "unreachable");
            },
            else => return false,
        }
    }
};

// Helper functions

/// Get function node types for a given language
fn getFunctionNodeTypes(language: Language) []const []const u8 {
    return switch (language) {
        .python => &[_][]const u8{ "function_definition", "async_function_definition" },
        .typescript, .javascript => &[_][]const u8{ "function_declaration", "method_definition", "arrow_function" },
        .rust => &[_][]const u8{ "function_item", "function_signature_item" },
        // Zig tree-sitter uses "FnProto" for function prototypes/declarations
        .zig => &[_][]const u8{ "FnProto", "TestDecl" },
        .go => &[_][]const u8{ "function_declaration", "method_declaration" },
        else => &[_][]const u8{},
    };
}

/// Convert a tree-sitter Node to a hole Location
fn nodeToLocation(node: Node, file_path: []const u8) Location {
    const start = node.startPoint();
    const end = node.endPoint();

    return .{
        .file_path = file_path,
        .start_line = start.row + 1, // tree-sitter uses 0-based rows
        .start_column = start.column + 1,
        .end_line = end.row + 1,
        .end_column = end.column + 1,
    };
}
