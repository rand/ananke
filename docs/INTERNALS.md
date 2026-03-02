# Ananke Internals

Ananke turns AI code generation from probabilistic text completion into
search through valid program spaces. It extracts constraints from source
code, compiles them into token-level masks and grammars, and ships those
artifacts to an inference backend that enforces them during decoding.

This document describes the machinery that makes that happen. Every
number below was verified against the source tree at commit `ae119b3`.

---

## System Layers

```
┌─────────────────────────────────────────────┐
│              CLI (src/cli/)                   │
│  extract │ compile │ generate │ validate      │
│  export-spec │ init │ version │ help          │
├─────────────────────────────────────────────┤
│              Ariadne (src/ariadne/)           │
│  Constraint DSL parsing                       │
├─────────────────────────────────────────────┤
│              Braid (src/braid/)               │
│  CLaSH algebra │ Domain fusion │ Feasibility  │
│  Type inhabitation │ FIM │ Salience │ Temporal│
├─────────────────────────────────────────────┤
│              Clew (src/clew/)                 │
│  14 languages │ tree-sitter │ patterns        │
│  Scope context │ Call graph │ Conventions      │
├─────────────────────────────────────────────┤
│              Maze (maze/)                     │
│  Rust FFI │ Modal client │ sglang integration │
├─────────────────────────────────────────────┤
│              Eval (eval/)                     │
│  pass@k │ quality scoring │ statistical tests │
└─────────────────────────────────────────────┘
```

Data flows bottom-up at extraction time and top-down at generation time.
Clew mines constraints from source; Braid compiles them to an IR that
Maze forwards to sglang or Modal for constrained decoding. The eval
harness measures whether any of this actually helps.

---

## File Map

### Clew — Constraint Extraction (`src/clew/`)

| File | Purpose |
|------|---------|
| `clew.zig` | Main extraction engine. The `Ananke` struct lives here. |
| `extractors.zig` | Extractor registry and dispatch |
| `extractors/` | 15 files: `base.zig` + one per language (`c.zig`, `cpp.zig`, `csharp.zig`, `go.zig`, `java.zig`, `javascript.zig`, `kotlin.zig`, `php.zig`, `python.zig`, `ruby.zig`, `rust.zig`, `swift.zig`, `typescript.zig`, `zig_lang.zig`) |
| `patterns.zig` | 383 pattern rules across 14 languages, 8 categories per language |
| `hybrid_extractor.zig` | tree-sitter primary + pattern fallback |
| `tree_sitter.zig` | tree-sitter FFI orchestration |
| `tree_sitter/` | C FFI bindings for tree-sitter |
| `scope_context.zig` | Homer scope graph integration: `ScopeBinding`, `CanonicalImport`, `ScopeContext` (11 tests) |
| `call_graph_context.zig` | InlineCoder-style caller/callee context (7 tests) |
| `conventions.zig` | Convention mining, produces soft CLaSH constraints (5 tests) |
| `hole_detector.zig` | Typed hole detection (`TODO`, `pass`, `unimplemented!`, etc.) |
| `semantic_hole_detector.zig` | Semantic hole detection via AST analysis |
| `parsers/` | Language-specific parser helpers |

### Braid — Constraint Compilation (`src/braid/`)

| File | Purpose |
|------|---------|
| `braid.zig` | Main compiler: Constraint[] to ConstraintIR. Cache, incremental, conflict resolution. |
| `domain_fusion.zig` | CLaSH 5-domain fusion: hard mask intersection + soft additive reweighting + CRANE phase switching (13 tests) |
| `feasibility.zig` | Conflict detection, tightness scoring, community-aware tension (7 tests) |
| `salience.zig` | Homer quadrant to intensity + confidence mapping (10 tests) |
| `temporal.zig` | Stability classes, co-change patterns, confidence adjustment (7 tests) |
| `fim.zig` | FIM context analysis: `PrefixAnalysis`, `SuffixAnalysis`, `HoleScale` (12 tests) |
| `types/type_system.zig` | `TypeArena`, `Type` union (12 variants), `PrimitiveKind` (20 variants), `Language` (10 variants) (5 tests) |
| `types/parser.zig` | `TypeParser`: string signatures to unified types, 10 languages (7 tests) |
| `types/inhabitation.zig` | `InhabitationGraph`: BFS reachability, 9 `EdgeKind`s, per-language builtins (4 tests) |
| `types/mask_generator.zig` | `MaskGenerator`, `TypeInhabitationState`, `TypeInhabitationBuilder` (8 tests) |
| `types/types.zig` | Type module root |
| `json_schema_builder.zig` | JSON Schema Draft 7 generation |
| `regex_analyzer.zig` | Regex pattern extraction + pathology filtering (catastrophic backtracking detection) |
| `string_interner.zig` | `GrammarInterner` + `RegexPatternPool` for string deduplication |
| `hole_compiler.zig` | Typed holes to IR compilation |
| `sanitizer.zig` | Constraint injection prevention (name length limits, input validation) |

