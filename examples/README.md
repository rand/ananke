# Ananke Examples

This directory contains runnable examples demonstrating different Ananke usage patterns, from basic constraint extraction to full end-to-end pipelines.

## Quick Start

Each example is self-contained with its own README, build files, and sample code.

```bash
# Run any example from its directory
cd examples/01-simple-extraction
zig build run

# Or from the ananke root
cd ananke
./run-example.sh 01-simple-extraction
```

**First time?** Start with Example 01 - it requires no setup and runs in under 100ms.

## Quick Reference Table

| Example | Time | Prerequisites | Demonstrates | Complexity | Status |
|---------|------|---------------|--------------|------------|--------|
| **01-simple-extraction** | ~100ms | None | Static analysis only | Beginner | Complete |
| **02-claude-analysis** | ~2s | Claude API key | Semantic understanding | Intermediate | Complete |
| **03-ariadne-dsl** | ~50ms | None | DSL constraint definitions | Intermediate | Partial |
| **04-full-pipeline** | ~100ms | None | Extract + Compile pipeline | Advanced | Partial |
| **05-mixed-mode** | ~200ms | None | Multi-source composition | Advanced | Complete |

## Examples Overview

### [01-simple-extraction](./01-simple-extraction/) - Basic Constraint Extraction

**What**: Extract constraints from TypeScript code without any LLM

**Key Concepts**:
- Static analysis with tree-sitter
- Pattern-based extraction
- No external dependencies
- Fast and deterministic

**When to Use**:
- Learning Ananke basics
- Pure local constraint discovery
- Speed is critical
- No Claude API available

**Run Time**: ~100ms

```bash
cd 01-simple-extraction
zig build run
```

### [02-claude-analysis](./02-claude-analysis/) - Semantic Constraint Analysis

**What**: Compare static extraction vs. Claude-enhanced semantic analysis

**Key Concepts**:
- Business rule extraction
- Comment and docstring analysis
- Confidence scoring
- Cost vs. value tradeoff

**When to Use**:
- Complex business logic
- Rich documentation in code
- Need semantic understanding
- Budget allows LLM calls

**Run Time**: ~2 seconds (with Claude)

```bash
# Set your API key
export ANTHROPIC_API_KEY='your-key-here'

cd 02-claude-analysis
zig build run
```

### [03-ariadne-dsl](./03-ariadne-dsl/) - Declarative Constraint Definition

**What**: Define constraints using Ariadne domain-specific language

**Key Concepts**:
- Declarative constraint specification
- Type-safe definitions
- Composable modules
- Version-controlled rules

**When to Use**:
- Organization-wide policies
- Complex query patterns
- Reusable constraint libraries
- Type safety matters

**Run Time**: ~50ms (compile time)

```bash
cd 03-ariadne-dsl
zig build run
```

### [04-full-pipeline](./04-full-pipeline/) - End-to-End Pipeline

**What**: Complete pipeline demonstrating Extract → Compile → Generate workflow

**Status**: Available (Partial - Generation step coming soon)

**Demonstrates**:
- Constraint extraction from TypeScript code (Clew)
- Constraint compilation to IR (Braid)
- JSON serialization for Rust FFI integration
- Foundation for constrained code generation

**Note**: Full code generation via Maze/Modal will be available once FFI functions are implemented

**Run Time**: ~100ms (extraction + compilation only)

```bash
cd 04-full-pipeline
zig build run
```

### [05-mixed-mode](./05-mixed-mode/) - Combining Multiple Approaches

**What**: Mix extracted, JSON-configured, and DSL-defined constraints

**Key Concepts**:
- Multi-source composition
- Layered constraints
- Best of all worlds
- Production-ready patterns

**When to Use**:
- Production systems
- Need comprehensive coverage
- Different teams own different layers
- Maximum flexibility

**Run Time**: ~200ms

```bash
cd 05-mixed-mode
zig build run
```

## Decision Guide

### I want to...

**Learn Ananke basics**
→ Start with Example 01

**Understand semantic analysis**
→ See Example 02

**Define custom constraints**
→ Check Example 03

**See end-to-end workflow**
→ Wait for Example 04 (or read placeholder)

**Build production system**
→ Study Example 05

## Feature Matrix

| Example | Extraction | Claude | Ariadne | JSON | Generation | Complexity |
|---------|-----------|--------|---------|------|------------|-----------|
| 01      | ✓         |        |         |      |            | Low       |
| 02      | ✓         | ✓      |         |      |            | Medium    |
| 03      |           |        | ✓       |      |            | Medium    |
| 04      | ✓         |        |         | ✓    | (partial)  | Medium    |
| 05      | ✓         |        | ✓       | ✓    |            | High      |

