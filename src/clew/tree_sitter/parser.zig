const std = @import("std");
const c_api = @import("c_api.zig");
const Allocator = std.mem.Allocator;

// Supported languages
pub const Language = enum {
    typescript,
    javascript,
    python,
    rust,
    go,
    zig,
    c,
    cpp,
    java,

    pub fn getParser(self: Language) !*const c_api.TSLanguage {
        const maybe_parser = switch (self) {
            .typescript => c_api.tree_sitter_typescript(),
            .javascript => c_api.tree_sitter_javascript(),
            .python => c_api.tree_sitter_python(),
            .rust => c_api.tree_sitter_rust(),
            .go => c_api.tree_sitter_go(),
            .zig => c_api.tree_sitter_zig(),
            .c => c_api.tree_sitter_c(),
            .cpp => c_api.tree_sitter_cpp(),
            .java => c_api.tree_sitter_java(),
        };

        if (maybe_parser) |parser| {
            return parser;
        } else {
            return c_api.Error.InvalidLanguage;
        }
    }

    pub fn fromExtension(ext: []const u8) ?Language {
        if (std.mem.eql(u8, ext, ".ts")) return .typescript;
        if (std.mem.eql(u8, ext, ".tsx")) return .typescript;
        if (std.mem.eql(u8, ext, ".js")) return .javascript;
        if (std.mem.eql(u8, ext, ".jsx")) return .javascript;
        if (std.mem.eql(u8, ext, ".py")) return .python;
        if (std.mem.eql(u8, ext, ".rs")) return .rust;
        if (std.mem.eql(u8, ext, ".go")) return .go;
        if (std.mem.eql(u8, ext, ".zig")) return .zig;
        if (std.mem.eql(u8, ext, ".c")) return .c;
        if (std.mem.eql(u8, ext, ".h")) return .c;
        if (std.mem.eql(u8, ext, ".cpp")) return .cpp;
        if (std.mem.eql(u8, ext, ".cc")) return .cpp;
        if (std.mem.eql(u8, ext, ".hpp")) return .cpp;
        if (std.mem.eql(u8, ext, ".java")) return .java;
        return null;
    }
};

// Tree-sitter parser wrapper
pub const TreeSitterParser = struct {
    parser: *c_api.TSParser,
    allocator: Allocator,
    language: Language,

    pub fn init(allocator: Allocator, language: Language) !TreeSitterParser {
        const maybe_parser = c_api.ts_parser_new();
        const parser = maybe_parser orelse return c_api.Error.ParserAllocationFailed;
        errdefer c_api.ts_parser_delete(parser);

        const lang = try language.getParser();
        if (!c_api.ts_parser_set_language(parser, lang)) {
            return c_api.Error.LanguageSetFailed;
        }

        return TreeSitterParser{
            .parser = parser,
            .allocator = allocator,
            .language = language,
        };
    }

    pub fn deinit(self: *TreeSitterParser) void {
        c_api.ts_parser_delete(self.parser);
    }

    pub fn parse(self: *TreeSitterParser, source: []const u8) !*Tree {
        // Ensure source is null-terminated for C API
        const c_source = try self.allocator.allocSentinel(u8, source.len, 0);
        defer self.allocator.free(c_source);
        @memcpy(c_source[0..source.len], source);

        const maybe_tree = c_api.ts_parser_parse_string(
            self.parser,
            null, // old_tree
            c_source.ptr,
            @intCast(source.len),
        );

        const tree = maybe_tree orelse return c_api.Error.ParseFailed;

        const result = try self.allocator.create(Tree);
        result.* = Tree{
            .tree = tree,
            .allocator = self.allocator,
        };
        return result;
    }

    pub fn setTimeout(self: *TreeSitterParser, timeout_micros: u64) void {
        c_api.ts_parser_set_timeout_micros(self.parser, timeout_micros);
    }

    pub fn getTimeout(self: *TreeSitterParser) u64 {
        return c_api.ts_parser_timeout_micros(self.parser);
    }

    pub fn reset(self: *TreeSitterParser) void {
        c_api.ts_parser_reset(self.parser);
    }
};

// Tree wrapper
pub const Tree = struct {
    tree: *c_api.TSTree,
    allocator: Allocator,

    pub fn deinit(self: *Tree) void {
        c_api.ts_tree_delete(self.tree);
        self.allocator.destroy(self);
    }

    pub fn rootNode(self: *Tree) Node {
        const node = c_api.ts_tree_root_node(self.tree);
        return Node{
            .node = node,
            .allocator = self.allocator,
        };
    }
};

