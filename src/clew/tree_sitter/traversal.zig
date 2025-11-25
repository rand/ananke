const std = @import("std");
const parser = @import("parser.zig");
const Node = parser.Node;
const Allocator = std.mem.Allocator;

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
            .pre_order => try self.traversePreOrder(root, 0, visitor, context),
            .post_order => try self.traversePostOrder(root, 0, visitor, context),
            .level_order => try self.traverseLevelOrder(root, visitor, context),
        }
    }

    /// Pre-order traversal (node, then children)
    fn traversePreOrder(
        self: Traversal,
        node: Node,
        depth: u32,
        visitor: VisitorFn,
        context: ?*anyopaque,
    ) !void {
        // Visit node first
        const should_continue = try visitor(node, depth, context);
        if (!should_continue) return;

        // Then visit children
        const child_count = node.namedChildCount();
        var i: u32 = 0;
        while (i < child_count) : (i += 1) {
            if (node.namedChild(i)) |child| {
                try self.traversePreOrder(child, depth + 1, visitor, context);
            }
        }
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

    /// Level-order (breadth-first) traversal
    fn traverseLevelOrder(
        self: Traversal,
        root: Node,
        visitor: VisitorFn,
        context: ?*anyopaque,
    ) !void {
        var queue = std.ArrayList(struct { node: Node, depth: u32 }).init(self.allocator);
        defer queue.deinit();

        try queue.append(.{ .node = root, .depth = 0 });

        while (queue.items.len > 0) {
            const item = queue.orderedRemove(0);
            const should_continue = try visitor(item.node, item.depth, context);
            if (!should_continue) return;

            // Add children to queue
            const child_count = item.node.namedChildCount();
            var i: u32 = 0;
            while (i < child_count) : (i += 1) {
                if (item.node.namedChild(i)) |child| {
                    try queue.append(.{ .node = child, .depth = item.depth + 1 });
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
        var results = std.ArrayList(Node).init(self.allocator);
        errdefer results.deinit();

        const Context = struct {
            predicate: *const fn (Node) bool,
            results: *std.ArrayList(Node),
        };

        var ctx = Context{
            .predicate = predicate,
            .results = &results,
        };

        const visitor = struct {
            fn visit(node: Node, depth: u32, context: ?*anyopaque) !bool {
                _ = depth;
                const c: *Context = @ptrCast(@alignCast(context.?));
                if (c.predicate(node)) {
                    try c.results.append(node);
                }
                return true;
            }
        }.visit;

        try self.traverse(root, .pre_order, visitor, &ctx);
        return try results.toOwnedSlice();
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
            fn visit(node: Node, depth: u32, context: ?*anyopaque) !bool {
                _ = depth;
                const c: *Context = @ptrCast(@alignCast(context.?));
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
            node_type: []const u8,
            results: std.ArrayList(Node),
        };

        var ctx = Context{
            .node_type = node_type,
            .results = std.ArrayList(Node).init(self.allocator),
        };
        errdefer ctx.results.deinit();

        const visitor = struct {
            fn visit(node: Node, depth: u32, context: ?*anyopaque) !bool {
                _ = depth;
                const c: *Context = @ptrCast(@alignCast(context.?));
                if (std.mem.eql(u8, node.nodeType(), c.node_type)) {
                    try c.results.append(node);
                }
                return true;
            }
        }.visit;

        try self.traverse(root, .pre_order, visitor, &ctx);
        return try ctx.results.toOwnedSlice();
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
            fn visit(node: Node, depth: u32, context: ?*anyopaque) !bool {
                const c: *Context = @ptrCast(@alignCast(context.?));

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

    var results = std.ArrayList(Node).init(allocator);
    defer results.deinit();

    for (function_types) |func_type| {
        const nodes = try t.findByType(root, func_type);
        defer allocator.free(nodes);
        try results.appendSlice(nodes);
    }

    return try results.toOwnedSlice();
}

/// Extract type/interface declarations
pub fn extractTypes(allocator: Allocator, root: Node) ![]Node {
    const t = Traversal.init(allocator);

    const type_node_types = [_][]const u8{
        "interface_declaration", // TypeScript/Java
        "type_alias_declaration", // TypeScript
        "class_declaration", // Most languages
        "struct_item", // Rust
        "struct_declaration", // C, Go
        "enum_declaration", // Many languages
        "trait_item", // Rust
    };

    var results = std.ArrayList(Node).init(allocator);
    defer results.deinit();

    for (type_node_types) |type_name| {
        const nodes = try t.findByType(root, type_name);
        defer allocator.free(nodes);
        try results.appendSlice(nodes);
    }

    return try results.toOwnedSlice();
}

/// Extract import/use statements
pub fn extractImports(allocator: Allocator, root: Node) ![]Node {
    const t = Traversal.init(allocator);

    const import_types = [_][]const u8{
        "import_statement", // Python
        "import_declaration", // JavaScript/TypeScript
        "use_declaration", // Rust
        "import_spec", // Go
        "include", // C/C++
    };

    var results = std.ArrayList(Node).init(allocator);
    defer results.deinit();

    for (import_types) |import_type| {
        const nodes = try t.findByType(root, import_type);
        defer allocator.free(nodes);
        try results.appendSlice(nodes);
    }

    return try results.toOwnedSlice();
}