### Ariadne — Constraint DSL (`src/ariadne/`)

| File | Purpose |
|------|---------|
| `ariadne.zig` | DSL parser (parsing complete, type checking deferred) |
| `test_parser.zig` | Parser tests |

### CLI (`src/cli/commands/`)

| File | Purpose |
|------|---------|
| `extract.zig` | Constraint extraction from source files |
| `compile.zig` | Constraint compilation to IR |
| `generate.zig` | Code generation via sglang/Modal, FIM support (11 tests) |
| `validate.zig` | Code validation against constraints |
| `export_spec.zig` | One-shot extract+compile+context to ConstraintSpec JSON |
| `init.zig` | `.ananke.toml` initialization |
| `version.zig` | Version information |
| `help.zig` | Help display |

### Maze — Rust FFI + Inference (`maze/`)

| File | Purpose |
|------|---------|
| `src/lib.rs` | Crate root. `MazeOrchestrator`, `GenerationRequest`, `GenerationResponse`. |
| `src/ffi.rs` | FFI bridge to Zig core (constraint extraction and compilation) |
| `src/modal_client.rs` | Modal HTTP client |
| `src/model_router.rs` | Model routing and selection logic |
| `src/model_selector.rs` | Strategy-based model selection |
| `src/adaptive_selector.rs` | Adaptive model selection based on task characteristics |
| `src/progressive_refinement.rs` | Iterative generation refinement |
| `src/diffusion.rs` | Diffusion-based generation strategy |
| `src/strategy_stats.rs` | Generation strategy statistics |
| `src/telemetry.rs` | Inference telemetry collection |
| `src/python.rs` | Python bindings |
| `tests/` | `ffi_tests.rs`, `orchestrator_tests.rs`, `zig_integration_test.rs`, `modal_client_tests.rs`, `end_to_end_tests.rs` |
| `modal_inference/inference.py` | Modal deployment: Qwen2.5-Coder-32B-Instruct on A100-80GB |

### Eval — Evaluation Framework (`eval/core/`)

| File | Purpose |
|------|---------|
| `evaluator.zig` | `Evaluator`, `MultiSampleEvaluator`, `BatchEvaluationResult` |
| `task_spec.zig` | `TaskSpec`, 24 `TaskCategory` variants, 4 `DifficultyLevel`s |
| `quality_scorer.zig` | 5-axis quality scoring |
| `metrics/pass_at_k.zig` | pass@k statistics |
| `metrics/statistical_tests.zig` | Paired t-test |
| `metrics/constraint_metrics.zig` | CodeIF constraint satisfaction metrics |
| `modal_client.zig` | Eval-specific Modal client |
| `eval_constraint_compiler.zig` | Constraint compilation for eval tasks |
| `test_runner.zig` | Test execution harness |
| `prompt_normalizer.zig` | Prompt normalization |
| `failure_analyzer.zig` | Failure classification and analysis |

---

## Core Types

### ConstraintKind

Six variants, mapping to analysis domains:

```zig
pub const ConstraintKind = enum {
    syntactic,      // Code structure, formatting, naming
    type_safety,    // Type annotations, null safety, generics
    semantic,       // Data flow, control flow, side effects
    architectural,  // Module boundaries, dependencies, layering
    operational,    // Performance, memory, concurrency
    security,       // Input validation, auth, dangerous ops
};
```

### ConstraintIR

The compiled form of constraints. This is the artifact that crosses the
FFI boundary and travels to the inference backend.

```zig
pub const ConstraintIR = struct {
    json_schema: ?JsonSchema = null,
    grammar: ?Grammar = null,
    regex_patterns: []const Regex = &.{},
    token_masks: ?TokenMaskRules = null,
    type_inhabitation: ?TypeInhabitationData = null,
    priority: u32 = 0,
    hole_specs: []const HoleSpec = &.{},
    rich_context: ?RichContext = null,
    feasibility_score: f32 = 0.0,
    is_feasible: bool = true,
    // ...
};
```

