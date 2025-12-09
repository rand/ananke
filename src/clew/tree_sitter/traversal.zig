const std = @import("std");
const parser = @import("parser.zig");
const Node = parser.Node;
const Allocator = std.mem.Allocator;

// ============================================================================
// Ring Queue - O(1) FIFO queue for BFS traversal
// ============================================================================

/// High-performance ring buffer queue with O(1) enqueue/dequeue.
/// Replaces ArrayList.orderedRemove(0) which is O(n).
fn RingQueue(comptime T: type) type {
    return struct {
        const Self = @This();

        items: []T,
        head: usize,
        tail: usize,
        count: usize,
        allocator: Allocator,

        fn init(allocator: Allocator, initial_capacity: usize) !Self {
            const capacity = std.math.ceilPowerOfTwo(usize, @max(initial_capacity, 4)) catch return error.OutOfMemory;
            const items = try allocator.alloc(T, capacity);
            return Self{
                .items = items,
                .head = 0,
                .tail = 0,
                .count = 0,
                .allocator = allocator,
            };
        }

        fn deinit(self: *Self) void {
            self.allocator.free(self.items);
        }

        fn enqueue(self: *Self, item: T) !void {
            if (self.count == self.items.len) {
                try self.grow();
            }
            self.items[self.tail] = item;
            self.tail = (self.tail + 1) & (self.items.len - 1);
            self.count += 1;
        }

        fn dequeue(self: *Self) !T {
            if (self.count == 0) return error.EmptyQueue;
            const item = self.items[self.head];
            self.head = (self.head + 1) & (self.items.len - 1);
            self.count -= 1;
            return item;
        }

        fn isEmpty(self: *Self) bool {
            return self.count == 0;
        }

        fn grow(self: *Self) !void {
            const old_capacity = self.items.len;
            const new_capacity = old_capacity * 2;
            var new_items = try self.allocator.alloc(T, new_capacity);

            var i: usize = 0;
            var current = self.head;
            while (i < self.count) : (i += 1) {
                new_items[i] = self.items[current];
                current = (current + 1) & (old_capacity - 1);
            }

            self.allocator.free(self.items);
            self.items = new_items;
            self.head = 0;
            self.tail = self.count;
        }
    };
}

/// Visitor callback for AST traversal
/// Returns true to continue traversal, false to stop
pub const VisitorFn = *const fn (node: Node, depth: u32, context: ?*anyopaque) anyerror!bool;

/// Traversal order
pub const TraversalOrder = enum {
    pre_order, // Visit node before children
    post_order, // Visit node after children
    level_order, // Breadth-first (level by level)
};

