# Ananke

Constraint-driven code generation with typed holes for progressive refinement.

## What is Ananke?

Ananke transforms AI code generation from probabilistic guessing into controlled search through valid program spaces. Instead of hoping the model follows your patterns, you define constraints and Ananke enforces them at the token level.

**Typed Holes** are the core abstraction: explicit markers for incomplete code that carry rich type information, constraints, and metadata. Fill them progressively with AI assistance while maintaining guarantees.

## Core Components

| Component | Language | Purpose |
|-----------|----------|---------|
| **Clew** | Zig | Extract constraints from code via tree-sitter AST |
| **Braid** | Zig | Compile constraints into executable IR |
| **Ariadne** | Zig | Constraint DSL for declarative specifications |
| **Maze** | Rust | Orchestrate constrained generation with LLMs |

## Quick Start

```bash
# Clone and build
git clone https://github.com/rand/ananke.git
cd ananke
zig build

# Run tests
zig build test
cd maze && cargo test

# Try an example
cd examples/01-simple-extraction && zig build run
```

### Requirements

- **Zig 0.15.0+** - [ziglang.org/download](https://ziglang.org/download/)
- **tree-sitter** - `brew install tree-sitter` (macOS) or `apt install libtree-sitter-dev`
- **Rust 1.70+** - For Maze orchestration layer

### Optional

- **Anthropic API Key** - For semantic analysis: `export ANTHROPIC_API_KEY='...'`
- **Modal** - For GPU inference: `export ANANKE_MODAL_ENDPOINT='...'`

## Architecture

```
Source Code
    ↓
┌─────────────┐
│    Clew     │ ← Tree-sitter extraction + semantic analysis
└──────┬──────┘
       ↓ Constraints
┌─────────────┐
│    Braid    │ ← Compile to JSON Schema, regex, token masks
└──────┬──────┘
       ↓ ConstraintIR
┌─────────────┐
│    Maze     │ ← Orchestrate with vLLM + llguidance
└──────┬──────┘
       ↓
Generated Code (constraint-validated)
```

## Typed Holes

Typed holes represent incomplete code with explicit contracts:

```python
def authenticate(user: User) -> AuthResult:
    # HOLE: validate credentials
    # Scale: function
    # Constraints: must check password hash, return AuthResult
    # Origin: user_marked
    pass
```

Ananke detects these holes, compiles their constraints, and fills them progressively while respecting the specified contracts.

### Hole Detection

```zig
var detector = HoleDetector.init(allocator, .python);
var holes = try detector.detectHoles(source, "auth.py");
// Finds: TODO markers, pass statements, unimplemented!, etc.
```

### Fill with Constraints

```python
result = await maze.generate(
    intent="Implement credential validation",
    hole_id=hole.id,
    constraints=compiled_ir,
)
```

## Editor Support

- **[ananke-lsp](https://github.com/rand/ananke-lsp)** - Language Server Protocol implementation
- **[ananke-nvim](https://github.com/rand/ananke-nvim)** - Neovim plugin
- **[ananke-intellij](https://github.com/rand/ananke-intellij)** - IntelliJ plugin

## Documentation

| Document | Description |
|----------|-------------|
| [QUICKSTART.md](QUICKSTART.md) | 10-minute getting started guide |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | System design and internals |
| [docs/CLI_GUIDE.md](docs/CLI_GUIDE.md) | Command-line interface reference |
| [docs/API_REFERENCE_ZIG.md](docs/API_REFERENCE_ZIG.md) | Zig library API |
| [docs/API_REFERENCE_RUST.md](docs/API_REFERENCE_RUST.md) | Rust Maze API |
| [docs/FFI_GUIDE.md](docs/FFI_GUIDE.md) | Cross-language integration |
| [docs/PYTHON_API.md](docs/PYTHON_API.md) | Python bindings |
| [SECURITY.md](SECURITY.md) | Security guidelines |

## Project Status

**Version**: 0.1.0 (December 2025)

### Production Ready

- Clew constraint extraction (TypeScript, Python)
- Braid constraint compilation (JSON Schema, regex, token masks)
- Maze orchestration with Modal/vLLM
- CLI tool with 6 commands
- 334 tests passing, zero memory leaks

### Typed Holes (v0.2.0)

- Semantic hole detection via tree-sitter AST
- Incremental constraint compilation
- Multi-model ensemble routing
- Adaptive strategy selection
- Editor plugins (LSP, Neovim, IntelliJ)

## Performance

| Operation | Achieved |
|-----------|----------|
| Constraint extraction | ~10ms |
| Constraint compilation | ~1ms |
| Token-level enforcement | ~50μs/token |
| Cache hit latency | ~5-15μs |

## Examples

```bash
examples/
├── 01-simple-extraction/  # No external services
├── 02-claude-analysis/    # Semantic analysis with Claude
├── 03-ariadne-dsl/        # Constraint DSL
├── 04-full-pipeline/      # End-to-end generation
└── 05-mixed-mode/         # Combined constraint sources
```

## License

All Rights Reserved - Copyright (c) 2025 Rand Arete

See [LICENSE](LICENSE) for details.