The `json_schema` field carries structural metadata for the sglang
backend. Only the `grammar` field (EBNF) goes to llguidance for
actual token masking.

The `rich_context` field carries the full CLaSH decomposition as
serialized JSON -- function signatures, type bindings, class
definitions, imports, control flow patterns, semantic constraints,
scope bindings, and call graph context. Eight JSON blobs, each
independently nullable. This structure lets backends consume whichever
context they support without requiring all-or-nothing.

`ConstraintIR` also carries `owns_grammar_strings` -- a flag
distinguishing borrowed (interned) grammar strings from owned (cloned)
ones. Cache hits return cloned IRs that own their strings; the cache
itself holds interned originals. Getting this wrong means either a
double-free or a use-after-free, which is why the flag exists.

### Sanitizer

`braid/sanitizer.zig` prevents constraint injection attacks. Constraint
names are capped at 64 bytes. Descriptions are scrubbed for control
characters. The concern is that untrusted constraint sources (user
config, telemetry, LLM-generated) could inject malformed data that
corrupts the IR or escapes into grammar rules. The sanitizer runs
before any constraint enters the compilation pipeline.

---

## Clew: Extraction

Clew answers one question: given source code, what constraints does it
imply?

### Hybrid Extraction

Extraction runs in two tiers:

1. **tree-sitter AST walk** (primary). Per-language extractors in
   `extractors/` walk the concrete syntax tree and emit structured
   constraints: function signatures, type annotations, class
   hierarchies, import maps, error handling patterns.

2. **Pattern matching** (fallback). When tree-sitter parsing fails or
   a language grammar isn't loaded, `patterns.zig` applies 383
   string-match rules organized into 8 categories per language:
   `function_decl`, `type_annotation`, `async_pattern`,
   `error_handling`, `imports`, `class_struct`, `metadata`,
   `memory_management`.

The `hybrid_extractor.zig` orchestrates this: try tree-sitter first,
fall back to patterns, merge results. The pattern matcher
(`scanPatterns` in `patterns.zig`) is a linear scan: for each byte
position in the source, it checks all pattern sets in a nested loop.
This is O(n * p) where n is source length and p is total pattern count
-- acceptable because p is bounded (383) and patterns are short string
matches, not regex.

### Homer Context (Optional)

When Homer is available, Clew enriches extraction with cross-file
intelligence:

- **Scope context** (`scope_context.zig`): queries Homer's scope graph
  for bindings visible at the cursor position. Produces
  `ScopeBinding` records (name, kind, qualified type, definition file)
  and `CanonicalImport` records. This feeds the Imports domain in
  CLaSH -- the vocabulary subset constraint ensures the model only
  references symbols that are actually in scope.

- **Call graph context** (`call_graph_context.zig`): InlineCoder-style
  analysis. For a function being generated, retrieves upstream callers
  (what calls this function, with what arguments, how is the result
  used) and downstream callees (what this function calls, with what
  signatures). This gives the model concrete usage patterns rather
  than abstract type signatures.

- **Conventions** (`conventions.zig`): mines repository-wide coding
  conventions (naming patterns, error handling idioms, import styles)
  and produces soft CLaSH constraints. If 95% of the codebase uses
  `camelCase`, the model gets a soft nudge toward `camelCase`.

### 14 Languages

C, C++, C#, Go, Java, JavaScript, Kotlin, PHP, Python, Ruby, Rust,
Swift, TypeScript, Zig. Each gets a dedicated extractor in
`extractors/` and a pattern set in `patterns.zig`.

### Rich Context Export

Extraction produces more than flat constraint lists. The `RichContext`
struct carries eight JSON blobs covering the CLaSH domain decomposition:

- `function_signatures_json` — name, parameters (with types), return type, async flag
- `type_bindings_json` — name, kind, fields
- `class_definitions_json` — name, methods, fields
- `imports_json` — module, items, wildcard flag
- `control_flow_json` — async patterns, generators, error handling style, recursion
- `semantic_constraints_json` — kind, expression, source
- `scope_bindings_json` — Homer scope graph bindings (cross-file)
- `call_graph_json` — Homer call graph (callers, callees, argument usage)

The last two require a running Homer instance. Without it, those
fields are null and everything else works fine.

---

## Braid: Compilation

Braid transforms a bag of constraints into a `ConstraintIR` suitable
for token-level enforcement. The pipeline has eleven stages.

### Compilation Pipeline

From `braid.zig`, method `compile()`:

