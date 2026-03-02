# Ananke

Constraint-driven code generation: define what valid code looks like, enforce it at the token level.

## What is Ananke?

Code generation is fast and fluent. The hard part is that it's wrong in the ways that matter: violated invariants, ignored conventions, misused APIs. The patterns your team has learned the hard way, encoded nowhere but everywhere in practice.

The standard fix is more context. Longer prompts. Better retrieval. But the constraints that matter are often implicit: organizational standards nobody documented, architectural patterns spread across dozens of files, lessons from production incidents living in postmortems and Slack threads. You can't retrieve what was never written down.

Ananke takes a different approach: treat code generation as constrained search, not token prediction with post-hoc repair. Extract constraints from the codebase. Compile them into a constraint algebra. Enforce them at the token level during generation. Hard constraints are exact: tokens that violate syntax, type, or import rules cannot be generated. Soft constraints bias the model toward your conventions without blocking alternatives. Code satisfies your requirements by construction, not by luck.

## How It Works

```
                        Homer (Rust)
                        ├ Scope graphs (13 langs)
                        ├ Centrality / Salience
                        ├ Temporal / Stability
                        └ Communities / Conventions
                              │
                          MCP or Rust FFI
                              │
                              v
Source code ──> Clew (tree-sitter) + Repository Context
                 │                         │
                 ├ SyntaxStructure         ├ ScopeContext (cross-file bindings)
                 │ (local AST data)        ├ Salience (per-entity importance)
                 │                         ├ Stability (temporal confidence)
                 └ Constraints             └ Conventions (empirical patterns)
                              │
                              v
                           Braid
                 ┌─────────────────────────────────────────────────┐
                 │ Feasibility   (community-aware satisfiability)  │
                 │ Priority      (salience-weighted)               │
                 │ Confidence    (stability-informed)              │
                 │ Morphisms     (cross-domain propagation)        │
                 └─────────────────────────────────────────────────┘
                              │
                  ConstraintIR + RichContext
                              │
                      ConstraintSpec JSON
                              │
                              v
                 ┌─────────────────────────────────────────────────┐
                 │ sglang + Ananke Backend                         │
                 └─────────────────────────────────────────────────┘
                              │
                              v
                 ┌─────────────────────────────────────────────────┐
                 │ Per-Token Mask Fusion                           │
                 │                                                 │
                 │ Syntax   ∩  Earley/PDA        (hard, exact)     │
                 │ Types    ∩  prefix automata   (hard, exact)     │
                 │ Imports  ∩  vocab subset      (hard, exact)     │
                 │ ─────────────────────────────────────────────── │
                 │ CtrlFlow ⊕  score reweighting (soft)            │
                 │ Semantic ⊕  score reweighting (soft)            │
                 └─────────────────────────────────────────────────┘
                              │
                       Shaped generation
                              │
                       Verified output
```

**Clew** (Zig) extracts constraints from source code via tree-sitter AST parsing across 14 languages (9 Tier 1 with full AST coverage, 5 Tier 2 with pattern-assisted extraction). It produces syntax structure, type bindings, import graphs, and control flow patterns. When Homer is available, Clew integrates cross-file context: scope graphs for name resolution, salience scores for prioritization, stability metrics from change history, and conventions mined from the codebase.

**Braid** (Zig) compiles extracted constraints into per-token decisions. Feasibility analysis detects constraint conflicts before they reach the model. Salience scoring prioritizes high-importance constraints. Temporal analysis adjusts confidence based on code stability. Cross-domain morphisms propagate information between constraint domains: type annotations imply imports; return types imply error handling patterns. The output is a ConstraintIR that downstream components consume.

**Maze** (Rust) orchestrates constrained generation via sglang/vLLM + llguidance. At decode time, five CLaSH domains fuse into a single per-token decision: three hard domains (Syntax, Types, Imports) compose by intersection; two soft domains (ControlFlow, Semantics) reweight the distribution within the feasible set. Constraint overhead adds less than 50us per token. Negligible against GPU forward pass time.

**Ariadne** (Zig) provides a declarative DSL for specifying constraints directly, compiling to the same ConstraintIR that Braid produces.

## Quick Start

```bash
# Clone and build
git clone --recurse-submodules https://github.com/rand/ananke.git
cd ananke && zig build

# Run all tests (617 tests, 0 failures)
zig build test --summary all
cd maze && cargo test && cd ..

# Extract constraints from source code
./zig-out/bin/ananke extract path/to/code.ts

# Compile to constraint IR
./zig-out/bin/ananke compile path/to/code.ts

# Generate with constraints (requires sglang or Modal endpoint)
./zig-out/bin/ananke generate "Implement authentication" \
    --context path/to/code.ts --backend sglang
```

### Requirements

