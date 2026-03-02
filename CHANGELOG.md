# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-03-02

### Added

#### CLaSH 5-Domain Constraint Algebra
- Formal constraint lattice with bounded meet-semilattice properties (commutativity, associativity, idempotency, bottom propagation)
- Five constraint domains in two tiers:
  - **Hard tier** (binary pass/fail): Syntax (Earley parser/PDA), Types (prefix automata), Imports (vocabulary subset masks)
  - **Soft tier** (graded 0.0–1.0): ControlFlow (error handling, async patterns), Semantics (pre/postconditions, invariants)
- Cross-domain morphisms: bidirectional (Types ↔ Imports), one-way (Hard → Soft), with monotonicity guarantee
- Architectural invariant: soft constraints never block generation — adding soft constraints cannot make a satisfiable set unsatisfiable
- Adaptive intensity levels: NONE, SYNTAX_ONLY, STANDARD, FULL_HARD, FULL, EXHAUSTIVE
- Domain shedding under latency pressure: Semantics → ControlFlow → Imports (Syntax is the floor)
- `src/braid/domain_fusion.zig` — 13 tests

#### Domain Fusion (ASAp + CRANE)
- Distribution-preserving hard domain fusion via exact intersection (~10μs/token, ~48KB memory bandwidth)
- Relaxation cascade on empty intersection: drop Imports → Types → Syntax-only → unconstrained
- Soft domain fusion via additive logit reweighting within the feasible set (not multiplicative — preserves conditional distribution shape)
- CRANE-style adaptive switching: relaxed constraints during reasoning tokens, full constraints for structured output
- Generation phase detection: reasoning, structured_output, transition
- Configurable soft weights and temperature
- `src/braid/domain_fusion.zig` — 13 tests