1. **Cache key** — `computeCacheKey` hashes canonically-sorted constraints with Wyhash.
2. **Cache lookup** — LRU cache with copy-on-write `SharedConstraintIR` (reference-counted). Cache hit returns a clone in O(1).
3. **Dependency graph** — `buildDependencyGraph` creates edges: syntactic before type_safety before semantic. Topological structure.
4. **Conflict detection** — `detectConflicts` groups constraints by `ConstraintKind`, checks pairs within each group. O(n^2/k) where k is the number of kinds.
5. **Conflict resolution** — Claude API if an LLM client is configured; otherwise default heuristic (higher severity wins).
6. **Graph optimization** — `optimizeGraph` does topological sort and boosts priority based on severity.
7. **IR generation** (`compileToIR`):
   - Feasibility analysis via `FeasibilityAnalyzer` (tightness scoring, feasibility flag)
   - JSON Schema generation from type constraints
   - Type inhabitation data (parses "must return type: T" from descriptions, builds reachability graph)
   - Grammar construction from syntactic constraints (EBNF rules, string-interned)
   - Regex pattern extraction with pathology filtering via `RegexAnalyzer`
   - Token mask generation from security constraints

After `compileToIR` returns, the caller layers on additional analyses:

8. **Salience scoring** — Homer quadrant mapped to intensity level and confidence.
9. **Temporal analysis** — stability classification, co-change decay, confidence adjustment.
10. **Domain fusion** — ASAp-style hard mask intersection + soft additive reweighting, with CRANE phase switching between reasoning and structured output.
11. **FIM analysis** — if `--fim` mode is active, `PrefixAnalysis` and `SuffixAnalysis` determine hole scale and context boundaries.

### Incremental Compilation

Braid supports incremental recompilation via fingerprint-based change
detection (`IncrementalState`). On recompile:

