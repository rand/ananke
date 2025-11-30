const std = @import("std");

// Tree-sitter C API bindings for direct FFI
// This bypasses z-tree-sitter compatibility issues with Zig 0.15.x

// Import tree-sitter C headers
pub const c = @cImport({
    @cInclude("tree_sitter/api.h");
});

// Re-export commonly used C types for convenience
pub const TSParser = c.TSParser;
pub const TSTree = c.TSTree;
pub const TSNode = c.TSNode;
pub const TSLanguage = c.TSLanguage;
pub const TSPoint = c.TSPoint;
pub const TSRange = c.TSRange;
pub const TSInput = c.TSInput;
pub const TSInputEdit = c.TSInputEdit;
pub const TSQuery = c.TSQuery;
pub const TSQueryCursor = c.TSQueryCursor;
pub const TSQueryMatch = c.TSQueryMatch;
pub const TSQueryCapture = c.TSQueryCapture;
pub const TSQueryError = c.TSQueryError;

// Parser functions
pub const ts_parser_new = c.ts_parser_new;
pub const ts_parser_delete = c.ts_parser_delete;
pub const ts_parser_set_language = c.ts_parser_set_language;
pub const ts_parser_language = c.ts_parser_language;
pub const ts_parser_parse_string = c.ts_parser_parse_string;
pub const ts_parser_parse = c.ts_parser_parse;
pub const ts_parser_reset = c.ts_parser_reset;
pub const ts_parser_set_timeout_micros = c.ts_parser_set_timeout_micros;
pub const ts_parser_timeout_micros = c.ts_parser_timeout_micros;

// Tree functions
pub const ts_tree_delete = c.ts_tree_delete;
pub const ts_tree_root_node = c.ts_tree_root_node;
pub const ts_tree_language = c.ts_tree_language;
pub const ts_tree_edit = c.ts_tree_edit;
pub const ts_tree_get_changed_ranges = c.ts_tree_get_changed_ranges;

// Node functions
pub const ts_node_type = c.ts_node_type;
pub const ts_node_start_byte = c.ts_node_start_byte;
pub const ts_node_end_byte = c.ts_node_end_byte;
pub const ts_node_start_point = c.ts_node_start_point;
pub const ts_node_end_point = c.ts_node_end_point;
pub const ts_node_string = c.ts_node_string;
pub const ts_node_is_null = c.ts_node_is_null;
pub const ts_node_is_named = c.ts_node_is_named;
pub const ts_node_is_missing = c.ts_node_is_missing;
pub const ts_node_is_extra = c.ts_node_is_extra;
pub const ts_node_has_error = c.ts_node_has_error;
pub const ts_node_parent = c.ts_node_parent;
pub const ts_node_child = c.ts_node_child;
pub const ts_node_named_child = c.ts_node_named_child;
pub const ts_node_child_by_field_name = c.ts_node_child_by_field_name;
pub const ts_node_child_count = c.ts_node_child_count;
pub const ts_node_named_child_count = c.ts_node_named_child_count;
pub const ts_node_next_sibling = c.ts_node_next_sibling;
pub const ts_node_prev_sibling = c.ts_node_prev_sibling;
pub const ts_node_next_named_sibling = c.ts_node_next_named_sibling;
pub const ts_node_prev_named_sibling = c.ts_node_prev_named_sibling;
pub const ts_node_eq = c.ts_node_eq;

// Query functions
pub const ts_query_new = c.ts_query_new;
pub const ts_query_delete = c.ts_query_delete;
pub const ts_query_pattern_count = c.ts_query_pattern_count;
pub const ts_query_capture_count = c.ts_query_capture_count;
pub const ts_query_capture_name_for_id = c.ts_query_capture_name_for_id;
pub const ts_query_cursor_new = c.ts_query_cursor_new;
pub const ts_query_cursor_delete = c.ts_query_cursor_delete;
pub const ts_query_cursor_exec = c.ts_query_cursor_exec;
pub const ts_query_cursor_next_match = c.ts_query_cursor_next_match;
pub const ts_query_cursor_set_byte_range = c.ts_query_cursor_set_byte_range;
pub const ts_query_cursor_set_point_range = c.ts_query_cursor_set_point_range;

// Language functions (external declarations for language parsers)
// These are provided by the tree-sitter-{lang} libraries compiled in build.zig
pub extern "c" fn tree_sitter_typescript() ?*const TSLanguage;
pub extern "c" fn tree_sitter_tsx() ?*const TSLanguage;
pub extern "c" fn tree_sitter_javascript() ?*const TSLanguage;
pub extern "c" fn tree_sitter_python() ?*const TSLanguage;
pub extern "c" fn tree_sitter_rust() ?*const TSLanguage;
pub extern "c" fn tree_sitter_go() ?*const TSLanguage;
pub extern "c" fn tree_sitter_zig() ?*const TSLanguage;
pub extern "c" fn tree_sitter_c() ?*const TSLanguage;
pub extern "c" fn tree_sitter_cpp() ?*const TSLanguage;
pub extern "c" fn tree_sitter_java() ?*const TSLanguage;

// Helper to check if a pointer is null
pub fn isNull(ptr: anytype) bool {
    return ptr == null or ptr == @as(@TypeOf(ptr), @ptrFromInt(0));
}

// Error types for tree-sitter operations
pub const Error = error{
    ParserAllocationFailed,
    LanguageSetFailed,
    ParseFailed,
    InvalidLanguage,
    NullTree,
    NullNode,
    QueryCreationFailed,
    CursorCreationFailed,
    InvalidCaptureIndex,
    UnsupportedLanguage,
};

// Helper to check if a language parser is available
pub fn isLanguageAvailable(language: []const u8) bool {
    if (std.mem.eql(u8, language, "typescript")) {
        return tree_sitter_typescript() != null;
    } else if (std.mem.eql(u8, language, "tsx")) {
        return tree_sitter_tsx() != null;
    } else if (std.mem.eql(u8, language, "javascript")) {
        return tree_sitter_javascript() != null;
    } else if (std.mem.eql(u8, language, "python")) {
        return tree_sitter_python() != null;
    } else if (std.mem.eql(u8, language, "rust")) {
        return tree_sitter_rust() != null;
    } else if (std.mem.eql(u8, language, "go")) {
        return tree_sitter_go() != null;
    } else if (std.mem.eql(u8, language, "zig")) {
        return tree_sitter_zig() != null;
    } else if (std.mem.eql(u8, language, "c")) {
        return tree_sitter_c() != null;
    } else if (std.mem.eql(u8, language, "cpp")) {
        return tree_sitter_cpp() != null;
    } else if (std.mem.eql(u8, language, "java")) {
        return tree_sitter_java() != null;
    }
    return false;
}

// Helper to convert C string to Zig string (caller must free with c allocator)
pub fn cStringToZig(allocator: std.mem.Allocator, c_str: [*c]const u8) ![]const u8 {
    if (c_str == null) return error.NullCString;
    const len = std.mem.len(c_str);
    const result = try allocator.alloc(u8, len);
    @memcpy(result, c_str[0..len]);
    return result;
}

// Helper to free C-allocated strings
pub fn freeCString(c_str: [*c]u8) void {
    if (c_str != null) {
        c.free(@ptrCast(c_str));
    }
}
