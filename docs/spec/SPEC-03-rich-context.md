# SPEC-03: Rich Context Export

## Rationale

Ananke's Clew extractor already parses source code into SyntaxStructure (FunctionDecl, TypeDecl, ImportDecl) via tree-sitter. Today, `toConstraints()` flattens this into summary text, discarding structured information that the Type and Import domains need. This spec defines a parallel serialization path that preserves structure, adds control flow and semantic extraction, implements cross-domain morphisms, and establishes the context hierarchy that governs what information matters most.

---

## [SPEC-03.01] SyntaxStructure to ConstraintSpec Serialization

`SyntaxStructure.toConstraintSpecJson()` serializes extracted AST data into the ConstraintSpec field format defined in [SPEC-02.01]. Field names must match `ConstraintSpec.from_dict()` exactly.

Mapping:

| SyntaxStructure Type | ConstraintSpec Field | Serialization |
|---------------------|---------------------|---------------|
| `FunctionDecl[]` | `function_signatures` | Each decl becomes `{name, params: [{name, type}], return_type, is_async, is_generator}` |
| `TypeDecl[]` (struct/class) | `class_definitions` | Each decl becomes `{name, fields: [{name, type}], methods: [name]}` |
| `TypeDecl[]` (alias/enum) | `type_bindings` | Each decl becomes `{name, type_expr, scope}` |
| `ImportDecl[]` | `imports` | Each decl becomes `{module, items: [name], alias}` |

Disambiguation between `class_definitions` and `type_bindings` is based on `TypeDecl.kind`: struct/class/interface map to `class_definitions`; type alias, enum, and typedef map to `type_bindings`.

All JSON field values are strings, not AST nodes. Type expressions are serialized as their source text representation (e.g., `"HashMap<String, Vec<u32>>"` not a parsed type tree).

**Acceptance criteria**: Round-trip test: serialize a SyntaxStructure containing all four declaration types in Zig, deserialize via `from_dict()` in Python, verify every field is present and correct. Null/optional fields (e.g., missing return type) must serialize as JSON null, not empty string. All 9 supported languages must produce valid output for their respective declaration types.

---

## [SPEC-03.02] RichContext Struct in ConstraintIR

The `RichContext` struct extends ConstraintIR with serialized JSON for each constraint domain:

```zig
pub const RichContext = struct {
    // Hard domain context (Phase 2)
    type_bindings_json: ?[]const u8 = null,
    function_signatures_json: ?[]const u8 = null,
    class_definitions_json: ?[]const u8 = null,
    imports_json: ?[]const u8 = null,

    // Soft domain context (Phase 3)
    control_flow_json: ?[]const u8 = null,
    semantic_constraints_json: ?[]const u8 = null,

    // Scope context (Phase 4A)
    scope_bindings_json: ?[]const u8 = null,
};
```

Each `_json` field contains a serialized JSON array or object matching the corresponding ConstraintSpec field. Fields are nullable: absent data is `null`, not empty JSON.

RichContext is attached to ConstraintIR and propagated through the compilation pipeline. Braid reads it during constraint compilation. The generate command merges it into the ConstraintSpec JSON payload.

The Rust FFI boundary (`maze/src/ffi.rs`) must extend `ConstraintIR` with `rich_context: Option<serde_json::Value>` to pass the complete context through the Maze layer.

**Acceptance criteria**: RichContext must be serializable to JSON and deserializable back without loss. Null fields must not appear in the serialized output (omit, do not include as `"field": null`). The Rust FFI must pass RichContext through without interpretation -- it is opaque JSON at that boundary.

---

## [SPEC-03.03] Control Flow Extraction

Clew extracts control flow context from the AST surrounding the generation hole:

| Signal | Source | ConstraintSpec Field |
|--------|--------|---------------------|
| Async context | `async def`, `async fn`, `async function` | `control_flow.is_async` |
| Generator context | `yield`, `yield from`, generator expressions | `control_flow.is_generator` |
| Loop depth | Nested `for`/`while`/`loop` enclosing the hole | `control_flow.loop_depth` |
| Try/catch scope | Whether the hole is inside a try/catch/finally | `control_flow.has_try_catch` |
| Error handling pattern | `Result<>` return + `?` operator (Rust), try/except (Python), etc. | `control_flow.error_handling_pattern` |

Error handling pattern values are language-specific strings:

- Rust: `"result_question_mark"`, `"result_match"`, `"unwrap"`
- Python: `"try_except"`, `"contextmanager"`
- Go: `"if_err"`, `"error_wrap"`
- JavaScript/TypeScript: `"try_catch"`, `"promise_catch"`, `"async_try_catch"`
- Other languages: `null` until patterns are defined

Extraction walks the AST upward from the hole position to the enclosing function/method, accumulating context. The enclosing function's signature determines async/generator status; the path to the hole determines loop depth and try/catch scope.

**Acceptance criteria**: A Python async function with a nested try/except containing a for loop must produce `{is_async: true, is_generator: false, loop_depth: 1, has_try_catch: true, error_handling_pattern: "try_except"}`. Extraction must work for all 9 supported languages. Missing context (e.g., hole at module level) produces all-null control flow.

---

## [SPEC-03.04] Semantic Constraint Extraction

Clew extracts behavioral intent from source-level annotations:

| Source | What is Extracted | ConstraintSpec Field |
|--------|-------------------|---------------------|
| Docstrings | Precondition phrases ("requires", "assumes", "expects", "input must") | `semantic_constraints.preconditions[]` |
| Docstrings | Postcondition phrases ("returns", "ensures", "guarantees", "output will") | `semantic_constraints.postconditions[]` |
| Docstrings | Invariant phrases ("maintains", "preserves", "invariant") | `semantic_constraints.invariants[]` |
| Assert statements | `assert expr` in function body before the hole | `semantic_constraints.preconditions[]` |
| Assert statements | `assert expr` in function body after the hole | `semantic_constraints.postconditions[]` |
| Test assertions | `assert_eq`, `expect().to`, `assertEqual` in test files for the function | `semantic_constraints.postconditions[]` |