/// AST Traversal utility
pub const Traversal = struct {
    allocator: Allocator,

    pub fn init(allocator: Allocator) Traversal {
        return Traversal{ .allocator = allocator };
    }

    /// Traverse AST depth-first with visitor callback
    pub fn traverse(
        self: Traversal,
        root: Node,
        order: TraversalOrder,
        visitor: VisitorFn,
        context: ?*anyopaque,
    ) !void {
        switch (order) {
            .pre_order => _ = try self.traversePreOrder(root, 0, visitor, context),
            .post_order => try self.traversePostOrder(root, 0, visitor, context),
            .level_order => try self.traverseLevelOrder(root, visitor, context),
        }
    }

    /// Pre-order traversal (node, then children)
    /// Returns true if traversal should continue, false if stopped early
    fn traversePreOrder(
        self: Traversal,
        node: Node,
        depth: u32,
        visitor: VisitorFn,
        context: ?*anyopaque,
    ) !bool {
        // Visit node first
        const should_continue = try visitor(node, depth, context);
        if (!should_continue) return false;

        // Then visit children
        const child_count = node.namedChildCount();
        var i: u32 = 0;
        while (i < child_count) : (i += 1) {
            if (node.namedChild(i)) |child| {
                const continue_traversal = try self.traversePreOrder(child, depth + 1, visitor, context);
                if (!continue_traversal) return false;
            }
        }

        return true;
    }

    /// Post-order traversal (children, then node)
    fn traversePostOrder(
        self: Traversal,
        node: Node,
        depth: u32,
        visitor: VisitorFn,
        context: ?*anyopaque,
    ) !void {
        // Visit children first
        const child_count = node.namedChildCount();
        var i: u32 = 0;
        while (i < child_count) : (i += 1) {
            if (node.namedChild(i)) |child| {
                try self.traversePostOrder(child, depth + 1, visitor, context);
            }
        }

        // Then visit node
        _ = try visitor(node, depth, context);
    }

    /// Level-order (breadth-first) traversal using O(1) ring buffer queue.
    /// Replaces O(n) ArrayList.orderedRemove(0) with O(1) dequeue operation.
    fn traverseLevelOrder(
        self: Traversal,
        root: Node,
        visitor: VisitorFn,
        context: ?*anyopaque,
    ) !void {
        var queue = try RingQueue(struct { node: Node, depth: u32 }).init(self.allocator, 16);
        defer queue.deinit();

        try queue.enqueue(.{ .node = root, .depth = 0 });

        while (!queue.isEmpty()) {
            const item = try queue.dequeue();
            const should_continue = try visitor(item.node, item.depth, context);
            if (!should_continue) return;

            // Add children to queue
            const child_count = item.node.namedChildCount();
            var i: u32 = 0;
            while (i < child_count) : (i += 1) {
                if (item.node.namedChild(i)) |child| {
                    try queue.enqueue(.{ .node = child, .depth = item.depth + 1 });
                }
            }
        }
    }

    /// Find all nodes matching a predicate
    pub fn findAll(
        self: Traversal,
        root: Node,
        predicate: *const fn (Node) bool,
    ) ![]Node {
        var results = std.ArrayList(Node){};
        errdefer results.deinit(self.allocator);

        const Context = struct {
            allocator: Allocator,
            predicate: *const fn (Node) bool,
            results: *std.ArrayList(Node),
        };

        var ctx = Context{
            .allocator = self.allocator,
            .predicate = predicate,
            .results = &results,
        };

        const visitor = struct {
            fn visit(node: Node, depth: u32, context_ptr: ?*anyopaque) !bool {
                _ = depth;
                const c: *Context = @ptrCast(@alignCast(context_ptr.?));
                if (c.predicate(node)) {
                    try c.results.append(c.allocator, node);
                }
                return true;
            }
        }.visit;

        try self.traverse(root, .pre_order, visitor, &ctx);
        return try results.toOwnedSlice(self.allocator);
    }

    /// Find first node matching a predicate
    pub fn findFirst(
        self: Traversal,
        root: Node,
        predicate: *const fn (Node) bool,
    ) !?Node {
        const Context = struct {
            predicate: *const fn (Node) bool,
            result: ?Node,
        };

        var ctx = Context{
            .predicate = predicate,
            .result = null,
        };

        const visitor = struct {
            fn visit(node: Node, depth: u32, context_ptr: ?*anyopaque) !bool {
                _ = depth;
                const c: *Context = @ptrCast(@alignCast(context_ptr.?));
                if (c.predicate(node)) {
                    c.result = node;
                    return false; // Stop traversal
                }
                return true;
            }
        }.visit;

        try self.traverse(root, .pre_order, visitor, &ctx);
        return ctx.result;
    }

    /// Find all nodes of a specific type
    pub fn findByType(
        self: Traversal,
        root: Node,
        node_type: []const u8,
    ) ![]Node {
        // Create a closure-like context
        const Context = struct {
            allocator: Allocator,
            node_type: []const u8,
            results: std.ArrayList(Node),
        };

        var ctx = Context{
            .allocator = self.allocator,
            .node_type = node_type,
            .results = std.ArrayList(Node){},
        };
        errdefer ctx.results.deinit(self.allocator);

        const visitor = struct {
            fn visit(node: Node, depth: u32, context_ptr: ?*anyopaque) !bool {
                _ = depth;
                const c: *Context = @ptrCast(@alignCast(context_ptr.?));
                if (std.mem.eql(u8, node.nodeType(), c.node_type)) {
                    try c.results.append(c.allocator, node);
                }
                return true;
            }
        }.visit;

        try self.traverse(root, .pre_order, visitor, &ctx);
        return try ctx.results.toOwnedSlice(self.allocator);
    }

    /// Find all nodes matching any of the given types in a SINGLE traversal.
    /// This is 8x more efficient than calling findByType() separately for each type.
    /// Returns a StringHashMap where keys are node types and values are arrays of matching nodes.
    /// Caller must free the returned map and its contents.
    pub fn findByTypes(
        self: Traversal,
        root: Node,
        node_types: []const []const u8,
    ) !std.StringHashMap([]Node) {
        // Create context for visitor
        const Context = struct {
            allocator: Allocator,
            node_types: []const []const u8,
            results: std.StringHashMap(std.ArrayList(Node)),
        };

        var ctx = Context{
            .allocator = self.allocator,
            .node_types = node_types,
            .results = std.StringHashMap(std.ArrayList(Node)).init(self.allocator),
        };
        errdefer {
            var iter = ctx.results.valueIterator();
            while (iter.next()) |list| {
                list.deinit(self.allocator);
            }
            ctx.results.deinit();
        }

        // Pre-populate with empty lists for each type
        for (node_types) |nt| {
            try ctx.results.put(nt, std.ArrayList(Node){});
        }

        // Single traversal collecting all matching types
        const visitor = struct {
            fn visit(node: Node, depth: u32, context_ptr: ?*anyopaque) !bool {
                _ = depth;
                const c: *Context = @ptrCast(@alignCast(context_ptr.?));
                const ntype = node.nodeType();

                // Check if this node type is one we're looking for
                for (c.node_types) |target_type| {
                    if (std.mem.eql(u8, ntype, target_type)) {
                        if (c.results.getPtr(target_type)) |list| {
                            try list.append(c.allocator, node);
                        }
                        break; // Node type matched, no need to check others
                    }
                }
                return true;
            }
        }.visit;

        try self.traverse(root, .pre_order, visitor, &ctx);

        // Convert ArrayLists to owned slices
        var final_results = std.StringHashMap([]Node).init(self.allocator);
        errdefer final_results.deinit();

        var iter = ctx.results.iterator();
        while (iter.next()) |entry| {
            const slice = try entry.value_ptr.toOwnedSlice(self.allocator);
            try final_results.put(entry.key_ptr.*, slice);
        }
        ctx.results.deinit();

        return final_results;
    }

    /// Free the results returned by findByTypes
    pub fn freeFindByTypesResult(self: Traversal, result: *std.StringHashMap([]Node)) void {
        var iter = result.valueIterator();
        while (iter.next()) |slice| {
            self.allocator.free(slice.*);
        }
        result.deinit();
    }

    /// Get text for a node from source
    pub fn getNodeText(self: Traversal, node: Node, source: []const u8) []const u8 {
        _ = self;
        const start = node.startByte();
        const end = node.endByte();
        if (end > source.len) return "";
        return source[start..end];
    }

    /// Print AST tree structure (for debugging)
    pub fn printTree(self: Traversal, root: Node, source: []const u8, writer: anytype) !void {
        const Context = struct {
            traversal: Traversal,
            source: []const u8,
            writer: @TypeOf(writer),
        };

        var ctx = Context{
            .traversal = self,
            .source = source,
            .writer = writer,
        };

        const visitor = struct {
            fn visit(node: Node, depth: u32, context_ptr: ?*anyopaque) !bool {
                const c: *Context = @ptrCast(@alignCast(context_ptr.?));

                // Print indentation
                var i: u32 = 0;
                while (i < depth) : (i += 1) {
                    try c.writer.writeAll("  ");
                }

                // Print node type
                try c.writer.print("{s}", .{node.nodeType()});

                // Print text if it's a small leaf node
                const text = c.traversal.getNodeText(node, c.source);
                if (node.namedChildCount() == 0 and text.len < 50) {
                    try c.writer.print(": \"{s}\"", .{text});
                }

                try c.writer.writeAll("\n");
                return true;
            }
        }.visit;

        try self.traverse(root, .pre_order, visitor, &ctx);
    }
};

