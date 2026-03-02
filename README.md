# Ananke

Constraint-driven code generation: define what valid code looks like, enforce it at the token level.

## What is Ananke?

AI code generation is probabilistic. You prompt a model, hope it follows your patterns, and review what comes back. When it doesn't (wrong types, missing error handling, violated conventions), you iterate. Ananke eliminates the iteration.

Ananke extracts constraints from your codebase (types, imports, conventions, control flow), compiles them into a constraint algebra called **CLaSH** (Coordinated Logical and Semantic Holes), and enforces them during generation. Tokens that violate hard constraints cannot be generated. Soft constraints bias the model toward your conventions without blocking alternatives. The result is code that satisfies your requirements by construction.

The system spans 14 languages, composes constraints across 5 domains with formal lattice properties, and adds less than 50us per token to inference. Negligible against GPU forward pass time.

## Core Components

| Component | Language | Purpose |
|-----------|----------|---------|
| **Clew** | Zig | Extract constraints from code via tree-sitter AST across 14 languages |
| **Braid** | Zig | Compile constraints into CLaSH domains, fuse into per-token decisions |
| **Ariadne** | Zig | Constraint DSL for declarative specifications |
| **Maze** | Rust | Orchestrate constrained generation via sglang/vLLM + llguidance |

## Architecture

```
Source Code ──→ Clew (14 langs, tree-sitter + patterns)
                  │
                  ├─ Constraints
                  ├─ Rich Context (types, imports, scope graph, call graph)
                  ├─ Homer Context (salience, temporal, conventions)
                  ↓
              Braid (CLaSH Constraint Algebra)
                  │
                  ├─ Hard Domains ─→ Syntax │ Types │ Imports
                  │   (binary pass/fail, compose by intersection)
                  │
                  ├─ Soft Domains ─→ ControlFlow │ Semantics
                  │   (graded 0.0–1.0, additive logit reweighting)
                  │
                  ├─ Domain Fusion (ASAp + CRANE)
                  ├─ Type Inhabitation
                  ├─ FIM (fill-in-the-middle)
                  ↓
              Maze ──→ sglang/vLLM + llguidance ──→ Generated Code
                       (constraint-validated, token by token)
```

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

## Typed Holes

Typed holes are explicit markers for incomplete code that carry type information, constraints, and metadata. Ananke detects them, compiles their constraints, and fills them progressively:

```python
def authenticate(user: User) -> AuthResult:
    # HOLE: validate credentials
    # Scale: function
    # Constraints: must check password hash, return AuthResult
    pass
```

Hole scale (`expression`, `statement`, `block`, `function`, `module`) maps to constraint intensity. Smaller holes get tighter constraints because the surrounding context provides more signal.

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

## Project Status

**617 tests** (473 Zig + 144 Rust), zero memory leaks, zero failures.

### Complete

- Constraint extraction across **14 languages** (tree-sitter AST + pattern fallback)
- CLaSH 5-domain constraint algebra with formal lattice properties
- Domain fusion (ASAp distribution-preserving + CRANE adaptive switching)
- Type inhabitation system (TypeArena, TypeParser, InhabitationGraph, MaskGenerator)
- Fill-in-the-middle (FIM) constrained decoding for IDE completions
- Homer integration (scope graphs, salience scoring, temporal analysis, conventions, call graph context)
- sglang backend with OpenAI-compatible endpoint
- Evaluation framework (multi-sample pass@k, statistical significance tests, batch evaluation)
- CLI with 8 commands (extract, compile, generate, validate, export-spec, init, version, help)
- Ariadne constraint DSL (parsing complete)
- Modal GPU inference (Qwen2.5-Coder-32B-Instruct on A100-80GB)

### Planned

- Ariadne DSL type checking
- Bidirectional streaming generation
- Multi-model orchestration
- Web UI

## Language Support

| Tier | Languages | Method | Confidence |
|------|-----------|--------|------------|
| **Tier 1** | TypeScript, JavaScript, Python, Rust, Go, Zig, C, C++, Java | tree-sitter AST | 0.95 |
| **Tier 2** | Kotlin, C#, Ruby, PHP, Swift | tree-sitter + patterns | 0.85 |

All 14 languages support constraint extraction, type analysis, and CLaSH domain compilation. See [docs/LANGUAGE_SUPPORT.md](docs/LANGUAGE_SUPPORT.md) for details.

## Performance

| Operation | Achieved |
|-----------|----------|
| Constraint extraction | ~10ms per file |
| Constraint compilation | ~1ms |
| Token-level enforcement | ~50μs/token |
| Cache hit latency | ~5–15μs |
| Hard domain fusion | ~10μs/token |
| Homer queries (amortized) | <5% of inference time |

Total constraint overhead per token is well under GPU forward pass time. Zero throughput impact.

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
