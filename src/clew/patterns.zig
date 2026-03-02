// Pattern-based constraint extraction for multiple languages
// Provides comprehensive regex patterns for TypeScript, Python, Rust, and Zig
const std = @import("std");

const root = @import("ananke");
const ConstraintKind = root.types.constraint.ConstraintKind;

/// A single pattern rule for matching code constructs
pub const PatternRule = struct {
    pattern: []const u8, // Pattern to match (will use std.mem operations)
    constraint_kind: ConstraintKind,
    description: []const u8,
    capture_groups: u8 = 0, // Number of capture groups (for future regex support)
};

/// Category of patterns
pub const PatternCategory = enum {
    function_decl,
    type_annotation,
    async_pattern,
    error_handling,
    imports,
    class_struct,
    metadata,
    memory_management,
};

/// Collection of pattern rules for a language
pub const LanguagePatterns = struct {
    function_decl: []const PatternRule,
    type_annotation: []const PatternRule,
    async_pattern: []const PatternRule,
    error_handling: []const PatternRule,
    imports: []const PatternRule,
    class_struct: []const PatternRule,
    metadata: []const PatternRule,
    memory_management: []const PatternRule,
};

// ============================================================================
// TypeScript Patterns
// ============================================================================

const ts_function_patterns = [_]PatternRule{
    .{
        .pattern = "async function",
        .constraint_kind = .semantic,
        .description = "Async function declaration",
    },
    .{
        .pattern = "function",
        .constraint_kind = .syntactic,
        .description = "Function declaration",
    },
    .{
        .pattern = "=>",
        .constraint_kind = .syntactic,
        .description = "Arrow function",
    },
};

const ts_type_patterns = [_]PatternRule{
    .{
        .pattern = ": string",
        .constraint_kind = .type_safety,
        .description = "String type annotation",
    },
    .{
        .pattern = ": number",
        .constraint_kind = .type_safety,
        .description = "Number type annotation",
    },
    .{
        .pattern = ": boolean",
        .constraint_kind = .type_safety,
        .description = "Boolean type annotation",
    },
    .{
        .pattern = ": void",
        .constraint_kind = .type_safety,
        .description = "Void type annotation",
    },
    .{
        .pattern = "interface",
        .constraint_kind = .type_safety,
        .description = "Interface definition",
    },
    .{
        .pattern = "type ",
        .constraint_kind = .type_safety,
        .description = "Type alias",
    },
};

const ts_async_patterns = [_]PatternRule{
    .{
        .pattern = "async",
        .constraint_kind = .semantic,
        .description = "Async keyword",
    },
    .{
        .pattern = "await",
        .constraint_kind = .semantic,
        .description = "Await keyword",
    },
    .{
        .pattern = "Promise<",
        .constraint_kind = .semantic,
        .description = "Promise type",
    },
};

const ts_error_patterns = [_]PatternRule{
    .{
        .pattern = "try {",
        .constraint_kind = .semantic,
        .description = "Try block",
    },
    .{
        .pattern = "catch",
        .constraint_kind = .semantic,
        .description = "Catch block",
    },
    .{
        .pattern = "throw",
        .constraint_kind = .semantic,
        .description = "Throw statement",
    },
};

const ts_import_patterns = [_]PatternRule{
    .{
        .pattern = "import {",
        .constraint_kind = .architectural,
        .description = "Named import",
    },
    .{
        .pattern = "import * as",
        .constraint_kind = .architectural,
        .description = "Namespace import",
    },
    .{
        .pattern = "import ",
        .constraint_kind = .architectural,
        .description = "Import statement",
    },
    .{
        .pattern = "export",
        .constraint_kind = .architectural,
        .description = "Export statement",
    },
};

const ts_class_patterns = [_]PatternRule{
    .{
        .pattern = "class ",
        .constraint_kind = .syntactic,
        .description = "Class declaration",
    },
    .{
        .pattern = "extends",
        .constraint_kind = .syntactic,
        .description = "Class inheritance",
    },
    .{
        .pattern = "implements",
        .constraint_kind = .type_safety,
        .description = "Interface implementation",
    },
};

const ts_metadata_patterns = [_]PatternRule{
    .{
        .pattern = "@",
        .constraint_kind = .syntactic,
        .description = "Decorator",
    },
};

const ts_memory_patterns = [_]PatternRule{};

pub const typescript_patterns = LanguagePatterns{
    .function_decl = &ts_function_patterns,
    .type_annotation = &ts_type_patterns,
    .async_pattern = &ts_async_patterns,
    .error_handling = &ts_error_patterns,
    .imports = &ts_import_patterns,
    .class_struct = &ts_class_patterns,
    .metadata = &ts_metadata_patterns,
    .memory_management = &ts_memory_patterns,
};

// ============================================================================
// Python Patterns
// ============================================================================

const py_function_patterns = [_]PatternRule{
    .{
        .pattern = "async def",
        .constraint_kind = .semantic,
        .description = "Async function definition",
    },
    .{
        .pattern = "def ",
        .constraint_kind = .syntactic,
        .description = "Function definition",
    },
    .{
        .pattern = "lambda",
        .constraint_kind = .syntactic,
        .description = "Lambda function",
    },
};

const py_type_patterns = [_]PatternRule{
    .{
        .pattern = "-> ",
        .constraint_kind = .type_safety,
        .description = "Return type annotation",
    },
    .{
        .pattern = ": int",
        .constraint_kind = .type_safety,
        .description = "Int type hint",
    },
    .{
        .pattern = ": str",
        .constraint_kind = .type_safety,
        .description = "String type hint",
    },
    .{
        .pattern = ": bool",
        .constraint_kind = .type_safety,
        .description = "Boolean type hint",
    },
    .{
        .pattern = ": List[",
        .constraint_kind = .type_safety,
        .description = "List type hint",
    },
    .{
        .pattern = ": Dict[",
        .constraint_kind = .type_safety,
        .description = "Dict type hint",
    },
    .{
        .pattern = ": Optional[",
        .constraint_kind = .type_safety,
        .description = "Optional type hint",
    },
};

const py_async_patterns = [_]PatternRule{
    .{
        .pattern = "async def",
        .constraint_kind = .semantic,
        .description = "Async function",
    },
    .{
        .pattern = "await ",
        .constraint_kind = .semantic,
        .description = "Await expression",
    },
    .{
        .pattern = "asyncio",
        .constraint_kind = .semantic,
        .description = "Asyncio library usage",
    },
};

const py_error_patterns = [_]PatternRule{
    .{
        .pattern = "try:",
        .constraint_kind = .semantic,
        .description = "Try block",
    },
    .{
        .pattern = "except",
        .constraint_kind = .semantic,
        .description = "Exception handler",
    },
    .{
        .pattern = "raise",
        .constraint_kind = .semantic,
        .description = "Raise exception",
    },
    .{
        .pattern = "finally:",
        .constraint_kind = .semantic,
        .description = "Finally block",
    },
};

const py_import_patterns = [_]PatternRule{
    .{
        .pattern = "import ",
        .constraint_kind = .architectural,
        .description = "Import statement",
    },
    .{
        .pattern = "from ",
        .constraint_kind = .architectural,
        .description = "From import",
    },
};

const py_class_patterns = [_]PatternRule{
    .{
        .pattern = "class ",
        .constraint_kind = .syntactic,
        .description = "Class definition",
    },
    .{
        .pattern = "@dataclass",
        .constraint_kind = .syntactic,
        .description = "Dataclass decorator",
    },
};

const py_metadata_patterns = [_]PatternRule{
    .{
        .pattern = "@",
        .constraint_kind = .syntactic,
        .description = "Decorator",
    },
};

const py_memory_patterns = [_]PatternRule{};

pub const python_patterns = LanguagePatterns{
    .function_decl = &py_function_patterns,
    .type_annotation = &py_type_patterns,
    .async_pattern = &py_async_patterns,
    .error_handling = &py_error_patterns,
    .imports = &py_import_patterns,
    .class_struct = &py_class_patterns,
    .metadata = &py_metadata_patterns,
    .memory_management = &py_memory_patterns,
};

// ============================================================================
// Rust Patterns
// ============================================================================

const rust_function_patterns = [_]PatternRule{
    .{
        .pattern = "async fn",
        .constraint_kind = .semantic,
        .description = "Async function",
    },
    .{
        .pattern = "pub fn",
        .constraint_kind = .syntactic,
        .description = "Public function",
    },
    .{
        .pattern = "fn ",
        .constraint_kind = .syntactic,
        .description = "Function definition",
    },
};