/// Helper functions for common constraint extraction patterns
/// Extract function/method declarations
pub fn extractFunctions(allocator: Allocator, root: Node) ![]Node {
    const t = Traversal.init(allocator);

    // Common function declaration node types across languages
    const function_types = [_][]const u8{
        "function_declaration", // C, Go, JavaScript
        "function_definition", // C++
        "function_item", // Rust
        "method_declaration", // Java
        "fn_decl", // Zig
        "function", // Python (can be function_definition in some grammars)
        "arrow_function", // JavaScript/TypeScript
        "method_definition", // JavaScript/TypeScript classes
    };

    var results = std.ArrayList(Node){};
    defer results.deinit(allocator);

    for (function_types) |func_type| {
        const nodes = try t.findByType(root, func_type);
        defer allocator.free(nodes);
        try results.appendSlice(allocator, nodes);
    }

    return try results.toOwnedSlice(allocator);
}

/// Extract type/interface declarations
pub fn extractTypes(allocator: Allocator, root: Node) ![]Node {
    const t = Traversal.init(allocator);

    const type_node_types = [_][]const u8{
        "interface_declaration", // TypeScript/Java
        "type_alias_declaration", // TypeScript
        "class_declaration", // TypeScript, Java, C++
        "class_definition", // Python
        "struct_item", // Rust
        "struct_declaration", // C, Go
        "enum_declaration", // Many languages
        "trait_item", // Rust
    };

    var results = std.ArrayList(Node){};
    defer results.deinit(allocator);

    for (type_node_types) |type_name| {
        const nodes = try t.findByType(root, type_name);
        defer allocator.free(nodes);
        try results.appendSlice(allocator, nodes);
    }

    return try results.toOwnedSlice(allocator);
}

