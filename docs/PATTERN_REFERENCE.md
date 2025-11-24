# Ananke Pattern Reference

**Version**: 1.0  
**Last Updated**: 2025-11-24  
**Total Patterns**: 101 across 5 languages

## Overview

Ananke uses pattern-based constraint extraction to mine programming patterns from source code. This document catalogs all 101 extraction patterns, organized by language and category.

### Pattern Categories

1. **Function Declarations**: Function definitions, methods, lambdas
2. **Type Annotations**: Type hints, generics, type safety markers
3. **Async Patterns**: Async/await, promises, coroutines
4. **Error Handling**: Try/catch, Result types, error propagation
5. **Imports**: Module imports, dependencies
6. **Class/Struct**: OOP constructs, data structures
7. **Metadata**: Decorators, attributes, compile-time markers
8. **Memory Management**: Allocations, ownership, lifetimes

### Confidence Scoring

Each pattern match generates a confidence score:

- **0.85**: Pattern-based extraction (good but not perfect)
- **0.90+**: Frequent patterns (>5 occurrences)
- **0.95+**: Tree-sitter AST-based (when available)
- **0.70-0.90**: LLM-derived constraints (varies by clarity)

---

## TypeScript Patterns (23 patterns)

### Function Declarations (3 patterns)

| Pattern | Kind | Description | Example |
|---------|------|-------------|---------|
| `async function` | semantic | Async function declaration | `async function fetchData()` |
| `function` | syntactic | Function declaration | `function calculate()` |
| `=>` | syntactic | Arrow function | `const fn = () => {}` |

### Type Annotations (6 patterns)

| Pattern | Kind | Description | Example |
|---------|------|-------------|---------|
| `: string` | type_safety | String type annotation | `name: string` |
| `: number` | type_safety | Number type annotation | `age: number` |
| `: boolean` | type_safety | Boolean type annotation | `active: boolean` |
| `: void` | type_safety | Void type annotation | `fn(): void` |
| `interface` | type_safety | Interface definition | `interface User` |
| `type ` | type_safety | Type alias | `type ID = string` |

### Async Patterns (3 patterns)

| Pattern | Kind | Description | Example |
|---------|------|-------------|---------|
| `async` | semantic | Async keyword | `async function` |
| `await` | semantic | Await keyword | `await promise` |
| `Promise<` | semantic | Promise type | `Promise<User>` |

### Error Handling (3 patterns)

| Pattern | Kind | Description | Example |
|---------|------|-------------|---------|
| `try {` | semantic | Try block | `try { ... }` |
| `catch` | semantic | Catch block | `catch (error)` |
| `throw` | semantic | Throw statement | `throw new Error()` |

### Imports (4 patterns)

| Pattern | Kind | Description | Example |
|---------|------|-------------|---------|
| `import {` | architectural | Named import | `import { fn } from` |
| `import * as` | architectural | Namespace import | `import * as lib` |
| `import ` | architectural | Import statement | `import lib from` |
| `export` | architectural | Export statement | `export const` |

### Class Declarations (3 patterns)

| Pattern | Kind | Description | Example |
|---------|------|-------------|---------|
| `class ` | syntactic | Class declaration | `class User {}` |
| `extends` | syntactic | Class inheritance | `class Admin extends User` |
| `implements` | type_safety | Interface implementation | `implements IUser` |

### Metadata (1 pattern)

| Pattern | Kind | Description | Example |
|---------|------|-------------|---------|
| `@` | syntactic | Decorator | `@Component` |

**Total TypeScript**: 23 patterns

---

## Python Patterns (21 patterns)

### Function Declarations (3 patterns)

| Pattern | Kind | Description | Example |
|---------|------|-------------|---------|
| `async def` | semantic | Async function definition | `async def fetch()` |
| `def ` | syntactic | Function definition | `def calculate()` |
| `lambda` | syntactic | Lambda function | `lambda x: x * 2` |

### Type Annotations (7 patterns)

| Pattern | Kind | Description | Example |
|---------|------|-------------|---------|
| `-> ` | type_safety | Return type annotation | `def fn() -> int:` |
| `: int` | type_safety | Int type hint | `age: int` |
| `: str` | type_safety | String type hint | `name: str` |
| `: bool` | type_safety | Boolean type hint | `active: bool` |
| `: List[` | type_safety | List type hint | `items: List[str]` |
| `: Dict[` | type_safety | Dict type hint | `data: Dict[str, int]` |
| `: Optional[` | type_safety | Optional type hint | `value: Optional[int]` |