const rust_type_patterns = [_]PatternRule{
    .{
        .pattern = "Result<",
        .constraint_kind = .type_safety,
        .description = "Result type",
    },
    .{
        .pattern = "Option<",
        .constraint_kind = .type_safety,
        .description = "Option type",
    },
    .{
        .pattern = "impl ",
        .constraint_kind = .type_safety,
        .description = "Trait implementation",
    },
    .{
        .pattern = "trait ",
        .constraint_kind = .type_safety,
        .description = "Trait definition",
    },
    .{
        .pattern = "&str",
        .constraint_kind = .type_safety,
        .description = "String slice reference",
    },
    .{
        .pattern = "&mut",
        .constraint_kind = .type_safety,
        .description = "Mutable reference",
    },
    .{
        .pattern = "&",
        .constraint_kind = .type_safety,
        .description = "Reference",
    },
};

const rust_async_patterns = [_]PatternRule{
    .{
        .pattern = "async",
        .constraint_kind = .semantic,
        .description = "Async keyword",
    },
    .{
        .pattern = ".await",
        .constraint_kind = .semantic,
        .description = "Await expression",
    },
};

const rust_error_patterns = [_]PatternRule{
    .{
        .pattern = "Result<",
        .constraint_kind = .semantic,
        .description = "Result type for error handling",
    },
    .{
        .pattern = "?",
        .constraint_kind = .semantic,
        .description = "Error propagation operator",
    },
    .{
        .pattern = "unwrap()",
        .constraint_kind = .semantic,
        .description = "Unwrap (potential panic)",
    },
    .{
        .pattern = "expect(",
        .constraint_kind = .semantic,
        .description = "Expect with message",
    },
};

const rust_import_patterns = [_]PatternRule{
    .{
        .pattern = "use ",
        .constraint_kind = .architectural,
        .description = "Use statement",
    },
    .{
        .pattern = "mod ",
        .constraint_kind = .architectural,
        .description = "Module declaration",
    },
};

const rust_class_patterns = [_]PatternRule{
    .{
        .pattern = "struct ",
        .constraint_kind = .syntactic,
        .description = "Struct definition",
    },
    .{
        .pattern = "enum ",
        .constraint_kind = .syntactic,
        .description = "Enum definition",
    },
};

const rust_metadata_patterns = [_]PatternRule{
    .{
        .pattern = "#[derive(",
        .constraint_kind = .syntactic,
        .description = "Derive macro",
    },
    .{
        .pattern = "#[",
        .constraint_kind = .syntactic,
        .description = "Attribute",
    },
};

const rust_memory_patterns = [_]PatternRule{
    .{
        .pattern = "Box<",
        .constraint_kind = .operational,
        .description = "Heap allocation",
    },
    .{
        .pattern = "Rc<",
        .constraint_kind = .operational,
        .description = "Reference counting",
    },
    .{
        .pattern = "Arc<",
        .constraint_kind = .operational,
        .description = "Atomic reference counting",
    },
    .{
        .pattern = "'static",
        .constraint_kind = .type_safety,
        .description = "Static lifetime",
    },
    .{
        .pattern = "'_",
        .constraint_kind = .type_safety,
        .description = "Elided lifetime",
    },
};

pub const rust_patterns = LanguagePatterns{
    .function_decl = &rust_function_patterns,
    .type_annotation = &rust_type_patterns,
    .async_pattern = &rust_async_patterns,
    .error_handling = &rust_error_patterns,
    .imports = &rust_import_patterns,
    .class_struct = &rust_class_patterns,
    .metadata = &rust_metadata_patterns,
    .memory_management = &rust_memory_patterns,
};

// ============================================================================
// Go Patterns
// ============================================================================

const go_function_patterns = [_]PatternRule{
    .{
        .pattern = "func (",
        .constraint_kind = .syntactic,
        .description = "Method with receiver",
    },
    .{
        .pattern = "func ",
        .constraint_kind = .syntactic,
        .description = "Function definition",
    },
};

const go_type_patterns = [_]PatternRule{
    .{
        .pattern = "error",
        .constraint_kind = .type_safety,
        .description = "Error type",
    },
    .{
        .pattern = "interface{",
        .constraint_kind = .type_safety,
        .description = "Interface definition",
    },
    .{
        .pattern = "type ",
        .constraint_kind = .type_safety,
        .description = "Type definition",
    },
    .{
        .pattern = "*",
        .constraint_kind = .type_safety,
        .description = "Pointer type",
    },
    .{
        .pattern = "[]",
        .constraint_kind = .type_safety,
        .description = "Slice type",
    },
    .{
        .pattern = "map[",
        .constraint_kind = .type_safety,
        .description = "Map type",
    },
};

const go_async_patterns = [_]PatternRule{
    .{
        .pattern = "go ",
        .constraint_kind = .semantic,
        .description = "Goroutine launch",
    },
    .{
        .pattern = "chan ",
        .constraint_kind = .semantic,
        .description = "Channel type",
    },
    .{
        .pattern = "<-",
        .constraint_kind = .semantic,
        .description = "Channel operation",
    },
    .{
        .pattern = "select {",
        .constraint_kind = .semantic,
        .description = "Select statement",
    },
};

const go_error_patterns = [_]PatternRule{
    .{
        .pattern = "if err != nil",
        .constraint_kind = .semantic,
        .description = "Error check",
    },
    .{
        .pattern = "error",
        .constraint_kind = .semantic,
        .description = "Error type usage",
    },
    .{
        .pattern = "panic(",
        .constraint_kind = .semantic,
        .description = "Panic call",
    },
    .{
        .pattern = "recover()",
        .constraint_kind = .semantic,
        .description = "Recover call",
    },
};

const go_import_patterns = [_]PatternRule{
    .{
        .pattern = "import (",
        .constraint_kind = .architectural,
        .description = "Multi-line import",
    },
    .{
        .pattern = "import \"",
        .constraint_kind = .architectural,
        .description = "Single import",
    },
    .{
        .pattern = "package ",
        .constraint_kind = .architectural,
        .description = "Package declaration",
    },
};

const go_class_patterns = [_]PatternRule{
    .{
        .pattern = "type ",
        .constraint_kind = .syntactic,
        .description = "Type declaration",
    },
    .{
        .pattern = "struct {",
        .constraint_kind = .syntactic,
        .description = "Struct definition",
    },
    .{
        .pattern = "interface {",
        .constraint_kind = .syntactic,
        .description = "Interface definition",
    },
};

const go_metadata_patterns = [_]PatternRule{
    .{
        .pattern = "`json:",
        .constraint_kind = .syntactic,
        .description = "JSON struct tag",
    },
    .{
        .pattern = "`",
        .constraint_kind = .syntactic,
        .description = "Struct tag",
    },
    .{
        .pattern = "//go:",
        .constraint_kind = .syntactic,
        .description = "Compiler directive",
    },
};

const go_memory_patterns = [_]PatternRule{
    .{
        .pattern = "make(",
        .constraint_kind = .operational,
        .description = "Make allocation",
    },
    .{
        .pattern = "new(",
        .constraint_kind = .operational,
        .description = "New allocation",
    },
    .{
        .pattern = "defer ",
        .constraint_kind = .operational,
        .description = "Defer statement",
    },
    .{
        .pattern = "&",
        .constraint_kind = .operational,
        .description = "Address-of operator",
    },
    .{
        .pattern = "context.Context",
        .constraint_kind = .operational,
        .description = "Context usage",
    },
};

pub const go_patterns = LanguagePatterns{
    .function_decl = &go_function_patterns,
    .type_annotation = &go_type_patterns,
    .async_pattern = &go_async_patterns,
    .error_handling = &go_error_patterns,
    .imports = &go_import_patterns,
    .class_struct = &go_class_patterns,
    .metadata = &go_metadata_patterns,
    .memory_management = &go_memory_patterns,
};

// ============================================================================
// Zig Patterns
// ============================================================================

const zig_function_patterns = [_]PatternRule{
    .{
        .pattern = "pub fn",
        .constraint_kind = .syntactic,
        .description = "Public function",
    },
    .{
        .pattern = "fn ",
        .constraint_kind = .syntactic,
        .description = "Function definition",
    },
};

const zig_type_patterns = [_]PatternRule{
    .{
        .pattern = "!void",
        .constraint_kind = .type_safety,
        .description = "Error union returning void",
    },
    .{
        .pattern = "!",
        .constraint_kind = .type_safety,
        .description = "Error union type",
    },
    .{
        .pattern = "?",
        .constraint_kind = .type_safety,
        .description = "Optional type",
    },
    .{
        .pattern = "[]const u8",
        .constraint_kind = .type_safety,
        .description = "Const byte slice",
    },
    .{
        .pattern = "[]u8",
        .constraint_kind = .type_safety,
        .description = "Mutable byte slice",
    },
};

const zig_async_patterns = [_]PatternRule{
    .{
        .pattern = "async",
        .constraint_kind = .semantic,
        .description = "Async function",
    },
    .{
        .pattern = "await",
        .constraint_kind = .semantic,
        .description = "Await expression",
    },
    .{
        .pattern = "suspend",
        .constraint_kind = .semantic,
        .description = "Suspend point",
    },
    .{
        .pattern = "resume",
        .constraint_kind = .semantic,
        .description = "Resume coroutine",
    },
};

