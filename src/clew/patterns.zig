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
        .pattern = "try ",
        .constraint_kind = .semantic,
        .description = "Try expression",
    },
    .{
        .pattern = "catch",
        .constraint_kind = .semantic,
        .description = "Catch expression",
    },
    .{
        .pattern = "error.",
        .constraint_kind = .semantic,
        .description = "Error value",
    },
    .{
        .pattern = "errdefer",
        .constraint_kind = .semantic,
        .description = "Error defer",
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
// Pattern Selection
// ============================================================================

/// Get patterns for a specific language
pub fn getPatternsForLanguage(language: []const u8) ?LanguagePatterns {
    if (std.mem.eql(u8, language, "typescript") or std.mem.eql(u8, language, "ts")) {
        return typescript_patterns;
    } else if (std.mem.eql(u8, language, "python") or std.mem.eql(u8, language, "py")) {
        return python_patterns;
    } else if (std.mem.eql(u8, language, "rust") or std.mem.eql(u8, language, "rs")) {
        return rust_patterns;
    } else if (std.mem.eql(u8, language, "zig")) {
        return zig_patterns;
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

/// Find all pattern matches in source code
pub fn findPatternMatches(
    allocator: std.mem.Allocator,
    source: []const u8,
    patterns: LanguagePatterns,
) ![]PatternMatch {
    var matches = std.ArrayList(PatternMatch){};
    errdefer matches.deinit(allocator);

    // Combine all pattern categories
    const all_patterns = [_][]const PatternRule{
        patterns.function_decl,
        patterns.type_annotation,
        patterns.async_pattern,
        patterns.error_handling,
        patterns.imports,
        patterns.class_struct,
        patterns.metadata,
        patterns.memory_management,
    };

    var line_num: u32 = 1;
    var line_start: usize = 0;
    var i: usize = 0;

    while (i < source.len) : (i += 1) {
        // Track line numbers
        if (source[i] == '\n') {
            line_num += 1;
            line_start = i + 1;
            continue;
        }

        // Check all patterns
        for (all_patterns) |pattern_set| {
            for (pattern_set) |*pattern| {
                // Check if pattern matches at current position
                if (i + pattern.pattern.len <= source.len) {
                    if (std.mem.eql(u8, source[i .. i + pattern.pattern.len], pattern.pattern)) {
                        // Extract context (current line)
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
    }

    return matches.toOwnedSlice(allocator);
}
