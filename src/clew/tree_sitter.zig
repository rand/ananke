// Tree-sitter module - AST parsing and traversal
// Provides direct C FFI to libtree-sitter with idiomatic Zig wrappers

pub const c_api = @import("tree_sitter/c_api.zig");
pub const parser = @import("tree_sitter/parser.zig");
pub const traversal = @import("tree_sitter/traversal.zig");
pub const query = @import("tree_sitter/query.zig");

// Re-export commonly used types for convenience
pub const TreeSitterParser = parser.TreeSitterParser;
pub const Tree = parser.Tree;
pub const Node = parser.Node;
pub const Language = parser.Language;
pub const Point = parser.Point;
pub const Range = parser.Range;

pub const Traversal = traversal.Traversal;
pub const TraversalOrder = traversal.TraversalOrder;
pub const VisitorFn = traversal.VisitorFn;

pub const Query = query.Query;
pub const QueryCursor = query.QueryCursor;
pub const QueryMatch = query.QueryMatch;
pub const QueryCapture = query.QueryCapture;
pub const QueryBuilder = query.QueryBuilder;
pub const QueryResults = query.QueryResults;