Extraction is heuristic, not formal. Docstring parsing uses keyword matching on the first word of each docstring line/section. Assert extraction captures the assertion expression as a string.

Semantic constraints are always soft-tier. They inform the Semantics domain's scoring function but never restrict the hard feasible set ([SPEC-01.04]).

**Acceptance criteria**: A Python function with docstring `"""Requires: x > 0. Returns: sorted list."""` must produce `preconditions: ["x > 0"]` and `postconditions: ["sorted list"]`. Assert statements `assert len(items) > 0` before the hole must appear in preconditions. Empty docstrings / no assertions must produce empty arrays, not null.

---

## [SPEC-03.05] Cross-Domain Morphism Implementation

Braid implements the morphisms defined in [SPEC-01.03] during constraint compilation:

### Types <-> Imports (bidirectional)

**Types -> Imports**: When a type binding references a type not locally defined, Braid infers the required import. For example, `HashMap<K,V>` in a Rust context adds `use std::collections::HashMap` to the import constraints.

**Imports -> Types**: When an import is present, all exported types from that module are added to the type domain's scope. For example, `from typing import List, Optional` makes `List` and `Optional` available for type checking.

Implementation: After initial extraction, Braid runs a fixpoint loop:
1. Collect all type references from `type_bindings` and `function_signatures`.
2. Resolve each against `imports`. Unresolved types generate import constraints.
3. Newly added imports expand the type scope. Repeat until stable.

The loop is bounded: at most `|type_references| + |imports|` iterations.

### Types -> ControlFlow (one-way)

When the return type or parameter types suggest error handling patterns, Braid adds a soft ControlFlow constraint:

- `Result<T, E>` / `Either<L, R>` -> `error_handling_pattern: "result_match"` (soft)
- `Optional<T>` / `Option<T>` -> `error_handling_pattern: "null_check"` (soft)
- `Future<T>` / `Promise<T>` -> `is_async: true` (soft, not overriding hard extraction)

### Types -> Semantics (one-way)

Type signatures imply behavioral expectations:

- `fn sort(&mut self)` where `Self: Ord` -> postcondition: "elements are ordered"
- `fn validate(&self) -> Result<(), Error>` -> postcondition: "returns error on invalid input"
- `fn clone(&self) -> Self` -> postcondition: "returned value equals self"

These are added as soft semantic constraints with lower confidence than explicitly extracted constraints.

### Imports -> Semantics (one-way)

Imported modules imply expected usage patterns:

- `import logging` / `use log::*` -> semantic expectation: log calls present
- `import unittest` / `use test` -> semantic expectation: test assertions present
- `import json` / `use serde_json` -> semantic expectation: serialization/deserialization calls

**Acceptance criteria**: The Types <-> Imports fixpoint must converge in bounded iterations. A type reference `HashMap<K,V>` with no matching import must generate an import constraint. A `Result<T,E>` return type must generate a ControlFlow soft constraint. All morphism outputs must be tagged with their source morphism for traceability. Soft constraints generated by morphisms must have strictly lower priority than explicitly extracted constraints.

---

## [SPEC-03.06] Context Hierarchy

Research converges on a clear ordering of context impact for code generation quality (InlineCoder January 2026, RepoExec NAACL 2025, PLDI 2025):

| Priority | Context Type | Source | Impact |
|----------|-------------|--------|--------|
| 1 (highest) | Type signatures of directly referenced entities | Clew + Homer scope graph | Most impactful -- defines the type-level contract |
| 2 | Upstream callers (how the function is used) | Homer call graph | Usage context constrains implementation |
| 3 | Downstream callees (what it depends on) | Homer call graph | Dependency context constrains what is available |
| 4 | Test files (specification + examples) | Homer co-change analysis | Executable specification |
| 5 | Similar code in codebase (patterns, conventions) | Homer convention mining | Stylistic and structural guidance |
| 6 | Import/module structure (what is available) | Clew extraction | Scope boundary definition |
| 7 (lowest) | Documentation (intent) | Clew extraction | Least impactful but nonzero |

Clew provides levels 1 (local file), 6, and 7 directly. Homer's scope graph provides levels 1-3 cross-file. Homer's convention mining provides level 5. Homer's co-change analysis identifies level 4 candidates.

When constructing the generation prompt, context is included in priority order until the context window budget is exhausted. Higher-priority context is never displaced by lower-priority context.

When constructing constraints, type signatures (level 1) seed the hard Type domain. Imports (level 6) seed the hard Import domain. Callers and callees (levels 2-3) enrich type context. Tests (level 4) seed semantic constraints. Conventions (level 5) seed soft ControlFlow constraints.

**Acceptance criteria**: The prompt construction must respect the priority ordering: level 1 context is always included if available, level 7 is first to be dropped under token budget pressure. Constraint construction must map each context level to its corresponding domain as specified. The mapping must be documented in code comments referencing this spec.

---

## References

- InlineCoder (January 2026): upstream callers + downstream callees = 49% improvement on RepoExec
- RepoExec (NAACL 2025): repository-level execution for code generation evaluation
- PLDI 2025 (ETH Zurich): type-constrained code generation with prefix automata
- Ananke SyntaxStructure: `src/clew/extractors/base.zig`, existing AST data structures
- ananke-sglang ConstraintSpec: `ConstraintSpec.from_dict()`, deserialization contract