const zig_error_patterns = [_]PatternRule{
    .{
        .pattern = "error{",
        .constraint_kind = .semantic,
        .description = "error set definition",
    },
    .{
        .pattern = "Error!",
        .constraint_kind = .semantic,
        .description = "error union type",
    },
    .{
        .pattern = "try ",
        .constraint_kind = .semantic,
        .description = "try expression",
    },
    .{
        .pattern = "catch",
        .constraint_kind = .semantic,
        .description = "catch expression",
    },
    .{
        .pattern = "error.",
        .constraint_kind = .semantic,
        .description = "error value",
    },
    .{
        .pattern = "errdefer",
        .constraint_kind = .semantic,
        .description = "errdefer statement",
    },
};

const zig_import_patterns = [_]PatternRule{
    .{
        .pattern = "@import(",
        .constraint_kind = .architectural,
        .description = "Import builtin",
    },
};

const zig_class_patterns = [_]PatternRule{
    .{
        .pattern = "const struct",
        .constraint_kind = .syntactic,
        .description = "Const struct definition",
    },
    .{
        .pattern = "struct {",
        .constraint_kind = .syntactic,
        .description = "Struct definition",
    },
    .{
        .pattern = "enum {",
        .constraint_kind = .syntactic,
        .description = "Enum definition",
    },
    .{
        .pattern = "union {",
        .constraint_kind = .syntactic,
        .description = "Union definition",
    },
};

const zig_metadata_patterns = [_]PatternRule{
    .{
        .pattern = "comptime",
        .constraint_kind = .operational,
        .description = "Compile-time execution",
    },
    .{
        .pattern = "pub const",
        .constraint_kind = .syntactic,
        .description = "Public constant",
    },
};

const zig_memory_patterns = [_]PatternRule{
    .{
        .pattern = "Allocator",
        .constraint_kind = .operational,
        .description = "Allocator type",
    },
    .{
        .pattern = ".alloc(",
        .constraint_kind = .operational,
        .description = "Allocation call",
    },
    .{
        .pattern = ".free(",
        .constraint_kind = .operational,
        .description = "Free call",
    },
    .{
        .pattern = "defer ",
        .constraint_kind = .operational,
        .description = "Defer statement",
    },
    .{
        .pattern = "deinit()",
        .constraint_kind = .operational,
        .description = "Deinitialization",
    },
};

pub const zig_patterns = LanguagePatterns{
    .function_decl = &zig_function_patterns,
    .type_annotation = &zig_type_patterns,
    .async_pattern = &zig_async_patterns,
    .error_handling = &zig_error_patterns,
    .imports = &zig_import_patterns,
    .class_struct = &zig_class_patterns,
    .metadata = &zig_metadata_patterns,
    .memory_management = &zig_memory_patterns,
};

// ============================================================================
// JavaScript Patterns
// ============================================================================

const js_function_patterns = [_]PatternRule{
    .{
        .pattern = "async function",
        .constraint_kind = .semantic,
        .description = "Async function declaration",
    },
    .{
        .pattern = "function*",
        .constraint_kind = .syntactic,
        .description = "Generator function",
    },
    .{
        .pattern = "function",
        .constraint_kind = .syntactic,
        .description = "Function declaration",
    },
    .{
        .pattern = "=>",
        .constraint_kind = .syntactic,
        .description = "Arrow function",
    },
};

const js_type_patterns = [_]PatternRule{
    .{
        .pattern = "typeof",
        .constraint_kind = .type_safety,
        .description = "Type check",
    },
    .{
        .pattern = "instanceof",
        .constraint_kind = .type_safety,
        .description = "Instance check",
    },
};

const js_async_patterns = [_]PatternRule{
    .{
        .pattern = "async",
        .constraint_kind = .semantic,
        .description = "Async keyword",
    },
    .{
        .pattern = "await",
        .constraint_kind = .semantic,
        .description = "Await keyword",
    },
    .{
        .pattern = "Promise",
        .constraint_kind = .semantic,
        .description = "Promise type",
    },
    .{
        .pattern = ".then(",
        .constraint_kind = .semantic,
        .description = "Promise chain",
    },
};

const js_error_patterns = [_]PatternRule{
    .{
        .pattern = "try {",
        .constraint_kind = .semantic,
        .description = "Try block",
    },
    .{
        .pattern = "catch",
        .constraint_kind = .semantic,
        .description = "Catch block",
    },
    .{
        .pattern = "throw",
        .constraint_kind = .semantic,
        .description = "Throw statement",
    },
    .{
        .pattern = "finally",
        .constraint_kind = .semantic,
        .description = "Finally block",
    },
};

const js_import_patterns = [_]PatternRule{
    .{
        .pattern = "import {",
        .constraint_kind = .architectural,
        .description = "Named import",
    },
    .{
        .pattern = "import * as",
        .constraint_kind = .architectural,
        .description = "Namespace import",
    },
    .{
        .pattern = "import ",
        .constraint_kind = .architectural,
        .description = "Import statement",
    },
    .{
        .pattern = "export",
        .constraint_kind = .architectural,
        .description = "Export statement",
    },
    .{
        .pattern = "require(",
        .constraint_kind = .architectural,
        .description = "CommonJS require",
    },
    .{
        .pattern = "module.exports",
        .constraint_kind = .architectural,
        .description = "CommonJS export",
    },
};

const js_class_patterns = [_]PatternRule{
    .{
        .pattern = "class ",
        .constraint_kind = .syntactic,
        .description = "Class declaration",
    },
    .{
        .pattern = "extends",
        .constraint_kind = .syntactic,
        .description = "Class inheritance",
    },
    .{
        .pattern = "constructor(",
        .constraint_kind = .syntactic,
        .description = "Constructor method",
    },
};

const js_metadata_patterns = [_]PatternRule{
    .{
        .pattern = "\"use strict\"",
        .constraint_kind = .syntactic,
        .description = "Strict mode",
    },
};

const js_memory_patterns = [_]PatternRule{};

pub const javascript_patterns = LanguagePatterns{
    .function_decl = &js_function_patterns,
    .type_annotation = &js_type_patterns,
    .async_pattern = &js_async_patterns,
    .error_handling = &js_error_patterns,
    .imports = &js_import_patterns,
    .class_struct = &js_class_patterns,
    .metadata = &js_metadata_patterns,
    .memory_management = &js_memory_patterns,
};

// ============================================================================
// C Patterns
// ============================================================================

const c_function_patterns = [_]PatternRule{
    .{
        .pattern = "static ",
        .constraint_kind = .syntactic,
        .description = "Static function/variable",
    },
    .{
        .pattern = "extern ",
        .constraint_kind = .syntactic,
        .description = "External declaration",
    },
    .{
        .pattern = "inline ",
        .constraint_kind = .syntactic,
        .description = "Inline function",
    },
};

const c_type_patterns = [_]PatternRule{
    .{
        .pattern = "const ",
        .constraint_kind = .type_safety,
        .description = "Const qualifier",
    },
    .{
        .pattern = "volatile ",
        .constraint_kind = .type_safety,
        .description = "Volatile qualifier",
    },
    .{
        .pattern = "unsigned ",
        .constraint_kind = .type_safety,
        .description = "Unsigned type",
    },
    .{
        .pattern = "size_t",
        .constraint_kind = .type_safety,
        .description = "Size type",
    },
    .{
        .pattern = "void*",
        .constraint_kind = .type_safety,
        .description = "Void pointer",
    },
};

const c_async_patterns = [_]PatternRule{};

const c_error_patterns = [_]PatternRule{
    .{
        .pattern = "errno",
        .constraint_kind = .semantic,
        .description = "Error number",
    },
    .{
        .pattern = "perror(",
        .constraint_kind = .semantic,
        .description = "Print error",
    },
    .{
        .pattern = "assert(",
        .constraint_kind = .semantic,
        .description = "Assertion",
    },
    .{
        .pattern = "abort(",
        .constraint_kind = .semantic,
        .description = "Abort call",
    },
    .{
        .pattern = "exit(",
        .constraint_kind = .semantic,
        .description = "Exit call",
    },
};

const c_import_patterns = [_]PatternRule{
    .{
        .pattern = "#include <",
        .constraint_kind = .architectural,
        .description = "System include",
    },
    .{
        .pattern = "#include \"",
        .constraint_kind = .architectural,
        .description = "Local include",
    },
};

const c_class_patterns = [_]PatternRule{
    .{
        .pattern = "struct ",
        .constraint_kind = .syntactic,
        .description = "Struct definition",
    },
    .{
        .pattern = "enum ",
        .constraint_kind = .syntactic,
        .description = "Enum definition",
    },
    .{
        .pattern = "union ",
        .constraint_kind = .syntactic,
        .description = "Union definition",
    },
    .{
        .pattern = "typedef ",
        .constraint_kind = .syntactic,
        .description = "Type definition",
    },
};

