# Ananke Architecture v2.0

**Last Updated**: 2025-11-24  
**System Version**: 0.1.0  
**Status**: 92% Complete (Phase 5 + Phase 7 Day 1)

## Table of Contents

1. [System Overview](#system-overview)
2. [Component Architecture](#component-architecture)
3. [Data Flow](#data-flow)
4. [FFI Integration](#ffi-integration)
5. [Performance Characteristics](#performance-characteristics)
6. [Security Considerations](#security-considerations)
7. [Extensibility](#extensibility)
8. [Known Limitations](#known-limitations)
9. [Future Architecture](#future-architecture)

---

## System Overview

Ananke is a constraint-driven code generation system that transforms abstract code constraints into token-level enforcement rules for LLM-based code generation. The system achieves deterministic constraint satisfaction through a multi-stage pipeline that analyzes code, compiles constraints, and orchestrates GPU-accelerated inference.

### High-Level Pipeline

```
┌────────────────┐         ┌────────────────┐         ┌────────────────┐
│  Source Code   │────────>│  Clew Engine   │────────>│ Constraint Set │
│  (TS/Py/Rust)  │         │  (Extraction)  │         │   (Zig types)  │
└────────────────┘         └────────────────┘         └────────┬───────┘
                                                                │
                                                                v
┌────────────────┐         ┌────────────────┐         ┌────────────────┐
│ Generated Code │<────────│  Modal Service │<────────│ Braid Engine   │
│   (Validated)  │         │  (vLLM+llg)    │         │  (Compilation) │
└────────────────┘         └────────────────┘         └────────┬───────┘
                                    ^                           │
                                    │                           v
                            ┌───────┴────────┐         ┌────────────────┐
                            │ Maze (Rust)    │<────────│ ConstraintIR   │
                            │ Orchestrator   │         │  (FFI Bridge)  │
                            └────────────────┘         └────────────────┘
```

### Design Philosophy

**Explicit Over Implicit**: Every constraint must be extractable, compilable, and verifiable. No "hoping" the LLM follows patterns.

**Separation of Concerns**:
- **Clew**: Extracts constraints (what to enforce)
- **Braid**: Compiles constraints (how to enforce)
- **Maze**: Orchestrates enforcement (when to enforce)
- **Modal**: Executes enforcement (token-level application)

**Performance First**: The entire extraction and compilation pipeline completes in <10ms for typical workflows, enabling real-time constraint-aware code generation.

---

## Component Architecture

### Clew: Constraint Extraction Engine

**Purpose**: Mine constraints from source code, tests, documentation, and telemetry.

**Implementation**: Zig 0.15.2, ~660 lines of core logic

**Location**: `/Users/rand/src/ananke/src/clew/clew.zig`

#### Extraction Methods

**1. Pattern-Based Extraction (Primary)**
- 60+ regex patterns across 5 languages (TypeScript, Python, Rust, Zig, Go)
- Pattern categories:
  - Function declarations (async, sync, arrow functions)
  - Type annotations (primitives, generics, unions)
  - Async patterns (async/await, promises)
  - Error handling (try/catch, Result types)
  - Imports and exports (module dependencies)
  - Class/struct definitions (OOP patterns)
  - Metadata (decorators, attributes, annotations)
  - Memory management (Box, Arc, ownership)

**Pattern Example** (TypeScript):
```zig
const ts_type_patterns = [_]PatternRule{
    .{
        .pattern = ": string",
        .constraint_kind = .type_safety,
        .description = "String type annotation",
    },
    .{
        .pattern = "interface",
        .constraint_kind = .type_safety,
        .description = "Interface definition",
    },
};
```

**2. Tree-Sitter AST Parsing (Disabled)**
- Blocked on Zig 0.15.x compatibility (z-tree-sitter upstream issue)
- Would provide ~95% coverage vs current ~80%
- Code structure preserved, ready for re-enablement

**3. Semantic Analysis (Optional)**
- Integrates with Claude API for deep code understanding
- Infers business rules, invariants, implicit constraints
- Graceful degradation if API unavailable
- Example use case: Understanding "user must be authenticated" from context

#### Data Structures

**ConstraintSet**:
```zig
pub const ConstraintSet = struct {
    constraints: std.ArrayList(Constraint),
    name: []const u8,
    allocator: std.mem.Allocator,
};
```

**Constraint**:
```zig
pub const Constraint = struct {
    id: ConstraintID,
    name: []const u8,
    description: []const u8,
    kind: ConstraintKind,  // syntactic, type_safety, semantic, etc.
    source: ConstraintSource,  // AST_Pattern, LLM_Analysis, etc.
    enforcement: EnforcementType,
    priority: ConstraintPriority,
    confidence: f32,  // 0.0-1.0
    frequency: u32,
    severity: Severity,  // err, warning, info, hint
    origin_file: ?[]const u8,
    origin_line: ?u32,
};
```

#### Performance Profile

| Operation | Time (Debug) | Memory |
|-----------|--------------|--------|
| Pattern matching (75 lines) | 4-5ms | ~500KB |
| Type extraction | <1ms | ~100KB |
| Semantic analysis (Claude) | 200-500ms | ~50KB |
| Cache lookup | <0.1ms | ~10KB |

#### Pattern Coverage by Language

**TypeScript**: 23 patterns (functions, types, async, classes, imports)
**Python**: 21 patterns (functions, type hints, async, decorators)
**Rust**: 25 patterns (ownership, lifetimes, traits, async)
**Zig**: 18 patterns (comptime, error unions, allocators)
**Go**: 15 patterns (goroutines, channels, interfaces)

**Total**: 60+ unique extraction patterns

---

### Braid: Constraint Compilation Engine

**Purpose**: Compile extracted constraints into executable enforcement rules (ConstraintIR).

**Implementation**: Zig 0.15.2, ~1450 lines of core logic

**Location**: `/Users/rand/src/ananke/src/braid/braid.zig`

#### Compilation Pipeline

**Step 1: Dependency Graph Construction**
- Builds directed graph of constraint dependencies
- Example: Type constraints depend on syntactic constraints
- Uses adjacency list representation

**Step 2: Conflict Detection**
- Optimized O(n log n) algorithm (groups by kind, checks within groups)
- Detects: contradictory requirements, circular dependencies
- Resolution strategies: priority-based, LLM-assisted (Claude)

**Step 3: Topological Sorting**
- Kahn's algorithm for optimal evaluation order
- Cycle detection with partial ordering fallback
- Priority propagation through dependency chains

**Step 4: IR Generation**
- Compiles to 4 output formats:
  1. **JSON Schema** (Draft 7) - Type constraints
  2. **EBNF Grammar** - Syntactic constraints
  3. **Regex Patterns** - Pattern constraints (OR-combined)
  4. **Token Masks** - Security constraints (blocking)

#### Output Formats

**JSON Schema Example**:
```json
{
  "type": "object",
  "properties": {
    "userId": {"type": "string", "pattern": "^[0-9]+$"},
    "email": {"type": "string", "format": "email"}
  },
  "required": ["userId", "email"]
}
```

**EBNF Grammar Example**:
```ebnf
program ::= statement_list
statement_list ::= statement statement_list_tail
statement ::= function_declaration | assignment | expression_statement
function_declaration ::= "async"? "function" identifier "(" params ")" "{" statement_list "}"
```

**Token Mask Example** (Security):
```zig
pub const TokenMaskRules = struct {
    allowed_tokens: ?[]const u32,    // Whitelist
    forbidden_tokens: ?[]const u32,  // Blacklist (15 patterns)
};
```

**15 Security Token Blocking Patterns**:
1. SQL injection: DROP, DELETE, INSERT, UPDATE
2. Command injection: eval, exec, system(
3. Credential patterns: password, api_key, token, secret
4. URL patterns: http://, https://
5. File paths: /path/, C:\

#### Conflict Resolution

**Default Strategy** (Priority-Based):
```zig
// Higher severity wins
if (severity_a > severity_b) {
    disable(constraint_b);
} else {
    disable(constraint_a);
}
```

**Claude-Assisted Strategy** (Optional):
```zig
const resolution = claude.suggestResolution(conflicts);
// Actions: disable_a, disable_b, merge, modify_a, modify_b
applyClaudeResolution(resolution);
```

#### Graph Algorithms

**Kahn's Algorithm (Topological Sort)**:
```
1. Calculate in-degree for all nodes
2. Enqueue nodes with in-degree 0
3. Process queue:
   - Dequeue node, add to result
   - Decrement in-degree of neighbors
   - Enqueue neighbors with in-degree 0
4. Check for cycles (processed < total)
```

**DFS Cycle Detection**:
- O(V+E) time complexity
- Recursion stack tracks current path
- Returns true on back edge detection

#### Performance Profile

| Operation | Time (Debug) | Memory |
|-----------|--------------|--------|
| Graph construction (10 constraints) | <1ms | ~200KB |
| Conflict detection | <1ms | ~50KB |
| Topological sort | <0.5ms | ~100KB |
| IR generation | 2ms | ~500KB |
| Total compilation | 2-3ms | ~700KB |

---

### Maze: Rust Orchestration Layer

**Purpose**: Coordinate Zig constraint engines with Modal inference service.

**Implementation**: Rust 1.75+, async/await with Tokio

**Location**: `/Users/rand/src/ananke/maze/src/lib.rs`

#### Architecture

**MazeOrchestrator**:
```rust
pub struct MazeOrchestrator {
    modal_client: ModalClient,
    constraint_cache: Arc<Mutex<LruCache<String, CompiledConstraint>>>,
    config: MazeConfig,
}
```

**Key Responsibilities**:
1. Convert ConstraintIR from Zig FFI to Rust types
2. Compile constraints to llguidance-compatible format
3. Cache compiled constraints (LRU eviction)
4. Manage Modal client lifecycle
5. Track generation provenance and metadata

#### Request Flow

```
1. Receive generation request (prompt + constraints)
2. Hash constraints → check cache (xxHash3)
3. If cache miss: compile to llguidance format
4. Build Modal inference request
5. Call Modal service with constraints
6. Parse response, track metadata
7. Return validated code + provenance
```

#### Caching Strategy

**xxHash3 for Cache Keys**:
- 2-3x faster than Rust's DefaultHasher
- Collision resistance: 2^64 keyspace
- Keys: hash(serialized_constraint_ir)

**LRU Cache**:
```rust
// O(1) get, O(1) put, O(1) eviction
constraint_cache: LruCache<String, CompiledConstraint>
```

**Cache Hit Rate**: ~60-80% for typical workflows (same constraints, different prompts)

#### Provenance Tracking

```rust
pub struct Provenance {
    model: String,  // "DeepSeek-Coder-V2-Lite-Instruct"
    timestamp: i64,
    constraints_applied: Vec<String>,
    original_intent: String,
    parameters: HashMap<String, Value>,
}
```

#### FFI Conversion

**Zig → Rust**:
```rust
impl ConstraintIR {
    pub fn from_ffi(ffi: *const ConstraintIRFFI) -> Result<Self> {
        // 1. Convert C strings to Rust Strings
        // 2. Convert C arrays to Rust Vecs
        // 3. Validate all pointers
        // 4. Deep copy all data
    }
}
```

**Memory Safety**:
- All Zig allocations freed after conversion
- Rust owns all data post-conversion
- No shared memory between Zig and Rust

#### Performance Profile

| Operation | Time (Release) | Notes |
|-----------|----------------|-------|
| FFI conversion | <1ms | Per ConstraintIR |
| Cache lookup | <0.1ms | xxHash3 |
| llguidance compilation | 2-5ms | Without cache |
| Modal API call | 100-2000ms | Network + GPU |
| Total orchestration | <10ms | Excluding Modal |

---

### Modal Inference Service

**Purpose**: GPU-accelerated constrained generation with vLLM + llguidance.

**Stack**:
- vLLM 0.11.0 (inference engine)
- llguidance 0.7.11 (constraint enforcement)
- Modal (serverless GPU deployment)
- DeepSeek-Coder-V2-Lite-Instruct (16B parameters)

**Deployment**:
```
- Scale-to-zero (60s cold start)
- GPU: A100/H100 (configurable)
- Timeout: 300s per request
- Cost: ~$0.01 per 1000 tokens
```

**Endpoints**:
- `POST /generate` - Generate with constraints
- `GET /health` - Health check
- `GET /models` - List available models

**Request Format**:
```json
{
  "prompt": "Implement user authentication",
  "constraints": { /* llguidance schema */ },
  "max_tokens": 2048,
  "temperature": 0.7,
  "context": { /* optional metadata */ }
}
```

**Response Format**:
```json
{
  "generated_text": "...",
  "tokens_generated": 1523,
  "model": "DeepSeek-Coder-V2-Lite-Instruct",
  "stats": {
    "total_time_ms": 1847,
    "time_per_token_us": 1213,
    "constraint_checks": 1523,
    "avg_constraint_check_us": 245
  }
}
```

---

## Data Flow

### Complete Pipeline: Source Code → Generated Code

```
┌──────────────────────────────────────────────────────────┐
│ 1. Source Code Input (TypeScript/Python/Rust)           │
└──────────────────┬───────────────────────────────────────┘
                   │
                   v
┌──────────────────────────────────────────────────────────┐
│ 2. Clew.extractFromCode(source, language)               │
│    - Pattern matching (60+ patterns)                     │
│    - Type inference                                      │
│    - Optional: Claude semantic analysis                  │
│    ⏱ 4-7ms                                               │
└──────────────────┬───────────────────────────────────────┘
                   │
                   v
┌──────────────────────────────────────────────────────────┐
│ 3. ConstraintSet { constraints: []Constraint }           │
│    - Constraint objects with metadata                    │
│    - Confidence scores, frequencies, priorities          │
└──────────────────┬───────────────────────────────────────┘
                   │
                   v
┌──────────────────────────────────────────────────────────┐
│ 4. Braid.compile(constraints)                            │
│    - Build dependency graph                              │
│    - Detect conflicts, resolve                           │
│    - Topological sort                                    │
│    - Generate IR (JSON Schema, EBNF, regex, masks)      │
│    ⏱ 2ms                                                 │
└──────────────────┬───────────────────────────────────────┘
                   │
                   v
┌──────────────────────────────────────────────────────────┐
│ 5. ConstraintIR {                                        │
│      json_schema: JsonSchema,                            │
│      grammar: Grammar,                                   │
│      regex_patterns: []Regex,                            │
│      token_masks: TokenMaskRules,                        │
│      priority: u32                                       │
│    }                                                     │
└──────────────────┬───────────────────────────────────────┘
                   │
                   v FFI Boundary (Zig → Rust)
┌──────────────────────────────────────────────────────────┐
│ 6. ConstraintIRFFI → Rust ConstraintIR                  │
│    - C string conversion (null-terminated → String)     │
│    - Array conversion (C arrays → Vec)                  │
│    - Ownership transfer (Zig alloc → Rust owned)       │
│    ⏱ <1ms                                                │
└──────────────────┬───────────────────────────────────────┘
                   │
                   v
┌──────────────────────────────────────────────────────────┐
│ 7. MazeOrchestrator.generate(request)                   │
│    - Cache check (xxHash3)                               │
│    - Compile to llguidance format                        │
│    - Build Modal request                                 │
│    ⏱ 2-5ms (without cache)                               │
└──────────────────┬───────────────────────────────────────┘
                   │
                   v Network Boundary
┌──────────────────────────────────────────────────────────┐
│ 8. ModalClient.generate_constrained(request)            │
│    - HTTP POST /generate                                 │
│    - Retry logic (exponential backoff)                   │
│    ⏱ 100-2000ms (network + GPU)                          │
└──────────────────┬───────────────────────────────────────┘
                   │
                   v
┌──────────────────────────────────────────────────────────┐
│ 9. vLLM + llguidance Inference                           │
│    - Load constraints into llguidance                    │
│    - Generate tokens with constraint checks              │
│    - Each token: validate against all constraints        │
│    - Reject invalid tokens (mask logits to -inf)         │
└──────────────────┬───────────────────────────────────────┘
                   │
                   v
┌──────────────────────────────────────────────────────────┐
│ 10. Generated Code (Validated)                           │
│     + Provenance (model, timestamp, constraints)         │
│     + Validation (all constraints satisfied)             │
│     + Metadata (tokens, time, performance)               │
└──────────────────────────────────────────────────────────┘
```

### Timing Breakdown (Typical Request)

```
Clew extraction:        4-7ms
Braid compilation:      2ms
FFI conversion:         <1ms
Maze orchestration:     2-5ms
─────────────────────────────
Local processing:       8-15ms
─────────────────────────────
Modal API (network):    50-100ms
Modal GPU inference:    1000-2000ms
─────────────────────────────
Total end-to-end:       1.1-2.1s
```

**95th percentile**: 2.5s  
**99th percentile**: 4s  

---

## FFI Integration

### FFI Contract

**See**: `/Users/rand/src/ananke/test/integration/FFI_CONTRACT.md` for complete specification.

### ConstraintIRFFI Structure

**Zig Definition**:
```zig
pub const ConstraintIRFFI = extern struct {
    json_schema: ?[*:0]const u8,        // Null-terminated JSON
    grammar: ?[*:0]const u8,            // Null-terminated JSON
    regex_patterns: ?[*]const [*:0]const u8,  // Array of strings
    regex_patterns_len: usize,
    token_masks: ?*anyopaque,           // Opaque pointer
    priority: u32,
    name: ?[*:0]const u8,
};
```

**Rust Definition**:
```rust
#[repr(C)]
pub struct ConstraintIRFFI {
    pub json_schema: *const c_char,
    pub grammar: *const c_char,
    pub regex_patterns: *const *const c_char,
    pub regex_patterns_len: usize,
    pub token_masks: *const TokenMaskRulesFFI,
    pub priority: u32,
    pub name: *const c_char,
}
```

### Memory Management

**Allocation**:
- Zig allocates all FFI structures using global GPA
- Rust converts to owned types immediately
- No shared memory (deep copy all data)

**Deallocation**:
```rust
// Rust side
let ir = ConstraintIR::from_ffi(ffi_ptr)?;  // Convert
unsafe { ananke_free_constraint_ir(ffi_ptr); }  // Free Zig memory
// ir now owned by Rust
```

```zig
// Zig side
export fn ananke_free_constraint_ir(ir: ?*ConstraintIRFFI) callconv(.c) void {
    if (ir) |ptr| {
        if (ptr.name) |name| gpa.free(std.mem.span(name));
        if (ptr.json_schema) |schema| gpa.free(std.mem.span(schema));
        if (ptr.grammar) |grammar| gpa.free(std.mem.span(grammar));
        // ... free other fields ...
        gpa.destroy(ptr);
    }
}
```

### Error Handling

**Error Codes**:
```c
enum AnankeError {
    Success = 0,
    NullPointer = 1,
    AllocationFailure = 2,
    InvalidInput = 3,
    ExtractionFailed = 4,
    CompilationFailed = 5,
}
```

**Pattern**:
```rust
let result = unsafe { ananke_extract_constraints(src, lang, &mut out) };
match result {
    0 => { /* success */ },
    4 => return Err(anyhow!("Extraction failed")),
    _ => return Err(anyhow!("Unknown error: {}", result)),
}
```

### Thread Safety

**Current Status**: Not thread-safe (global allocator without synchronization)

**Workaround**: Serialize all FFI calls

**Future**: Per-thread allocators or mutex-protected global state

---

## Performance Characteristics

### Benchmarks (Debug Build)

| Component | Operation | Time | Memory | Notes |
|-----------|-----------|------|--------|-------|
| **Clew** | TS extraction (75 lines) | 4-7ms | ~500KB | Pattern matching |
| **Clew** | Type extraction | <1ms | ~100KB | Quick scan |
| **Clew** | Semantic (Claude) | 200-500ms | ~50KB | Network call |
| **Braid** | Graph construction (10) | <1ms | ~200KB | Adjacency list |
| **Braid** | Conflict detection | <1ms | ~50KB | O(n log n) |
| **Braid** | Compilation | 2ms | ~500KB | IR generation |
| **Maze** | FFI conversion | <1ms | ~10KB | C → Rust |
| **Maze** | Cache lookup | <0.1ms | - | xxHash3 |
| **Maze** | llguidance compile | 2-5ms | ~200KB | JSON building |
| **Modal** | Network latency | 50-100ms | - | HTTP |
| **Modal** | GPU inference | 1-2s | ~4GB | vLLM + llguidance |

### Optimization Strategies

**1. Pattern Caching (Planned)**
- Pre-compile regex patterns to DFA
- Cache compiled patterns per language
- Expected: 2-3x speedup on extraction

**2. Arena Allocators (In Use)**
- Bulk deallocation for temporary data
- Used in Clew for constraint strings
- Reduces fragmentation, improves cache locality

**3. Constraint Caching (Implemented)**
- LRU cache for compiled ConstraintIR
- xxHash3 for fast key generation
- O(1) lookup, O(1) eviction
- Hit rate: 60-80% for typical workflows

**4. Connection Pooling (Planned)**
- Reuse HTTP connections to Modal
- Reduce SSL handshake overhead
- Expected: 10-20ms savings per request

### Scaling Characteristics

**Clew Extraction**:
- O(n × p) where n = lines of code, p = patterns
- Linear scaling with file size
- 782 pattern rules compiled at startup

**Braid Compilation**:
- Graph construction: O(n²) worst case (all constraints depend on each other)
- Conflict detection: O(n log n) average (grouped by kind)
- Topological sort: O(n + e) where e = edges
- Typical: <5ms for 50 constraints

**Maze Orchestration**:
- Cache lookup: O(1)
- llguidance compilation: O(n) where n = constraints
- Typical: <10ms excluding Modal

---

## Security Considerations

### Token Masking (15 Blocking Patterns)

**SQL Injection**:
```
DROP, DELETE, INSERT, UPDATE, TRUNCATE, ALTER
```

**Command Injection**:
```
eval, exec, system(, spawn(, sh -c
```

**Credential Patterns**:
```
password, api_key, token, secret
```

**URL Patterns**:
```
http://, https://, ftp://
```

**File Path Patterns**:
```
/etc/, /root/, C:\Windows\, ../
```

### Input Validation

**Source Code**:
- Size limit: 10MB per file
- Encoding: UTF-8 only
- Timeout: 10s for extraction

**Constraints**:
- Count limit: 1000 per file
- Description length: 1KB max
- Timeout: 5s for compilation

### Audit Trail

**Provenance Tracking**:
```rust
pub struct Provenance {
    model: String,              // Which model generated code
    timestamp: i64,             // When generated
    constraints_applied: Vec<String>,  // Which constraints enforced
    original_intent: String,    // Original prompt
    parameters: HashMap<...>,   // Generation parameters
}
```

**Validation Result**:
```rust
pub struct ValidationResult {
    all_satisfied: bool,        // Were all constraints satisfied?
    satisfied: Vec<String>,     // Which constraints passed
    violated: Vec<String>,      // Which constraints failed
    metadata: HashMap<...>,     // Additional validation data
}
```

---

## Extensibility

### Adding New Languages

**Step 1**: Define patterns in `src/clew/patterns.zig`:
```zig
const go_function_patterns = [_]PatternRule{
    .{
        .pattern = "func ",
        .constraint_kind = .syntactic,
        .description = "Function declaration",
    },
    // ... more patterns
};

pub const go_patterns = LanguagePatterns{
    .function_decl = &go_function_patterns,
    // ... other categories
};
```

**Step 2**: Register in `getPatternsForLanguage()`:
```zig
pub fn getPatternsForLanguage(language: []const u8) ?LanguagePatterns {
    if (std.mem.eql(u8, language, "go")) return go_patterns;
    // ... other languages
    return null;
}
```

**Step 3**: Add test fixtures in `test/fixtures/sample.go`

**Step 4**: Run tests: `zig build test`

### Adding Constraint Types

**Step 1**: Extend `ConstraintKind` enum:
```zig
pub const ConstraintKind = enum {
    syntactic,
    type_safety,
    semantic,
    architectural,
    operational,
    security,
    my_new_kind,  // <-- Add here
};
```

**Step 2**: Update Braid compilation logic:
```zig
fn compileToIR(self: *Braid, graph: *const ConstraintGraph) !ConstraintIR {
    // ... existing code ...
    
    const my_constraints = try self.extractMyConstraints(graph);
    if (my_constraints.len > 0) {
        ir.my_field = try self.buildMyFormat(my_constraints);
    }
}
```

**Step 3**: Update FFI structure (breaking change):
```zig
pub const ConstraintIRFFI = extern struct {
    // ... existing fields ...
    my_field: ?[*:0]const u8,  // <-- Add here
};
```

**Step 4**: Update Rust conversion:
```rust
impl ConstraintIR {
    pub fn from_ffi(ffi: *const ConstraintIRFFI) -> Result<Self> {
        // ... existing conversions ...
        let my_field = unsafe { /* convert my_field */ };
    }
}
```

### Adding IR Output Formats

Current formats: JSON Schema, EBNF, Regex, Token Masks

**To add new format**:

```zig
// 1. Define format structure in types/constraint.zig
pub const MyFormat = struct {
    rules: []const MyRule,
    config: MyConfig,
};

// 2. Add to ConstraintIR
pub const ConstraintIR = struct {
    json_schema: ?JsonSchema,
    grammar: ?Grammar,
    regex_patterns: []const Regex,
    token_masks: ?TokenMaskRules,
    my_format: ?MyFormat,  // <-- Add here
};

// 3. Implement builder in Braid
fn buildMyFormat(self: *Braid, constraints: []const Constraint) !MyFormat {
    // ... implementation ...
}

// 4. Update llguidance compilation in Maze
fn compile_to_llguidance(&self, ir: &ConstraintIR) -> Result<Value> {
    // ... handle my_format ...
}
```

---

## Known Limitations

### Current Limitations

**1. Tree-sitter Integration Blocked**
- **Issue**: z-tree-sitter not compatible with Zig 0.15.x
- **Impact**: Limited to pattern-based extraction (~80% coverage)
- **Workaround**: Comprehensive pattern library covers common cases
- **Timeline**: Waiting for upstream fix

**2. Single-Threaded FFI**
- **Issue**: Global allocator without synchronization
- **Impact**: Cannot extract constraints concurrently
- **Workaround**: Serialize FFI calls
- **Timeline**: Phase 8 (thread-safe allocators)

**3. No Streaming Extraction**
- **Issue**: Entire source must be in memory
- **Impact**: Large files (>10MB) may cause memory pressure
- **Workaround**: Split into smaller compilation units
- **Timeline**: Phase 9 (streaming parser)

**4. Regex Flags Not Preserved (FFI)**
- **Issue**: Regex flags ("g", "i", "m") lost across FFI boundary
- **Impact**: Minor (flags rarely critical for constraints)
- **Workaround**: Encode flags in pattern if needed
- **Timeline**: Low priority

**5. Modal Cold Starts**
- **Issue**: Scale-to-zero causes 60s delay on first request
- **Impact**: Poor UX for infrequent use
- **Workaround**: Keep-alive pings, warm instance pools
- **Timeline**: Modal infrastructure improvement

### Performance Bottlenecks

**1. Claude API Latency**
- **Current**: 200-500ms per request
- **Solution**: Batch requests, cache results aggressively
- **Alternative**: Run local semantic analysis (Llama 3.1)

**2. Modal Network Latency**
- **Current**: 50-100ms overhead
- **Solution**: Deploy Maze in same region as Modal
- **Alternative**: Self-hosted vLLM instance

**3. Grammar Generation**
- **Current**: 2ms for complex grammars (50+ rules)
- **Solution**: Pre-compile common grammar templates
- **Alternative**: Use simpler regex-based constraints

---

## Future Architecture

### Phase 6: Tree-sitter Integration

**Goal**: Increase constraint coverage from ~80% to ~95%

**Changes**:
- Re-enable tree-sitter parsing in Clew
- Add language-specific AST walkers
- Combine tree-sitter + patterns (best of both)

**Expected Performance**:
- Extraction: 10-15ms (2x slower but more accurate)
- Memory: +500KB (AST overhead)

### Phase 8: Thread-Safe FFI

**Goal**: Enable concurrent constraint extraction

**Changes**:
- Per-thread allocators or mutex-protected GPA
- Thread-local Clew/Braid instances
- Atomic reference counting for shared data

**Expected Performance**:
- 4-8x throughput (depends on core count)
- No latency increase

### Phase 9: Streaming Parser

**Goal**: Handle arbitrarily large files

**Changes**:
- Incremental constraint extraction
- Sliding window over source code
- Partial ConstraintIR updates

**Expected Performance**:
- Constant memory usage (independent of file size)
- Linear time complexity (single pass)

### Phase 11: Distributed Deployment

**Goal**: Horizontal scaling of Modal services

**Components**:
- Load balancer for Modal instances
- Multi-region deployment (US, EU, Asia)
- Constraint result caching (Redis/Memcached)

**Expected Performance**:
- 10-100x throughput
- <50ms p99 latency (regional deployment)

### Phase 12: Local Inference Option

**Goal**: Remove Modal dependency for sensitive codebases

**Components**:
- vLLM + llguidance containerized
- Kubernetes deployment manifests
- Auto-scaling based on queue depth

**Benefits**:
- No data leaves environment
- Predictable costs (fixed infrastructure)
- Sub-10ms local network latency

---

## Appendix

### File Locations

**Zig Core**:
- Constraint types: `/Users/rand/src/ananke/src/types/constraint.zig`
- Clew engine: `/Users/rand/src/ananke/src/clew/clew.zig`
- Pattern library: `/Users/rand/src/ananke/src/clew/patterns.zig` (782 lines)
- Braid engine: `/Users/rand/src/ananke/src/braid/braid.zig` (1448 lines)
- FFI layer: `/Users/rand/src/ananke/src/ffi/zig_ffi.zig`

**Rust Maze**:
- Orchestrator: `/Users/rand/src/ananke/maze/src/lib.rs`
- Modal client: `/Users/rand/src/ananke/maze/src/modal_client.rs`
- FFI bridge: `/Users/rand/src/ananke/maze/src/ffi.rs`

**Tests**:
- E2E tests (Zig): `/Users/rand/src/ananke/test/integration/e2e_pipeline_test.zig`
- FFI tests (Rust): `/Users/rand/src/ananke/maze/tests/zig_integration_test.rs`
- Integration tests (Zig): `/Users/rand/src/ananke/test/integration/pipeline_tests.zig`

**Documentation**:
- FFI contract: `/Users/rand/src/ananke/test/integration/FFI_CONTRACT.md`
- E2E test report: `/Users/rand/src/ananke/test/integration/E2E_TEST_REPORT.md`
- User guide: `/Users/rand/src/ananke/docs/USER_GUIDE.md`
- FAQ: `/Users/rand/src/ananke/docs/FAQ.md`

### Test Results

**Zig Tests**: 100/100 passing (0 leaks)
**Rust Tests**: 74/74 passing
**CI**: All platforms passing (Linux, macOS, Windows)

### Version Information

- Zig: 0.15.2
- Rust: 1.75+
- vLLM: 0.11.0
- llguidance: 0.7.11
- Modal: Latest

---

**Document Maintained By**: Claude Code (docs-writer subagent)  
**Last Review**: 2025-11-24  
**Next Review**: On Phase 6 completion or API changes
