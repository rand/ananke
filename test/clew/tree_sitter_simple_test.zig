const std = @import("std");
const testing = std.testing;

// Direct C API import for testing
const c = @cImport({
    @cInclude("tree_sitter/api.h");
});

test "tree-sitter basic C FFI" {
    // Test basic tree-sitter functionality
    const parser = c.ts_parser_new();
    if (parser == null) {
        std.debug.print("\nERROR: Failed to create parser - libtree-sitter not found\n", .{});
        return error.TreeSitterNotAvailable;
    }
    defer c.ts_parser_delete(parser);

    std.debug.print("\nSUCCESS: Created tree-sitter parser via C FFI\n", .{});

    // Test parsing without language (should work but produce minimal tree)
    const source = "test code";
    const tree = c.ts_parser_parse_string(
        parser,
        null,
        source.ptr,
        @intCast(source.len),
    );

    if (tree != null) {
        defer c.ts_tree_delete(tree);
        std.debug.print("SUCCESS: Parsed string (without language parser)\n", .{});

        const root = c.ts_tree_root_node(tree);
        const child_count = c.ts_node_child_count(root);
        std.debug.print("Root node child count: {}\n", .{child_count});

        // Without a language, we expect 0 children (just ERROR node)
        try testing.expectEqual(@as(u32, 0), child_count);
    } else {
        std.debug.print("WARNING: Parse returned null (expected without language)\n", .{});
    }
}

test "tree-sitter memory management" {
    // Test creating and destroying multiple parsers
    var i: usize = 0;
    while (i < 5) : (i += 1) {
        const parser = c.ts_parser_new() orelse return error.TreeSitterNotAvailable;
        defer c.ts_parser_delete(parser);

        // Set a timeout to ensure parser is configured
        c.ts_parser_set_timeout_micros(parser, 1000);
        const timeout = c.ts_parser_timeout_micros(parser);
        try testing.expectEqual(@as(u64, 1000), timeout);
    }

    std.debug.print("\nMemory management test passed\n", .{});
}