- **Zig 0.15.2+**: [ziglang.org/download](https://ziglang.org/download/)
- **Rust 1.70+**: for the Maze orchestration layer

### Optional

- **Anthropic API Key**: for semantic analysis (`export ANTHROPIC_API_KEY='...'`)
- **Modal**: for GPU inference (`modal deploy maze/modal_inference/inference.py`)
- **Homer**: for repository intelligence (scope graphs, salience, temporal analysis)

## CLaSH: The Constraint Algebra

Five constraint domains in two tiers:

| Domain | Tier | Compilation Target | What It Catches |
|--------|------|--------------------|-----------------|
| **Syntax** | Hard | Earley parser / PDA | Grammar violations |
| **Types** | Hard | Prefix automata | Type errors at the hole |
| **Imports** | Hard | Vocabulary subset mask | Unavailable symbols |
| **ControlFlow** | Soft | Logit adjustments | Error handling, async patterns |
| **Semantics** | Soft | Logit adjustments | Pre/postconditions, invariants |

Hard constraints compose by intersection: if any hard domain rejects a token, it cannot be generated. Soft constraints compose additively within the feasible set, biasing the distribution without blocking alternatives. This separation is the key architectural invariant: adding soft constraints can never make a satisfiable constraint set unsatisfiable.

See [docs/CLASH_ALGEBRA.md](docs/CLASH_ALGEBRA.md) for the full algebra, and [docs/DOMAIN_FUSION.md](docs/DOMAIN_FUSION.md) for how five domains fuse into one per-token decision.

## What's New in v0.2.0

v0.1.0 extracted constraints and compiled them. v0.2.0 makes them compose.

**CLaSH** is a 5-domain constraint algebra with formal lattice properties. Hard domains (Syntax, Types, Imports) compose by intersection: if any domain rejects a token, it can't be generated. Soft domains (ControlFlow, Semantics) bias the distribution without blocking. The key invariant: adding soft constraints can never make a satisfiable set unsatisfiable.

**Domain fusion** combines all five domains into a single per-token decision. Hard domains fuse via exact mask intersection (~10us/token). Soft domains fuse via additive logit reweighting within the feasible set. CRANE-style adaptive switching relaxes constraints during reasoning tokens and tightens them for structured output.

**Type inhabitation** answers: given a target type, which expressions in scope can produce it? The inhabitation graph does BFS reachability over 9 edge kinds across 10 languages, then generates token masks from the reachable set.

**FIM** (fill-in-the-middle) constrains IDE completions by quotienting: left-quotient the grammar by the prefix, right-quotient by the suffix, generate only in the residual.

**Homer integration** brings cross-file intelligence: scope graphs for name resolution, call graph context (upstream callers + downstream callees), four-quadrant salience scoring, temporal analysis, and convention mining. All optional; the system degrades gracefully without it.

**5 new languages** (Kotlin, C#, Ruby, PHP, Swift) bring the total to 14, with 383 patterns across all extractors.

**sglang backend** with OpenAI-compatible endpoint and `constraint_spec` extension field. Tests went from 301 to 617 (473 Zig + 144 Rust), zero failures.

See [CHANGELOG.md](CHANGELOG.md) for the full list.

## Documentation

| Document | Description |
|----------|-------------|
| [QUICKSTART.md](QUICKSTART.md) | 10-minute getting started guide |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | System design and data flow |
| [docs/CLASH_ALGEBRA.md](docs/CLASH_ALGEBRA.md) | CLaSH constraint algebra (5 domains, 2 tiers) |
| [docs/DOMAIN_FUSION.md](docs/DOMAIN_FUSION.md) | How 5 domains fuse into 1 per-token decision |
| [docs/TYPE_INHABITATION.md](docs/TYPE_INHABITATION.md) | Type-directed token mask generation |
| [docs/FIM_GUIDE.md](docs/FIM_GUIDE.md) | Fill-in-the-middle for IDE completions |
| [docs/HOMER_INTEGRATION.md](docs/HOMER_INTEGRATION.md) | Repository intelligence via Homer |
| [docs/LANGUAGE_SUPPORT.md](docs/LANGUAGE_SUPPORT.md) | 14-language support matrix |
| [docs/CLI_GUIDE.md](docs/CLI_GUIDE.md) | Command-line reference |
| [docs/EVAL_GUIDE.md](docs/EVAL_GUIDE.md) | Evaluation framework guide |
| [docs/API_REFERENCE_ZIG.md](docs/API_REFERENCE_ZIG.md) | Zig library API |
| [docs/INTERNALS.md](docs/INTERNALS.md) | Implementation deep dive |

## Examples

```bash
examples/
├── 01-simple-extraction/  # Constraint extraction, no external services
├── 02-claude-analysis/    # Semantic analysis with Claude
├── 03-ariadne-dsl/        # Constraint DSL
├── 04-full-pipeline/      # End-to-end generation
└── 05-mixed-mode/         # Combined constraint sources
```

## Editor Support

- **[ananke-vscode](https://github.com/rand/ananke-vscode)**: VS Code / Cursor extension
- **[ananke-nvim](https://github.com/rand/ananke-nvim)**: Neovim plugin
- **[ananke-lsp](https://github.com/rand/ananke-lsp)**: Language Server Protocol implementation

## License

All Rights Reserved. Copyright (c) 2025 Rand Arete

## Acknowledgments

Built on: [llguidance](https://github.com/guidance-ai/llguidance) (token-level constraint enforcement), [vLLM](https://github.com/vllm-project/vllm) / [sglang](https://github.com/sgl-project/sglang) (inference), [tree-sitter](https://tree-sitter.github.io/tree-sitter/) (syntax parsing).

Informed by: ASAp (NeurIPS 2024, distribution-preserving constrained decoding), CRANE (ICML 2025, adaptive constraint switching), InlineCoder (2026, call graph context inlining).
