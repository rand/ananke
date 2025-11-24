# Ananke Zig API Reference

Complete API reference for Ananke's Zig components (Clew and Braid).

**Version**: 0.1.0  
**Generated**: November 24, 2025  
**Zig Version**: 0.15.1

---

## Table of Contents

- [Quick Start](#quick-start)
- [Core API](#core-api)
- [Clew API (Constraint Extraction)](#clew-api-constraint-extraction)
- [Braid API (Constraint Compilation)](#braid-api-constraint-compilation)
- [Type System](#type-system)
- [FFI Integration](#ffi-integration)
- [Usage Patterns](#usage-patterns)
- [Error Handling](#error-handling)
- [Performance Considerations](#performance-considerations)

---

## Quick Start

```zig
const ananke = @import("ananke");
const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Initialize Ananke
    var ananke_instance = try ananke.Ananke.init(allocator);
    defer ananke_instance.deinit();
    
    // Extract constraints from source code
    const source = "function add(a, b) { return a + b; }";
    var constraints = try ananke_instance.extract(source, "typescript");
    defer constraints.deinit();
    
    // Compile constraints to IR
    var ir = try ananke_instance.compile(constraints.constraints.items);
    defer ir.deinit(allocator);
    
    std.debug.print("Extracted {} constraints\n", .{constraints.constraints.items.len});
}
```

---

## Core API

### ananke.Ananke

Main entry point for the Ananke system. Coordinates Clew and Braid engines.

#### Methods

##### `init(allocator: std.mem.Allocator) !Ananke`

Creates a new Ananke instance with all engines initialized.

**Parameters**:
- `allocator`: Memory allocator for the instance

**Returns**: Ananke instance or error

**Errors**:
- `OutOfMemory`: Failed to allocate memory for engines

**Example**:
```zig
var ananke = try ananke.Ananke.init(std.heap.page_allocator);
defer ananke.deinit();
```

**Performance**: Initializes three engines (Clew, Braid, Ariadne). Takes ~1ms on modern hardware.

---

##### `deinit(self: *Ananke) void`

Cleans up all resources used by the Ananke instance.

**Must be called** when done with the instance to prevent memory leaks.

**Example**:
```zig
defer ananke.deinit(); // Always use defer for cleanup
```

**Safety**: Safe to call multiple times (idempotent).

---

##### `extract(self: *Ananke, source: []const u8, language: []const u8) !ConstraintSet`

Extracts constraints from source code using pattern matching and optional LLM analysis.

**Parameters**:
- `source`: Source code to analyze (UTF-8 encoded)
- `language`: Programming language identifier

**Supported Languages**:
- `"typescript"` - TypeScript/JavaScript
- `"python"` - Python
- `"rust"` - Rust
- `"zig"` - Zig
- `"go"` - Go

**Returns**: ConstraintSet with extracted constraints

**Errors**:
- `OutOfMemory`: Failed to allocate memory
- `InvalidLanguage`: Unsupported language
- `ParseError`: Failed to parse source code

**Performance**: 4-7ms for ~75 lines of code (pattern-based). Add 200-500ms if using Claude.

**Example**:
```zig
const source = 
    \\export function calculatePrice(items: Item[]): number {
    \\    return items.reduce((sum, item) => sum + item.price, 0);
    \\}
;

var constraints = try instance.extract(source, "typescript");
defer constraints.deinit();

std.debug.print("Found {} constraints\n", .{constraints.constraints.items.len});
```

**Constraint Types Extracted**:
- Syntactic: Functions, classes, control structures
- Type Safety: Type annotations, null checks
- Semantic: Error handling, async patterns
- Security: Input validation patterns

---

##### `compile(self: *Ananke, constraints: []const Constraint) !ConstraintIR`

Compiles constraints into an intermediate representation for efficient validation.

**Parameters**:
- `constraints`: Array of constraints to compile

**Returns**: ConstraintIR with optimized constraint representation

**Errors**:
- `OutOfMemory`: Failed to allocate memory
- `CompilationFailed`: Constraint conflict could not be resolved

**Performance**: ~10ms for 50 constraints (dependency analysis + optimization).

**Example**:
```zig
var ir = try instance.compile(constraint_set.constraints.items);
defer ir.deinit(allocator);

if (ir.json_schema) |schema| {
    std.debug.print("JSON Schema: {s}\n", .{schema.type});
}

if (ir.grammar) |grammar| {
    std.debug.print("Grammar rules: {d}\n", .{grammar.rules.len});
}
```

**Compilation Steps**:
1. Build constraint dependency graph
2. Detect and resolve conflicts
3. Optimize evaluation order (topological sort)
4. Generate JSON schema, grammar, regex, and token masks

---

##### `compileAriadne(self: *Ananke, source: []const u8) !ConstraintIR`

Compiles Ariadne DSL source to ConstraintIR.

**Parameters**:
- `source`: Ariadne DSL source code

**Returns**: ConstraintIR compiled from DSL

**Errors**:
- `AriadneNotAvailable`: Ariadne engine not initialized
- `OutOfMemory`: Memory allocation failure
- `ParseError`: Invalid Ariadne syntax

**Example**:
```zig
const ariadne_source = 
    \\constraint secure_api {
    \\    requires: authentication;
    \\    forbid: ["eval", "exec"];
    \\}
;

var ir = try instance.compileAriadne(ariadne_source);
defer ir.deinit(allocator);
```

---

## Clew API (Constraint Extraction)

### clew.Clew

Low-level constraint extraction engine. Use directly for fine-grained control.

#### Methods

##### `init(allocator: std.mem.Allocator) !Clew`

Creates a new Clew extraction engine.

**Parameters**:
- `allocator`: Memory allocator

**Returns**: Clew instance or error

**Example**:
```zig
var clew = try clew.Clew.init(allocator);
defer clew.deinit();
```

---

##### `deinit(self: *Clew) void`

Frees all resources, including the internal arena allocator.

**Example**:
```zig
defer clew.deinit();
```

---

##### `setClaudeClient(self: *Clew, client: *claude_api.ClaudeClient) void`

Enables semantic analysis using Claude for deeper constraint extraction.

**Parameters**:
- `client`: Initialized Claude API client

**Example**:
```zig
var claude_client = try claude_api.ClaudeClient.init(allocator, api_key);
defer claude_client.deinit();

clew.setClaudeClient(&claude_client);
```

**Performance Impact**: Adds 200-500ms per extraction call due to API roundtrip.

---

##### `extractFromCode(self: *Clew, source: []const u8, language: []const u8) !ConstraintSet`

Extracts constraints from source code using pattern matching and optional LLM analysis.

**Parameters**:
- `source`: Source code string
- `language`: Programming language

**Returns**: ConstraintSet with extracted constraints

**Extraction Strategy**:
1. Pattern-based syntactic analysis (always)
2. Type system analysis (always)
3. Claude semantic analysis (if client set)

**Example**:
```zig
var constraint_set = try clew.extractFromCode(source, "typescript");
defer constraint_set.deinit();

for (constraint_set.constraints.items) |constraint| {
    std.debug.print("{s}: {s}\n", .{constraint.name, constraint.description});
}
```

---

##### `extractFromTests(self: *Clew, test_source: []const u8) !ConstraintSet`

Extracts constraints from test code by analyzing assertions and test structure.

**Parameters**:
- `test_source`: Test file source code

**Returns**: ConstraintSet with test-derived constraints

**Example**:
```zig
const test_code = 
    \\test "validates email" {
    \\    try std.testing.expect(isValidEmail("test@example.com"));
    \\}
;

var constraints = try clew.extractFromTests(test_code);
defer constraints.deinit();
```

**Extracted Information**:
- Invariants from assertions
- Input validation patterns
- Expected behaviors
- Error conditions

---

##### `extractFromTelemetry(self: *Clew, telemetry: Telemetry) !ConstraintSet`

Extracts operational constraints from production telemetry data.

**Parameters**:
- `telemetry`: Telemetry data structure

**Returns**: ConstraintSet with operational constraints

**Example**:
```zig
const telemetry = clew.Telemetry{
    .latency_p99 = 150.0,  // ms
    .error_rate = 0.02,    // 2%
    .memory_usage = 1024 * 1024 * 512, // 512 MB
};

var constraints = try clew.extractFromTelemetry(telemetry);
defer constraints.deinit();
```

**Generated Constraints**:
- Latency bounds (if P99 > 100ms)
- Error rate limits (if > 1%)
- Memory limits
- CPU usage constraints

---

### clew.Telemetry

Telemetry data structure for operational constraint extraction.

```zig
pub const Telemetry = struct {
    latency_p50: ?f64 = null,
    latency_p99: ?f64 = null,
    error_rate: ?f64 = null,
    memory_usage: ?u64 = null,
    cpu_usage: ?f64 = null,
};
```

**Fields**:
- `latency_p50`: 50th percentile latency in milliseconds
- `latency_p99`: 99th percentile latency in milliseconds
- `error_rate`: Error rate as fraction (0.01 = 1%)
- `memory_usage`: Memory usage in bytes
- `cpu_usage`: CPU usage as fraction (0.5 = 50%)

---

## Braid API (Constraint Compilation)

### braid.Braid

Constraint compilation engine. Converts constraints to optimized IR.

#### Methods

##### `init(allocator: std.mem.Allocator) !Braid`

Creates a new Braid compilation engine.

**Parameters**:
- `allocator`: Memory allocator

**Returns**: Braid instance or error

**Example**:
```zig
var braid = try braid.Braid.init(allocator);
defer braid.deinit();
```

---

##### `deinit(self: *Braid) void`

Frees all resources including the IR cache.

**Example**:
```zig
defer braid.deinit();
```

---

##### `setClaudeClient(self: *Braid, client: *claude_api.ClaudeClient) void`

Enables LLM-assisted conflict resolution for complex constraint conflicts.

**Parameters**:
- `client`: Initialized Claude API client

**Example**:
```zig
braid.setClaudeClient(&claude_client);
```

---

##### `compile(self: *Braid, constraints: []const Constraint) !ConstraintIR`

Compiles constraints into optimized ConstraintIR.

**Parameters**:
- `constraints`: Array of constraints to compile

**Returns**: ConstraintIR structure

**Compilation Pipeline**:
1. Build dependency graph (O(n²) worst case, typically O(n log n))
2. Detect conflicts (optimized to O(n log n) via grouping)
3. Resolve conflicts (heuristic or LLM-based)
4. Optimize evaluation order (topological sort)
5. Generate IR (JSON schema, grammar, regex, masks)

**Example**:
```zig
var ir = try braid.compile(constraints);
defer ir.deinit(allocator);

// Access compiled components
if (ir.json_schema) |schema| {
    std.debug.print("Type: {s}\n", .{schema.type});
}

for (ir.regex_patterns) |pattern| {
    std.debug.print("Pattern: {s}\n", .{pattern.pattern});
}
```

**Performance**: 5-15ms for typical constraint sets (<100 constraints).

---

##### `toLLGuidanceSchema(self: *Braid, ir: ConstraintIR) ![]const u8`

Converts ConstraintIR to llguidance-compatible JSON format.

**Parameters**:
- `ir`: Compiled ConstraintIR

**Returns**: JSON string for llguidance (caller must free)

**Example**:
```zig
const json = try braid.toLLGuidanceSchema(ir);
defer allocator.free(json);

std.debug.print("{s}\n", .{json});
```

**Output Format**:
```json
{
  "type": "guidance",
  "version": "1.0",
  "json_schema": {...},
  "grammar": {...},
  "patterns": ["...", "..."],
  "token_masks": {...},
  "priority": 100
}
```

---

### braid.ConstraintGraph

Constraint dependency graph for compilation.

#### Methods

##### `init(allocator: std.mem.Allocator) ConstraintGraph`

Creates an empty constraint graph.

---

##### `deinit(self: *ConstraintGraph) void`

Frees graph resources.

---

##### `addNode(self: *ConstraintGraph, constraint: Constraint) !usize`

Adds a constraint as a node in the graph.

**Returns**: Node index

---

##### `addEdge(self: *ConstraintGraph, from: usize, to: usize) !void`

Adds a dependency edge from one constraint to another.

---

##### `topologicalSort(self: *ConstraintGraph) ![]usize`

Performs topological sort using Kahn's algorithm.

**Returns**: Array of node indices in execution order (caller must free)

**Handles**: Cyclic dependencies (warns and returns partial order)

---

##### `detectCycle(self: *ConstraintGraph) !bool`

Detects cycles in the dependency graph using DFS.

**Returns**: true if cycle detected

---

##### `getMaxPriority(self: *const ConstraintGraph) u32`

Returns the highest priority value in the graph.

---

### Utility Functions

##### `braid.buildTokenMasks(allocator: std.mem.Allocator, constraints: []const Constraint) ![]TokenMaskRule`

Builds token mask rules from security and operational constraints.

**Parameters**:
- `allocator`: Memory allocator
- `constraints`: Constraints to analyze

**Returns**: Array of token mask rules (caller must free)

**Pattern Detection**:
- Credentials: Blocks "password", "api_key", "token", "secret"
- URLs: Blocks "http://", "https://"
- File paths: Blocks "/path/", "C:\"
- SQL injection: Blocks "DROP", "DELETE", "INSERT", "UPDATE"
- Code execution: Blocks "eval", "exec", "system("

**Example**:
```zig
const rules = try braid.buildTokenMasks(allocator, security_constraints);
defer allocator.free(rules);

for (rules) |rule| {
    std.debug.print("Block: {s} - {s}\n", .{rule.pattern, rule.description});
}
```

---

##### `braid.buildGrammarFromConstraints(allocator: std.mem.Allocator, constraints: []const Constraint) !Grammar`

Builds a context-free grammar from syntactic constraints.

**Parameters**:
- `allocator`: Memory allocator
- `constraints`: Syntactic constraints

**Returns**: Grammar structure (caller must free)

**Example**:
```zig
const grammar = try braid.buildGrammarFromConstraints(allocator, syntax_constraints);
defer {
    for (grammar.rules) |rule| {
        allocator.free(rule.lhs);
        for (rule.rhs) |item| allocator.free(item);
        allocator.free(rule.rhs);
    }
    allocator.free(grammar.rules);
}
```

---

##### `braid.buildRegexPattern(allocator: std.mem.Allocator, constraints: []const Constraint) !?[]const u8`

Extracts and combines regex patterns from constraint descriptions.

**Returns**: Combined regex pattern or null if none found (caller must free)

**Example**:
```zig
if (try braid.buildRegexPattern(allocator, constraints)) |pattern| {
    defer allocator.free(pattern);
    std.debug.print("Pattern: {s}\n", .{pattern});
}
```

---

##### `braid.mergeConstraints(allocator: std.mem.Allocator, set1: ConstraintSet, set2: ConstraintSet) !ConstraintSet`

Merges two constraint sets into a new combined set.

**Parameters**:
- `allocator`: Memory allocator
- `set1`: First constraint set
- `set2`: Second constraint set

**Returns**: Merged ConstraintSet (caller must call deinit)

**Example**:
```zig
var merged = try braid.mergeConstraints(allocator, syntax_constraints, type_constraints);
defer merged.deinit();
```

---

##### `braid.deduplicateConstraints(allocator: std.mem.Allocator, constraints: []const Constraint) ![]Constraint`

Removes duplicate constraints based on kind, description, and source.

**Returns**: Deduplicated array (caller must free)

**Example**:
```zig
const unique = try braid.deduplicateConstraints(allocator, all_constraints);
defer allocator.free(unique);
```

---

##### `braid.updatePriority(constraint: *Constraint, new_priority: ConstraintPriority) void`

Updates a constraint's priority for conflict resolution.

**Example**:
```zig
braid.updatePriority(&my_constraint, .Critical);
```

---

## Type System

### ananke.Constraint

Core constraint type representing a single validation rule.

```zig
pub const Constraint = struct {
    id: ConstraintID = 0,
    name: []const u8,
    description: []const u8,
    kind: ConstraintKind,
    source: ConstraintSource = .AST_Pattern,
    enforcement: EnforcementType = .Syntactic,
    priority: ConstraintPriority = .Medium,
    confidence: f32 = 1.0,
    frequency: u32 = 1,
    severity: Severity,
    origin_file: ?[]const u8 = null,
    origin_line: ?u32 = null,
    created_at: i64 = 0,
    validate: ?*const fn (token: []const u8) bool = null,
    compile_fn: ?*const fn (self: *const Constraint) ConstraintIR = null,
};
```

**Fields**:
- `id`: Unique identifier (auto-generated)
- `name`: Human-readable constraint name
- `description`: Detailed description
- `kind`: Category (syntactic, type_safety, semantic, etc.)
- `source`: Origin (AST_Pattern, Type_System, LLM_Analysis, etc.)
- `enforcement`: How enforced (Syntactic, Structural, Semantic, etc.)
- `priority`: Conflict resolution priority (Low, Medium, High, Critical)
- `confidence`: Confidence level (0.0-1.0)
- `frequency`: Occurrence count in codebase
- `severity`: Violation severity (err, warning, info, hint)
- `origin_file`: Source file (if applicable)
- `origin_line`: Source line number (if applicable)
- `created_at`: Unix timestamp
- `validate`: Optional validation function pointer
- `compile_fn`: Optional custom compilation function

#### Methods

##### `init(id: ConstraintID, name: []const u8, description: []const u8) Constraint`

Creates a new constraint with required fields.

**Example**:
```zig
const constraint = Constraint.init(1, "no_eval", "Avoid eval() usage");
```

---

##### `isValid(self: *const Constraint) bool`

Validates constraint internal consistency.

**Checks**:
- Confidence in range [0.0, 1.0]
- Name not empty
- Enforcement matches kind

**Example**:
```zig
if (!constraint.isValid()) {
    std.debug.print("Invalid constraint!\n", .{});
}
```

---

##### `getPriorityValue(self: *const Constraint) u32`

Returns numeric priority for sorting.

**Returns**: 0 (Low), 1 (Medium), 2 (High), 3 (Critical)

---

### ananke.ConstraintKind

Categories of constraints.

```zig
pub const ConstraintKind = enum {
    syntactic,      // Code structure, formatting, naming
    type_safety,    // Type annotations, null safety
    semantic,       // Data flow, control flow, side effects
    architectural,  // Module boundaries, dependencies
    operational,    // Performance, memory, concurrency
    security,       // Input validation, auth, dangerous ops
};
```

---

### ananke.ConstraintSource

Source from which constraint was extracted.

```zig
pub const ConstraintSource = enum {
    AST_Pattern,    // From AST analysis
    Type_System,    // From type annotations
    Control_Flow,   // From control flow analysis
    Data_Flow,      // From data flow analysis
    Test_Mining,    // From test code
    Documentation,  // From docs/comments
    Telemetry,      // From runtime metrics
    User_Defined,   // Manually specified
    LLM_Analysis,   // From LLM analysis
};
```

---

### ananke.ConstraintPriority

Priority levels for conflict resolution.

```zig
pub const ConstraintPriority = enum {
    Low,
    Medium,
    High,
    Critical,
    
    pub fn toNumeric(self: ConstraintPriority) u32;
};
```

---

### ananke.Severity

Severity levels for violations.

```zig
pub const Severity = enum {
    err,      // Must be fixed
    warning,  // Should be addressed
    info,     // Informational
    hint,     // Suggestion
};
```

---

### ananke.EnforcementType

How constraints are enforced.

```zig
pub const EnforcementType = enum {
    Syntactic,    // At syntax level
    Structural,   // At structure level
    Semantic,     // At semantic level
    Performance,  // For performance requirements
    Security,     // For security requirements
};
```

---

### ananke.ConstraintSet

Collection of constraints with metadata.

```zig
pub const ConstraintSet = struct {
    constraints: std.ArrayList(Constraint),
    name: []const u8,
    allocator: std.mem.Allocator,
};
```

#### Methods

##### `init(allocator: std.mem.Allocator, name: []const u8) ConstraintSet`

Creates a new empty constraint set.

---

##### `deinit(self: *ConstraintSet) void`

Frees the constraint array.

Note: Does not free individual constraint string fields. Use arena allocator for constraint strings.

---

##### `add(self: *ConstraintSet, constraint: Constraint) !void`

Adds a constraint to the set.

---

### ananke.ConstraintIR

Compiled intermediate representation.

```zig
pub const ConstraintIR = struct {
    json_schema: ?JsonSchema = null,
    grammar: ?Grammar = null,
    regex_patterns: []const Regex = &.{},
    token_masks: ?TokenMaskRules = null,
    priority: u32 = 0,
};
```

**Fields**:
- `json_schema`: JSON Schema for structured data
- `grammar`: Context-free grammar for syntax
- `regex_patterns`: Array of regex patterns
- `token_masks`: Token-level masking rules
- `priority`: Overall priority for llguidance

#### Methods

##### `deinit(self: *ConstraintIR, allocator: std.mem.Allocator) void`

Frees all allocated memory in the IR.

**Must call** to prevent memory leaks.

---

### ananke.JsonSchema

JSON Schema representation.

```zig
pub const JsonSchema = struct {
    type: []const u8,
    properties: ?std.json.ObjectMap = null,
    required: []const []const u8 = &.{},
    additional_properties: bool = true,
};
```

---

### ananke.Grammar

Context-free grammar.

```zig
pub const Grammar = struct {
    rules: []const GrammarRule,
    start_symbol: []const u8,
};

pub const GrammarRule = struct {
    lhs: []const u8,
    rhs: []const []const u8,
};
```

**Example**:
```zig
// Grammar rule: expression -> identifier | literal | function_call
const rule = GrammarRule{
    .lhs = "expression",
    .rhs = &.{"identifier", "literal", "function_call"},
};
```

---

### ananke.Regex

Regular expression pattern.

```zig
pub const Regex = struct {
    pattern: []const u8,
    flags: []const u8 = "",
};
```

---

### ananke.TokenMaskRules

Token-level masking for llguidance.

```zig
pub const TokenMaskRules = struct {
    allowed_tokens: ?[]const u32 = null,
    forbidden_tokens: ?[]const u32 = null,
    
    pub fn apply(self: TokenMaskRules, logits: []f32) void;
};
```

#### Methods

##### `apply(self: TokenMaskRules, logits: []f32) void`

Applies token masks to logit array.

Sets forbidden tokens to -inf and optionally restricts to allowed tokens.

---

### ananke.TokenMaskRule

Individual token mask rule.

```zig
pub const TokenMaskRule = struct {
    mask_type: MaskType,
    pattern: []const u8,
    description: []const u8,
    
    pub const MaskType = enum {
        allow_tokens,
        deny_tokens,
        require_tokens,
    };
};
```

---

## FFI Integration

### zig_ffi API

C-compatible FFI for Rust integration.

#### Functions

##### `ananke_init() callconv(.c) c_int`

Initializes the Ananke system.

**Returns**: 0 on success, error code otherwise

**Must call** before using other FFI functions.

---

##### `ananke_deinit() callconv(.c) void`

Cleans up the Ananke system.

**Call** when done using Ananke.

---

##### `ananke_extract_constraints(source: [*:0]const u8, language: [*:0]const u8, out_ir: *?*ConstraintIRFFI) callconv(.c) c_int`

Extracts constraints from source code.

**Parameters**:
- `source`: Null-terminated source code string
- `language`: Null-terminated language identifier
- `out_ir`: Output pointer for ConstraintIR (allocated by function)

**Returns**: 0 on success, error code otherwise

**Safety**: Caller must free with `ananke_free_constraint_ir`

**Example** (from Rust):
```rust
let source = CString::new("function test() {}").unwrap();
let language = CString::new("typescript").unwrap();
let mut ir_ptr: *mut ConstraintIRFFI = std::ptr::null_mut();

let result = ananke_extract_constraints(
    source.as_ptr(),
    language.as_ptr(),
    &mut ir_ptr as *mut _,
);

if result == 0 {
    // Use ir_ptr
    ananke_free_constraint_ir(ir_ptr);
}
```

---

##### `ananke_compile_constraints(constraints: [*:0]const u8, out_ir: *?*ConstraintIRFFI) callconv(.c) c_int`

Compiles constraints to ConstraintIR.

**Parameters**:
- `constraints`: JSON-formatted constraint array
- `out_ir`: Output pointer for ConstraintIR

**Returns**: 0 on success, error code otherwise

---

##### `ananke_free_constraint_ir(ir: ?*ConstraintIRFFI) callconv(.c) void`

Frees a ConstraintIR structure.

**Safety**: Must call exactly once on each ConstraintIR from FFI functions.

---

##### `ananke_version() callconv(.c) [*:0]const u8`

Returns version information string.

**Returns**: Null-terminated version string (do not free)

---

### ConstraintIRFFI

C-compatible ConstraintIR structure.

```zig
pub const ConstraintIRFFI = extern struct {
    json_schema: ?[*:0]const u8,
    grammar: ?[*:0]const u8,
    regex_patterns: ?[*]const [*:0]const u8,
    regex_patterns_len: usize,
    token_masks: ?*anyopaque,
    priority: u32,
    name: ?[*:0]const u8,
};
```

**Memory Layout**: Matches C ABI for FFI safety.

---

### AnankeError

C-compatible error codes.

```zig
pub const AnankeError = enum(c_int) {
    Success = 0,
    NullPointer = 1,
    AllocationFailure = 2,
    InvalidInput = 3,
    ExtractionFailed = 4,
    CompilationFailed = 5,
};
```

---

## Usage Patterns

### Basic Extraction

Extract constraints from a single source file:

```zig
const std = @import("std");
const ananke = @import("ananke");

pub fn extractFromFile(allocator: std.mem.Allocator, path: []const u8) !void {
    // Read file
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    
    const source = try file.readToEndAlloc(allocator, 10 * 1024 * 1024);
    defer allocator.free(source);
    
    // Detect language from extension
    const language = if (std.mem.endsWith(u8, path, ".ts")) 
        "typescript" 
    else if (std.mem.endsWith(u8, path, ".py")) 
        "python" 
    else 
        "unknown";
    
    // Extract constraints
    var clew = try ananke.clew.Clew.init(allocator);
    defer clew.deinit();
    
    var constraint_set = try clew.extractFromCode(source, language);
    defer constraint_set.deinit();
    
    // Print results
    std.debug.print("Extracted {} constraints from {s}\n", 
        .{constraint_set.constraints.items.len, path});
    
    for (constraint_set.constraints.items) |constraint| {
        std.debug.print("  - {s} ({s}): {s}\n", 
            .{constraint.name, @tagName(constraint.kind), constraint.description});
    }
}
```

---

### Full Pipeline

Complete workflow from extraction to compilation:

```zig
const std = @import("std");
const ananke = @import("ananke");

pub fn fullPipeline(allocator: std.mem.Allocator) !void {
    // Initialize Ananke
    var ananke_instance = try ananke.Ananke.init(allocator);
    defer ananke_instance.deinit();
    
    // Source code to analyze
    const source = 
        \\export async function validateUser(email: string): Promise<boolean> {
        \\    if (!email || !email.includes('@')) {
        \\        throw new Error('Invalid email');
        \\    }
        \\    return await database.checkUser(email);
        \\}
    ;
    
    // Step 1: Extract constraints
    std.debug.print("Extracting constraints...\n", .{});
    var constraints = try ananke_instance.extract(source, "typescript");
    defer constraints.deinit();
    
    std.debug.print("Found {} constraints\n", .{constraints.constraints.items.len});
    
    // Step 2: Compile to IR
    std.debug.print("Compiling constraints...\n", .{});
    var ir = try ananke_instance.compile(constraints.constraints.items);
    defer ir.deinit(allocator);
    
    // Step 3: Inspect compiled IR
    if (ir.json_schema) |schema| {
        std.debug.print("JSON Schema type: {s}\n", .{schema.type});
    }
    
    if (ir.grammar) |grammar| {
        std.debug.print("Grammar rules: {d}\n", .{grammar.rules.len});
        std.debug.print("Start symbol: {s}\n", .{grammar.start_symbol});
    }
    
    std.debug.print("Regex patterns: {d}\n", .{ir.regex_patterns.len});
    for (ir.regex_patterns) |pattern| {
        std.debug.print("  - {s}\n", .{pattern.pattern});
    }
    
    // Step 4: Convert to llguidance format
    const braid = &ananke_instance.braid_engine;
    const llguidance_json = try braid.toLLGuidanceSchema(ir);
    defer allocator.free(llguidance_json);
    
    std.debug.print("\nllguidance schema:\n{s}\n", .{llguidance_json});
}
```

---

### With Claude Integration

Use Claude for semantic analysis:

```zig
const std = @import("std");
const ananke = @import("ananke");
const claude_api = @import("claude");

pub fn withClaude(allocator: std.mem.Allocator, api_key: []const u8) !void {
    // Initialize Claude client
    var claude_client = try claude_api.ClaudeClient.init(allocator, api_key);
    defer claude_client.deinit();
    
    // Initialize Clew with Claude
    var clew = try ananke.clew.Clew.init(allocator);
    defer clew.deinit();
    clew.setClaudeClient(&claude_client);
    
    // Extract with semantic analysis
    const source = 
        \\def process_payment(amount, user_id):
        \\    if amount <= 0:
        \\        raise ValueError("Invalid amount")
        \\    
        \\    user = get_user(user_id)
        \\    if not user.is_verified:
        \\        raise PermissionError("User not verified")
        \\    
        \\    return charge_card(user.card, amount)
    ;
    
    var constraint_set = try clew.extractFromCode(source, "python");
    defer constraint_set.deinit();
    
    // Claude will identify semantic constraints like:
    // - Input validation (amount > 0)
    // - Authorization check (user verification)
    // - Error handling patterns
    
    for (constraint_set.constraints.items) |constraint| {
        if (constraint.source == .LLM_Analysis) {
            std.debug.print("Claude found: {s} (confidence: {d:.2})\n", 
                .{constraint.description, constraint.confidence});
        }
    }
}
```

---

### Constraint Merging

Merge constraints from multiple sources:

```zig
const std = @import("std");
const ananke = @import("ananke");

pub fn mergeMultipleSources(allocator: std.mem.Allocator) !void {
    var clew = try ananke.clew.Clew.init(allocator);
    defer clew.deinit();
    
    // Extract from source code
    const source = "function add(a, b) { return a + b; }";
    var source_constraints = try clew.extractFromCode(source, "typescript");
    defer source_constraints.deinit();
    
    // Extract from tests
    const tests = "test('adds numbers', () => { expect(add(1, 2)).toBe(3); });";
    var test_constraints = try clew.extractFromTests(tests);
    defer test_constraints.deinit();
    
    // Extract from telemetry
    const telemetry = ananke.clew.Telemetry{
        .latency_p99 = 50.0,
        .error_rate = 0.001,
    };
    var telemetry_constraints = try clew.extractFromTelemetry(telemetry);
    defer telemetry_constraints.deinit();
    
    // Merge all constraints
    const braid_module = @import("braid");
    var merged = try braid_module.mergeConstraints(allocator, source_constraints, test_constraints);
    defer merged.deinit();
    
    merged = try braid_module.mergeConstraints(allocator, merged, telemetry_constraints);
    
    // Deduplicate
    const unique = try braid_module.deduplicateConstraints(allocator, merged.constraints.items);
    defer allocator.free(unique);
    
    std.debug.print("Total unique constraints: {d}\n", .{unique.len});
}
```

---

### Custom Pattern Matching

Add custom constraint patterns:

```zig
const std = @import("std");
const ananke = @import("ananke");

pub fn customPatterns(allocator: std.mem.Allocator) !void {
    // Create custom constraints
    var constraints = std.ArrayList(ananke.Constraint){};
    defer constraints.deinit(allocator);
    
    try constraints.append(allocator, ananke.Constraint{
        .id = 1,
        .name = "no_console_log",
        .description = "Avoid console.log in production code",
        .kind = .syntactic,
        .source = .User_Defined,
        .severity = .warning,
        .confidence = 1.0,
    });
    
    try constraints.append(allocator, ananke.Constraint{
        .id = 2,
        .name = "require_error_handling",
        .description = "All async functions must have try/catch",
        .kind = .semantic,
        .source = .User_Defined,
        .severity = .err,
        .priority = .High,
        .confidence = 1.0,
    });
    
    // Compile custom constraints
    var braid = try ananke.braid.Braid.init(allocator);
    defer braid.deinit();
    
    var ir = try braid.compile(constraints.items);
    defer ir.deinit(allocator);
    
    std.debug.print("Compiled {d} custom constraints\n", .{constraints.items.len});
}
```

---

### Ariadne DSL

Use the Ariadne DSL for high-level constraint definition:

```zig
const std = @import("std");
const ananke = @import("ananke");

pub fn ariadneExample(allocator: std.mem.Allocator) !void {
    var ananke_instance = try ananke.Ananke.init(allocator);
    defer ananke_instance.deinit();
    
    const ariadne_source = 
        \\constraint secure_api {
        \\    kind: security;
        \\    priority: critical;
        \\    
        \\    requires: [authentication, input_validation];
        \\    
        \\    forbid: [
        \\        "eval",
        \\        "exec",
        \\        "system",
        \\        "__import__"
        \\    ];
        \\    
        \\    validate: {
        \\        max_complexity: 15;
        \\        min_test_coverage: 0.8;
        \\    }
        \\    
        \\    patterns: {
        \\        email: "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$";
        \\        uuid: "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$";
        \\    }
        \\}
    ;
    
    var ir = try ananke_instance.compileAriadne(ariadne_source);
    defer ir.deinit(allocator);
    
    std.debug.print("Compiled Ariadne constraint set\n", .{});
}
```

---

## Error Handling

### Error Types

Common error types and how to handle them:

```zig
const AnankeError = error{
    OutOfMemory,
    InvalidLanguage,
    ParseError,
    ExtractionFailed,
    CompilationFailed,
    AriadneNotAvailable,
    NotImplemented,
};
```

### Error Handling Patterns

#### Basic Error Handling

```zig
var instance = ananke.Ananke.init(allocator) catch |err| {
    std.debug.print("Failed to initialize: {}\n", .{err});
    return err;
};
defer instance.deinit();
```

#### Specific Error Handling

```zig
var constraints = instance.extract(source, "typescript") catch |err| switch (err) {
    error.OutOfMemory => {
        std.debug.print("Out of memory! Try reducing source size.\n", .{});
        return error.OutOfMemory;
    },
    error.InvalidLanguage => {
        std.debug.print("Unsupported language. Try: typescript, python, rust, zig, go\n", .{});
        return error.InvalidLanguage;
    },
    error.ParseError => {
        std.debug.print("Failed to parse source. Check syntax.\n", .{});
        return error.ParseError;
    },
    else => return err,
};
defer constraints.deinit();
```

#### Graceful Degradation

```zig
// Try Claude analysis, fall back to pattern matching
var clew = try ananke.clew.Clew.init(allocator);
defer clew.deinit();

if (claude_client) |client| {
    clew.setClaudeClient(client);
}

var constraints = clew.extractFromCode(source, language) catch |err| {
    std.log.warn("Extraction failed: {}, using empty constraint set", .{err});
    ananke.ConstraintSet.init(allocator, "empty")
};
defer constraints.deinit();
```

---

## Performance Considerations

### Memory Management

#### Use Arena Allocators for Temporary Data

```zig
var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
defer arena.deinit();
const allocator = arena.allocator();

// All allocations freed at once on arena.deinit()
var constraints = try clew.extractFromCode(source, "typescript");
// No need to call constraints.deinit() - arena handles it
```

#### Reuse Engine Instances

```zig
// BAD: Creating new instances repeatedly
for (files) |file| {
    var clew = try ananke.clew.Clew.init(allocator);
    defer clew.deinit();
    var result = try clew.extractFromCode(file.source, file.language);
    defer result.deinit();
}

// GOOD: Reuse single instance
var clew = try ananke.clew.Clew.init(allocator);
defer clew.deinit();

for (files) |file| {
    var result = try clew.extractFromCode(file.source, file.language);
    defer result.deinit();
}
```

### Performance Benchmarks

Typical performance on modern hardware (M1/M2 Mac, AMD Ryzen 5000+):

**Extraction** (pattern-based):
- Small file (< 100 lines): 2-5ms
- Medium file (100-500 lines): 5-15ms
- Large file (500-2000 lines): 15-50ms

**Extraction** (with Claude):
- Add 200-500ms for API roundtrip per call

**Compilation**:
- Small set (< 10 constraints): 1-3ms
- Medium set (10-50 constraints): 3-10ms
- Large set (50-200 constraints): 10-30ms

**Optimization Tips**:
1. Use pattern-based extraction for CI/CD pipelines
2. Cache Claude results with constraint key hashing
3. Use arena allocators for batch processing
4. Profile with `zig build -Doptimize=ReleaseFast`

### Thread Safety

**Important**: Ananke instances are **NOT** thread-safe.

#### Single-Threaded Usage

```zig
var ananke_instance = try ananke.Ananke.init(allocator);
defer ananke_instance.deinit();
```

#### Multi-Threaded Usage

Create one instance per thread:

```zig
const Thread = std.Thread;

fn workerThread(allocator: std.mem.Allocator, source: []const u8) !void {
    var ananke_instance = try ananke.Ananke.init(allocator);
    defer ananke_instance.deinit();
    
    var constraints = try ananke_instance.extract(source, "typescript");
    defer constraints.deinit();
    
    // Process constraints...
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    
    const threads = try allocator.alloc(Thread, 4);
    defer allocator.free(threads);
    
    for (threads, 0..) |*thread, i| {
        thread.* = try Thread.spawn(.{}, workerThread, .{gpa.allocator(), sources[i]});
    }
    
    for (threads) |thread| {
        thread.join();
    }
}
```

### Constraint Validation Performance

ConstraintIR evaluation is optimized for token-level validation:

- **JSON Schema**: O(1) per token using precompiled validators
- **Grammar**: O(k) where k is grammar rule count
- **Regex**: O(n) where n is pattern length (cached compilation)
- **Token Masks**: O(1) direct lookup

Braid optimizes evaluation order using topological sort for minimal redundant checks.

---

## See Also

- [Rust API Reference](/Users/rand/src/ananke/docs/API_REFERENCE_RUST.md) - Maze orchestration layer
- [Ariadne DSL Guide](/Users/rand/src/ananke/docs/ariadne-grammar.md) - Constraint DSL
- [Architecture](/Users/rand/src/ananke/docs/ARCHITECTURE.md) - System design
- [User Guide](/Users/rand/src/ananke/docs/USER_GUIDE.md) - Getting started
- [Examples](/Users/rand/src/ananke/docs/api_examples/) - Working code examples

---

**API Version**: 0.1.0  
**Last Updated**: November 24, 2025  
**Zig Compiler**: 0.15.1
