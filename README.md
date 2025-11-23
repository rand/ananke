# Ananke

> Constraint-driven code generation that transforms AI from probabilistic guessing into controlled search through valid program spaces.

[![CI](https://github.com/ananke-ai/ananke/actions/workflows/ci.yml/badge.svg)](https://github.com/ananke-ai/ananke/actions/workflows/ci.yml)
[![Maze Tests](https://github.com/ananke-ai/ananke/actions/workflows/maze-tests.yml/badge.svg)](https://github.com/ananke-ai/ananke/actions/workflows/maze-tests.yml)
[![Security](https://github.com/ananke-ai/ananke/actions/workflows/security.yml/badge.svg)](https://github.com/ananke-ai/ananke/actions/workflows/security.yml)
[![Docs](https://github.com/ananke-ai/ananke/actions/workflows/docs.yml/badge.svg)](https://github.com/ananke-ai/ananke/actions/workflows/docs.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Language: Zig](https://img.shields.io/badge/Language-Zig-blue.svg)](https://ziglang.org/)
[![Status: Early Development](https://img.shields.io/badge/Status-Early%20Development-orange.svg)](#current-project-status)

## Project Philosophy

If you can't make it explicit, you can't control it. If you can't control it, you can't trust it. If you can't trust it, you can't ship it.

Ananke enforces constraints at the **token level** during code generation, ensuring outputs always satisfy specified requirements. No more hoping the model will follow your patterns. You define the rules, Ananke enforces them.

---

## Quickstart (10 minutes)

Get started with constraint extraction and analysis in 10 minutes:

```bash
# Clone and build
git clone https://github.com/ananke-ai/ananke.git
cd ananke
zig build

# Run your first constraint extraction
cd examples/01-simple-extraction
zig build run

# Output: Extracted constraints from TypeScript code
# - Function signatures, types, security patterns
# - All under 100ms, no external services needed
```

**Want more?** See the [complete quickstart guide](QUICKSTART.md) for:
- Semantic analysis with Claude
- Combining multiple constraint sources
- Understanding the full pipeline
- Troubleshooting tips

### 5-Minute Quick Tour

**Extract constraints from code** (no external services needed):
```bash
cd examples/01-simple-extraction && zig build run
# Finds: function signatures, types, security patterns
```

**Add semantic analysis** (optional, requires Claude API):
```bash
export ANTHROPIC_API_KEY='your-key'
cd examples/02-claude-analysis && zig build run
# Finds: business rules, implicit constraints, intent
```

**Combine all approaches** (production-ready pattern):
```bash
cd examples/05-mixed-mode && zig build run
# Merges: extracted + JSON config + Ariadne DSL
```

**Read more**: [QUICKSTART.md](QUICKSTART.md) | [docs/USER_GUIDE.md](docs/USER_GUIDE.md)

---

## Overview

Ananke is a two-layer system for intelligent, constrained code generation:

1. **Analysis Layer** (Clew, Braid, Ariadne): Lightweight Zig binaries that extract constraints from code, tests, and documentation. Can leverage managed APIs (Claude, OpenAI) for semantic understanding.

2. **Generation Layer** (Maze + vLLM/SGLang + llguidance): GPU-powered constrained generation that applies constraints at the token level. Requires inference server control that managed APIs cannot provide.

This hybrid approach lets you use Claude for what it's great at (understanding code semantics, resolving conflicts) while maintaining token-level control where you need it (generation).

---

## Architecture at a Glance

```
User Code/Tests/Docs
        ↓
   ┌─────────────┐
   │ Clew/Braid  │ ← Optional: Claude API for semantic analysis
   │  (Zig)      │   Runs locally (no GPU needed)
   └──────┬──────┘
          ↓ Compiled ConstraintIR
   ┌─────────────┐
   │    Maze     │ ← Orchestration layer (Rust)
   │ (Rust/Py)   │   Coordinates constrained generation
   └──────┬──────┘
          ↓ API calls
   ┌─────────────────────────────┐
   │  Inference Service (Modal)  │ ← Required: vLLM + llguidance
   │  - GPU-accelerated          │   Token-level constraint enforcement
   │  - <50μs per token          │
   └─────────────────────────────┘
```

---

## When to Use Claude API vs Inference Server

### Claude API (Analysis Tasks) ✨
Use for understanding and extracting constraints:
- **Clew**: Semantic code analysis, pattern recognition from source
- **Braid**: Conflict resolution between constraints
- Trade-off: Fast, no GPU, per-API-call cost

**Examples:**
```python
# Understanding test intent to infer constraints
constraints = await clew.extract_from_tests(
    test_code,
    use_claude=True  # Semantic understanding
)

# Resolving conflicting constraints intelligently
resolved = await braid.compile(
    constraints,
    optimize_with_llm=True  # Claude suggests resolution
)
```

### Inference Server (Generation Tasks) ⚡
Use for token-level controlled generation:
- **Maze**: Constrained code generation on open models
- **Requirement**: vLLM + llguidance on GPU infrastructure
- Trade-off: Full control, token-level masking, ~$0.01-0.05/request

**Why not Claude here?** You need access to raw logits to apply token-by-token constraints. Managed APIs don't expose this level of control.

```python
# This MUST use constrained inference, not Claude
result = await maze.generate(
    intent="Add authentication middleware",
    constraints=compiled_ir,
    # Only works with controlled inference server
)
```

---

## Installation

### Prerequisites
- Zig 0.15.1+
- For generation: GPU infrastructure (Modal, RunPod, or local)
- Optional: Claude API key for analysis enhancements

### From Source

```bash
git clone https://github.com/ananke-ai/ananke.git
cd ananke

# Build all components
zig build

# Run tests
zig build test

# Build examples
zig build examples
```

### Using as a Library

Add to your `build.zig.zon`:

```zig
.ananke = .{
    .url = "https://github.com/ananke-ai/ananke/archive/refs/tags/v0.1.0.tar.gz",
    .hash = "12207...",
},
```

---

## Quick Start

### Pattern 1: Pure Local (No Claude, No GPU)

Extract constraints from your codebase, no external services:

```python
from ananke import Ananke

# Initialize with no external services
ananke = Ananke()

# Extract constraints from code (tree-sitter based)
constraints = await ananke.extract_from_code(
    source_file="src/handlers/auth.py",
    use_llm=False  # No Claude needed
)

# Compile constraints locally
compiled = await ananke.compile(
    constraints,
    optimize_with_llm=False  # No Claude needed
)

# Check: What constraints were found?
print(constraints)
# Output: {
#   "type_safety": {...},
#   "security_patterns": {...},
#   "architectural": {...}
# }
```

### Pattern 2: With Claude for Smarter Analysis

Use Claude for semantic understanding while keeping generation local (or deferred):

```python
ananke = Ananke(
    claude_api_key=os.getenv("ANTHROPIC_API_KEY"),
    # No modal endpoint yet - just analysis
)

# Claude helps understand complex test requirements
constraints = await ananke.extract_from_tests(
    test_code,
    use_claude=True  # "What constraints do these tests imply?"
)

# Claude can help resolve conflicts
compiled = await ananke.compile(
    constraints,
    optimize_with_llm=True  # "How should these constraints be prioritized?"
)
```

### Pattern 3: Full Pipeline (Analysis + Generation)

End-to-end with both Claude and constrained generation:

```python
ananke = Ananke(
    claude_api_key=os.getenv("ANTHROPIC_API_KEY"),
    modal_endpoint="https://ananke-inference.modal.run",
    model="meta-llama/Llama-3.1-8B-Instruct",
)

# 1. Extract constraints (optionally with Claude)
constraints = await ananke.extract_from_code(
    "./src",
    use_llm=True  # Claude: "What patterns does this code follow?"
)

# 2. Compile (optionally with Claude for optimization)
compiled = await ananke.compile(
    constraints,
    optimize_with_llm=True  # Claude: "How should these be ordered?"
)

# 3. Generate with constraints (requires vLLM + llguidance)
result = await ananke.generate(
    intent="Add JWT validation to the auth handler",
    constraints=compiled,
    temperature=0.7,
    max_tokens=500,
)

print(result.code)
# Output: Type-safe, validated code that follows all constraints
```

### Via Ariadne DSL

Optionally use our constraint DSL instead of JSON:

```ariadne
constraint secure_api {
    requires: authentication;
    validates: input_schema;
    forbid: ["eval", "exec"];
    max_complexity: 10;

    temporal: {
        timeout: 30s;
        retry_policy: exponential_backoff;
    }
}
```

Compile to ConstraintIR:

```zig
const compiler = AriadneCompiler{ .llm_client = null };
const ir = try compiler.compile(@embedFile("secure_api.ariadne"));
```

---

## Usage Examples

### CLI

```bash
# Extract constraints from codebase
ananke extract ./src --use-claude -o constraints.json

# Compile constraints
ananke compile constraints.json -o compiled.cir

# Generate code with constraints
ananke generate "implement user signup endpoint" \
    --constraints compiled.cir \
    --inference-url https://ananke-inference.modal.run \
    --temperature 0.7

# Validate generated code
ananke validate output.py compiled.cir
```

### Library API (Zig)

```zig
const ananke = @import("ananke");
const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize constraint engine
    var clew = try ananke.Clew.init(allocator, null);  // null = no Claude
    defer clew.deinit();

    // Extract from source code
    const source = @embedFile("handler.py");
    const constraints = try clew.extractFromCode(source);
    defer allocator.free(constraints);

    // Compile constraints
    var braid = try ananke.Braid.init(allocator);
    const compiled = try braid.compile(constraints);

    std.debug.print("Extracted {d} constraints\n", .{constraints.len});
}
```

### Library API (Python)

```python
import asyncio
from ananke import Clew, Braid, Maze

async def main():
    # Initialize
    clew = Clew(claude_api_key=None)
    braid = Braid()
    maze = Maze(
        endpoint="https://ananke-inference.modal.run",
        model="llama-3.1-8b"
    )

    # Extract constraints
    with open("auth.py") as f:
        source = f.read()
    constraints = await clew.extract(source)

    # Compile
    compiled = await braid.compile(constraints)

    # Generate
    result = await maze.generate(
        intent="Add rate limiting",
        constraints=compiled,
        max_tokens=200
    )

    print(f"Generated:\n{result.code}")
    print(f"Validation: {result.constraint_violations} violations")

if __name__ == "__main__":
    asyncio.run(main())
```

---

## Development Setup

### Build Commands

```bash
# Build everything
zig build -Doptimize=ReleaseSafe

# Run tests
zig build test

# Build with Claude integration
zig build -Dclause=true

# Build for WebAssembly
zig build -Dwasm=true
```

### Project Structure

```
ananke/
├── src/
│   ├── root.zig              # Main module export
│   ├── clew/                 # Constraint extraction
│   │   ├── clew.zig
│   │   ├── extractor.zig
│   │   └── tree_sitter.zig
│   ├── braid/                # Constraint compilation
│   │   ├── braid.zig
│   │   ├── graph.zig
│   │   └── compiler.zig
│   ├── ariadne/              # DSL compiler
│   │   ├── ariadne.zig
│   │   └── parser.zig
│   ├── maze/                 # Orchestration (Rust)
│   │   └── lib.rs
│   └── types/                # Shared types
│       ├── constraint.zig
│       └── constraint_ir.zig
├── docs/
│   ├── ARCHITECTURE.md       # System design
│   └── IMPLEMENTATION_PLAN.md # Development roadmap
├── beads/
│   └── implementation-phases.bead  # Task tracking
├── examples/
│   ├── pure-local/           # No external services
│   ├── with-claude-analysis/ # Claude for analysis
│   └── full-pipeline/        # Full end-to-end
└── build.zig                 # Build configuration
```

### Running Tests

```bash
# All tests
zig build test

# Specific test file
zig build test -- src/clew/tests.zig

# With coverage (requires kcov)
zig build test -- --coverage
```

### IDE Integration

- **VS Code**: Install `ziglang.vscode-zig` extension
- **Vim/Neovim**: Use `zig-lang/zig.vim`
- **Emacs**: Use `zig-mode`
- **LSP**: Built-in Zig language server support

---

## Current Project Status

**Phase**: Foundation & Research (Week 1)

**Completed:**
- Architecture specification
- Documentation structure
- Build system setup
- Core module scaffolding

**In Progress:**
- Constraint extraction engine (Clew)
- Constraint compilation engine (Braid)
- Test infrastructure

**Upcoming:**
- Ariadne DSL (Week 4)
- Maze orchestration layer (Weeks 5-6)
- Inference service deployment (Week 7)
- Integration patterns (Week 8)
- Testing & benchmarks (Week 9)
- Production deployment (Week 11)

**Target Launch**: 12 weeks from project start

See `/docs/IMPLEMENTATION_PLAN.md` for detailed roadmap.

---

## Architecture Deep Dive

### Clew: Constraint Extraction

Mines constraints from multiple sources using both static analysis and optional Claude integration:

```
Source Code → Tree-sitter parsing → Syntactic constraints
Tests       → Tree-sitter parsing → Type/behavior constraints
Telemetry   → Claude analysis      → Performance constraints
Docs        → Claude analysis      → Business rules
```

Constraint categories:
- **Syntactic**: Code structure, formatting, naming
- **Type**: Type safety, null checks, return types
- **Semantic**: Data flow, control flow, side effects
- **Architectural**: Module boundaries, layering
- **Operational**: Performance bounds, resource limits
- **Security**: Input validation, auth patterns

### Braid: Constraint Compilation

Transforms extracted constraints into efficient execution:

1. **Graph Construction**: Builds constraint dependency DAG
2. **Conflict Detection**: Identifies contradictions
3. **Resolution**: Finds valid ordering (with optional Claude help)
4. **Optimization**: SIMD-accelerated parallel validation
5. **Compilation**: Outputs ConstraintIR for llguidance

### Maze: Orchestration

Coordinates generation across the system:

- Manages constraint cache
- Handles inference server communication
- Applies token-level masks via llguidance
- Supports streaming generation
- Validates outputs against constraints

### Inference Service

Must be controlled locally for token-level constraint enforcement:

- **vLLM/SGLang**: High-performance model serving
- **llguidance**: ~50μs/token constraint application
- **Model**: Llama, Mistral, DeepSeek, or similar
- **GPU**: 16GB+ VRAM for 7B models

---

## Performance Targets

| Operation | Target | Status |
|-----------|--------|--------|
| Constraint validation | <50μs | In progress |
| Extraction | <2s (with Claude) | In progress |
| Compilation | <50ms | In progress |
| Generation | <5s | In progress |
| Invalid output rate | <0.12% | Planned |

---

## Documentation

- **[ARCHITECTURE.md](docs/ARCHITECTURE.md)** - System design and component details
- **[IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md)** - Detailed roadmap with phases
- **[beads/implementation-phases.bead](beads/implementation-phases.bead)** - Task tracking

---

## Examples

See `/examples` directory for working examples:

1. **pure-local**: Constraint extraction with no external services
2. **with-claude-analysis**: Using Claude for semantic understanding
3. **full-pipeline**: End-to-end with generation

```bash
# Run an example
cd examples/pure-local
zig build
./zig-cache/bin/example
```

---

## Contributing

We're actively building Ananke. Contributions welcome in:

- Constraint extraction improvements
- Performance optimization
- Model/platform support
- Documentation
- Test coverage

See `CONTRIBUTING.md` (coming soon).

---

## License

MIT License - See LICENSE file for details

---

## Acknowledgments

Inspired by:
- **llguidance**: Token-level constraint enforcement
- **vLLM**: Efficient inference infrastructure
- **Tree-sitter**: Robust syntax parsing
- **Claude**: Semantic code understanding

---

## Roadmap

- [ ] Phase 1: Foundation & Zig setup (Week 1)
- [ ] Phase 2: Constraint extraction (Weeks 2-3)
- [ ] Phase 3: Ariadne DSL (Week 4)
- [ ] Phase 4: Maze orchestration (Weeks 5-6)
- [ ] Phase 5: Inference service (Week 7)
- [ ] Phase 6: Integration patterns (Week 8)
- [ ] Phase 7: Testing & benchmarks (Week 9)
- [ ] Phase 8: Documentation (Week 10)
- [ ] Phase 9: Production deployment (Week 11)
- [ ] Phase 10: Optimization (Week 12)

---

**Questions?** Open an issue or check the documentation in `/docs`.