const std = @import("std");
const c_api = @import("c_api.zig");
const parser = @import("parser.zig");
const Node = parser.Node;
const Tree = parser.Tree;
const Language = parser.Language;
const Allocator = std.mem.Allocator;

/// Query for pattern matching in AST
pub const Query = struct {
    query: *c_api.TSQuery,
    allocator: Allocator,
    pattern_count: u32,

    pub fn init(allocator: Allocator, language: Language, source: []const u8) !Query {
        const lang_ptr = try language.getParser();

        // Ensure source is null-terminated
        const c_source = try allocator.allocSentinel(u8, source.len, 0);
        defer allocator.free(c_source);
        @memcpy(c_source[0..source.len], source);

        var error_offset: u32 = 0;
        var error_type: c_api.TSQueryError = undefined;

        const query = c_api.ts_query_new(
            lang_ptr,
            c_source.ptr,
            @intCast(source.len),
            &error_offset,
            &error_type,
        ) orelse {
            return c_api.Error.QueryCreationFailed;
        };

        const pattern_count = c_api.ts_query_pattern_count(query);

        return Query{
            .query = query,
            .allocator = allocator,
            .pattern_count = pattern_count,
        };
    }

    pub fn deinit(self: *Query) void {
        c_api.ts_query_delete(self.query);
    }

    /// Execute query on a tree
    pub fn execute(self: *Query, tree: *Tree) !QueryCursor {
        const cursor = c_api.ts_query_cursor_new() orelse {
            return c_api.Error.CursorCreationFailed;
        };

        const root = tree.rootNode();
        c_api.ts_query_cursor_exec(cursor, self.query, root.node);

        return QueryCursor{
            .cursor = cursor,
            .allocator = self.allocator,
        };
    }

    /// Get number of patterns in query
    pub fn patternCount(self: Query) u32 {
        return self.pattern_count;
    }

    /// Get number of captures in query
    pub fn captureCount(self: Query) u32 {
        return c_api.ts_query_capture_count(self.query);
    }

    /// Get capture name by index
    pub fn captureName(self: Query, index: u32) ![]const u8 {
        var length: u32 = 0;
        const name_ptr = c_api.ts_query_capture_name_for_id(self.query, index, &length);
        if (c_api.isNull(name_ptr)) return c_api.Error.InvalidCaptureIndex;

        return name_ptr[0..length];
    }
};

/// Query cursor for iterating matches
pub const QueryCursor = struct {
    cursor: *c_api.TSQueryCursor,
    allocator: Allocator,

    pub fn deinit(self: *QueryCursor) void {
        c_api.ts_query_cursor_delete(self.cursor);
    }

    /// Get next match
    pub fn nextMatch(self: *QueryCursor) ?QueryMatch {
        var match: c_api.TSQueryMatch = undefined;
        if (!c_api.ts_query_cursor_next_match(self.cursor, &match)) {
            return null;
        }

        return QueryMatch{
            .match = match,
            .allocator = self.allocator,
        };
    }

    /// Set byte range for query execution
    pub fn setByteRange(self: *QueryCursor, start: u32, end: u32) void {
        c_api.ts_query_cursor_set_byte_range(self.cursor, start, end);
    }

    /// Set point range for query execution
    pub fn setPointRange(self: *QueryCursor, start: parser.Point, end: parser.Point) void {
        const start_point = c_api.TSPoint{
            .row = start.row,
            .column = start.column,
        };
        const end_point = c_api.TSPoint{
            .row = end.row,
            .column = end.column,
        };
        c_api.ts_query_cursor_set_point_range(self.cursor, start_point, end_point);
    }
};

