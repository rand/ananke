// Tree-sitter Traversal Tests
// Tests AST traversal utilities and extraction functions

const std = @import("std");
const testing = std.testing;

const tree_sitter = @import("tree_sitter");
const TreeSitterParser = tree_sitter.TreeSitterParser;
const Language = tree_sitter.Language;
const Traversal = tree_sitter.Traversal;
const TraversalOrder = tree_sitter.TraversalOrder;

// Import traversal helper functions
const traversal_helpers = tree_sitter.traversal;

// ============================================================================
// Test Data
// ============================================================================

const typescript_sample =
    \\import { Database } from './database';
    \\import * as utils from './utils';
    \\
    \\interface User {
    \\    id: number;
    \\    name: string;
    \\}
    \\
    \\type UserResult = User | null;
    \\
    \\class UserService {
    \\    constructor(private db: Database) {}
    \\    
    \\    async getUser(id: number): Promise<User> {
    \\        return { id, name: "test" };
    \\    }
    \\}
    \\
    \\function processUser(user: User): void {
    \\    console.log(user.name);
    \\}
    \\
    \\const arrowFunc = (x: number) => x * 2;
;

const python_sample =
    \\from typing import Optional, List
    \\import asyncio
    \\
    \\class User:
    \\    def __init__(self, id: int, name: str):
    \\        self.id = id
    \\        self.name = name
    \\
    \\async def fetch_user(user_id: int) -> Optional[User]:
    \\    return User(id=user_id, name="test")
    \\
    \\def process_user(user: User) -> None:
    \\    print(user.name)
    \\
    \\lambda_func = lambda x: x * 2
;

// ============================================================================
// Traversal Helper Function Tests
// ============================================================================

test "Traversal: extractFunctions finds TypeScript functions" {
    const allocator = testing.allocator;

    var parser = try TreeSitterParser.init(allocator, .typescript);
    defer parser.deinit();

    var tree = try parser.parse(typescript_sample);
    defer tree.deinit();

    const root = tree.rootNode();
    const functions = try traversal_helpers.extractFunctions(allocator, root);
    defer allocator.free(functions);

    // Should find: class methods, regular functions, arrow functions
    // Minimum: getUser (method), processUser (function)
    try testing.expect(functions.len >= 2);

    // Verify we can get node types
    var found_method = false;
    var found_function = false;

    for (functions) |func| {
        const node_type = func.nodeType();
        if (std.mem.indexOf(u8, node_type, "method") != null) {
            found_method = true;
        }
        if (std.mem.indexOf(u8, node_type, "function") != null) {
            found_function = true;
        }
    }

    try testing.expect(found_method or found_function);
}

test "Traversal: extractFunctions finds Python functions" {
    const allocator = testing.allocator;

    var parser = try TreeSitterParser.init(allocator, .python);
    defer parser.deinit();

    var tree = try parser.parse(python_sample);
    defer tree.deinit();

    const root = tree.rootNode();
    const functions = try traversal_helpers.extractFunctions(allocator, root);
    defer allocator.free(functions);

    // Should find: __init__, fetch_user, process_user
    try testing.expect(functions.len >= 3);
}

test "Traversal: extractTypes finds TypeScript types" {
    const allocator = testing.allocator;

    var parser = try TreeSitterParser.init(allocator, .typescript);
    defer parser.deinit();

    var tree = try parser.parse(typescript_sample);
    defer tree.deinit();

    const root = tree.rootNode();
    const types = try traversal_helpers.extractTypes(allocator, root);
    defer allocator.free(types);

    // Should find: User (interface), UserResult (type alias), UserService (class)
    try testing.expect(types.len >= 3);

    // Verify node types include interface, type_alias, class
    var found_interface = false;
    var found_class = false;
    var found_type_alias = false;

    for (types) |type_node| {
        const node_type = type_node.nodeType();
        if (std.mem.indexOf(u8, node_type, "interface") != null) {
            found_interface = true;
        }
        if (std.mem.indexOf(u8, node_type, "class") != null) {
            found_class = true;
        }
        if (std.mem.indexOf(u8, node_type, "type_alias") != null) {
            found_type_alias = true;
        }
    }

    try testing.expect(found_interface);
    try testing.expect(found_class);
    try testing.expect(found_type_alias);
}

