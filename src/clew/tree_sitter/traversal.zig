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

    // Determine which identifier types to search based on node type
    // This is important because different declaration types use different identifier child types
    var identifier_types: []const []const u8 = undefined;

    if (std.mem.indexOf(u8, node_type, "class") != null or
        std.mem.indexOf(u8, node_type, "interface") != null or
        std.mem.indexOf(u8, node_type, "type_alias") != null or
        std.mem.eql(u8, node_type, "enum_declaration")) {
        // Type declarations use type_identifier for their name
        identifier_types = &[_][]const u8{
            "type_identifier",      // The actual name of the type
            "identifier",           // Fallback for some languages
            "name",                 // Generic fallback
        };
    } else {
        // Functions and other declarations use identifier for their name
        identifier_types = &[_][]const u8{
            "identifier",           // The actual name of the function/variable
            "type_identifier",      // Fallback for rare cases
            "name",                 // Generic fallback
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