/// Extract import/use statements
pub fn extractImports(allocator: Allocator, root: Node) ![]Node {
    const t = Traversal.init(allocator);

    const import_types = [_][]const u8{
        "import_statement", // Python (import x)
        "import_from_statement", // Python (from x import y)
        "import_declaration", // JavaScript/TypeScript
        "use_declaration", // Rust
        "import_spec", // Go
        "include", // C/C++
    };

    var results = std.ArrayList(Node){};
    defer results.deinit(allocator);

    for (import_types) |import_type| {
        const nodes = try t.findByType(root, import_type);
        defer allocator.free(nodes);
        try results.appendSlice(allocator, nodes);
    }

    return try results.toOwnedSlice(allocator);
}

// ============================================================================
// Identifier Extraction (for semantic-level constraints)
// ============================================================================

/// Represents a named declaration with its identifier
pub const NamedDeclaration = struct {
    node: Node,
    name: []const u8,
    kind: []const u8, // Node type (e.g., "function_declaration", "class_declaration")

    pub fn deinit(self: *NamedDeclaration, allocator: Allocator) void {
        allocator.free(self.name);
    }
};

/// Extract identifier name from a declaration node
fn extractIdentifierName(allocator: Allocator, node: Node, source: []const u8) !?[]const u8 {
    const t = Traversal.init(allocator);
    const node_type = node.nodeType();

    // Special handling for Python class_definition: extract name from source text
    // This is more robust across different tree-sitter Python parser versions
    if (std.mem.eql(u8, node_type, "class_definition")) {
        const class_text = t.getNodeText(node, source);

        // Look for "class ClassName" pattern (may be preceded by decorators)
        if (std.mem.indexOf(u8, class_text, "class ")) |class_pos| {
            var i: usize = class_pos + 6; // Start after "class "

            // Skip whitespace
            while (i < class_text.len and class_text[i] == ' ') : (i += 1) {}

            // Extract identifier (stop at '(', ':', whitespace, or newline)
            const start = i;
            while (i < class_text.len) : (i += 1) {
                const c = class_text[i];
                if (c == '(' or c == ':' or c == ' ' or c == '\n' or c == '\r') {
                    break;
                }
            }

            if (i > start) {
                const class_name = class_text[start..i];
                return try allocator.dupe(u8, class_name);
            }
        }
    }

    // First, try to get name using field accessor (more reliable across tree-sitter versions)
    if (node.childByFieldName("name")) |name_node| {
        const name_text = t.getNodeText(name_node, source);
        if (name_text.len > 0) {
            return try allocator.dupe(u8, name_text);
        }
    }

    // Fallback: Determine which identifier types to search based on node type
    // This is important because different declaration types use different identifier child types
    var identifier_types: []const []const u8 = undefined;

    if (std.mem.indexOf(u8, node_type, "class") != null or
        std.mem.indexOf(u8, node_type, "interface") != null or
        std.mem.indexOf(u8, node_type, "type_alias") != null or
        std.mem.eql(u8, node_type, "enum_declaration"))
    {
        // Type declarations use type_identifier for their name
        identifier_types = &[_][]const u8{
            "type_identifier", // The actual name of the type
            "identifier", // Fallback for some languages
            "name", // Generic fallback
        };
    } else {
        // Functions and other declarations use identifier for their name
        identifier_types = &[_][]const u8{
            "identifier", // The actual name of the function/variable
            "type_identifier", // Fallback for rare cases
            "name", // Generic fallback
        };
    }

    // Try to find identifier child in order
    for (identifier_types) |id_type| {
        const identifiers = try t.findByType(node, id_type);
        defer allocator.free(identifiers);

        if (identifiers.len > 0) {
            const id_node = identifiers[0];
            const id_text = t.getNodeText(id_node, source);
            if (id_text.len > 0) {
                return try allocator.dupe(u8, id_text);
            }
        }
    }

    return null;
}