const c_metadata_patterns = [_]PatternRule{
    .{
        .pattern = "#define ",
        .constraint_kind = .syntactic,
        .description = "Macro definition",
    },
    .{
        .pattern = "#ifdef",
        .constraint_kind = .syntactic,
        .description = "Conditional compilation",
    },
    .{
        .pattern = "#ifndef",
        .constraint_kind = .syntactic,
        .description = "Conditional compilation",
    },
    .{
        .pattern = "#pragma",
        .constraint_kind = .syntactic,
        .description = "Pragma directive",
    },
};

const c_memory_patterns = [_]PatternRule{
    .{
        .pattern = "malloc(",
        .constraint_kind = .operational,
        .description = "Memory allocation",
    },
    .{
        .pattern = "calloc(",
        .constraint_kind = .operational,
        .description = "Cleared allocation",
    },
    .{
        .pattern = "realloc(",
        .constraint_kind = .operational,
        .description = "Reallocation",
    },
    .{
        .pattern = "free(",
        .constraint_kind = .operational,
        .description = "Memory free",
    },
    .{
        .pattern = "memcpy(",
        .constraint_kind = .operational,
        .description = "Memory copy",
    },
    .{
        .pattern = "memset(",
        .constraint_kind = .operational,
        .description = "Memory set",
    },
};

pub const c_patterns = LanguagePatterns{
    .function_decl = &c_function_patterns,
    .type_annotation = &c_type_patterns,
    .async_pattern = &c_async_patterns,
    .error_handling = &c_error_patterns,
    .imports = &c_import_patterns,
    .class_struct = &c_class_patterns,
    .metadata = &c_metadata_patterns,
    .memory_management = &c_memory_patterns,
};

// ============================================================================
// C++ Patterns
// ============================================================================

const cpp_function_patterns = [_]PatternRule{
    .{
        .pattern = "virtual ",
        .constraint_kind = .syntactic,
        .description = "Virtual function",
    },
    .{
        .pattern = "override",
        .constraint_kind = .syntactic,
        .description = "Override specifier",
    },
    .{
        .pattern = "constexpr ",
        .constraint_kind = .syntactic,
        .description = "Constexpr function",
    },
    .{
        .pattern = "noexcept",
        .constraint_kind = .syntactic,
        .description = "Noexcept specifier",
    },
    .{
        .pattern = "template<",
        .constraint_kind = .syntactic,
        .description = "Template declaration",
    },
};

const cpp_type_patterns = [_]PatternRule{
    .{
        .pattern = "const ",
        .constraint_kind = .type_safety,
        .description = "Const qualifier",
    },
    .{
        .pattern = "auto ",
        .constraint_kind = .type_safety,
        .description = "Auto type deduction",
    },
    .{
        .pattern = "decltype(",
        .constraint_kind = .type_safety,
        .description = "Decltype specifier",
    },
    .{
        .pattern = "nullptr",
        .constraint_kind = .type_safety,
        .description = "Null pointer",
    },
    .{
        .pattern = "static_cast<",
        .constraint_kind = .type_safety,
        .description = "Static cast",
    },
    .{
        .pattern = "dynamic_cast<",
        .constraint_kind = .type_safety,
        .description = "Dynamic cast",
    },
    .{
        .pattern = "reinterpret_cast<",
        .constraint_kind = .type_safety,
        .description = "Reinterpret cast",
    },
};

const cpp_async_patterns = [_]PatternRule{
    .{
        .pattern = "std::async(",
        .constraint_kind = .semantic,
        .description = "Async call",
    },
    .{
        .pattern = "std::future<",
        .constraint_kind = .semantic,
        .description = "Future type",
    },
    .{
        .pattern = "std::promise<",
        .constraint_kind = .semantic,
        .description = "Promise type",
    },
    .{
        .pattern = "std::thread",
        .constraint_kind = .semantic,
        .description = "Thread type",
    },
    .{
        .pattern = "std::mutex",
        .constraint_kind = .semantic,
        .description = "Mutex type",
    },
};

const cpp_error_patterns = [_]PatternRule{
    .{
        .pattern = "try {",
        .constraint_kind = .semantic,
        .description = "Try block",
    },
    .{
        .pattern = "catch (",
        .constraint_kind = .semantic,
        .description = "Catch block",
    },
    .{
        .pattern = "throw ",
        .constraint_kind = .semantic,
        .description = "Throw statement",
    },
    .{
        .pattern = "std::exception",
        .constraint_kind = .semantic,
        .description = "Standard exception",
    },
    .{
        .pattern = "std::runtime_error",
        .constraint_kind = .semantic,
        .description = "Runtime error",
    },
    .{
        .pattern = "std::logic_error",
        .constraint_kind = .semantic,
        .description = "Logic error",
    },
};

const cpp_import_patterns = [_]PatternRule{
    .{
        .pattern = "#include <",
        .constraint_kind = .architectural,
        .description = "System include",
    },
    .{
        .pattern = "#include \"",
        .constraint_kind = .architectural,
        .description = "Local include",
    },
    .{
        .pattern = "using namespace",
        .constraint_kind = .architectural,
        .description = "Using namespace",
    },
    .{
        .pattern = "using ",
        .constraint_kind = .architectural,
        .description = "Using declaration",
    },
    .{
        .pattern = "namespace ",
        .constraint_kind = .architectural,
        .description = "Namespace definition",
    },
};

const cpp_class_patterns = [_]PatternRule{
    .{
        .pattern = "class ",
        .constraint_kind = .syntactic,
        .description = "Class definition",
    },
    .{
        .pattern = "struct ",
        .constraint_kind = .syntactic,
        .description = "Struct definition",
    },
    .{
        .pattern = "enum class",
        .constraint_kind = .syntactic,
        .description = "Scoped enum",
    },
    .{
        .pattern = "public:",
        .constraint_kind = .syntactic,
        .description = "Public access",
    },
    .{
        .pattern = "private:",
        .constraint_kind = .syntactic,
        .description = "Private access",
    },
    .{
        .pattern = "protected:",
        .constraint_kind = .syntactic,
        .description = "Protected access",
    },
};

const cpp_metadata_patterns = [_]PatternRule{
    .{
        .pattern = "[[",
        .constraint_kind = .syntactic,
        .description = "Attribute",
    },
    .{
        .pattern = "#define ",
        .constraint_kind = .syntactic,
        .description = "Macro definition",
    },
};

const cpp_memory_patterns = [_]PatternRule{
    .{
        .pattern = "std::unique_ptr<",
        .constraint_kind = .operational,
        .description = "Unique pointer",
    },
    .{
        .pattern = "std::shared_ptr<",
        .constraint_kind = .operational,
        .description = "Shared pointer",
    },
    .{
        .pattern = "std::weak_ptr<",
        .constraint_kind = .operational,
        .description = "Weak pointer",
    },
    .{
        .pattern = "std::make_unique<",
        .constraint_kind = .operational,
        .description = "Make unique",
    },
    .{
        .pattern = "std::make_shared<",
        .constraint_kind = .operational,
        .description = "Make shared",
    },
    .{
        .pattern = "new ",
        .constraint_kind = .operational,
        .description = "New allocation",
    },
    .{
        .pattern = "delete ",
        .constraint_kind = .operational,
        .description = "Delete deallocation",
    },
    .{
        .pattern = "std::move(",
        .constraint_kind = .operational,
        .description = "Move semantics",
    },
};

pub const cpp_patterns = LanguagePatterns{
    .function_decl = &cpp_function_patterns,
    .type_annotation = &cpp_type_patterns,
    .async_pattern = &cpp_async_patterns,
    .error_handling = &cpp_error_patterns,
    .imports = &cpp_import_patterns,
    .class_struct = &cpp_class_patterns,
    .metadata = &cpp_metadata_patterns,
    .memory_management = &cpp_memory_patterns,
};

// ============================================================================
// Java Patterns
// ============================================================================

const java_function_patterns = [_]PatternRule{
    .{
        .pattern = "public ",
        .constraint_kind = .syntactic,
        .description = "Public access",
    },
    .{
        .pattern = "private ",
        .constraint_kind = .syntactic,
        .description = "Private access",
    },
    .{
        .pattern = "protected ",
        .constraint_kind = .syntactic,
        .description = "Protected access",
    },
    .{
        .pattern = "static ",
        .constraint_kind = .syntactic,
        .description = "Static member",
    },
    .{
        .pattern = "synchronized ",
        .constraint_kind = .semantic,
        .description = "Synchronized method",
    },
    .{
        .pattern = "abstract ",
        .constraint_kind = .syntactic,
        .description = "Abstract method",
    },
    .{
        .pattern = "final ",
        .constraint_kind = .syntactic,
        .description = "Final method/class",
    },
};

