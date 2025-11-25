const std = @import("std");
const testing = std.testing;
const parser = @import("clew").tree_sitter.parser;
const traversal = @import("clew").tree_sitter.traversal;
const Traversal = traversal.Traversal;

test "traversal: pre-order visit all nodes" {
    const allocator = testing.allocator;

    // Simple expression tree
    const source =
        \\const x = 42;
    ;

    var ts_parser = try parser.TreeSitterParser.init(allocator, .javascript);
    defer ts_parser.deinit();

    var tree = try ts_parser.parse(source);
    defer tree.deinit();

    const root = tree.rootNode();

    var visit_count: u32 = 0;

    const visitor = struct {
        fn visit(node: parser.Node, depth: u32, context: ?*anyopaque) !bool {
            _ = node;
            _ = depth;
            const count: *u32 = @ptrCast(@alignCast(context.?));
            count.* += 1;
            return true;
        }
    }.visit;

    const t = Traversal.init(allocator);
    try t.traverse(root, .pre_order, visitor, &visit_count);

    // Should have visited at least the root node
    try testing.expect(visit_count > 0);
}

test "traversal: post-order visit" {
    const allocator = testing.allocator;

    const source = "const x = 42;";

    var ts_parser = try parser.TreeSitterParser.init(allocator, .javascript);
    defer ts_parser.deinit();

    var tree = try ts_parser.parse(source);
    defer tree.deinit();

    const root = tree.rootNode();

    var visit_count: u32 = 0;

    const visitor = struct {
        fn visit(node: parser.Node, depth: u32, context: ?*anyopaque) !bool {
            _ = node;
            _ = depth;
            const count: *u32 = @ptrCast(@alignCast(context.?));
            count.* += 1;
            return true;
        }
    }.visit;

    const t = Traversal.init(allocator);
    try t.traverse(root, .post_order, visitor, &visit_count);

    try testing.expect(visit_count > 0);
}

test "traversal: level-order visit" {
    const allocator = testing.allocator;

    const source = "const x = 42;";

    var ts_parser = try parser.TreeSitterParser.init(allocator, .javascript);
    defer ts_parser.deinit();

    var tree = try ts_parser.parse(source);
    defer tree.deinit();

    const root = tree.rootNode();

    var visit_count: u32 = 0;

    const visitor = struct {
        fn visit(node: parser.Node, depth: u32, context: ?*anyopaque) !bool {
            _ = node;
            _ = depth;
            const count: *u32 = @ptrCast(@alignCast(context.?));
            count.* += 1;
            return true;
        }
    }.visit;

    const t = Traversal.init(allocator);
    try t.traverse(root, .level_order, visitor, &visit_count);

    try testing.expect(visit_count > 0);
}

test "traversal: stop traversal early" {
    const allocator = testing.allocator;

    const source = "const x = 42;";

    var ts_parser = try parser.TreeSitterParser.init(allocator, .javascript);
    defer ts_parser.deinit();

    var tree = try ts_parser.parse(source);
    defer tree.deinit();

    const root = tree.rootNode();

    var visit_count: u32 = 0;

    const visitor = struct {
        fn visit(node: parser.Node, depth: u32, context: ?*anyopaque) !bool {
            _ = node;
            _ = depth;
            const count: *u32 = @ptrCast(@alignCast(context.?));
            count.* += 1;
            // Stop after first visit
            return false;
        }
    }.visit;

    const t = Traversal.init(allocator);
    try t.traverse(root, .pre_order, visitor, &visit_count);

    // Should have visited exactly one node
    try testing.expectEqual(@as(u32, 1), visit_count);
}

test "traversal: findByType" {
    const allocator = testing.allocator;

    const source =
        \\function add(a, b) {
        \\  return a + b;
        \\}
    ;

    var ts_parser = try parser.TreeSitterParser.init(allocator, .javascript);
    defer ts_parser.deinit();

    var tree = try ts_parser.parse(source);
    defer tree.deinit();

    const root = tree.rootNode();

    const t = Traversal.init(allocator);

    // Find identifier nodes
    const identifiers = try t.findByType(root, "identifier");
    defer allocator.free(identifiers);

    // Should find at least the function name 'add' and parameters 'a', 'b'
    try testing.expect(identifiers.len >= 3);
}

test "traversal: getNodeText" {
    const allocator = testing.allocator;

    const source = "const x = 42;";

    var ts_parser = try parser.TreeSitterParser.init(allocator, .javascript);
    defer ts_parser.deinit();

    var tree = try ts_parser.parse(source);
    defer tree.deinit();

    const root = tree.rootNode();

    const t = Traversal.init(allocator);
    const text = t.getNodeText(root, source);

    // Root node should contain the entire source
    try testing.expectEqualStrings(source, text);
}