test "Traversal: extractTypes finds Python classes" {
    const allocator = testing.allocator;

    var parser = try TreeSitterParser.init(allocator, .python);
    defer parser.deinit();

    var tree = try parser.parse(python_sample);
    defer tree.deinit();

    const root = tree.rootNode();
    const types = try traversal_helpers.extractTypes(allocator, root);
    defer allocator.free(types);

    // Should find: User (class)
    try testing.expect(types.len >= 1);

    // Verify it's a class
    const class_node = types[0];
    const node_type = class_node.nodeType();
    try testing.expect(std.mem.indexOf(u8, node_type, "class") != null);
}

test "Traversal: extractImports finds TypeScript imports" {
    const allocator = testing.allocator;

    var parser = try TreeSitterParser.init(allocator, .typescript);
    defer parser.deinit();

    var tree = try parser.parse(typescript_sample);
    defer tree.deinit();

    const root = tree.rootNode();
    const imports = try traversal_helpers.extractImports(allocator, root);
    defer allocator.free(imports);

    // Should find: 2 import statements
    try testing.expect(imports.len >= 2);

    // Verify they're import declarations
    for (imports) |import_node| {
        const node_type = import_node.nodeType();
        try testing.expect(std.mem.indexOf(u8, node_type, "import") != null);
    }
}

test "Traversal: extractImports finds Python imports" {
    const allocator = testing.allocator;

    var parser = try TreeSitterParser.init(allocator, .python);
    defer parser.deinit();

    var tree = try parser.parse(python_sample);
    defer tree.deinit();

    const root = tree.rootNode();
    const imports = try traversal_helpers.extractImports(allocator, root);
    defer allocator.free(imports);

    // Should find: from typing import..., import asyncio
    try testing.expect(imports.len >= 2);
}

// ============================================================================
// Traversal Object Tests
// ============================================================================

test "Traversal: findByType locates specific node types" {
    const allocator = testing.allocator;

    var parser = try TreeSitterParser.init(allocator, .typescript);
    defer parser.deinit();

    var tree = try parser.parse(typescript_sample);
    defer tree.deinit();

    const root = tree.rootNode();
    const t = Traversal.init(allocator);

    // Find all interface declarations
    const interfaces = try t.findByType(root, "interface_declaration");
    defer allocator.free(interfaces);

    try testing.expect(interfaces.len >= 1);

    // Verify node type
    for (interfaces) |interface| {
        try testing.expectEqualStrings("interface_declaration", interface.nodeType());
    }
}

test "Traversal: findAll with predicate" {
    const allocator = testing.allocator;

    var parser = try TreeSitterParser.init(allocator, .typescript);
    defer parser.deinit();

    var tree = try parser.parse(typescript_sample);
    defer tree.deinit();

    const root = tree.rootNode();
    const t = Traversal.init(allocator);

    // Find all nodes with "async" in the type
    const predicate = struct {
        fn check(node: tree_sitter.Node) bool {
            return std.mem.indexOf(u8, node.nodeType(), "async") != null or
                std.mem.indexOf(u8, node.nodeType(), "await") != null;
        }
    }.check;

    const async_nodes = try t.findAll(root, predicate);
    defer allocator.free(async_nodes);

    // May or may not find async nodes depending on grammar
    // Just verify it doesn't crash
}

test "Traversal: findFirst locates first matching node" {
    const allocator = testing.allocator;

    var parser = try TreeSitterParser.init(allocator, .typescript);
    defer parser.deinit();

    var tree = try parser.parse(typescript_sample);
    defer tree.deinit();

    const root = tree.rootNode();
    const t = Traversal.init(allocator);

    // Find first class declaration
    const predicate = struct {
        fn check(node: tree_sitter.Node) bool {
            return std.mem.eql(u8, node.nodeType(), "class_declaration");
        }
    }.check;

    const first_class = try t.findFirst(root, predicate);

    try testing.expect(first_class != null);
    if (first_class) |class_node| {
        try testing.expectEqualStrings("class_declaration", class_node.nodeType());
    }
}