/// Extract function declarations with their names
pub fn extractFunctionIdentifiers(allocator: Allocator, root: Node, source: []const u8) ![]NamedDeclaration {
    const functions = try extractFunctions(allocator, root);
    defer allocator.free(functions);

    var results = std.ArrayList(NamedDeclaration){};
    errdefer {
        for (results.items) |*item| {
            item.deinit(allocator);
        }
        results.deinit(allocator);
    }

    for (functions) |func_node| {
        if (try extractIdentifierName(allocator, func_node, source)) |name| {
            try results.append(allocator, .{
                .node = func_node,
                .name = name,
                .kind = func_node.nodeType(),
            });
        }
    }

    return try results.toOwnedSlice(allocator);
}

/// Extract type declarations with their names (classes, interfaces, structs, etc.)
pub fn extractTypeIdentifiers(allocator: Allocator, root: Node, source: []const u8) ![]NamedDeclaration {
    const types = try extractTypes(allocator, root);
    defer allocator.free(types);

    var results = std.ArrayList(NamedDeclaration){};
    errdefer {
        for (results.items) |*item| {
            item.deinit(allocator);
        }
        results.deinit(allocator);
    }

    for (types) |type_node| {
        if (try extractIdentifierName(allocator, type_node, source)) |name| {
            try results.append(allocator, .{
                .node = type_node,
                .name = name,
                .kind = type_node.nodeType(),
            });
        }
    }

    return try results.toOwnedSlice(allocator);
}

// ============================================================================
// Type Constraint Information (AST-based type analysis)
// ============================================================================