// Node wrapper
pub const Node = struct {
    node: c_api.TSNode,
    allocator: Allocator,

    pub fn nodeType(self: Node) []const u8 {
        const type_str = c_api.ts_node_type(self.node);
        if (c_api.isNull(type_str)) return "";
        return std.mem.span(type_str);
    }

    pub fn startByte(self: Node) u32 {
        return c_api.ts_node_start_byte(self.node);
    }

    pub fn endByte(self: Node) u32 {
        return c_api.ts_node_end_byte(self.node);
    }

    pub fn startPoint(self: Node) Point {
        const point = c_api.ts_node_start_point(self.node);
        return Point{
            .row = point.row,
            .column = point.column,
        };
    }

    pub fn endPoint(self: Node) Point {
        const point = c_api.ts_node_end_point(self.node);
        return Point{
            .row = point.row,
            .column = point.column,
        };
    }

    pub fn isNull(self: Node) bool {
        return c_api.ts_node_is_null(self.node);
    }

    pub fn isNamed(self: Node) bool {
        return c_api.ts_node_is_named(self.node);
    }

    pub fn isMissing(self: Node) bool {
        return c_api.ts_node_is_missing(self.node);
    }

    pub fn isExtra(self: Node) bool {
        return c_api.ts_node_is_extra(self.node);
    }

    pub fn hasError(self: Node) bool {
        return c_api.ts_node_has_error(self.node);
    }

    pub fn childCount(self: Node) u32 {
        return c_api.ts_node_child_count(self.node);
    }

    pub fn namedChildCount(self: Node) u32 {
        return c_api.ts_node_named_child_count(self.node);
    }

    pub fn child(self: Node, index: u32) ?Node {
        const child_node = c_api.ts_node_child(self.node, index);
        if (c_api.ts_node_is_null(child_node)) return null;
        return Node{
            .node = child_node,
            .allocator = self.allocator,
        };
    }

    pub fn namedChild(self: Node, index: u32) ?Node {
        const child_node = c_api.ts_node_named_child(self.node, index);
        if (c_api.ts_node_is_null(child_node)) return null;
        return Node{
            .node = child_node,
            .allocator = self.allocator,
        };
    }

    pub fn parent(self: Node) ?Node {
        const parent_node = c_api.ts_node_parent(self.node);
        if (c_api.ts_node_is_null(parent_node)) return null;
        return Node{
            .node = parent_node,
            .allocator = self.allocator,
        };
    }

    pub fn nextSibling(self: Node) ?Node {
        const sibling = c_api.ts_node_next_sibling(self.node);
        if (c_api.ts_node_is_null(sibling)) return null;
        return Node{
            .node = sibling,
            .allocator = self.allocator,
        };
    }

    pub fn prevSibling(self: Node) ?Node {
        const sibling = c_api.ts_node_prev_sibling(self.node);
        if (c_api.ts_node_is_null(sibling)) return null;
        return Node{
            .node = sibling,
            .allocator = self.allocator,
        };
    }

    pub fn nextNamedSibling(self: Node) ?Node {
        const sibling = c_api.ts_node_next_named_sibling(self.node);
        if (c_api.ts_node_is_null(sibling)) return null;
        return Node{
            .node = sibling,
            .allocator = self.allocator,
        };
    }

    pub fn prevNamedSibling(self: Node) ?Node {
        const sibling = c_api.ts_node_prev_named_sibling(self.node);
        if (c_api.ts_node_is_null(sibling)) return null;
        return Node{
            .node = sibling,
            .allocator = self.allocator,
        };
    }

    pub fn toString(self: Node) ![]const u8 {
        const c_str = c_api.ts_node_string(self.node);
        if (c_api.isNull(c_str)) return c_api.Error.NullNode;
        defer c_api.freeCString(@constCast(c_str));
        return try c_api.cStringToZig(self.allocator, c_str);
    }

    pub fn equals(self: Node, other: Node) bool {
        return c_api.ts_node_eq(self.node, other.node);
    }
};

// Point represents a position in source code
pub const Point = struct {
    row: u32,
    column: u32,

    pub fn format(self: Point, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.print("{}:{}", .{ self.row + 1, self.column + 1 });
    }
};

// Range in source code
pub const Range = struct {
    start_byte: u32,
    end_byte: u32,
    start_point: Point,
    end_point: Point,
};