test "Traversal: traverse with pre-order" {
    const allocator = testing.allocator;

    var parser = try TreeSitterParser.init(allocator, .typescript);
    defer parser.deinit();

    var tree = try parser.parse("function foo() { return 42; }");
    defer tree.deinit();

    const root = tree.rootNode();
    const t = Traversal.init(allocator);

    // Count all nodes visited
    const Context = struct {
        count: u32,
    };

    var ctx = Context{ .count = 0 };

    const visitor = struct {
        fn visit(node: tree_sitter.Node, depth: u32, context: ?*anyopaque) !bool {
            _ = node;
            _ = depth;
            const c: *Context = @ptrCast(@alignCast(context.?));
            c.count += 1;
            return true;
        }
    }.visit;

    try t.traverse(root, .pre_order, visitor, &ctx);

    // Should have visited multiple nodes
    try testing.expect(ctx.count > 1);
}

test "Traversal: traverse with post-order" {
    const allocator = testing.allocator;

    var parser = try TreeSitterParser.init(allocator, .python);
    defer parser.deinit();

    var tree = try parser.parse("def foo():\n    return 42");
    defer tree.deinit();

    const root = tree.rootNode();
    const t = Traversal.init(allocator);

    const Context = struct {
        count: u32,
    };

    var ctx = Context{ .count = 0 };

    const visitor = struct {
        fn visit(node: tree_sitter.Node, depth: u32, context: ?*anyopaque) !bool {
            _ = node;
            _ = depth;
            const c: *Context = @ptrCast(@alignCast(context.?));
            c.count += 1;
            return true;
        }
    }.visit;

    try t.traverse(root, .post_order, visitor, &ctx);

    try testing.expect(ctx.count > 1);
}

test "Traversal: traverse with level-order (breadth-first)" {
    const allocator = testing.allocator;

    var parser = try TreeSitterParser.init(allocator, .typescript);
    defer parser.deinit();

    var tree = try parser.parse("class Foo { method() {} }");
    defer tree.deinit();

    const root = tree.rootNode();
    const t = Traversal.init(allocator);

    const Context = struct {
        count: u32,
    };

    var ctx = Context{ .count = 0 };

    const visitor = struct {
        fn visit(node: tree_sitter.Node, depth: u32, context: ?*anyopaque) !bool {
            _ = node;
            _ = depth;
            const c: *Context = @ptrCast(@alignCast(context.?));
            c.count += 1;
            return true;
        }
    }.visit;

    try t.traverse(root, .level_order, visitor, &ctx);

    try testing.expect(ctx.count > 1);
}

test "Traversal: visitor can stop traversal early" {
    const allocator = testing.allocator;

    var parser = try TreeSitterParser.init(allocator, .typescript);
    defer parser.deinit();

    var tree = try parser.parse(typescript_sample);
    defer tree.deinit();

    const root = tree.rootNode();
    const t = Traversal.init(allocator);

    const Context = struct {
        count: u32,
        max_count: u32,
    };

    var ctx = Context{ .count = 0, .max_count = 5 };

    const visitor = struct {
        fn visit(node: tree_sitter.Node, depth: u32, context: ?*anyopaque) !bool {
            _ = node;
            _ = depth;
            const c: *Context = @ptrCast(@alignCast(context.?));
            c.count += 1;
            return c.count < c.max_count; // Stop after max_count
        }
    }.visit;

    try t.traverse(root, .pre_order, visitor, &ctx);

    // Should have stopped early
    try testing.expectEqual(@as(u32, 5), ctx.count);
}

test "Traversal: getNodeText extracts source text" {
    const allocator = testing.allocator;

    const source = "function hello() { return 'world'; }";

    var parser = try TreeSitterParser.init(allocator, .typescript);
    defer parser.deinit();

    var tree = try parser.parse(source);
    defer tree.deinit();

    const root = tree.rootNode();
    const t = Traversal.init(allocator);

    // Get text for root node
    const text = t.getNodeText(root, source);

    // Should match the source
    try testing.expectEqualStrings(source, text);
}

// ============================================================================
// Node Navigation Tests
// ============================================================================