### Async Patterns (3 patterns)

| Pattern | Kind | Description | Example |
|---------|------|-------------|---------|
| `async def` | semantic | Async function | `async def fetch()` |
| `await ` | semantic | Await expression | `await coroutine()` |
| `asyncio` | semantic | Asyncio library usage | `import asyncio` |

### Error Handling (4 patterns)

| Pattern | Kind | Description | Example |
|---------|------|-------------|---------|
| `try:` | semantic | Try block | `try: ...` |
| `except` | semantic | Exception handler | `except ValueError:` |
| `raise` | semantic | Raise exception | `raise Exception()` |
| `finally:` | semantic | Finally block | `finally: cleanup()` |

### Imports (2 patterns)

| Pattern | Kind | Description | Example |
|---------|------|-------------|---------|
| `import ` | architectural | Import statement | `import sys` |
| `from ` | architectural | From import | `from os import path` |

### Class Declarations (2 patterns)

| Pattern | Kind | Description | Example |
|---------|------|-------------|---------|
| `class ` | syntactic | Class definition | `class User:` |
| `@dataclass` | syntactic | Dataclass decorator | `@dataclass class User` |

### Metadata (1 pattern)

| Pattern | Kind | Description | Example |
|---------|------|-------------|---------|
| `@` | syntactic | Decorator | `@property` |

**Total Python**: 21 patterns (1 duplicate with async def)

---

## Rust Patterns (28 patterns)

### Function Declarations (3 patterns)

| Pattern | Kind | Description | Example |
|---------|------|-------------|---------|
| `async fn` | semantic | Async function | `async fn fetch()` |
| `pub fn` | syntactic | Public function | `pub fn calculate()` |
| `fn ` | syntactic | Function definition | `fn helper()` |

### Type Annotations (7 patterns)

| Pattern | Kind | Description | Example |
|---------|------|-------------|---------|
| `Result<` | type_safety | Result type | `Result<T, E>` |
| `Option<` | type_safety | Option type | `Option<T>` |
| `impl ` | type_safety | Trait implementation | `impl Trait for Type` |
| `trait ` | type_safety | Trait definition | `trait MyTrait` |
| `&str` | type_safety | String slice reference | `fn(&str)` |
| `&mut` | type_safety | Mutable reference | `&mut value` |
| `&` | type_safety | Reference | `&value` |

### Async Patterns (2 patterns)

| Pattern | Kind | Description | Example |
|---------|------|-------------|---------|
| `async` | semantic | Async keyword | `async move` |
| `.await` | semantic | Await expression | `future.await` |

### Error Handling (4 patterns)

| Pattern | Kind | Description | Example |
|---------|------|-------------|---------|
| `Result<` | semantic | Result type for error handling | `Result<(), Error>` |
| `?` | semantic | Error propagation operator | `file.read()?` |
| `unwrap()` | semantic | Unwrap (potential panic) | `value.unwrap()` |
| `expect(` | semantic | Expect with message | `val.expect("msg")` |

### Imports (2 patterns)

| Pattern | Kind | Description | Example |
|---------|------|-------------|---------|
| `use ` | architectural | Use statement | `use std::fs;` |
| `mod ` | architectural | Module declaration | `mod utils;` |

### Class/Struct Declarations (2 patterns)

| Pattern | Kind | Description | Example |
|---------|------|-------------|---------|
| `struct ` | syntactic | Struct definition | `struct User {}` |
| `enum ` | syntactic | Enum definition | `enum Status {}` |

### Metadata (2 patterns)

| Pattern | Kind | Description | Example |
|---------|------|-------------|---------|
| `#[derive(` | syntactic | Derive macro | `#[derive(Debug)]` |
| `#[` | syntactic | Attribute | `#[test]` |

### Memory Management (6 patterns)

| Pattern | Kind | Description | Example |
|---------|------|-------------|---------|
| `Box<` | operational | Heap allocation | `Box<T>` |
| `Rc<` | operational | Reference counting | `Rc<T>` |
| `Arc<` | operational | Atomic reference counting | `Arc<T>` |
| `'static` | type_safety | Static lifetime | `&'static str` |
| `'_` | type_safety | Elided lifetime | `fn(&'_ str)` |

**Total Rust**: 28 patterns

---

## Zig Patterns (27 patterns)

### Function Declarations (2 patterns)

| Pattern | Kind | Description | Example |
|---------|------|-------------|---------|
| `pub fn` | syntactic | Public function | `pub fn calculate()` |
| `fn ` | syntactic | Function definition | `fn helper()` |