/// A single query match
pub const QueryMatch = struct {
    match: c_api.TSQueryMatch,
    allocator: Allocator,

    /// Get pattern index for this match
    pub fn patternIndex(self: QueryMatch) u32 {
        return self.match.pattern_index;
    }

    /// Get number of captures in this match
    pub fn captureCount(self: QueryMatch) u32 {
        return @intCast(self.match.capture_count);
    }

    /// Get capture by index
    pub fn capture(self: QueryMatch, index: u32) ?QueryCapture {
        if (index >= self.captureCount()) return null;

        const caps_slice = self.match.captures[0..self.match.capture_count];
        const cap = caps_slice[index];

        return QueryCapture{
            .node = Node{
                .node = cap.node,
                .allocator = self.allocator,
            },
            .index = cap.index,
        };
    }

    /// Get all captures as a slice
    pub fn captures(self: QueryMatch) []const QueryCapture {
        const count = self.captureCount();
        const caps = self.allocator.alloc(QueryCapture, count) catch return &[_]QueryCapture{};

        var i: u32 = 0;
        while (i < count) : (i += 1) {
            if (self.capture(i)) |cap| {
                caps[i] = cap;
            }
        }

        return caps;
    }
};

/// A captured node from a query match
pub const QueryCapture = struct {
    node: Node,
    index: u32, // Capture index in the query
};

/// Common query patterns for constraint extraction
/// TypeScript/JavaScript function query
pub const TS_FUNCTION_QUERY =
    \\(function_declaration
    \\  name: (identifier) @name
    \\  parameters: (formal_parameters) @params
    \\  return_type: (type_annotation)? @return_type
    \\) @function
;

/// TypeScript interface query
pub const TS_INTERFACE_QUERY =
    \\(interface_declaration
    \\  name: (type_identifier) @name
    \\  body: (object_type) @body
    \\) @interface
;

/// Python function query
pub const PY_FUNCTION_QUERY =
    \\(function_definition
    \\  name: (identifier) @name
    \\  parameters: (parameters) @params
    \\  return_type: (type)? @return_type
    \\) @function
;

/// Python class query
pub const PY_CLASS_QUERY =
    \\(class_definition
    \\  name: (identifier) @name
    \\  superclasses: (argument_list)? @bases
    \\  body: (block) @body
    \\) @class
;

/// Rust function query
pub const RUST_FUNCTION_QUERY =
    \\(function_item
    \\  name: (identifier) @name
    \\  parameters: (parameters) @params
    \\  return_type: (type_identifier)? @return_type
    \\) @function
;

/// Rust struct query
pub const RUST_STRUCT_QUERY =
    \\(struct_item
    \\  name: (type_identifier) @name
    \\  body: (field_declaration_list)? @fields
    \\) @struct
;

/// Helper to build common queries
pub const QueryBuilder = struct {
    allocator: Allocator,

    pub fn init(allocator: Allocator) QueryBuilder {
        return QueryBuilder{ .allocator = allocator };
    }

    /// Build a query for function declarations
    pub fn functionQuery(self: QueryBuilder, language: Language) !Query {
        const query_str = switch (language) {
            .typescript, .javascript => TS_FUNCTION_QUERY,
            .python => PY_FUNCTION_QUERY,
            .rust => RUST_FUNCTION_QUERY,
            else => return c_api.Error.UnsupportedLanguage,
        };

        return try Query.init(self.allocator, language, query_str);
    }

    /// Build a query for type/interface declarations
    pub fn typeQuery(self: QueryBuilder, language: Language) !Query {
        const query_str = switch (language) {
            .typescript, .javascript => TS_INTERFACE_QUERY,
            .python => PY_CLASS_QUERY,
            .rust => RUST_STRUCT_QUERY,
            else => return c_api.Error.UnsupportedLanguage,
        };

        return try Query.init(self.allocator, language, query_str);
    }
};

/// Query result collector
pub const QueryResults = struct {
    matches: std.ArrayList(QueryMatch),
    allocator: Allocator,

    pub fn init(allocator: Allocator) QueryResults {
        return QueryResults{
            .matches = std.ArrayList(QueryMatch).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *QueryResults) void {
        self.matches.deinit();
    }

    /// Collect all matches from a cursor
    pub fn collectFrom(self: *QueryResults, cursor: *QueryCursor) !void {
        while (cursor.nextMatch()) |match| {
            try self.matches.append(match);
        }
    }

    /// Get all matches as slice
    pub fn items(self: QueryResults) []const QueryMatch {
        return self.matches.items;
    }

    /// Get number of matches
    pub fn count(self: QueryResults) usize {
        return self.matches.items.len;
    }
};
