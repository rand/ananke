# Ananke System Architecture

Constraint-driven code generation treats AI output as search through valid program spaces. Instead of hoping a language model produces correct code and checking afterward, Ananke narrows the search space at every token so the model *cannot* produce invalid output. The constraint overhead per token is well under GPU forward-pass time. You pay nothing in throughput and get guarantees for free.

> "If you can't make it explicit, you can't control it. If you can't control it, you can't trust it. If you can't trust it, you can't ship it."

## Table of Contents

- [CLaSH Domain Architecture](#clash-domain-architecture)
- [System Components](#system-components)
  - [Clew: Constraint Extraction](#clew-constraint-extraction)
  - [Braid: Constraint Compilation](#braid-constraint-compilation)
  - [Ariadne: Constraint DSL](#ariadne-constraint-dsl)
  - [Maze: Inference Orchestration](#maze-inference-orchestration)
- [Data Flow](#data-flow)
- [Deployment](#deployment)
- [Performance](#performance)
- [Implementation Status](#implementation-status)
- [Cross-References](#cross-references)

---

## CLaSH Domain Architecture

CLaSH (Coordinated Logical and Semantic Holes) organizes constraints into five domains across two tiers. The key insight: constraints compose algebraically via a formal lattice. Hard constraints guarantee; soft constraints guide. This is not a metaphor -- the composition rules have lattice properties, and the system enforces them structurally.

### Hard Tier (binary, compose by intersection)

Hard constraints are pass/fail. A token either satisfies them or it does not. When multiple hard constraints apply, the valid set is their intersection. An empty intersection means the constraint set is infeasible, which Braid detects before generation begins.

| Domain | What it constrains | Enforcement mechanism |
|--------|-------------------|----------------------|
| **Syntax** | Grammar conformance at the cursor position | Earley parser / PDA tracking the parse state |
| **Types** | Well-typedness of the expression being generated | Prefix automata over type-valid continuations |
| **Imports** | Symbol availability from the scope graph | Vocabulary subset restricting to in-scope names |

### Soft Tier (graded 0.0--1.0, compose additively)

Soft constraints bias the distribution without blocking any token. They compose by weighted addition -- more evidence of a preference makes it stronger, but never absolute.

| Domain | What it captures | Examples |
|--------|-----------------|----------|
| **ControlFlow** | Error handling patterns, async/await conventions, loop idioms | "This codebase uses `Result<T, E>` not exceptions" |
| **Semantics** | Preconditions, postconditions, invariants | "The returned list is always sorted" |

### Composition Invariants

Three rules that the system enforces structurally, not by convention:

1. **Soft never blocks.** A soft constraint with score 0.0 still permits the token. Soft constraints adjust logits; they do not mask them.
2. **Cross-domain morphisms are monotonic.** A constraint flowing from one domain to another can only tighten the valid set, never widen it. This prevents circular relaxation.
3. **Soft-to-Hard promotion is forbidden.** There is no path by which a soft preference becomes a hard gate. If you want a hard constraint, declare it as one. The type system enforces this at compile time.

The full algebra -- including proofs of lattice closure, monotonicity, and distributivity -- is in [SPEC-01: CLaSH Algebra](spec/SPEC-01-clash-algebra.md).

---

## System Components

### Clew: Constraint Extraction

**Language**: Zig | **Location**: `src/clew/` | **Runs**: locally, no GPU

Clew mines constraints from source code. It supports 14 languages via tree-sitter AST parsing with a pattern-matching fallback:

**Tier 1** (9 languages, tree-sitter primary, 0.95 confidence):
TypeScript, JavaScript, Python, Rust, Go, Zig, C, C++, Java

These languages have mature tree-sitter grammars and comprehensive query coverage. The AST path handles all standard constructs; the pattern fallback activates only for edge cases (e.g., complex macro expansions in C/C++, decorator chains in Python).

**Tier 2** (5 languages, tree-sitter + pattern hybrid, 0.85 confidence):
Kotlin, C#, Ruby, PHP, Swift

Tier 2 languages have tree-sitter grammars that cover the core syntax but need pattern assistance for language-specific idioms -- Ruby's metaprogramming, PHP's mixed HTML/code boundaries, Kotlin's coroutine patterns. The 0.85 confidence floor means extraction results are still reliable enough for all five CLaSH domains; the slightly lower confidence adjusts how aggressively Braid trusts the extracted constraints during compilation.

All 14 parsers are compiled as static libraries and linked at build time via the Zig build system's C interop. No runtime parser loading, no dynamic dispatch on the hot path. Adding a new language means adding its tree-sitter grammar as a build dependency and implementing the extraction queries -- the pattern library and CLaSH domain tagging follow a template established by the existing languages.

#### Extraction Pipeline

The hybrid extraction architecture lives in two layers:

- **`src/clew/tree_sitter/`** -- AST-based extraction. Walks the concrete syntax tree to extract type bindings, function signatures, class definitions, imports, control flow patterns, and semantic constraints. This is the primary path for Tier 1 languages.
- **`src/clew/patterns.zig`** -- Pattern-matching fallback. 383 patterns across 14 languages (up from 101 across 5 in v0.1). Activates when tree-sitter produces low-confidence results or for language constructs that resist AST-level extraction.

#### Context Sources

Beyond direct extraction, Clew integrates several context sources:

- **Scope context** (`src/clew/scope_context.zig`): Cross-file name resolution via Homer's scope graph. Exports `ScopeBinding`, `BindingKind`, and `CanonicalImport` -- enough for the Imports domain to know what symbols are actually available, not just what's declared locally.
- **Call graph context** (`src/clew/call_graph_context.zig`): InlineCoder-style upstream callers and downstream callees. Gives the model awareness of how the code being generated will be called and what it will call.
- **Convention mining** (`src/clew/conventions.zig`): Extracts naming conventions, import ordering preferences, error handling patterns, documentation style, and code organization norms. These feed the soft CLaSH domains -- ControlFlow and Semantics -- so the model matches the codebase's existing style without being forced to.

#### Output

Clew produces a rich context bundle: `type_bindings`, `function_signatures`, `class_definitions`, `imports`, `control_flow`, and `semantic_constraints`. Each is tagged with its CLaSH domain and confidence level.

---

### Braid: Constraint Compilation

**Language**: Zig | **Location**: `src/braid/` | **Runs**: locally, no GPU

Braid compiles extracted constraints into the `ConstraintIR` format that Maze and llguidance consume. This is where the CLaSH algebra becomes concrete.

#### Core Compiler

**`src/braid/braid.zig`** orchestrates the full compilation pipeline: take a set of `Constraint` values, run them through feasibility analysis, salience scoring, temporal adjustment, domain fusion, and type inhabitation, then emit `ConstraintIR`. The compiler supports incremental recompilation (only recompute what changed) and an LRU constraint cache with clone-on-get semantics.

Conflict resolution has two modes: a deterministic default strategy (priority-based with domain ordering), and an optional Claude API call for genuinely ambiguous conflicts where human-like judgment helps.

#### Analysis Stages

Each stage enriches or filters the constraint set before final compilation:

**Feasibility analysis** (`src/braid/feasibility.zig`, 7 tests): Detects conflicts between constraints before they reach the model. Computes tightness scores (how close the constraint set is to infeasible) and identifies community-aware tension -- clusters of constraints that are individually satisfiable but collectively problematic.

**Salience scoring** (`src/braid/salience.zig`, 10 tests): Maps Homer's four-quadrant salience model (high/low importance x high/low urgency) into a normalized intensity + confidence pair. High-salience constraints get priority in soft-domain composition; low-salience constraints still apply but with reduced influence.

**Temporal analysis** (`src/braid/temporal.zig`, 7 tests): Classifies constraints by stability (stable, trending, volatile) using change history. Recent changes reduce confidence; long-stable constraints get a confidence boost. Co-change patterns from Homer inform which constraints are likely to shift together.

**Domain fusion** (`src/braid/domain_fusion.zig`, 13 tests): The main event. Two fusion strategies compose hard and soft constraints into a single token-level guidance signal:

- *ASAp* (Algebraic Soft-as-Prior): Distribution-preserving fusion. Hard constraints mask; soft constraints adjust the remaining probability mass proportionally. The model's original distribution is disturbed as little as possible while satisfying all constraints.
- *CRANE* (Constraint-Ranked Adaptive Normalization Engine): Adaptive switching. Under low constraint density, CRANE behaves like ASAp. Under high density, it becomes more aggressive, giving hard constraints earlier influence to avoid dead ends in the generation.

The system selects between them based on constraint density and tightness -- details in [DOMAIN_FUSION.md](DOMAIN_FUSION.md).

**Type inhabitation** (`src/braid/types/`, 24 tests across 4 modules): For the Types domain specifically, Braid builds an inhabitation graph from the type environment at the cursor. The four modules:

- `type_system.zig` -- `TypeArena` for efficient type allocation and structural equality
- `parser.zig` -- `TypeParser` for parsing type annotations from source
- `inhabitation.zig` -- `InhabitationGraph` for computing which types can be constructed from available values
- `mask_generator.zig` -- `MaskGenerator` for converting inhabitation results into token masks

The result: at each token position, only type-valid continuations are permitted.

**FIM analysis** (`src/braid/fim.zig`, 12 tests): For fill-in-the-middle completions (cursor in the middle of existing code), Braid analyzes both the prefix and suffix to constrain the hole. `PrefixAnalysis` determines the syntactic and type context leading in; `SuffixAnalysis` determines what the generated code must connect to. `HoleScale` classifies the expected completion size (expression, statement, block, function body) to calibrate constraint aggressiveness.

---

### Ariadne: Constraint DSL

**Language**: Zig | **Location**: `src/ariadne/` | **Status**: parsing complete, type checking deferred

Ariadne provides a declarative DSL for specifying constraint sets. It compiles to the same `ConstraintIR` that Braid produces, so downstream components (Maze, llguidance) are agnostic to the constraint source.

```ariadne
constraint secure_api inherits base_security {
    requires: authentication;
    validates: input_schema;
    forbid: ["eval", "exec", "system"];
}
```

The parser is complete; type checking is deferred. For production use today, Braid's programmatic API or JSON configuration are the recommended paths.

---

### Maze: Inference Orchestration

**Language**: Rust | **Location**: `maze/` | **Tests**: 144

Maze bridges the constraint world (Zig) to the inference world (Python/GPU). It has one job that matters: get `ConstraintIR` to the inference server and get constrained tokens back.

#### Architecture

- **Rust core** (`maze/src/`): Async orchestration with Tokio. Handles request routing, retry logic, backend auto-detection, and the FFI bridge to Zig.
- **Modal deployment** (`maze/modal_inference/inference.py`): Qwen2.5-Coder-32B-Instruct on A100-80GB with scale-to-zero. Two endpoints:
  - `/v1/chat/completions` -- OpenAI-compatible, with a `constraint_spec` extension field that carries the compiled CLaSH domains
  - `/generate` -- custom format for direct constraint control
- **Backend auto-detect**: sglang if configured, Modal as fallback. The system discovers available backends at startup and routes accordingly.

#### Constraint Delivery

The `constraint_spec` extension field in the OpenAI-compatible endpoint carries per-domain structured context as JSON. This is metadata for the inference server -- it tells llguidance what constraints to enforce. The `json_schema` field in `ConstraintIR` is structural metadata about the constraint shape, not an output-format constraint. Only EBNF grammars go to llguidance for token-level enforcement.

Maze uses sglang and vLLM as inference backends because constrained generation requires logit access. Managed APIs (Claude, OpenAI) do not expose raw logits, so they cannot participate in token-level constraint enforcement. They can, however, be used upstream for semantic analysis during extraction.

#### Rust Modules

The Maze codebase (`maze/src/`) is organized around specific concerns:

- `modal_client.rs` -- HTTP client for the Modal inference endpoint, with retry logic and error mapping
- `ffi.rs` -- FFI bridge to Zig core; marshals `ConstraintIR` across the language boundary
- `model_router.rs` and `model_selector.rs` -- backend discovery and request routing
- `adaptive_selector.rs` -- runtime strategy selection based on constraint density and latency history
- `telemetry.rs` -- structured logging for constraint application, latency tracking, and cache metrics
- `progressive_refinement.rs` -- foundation for bidirectional streaming (not yet fully wired)

---

## Data Flow

```
Source Code (14 languages)
    |
    v
Clew (tree-sitter AST + pattern fallback)
    |-- Constraints (tagged per CLaSH domain)
    |-- Rich Context (types, imports, control flow, semantics)
    |-- Homer Context (scope graph, salience, temporal, conventions, call graph)
    |
    v
Braid
    |-- Feasibility analysis (conflict detection, tightness scoring)
    |-- Salience scoring (Homer quadrant -> intensity + confidence)
    |-- Temporal analysis (stability class -> confidence adjustment)
    |-- CLaSH domain compilation
    |   |-- Hard: Syntax mask, Types mask, Imports mask
    |   +-- Soft: ControlFlow scores, Semantics scores
    |-- Domain Fusion (ASAp + CRANE adaptive selection)
    |-- Type Inhabitation (if Types domain active)
    |-- FIM Analysis (if fill-in-the-middle mode)
    |
    v
ConstraintIR + ConstraintSpec (JSON)
    |
    v
Maze / sglang
    |-- OpenAI-compatible endpoint with constraint_spec extension
    |-- llguidance token-level enforcement
    |-- Hard masks applied per-token; soft scores adjust logits
    |
    v
Generated Code (constraint-validated)
```

The entire pipeline from source to `ConstraintIR` runs locally with no GPU. Network calls happen only at inference time (Maze to sglang/Modal) and optionally during extraction (Claude API for semantic analysis, Homer for scope/salience/temporal data).

A few things worth noting about the flow:

**Incremental by default.** When a file changes, Clew re-extracts only that file's constraints. Braid's cache means unchanged constraint sets skip recompilation entirely. In a typical editing session, the end-to-end latency from keystroke to updated `ConstraintIR` is dominated by tree-sitter parsing (~10 ms), not by compilation.

**Fail-open on context.** Homer context (scope graph, salience, temporal, call graph) enriches the constraint set but is not required. If Homer is unavailable, Clew falls back to file-local extraction. The constraint set is narrower but still valid -- you lose cross-file awareness, not correctness.

**FIM is a mode, not a different pipeline.** Fill-in-the-middle requests follow the same data flow. The difference is that Braid's FIM analysis adds suffix-derived constraints alongside the prefix-derived ones, and `HoleScale` adjusts how tightly those constraints bind. A small hole (expression-level) gets tight constraints; a large hole (function body) gets looser ones to avoid over-constraining the model.

---

## Deployment

### Local Development

```
Developer Machine
+-- Ananke CLI (Zig binary, ~4MB)
|   +-- Clew (extraction)
|   +-- Braid (compilation)
|   +-- Ariadne (DSL, optional)
+-- Maze (Rust binary)
+-- API keys (Modal, optionally Claude/Homer)
```

Eight CLI commands: `extract`, `compile`, `generate`, `validate`, `export-spec`, `init`, `version`, `help`.

FIM mode is available via `--fim --prefix <prefix> --suffix <suffix>` on the `generate` command.

### Production

The inference service runs on Modal with scale-to-zero:

| Parameter | Value |
|-----------|-------|
| Model | Qwen2.5-Coder-32B-Instruct |
| GPU | A100-80GB |
| Scale | 0 to N (auto) |
| Endpoints | `https://rand--v1-chat-completions.modal.run` (OpenAI-compat) |
| | `https://rand--ananke-inference-generate-api.modal.run` (custom) |

Backend selection is automatic: the system checks for a local sglang instance first, then falls back to Modal. Configuration lives in `maze/modal_inference/config.yaml`.

### Why Modal

Scale-to-zero matters. A100-80GB GPUs cost real money when idle. Modal spins up an instance on the first request and tears it down after a configurable idle timeout (currently 2 minutes for development, longer for production). Cold start is noticeable (~30 seconds for model loading), but warm inference is fast. For a development tool that sees bursty usage -- intense for an hour, idle for three -- this beats a persistent GPU allocation on cost by an order of magnitude.

### Evaluation Infrastructure

The eval framework (`eval/core/evaluator.zig`) supports multi-sample pass@k estimation: generate N completions, check how many pass a test suite, compute the unbiased pass@k estimator. `BatchEvaluationResult` aggregates across task categories with statistical significance tests (paired t-test, bootstrap confidence intervals). This is how we verify that constraint changes actually improve generation quality rather than just changing it.

---

## Performance

| Operation | Measured Latency |
|-----------|-----------------|
| Constraint extraction (per file) | ~10 ms |
| Constraint compilation | ~1 ms |
| Token-level enforcement (llguidance) | ~50 us/token |
| Hard domain fusion | ~10 us/token |
| Cache hit (LRU, clone-on-get) | ~5--15 us |
| Homer queries (amortized) | <5% of inference time |

For context, GPU forward-pass time for a 32B parameter model is roughly 10 ms/token. The total constraint overhead per token -- fusion, masking, type checking -- is under 100 us. That is 1% of inference time. Throughput impact: zero.

The LRU cache deserves a note. Braid caches compiled `ConstraintIR` keyed on the input constraint set's content hash. On a cache hit, it clones the result (no shared mutable state) in 5--15 us. Typical hit rates exceed 80% during interactive editing sessions where the file's constraint environment changes incrementally.

---

## Implementation Status

### By the Numbers

| Metric | Count |
|--------|-------|
| Tests (Zig + Rust) | 617 (473 + 144) |
| Test failures | 0 |
| Memory leaks | 0 |
| Supported languages | 14 |
| Constraint patterns | 383 |
| CLaSH domains | 5 (3 hard, 2 soft) |
| CLI commands | 8 |

### Complete

- **CLaSH algebra**: Five-domain, two-tier constraint lattice with formal composition rules
- **Domain fusion**: ASAp distribution-preserving + CRANE adaptive switching
- **Type inhabitation**: TypeArena, TypeParser, InhabitationGraph, MaskGenerator
- **FIM support**: Prefix/suffix analysis, hole-scale classification
- **Homer integration**: Scope graph, salience scoring, temporal analysis, convention mining, call graph context
- **sglang backend**: OpenAI-compatible endpoint with `constraint_spec` extension
- **Modal deployment**: Qwen2.5-Coder-32B-Instruct on A100-80GB, scale-to-zero
- **Evaluation framework**: Multi-sample pass@k, statistical significance tests, batch evaluation, extended task categories
- **14-language extraction**: Tier 1 (9 languages, AST-primary) + Tier 2 (5 languages, hybrid)

### Planned

- **Ariadne type checking**: Parser works; type system deferred
- **Bidirectional streaming**: Progressive constraint refinement during generation
- **Multi-model orchestration**: Route different constraint profiles to different models
- **Distributed constraint cache**: Currently single-machine, in-memory only

---

## Design Decisions

A few choices that are non-obvious and worth explaining.

**Zig for extraction and compilation, Rust for orchestration.** Clew and Braid are pure computation -- parse trees, constraint graphs, mask generation. Zig's comptime, explicit allocators, and C interop (critical for tree-sitter) make it the right tool. Maze is I/O-bound -- HTTP clients, async request routing, FFI marshaling. Rust's async ecosystem (Tokio) and the PyO3 bridge to Python make it the right tool there. The boundary is clean: Zig produces `ConstraintIR` as a serializable struct; Rust consumes it.

**Two-tier constraint classification is structural, not cosmetic.** We tried a single-tier system with priority levels. It didn't work. The fundamental issue: if a "soft" constraint can accidentally block a token (because someone set its priority high enough), you get silent infeasibility that manifests as empty completions or degenerate output. The hard/soft split makes this impossible by construction. Hard constraints mask tokens out of the vocabulary; soft constraints adjust logit values. Different mechanisms, not different priority levels.

**ASAp as default, CRANE as escalation.** ASAp preserves the model's original probability distribution as much as possible -- it only removes probability mass (hard masks) and rescales what remains (soft adjustments). This is conservative and safe. CRANE activates under high constraint density where ASAp's conservative approach leads to generation dead ends (the model commits to a token sequence that becomes infeasible three tokens later). CRANE looks ahead and applies hard constraints more aggressively to avoid these traps. The selection is automatic based on constraint tightness.

**Convention mining feeds soft constraints, never hard.** When Clew discovers that a codebase uses `camelCase` for functions, this becomes a Semantics-domain soft constraint, not a Syntax-domain hard constraint. The model is nudged toward `camelCase` but can use `snake_case` if the type system or API requires it. Getting this wrong -- making style conventions into hard constraints -- was an early mistake that produced syntactically valid but contextually absurd code.

---

## Cross-References

| Document | Contents |
|----------|----------|
| [SPEC-01: CLaSH Algebra](spec/SPEC-01-clash-algebra.md) | Formal lattice properties, composition proofs, domain morphisms |
| [SPEC-02: sglang Integration](spec/SPEC-02-sglang-integration.md) | Backend protocol, `constraint_spec` format, endpoint design |
| [SPEC-03: Rich Context](spec/SPEC-03-rich-context.md) | Context bundle format, extraction pipeline, confidence scoring |
| [SPEC-04: Homer Integration](spec/SPEC-04-homer-integration.md) | Scope graph, salience, temporal analysis, convention mining |
| [SPEC-05: Domain Fusion](spec/SPEC-05-domain-fusion.md) | ASAp and CRANE algorithms, adaptive selection, benchmarks |
| [CLASH_ALGEBRA.md](CLASH_ALGEBRA.md) | 5-domain, 2-tier constraint algebra |
| [DOMAIN_FUSION.md](DOMAIN_FUSION.md) | Domain fusion implementation guide |
| [TYPE_INHABITATION.md](TYPE_INHABITATION.md) | Type-directed token mask generation |
| [DEPLOYMENT.md](DEPLOYMENT.md) | Modal setup, GPU configuration, endpoint management |
| [CLI_GUIDE.md](CLI_GUIDE.md) | All 8 commands with examples |
| [FFI_GUIDE.md](FFI_GUIDE.md) | Zig-Rust FFI boundary, data marshaling |
| [EXTENDING.md](EXTENDING.md) | Adding languages, constraint types, extractors |
