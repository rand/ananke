# Ananke

> Constraint-driven code generation that transforms AI from probabilistic guessing into controlled search through valid program spaces.

[![CI](https://github.com/ananke-ai/ananke/actions/workflows/ci.yml/badge.svg)](https://github.com/ananke-ai/ananke/actions/workflows/ci.yml)
[![Maze Tests](https://github.com/ananke-ai/ananke/actions/workflows/maze-tests.yml/badge.svg)](https://github.com/ananke-ai/ananke/actions/workflows/maze-tests.yml)
[![Security](https://github.com/ananke-ai/ananke/actions/workflows/security.yml/badge.svg)](https://github.com/ananke-ai/ananke/actions/workflows/security.yml)
[![Docs](https://github.com/ananke-ai/ananke/actions/workflows/docs.yml/badge.svg)](https://github.com/ananke-ai/ananke/actions/workflows/docs.yml)
[![License: Proprietary](https://img.shields.io/badge/License-Proprietary-red.svg)](LICENSE)
[![Language: Zig](https://img.shields.io/badge/Language-Zig-blue.svg)](https://ziglang.org/)
[![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-green.svg)](RELEASE_NOTES.md)
[![Status: Beta (Core Ready)](https://img.shields.io/badge/Status-Beta%20(Core%20Ready)-yellowgreen.svg)](#current-project-status)

## Project Philosophy

If you can't make it explicit, you can't control it. If you can't control it, you can't trust it. If you can't trust it, you can't ship it.

Ananke enforces constraints at the **token level** during code generation, ensuring outputs always satisfy specified requirements. No more hoping the model will follow your patterns. You define the rules, Ananke enforces them.

---

## Prerequisites

Before using Ananke, ensure you have the following installed:

### Required

- **Zig 0.15.0 or later** - [Download from ziglang.org](https://ziglang.org/download/)
  ```bash
  zig version  # Should show 0.15.0 or later
  ```

- **tree-sitter** - Required for AST-based constraint extraction
  ```bash
  # macOS (Homebrew)
  brew install tree-sitter

  # Ubuntu/Debian
  sudo apt-get install libtree-sitter-dev

  # Arch Linux
  sudo pacman -S tree-sitter

  # Verify installation
  tree-sitter --version
  ```

### Optional

- **Anthropic API Key** - For semantic constraint analysis (Claude integration)
  ```bash
  export ANTHROPIC_API_KEY='your-key-here'
  ```
  Get your key at [console.anthropic.com](https://console.anthropic.com/)

- **OpenAI API Key** - Alternative LLM provider
  ```bash
  export OPENAI_API_KEY='your-key-here'
  ```

- **Git** - For cloning the repository

### System Requirements

- **OS**: macOS, Linux (Ubuntu 20.04+, Debian 11+, Arch), Windows WSL2
- **Memory**: 2GB RAM minimum, 4GB recommended
- **Disk**: 500MB for installation + dependencies

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
Source Code, Tests, Docs
        ↓
   ┌──────────────────┐
   │  Clew            │ ← Pure Zig structural parsers
   │  (Extraction)    │   Optional: Claude API for semantic analysis
   └────────┬─────────┘   Runs locally (no GPU needed)
            ↓ Extracted Constraints
   ┌──────────────────┐
   │  Braid           │ ← Pure Zig constraint compiler
   │  (Compilation)   │   - Regex extraction
   │  4 components:   │   - JSON Schema generation
   │  ✓ Regex matcher │   - Grammar building
   │  ✓ Schema build  │   - Token mask compilation
   │  ✓ Mask creator  │   - Caching with clone-on-get
   │  ✓ Merger        │
   └────────┬─────────┘
            ↓ ConstraintIR
   ┌──────────────────┐
   │  Maze            │ ← Rust orchestration layer
   │  (Orchestration) │   HTTP API coordination
   └────────┬─────────┘
            ↓ API calls
   ┌──────────────────────────────┐
   │ Modal/vLLM Inference Service │ ← GPU-powered (controlled via llguidance)
   │ - Qwen2.5-Coder-32B-Instruct │   Token-level constraint enforcement
   │ - ~50μs per token overhead   │   Scale-to-zero architecture
   └──────────────────────────────┘
          ↓
   Generated Code (Constraint-Validated)
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
- Zig 0.15.1+ (for building from source)
- Rust 1.70+ (for Maze library)
- For generation: GPU infrastructure (Modal, RunPod, or local)
- Optional: Claude API key for analysis enhancements

### Option 1: Pre-built Binaries (Recommended)

#### macOS (Homebrew)
```bash
# Add Ananke tap
brew tap ananke-project/ananke

# Install
brew install ananke

# Verify
ananke --version
```

#### macOS/Linux (Direct Download)
```bash
# Download for your platform
curl -L https://github.com/ananke-project/ananke/releases/latest/download/ananke-$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m).tar.gz | tar xz

# Extract and install
cd ananke-v*-*
./install.sh

# Or install to custom location
PREFIX=~/.local ./install.sh
```

#### Windows
1. Download the `.zip` file for your architecture from [releases](https://github.com/ananke-project/ananke/releases)
2. Extract to your desired location
3. Add the `bin` directory to your PATH

### Option 2: From Source

```bash
git clone https://github.com/ananke-ai/ananke.git
cd ananke

# Build all components (Zig + Rust)
zig build

# Build Rust Maze library
cd maze && cargo build --release && cd ..

# Run tests
zig build test
cd maze && cargo test && cd ..

# Build examples
zig build examples
```

### Option 3: Using as a Library

**Zig Library** - Add to your `build.zig.zon`:
```zig
.ananke = .{
    .url = "https://github.com/ananke-ai/ananke/archive/refs/tags/v0.1.0.tar.gz",
    .hash = "12207...",
},
```

**Rust Library (Maze)** - Add to your `Cargo.toml`:
```toml
[dependencies]
maze = "0.1.0"
```

### Verifying Installation

```bash
# Check Ananke CLI
ananke --version

# Test constraint extraction
ananke extract examples/sample.ts

# Check available commands
ananke help
```

---

## Configuration

### Claude API Setup (Optional)

Ananke can use Claude for enhanced semantic analysis of constraints. This is completely optional - Ananke works great with just its built-in structural parsers.

#### Setting up Claude API

1. **Get an API key** from [Anthropic Console](https://console.anthropic.com/)

2. **Set the environment variable**:
```bash
export ANTHROPIC_API_KEY='sk-ant-api...'
```

3. **Or configure in `.ananke.toml`**:
```toml
[claude]
# API key can be set here or via ANTHROPIC_API_KEY env var
# api_key = "sk-ant-api..."  # Not recommended for security
model = "claude-sonnet-4-5-20250929"
enabled = true
```

#### Using Claude in Commands

```bash
# Extract with semantic analysis
ananke extract src/main.ts --use-claude

# Claude will analyze for:
# - Business logic constraints
# - Implicit patterns
# - Security requirements
# - Architectural decisions
```

#### Graceful Fallback

If Claude is not configured or unavailable, Ananke automatically falls back to structural analysis only. Your workflow won't be interrupted.

### Full Configuration File

Create `.ananke.toml` in your project root:

```toml
[claude]
# Claude API for semantic analysis (optional)
# api_key sourced from ANTHROPIC_API_KEY env var
model = "claude-sonnet-4-5-20250929"
enabled = true  # Auto-enabled if API key present

[modal]
# For code generation (optional)
endpoint = "https://your-app.modal.run"
# api_key sourced from ANANKE_MODAL_API_KEY env var

[defaults]
language = "typescript"
max_tokens = 4096
temperature = 0.7
confidence_threshold = 0.5
output_format = "pretty"

[extract]
use_claude = false  # Enable globally or per-command
patterns = ["all"]

[compile]
priority = "medium"
formats = ["json-schema"]
```

### Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `ANTHROPIC_API_KEY` | Claude API key for semantic analysis | No |
| `ANANKE_MODAL_API_KEY` | Modal API key for generation | No |
| `ANANKE_MODAL_ENDPOINT` | Modal endpoint URL | No |
| `ANANKE_LANGUAGE` | Default source language | No |
| `ANANKE_CLAUDE_ENDPOINT` | Custom Claude API endpoint | No |

All configuration is optional. Ananke works with zero configuration using its built-in parsers.

---

## Quick Start

### Pattern 1: Pure Local (No Claude, No GPU)

Extract constraints from your codebase, no external services:

```zig
const ananke = @import("ananke");
const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize Clew (no external services needed)
    var clew = try ananke.Clew.init(allocator, null);  // null = no Claude API
    defer clew.deinit();

    // Extract constraints from source code (pure Zig parsers)
    const source = @embedFile("handlers/auth.ts");
    const constraints = try clew.extractFromCode(source, null);
    defer allocator.free(constraints);

    // Compile constraints locally
    var braid = try ananke.Braid.init(allocator);
    defer braid.deinit();
    const compiled = try braid.compile(constraints);

    std.debug.print("Found {d} constraints\n", .{constraints.len});
    // Output: Type safety, security patterns, architectural constraints
    // All extracted and compiled locally in <100ms
}
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
    modal_endpoint="https://<YOUR_MODAL_WORKSPACE>--ananke-inference-generate-api.modal.run",
    model="Qwen/Qwen2.5-Coder-32B-Instruct",
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
    --inference-url https://<YOUR_MODAL_WORKSPACE>--ananke-inference-generate-api.modal.run \
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
        endpoint="https://<YOUR_MODAL_WORKSPACE>--ananke-inference-generate-api.modal.run",
        model="Qwen/Qwen2.5-Coder-32B-Instruct"
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
# Build everything (default)
zig build

# Build with optimizations (recommended)
zig build -Doptimize=ReleaseFast

# Run all tests
zig build test

# Run specific test suite
zig build test -- src/clew/tests.zig

# Build benchmarks
zig build bench-phase8b
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
│   ├── 01-simple-extraction/ # No external services
│   ├── 02-claude-analysis/   # Claude for analysis
│   └── 04-full-pipeline/     # Full end-to-end
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

**Phase**: v0.1.0 - Beta (Core Ready)

**Release**: November 24, 2025

**Production-Ready Components (v0.1.0):**

- **Clew (Constraint Extraction)**: PRODUCTION READY
  - Pure Zig structural parsers with tree-sitter integration
  - 101+ constraint patterns across TypeScript/Python
  - 40+ unit tests passing, 0 memory leaks
  - <100ms extraction time (static analysis)
  - Optional Claude API integration for semantic analysis
  - Verified working across tutorial and production examples

- **Braid (Constraint Compilation)**: PRODUCTION READY
  - All 4 components fully implemented and tested:
    - JSON Schema generator
    - Regular expression matcher
    - Grammar builder
    - Token mask compiler
  - 31+ unit tests passing, 0 memory leaks
  - LRU caching with deep cloning (clone-on-get strategy)
  - 11-13x cache speedup, ~5-15μs cache hit latency

- **Security Hardening**: PRODUCTION READY
  - Path traversal protection with symlink validation
  - Constraint injection prevention (SQL, XSS, command injection)
  - API key memory zeroing with volatile writes
  - HTTP retry with exponential backoff and rate limiting
  - 23 dedicated security edge case tests
  - Full OWASP Top 10 compliance verification
  - See [docs/SECURITY_TEST_REPORT.md](docs/SECURITY_TEST_REPORT.md)

- **CLI Tool**: PRODUCTION READY
  - 6 commands fully functional: extract, compile, generate, validate, init, version, help
  - Enhanced error messages with actionable suggestions
  - Context-aware help and troubleshooting guides
  - 43+ CLI tests passing
  - Verified working with all examples
  - JSON output format for programmatic use (--format json)

- **Modal Inference Service**: PRODUCTION READY
  - vLLM 0.11.0 + llguidance 0.7.11 deployed
  - Endpoint: https://<YOUR_MODAL_WORKSPACE>--ananke-inference-generate-api.modal.run
  - Model: Qwen2.5-Coder-32B-Instruct
  - Performance: 22.3 tokens/sec with JSON schema constraints
  - ~50μs per-token overhead for constraint enforcement

- **Maze (Orchestration)**: PRODUCTION READY
  - Rust-based async orchestration layer
  - Complete FFI integration with Zig
  - 43+ Rust tests passing
  - HTTP API coordination with inference service
  - Verified working in full end-to-end examples

**Experimental/In-Progress:**
- Ariadne DSL: 70% COMPLETE
  - Parsing: Complete
  - Type checking and error recovery: Deferred to v0.2
  - Basic constraint definitions work well

- Additional Extractors: NOT YET IMPLEMENTED
  - Rust extraction support (Planned v0.2)
  - Go extraction support (Planned v0.2)
  - Zig extraction support (Planned v0.2)

**Test Coverage:**
- 301 total tests passing (100% pass rate)
- 258 Zig tests (extraction, compilation, integration, E2E, security)
- 43 CLI/Rust tests (orchestration, FFI, infrastructure)
- 23 dedicated security edge case tests
- Zero critical failures, zero memory leaks
- <2 minutes total test suite runtime

**Known Limitations:**
- Pure Zig parsers extract syntax patterns only (tree-sitter compatibility deferred to v0.2)
- Token masking uses hash-based IDs (not real cryptographic tokens)
- Ariadne DSL lacks full type checking (v0.2 feature)
- Only TypeScript and Python extractors fully implemented (others in v0.2 roadmap)

**Next Release (v0.2.0)**: Q1 2026
- Full tree-sitter integration for extended language support
- Bidirectional streaming generation
- Multi-model orchestration
- Ariadne DSL type checking and error recovery
- Web UI (beta)
- Complete Rust/Go/Zig extractors

See [RELEASE_NOTES.md](RELEASE_NOTES.md) for v0.1.0 details.
See [docs/IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md) for v0.2 roadmap.

---

## Architecture Deep Dive

### Clew: Constraint Extraction

Mines constraints from multiple sources using pure Zig structural parsers and optional Claude integration:

```
Source Code → Pure Zig parsers → Syntactic constraints
Tests       → Pure Zig parsers → Type/behavior constraints
Telemetry   → Claude analysis  → Performance constraints
Docs        → Claude analysis  → Business rules
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

## Documentation Hub

### Getting Started
- **[QUICKSTART.md](QUICKSTART.md)** - 10-minute getting started guide
- **[INSTALL_QUICKREF.md](INSTALL_QUICKREF.md)** - Quick installation reference
- **[RELEASE_NOTES.md](RELEASE_NOTES.md)** - v0.1.0 features and highlights

### Deep Dives
- **[ARCHITECTURE.md](docs/ARCHITECTURE.md)** - System design and component details
- **[ARCHITECTURE_V2.md](docs/ARCHITECTURE_V2.md)** - Advanced architecture patterns
- **[API_REFERENCE_ZIG.md](docs/API_REFERENCE_ZIG.md)** - Zig library API reference
- **[API_REFERENCE_RUST.md](docs/API_REFERENCE_RUST.md)** - Rust Maze API reference
- **[CLI_GUIDE.md](docs/CLI_GUIDE.md)** - Complete CLI command reference
- **[API_ERROR_HANDLING.md](docs/API_ERROR_HANDLING.md)** - API error handling and troubleshooting
- **[COMPILE_COMMAND.md](docs/COMPILE_COMMAND.md)** - Comprehensive compile command guide
- **[MODAL_INFRASTRUCTURE.md](docs/MODAL_INFRASTRUCTURE.md)** - Modal deployment and configuration

### Operations & Development
- **[DEPLOYMENT.md](docs/DEPLOYMENT.md)** - Production deployment guide
- **[SECURITY.md](SECURITY.md)** - Security guidelines and best practices
- **[SECURITY_TEST_REPORT.md](docs/SECURITY_TEST_REPORT.md)** - Comprehensive security testing report
- **[PERFORMANCE.md](PERFORMANCE.md)** - Performance optimization guide
- **[FFI_GUIDE.md](docs/FFI_GUIDE.md)** - Cross-language integration
- **[TEST_STRATEGY.md](TEST_STRATEGY.md)** - Testing approach and strategy
- **[CONTRIBUTING.md](CONTRIBUTING.md)** - Contribution guidelines
- **[DEVELOPMENT_HISTORY.md](DEVELOPMENT_HISTORY.md)** - Development narrative
- **[FAQ.md](docs/FAQ.md)** - Frequently asked questions
- **[TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** - Common issues and solutions

### Implementation
- **[IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md)** - Detailed roadmap with phases
- **[beads/implementation-phases.bead](beads/implementation-phases.bead)** - Task tracking

---

## Known Limitations (v0.1.0)

**Language Support:**
- Extractors: TypeScript/JavaScript and Python fully supported
- Rust, Go, and Zig extractors planned for v0.2
- Pure Zig parsers limit semantic extraction (full tree-sitter integration in v0.2)

**Ariadne DSL:**
- Parsing works well for constraint definitions
- Type checking and detailed error messages deferred to v0.2
- Use JSON configuration for production deployments

**Token Masking:**
- Uses hash-based IDs for token identification
- Real cryptographic tokenization planned for v0.2
- Safe for most use cases but not recommended for cryptographic token handling

**Caching:**
- Works reliably with clone-on-get strategy
- Single-machine in-process cache (distributed caching in roadmap)

**CLI:**
- Core commands functional and tested
- Some advanced features (batch processing, config files) in v0.2
- Windows support experimental (full support in v0.2)

---

## Examples

See `/examples` directory for working examples:

1. **01-simple-extraction**: Constraint extraction with no external services
2. **02-claude-analysis**: Using Claude for semantic understanding
3. **04-full-pipeline**: End-to-end with generation

```bash
# Run an example
cd examples/01-simple-extraction
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

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

---

## License

All Rights Reserved - See LICENSE file for details

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