const java_type_patterns = [_]PatternRule{
    .{
        .pattern = "Optional<",
        .constraint_kind = .type_safety,
        .description = "Optional type",
    },
    .{
        .pattern = "List<",
        .constraint_kind = .type_safety,
        .description = "List type",
    },
    .{
        .pattern = "Map<",
        .constraint_kind = .type_safety,
        .description = "Map type",
    },
    .{
        .pattern = "Set<",
        .constraint_kind = .type_safety,
        .description = "Set type",
    },
    .{
        .pattern = "@NonNull",
        .constraint_kind = .type_safety,
        .description = "NonNull annotation",
    },
    .{
        .pattern = "@Nullable",
        .constraint_kind = .type_safety,
        .description = "Nullable annotation",
    },
};

const java_async_patterns = [_]PatternRule{
    .{
        .pattern = "CompletableFuture<",
        .constraint_kind = .semantic,
        .description = "CompletableFuture type",
    },
    .{
        .pattern = "Future<",
        .constraint_kind = .semantic,
        .description = "Future type",
    },
    .{
        .pattern = "ExecutorService",
        .constraint_kind = .semantic,
        .description = "Executor service",
    },
    .{
        .pattern = "Runnable",
        .constraint_kind = .semantic,
        .description = "Runnable interface",
    },
    .{
        .pattern = "Callable<",
        .constraint_kind = .semantic,
        .description = "Callable interface",
    },
    .{
        .pattern = "synchronized",
        .constraint_kind = .semantic,
        .description = "Synchronized block",
    },
};

const java_error_patterns = [_]PatternRule{
    .{
        .pattern = "try {",
        .constraint_kind = .semantic,
        .description = "Try block",
    },
    .{
        .pattern = "catch (",
        .constraint_kind = .semantic,
        .description = "Catch block",
    },
    .{
        .pattern = "finally {",
        .constraint_kind = .semantic,
        .description = "Finally block",
    },
    .{
        .pattern = "throws ",
        .constraint_kind = .semantic,
        .description = "Throws declaration",
    },
    .{
        .pattern = "throw new",
        .constraint_kind = .semantic,
        .description = "Throw statement",
    },
    .{
        .pattern = "Exception",
        .constraint_kind = .semantic,
        .description = "Exception type",
    },
};

const java_import_patterns = [_]PatternRule{
    .{
        .pattern = "import ",
        .constraint_kind = .architectural,
        .description = "Import statement",
    },
    .{
        .pattern = "import static",
        .constraint_kind = .architectural,
        .description = "Static import",
    },
    .{
        .pattern = "package ",
        .constraint_kind = .architectural,
        .description = "Package declaration",
    },
};

const java_class_patterns = [_]PatternRule{
    .{
        .pattern = "class ",
        .constraint_kind = .syntactic,
        .description = "Class definition",
    },
    .{
        .pattern = "interface ",
        .constraint_kind = .syntactic,
        .description = "Interface definition",
    },
    .{
        .pattern = "enum ",
        .constraint_kind = .syntactic,
        .description = "Enum definition",
    },
    .{
        .pattern = "extends ",
        .constraint_kind = .syntactic,
        .description = "Class inheritance",
    },
    .{
        .pattern = "implements ",
        .constraint_kind = .syntactic,
        .description = "Interface implementation",
    },
    .{
        .pattern = "record ",
        .constraint_kind = .syntactic,
        .description = "Record definition",
    },
};

const java_metadata_patterns = [_]PatternRule{
    .{
        .pattern = "@Override",
        .constraint_kind = .syntactic,
        .description = "Override annotation",
    },
    .{
        .pattern = "@Deprecated",
        .constraint_kind = .syntactic,
        .description = "Deprecated annotation",
    },
    .{
        .pattern = "@SuppressWarnings",
        .constraint_kind = .syntactic,
        .description = "Suppress warnings",
    },
    .{
        .pattern = "@",
        .constraint_kind = .syntactic,
        .description = "Annotation",
    },
};

const java_memory_patterns = [_]PatternRule{
    .{
        .pattern = "new ",
        .constraint_kind = .operational,
        .description = "Object allocation",
    },
    .{
        .pattern = "AutoCloseable",
        .constraint_kind = .operational,
        .description = "AutoCloseable resource",
    },
    .{
        .pattern = "try (",
        .constraint_kind = .operational,
        .description = "Try-with-resources",
    },
    .{
        .pattern = ".close()",
        .constraint_kind = .operational,
        .description = "Resource close",
    },
};

pub const java_patterns = LanguagePatterns{
    .function_decl = &java_function_patterns,
    .type_annotation = &java_type_patterns,
    .async_pattern = &java_async_patterns,
    .error_handling = &java_error_patterns,
    .imports = &java_import_patterns,
    .class_struct = &java_class_patterns,
    .metadata = &java_metadata_patterns,
    .memory_management = &java_memory_patterns,
};

// ============================================================================
// Kotlin Patterns
// ============================================================================

const kotlin_function_patterns = [_]PatternRule{
    .{
        .pattern = "suspend fun",
        .constraint_kind = .semantic,
        .description = "Suspend function",
    },
    .{
        .pattern = "fun ",
        .constraint_kind = .syntactic,
        .description = "Function definition",
    },
};

const kotlin_type_patterns = [_]PatternRule{
    .{
        .pattern = "?",
        .constraint_kind = .type_safety,
        .description = "Nullable type",
    },
    .{
        .pattern = "<",
        .constraint_kind = .type_safety,
        .description = "Generic type",
    },
    .{
        .pattern = "sealed class",
        .constraint_kind = .type_safety,
        .description = "Sealed class",
    },
    .{
        .pattern = "data class",
        .constraint_kind = .type_safety,
        .description = "Data class",
    },
};

const kotlin_async_patterns = [_]PatternRule{
    .{
        .pattern = "suspend ",
        .constraint_kind = .semantic,
        .description = "Suspend modifier",
    },
    .{
        .pattern = "launch",
        .constraint_kind = .semantic,
        .description = "Coroutine launch",
    },
    .{
        .pattern = "async",
        .constraint_kind = .semantic,
        .description = "Async builder",
    },
    .{
        .pattern = "Flow<",
        .constraint_kind = .semantic,
        .description = "Flow type",
    },
    .{
        .pattern = "Deferred<",
        .constraint_kind = .semantic,
        .description = "Deferred type",
    },
};

const kotlin_error_patterns = [_]PatternRule{
    .{
        .pattern = "try {",
        .constraint_kind = .semantic,
        .description = "Try block",
    },
    .{
        .pattern = "catch (",
        .constraint_kind = .semantic,
        .description = "Catch block",
    },
    .{
        .pattern = "finally {",
        .constraint_kind = .semantic,
        .description = "Finally block",
    },
    .{
        .pattern = "runCatching",
        .constraint_kind = .semantic,
        .description = "RunCatching call",
    },
};

const kotlin_import_patterns = [_]PatternRule{
    .{
        .pattern = "import ",
        .constraint_kind = .architectural,
        .description = "Import statement",
    },
    .{
        .pattern = "package ",
        .constraint_kind = .architectural,
        .description = "Package declaration",
    },
};

const kotlin_class_patterns = [_]PatternRule{
    .{
        .pattern = "class ",
        .constraint_kind = .syntactic,
        .description = "Class definition",
    },
    .{
        .pattern = "data class",
        .constraint_kind = .syntactic,
        .description = "Data class definition",
    },
    .{
        .pattern = "sealed class",
        .constraint_kind = .syntactic,
        .description = "Sealed class definition",
    },
    .{
        .pattern = "object ",
        .constraint_kind = .syntactic,
        .description = "Object declaration",
    },
    .{
        .pattern = "interface ",
        .constraint_kind = .syntactic,
        .description = "Interface definition",
    },
    .{
        .pattern = "enum class",
        .constraint_kind = .syntactic,
        .description = "Enum class definition",
    },
};

const kotlin_metadata_patterns = [_]PatternRule{
    .{
        .pattern = "@",
        .constraint_kind = .syntactic,
        .description = "Annotation",
    },
    .{
        .pattern = "annotation class",
        .constraint_kind = .syntactic,
        .description = "Annotation class",
    },
};

const kotlin_memory_patterns = [_]PatternRule{};

pub const kotlin_patterns = LanguagePatterns{
    .function_decl = &kotlin_function_patterns,
    .type_annotation = &kotlin_type_patterns,
    .async_pattern = &kotlin_async_patterns,
    .error_handling = &kotlin_error_patterns,
    .imports = &kotlin_import_patterns,
    .class_struct = &kotlin_class_patterns,
    .metadata = &kotlin_metadata_patterns,
    .memory_management = &kotlin_memory_patterns,
};

// ============================================================================
// C# Patterns
// ============================================================================