test "Traversal: node navigation - children" {
    const allocator = testing.allocator;

    var parser = try TreeSitterParser.init(allocator, .typescript);
    defer parser.deinit();

    var tree = try parser.parse("function foo() {}");
    defer tree.deinit();

    const root = tree.rootNode();

    // Root should have children
    try testing.expect(root.childCount() > 0);
    try testing.expect(root.namedChildCount() > 0);

    // First named child should exist
    const first_child = root.namedChild(0);
    try testing.expect(first_child != null);
}

test "Traversal: node navigation - siblings" {
    const allocator = testing.allocator;

    const source =
        \\function foo() {}
        \\function bar() {}
    ;

    var parser = try TreeSitterParser.init(allocator, .typescript);
    defer parser.deinit();

    var tree = try parser.parse(source);
    defer tree.deinit();

    const root = tree.rootNode();

    if (root.namedChild(0)) |first_func| {
        const sibling = first_func.nextNamedSibling();
        try testing.expect(sibling != null);

        if (sibling) |second_func| {
            // Should be another function
            try testing.expect(std.mem.indexOf(u8, second_func.nodeType(), "function") != null);
        }
    }
}

test "Traversal: node properties - position info" {
    const allocator = testing.allocator;

    var parser = try TreeSitterParser.init(allocator, .typescript);
    defer parser.deinit();

    var tree = try parser.parse("function foo() {}");
    defer tree.deinit();

    const root = tree.rootNode();

    // Should have valid byte positions
    try testing.expect(root.startByte() == 0);
    try testing.expect(root.endByte() > 0);

    // Should have valid point positions
    const start_point = root.startPoint();
    const end_point = root.endPoint();

    try testing.expect(start_point.row == 0);
    try testing.expect(end_point.row >= start_point.row);
}

test "Traversal: node properties - flags" {
    const allocator = testing.allocator;

    var parser = try TreeSitterParser.init(allocator, .typescript);
    defer parser.deinit();

    var tree = try parser.parse("function foo() {}");
    defer tree.deinit();

    const root = tree.rootNode();

    // Root should not be null
    try testing.expect(!root.isNull());

    // Root should be named
    try testing.expect(root.isNamed());
}

// ============================================================================
// Edge Cases
// ============================================================================

test "Traversal: handles empty source" {
    const allocator = testing.allocator;

    var parser = try TreeSitterParser.init(allocator, .typescript);
    defer parser.deinit();

    var tree = try parser.parse("");
    defer tree.deinit();

    const root = tree.rootNode();

    // Empty source should still have a root node
    try testing.expect(!root.isNull());

    // Should have no functions
    const functions = try traversal_helpers.extractFunctions(allocator, root);
    defer allocator.free(functions);
    try testing.expectEqual(@as(usize, 0), functions.len);
}

test "Traversal: handles comments-only source" {
    const allocator = testing.allocator;

    const source =
        \\// Just a comment
        \\/* Another comment */
    ;

    var parser = try TreeSitterParser.init(allocator, .typescript);
    defer parser.deinit();

    var tree = try parser.parse(source);
    defer tree.deinit();

    const root = tree.rootNode();

    // Should parse successfully
    try testing.expect(!root.isNull());

    // Should have no functions or types
    const functions = try traversal_helpers.extractFunctions(allocator, root);
    defer allocator.free(functions);
    try testing.expectEqual(@as(usize, 0), functions.len);
}

test "Traversal: handles deeply nested structures" {
    const allocator = testing.allocator;

    // Valid TypeScript with nested classes and functions
    const source =
        \\class A {
        \\    innerClass = class B {
        \\        method() {
        \\            function nested() {
        \\                return 42;
        \\            }
        \\            return nested();
        \\        }
        \\    }
        \\}
    ;

    var parser = try TreeSitterParser.init(allocator, .typescript);
    defer parser.deinit();

    var tree = try parser.parse(source);
    defer tree.deinit();

    const root = tree.rootNode();

    // Should parse and traverse successfully
    const types = try traversal_helpers.extractTypes(allocator, root);
    defer allocator.free(types);

    // Should find at least the outer class (class A)
    try testing.expect(types.len >= 1);
}