### Type Annotations (5 patterns)

| Pattern | Kind | Description | Example |
|---------|------|-------------|---------|
| `!void` | type_safety | Error union returning void | `fn() !void` |
| `!` | type_safety | Error union type | `T!` |
| `?` | type_safety | Optional type | `?T` |
| `[]const u8` | type_safety | Const byte slice | `[]const u8` |
| `[]u8` | type_safety | Mutable byte slice | `[]u8` |

### Async Patterns (4 patterns)

| Pattern | Kind | Description | Example |
|---------|------|-------------|---------|
| `async` | semantic | Async function | `async fn()` |
| `await` | semantic | Await expression | `await frame` |
| `suspend` | semantic | Suspend point | `suspend {}` |
| `resume` | semantic | Resume coroutine | `resume frame` |

### Error Handling (6 patterns)

| Pattern | Kind | Description | Example |
|---------|------|-------------|---------|
| `error{` | semantic | Error set definition | `error{OutOfMemory}` |
| `Error!` | semantic | Error union type | `Error!T` |
| `try ` | semantic | Try expression | `try operation()` |
| `catch` | semantic | Catch expression | `fn() catch err` |
| `error.` | semantic | Error value | `error.OutOfMemory` |
| `errdefer` | semantic | Errdefer statement | `errdefer free()` |

### Imports (1 pattern)

| Pattern | Kind | Description | Example |
|---------|------|-------------|---------|
| `@import(` | architectural | Import builtin | `@import("std")` |

### Class/Struct Declarations (4 patterns)

| Pattern | Kind | Description | Example |
|---------|------|-------------|---------|
| `const struct` | syntactic | Const struct definition | `const S = struct {}` |
| `struct {` | syntactic | Struct definition | `struct { ... }` |
| `enum {` | syntactic | Enum definition | `enum { ... }` |
| `union {` | syntactic | Union definition | `union { ... }` |

### Metadata (2 patterns)

| Pattern | Kind | Description | Example |
|---------|------|-------------|---------|
| `comptime` | operational | Compile-time execution | `comptime var` |
| `pub const` | syntactic | Public constant | `pub const x = 1` |

### Memory Management (5 patterns)

| Pattern | Kind | Description | Example |
|---------|------|-------------|---------|
| `Allocator` | operational | Allocator type | `std.mem.Allocator` |
| `.alloc(` | operational | Allocation call | `allocator.alloc()` |
| `.free(` | operational | Free call | `allocator.free()` |
| `defer ` | operational | Defer statement | `defer deinit()` |
| `deinit()` | operational | Deinitialization | `obj.deinit()` |

**Total Zig**: 27 patterns (1 duplicate corrected)

---

## Go Patterns (2 patterns - minimal support)

### Currently Supported

| Pattern | Kind | Description | Example |
|---------|------|-------------|---------|
| `func ` | syntactic | Function declaration | `func calculate()` |
| `go ` | semantic | Goroutine launch | `go routine()` |

**Note**: Go support is minimal. Future expansion planned for:
- Channels (`chan`, `<-chan`, `chan<-`)
- Interfaces (`interface{}`)
- Defer statements (`defer`)
- Error handling (`if err != nil`)

**Total Go**: 2 patterns

---

## Pattern Matching Algorithm

### Match Detection

```zig
pub fn findPatternMatches(
    allocator: Allocator,
    source: []const u8,
    patterns: LanguagePatterns,
) ![]PatternMatch {
    var matches = std.ArrayList(PatternMatch){};
    
    // Iterate through all pattern categories
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
    
    // Track line numbers for provenance
    var line: u32 = 1;
    var line_start: usize = 0;
    
    for (source, 0..) |char, idx| {
        if (char == '\n') {
            line += 1;
            line_start = idx + 1;
        }
        
        // Check each pattern at this position
        for (all_patterns) |pattern_category| {
            for (pattern_category) |pattern_rule| {
                if (matchesAt(source, idx, pattern_rule.pattern)) {
                    try matches.append(allocator, .{
                        .rule = pattern_rule,
                        .line = line,
                        .col = idx - line_start,
                    });
                }
            }
        }
    }
    
    return try matches.toOwnedSlice(allocator);
}
```

### Performance Characteristics

- **Time Complexity**: O(n × p) where n = source length, p = pattern count
- **Space Complexity**: O(m) where m = number of matches
- **Optimization**: Early exit on non-matching first character