const csharp_function_patterns = [_]PatternRule{
    .{
        .pattern = "async ",
        .constraint_kind = .semantic,
        .description = "Async method",
    },
    .{
        .pattern = "static ",
        .constraint_kind = .syntactic,
        .description = "Static member",
    },
    .{
        .pattern = "virtual ",
        .constraint_kind = .syntactic,
        .description = "Virtual method",
    },
    .{
        .pattern = "override ",
        .constraint_kind = .syntactic,
        .description = "Override method",
    },
};

const csharp_type_patterns = [_]PatternRule{
    .{
        .pattern = "?",
        .constraint_kind = .type_safety,
        .description = "Nullable type",
    },
    .{
        .pattern = "<",
        .constraint_kind = .type_safety,
        .description = "Generic type",
    },
    .{
        .pattern = "Task<",
        .constraint_kind = .type_safety,
        .description = "Task generic type",
    },
};

const csharp_async_patterns = [_]PatternRule{
    .{
        .pattern = "async ",
        .constraint_kind = .semantic,
        .description = "Async keyword",
    },
    .{
        .pattern = "await ",
        .constraint_kind = .semantic,
        .description = "Await keyword",
    },
    .{
        .pattern = "Task<",
        .constraint_kind = .semantic,
        .description = "Task type",
    },
    .{
        .pattern = "ValueTask",
        .constraint_kind = .semantic,
        .description = "ValueTask type",
    },
};

const csharp_error_patterns = [_]PatternRule{
    .{
        .pattern = "try {",
        .constraint_kind = .semantic,
        .description = "Try block",
    },
    .{
        .pattern = "catch (",
        .constraint_kind = .semantic,
        .description = "Catch block",
    },
    .{
        .pattern = "finally {",
        .constraint_kind = .semantic,
        .description = "Finally block",
    },
    .{
        .pattern = "throw ",
        .constraint_kind = .semantic,
        .description = "Throw statement",
    },
};

const csharp_import_patterns = [_]PatternRule{
    .{
        .pattern = "using ",
        .constraint_kind = .architectural,
        .description = "Using directive",
    },
    .{
        .pattern = "namespace ",
        .constraint_kind = .architectural,
        .description = "Namespace declaration",
    },
};

const csharp_class_patterns = [_]PatternRule{
    .{
        .pattern = "class ",
        .constraint_kind = .syntactic,
        .description = "Class definition",
    },
    .{
        .pattern = "struct ",
        .constraint_kind = .syntactic,
        .description = "Struct definition",
    },
    .{
        .pattern = "interface ",
        .constraint_kind = .syntactic,
        .description = "Interface definition",
    },
    .{
        .pattern = "enum ",
        .constraint_kind = .syntactic,
        .description = "Enum definition",
    },
    .{
        .pattern = "record ",
        .constraint_kind = .syntactic,
        .description = "Record definition",
    },
};

const csharp_metadata_patterns = [_]PatternRule{
    .{
        .pattern = "[",
        .constraint_kind = .syntactic,
        .description = "Attribute",
    },
};

const csharp_memory_patterns = [_]PatternRule{
    .{
        .pattern = "using(",
        .constraint_kind = .operational,
        .description = "Using statement",
    },
    .{
        .pattern = "Dispose()",
        .constraint_kind = .operational,
        .description = "Dispose call",
    },
    .{
        .pattern = "IDisposable",
        .constraint_kind = .operational,
        .description = "IDisposable interface",
    },
};

pub const csharp_patterns = LanguagePatterns{
    .function_decl = &csharp_function_patterns,
    .type_annotation = &csharp_type_patterns,
    .async_pattern = &csharp_async_patterns,
    .error_handling = &csharp_error_patterns,
    .imports = &csharp_import_patterns,
    .class_struct = &csharp_class_patterns,
    .metadata = &csharp_metadata_patterns,
    .memory_management = &csharp_memory_patterns,
};

// ============================================================================
// Ruby Patterns
// ============================================================================

const ruby_function_patterns = [_]PatternRule{
    .{
        .pattern = "def self.",
        .constraint_kind = .syntactic,
        .description = "Class method definition",
    },
    .{
        .pattern = "def ",
        .constraint_kind = .syntactic,
        .description = "Method definition",
    },
};

const ruby_type_patterns = [_]PatternRule{};

const ruby_async_patterns = [_]PatternRule{
    .{
        .pattern = "Fiber",
        .constraint_kind = .semantic,
        .description = "Fiber usage",
    },
    .{
        .pattern = "Thread.new",
        .constraint_kind = .semantic,
        .description = "Thread creation",
    },
};

const ruby_error_patterns = [_]PatternRule{
    .{
        .pattern = "begin",
        .constraint_kind = .semantic,
        .description = "Begin block",
    },
    .{
        .pattern = "rescue ",
        .constraint_kind = .semantic,
        .description = "Rescue block",
    },
    .{
        .pattern = "ensure",
        .constraint_kind = .semantic,
        .description = "Ensure block",
    },
    .{
        .pattern = "raise ",
        .constraint_kind = .semantic,
        .description = "Raise exception",
    },
};

const ruby_import_patterns = [_]PatternRule{
    .{
        .pattern = "require ",
        .constraint_kind = .architectural,
        .description = "Require statement",
    },
    .{
        .pattern = "require_relative ",
        .constraint_kind = .architectural,
        .description = "Require relative",
    },
    .{
        .pattern = "include ",
        .constraint_kind = .architectural,
        .description = "Module include",
    },
    .{
        .pattern = "extend ",
        .constraint_kind = .architectural,
        .description = "Module extend",
    },
};

const ruby_class_patterns = [_]PatternRule{
    .{
        .pattern = "class ",
        .constraint_kind = .syntactic,
        .description = "Class definition",
    },
    .{
        .pattern = "module ",
        .constraint_kind = .syntactic,
        .description = "Module definition",
    },
    .{
        .pattern = "Struct.new",
        .constraint_kind = .syntactic,
        .description = "Struct creation",
    },
};

const ruby_metadata_patterns = [_]PatternRule{};

const ruby_memory_patterns = [_]PatternRule{
    .{
        .pattern = "GC.start",
        .constraint_kind = .operational,
        .description = "GC trigger",
    },
};

pub const ruby_patterns = LanguagePatterns{
    .function_decl = &ruby_function_patterns,
    .type_annotation = &ruby_type_patterns,
    .async_pattern = &ruby_async_patterns,
    .error_handling = &ruby_error_patterns,
    .imports = &ruby_import_patterns,
    .class_struct = &ruby_class_patterns,
    .metadata = &ruby_metadata_patterns,
    .memory_management = &ruby_memory_patterns,
};

// ============================================================================
// PHP Patterns
// ============================================================================

const php_function_patterns = [_]PatternRule{
    .{
        .pattern = "function ",
        .constraint_kind = .syntactic,
        .description = "Function definition",
    },
    .{
        .pattern = "fn ",
        .constraint_kind = .syntactic,
        .description = "Arrow function",
    },
};

const php_type_patterns = [_]PatternRule{
    .{
        .pattern = ": int",
        .constraint_kind = .type_safety,
        .description = "Int type hint",
    },
    .{
        .pattern = ": string",
        .constraint_kind = .type_safety,
        .description = "String type hint",
    },
    .{
        .pattern = "?",
        .constraint_kind = .type_safety,
        .description = "Nullable type",
    },
};

const php_async_patterns = [_]PatternRule{
    .{
        .pattern = "Fiber",
        .constraint_kind = .semantic,
        .description = "Fiber usage",
    },
    .{
        .pattern = "yield",
        .constraint_kind = .semantic,
        .description = "Generator yield",
    },
};

const php_error_patterns = [_]PatternRule{
    .{
        .pattern = "try {",
        .constraint_kind = .semantic,
        .description = "Try block",
    },
    .{
        .pattern = "catch (",
        .constraint_kind = .semantic,
        .description = "Catch block",
    },
    .{
        .pattern = "finally {",
        .constraint_kind = .semantic,
        .description = "Finally block",
    },
    .{
        .pattern = "throw ",
        .constraint_kind = .semantic,
        .description = "Throw statement",
    },
};

const php_import_patterns = [_]PatternRule{
    .{
        .pattern = "use ",
        .constraint_kind = .architectural,
        .description = "Use statement",
    },
    .{
        .pattern = "require ",
        .constraint_kind = .architectural,
        .description = "Require statement",
    },
    .{
        .pattern = "include ",
        .constraint_kind = .architectural,
        .description = "Include statement",
    },
    .{
        .pattern = "namespace ",
        .constraint_kind = .architectural,
        .description = "Namespace declaration",
    },
};

const php_class_patterns = [_]PatternRule{
    .{
        .pattern = "class ",
        .constraint_kind = .syntactic,
        .description = "Class definition",
    },
    .{
        .pattern = "interface ",
        .constraint_kind = .syntactic,
        .description = "Interface definition",
    },
    .{
        .pattern = "trait ",
        .constraint_kind = .syntactic,
        .description = "Trait definition",
    },
    .{
        .pattern = "enum ",
        .constraint_kind = .syntactic,
        .description = "Enum definition",
    },
};