## Recommended Learning Path

### Beginner

1. **Example 01**: Understand basic extraction
2. **Example 03**: Learn constraint definition
3. **Example 05**: See how they compose

### Intermediate

1. **Example 02**: Compare static vs. semantic
2. **Example 05**: Build mixed-mode system
3. **Example 04**: End-to-end workflow (when ready)

### Advanced

1. Read all examples
2. Combine patterns for your use case
3. Build custom constraint libraries
4. Deploy to production

## Common Patterns

### Pattern: Organizational Standards

Extract from codebase + JSON policies:

```bash
# Example 01: Extract patterns
# + JSON config for company rules
# = Consistent, policy-compliant code
```

### Pattern: Domain Compliance

Extract patterns + Ariadne regulations:

```bash
# Example 01 or 02: Learn from code
# + Example 03: Define compliance rules
# = Industry-compliant generation
```

### Pattern: Full Stack

All approaches combined:

```bash
# Example 05: Everything together
# = Maximum coverage and flexibility
```

## Performance Comparison

| Example | Extraction | Compilation | Total   | External API |
|---------|-----------|-------------|---------|--------------|
| 01      | 50ms      | -           | 50ms    | No           |
| 02      | 50ms      | -           | 2000ms  | Claude       |
| 03      | -         | 30ms        | 30ms    | No           |
| 04      | 50ms      | 50ms        | 100ms   | (No - gen pending) |
| 05      | 150ms     | 50ms        | 200ms   | No           |

All examples are fast enough for interactive use.

## Requirements

### All Examples

- Zig 0.15.1+
- Ananke source code

### Example 02 (Claude Analysis)

- `ANTHROPIC_API_KEY` environment variable
- Internet connection

### Example 04 (Full Pipeline)

- Currently: No additional requirements (extraction + compilation only)
- Future: Modal deployment for code generation (see `/modal_inference/`)

## Example Structure

Each example follows the same structure:

```
examples/XX-name/
├── README.md           # Detailed explanation
├── main.zig           # Example program
├── build.zig          # Build configuration
├── build.zig.zon      # Dependencies
└── sample.*           # Sample code to analyze
    OR constraint files (.json, .ariadne)
```

## Building All Examples

From the ananke root:

```bash
# Build everything
for dir in examples/0{1,2,3,5}-*/; do
    (cd "$dir" && zig build)
done

# Run all examples
for dir in examples/0{1,2,3,5}-*/; do
    echo "=== Running $dir ==="
    (cd "$dir" && zig build run)
done
```

## Common Issues

### Missing Dependencies

```bash
# From each example directory
zig build

# If dependency errors, check build.zig.zon path to ananke
```

### API Key Issues (Example 02)

```bash
# Set your key
export ANTHROPIC_API_KEY='your-key-here'

# Verify it's set
echo $ANTHROPIC_API_KEY
```

### Build Errors

```bash
# Clean and rebuild
rm -rf zig-cache/ zig-out/
zig build
```

## Contributing Examples

Want to add an example? Follow the pattern:

1. Create directory: `examples/XX-name/`
2. Add `README.md` with clear explanation
3. Include `main.zig` with runnable code
4. Provide `build.zig` and `build.zig.zon`
5. Add sample files demonstrating the concept
6. Update this README with new example

## Integration with Documentation

Examples complement the documentation:

- **Examples**: Runnable, hands-on learning
- **Docs**: Conceptual understanding, API reference
- **Implementation Plans**: Development roadmap

Read the docs first, then run the examples to cement understanding.

## Next Steps

After exploring examples:

1. **Read Architecture**: `/docs/ARCHITECTURE.md`
2. **Check Implementation Plan**: `/docs/IMPLEMENTATION_PLAN.md`
3. **Try Modal Inference**: `/modal_inference/QUICKSTART.md`
4. **Build Your Application**: Use what you learned

## Questions?

- Check individual example READMEs for details
- Read the main Ananke README
- See `/docs/` for architecture and API docs
- Open an issue on GitHub

## Example Progression

```
01: Simple Extraction
    ↓
02: +Claude Analysis
    ↓
03: +Ariadne DSL
    ↓
05: Mix All Together
    ↓
04: Full Pipeline (coming soon)
    ↓
Production Deployment
```

Start simple, add complexity as needed.

## Key Takeaways

1. **Static extraction (01)** is fast and always available
2. **Claude analysis (02)** adds semantic understanding when needed
3. **Ariadne DSL (03)** provides declarative constraint definition
4. **Mixed-mode (05)** combines strengths of all approaches
5. **Full pipeline (04)** shows end-to-end constrained generation

Use the right tool for each constraint, compose them together, and generate validated code.

Happy coding with Ananke!