/// Structured information about type constraints extracted from AST nodes.
/// Replaces brittle string matching with AST-aware analysis.
pub const TypeConstraintInfo = struct {
    /// True if optional types are present (TypeScript `?`, `| undefined`, Python `Optional[]`)
    has_optional_types: bool = false,
    /// True if `any` or `unknown` types are present (TypeScript-specific, considered weak typing)
    has_any_types: bool = false,
    /// True if union types are present (`|` in TypeScript, `Union[]` in Python)
    has_union_types: bool = false,
    /// True if null/None is explicitly referenced in type annotations
    has_null_types: bool = false,
    /// Number of type annotations found
    type_annotation_count: u32 = 0,
    /// Confidence level of the analysis (0.0-1.0)
    confidence: f32 = 0.0,
};

/// Language-specific type annotation node types
const TypeAnnotationNodeTypes = struct {
    /// TypeScript/JavaScript type annotation nodes
    const typescript = [_][]const u8{
        "type_annotation",
        "type_alias_declaration",
        "interface_declaration",
        "type_predicate",
    };

    /// Python type hint nodes
    const python = [_][]const u8{
        "type",
        "type_parameter",
        "subscript", // Used for Optional[T], Union[T, U], etc.
    };

    /// Generic identifier nodes that might contain type info
    const generic = [_][]const u8{
        "type_identifier",
        "predefined_type",
        "generic_type",
    };
};

/// Extract type constraint information from AST nodes.
/// This is language-aware and only examines actual type annotation nodes,
/// avoiding false positives from comments, strings, and variable names.
pub fn extractTypeConstraintInfo(
    allocator: Allocator,
    root: Node,
    source: []const u8,
    language: []const u8,
) !TypeConstraintInfo {
    const t = Traversal.init(allocator);
    var info = TypeConstraintInfo{};

    // Determine which node types to search based on language
    const is_typescript = std.mem.eql(u8, language, "typescript") or
        std.mem.eql(u8, language, "javascript") or
        std.mem.eql(u8, language, "tsx") or
        std.mem.eql(u8, language, "jsx");
    const is_python = std.mem.eql(u8, language, "python");

    if (is_typescript) {
        info = try extractTypescriptConstraints(allocator, t, root, source);
    } else if (is_python) {
        info = try extractPythonConstraints(allocator, t, root, source);
    } else {
        // For other languages, do basic type annotation search
        info = try extractGenericConstraints(allocator, t, root, source);
    }

    return info;
}

/// Extract TypeScript-specific type constraints from AST
fn extractTypescriptConstraints(
    allocator: Allocator,
    t: Traversal,
    root: Node,
    source: []const u8,
) !TypeConstraintInfo {
    var info = TypeConstraintInfo{
        .confidence = 0.95, // High confidence for AST-based extraction
    };

    // Find all type annotation nodes
    for (TypeAnnotationNodeTypes.typescript) |node_type| {
        const type_nodes = try t.findByType(root, node_type);
        defer allocator.free(type_nodes);

        info.type_annotation_count += @intCast(type_nodes.len);

        for (type_nodes) |type_node| {
            const type_text = t.getNodeText(type_node, source);

            // Check for 'any' or 'unknown' (weak typing)
            // Only match as standalone types, not as part of other words
            if (containsTypeKeyword(type_text, "any") or
                containsTypeKeyword(type_text, "unknown"))
            {
                info.has_any_types = true;
            }

            // Check for optional types
            if (std.mem.indexOf(u8, type_text, "?") != null or
                containsTypeKeyword(type_text, "undefined"))
            {
                info.has_optional_types = true;
            }

            // Check for null types
            if (containsTypeKeyword(type_text, "null")) {
                info.has_null_types = true;
            }

            // Check for union types
            if (std.mem.indexOf(u8, type_text, "|") != null) {
                info.has_union_types = true;
            }
        }
    }

    // Also check for predefined_type nodes which contain 'any', 'unknown', etc.
    const predefined_types = try t.findByType(root, "predefined_type");
    defer allocator.free(predefined_types);

    for (predefined_types) |pred_node| {
        const pred_text = t.getNodeText(pred_node, source);
        if (std.mem.eql(u8, pred_text, "any") or std.mem.eql(u8, pred_text, "unknown")) {
            info.has_any_types = true;
        }
        if (std.mem.eql(u8, pred_text, "undefined")) {
            info.has_optional_types = true;
        }
        if (std.mem.eql(u8, pred_text, "null")) {
            info.has_null_types = true;
        }
    }

    return info;
}

