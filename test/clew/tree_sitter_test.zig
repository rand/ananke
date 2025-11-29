const std = @import("std");
const testing = std.testing;
const parser = @import("tree_sitter");
const TreeSitterParser = parser.TreeSitterParser;
const Language = parser.Language;

test "create and destroy parser" {
    const allocator = testing.allocator;

    // Note: This test will fail if tree-sitter-typescript is not installed
    // Install with: brew install tree-sitter-typescript (on macOS)
    var ts_parser = TreeSitterParser.init(allocator, .typescript) catch |err| {
        std.debug.print("\nWarning: tree-sitter-typescript not available: {}\n", .{err});
        std.debug.print("Install with: brew install tree-sitter-typescript\n", .{});
        return;
    };
    defer ts_parser.deinit();

    // Parser should be initialized (parser is a non-null pointer by construction)
    try testing.expectEqual(Language.typescript, ts_parser.language);
}

test "parse simple TypeScript code" {
    const allocator = testing.allocator;

    var ts_parser = TreeSitterParser.init(allocator, .typescript) catch |err| {
        std.debug.print("\nWarning: tree-sitter-typescript not available: {}\n", .{err});
        return;
    };
    defer ts_parser.deinit();

    const source = "function add(a, b) { return a + b; }";

    const tree = try ts_parser.parse(source);
    defer tree.deinit();

    const root = tree.rootNode();

    // Root node should not be null
    try testing.expect(!root.isNull());

    // Root node should have children
    const child_count = root.childCount();
    try testing.expect(child_count > 0);

    // Get the function node
    if (root.child(0)) |function_node| {
        const node_type = function_node.nodeType();
        std.debug.print("\nFirst child node type: {s}\n", .{node_type});

        // Should be a function declaration
        try testing.expect(std.mem.indexOf(u8, node_type, "function") != null or
            std.mem.eql(u8, node_type, "function_declaration"));

        // Check position information
        const start_byte = function_node.startByte();
        const end_byte = function_node.endByte();
        try testing.expect(start_byte == 0);
        try testing.expect(end_byte == source.len);

        const start_point = function_node.startPoint();
        try testing.expectEqual(@as(u32, 0), start_point.row);
        try testing.expectEqual(@as(u32, 0), start_point.column);
    }
}

test "parse Python code" {
    const allocator = testing.allocator;

    var py_parser = TreeSitterParser.init(allocator, .python) catch |err| {
        std.debug.print("\nWarning: tree-sitter-python not available: {}\n", .{err});
        std.debug.print("Install with: brew install tree-sitter-python\n", .{});
        return;
    };
    defer py_parser.deinit();

    const source = "def hello(name):\n    print(f'Hello, {name}!')";

    const tree = try py_parser.parse(source);
    defer tree.deinit();

    const root = tree.rootNode();
    try testing.expect(!root.isNull());
    try testing.expect(root.childCount() > 0);
}

test "traverse AST tree" {
    const allocator = testing.allocator;

    var ts_parser = TreeSitterParser.init(allocator, .typescript) catch |err| {
        std.debug.print("\nWarning: tree-sitter-typescript not available: {}\n", .{err});
        return;
    };
    defer ts_parser.deinit();

    const source =
        \\const x = 10;
        \\const y = 20;
        \\function add() { return x + y; }
    ;

    const tree = try ts_parser.parse(source);
    defer tree.deinit();

    const root = tree.rootNode();
    const child_count = root.childCount();

    // Should have 3 statements
    try testing.expect(child_count >= 3);

    // Traverse children
    var i: u32 = 0;
    while (i < child_count) : (i += 1) {
        if (root.child(i)) |child| {
            const node_type = child.nodeType();
            std.debug.print("\nChild {}: type={s}, named={}\n", .{ i, node_type, child.isNamed() });

            // Check for errors
            try testing.expect(!child.hasError());
        }
    }
}

test "language detection from extension" {
    try testing.expectEqual(Language.typescript, Language.fromExtension(".ts").?);
    try testing.expectEqual(Language.typescript, Language.fromExtension(".tsx").?);
    try testing.expectEqual(Language.javascript, Language.fromExtension(".js").?);
    try testing.expectEqual(Language.python, Language.fromExtension(".py").?);
    try testing.expectEqual(Language.rust, Language.fromExtension(".rs").?);
    try testing.expectEqual(Language.go, Language.fromExtension(".go").?);
    try testing.expectEqual(Language.zig, Language.fromExtension(".zig").?);
    try testing.expectEqual(@as(?Language, null), Language.fromExtension(".unknown"));
}

test "parse with errors" {
    const allocator = testing.allocator;

    var ts_parser = TreeSitterParser.init(allocator, .typescript) catch |err| {
        std.debug.print("\nWarning: tree-sitter-typescript not available: {}\n", .{err});
        return;
    };
    defer ts_parser.deinit();

    // Invalid TypeScript code
    const source = "function add(a, b { return a + b; }"; // Missing closing parenthesis

    const tree = try ts_parser.parse(source);
    defer tree.deinit();

    const root = tree.rootNode();

    // Even invalid code should produce a tree
    try testing.expect(!root.isNull());

    // The tree should indicate errors
    try testing.expect(root.hasError());
}

test "parser timeout" {
    const allocator = testing.allocator;

    var ts_parser = TreeSitterParser.init(allocator, .typescript) catch |err| {
        std.debug.print("\nWarning: tree-sitter-typescript not available: {}\n", .{err});
        return;
    };
    defer ts_parser.deinit();

    // Set timeout to 1000 microseconds (1ms)
    ts_parser.setTimeout(1000);
    const timeout = ts_parser.getTimeout();
    try testing.expectEqual(@as(u64, 1000), timeout);

    // Parse normally (should complete within timeout)
    const source = "const x = 1;";
    const tree = try ts_parser.parse(source);
    defer tree.deinit();

    const root = tree.rootNode();
    try testing.expect(!root.isNull());
}

test "memory leak check" {
    const allocator = testing.allocator;

    // Create and destroy multiple parsers and trees
    var i: usize = 0;
    while (i < 10) : (i += 1) {
        var ts_parser = TreeSitterParser.init(allocator, .typescript) catch |err| {
            std.debug.print("\nWarning: tree-sitter-typescript not available: {}\n", .{err});
            return;
        };
        defer ts_parser.deinit();

        const source = "const x = 42;";
        const tree = try ts_parser.parse(source);
        defer tree.deinit();

        const root = tree.rootNode();
        try testing.expect(!root.isNull());
    }

    // If we get here without memory errors, we're properly managing memory
}