#### Type Inhabitation System
- Arena-allocated cross-language type representation (TypeArena) supporting 10 languages
- Type enum: Primitive (20 variants), Array, Tuple, Object, Function, Union, Intersection, Optional, Named, Generic, Reference, ErrorUnion
- TypeParser: parses string type signatures from TypeScript, Python, Rust, Go, Java, C++, C#, Kotlin, Zig into unified representation
- InhabitationGraph: BFS reachability analysis with 9 edge kinds (Coercion, BinaryOp, Property, Method, Application, Indexing, Construction, Template, Assertion)
- Per-language builtin edge sets (TypeScript, Python, Rust, Go, Java, C++, C#, Kotlin, Zig)
- MaskGenerator: converts inhabitation analysis to token masks for constrained decoding
- TypeInhabitationState: progressive generation state tracking
- `src/braid/types/` — 24 tests across 4 modules (type_system, parser, inhabitation, mask_generator)

#### Fill-in-the-Middle (FIM) Constrained Decoding
- IDE-quality FIM via grammar quotienting: left-quotient by prefix, right-quotient by suffix
- FimContext with prefix, suffix, language, hole_scale, file_path, cursor position
- PrefixAnalysis: delimiter balance, string/comment state, indentation tracking
- SuffixAnalysis: leading close-delimiters, first token detection, trailing newline requirement
- HoleScale enum: expression, statement, block, function, module — maps to constraint intensity
- CLI support: `ananke generate --fim --prefix "..." --suffix "..." --language zig`
- `src/braid/fim.zig` — 12 tests

#### Homer Repository Intelligence Integration
- Scope context from Homer scope graphs: cross-file name resolution, canonical imports, binding kinds (type_definition, function, variable, module, type_alias)
- Call graph context (InlineCoder-style): upstream callers (up to 3) + downstream callees (up to 5), with argument types and result usage
- Four-quadrant salience scoring (centrality × churn): FoundationalStable, ActiveHotspot, PeripheralActive, QuietLeaf
- Composite salience weights: PageRank 30%, betweenness 15%, HITS 15%, churn 15%, bus factor 10%, code size 5%, test presence 10%
- Salience-based intensity selection: FoundationalStable → FULL_HARD, ActiveHotspot → FULL, PeripheralActive → STANDARD, QuietLeaf → SYNTAX_ONLY
- Temporal analysis: stability classes (StableCore, ActiveCore, StableLeaf, ActiveLeaf), centrality trends, co-change partners (Jaccard similarity)
- Convention mining: naming, import ordering, error handling, documentation, code organization → soft-tier CLaSH constraints
- All Homer context is optional — system degrades gracefully without it
- `src/clew/scope_context.zig` — 11 tests
- `src/clew/call_graph_context.zig` — 7 tests
- `src/braid/salience.zig` — 10 tests
- `src/braid/temporal.zig` — 7 tests
- `src/clew/conventions.zig` — 5 tests

#### 5 New Language Extractors (14 Total)
- Kotlin: tree-sitter AST + 25 patterns
- C#: tree-sitter AST + 26 patterns
- Ruby: tree-sitter AST + 16 patterns
- PHP: tree-sitter AST + 22 patterns
- Swift: tree-sitter AST + 24 patterns (alex-pinkus fork, v0.7.1 tag)
- Total patterns across 14 languages: 383 (up from 101 across 5)
- All languages support full CLaSH domain compilation

#### sglang Backend
- OpenAI-compatible HTTP endpoint with `constraint_spec` extension field
- ConstraintSpec carries per-domain structured context: type_bindings, function_signatures, class_definitions, imports, control_flow, semantic_constraints, scope_bindings
- Backend auto-detection: sglang (if configured) → Modal (fallback)
- `export-spec` command: one-shot pipeline (extract + compile + rich context → ConstraintSpec JSON)
- Environment variable or `.ananke.toml` configuration

#### Evaluation Framework
- Multi-sample pass@k evaluation (configurable samples per task, default 5)
- Paired constrained vs. unconstrained comparison
- Statistical significance testing (paired t-test, p < 0.05)
- 24 task categories, 4 difficulty levels, 2 languages (TypeScript, Python)
- Quality scoring: correctness (60%), constraint adherence, pattern conformity, code quality, security
- Batch evaluation with aggregate statistics and effect size interpretation
- `eval/core/` — evaluator, task_spec, quality_scorer, pass_at_k, statistical_tests

#### Feasibility Analysis
- Constraint set satisfiability checking
- Conflict detection: mutual exclusion, ordering violations, semantic conflicts
- Tightness scoring with per-kind weights and keyword modifiers
- Community-aware feasibility: Louvain community detection, cross-community architectural tension flagging
- Relaxation priority ordering (syntactic first → security last)
- `src/braid/feasibility.zig` — 7 tests

#### Rich Context Export
- Parallel serialization path from tree-sitter ASTs preserving structured information
- RichContext struct: type_bindings_json, function_signatures_json, class_definitions_json, imports_json, control_flow_json, semantic_constraints_json, scope_bindings_json
- Control flow extraction: async, generator, loop depth, try/catch, error handling patterns
- Semantic constraint extraction: docstring keyword matching (requires/ensures/maintains)
- Cross-domain morphism implementation: Types ↔ Imports fixpoint loop

#### CLI Enhancements
- `export-spec` command: one-shot extract + compile + context → ConstraintSpec JSON
- FIM mode: `--fim --prefix --suffix --hole-scale --cursor-line --cursor-column`
- Backend selection: `--backend sglang|modal`
- Rich context: `--context <source-file>` for automatic extraction
- Total: 8 commands (added export-spec; help was already present)

### Changed
- Test count: 301 → 617 (473 Zig + 144 Rust, 113 build steps)
- Pattern count: 101 across 5 languages → 383 across 14 languages
- Constraint compilation now includes domain fusion, type inhabitation, and FIM analysis
- Braid pipeline: graph → IR now includes feasibility check, salience scoring, temporal analysis

### Fixed
- Tree-sitter integration fully working (was listed as "pending" in v0.1.0 known limitations)
- tree-sitter-swift pinned to v0.7.1 tagged release (alex-pinkus fork with generated parser.c)

---

## [0.1.0] - 2025-11-24

### Added

#### Constraint Extraction Engine (Clew)
- 101 constraint patterns across 5 languages
  - TypeScript/JavaScript (30 patterns)
  - Python (25 patterns)
  - Rust (20 patterns)
  - Go (15 patterns)
  - Zig (11 patterns)
- Static syntax analysis via tree-sitter
- Optional Claude API integration for semantic analysis
- Pattern-based constraint discovery (functions, types, security, async, control flow)
- Multi-source constraint aggregation
- HTTP client with retries and timeout handling
- 50+ passing unit tests

#### Constraint Compilation Engine (Braid)
- JSON Schema Draft 7 generation (src/braid/json_schema_builder.zig - 440 lines)
  - Comprehensive type parsing and conversion
  - Support for objects, arrays, unions, nested types
  - llguidance-compatible output
- Topological sort and dependency graphs
  - Kahn's algorithm for O(V+E) optimal dependency ordering
  - DFS-based cycle detection
- Grammar building (EBNF rule generation)
  - Pattern-driven rule generation for functions, async, control flow
  - Syntactic constraint compilation
- Regex pattern extraction and optimization
  - Multi-pattern marker support
  - Case-insensitive matching with OR operator
- Security token masking
  - 5 security pattern categories (credentials, URLs, file paths, SQL, code execution)
  - Token-level constraint rules
- Constraint operations (merge, deduplicate, prioritize)
- 31 passing unit tests

#### Orchestration Layer (Maze)
- Production-ready Modal GPU inference service
- vLLM 0.11.0 + llguidance 0.7.11 deployment
- Working endpoint: https://<YOUR_MODAL_WORKSPACE>--ananke-inference-generate-api.modal.run
- JSON Schema constraint enforcement (V1 structured outputs)
- Context-free grammar constraints
- Regex pattern constraints
- Token mask support
- Environment-based cost controls (dev/demo/prod modes)
- Scale-to-zero architecture (cost: $4.09/hr active)
- FastAPI web interface with health check
- 805-line comprehensive documentation

#### Core Type System
- Constraint types with 6 categories (syntactic, type_safety, semantic, architectural, operational, security)
- ConstraintSource union with 11 source types
- ConstraintPriority enum (Critical, High, Medium, Low, Optional)
- Severity levels (err, warning, info, hint)
- EnforcementType with 6 strategies
- ConstraintSet with deduplication and iteration
- ConstraintIR intermediate representation
- TokenMaskRules for token-level control
- 25 passing unit tests

#### Build System
- Comprehensive build.zig (334+ lines)
- Zig 0.15.2+ compatibility
- Multi-platform support (Linux, macOS, Windows)
- Module system for component isolation
- Integrated benchmarking infrastructure
- WebAssembly support (experimental)
- All core tests passing

#### CLI Interface
- 7 commands: extract, compile, generate, validate, init, version, help
- 4 output formats: pretty (default), json, compact, verbose
- Configuration file support
- Environment variable integration
- Streaming output support

#### Infrastructure
- GitHub Actions CI/CD pipeline
  - Multi-platform testing (Linux, macOS, Windows)
  - Automated benchmarking
  - Security auditing
- Docker containerization
  - Multi-stage builds
  - Production-optimized images
- Installation scripts for all platforms
- Performance benchmarking suite

#### Testing Infrastructure
- 120+ passing unit tests
- 26 integration test scenarios
- Memory leak detection (zero leaks)
- Segmentation fault elimination
- Performance benchmarking targets
- Comprehensive test strategy (1,409 lines in TEST_STRATEGY.md)

#### Documentation
- QUICKSTART.md (12,000+ words) - Getting started guide
- ARCHITECTURE.md - System design deep dive
- API_REFERENCE_ZIG.md - Zig library API (38,600 lines)
- API_REFERENCE_RUST.md (29,400 lines) - Maze Rust API
- CLI_GUIDE.md - Command reference
- DEPLOYMENT.md - Production deployment guide
- SECURITY.md - Security guidelines
- DEVELOPMENT_HISTORY.md - Development narrative
- FFI_GUIDE.md - Cross-language integration
- FAQ.md - Common questions
- Example projects (6 working examples)

### Fixed

#### Memory Leak Fixes
- Fixed 16 memory leaks in src/clew/clew.zig
- Changed allocPrint() to use constraintAllocator() arena
- All constraint strings now properly managed
- Result: 0 memory leaks verified after fixes

#### CI/CD Fixes
- Updated GitHub Actions workflows to setup-zig v2
- Fixed Zig 0.15.2 download compatibility
- Improved mirror support for reliable builds
- All workflows validated for YAML correctness

#### Zig Compatibility
- ArrayList API migration for Zig 0.15.x
- Updated append() error handling
- Fixed items field access (slice vs pointer)
- Build system modularization

### Performance

#### Achieved Metrics
- Modal inference: 22.3 tokens/sec with JSON schema constraints
- llguidance overhead: ~50μs per token
- Constraint validation: <1ms (type system)
- Extraction: <100ms for typical files
- Compilation: ~10-50ms for typical constraint sets
- Cache hit latency: ~0.5-1ms
- Memory overhead: ~45MB

#### Target Achievement
- Exceeded constraint validation target (50μs)
- Met extraction time target (<100ms)
- Met compilation time target (<50ms)
- Exceeded invalid output rate target (<0.1% vs 0.12% target)

### Infrastructure

#### Deployment
- Modal GPU infrastructure (A100-80GB)
- Qwen2.5-Coder-32B-Instruct model deployment
- Environment-based configuration
- HuggingFace token integration

#### Cost Controls
- Scale-to-zero architecture
- Development mode: 2-minute scaledown ($4.09/hr active)
- Demo mode: 10-minute scaledown
- Production mode: 5-minute scaledown

### Dependencies

#### Core Runtime
- Zig 0.15.2 or later
- Rust 1.70+ (for Maze)

#### Inference Service
- vLLM 0.11.0
- llguidance 0.7.11+
- PyTorch with CUDA support
- HuggingFace Transformers

#### Build Tools
- tree-sitter (vendored)
- Modal CLI (for deployment)
- Docker (optional)

### Known Limitations
- Tree-sitter integration pending upstream Zig 0.15.x compatibility
- Streaming generation: Basic implementation (full bidirectional in v0.2)
- Local GGUF model support: Planned for v0.2
- Windows CLI: Experimental (full support in v0.2)
- Multi-model orchestration: Planned for v0.2
- Web UI: Planned for v0.3

### Security
- No hardcoded credentials in source code
- Environment-based secret management
- Input validation on all API calls
- Rate limiting on inference endpoints
- HTTPS-only external API communication

### Contributing
- CONTRIBUTING.md with contribution guidelines
- Test requirements and standards
- Code style and formatting guidelines
- Commit message conventions

---

## Version History

[0.2.0]: https://github.com/ananke-ai/ananke/releases/tag/v0.2.0
[0.1.0]: https://github.com/ananke-ai/ananke/releases/tag/v0.1.0

## Release Template

For future releases, use this template:

```markdown
## [X.Y.Z] - YYYY-MM-DD

### Added
- New features and capabilities

### Changed
- Changes to existing functionality

### Deprecated
- Features marked for removal

### Removed
- Removed features

### Fixed
- Bug fixes

### Security
- Security improvements

### Performance
- Performance optimizations
```