/// Extract Python-specific type constraints from AST
fn extractPythonConstraints(
    allocator: Allocator,
    t: Traversal,
    root: Node,
    source: []const u8,
) !TypeConstraintInfo {
    var info = TypeConstraintInfo{
        .confidence = 0.95,
    };

    // Find type hint nodes (Python uses 'type' nodes for annotations)
    for (TypeAnnotationNodeTypes.python) |node_type| {
        const type_nodes = try t.findByType(root, node_type);
        defer allocator.free(type_nodes);

        info.type_annotation_count += @intCast(type_nodes.len);

        for (type_nodes) |type_node| {
            const type_text = t.getNodeText(type_node, source);

            // Python's Any type from typing module
            if (std.mem.indexOf(u8, type_text, "Any") != null) {
                info.has_any_types = true;
            }

            // Python's Optional[T] or T | None (3.10+)
            if (std.mem.indexOf(u8, type_text, "Optional") != null or
                std.mem.indexOf(u8, type_text, "| None") != null or
                std.mem.indexOf(u8, type_text, "|None") != null)
            {
                info.has_optional_types = true;
            }

            // Python's None type
            if (std.mem.indexOf(u8, type_text, "None") != null) {
                info.has_null_types = true;
            }

            // Python's Union type
            if (std.mem.indexOf(u8, type_text, "Union") != null or
                std.mem.indexOf(u8, type_text, "|") != null)
            {
                info.has_union_types = true;
            }
        }
    }

    return info;
}

/// Extract generic type constraints for languages without specific handling
fn extractGenericConstraints(
    allocator: Allocator,
    t: Traversal,
    root: Node,
    source: []const u8,
) !TypeConstraintInfo {
    var info = TypeConstraintInfo{
        .confidence = 0.80, // Lower confidence for generic extraction
    };

    // Look for generic type identifier nodes
    for (TypeAnnotationNodeTypes.generic) |node_type| {
        const type_nodes = try t.findByType(root, node_type);
        defer allocator.free(type_nodes);

        info.type_annotation_count += @intCast(type_nodes.len);

        for (type_nodes) |type_node| {
            const type_text = t.getNodeText(type_node, source);

            // Generic checks (conservative)
            if (std.mem.eql(u8, type_text, "any") or
                std.mem.eql(u8, type_text, "Any"))
            {
                info.has_any_types = true;
            }
        }
    }

    return info;
}

/// Check if a type text contains a specific type keyword as a standalone type.
/// Avoids matching "any" in "company" or "many".
fn containsTypeKeyword(text: []const u8, keyword: []const u8) bool {
    var pos: usize = 0;
    while (pos < text.len) {
        if (std.mem.indexOfPos(u8, text, pos, keyword)) |idx| {
            // Check that it's a standalone word (not part of another identifier)
            const before_ok = idx == 0 or !isIdentifierChar(text[idx - 1]);
            const after_idx = idx + keyword.len;
            const after_ok = after_idx >= text.len or !isIdentifierChar(text[after_idx]);

            if (before_ok and after_ok) {
                return true;
            }
            pos = idx + 1;
        } else {
            break;
        }
    }
    return false;
}

/// Check if a character can be part of an identifier
fn isIdentifierChar(c: u8) bool {
    return (c >= 'a' and c <= 'z') or
        (c >= 'A' and c <= 'Z') or
        (c >= '0' and c <= '9') or
        c == '_';
}