test "traversal: findFirst with predicate" {
    const allocator = testing.allocator;

    const source =
        \\function add(a, b) {
        \\  return a + b;
        \\}
    ;

    var ts_parser = try parser.TreeSitterParser.init(allocator, .javascript);
    defer ts_parser.deinit();

    var tree = try ts_parser.parse(source);
    defer tree.deinit();

    const root = tree.rootNode();

    const predicate = struct {
        fn match(node: parser.Node) bool {
            return std.mem.eql(u8, node.nodeType(), "identifier");
        }
    }.match;

    const t = Traversal.init(allocator);
    const first_id = try t.findFirst(root, predicate);

    try testing.expect(first_id != null);
}

test "traversal: findAll with predicate" {
    const allocator = testing.allocator;

    const source =
        \\function add(a, b) {
        \\  return a + b;
        \\}
    ;

    var ts_parser = try parser.TreeSitterParser.init(allocator, .javascript);
    defer ts_parser.deinit();

    var tree = try ts_parser.parse(source);
    defer tree.deinit();

    const root = tree.rootNode();

    const predicate = struct {
        fn match(node: parser.Node) bool {
            return std.mem.eql(u8, node.nodeType(), "identifier");
        }
    }.match;

    const t = Traversal.init(allocator);
    const all_ids = try t.findAll(root, predicate);
    defer allocator.free(all_ids);

    // Should find multiple identifiers
    try testing.expect(all_ids.len > 0);
}

test "traversal: extractFunctions helper" {
    const allocator = testing.allocator;

    const source =
        \\function add(a, b) {
        \\  return a + b;
        \\}
        \\function multiply(x, y) {
        \\  return x * y;
        \\}
    ;

    var ts_parser = try parser.TreeSitterParser.init(allocator, .javascript);
    defer ts_parser.deinit();

    var tree = try ts_parser.parse(source);
    defer tree.deinit();

    const root = tree.rootNode();

    const functions = try traversal.extractFunctions(allocator, root);
    defer allocator.free(functions);

    // Should find both functions
    try testing.expectEqual(@as(usize, 2), functions.len);
}

test "traversal: extractTypes helper TypeScript" {
    const allocator = testing.allocator;

    const source =
        \\interface User {
        \\  name: string;
        \\  age: number;
        \\}
        \\class Person {
        \\  constructor(public name: string) {}
        \\}
    ;

    var ts_parser = try parser.TreeSitterParser.init(allocator, .typescript);
    defer ts_parser.deinit();

    var tree = try ts_parser.parse(source);
    defer tree.deinit();

    const root = tree.rootNode();

    const types = try traversal.extractTypes(allocator, root);
    defer allocator.free(types);

    // Should find interface and class
    try testing.expect(types.len >= 1);
}

test "traversal: printTree" {
    const allocator = testing.allocator;

    const source = "const x = 42;";

    var ts_parser = try parser.TreeSitterParser.init(allocator, .javascript);
    defer ts_parser.deinit();

    var tree = try ts_parser.parse(source);
    defer tree.deinit();

    const root = tree.rootNode();

    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    const t = Traversal.init(allocator);
    try t.printTree(root, source, buffer.writer());

    const output = buffer.items;

    // Should contain at least the program node
    try testing.expect(output.len > 0);
    try testing.expect(std.mem.indexOf(u8, output, "program") != null);
}

test "traversal: depth tracking" {
    const allocator = testing.allocator;

    const source =
        \\function outer() {
        \\  function inner() {
        \\    return 42;
        \\  }
        \\}
    ;

    var ts_parser = try parser.TreeSitterParser.init(allocator, .javascript);
    defer ts_parser.deinit();

    var tree = try ts_parser.parse(source);
    defer tree.deinit();

    const root = tree.rootNode();

    var max_depth: u32 = 0;

    const visitor = struct {
        fn visit(node: parser.Node, depth: u32, context: ?*anyopaque) !bool {
            _ = node;
            const max_d: *u32 = @ptrCast(@alignCast(context.?));
            if (depth > max_d.*) {
                max_d.* = depth;
            }
            return true;
        }
    }.visit;

    const t = Traversal.init(allocator);
    try t.traverse(root, .pre_order, visitor, &max_depth);

    // Nested functions should have depth > 0
    try testing.expect(max_depth > 0);
}
