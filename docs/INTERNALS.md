# Ananke Internals: Developer Guide

This guide provides deep technical documentation of Ananke's internal architecture for developers who want to understand, maintain, or extend the codebase.

**Audience**: Systems engineers, compiler developers, maintainers

**Time to Read**: 60-90 minutes for full overview

---

## Table of Contents

- [Overview](#overview)
- [Core Type System](#core-type-system)
- [Clew: Constraint Extraction Engine](#clew-constraint-extraction-engine)
- [Braid: Constraint Compilation Engine](#braid-constraint-compilation-engine)
- [Ariadne: Constraint DSL](#ariadne-constraint-dsl)
- [Maze: Orchestration Layer](#maze-orchestration-layer)
- [Memory Management](#memory-management)
- [Concurrency Model](#concurrency-model)
- [Testing Strategy](#testing-strategy)
- [Performance Profiling](#performance-profiling)

---

## Overview

Ananke transforms AI code generation through **constraint-driven synthesis**: converting probabilistic text completion into controlled search through valid program spaces.

### System Layers

```
Layer 4: Inference Service (GPU)
├─ vLLM/SGLang Server
├─ llguidance Token Masking
└─ Constrained Generation

Layer 3: Maze (Orchestration)
├─ Async Rust + Tokio
├─ FFI Boundary (Zig/Rust)
└─ HTTP Client

Layer 2: Braid (Compilation)
├─ Constraint Graph Analysis
├─ Conflict Resolution
├─ IR Generation
└─ LRU Caching

Layer 1: Clew (Extraction)
├─ Pattern Matching
├─ Language Parsing
└─ Optional LLM Analysis

Foundation: Type System
├─ Constraint Definition
├─ Constraint Kinds
└─ Intermediate Representation
```

### Key Files

**Type System** (`/Users/rand/src/ananke/src/types/`)
- `constraint.zig` - Core type definitions (Constraint, ConstraintIR, ConstraintKind)
- `intent.zig` - Intent representation for generation requests

**Clew** (`/Users/rand/src/ananke/src/clew/`)
- `clew.zig` - Main extraction engine
- `parsers/` - Language-specific parsers
- `patterns/` - Constraint pattern library
- `extractors/` - Source-specific extractors

**Braid** (`/Users/rand/src/ananke/src/braid/`)
- `braid.zig` - Main compilation engine
- `json_schema_builder.zig` - JSON schema generation

**Ariadne** (`/Users/rand/src/ananke/src/ariadne/`)
- `ariadne.zig` - DSL parser and compiler

**CLI** (`/Users/rand/src/ananke/src/cli/`)
- `main.zig` - Entry point
- `commands/` - Command implementations
- `config.zig` - Configuration management

---

## Core Type System

### Constraint Definition

**File**: `/Users/rand/src/ananke/src/types/constraint.zig`

```zig
pub const Constraint = struct {
    /// Unique constraint identifier
    id: []const u8,
    
    /// Human-readable name
    name: []const u8,
    
    /// Constraint category
    kind: ConstraintKind,
    
    /// What constraint enforces
    description: []const u8,
    
    /// Where constraint came from
    source: ConstraintSource,
    
    /// Evaluation priority (higher = earlier)
    priority: ConstraintPriority = .medium,
    
    /// Whether constraint is active
    enabled: bool = true,
    
    /// Dependent constraint IDs
    dependencies: []const []const u8 = &[_][]const u8{},
    
    /// Conflicting constraint IDs (if known)
    conflicts: []const []const u8 = &[_][]const u8{},
};

pub const ConstraintKind = enum {
    type_safety,
    security,
    performance,
    semantic,
    architectural,
    custom,
};

pub const ConstraintSource = enum {
    source_code,
    test_file,
    telemetry,
    documentation,
    ariadne_dsl,
    api_spec,
    policy,
    user_defined,
};
```

### Constraint Set

Wrapper around collection of constraints with metadata:

```zig
pub const ConstraintSet = struct {
    constraints: std.ArrayList(Constraint),
    extracted_at: i64,  // Unix timestamp
    version: []const u8,
    
    /// Add constraint to set
    pub fn add(self: *ConstraintSet, constraint: Constraint) !void
    
    /// Check if constraint exists by ID
    pub fn contains(self: ConstraintSet, id: []const u8) bool
    
    /// Remove constraint by ID
    pub fn remove(self: *ConstraintSet, id: []const u8) bool
    
    /// Get constraint by ID
    pub fn get(self: ConstraintSet, id: []const u8) ?Constraint
};
```

### ConstraintIR: Intermediate Representation

The compiled form of constraints, optimized for token-level validation:

```zig
pub const ConstraintIR = union(ConstraintKind) {
    type_safety: JsonSchema,
    security: Grammar,
    performance: TokenMaskRules,
    semantic: RegexConstraints,
    architectural: DependencyRules,
    custom: CustomConstraintIR,
};
```

**Each variant stores precompiled form ready for inference:**

```zig
pub const JsonSchema = struct {
    type: []const u8,  // "object", "array", "string", etc.
    properties: ?std.StringHashMap(JsonSchema),
    required: [][]const u8,
    pattern: ?[]const u8,
    minLength: ?usize,
    maxLength: ?usize,
    enum: ?[][]const u8,
};

pub const Grammar = struct {
    rules: []GrammarRule,
    start_symbol: []const u8,
};

pub const GrammarRule = struct {
    name: []const u8,
    productions: [][]const u8,  // Alternatives
};

pub const TokenMaskRules = struct {
    rules: []TokenMaskRule,
};

pub const TokenMaskRule = struct {
    context: []const u8,  // Previous tokens pattern
    allowed_tokens: []i32,  // Token IDs that satisfy constraint
    forbidden_tokens: []i32,
};
```

---

## Clew: Constraint Extraction Engine

**Location**: `/Users/rand/src/ananke/src/clew/clew.zig`

**Purpose**: Mine constraints from multiple sources through pattern matching and optional LLM analysis.

### Architecture

```
Source Code (TS/Py/Rust/Zig)
    ↓
Language Detection
    ↓
Tokenization
    ↓
Pattern Matching (101 built-in patterns)
    ↓
Constraint Extraction
    ↓
Optional Claude Analysis (semantic enrichment)
    ↓
ConstraintSet
```

### Main Functions

#### `extractFromCode()`

```zig
pub fn extractFromCode(
    self: *Clew,
    source: []const u8,
    language: []const u8,
) !ConstraintSet
```

**Complexity**: O(n) where n = source code length

**Time**: 4-7ms for ~75 lines (pattern-based)

**Algorithm**:
1. Language detection (switch on language string)
2. Get language parser from factory
3. Tokenize source code
4. Apply pattern library to tokens
5. Deduplicate constraints
6. Optional: Call Claude for semantic analysis
7. Return ConstraintSet

**Pattern Library** (101 patterns):

Patterns are regex/syntactic rules that match constraint indicators:

```zig
pub const PATTERNS = [_]Pattern{
    .{
        .name = "null_check_required",
        .regex = "if \\(.*\\s*==\\s*null\\)",
        .kind = .type_safety,
    },
    .{
        .name = "encryption_required",
        .regex = "password|secret|credential",
        .kind = .security,
    },
    // ... 99 more patterns
};
```

#### `extractFromTests()`

Analyzes test files for implicit constraints:

```zig
pub fn extractFromTests(self: *Clew, test_source: []const u8) !ConstraintSet
```

**Extracts**:
- Invariants from assertions
- Input validation patterns
- Expected error conditions
- Boundary values

**Example**:
```javascript
test("rejects negative numbers", () => {
  expect(() => process(-1)).toThrow();
});
```

Extracted constraint: "input must be non-negative"

#### `extractFromTelemetry()`

Generates operational constraints from production data:

```zig
pub fn extractFromTelemetry(
    self: *Clew,
    telemetry: Telemetry,
) !ConstraintSet
```

**Example**: If P99 latency > 100ms, generates performance constraint

### Language Parsers

**File**: `/Users/rand/src/ananke/src/clew/parsers/`

Each language gets a dedicated parser:

```zig
pub const TypeScriptParser = struct {
    pub fn tokenize(source: []const u8) ![]Token
    pub fn extractFunctions(source: []const u8) ![]FunctionPattern
    pub fn extractClasses(source: []const u8) ![]ClassPattern
    pub fn extractTypeAnnotations(source: []const u8) ![]TypeConstraint
};
```

**Tokenization strategy**: Lexical analysis without full AST

**Trade-off**: Speed (ms) over complete semantic understanding

### Claude Integration

Optional semantic analysis step:

```zig
pub fn setClaudeClient(self: *Clew, client: *claude_api.ClaudeClient) void {
    self.claude_client = client;
}
```

When set, after pattern extraction:
1. Serialize constraints to JSON
2. Send to Claude API with context
3. Receive enhanced/additional constraints
4. Merge results

**Performance impact**: +200-500ms per extraction (HTTP latency)

---

## Braid: Constraint Compilation Engine

**Location**: `/Users/rand/src/ananke/src/braid/braid.zig`

**Purpose**: Transform constraints into optimized evaluation programs (ConstraintIR).

### Compilation Pipeline

```
Constraint[]
    ↓
Build Dependency Graph (DAG)
    ↓
Detect Conflicts
    ↓
Resolve Conflicts (heuristic or LLM)
    ↓
Optimize Order (topological sort)
    ↓
Generate IR (JSON Schema, Grammar, Regex, TokenMasks)
    ↓
Cache Results (LRU, 20x typical speedup)
    ↓
ConstraintIR
```

### Step 1: Dependency Graph Construction

```zig
fn buildDependencyGraph(self: *Braid, constraints: []const Constraint) !ConstraintGraph {
    // Initialize graph with constraint count vertices
    var graph = try ConstraintGraph.init(allocator, constraints.len);
    
    // Build edges from dependency declarations
    for (constraints) |constraint, i| {
        for (constraint.dependencies) |dep_id| {
            // Find constraint with dep_id
            if (findConstraint(constraints, dep_id)) |dep_idx| {
                try graph.addEdge(i, dep_idx);
            }
        }
    }
    
    return graph;
}

pub const ConstraintGraph = struct {
    vertices: usize,
    edges: [][]usize,  // Adjacency list
    constraints: []const Constraint,
    
    pub fn hasCycle(self: ConstraintGraph) bool {
        // DFS-based cycle detection
    }
};
```

**Complexity**: O(c²) worst case where c = constraint count

**Typical case**: O(c) for sparse graphs

### Step 2: Conflict Detection

Identifies constraints that cannot be simultaneously satisfied:

```zig
fn detectConflicts(self: *Braid, graph: *ConstraintGraph) ![]Conflict {
    var conflicts = std.ArrayList(Conflict).init(self.allocator);
    
    // Check explicit conflict declarations
    for (graph.constraints) |constraint| {
        for (constraint.conflicts) |conflict_id| {
            try conflicts.append(Conflict{
                .constraint_a = constraint.id,
                .constraint_b = conflict_id,
                .reason = .explicit_declaration,
            });
        }
    }
    
    // Semantic conflict detection (if enabled)
    try self.detectSemanticConflicts(graph, &conflicts);
    
    return conflicts.toOwnedSlice();
}

pub const Conflict = struct {
    constraint_a: []const u8,
    constraint_b: []const u8,
    reason: ConflictReason,
    severity: Severity = .warning,
};
```

**Conflict types**:
- **Explicit**: Declared in constraint metadata
- **Semantic**: Incompatible requirements (e.g., "forbid eval" + "allow eval")
- **Resource**: Competing for same resource

### Step 3: Conflict Resolution

Three strategies:

```zig
fn resolveConflicts(self: *Braid, graph: *ConstraintGraph, conflicts: []const Conflict) !void {
    for (conflicts) |conflict| {
        if (conflict.severity == .error) {
            // Option 1: Manual override (user specified resolution)
            if (self.resolution_overrides.get(conflict.constraint_a)) |action| {
                switch (action) {
                    .disable => disableConstraint(graph, conflict.constraint_b),
                    .relax => relaxConstraint(graph, conflict.constraint_b),
                    .reorder => reorderConstraints(graph, conflict.constraint_a, conflict.constraint_b),
                }
            } else if (self.llm_client) |client| {
                // Option 2: LLM-assisted resolution
                const suggestion = try client.suggestResolution(conflict);
                try applyResolution(graph, suggestion);
            } else {
                // Option 3: Default heuristic
                try defaultResolution(graph, conflict);
            }
        }
    }
}
```

### Step 4: Graph Optimization

Topological sort to determine evaluation order:

```zig
fn optimizeGraph(self: *Braid, graph: *ConstraintGraph) !void {
    const order = try topologicalSort(graph);
    
    // Reorder constraints to minimize redundant checks
    var optimized = std.ArrayList(Constraint).init(self.allocator);
    for (order) |idx| {
        try optimized.append(graph.constraints[idx]);
    }
    
    graph.constraints = optimized.items;
}
```

**Result**: Constraints evaluated in dependency order, maximizing early termination.

### Step 5: IR Generation

Convert constraints to format llguidance can use:

```zig
fn compileToIR(self: *Braid, graph: *ConstraintGraph) !ConstraintIR {
    // Group constraints by kind
    var ir: ConstraintIR = undefined;
    
    for (graph.constraints) |constraint| {
        switch (constraint.kind) {
            .type_safety => {
                ir.type_safety = try self.buildJsonSchema(constraint);
            },
            .security => {
                ir.security = try self.buildGrammar(constraint);
            },
            .performance => {
                ir.performance = try self.buildTokenMasks(constraint);
            },
            // ... other kinds
        }
    }
    
    return ir;
}
```

### Step 6: IR Caching

LRU cache with clone-on-get strategy:

```zig
pub const IRCache = struct {
    cache: std.AutoHashMap([32]u8, ConstraintIR),  // Hash -> IR
    lru_order: RingQueue(usize),  // Track access order
    max_size: usize = 128,  // Max 128 compiled IRs in memory
    
    pub fn get(self: *IRCache, key: [32]u8) !?ConstraintIR {
        if (self.cache.get(key)) |ir| {
            // Clone before returning (copy-on-get)
            const cloned = try ir.clone(self.allocator);
            self.lru_order.push(key);
            return cloned;
        }
        return null;
    }
    
    pub fn put(self: *IRCache, key: [32]u8, ir: ConstraintIR) !void {
        if (self.cache.count() >= self.max_size) {
            // Evict LRU entry
            const oldest = self.lru_order.pop() orelse return;
            _ = self.cache.remove(oldest);
        }
        try self.cache.put(key, ir);
    }
};
```

**Performance**: ~20x typical speedup on repeated compilations

---

## Ariadne: Constraint DSL

**Location**: `/Users/rand/src/ananke/src/ariadne/ariadne.zig`

**Purpose**: High-level language for expressing complex constraint relationships.

### DSL Syntax

```ariadne
constraint secure_api inherits base_security {
    requires: authentication;
    validates: input_schema;
    forbid: ["eval", "exec", "system"];
    
    temporal: {
        timeout: 30s;
        retry_policy: exponential_backoff;
    }
    
    complexity: {
        max_cyclomatic: 10;
        max_nesting: 5;
    }
}
```

### Parsing Strategy

```
DSL Source
    ↓
Lexical Analysis (tokenization)
    ↓
Syntax Analysis (grammar parsing)
    ↓
Semantic Analysis (type checking, v0.2)
    ↓
Code Generation (Constraint[])
```

### Lexer

```zig
pub fn tokenize(source: []const u8) ![]Token {
    var tokens = std.ArrayList(Token).init(allocator);
    
    // Scan source character by character
    while (i < source.len) {
        // Skip whitespace
        // Handle keywords (constraint, requires, forbid, etc.)
        // Handle identifiers
        // Handle strings/numbers
        // Handle operators
    }
    
    return tokens.toOwnedSlice();
}
```

### Parser

Recursive descent parser:

```zig
pub fn parse(self: *Parser) ![]Constraint {
    var constraints = std.ArrayList(Constraint).init(self.allocator);
    
    while (!self.isAtEnd()) {
        const constraint = try self.parseConstraint();
        try constraints.append(constraint);
    }
    
    return constraints.toOwnedSlice();
}

fn parseConstraint(self: *Parser) !Constraint {
    try self.consume(.keyword_constraint, "Expected 'constraint'");
    const name = try self.parseIdentifier();
    
    var inherited: ?[]const u8 = null;
    if (self.match(.keyword_inherits)) {
        inherited = try self.parseIdentifier();
    }
    
    try self.consume(.left_brace, "Expected '{'");
    const body = try self.parseConstraintBody();
    try self.consume(.right_brace, "Expected '}'");
    
    return Constraint{
        .name = name,
        .inherits_from = inherited,
        .body = body,
    };
}
```

### Compilation to Constraints

```zig
fn compileConstraint(self: *Compiler, ariadne_constraint: AriadneConstraint) ![]Constraint {
    var constraints = std.ArrayList(Constraint).init(self.allocator);
    
    // Handle inheritance
    if (ariadne_constraint.inherits_from) |parent_name| {
        const parent = try self.lookupConstraint(parent_name);
        // Merge parent constraints
    }
    
    // Compile each declaration
    for (ariadne_constraint.requires) |req| {
        try constraints.append(try self.compileRequirement(req));
    }
    
    for (ariadne_constraint.forbid) |forbid_item| {
        try constraints.append(try self.compileForbid(forbid_item));
    }
    
    return constraints.toOwnedSlice();
}
```

---

## Maze: Orchestration Layer

**Location**: `/Users/rand/src/ananke/src/maze/` (Rust)

**Language**: Rust (PyO3 bindings to Python)

**Purpose**: Coordinate constrained code generation with inference service.

### Architecture

```
Python CLI / Library Call
    ↓
PyO3 Binding (Python ↔ Rust FFI)
    ↓
Rust Async Executor (Tokio)
    ↓
Constraint Application (token masking)
    ↓
HTTP Client (Modal/vLLM)
    ↓
Inference Service (GPU)
    ↓
Token Stream
    ↓
Output
```

### FFI Boundary

**Zig side** (exports):
```zig
pub extern "c" fn clew_extract(source: [*]const u8, len: usize, language: [*]const u8) callconv(.C) ConstraintSet
pub extern "c" fn braid_compile(constraints: [*]const Constraint, count: usize) callconv(.C) ConstraintIR
```

**Rust side** (imports):
```rust
extern "C" {
    fn clew_extract(source: *const u8, len: usize, language: *const u8) -> ConstraintSet;
    fn braid_compile(constraints: *const Constraint, count: usize) -> ConstraintIR;
}
```

### Token Masking Application

```rust
pub fn apply_constraints(
    ir: &ConstraintIR,
    logits: &mut [f32],
    token_id: i32,
) -> Result<()> {
    // Apply JSON schema validation
    if let Some(schema) = &ir.json_schema {
        self.apply_json_schema(schema, logits)?;
    }
    
    // Apply grammar rules
    if let Some(grammar) = &ir.grammar {
        self.apply_grammar(grammar, logits)?;
    }
    
    // Apply token masks
    if let Some(masks) = &ir.token_masks {
        self.apply_token_masks(masks, logits)?;
    }
    
    // Zero out disallowed tokens
    for (mask, logit) in self.allowed_mask.iter().zip(logits.iter_mut()) {
        if !*mask {
            *logit = f32::NEG_INFINITY;
        }
    }
    
    Ok(())
}
```

**Performance**: ~50μs/token for constraint application

---

## Memory Management

### Allocator Strategy

Ananke uses explicit allocator passing throughout:

```zig
// Good: Explicit allocator parameter
pub fn extractConstraints(allocator: std.mem.Allocator, source: []const u8) !ConstraintSet

// Bad: Hidden global allocator
pub fn extractConstraints(source: []const u8) !ConstraintSet
```

### Arena Allocation Pattern

For temporary allocations during processing:

```zig
var arena = std.heap.ArenaAllocator.init(allocator);
defer arena.deinit();

const temp_allocator = arena.allocator();
const parsed = try parseConstraints(temp_allocator, source);
// All temp_allocator allocations freed at arena.deinit()
```

### Ownership Semantics

```zig
// Return value is caller-owned (must deinit/free)
pub fn extractConstraints(...) !ConstraintSet {
    var constraints = try ConstraintSet.init(allocator);
    // Caller must call constraints.deinit()
    return constraints;
}

// Slice parameters are borrowed (not owned)
pub fn compile(constraints: []const Constraint) !ConstraintIR {
    // Don't free constraints parameter
}
```

### Error Path Cleanup

```zig
pub fn compileConstraints(allocator: std.mem.Allocator, constraints: []const Constraint) !ConstraintIR {
    var graph = try allocator.alloc(Node, constraints.len);
    errdefer allocator.free(graph);  // Freed if function returns error
    
    var ir = try buildIR(allocator, graph);
    errdefer ir.deinit(allocator);
    
    return ir;
}
```

---

## Concurrency Model

### Single-Threaded Processing

Default mode: All operations are single-threaded.

```zig
// Typical usage
var ananke = try Ananke.init(allocator);
defer ananke.deinit();

var constraints = try ananke.extract(source, "typescript");
var ir = try ananke.compile(constraints.constraints.items);
```

### Thread-Safe Wrapper (Planned v0.2)

```zig
pub const ConcurrentAnankee = struct {
    mutex: std.Thread.Mutex,
    ananke: Ananke,
    
    pub fn extractAsync(self: *ConcurrentAnanke, source: []const u8) !ConstraintSet {
        self.mutex.lock();
        defer self.mutex.unlock();
        return try self.ananke.extract(source, "typescript");
    }
};
```

### Modal Concurrency

Python/Rust layer handles parallel inference requests:

```rust
pub async fn generate_parallel(prompts: Vec<String>, constraints: &ConstraintIR) -> Result<Vec<String>> {
    let futures = prompts.iter().map(|prompt| {
        self.generate_one(prompt, constraints)
    });
    
    let results = futures::future::join_all(futures).await;
    Ok(results)
}
```

---

## Testing Strategy

### Unit Testing

Tests co-located with implementation:

```zig
// In clew.zig or clew_test.zig
test "extract constraints from typescript" {
    const allocator = std.testing.allocator;
    const source = "function add(a: number, b: number): number { return a + b; }";
    
    var clew = try Clew.init(allocator);
    defer clew.deinit();
    
    var constraints = try clew.extractFromCode(source, "typescript");
    defer constraints.deinit();
    
    try std.testing.expect(constraints.constraints.items.len > 0);
}
```

### Integration Testing

Multi-component tests:

```zig
test "full pipeline: extract -> compile -> validate" {
    const allocator = std.testing.allocator;
    const source = @embedFile("test/fixtures/sample.ts");
    
    // Extract
    var clew = try Clew.init(allocator);
    defer clew.deinit();
    var constraints = try clew.extractFromCode(source, "typescript");
    defer constraints.deinit();
    
    // Compile
    var braid = try Braid.init(allocator);
    defer braid.deinit();
    var ir = try braid.compile(constraints.constraints.items);
    defer ir.deinit(allocator);
    
    // Validate IR
    try validateIR(ir);
}
```

### Test Coverage

Current status (v0.1.0):
- **Unit tests**: 154 tests
- **Integration tests**: 43 tests
- **Pass rate**: 100%
- **Execution time**: <5 seconds

---

## Performance Profiling

### Benchmarking Extraction

```zig
test "benchmark constraint extraction" {
    const source = @embedFile("bench/fixtures/large.ts");  // ~10K lines
    const start = std.time.milliTimestamp();
    
    var clew = try Clew.init(allocator);
    var constraints = try clew.extractFromCode(source, "typescript");
    defer constraints.deinit();
    
    const elapsed = std.time.milliTimestamp() - start;
    std.debug.print("Extraction: {}ms\n", .{elapsed});
}
```

### Benchmarking Compilation

```zig
test "benchmark constraint compilation" {
    const constraints = generateTestConstraints(allocator, 100);
    defer allocator.free(constraints);
    
    const start = std.time.milliTimestamp();
    
    var braid = try Braid.init(allocator);
    var ir = try braid.compile(constraints);
    defer ir.deinit(allocator);
    
    const elapsed = std.time.milliTimestamp() - start;
    std.debug.print("Compilation (100 constraints): {}ms\n", .{elapsed});
}
```

### Cache Performance

```zig
test "benchmark cache hit rate" {
    const constraints = generateTestConstraints(allocator, 50);
    
    var braid = try Braid.init(allocator);
    defer braid.deinit();
    
    // First compilation (cache miss)
    const start1 = std.time.nanoTimestamp();
    var ir1 = try braid.compile(constraints);
    defer ir1.deinit(allocator);
    const elapsed1 = std.time.nanoTimestamp() - start1;
    
    // Second compilation (cache hit)
    const start2 = std.time.nanoTimestamp();
    var ir2 = try braid.compile(constraints);
    defer ir2.deinit(allocator);
    const elapsed2 = std.time.nanoTimestamp() - start2;
    
    std.debug.print("Cache speedup: {d:.1}x\n", .{@intToFloat(f64, elapsed1) / @intToFloat(f64, elapsed2)});
}
```

### Memory Profiling

```bash
# Valgrind memory check
valgrind --leak-check=full zig build run

# Instrument code with allocator tracking
var gpa = std.heap.GeneralPurposeAllocator(.{ .verbose_log = true }){};
var allocator = gpa.allocator();

// ... run code ...

_ = gpa.deinit();  // Reports any leaks
```

---

## Debugging Techniques

### Using Zig's Built-in Debugging

```bash
# Build with debug symbols
zig build -Doptimize=Debug

# Run with GDB
gdb ./zig-cache/bin/ananke
(gdb) b clew.zig:123
(gdb) run
(gdb) bt  # Backtrace
```

### Debug Output

```zig
// Add temporary debug prints
std.debug.print("Extracted {} constraints\n", .{constraints.len});

// Check a condition
if (constraints.len == 0) {
    std.debug.panic("No constraints extracted", .{});
}

// Trace execution
for (constraints) |constraint| {
    std.debug.print("Processing: {s}\n", .{constraint.name});
    try processConstraint(constraint);
    std.debug.print("  -> OK\n", .{});
}
```

### Assertion-Based Testing

```zig
std.debug.assert(constraints.len > 0);
std.debug.assert(ir.json_schema != null);
```

---

## Future Enhancements

### Planned v0.2

- **Tree-sitter integration**: Full AST-based extraction
- **Extended language support**: Rust, Go, C++, Java
- **Ariadne type checking**: Compile-time constraint validation
- **Incremental compilation**: Compile only changed constraints
- **Distributed caching**: Redis backend for constraint IR cache

### Research Areas

- **Formal verification**: Prove constraint sets are satisfiable
- **Constraint synthesis**: Generate constraints from examples
- **Cross-language transfer**: Reuse constraints across languages
- **Probabilistic relaxation**: Gracefully degrade constraints

---

## Contributing Guidelines

**Before modifying internals:**

1. Understand the layer (Clew/Braid/Ariadne/Maze)
2. Review existing tests for the component
3. Check CONSTRAINT.md for type changes
4. Write tests before implementation
5. Profile performance impact

**Code review checklist:**

- [ ] Tests added/updated
- [ ] Memory management verified (no leaks)
- [ ] Performance impact profiled
- [ ] Documentation updated
- [ ] All tests pass
- [ ] No compiler warnings

---

**Version**: 0.1.0  
**Last Updated**: November 2025  
**Maintainers**: Ananke Core Team