const php_metadata_patterns = [_]PatternRule{
    .{
        .pattern = "#[",
        .constraint_kind = .syntactic,
        .description = "PHP attribute",
    },
};

const php_memory_patterns = [_]PatternRule{
    .{
        .pattern = "unset(",
        .constraint_kind = .operational,
        .description = "Unset call",
    },
    .{
        .pattern = "__destruct",
        .constraint_kind = .operational,
        .description = "Destructor method",
    },
};

pub const php_patterns = LanguagePatterns{
    .function_decl = &php_function_patterns,
    .type_annotation = &php_type_patterns,
    .async_pattern = &php_async_patterns,
    .error_handling = &php_error_patterns,
    .imports = &php_import_patterns,
    .class_struct = &php_class_patterns,
    .metadata = &php_metadata_patterns,
    .memory_management = &php_memory_patterns,
};

// ============================================================================
// Swift Patterns
// ============================================================================

const swift_function_patterns = [_]PatternRule{
    .{
        .pattern = "func ",
        .constraint_kind = .syntactic,
        .description = "Function definition",
    },
    .{
        .pattern = "async func",
        .constraint_kind = .semantic,
        .description = "Async function",
    },
};

const swift_type_patterns = [_]PatternRule{
    .{
        .pattern = "->",
        .constraint_kind = .type_safety,
        .description = "Return type annotation",
    },
    .{
        .pattern = "Optional",
        .constraint_kind = .type_safety,
        .description = "Optional type",
    },
    .{
        .pattern = "?",
        .constraint_kind = .type_safety,
        .description = "Optional shorthand",
    },
};

const swift_async_patterns = [_]PatternRule{
    .{
        .pattern = "async ",
        .constraint_kind = .semantic,
        .description = "Async keyword",
    },
    .{
        .pattern = "await ",
        .constraint_kind = .semantic,
        .description = "Await keyword",
    },
    .{
        .pattern = "Task {",
        .constraint_kind = .semantic,
        .description = "Task block",
    },
    .{
        .pattern = "actor ",
        .constraint_kind = .semantic,
        .description = "Actor type",
    },
};

const swift_error_patterns = [_]PatternRule{
    .{
        .pattern = "do {",
        .constraint_kind = .semantic,
        .description = "Do block",
    },
    .{
        .pattern = "catch ",
        .constraint_kind = .semantic,
        .description = "Catch block",
    },
    .{
        .pattern = "throw ",
        .constraint_kind = .semantic,
        .description = "Throw statement",
    },
    .{
        .pattern = "try ",
        .constraint_kind = .semantic,
        .description = "Try expression",
    },
};

const swift_import_patterns = [_]PatternRule{
    .{
        .pattern = "import ",
        .constraint_kind = .architectural,
        .description = "Import statement",
    },
};

const swift_class_patterns = [_]PatternRule{
    .{
        .pattern = "class ",
        .constraint_kind = .syntactic,
        .description = "Class definition",
    },
    .{
        .pattern = "struct ",
        .constraint_kind = .syntactic,
        .description = "Struct definition",
    },
    .{
        .pattern = "enum ",
        .constraint_kind = .syntactic,
        .description = "Enum definition",
    },
    .{
        .pattern = "protocol ",
        .constraint_kind = .syntactic,
        .description = "Protocol definition",
    },
    .{
        .pattern = "extension ",
        .constraint_kind = .syntactic,
        .description = "Extension definition",
    },
};

const swift_metadata_patterns = [_]PatternRule{
    .{
        .pattern = "@objc",
        .constraint_kind = .syntactic,
        .description = "Objective-C attribute",
    },
    .{
        .pattern = "@available",
        .constraint_kind = .syntactic,
        .description = "Availability attribute",
    },
};

const swift_memory_patterns = [_]PatternRule{
    .{
        .pattern = "weak ",
        .constraint_kind = .operational,
        .description = "Weak reference",
    },
    .{
        .pattern = "unowned ",
        .constraint_kind = .operational,
        .description = "Unowned reference",
    },
    .{
        .pattern = "deinit",
        .constraint_kind = .operational,
        .description = "Deinitializer",
    },
};

pub const swift_patterns = LanguagePatterns{
    .function_decl = &swift_function_patterns,
    .type_annotation = &swift_type_patterns,
    .async_pattern = &swift_async_patterns,
    .error_handling = &swift_error_patterns,
    .imports = &swift_import_patterns,
    .class_struct = &swift_class_patterns,
    .metadata = &swift_metadata_patterns,
    .memory_management = &swift_memory_patterns,
};

// ============================================================================
// Pattern Selection
// ============================================================================

/// Get patterns for a specific language
pub fn getPatternsForLanguage(language: []const u8) ?LanguagePatterns {
    if (std.mem.eql(u8, language, "typescript") or std.mem.eql(u8, language, "ts")) {
        return typescript_patterns;
    } else if (std.mem.eql(u8, language, "python") or std.mem.eql(u8, language, "py")) {
        return python_patterns;
    } else if (std.mem.eql(u8, language, "javascript") or std.mem.eql(u8, language, "js")) {
        return javascript_patterns;
    } else if (std.mem.eql(u8, language, "rust") or std.mem.eql(u8, language, "rs")) {
        return rust_patterns;
    } else if (std.mem.eql(u8, language, "go")) {
        return go_patterns;
    } else if (std.mem.eql(u8, language, "zig")) {
        return zig_patterns;
    } else if (std.mem.eql(u8, language, "c")) {
        return c_patterns;
    } else if (std.mem.eql(u8, language, "cpp") or std.mem.eql(u8, language, "c++")) {
        return cpp_patterns;
    } else if (std.mem.eql(u8, language, "java")) {
        return java_patterns;
    } else if (std.mem.eql(u8, language, "kotlin") or std.mem.eql(u8, language, "kt")) {
        return kotlin_patterns;
    } else if (std.mem.eql(u8, language, "csharp") or std.mem.eql(u8, language, "cs") or std.mem.eql(u8, language, "c#")) {
        return csharp_patterns;
    } else if (std.mem.eql(u8, language, "ruby") or std.mem.eql(u8, language, "rb")) {
        return ruby_patterns;
    } else if (std.mem.eql(u8, language, "php")) {
        return php_patterns;
    } else if (std.mem.eql(u8, language, "swift")) {
        return swift_patterns;
    }
    return null;
}

/// Match result containing pattern and location
pub const PatternMatch = struct {
    rule: *const PatternRule,
    line: u32,
    column: u32,
    context: []const u8, // Surrounding code context
};

/// Per-language comment and string delimiter rules for context-aware matching.
/// Used by findPatternMatches to skip patterns inside comments and strings.
pub const ContextRules = struct {
    line_comment: []const u8, // e.g. "//" or "#"
    block_comment_open: []const u8, // e.g. "/*"
    block_comment_close: []const u8, // e.g. "*/"
    has_triple_quote: bool, // Python/Kotlin triple-quoted strings
    has_backtick_string: bool, // JS/TS/Go template literals
    has_raw_string: bool, // Rust r"..." raw strings

    pub fn forLanguage(language: []const u8) ContextRules {
        if (std.mem.eql(u8, language, "python") or std.mem.eql(u8, language, "py")) {
            return .{
                .line_comment = "#",
                .block_comment_open = "",
                .block_comment_close = "",
                .has_triple_quote = true,
                .has_backtick_string = false,
                .has_raw_string = false,
            };
        }
        if (std.mem.eql(u8, language, "ruby") or std.mem.eql(u8, language, "rb")) {
            return .{
                .line_comment = "#",
                .block_comment_open = "=begin",
                .block_comment_close = "=end",
                .has_triple_quote = false,
                .has_backtick_string = false,
                .has_raw_string = false,
            };
        }
        // JS/TS have backtick template literals
        if (std.mem.eql(u8, language, "javascript") or std.mem.eql(u8, language, "js") or
            std.mem.eql(u8, language, "typescript") or std.mem.eql(u8, language, "ts"))
        {
            return .{
                .line_comment = "//",
                .block_comment_open = "/*",
                .block_comment_close = "*/",
                .has_triple_quote = false,
                .has_backtick_string = true,
                .has_raw_string = false,
            };
        }
        // Go has backtick raw strings
        if (std.mem.eql(u8, language, "go")) {
            return .{
                .line_comment = "//",
                .block_comment_open = "/*",
                .block_comment_close = "*/",
                .has_triple_quote = false,
                .has_backtick_string = true,
                .has_raw_string = false,
            };
        }
        // Rust has r"..." and r#"..."# raw strings
        if (std.mem.eql(u8, language, "rust") or std.mem.eql(u8, language, "rs")) {
            return .{
                .line_comment = "//",
                .block_comment_open = "/*",
                .block_comment_close = "*/",
                .has_triple_quote = false,
                .has_backtick_string = false,
                .has_raw_string = true,
            };
        }
        // Kotlin has triple-quoted strings
        if (std.mem.eql(u8, language, "kotlin") or std.mem.eql(u8, language, "kt")) {
            return .{
                .line_comment = "//",
                .block_comment_open = "/*",
                .block_comment_close = "*/",
                .has_triple_quote = true,
                .has_backtick_string = false,
                .has_raw_string = false,
            };
        }
        // PHP uses // and /* */ and # for comments
        if (std.mem.eql(u8, language, "php")) {
            return .{
                .line_comment = "//",
                .block_comment_open = "/*",
                .block_comment_close = "*/",
                .has_triple_quote = false,
                .has_backtick_string = false,
                .has_raw_string = false,
            };
        }
        // Default: C-family style (C, C++, Java, C#, Zig, Swift)
        return .{
            .line_comment = "//",
            .block_comment_open = "/*",
            .block_comment_close = "*/",
            .has_triple_quote = false,
            .has_backtick_string = false,
            .has_raw_string = false,
        };
    }
};