- Unchanged constraints skip reprocessing entirely.
- Changed constraints propagate through `getAffectedSubgraph`.
- If more than 80% of the graph is affected, Braid falls back to a
  full rebuild (it's faster than selective patching at that point).

### CLaSH Algebra

CLaSH organizes constraints into 5 domains across 2 tiers:

| Domain | Tier | Enforcement |
|--------|------|-------------|
| Syntax | Hard | Earley parser / PDA |
| Types | Hard | Prefix automata |
| Imports | Hard | Vocabulary subset |
| ControlFlow | Soft | Graded 0.0--1.0 |
| Semantics | Soft | Graded 0.0--1.0 |

Hard constraints define the feasible token set (binary pass/fail). Soft
constraints rank candidates within that set. Domain fusion intersects
hard masks, then applies additive reweighting from soft scores.

CRANE-style phase switching relaxes constraints during reasoning tokens
and tightens them during structured output, preventing constraint
enforcement from interfering with chain-of-thought. During `reasoning`
phase with adaptive switching enabled, only the Syntax domain stays
active. During `structured_output`, all domains at the current
intensity level participate.

### Salience and Intensity

Salience scoring (`salience.zig`) maps Homer's repository analysis into
constraint intensity levels. Homer produces a composite score (weighted
blend of PageRank 30%, betweenness 15%, HITS 15%, churn 15%, bus
factor 10%, code size 5%, test presence 10%) and a four-quadrant
classification:

| Quadrant | Centrality | Churn | Intensity | Confidence |
|----------|-----------|-------|-----------|------------|
| FoundationalStable | High | Low | `full_hard` | High |
| ActiveHotspot | High | High | `full` | Medium |
| PeripheralActive | Low | High | `standard` | -- |
| QuietLeaf | Low | Low | `syntax_only` | -- |

Intensity levels form a lattice from `none` (no constraints) through
`syntax_only`, `standard` (Syntax + Types), `full_hard` (all 3 hard
domains), `full` (all 5 domains), to `exhaustive` (all domains plus
verification hooks). Each level carries a per-token latency budget:
50us for syntax-only up to 5000us for exhaustive.

The practical effect: foundational code gets all five domains enforced;
a rarely-touched leaf file might only get grammar checking. This avoids
the "constrain everything equally" failure mode where enforcement cost
swamps generation speed on code that doesn't need it.

### Temporal Analysis

Temporal analysis (`temporal.zig`) adjusts constraint confidence based
on code stability over time. It classifies files by modification
frequency, applies co-change decay (recently-changed files get reduced
confidence), and modulates the salience-derived intensity accordingly.
A file that was stable for months but just got a major refactor should
temporarily have its constraint confidence reduced until the new
patterns settle.

### FIM (Fill-in-the-Middle)

When `--fim` mode is active, `fim.zig` analyzes the code surrounding a
cursor position. `PrefixAnalysis` examines what comes before the hole:
function context, type expectations, variable bindings in scope.
`SuffixAnalysis` examines what comes after: expected return types,
closing delimiters, downstream usage. Together they determine the
`HoleScale` -- whether the model needs to fill a single expression, a
statement, a block, or an entire function body. This scale determines
which constraint domains are relevant (a single expression needs type
constraints; a full function body needs all five domains).

### Type Inhabitation

The type system in `braid/types/` implements cross-language type
reasoning:

- **TypeArena** allocates all types in a single arena. One `deinit`
  frees everything.
- **Type** is a tagged union with 12 variants: `primitive`, `array`,
  `tuple`, `object`, `function`, `union_type`, `intersection`,
  `optional`, `named`, `generic`, `reference`, `error_union`.
- **PrimitiveKind** has 20 variants spanning Zig's integer types,
  floats, JS/TS specials (`number`, `any`, `unknown`, `never`), and
  universals (`string`, `char`, `boolean`, `void_type`, `null_type`,
  `undefined`).
- **TypeParser** maps string type signatures from 10 languages into
  the unified `Type` representation.
- **InhabitationGraph** does BFS reachability over 9 edge kinds
  (`coercion`, `binary_op`, `property`, `method`, `application`,
  `indexing`, `construction`, `template`, `assertion`) to determine
  which types are constructible from available bindings.
- **MaskGenerator** converts inhabitation results into token masks.

---

## Maze: FFI and Inference

Maze is the Rust crate that bridges Zig's constraint engine to GPU
inference.

### Architecture

```
Zig (Ananke core)  →  C ABI  →  Rust FFI (maze/src/ffi.rs)
                                      ↓
                               MazeOrchestrator
                                 ↓           ↓
                          Modal client    sglang client
                                 ↓           ↓
                           A100-80GB     vLLM + llguidance
```

The Zig core is compiled as a C-compatible library. Rust calls it via
FFI for constraint extraction and compilation, receiving a
`ConstraintIR` that it serializes and forwards to the inference
backend.

### Inference Backends

**sglang**: OpenAI-compatible HTTP with a `constraint_spec` extension
field. The grammar goes to llguidance for token masking; JSON schema
travels as structural metadata.

**Modal**: Custom `/generate` endpoint. Currently runs
Qwen2.5-Coder-32B-Instruct on an A100-80GB. Deployed via
`modal deploy maze/modal_inference/inference.py`.

The orchestrator (`MazeOrchestrator` in `lib.rs`) handles the full
generation lifecycle. It accepts a `GenerationRequest` (prompt,
constraints IR, max tokens, temperature, optional context) and returns
a `GenerationResponse` with the generated code, validation results,
and provenance metadata (which model, which constraints were active).

Supporting modules:

- `model_router.rs` + `model_selector.rs` + `adaptive_selector.rs`:
  pick the right backend and model for a given task. The adaptive
  selector adjusts based on task characteristics (code complexity,
  constraint density, language).
- `progressive_refinement.rs`: iterative generation -- generate,
  validate against constraints, refine, repeat until satisfied or
  budget exhausted.
- `diffusion.rs`: diffusion-based generation strategy (experimental).
- `strategy_stats.rs`: tracks per-strategy success rates and latencies.
- `telemetry.rs`: collects inference metrics for observability.

---

## Memory Management

### Allocation Strategy

Zig's explicit allocator passing is used throughout. No hidden globals.
The pattern is consistent:

```zig
var thing = try allocate(allocator);
errdefer thing.deinit(allocator);
// ... use thing ...
return thing;  // caller owns it
```

### Key Allocators

- **TypeArena** (`braid/types/type_system.zig`): Single
  `ArenaAllocator` for all type allocations during inhabitation
  analysis. One `deinit` frees every `Type` node, every field slice,
  every string. No individual frees needed.

- **GrammarInterner** (`braid/string_interner.zig`): Deduplicates
  grammar rule strings and regex patterns. Grammar rules for common
  constructs (e.g., identifier patterns) appear hundreds of times
  across constraints; interning them saves meaningful memory.

- **RingQueue**: Fixed-size circular buffer used for LRU cache
  eviction ordering.

- **SharedConstraintIR**: Reference-counted wrapper around
  `ConstraintIR`. Cache stores the original; callers get either a
  clone (via `compile()`) or an acquired reference (via
  `compileShared()`). The shared path avoids cloning for read-only
  access -- important when the same constraint set is compiled
  repeatedly during iterative generation. `compileShared()` returns
  an acquired reference that the caller must `release()` when done;
  `compile()` returns an owned clone the caller must `deinit()`.
  Two APIs because the performance characteristics differ enough
  to matter: the shared path is O(1), the clone path is O(n) in
  IR size.

### Error Paths

Every allocation that could be abandoned on error gets an `errdefer`.
This is enforced by convention and caught by Zig's leak-detecting test
allocator, which fails the test if any allocation is not freed.

---

## Testing

### Counts

At last measurement: 370 Zig tests + 86 Rust tests = 456 total, zero
failures, zero memory leaks (Zig's `std.testing.allocator` detects
leaks as test failures).

### Organization

**Zig**: Inline `test "name" { ... }` blocks colocated with the code
they test. This is idiomatic Zig -- tests live next to the functions
they exercise, share the same file scope, and run with
`zig build test --summary all`.

**Rust**: `maze/tests/` for integration tests (`ffi_tests.rs`,
`orchestrator_tests.rs`, `zig_integration_test.rs`,
`modal_client_tests.rs`). Unit tests via `#[cfg(test)]` modules
inside `maze/src/` files.

**Eval fixtures**: `eval/tasks/fixtures/` contains Zig programs used
as evaluation targets.

### Test Coverage by Module

Modules with the highest test density (test count in parentheses):

- `domain_fusion.zig` (13) — CLaSH fusion correctness
- `fim.zig` (12) — FIM prefix/suffix analysis
- `scope_context.zig` (11) — scope graph integration
- `generate.zig` (11) — CLI generation command
- `salience.zig` (10) — salience scoring
- `mask_generator.zig` (8) — type inhabitation masks
- `feasibility.zig` (7) — conflict detection
- `temporal.zig` (7) — temporal analysis
- `parser.zig` (7) — type parser
- `call_graph_context.zig` (7) — call graph context

### Eval Framework

The eval harness supports multi-sample pass@k evaluation with paired
constrained-vs-unconstrained comparison. `MultiSampleEvaluator`
generates n samples per task, `pass_at_k.zig` computes the unbiased
estimator, and `statistical_tests.zig` runs a paired t-test (p < 0.05
threshold) to determine whether constraints actually improve output
quality.

Task specs cover 24 categories (algorithms, API, async, caching,
concurrency, data processing, data structures, database, error handling,
file I/O, mathematics, memory management, messaging, parsing, patterns,
performance, resilience, security, string processing, system utilities,
type system, utilities, validation, web components) across 4 difficulty
levels (simple, medium, moderate, complex).

---

## Build and Run

```bash
# Build and test (Zig)
zig build test --summary all

# Build release binary
zig build -Doptimize=ReleaseSafe -p /tmp/ananke-build

# Rust tests (from maze/)
cargo test

# Deploy Modal inference
modal deploy maze/modal_inference/inference.py
```

CI runs 7 jobs: security, lint, coverage, ubuntu, macos, integration,
and gate. `zig fmt --check .` enforces formatting at the repository
root (including `build.zig`). `cargo fmt --check` enforces Rust
formatting in `maze/`.

One quirk: the `tree-sitter-zig` submodule always shows as dirty
(`m vendor/tree-sitter-zig` in `git status`). This is harmless -- a
generated file differs from what git expects. Do not commit it.
`tree-sitter-swift` is pinned to the `0.7.1-with-generated-files` tag
of the alex-pinkus fork (the upstream main branch lacks `parser.c`).

---

## Cross-References

| Document | What it covers |
|----------|---------------|
| `docs/CLASH_ALGEBRA.md` | Formal CLaSH domain definitions, tier semantics |
| `docs/DOMAIN_FUSION.md` | ASAp + CRANE fusion algorithm details |
| `docs/TYPE_INHABITATION.md` | Type system, inhabitation graph, mask generation |
| `docs/FIM_GUIDE.md` | Fill-in-the-middle mode usage and internals |
| `docs/HOMER_INTEGRATION.md` | Homer MCP integration, scope graph, call graph |
| `docs/FFI_GUIDE.md` | Zig/Rust FFI boundary details |
| `docs/EVAL_GUIDE.md` | Evaluation framework usage |
| `docs/spec/SPEC-01` through `SPEC-05` | Feature specifications |
| `docs/adr/ADR-001` through `ADR-007` | Architectural decision records |