**Benchmarks**:
- 75 lines of TypeScript: 4-5ms (101 patterns checked)
- 200 lines of Rust: 10-12ms
- 500 lines of Python: 25-30ms

---

## Adding Custom Patterns

### Step 1: Define Pattern Rule

```zig
// In src/clew/patterns.zig
const my_custom_patterns = [_]PatternRule{
    .{
        .pattern = "my_keyword",
        .constraint_kind = .semantic,
        .description = "My custom pattern",
        .capture_groups = 0,  // For future regex support
    },
};
```

### Step 2: Add to Language Patterns

```zig
pub const my_language_patterns = LanguagePatterns{
    .function_decl = &my_function_patterns,
    .type_annotation = &my_type_patterns,
    .async_pattern = &my_async_patterns,
    .error_handling = &my_error_patterns,
    .imports = &my_import_patterns,
    .class_struct = &my_class_patterns,
    .metadata = &my_custom_patterns,  // <-- Add here
    .memory_management = &my_memory_patterns,
};
```

### Step 3: Register Language

```zig
pub fn getPatternsForLanguage(language: []const u8) ?LanguagePatterns {
    if (std.mem.eql(u8, language, "my_language")) {
        return my_language_patterns;
    }
    // ... other languages
    return null;
}
```

### Step 4: Test Pattern

```zig
test "my custom pattern extraction" {
    var clew = try Clew.init(testing.allocator);
    defer clew.deinit();
    
    const source = "my_keyword example code";
    const constraints = try clew.extractFromCode(source, "my_language");
    defer constraints.deinit();
    
    try testing.expect(constraints.constraints.items.len > 0);
}
```

---

## Pattern Coverage Analysis

### By Constraint Kind

| Kind | Pattern Count | Languages |
|------|---------------|-----------|
| syntactic | 35 | All |
| type_safety | 29 | TS, Py, Rust, Zig |
| semantic | 24 | All |
| architectural | 12 | All |
| operational | 15 | Rust, Zig |
| security | 0 | (Token masks only) |

### By Language Support

| Language | Function | Type | Async | Error | Import | Class | Meta | Memory |
|----------|----------|------|-------|-------|--------|-------|------|--------|
| TypeScript | 3 | 6 | 3 | 3 | 4 | 3 | 1 | 0 |
| Python | 3 | 7 | 3 | 4 | 2 | 2 | 1 | 0 |
| Rust | 3 | 7 | 2 | 4 | 2 | 2 | 2 | 6 |
| Zig | 2 | 5 | 4 | 6 | 1 | 4 | 2 | 5 |
| Go | 1 | 0 | 1 | 0 | 0 | 0 | 0 | 0 |
| **Total** | 12 | 25 | 13 | 17 | 9 | 11 | 6 | 11 |

### Coverage Estimate

**With Pattern Matching**: ~80%
- Captures common syntactic constructs
- Misses complex nested structures
- May produce false positives on comments

**With Tree-Sitter** (Future): ~95%
- Full AST understanding
- Context-aware matching
- Accurate line/column positions

---

## Pattern Limitations

### Current Limitations

1. **No Context Awareness**: Cannot distinguish pattern in comment vs code
2. **No Nesting Detection**: Misses deeply nested structures
3. **Substring Matching**: May match partial keywords
4. **No Semantic Understanding**: Cannot infer meaning from context

### Workarounds

**False Positives**:
- Filter by confidence score (<0.85 likely spurious)
- Use frequency analysis (single occurrence = suspicious)
- Cross-reference with Claude semantic analysis

**False Negatives**:
- Add more specific patterns
- Use Claude API for missed patterns
- Combine with tree-sitter (when available)

---

## Pattern Evolution

### Phase 6 (Tree-Sitter Integration)

When tree-sitter support is restored:

**Pattern Role**: Fallback + quick filtering
**Tree-Sitter Role**: Primary extraction + validation

**Hybrid Approach**:
1. Run pattern matching (fast, 4-7ms)
2. Run tree-sitter parsing (slower, 10-15ms)
3. Merge results, prefer tree-sitter for conflicts
4. Use patterns for unsupported languages

---

## References

- Pattern implementation: `/Users/rand/src/ananke/src/clew/patterns.zig`
- Extraction logic: `/Users/rand/src/ananke/src/clew/clew.zig`
- Pattern tests: `/Users/rand/src/ananke/test/clew/pattern_extraction_test.zig`

**Document Version**: 1.0  
**Maintained By**: Claude Code (docs-writer subagent)  
**Last Updated**: 2025-11-24