/// Lexer state for tracking context (inside comments, strings, etc.)
const LexerState = enum {
    code,
    line_comment,
    block_comment,
    double_string,
    single_string,
    backtick_string,
    triple_string,
    raw_string,
};

/// Check if source at position starts with the given prefix
fn startsWithAt(source: []const u8, pos: usize, prefix: []const u8) bool {
    if (prefix.len == 0) return false;
    if (pos + prefix.len > source.len) return false;
    return std.mem.eql(u8, source[pos .. pos + prefix.len], prefix);
}

/// Find all pattern matches in source code, skipping matches inside
/// comments and string literals.
pub fn findPatternMatches(
    allocator: std.mem.Allocator,
    source: []const u8,
    lang_patterns: LanguagePatterns,
    language: []const u8,
) ![]PatternMatch {
    var matches = std.ArrayList(PatternMatch){};
    errdefer matches.deinit(allocator);

    const rules = ContextRules.forLanguage(language);

    // Combine all pattern categories
    const all_patterns = [_][]const PatternRule{
        lang_patterns.function_decl,
        lang_patterns.type_annotation,
        lang_patterns.async_pattern,
        lang_patterns.error_handling,
        lang_patterns.imports,
        lang_patterns.class_struct,
        lang_patterns.metadata,
        lang_patterns.memory_management,
    };

    var line_num: u32 = 1;
    var line_start: usize = 0;
    var state: LexerState = .code;
    var i: usize = 0;

    while (i < source.len) {
        const c = source[i];

        // Track line numbers
        if (c == '\n') {
            // Line comments end at newline
            if (state == .line_comment) {
                state = .code;
            }
            line_num += 1;
            line_start = i + 1;
            i += 1;
            continue;
        }

        // State transitions
        switch (state) {
            .code => {
                // Check for line comment
                if (rules.line_comment.len > 0 and startsWithAt(source, i, rules.line_comment)) {
                    state = .line_comment;
                    i += rules.line_comment.len;
                    continue;
                }

                // Check for block comment open
                if (rules.block_comment_open.len > 0 and startsWithAt(source, i, rules.block_comment_open)) {
                    state = .block_comment;
                    i += rules.block_comment_open.len;
                    continue;
                }

                // Check for triple-quoted string (before single/double checks)
                if (rules.has_triple_quote and startsWithAt(source, i, "\"\"\"")) {
                    state = .triple_string;
                    i += 3;
                    continue;
                }

                // Check for raw string (Rust: r" or r#")
                if (rules.has_raw_string and c == 'r' and i + 1 < source.len and
                    (source[i + 1] == '"' or source[i + 1] == '#'))
                {
                    state = .raw_string;
                    i += 2;
                    // Skip past r#...#" opener
                    while (i < source.len and source[i] == '#') i += 1;
                    if (i < source.len and source[i] == '"') i += 1;
                    continue;
                }

                // Check for double-quoted string
                if (c == '"') {
                    state = .double_string;
                    i += 1;
                    continue;
                }

                // Check for single-quoted string (skip for Rust lifetimes)
                if (c == '\'' and !rules.has_raw_string) {
                    state = .single_string;
                    i += 1;
                    continue;
                }

                // Check for backtick string
                if (rules.has_backtick_string and c == '`') {
                    state = .backtick_string;
                    i += 1;
                    continue;
                }

                // In code context: check all patterns
                for (all_patterns) |pattern_set| {
                    for (pattern_set) |*pattern| {
                        if (i + pattern.pattern.len <= source.len) {
                            if (std.mem.eql(u8, source[i .. i + pattern.pattern.len], pattern.pattern)) {
                                const line_end = std.mem.indexOfScalarPos(u8, source, i, '\n') orelse source.len;
                                const context = source[line_start..line_end];

                                const match = PatternMatch{
                                    .rule = pattern,
                                    .line = line_num,
                                    .column = @intCast(i - line_start),
                                    .context = context,
                                };
                                try matches.append(allocator, match);
                            }
                        }
                    }
                }
                i += 1;
            },

            .line_comment => {
                // Consumed until newline (handled above)
                i += 1;
            },

            .block_comment => {
                if (rules.block_comment_close.len > 0 and startsWithAt(source, i, rules.block_comment_close)) {
                    state = .code;
                    i += rules.block_comment_close.len;
                } else {
                    i += 1;
                }
            },

            .double_string => {
                if (c == '\\' and i + 1 < source.len) {
                    i += 2; // Skip escape sequence
                } else if (c == '"') {
                    state = .code;
                    i += 1;
                } else {
                    i += 1;
                }
            },

            .single_string => {
                if (c == '\\' and i + 1 < source.len) {
                    i += 2;
                } else if (c == '\'') {
                    state = .code;
                    i += 1;
                } else {
                    i += 1;
                }
            },

            .backtick_string => {
                if (c == '\\' and i + 1 < source.len) {
                    i += 2;
                } else if (c == '`') {
                    state = .code;
                    i += 1;
                } else {
                    i += 1;
                }
            },

            .triple_string => {
                if (startsWithAt(source, i, "\"\"\"")) {
                    state = .code;
                    i += 3;
                } else {
                    i += 1;
                }
            },

            .raw_string => {
                // Simplified: end at unescaped "
                if (c == '"') {
                    state = .code;
                    i += 1;
                } else {
                    i += 1;
                }
            },
        }
    }

    return matches.toOwnedSlice(allocator);
}

test "findPatternMatches: skip patterns in comments" {
    const allocator = std.testing.allocator;
    const source =
        \\// fn commented_out() {}
        \\fn real_function() {}
    ;
    const lang_patterns = getPatternsForLanguage("rust") orelse return error.TestUnexpectedResult;
    const matches = try findPatternMatches(allocator, source, lang_patterns, "rust");
    defer allocator.free(matches);
    // Should only match the real function, not the commented one
    var fn_count: usize = 0;
    for (matches) |m| {
        if (std.mem.eql(u8, m.rule.pattern, "fn ")) fn_count += 1;
    }
    try std.testing.expectEqual(@as(usize, 1), fn_count);
}

test "findPatternMatches: skip patterns in strings" {
    const allocator = std.testing.allocator;
    const source =
        \\const s = "fn fake()";
        \\fn real() {}
    ;
    const lang_patterns = getPatternsForLanguage("rust") orelse return error.TestUnexpectedResult;
    const matches = try findPatternMatches(allocator, source, lang_patterns, "rust");
    defer allocator.free(matches);
    var fn_count: usize = 0;
    for (matches) |m| {
        if (std.mem.eql(u8, m.rule.pattern, "fn ")) fn_count += 1;
    }
    try std.testing.expectEqual(@as(usize, 1), fn_count);
}

test "findPatternMatches: skip patterns in block comments" {
    const allocator = std.testing.allocator;
    const source =
        \\/* fn fake() {} */
        \\fn real() {}
    ;
    const lang_patterns = getPatternsForLanguage("rust") orelse return error.TestUnexpectedResult;
    const matches = try findPatternMatches(allocator, source, lang_patterns, "rust");
    defer allocator.free(matches);
    var fn_count: usize = 0;
    for (matches) |m| {
        if (std.mem.eql(u8, m.rule.pattern, "fn ")) fn_count += 1;
    }
    try std.testing.expectEqual(@as(usize, 1), fn_count);
}

test "findPatternMatches: python hash comments" {
    const allocator = std.testing.allocator;
    const source =
        \\# def commented():
        \\def real():
    ;
    const lang_patterns = getPatternsForLanguage("python") orelse return error.TestUnexpectedResult;
    const matches = try findPatternMatches(allocator, source, lang_patterns, "python");
    defer allocator.free(matches);
    var def_count: usize = 0;
    for (matches) |m| {
        if (std.mem.eql(u8, m.rule.pattern, "def ")) def_count += 1;
    }
    try std.testing.expectEqual(@as(usize, 1), def_count);
}
