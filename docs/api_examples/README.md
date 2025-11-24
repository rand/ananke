# Ananke API Examples

Working code examples demonstrating Ananke's Zig and Rust APIs.

**Last Updated**: November 24, 2025

---

## Quick Start

### Zig Examples

```bash
# Basic constraint extraction
zig build-exe zig_basic_extraction.zig
./zig_basic_extraction

# Full pipeline (extract → compile → llguidance)
zig build-exe zig_full_pipeline.zig
./zig_full_pipeline

# Custom constraint patterns
zig build-exe zig_custom_patterns.zig
./zig_custom_patterns
```

### Rust Examples

```bash
# MazeOrchestrator usage
cargo build --example rust_orchestrator
cargo run --example rust_orchestrator

# Direct ModalClient usage
cargo build --example rust_modal_client
cargo run --example rust_modal_client

# FFI integration
cargo build --example rust_ffi_integration
cargo run --example rust_ffi_integration
```

---

## Examples Overview

### 1. zig_basic_extraction.zig

**What it demonstrates**:
- Initializing Clew extraction engine
- Extracting constraints from TypeScript code
- Grouping constraints by kind
- Displaying confidence scores

**Runtime**: 5-10ms  
**Lines**: 120  
**Complexity**: Beginner

**Output preview**:
```
✓ Extracted 8 constraints

Constraints by category:
===========================================================

syntactic (3 constraints):
  • async function detected at line 1 in typescript code
    Source: AST_Pattern, Confidence: 0.85
  ...
```

---

### 2. zig_full_pipeline.zig

**What it demonstrates**:
- Complete workflow from source to llguidance
- Performance timing for each phase
- Inspecting compiled ConstraintIR components
- llguidance schema generation

**Runtime**: 15-30ms  
**Lines**: 180  
**Complexity**: Intermediate

**Pipeline**:
1. Initialize Ananke (Clew + Braid + Ariadne)
2. Extract constraints from Python code
3. Compile to ConstraintIR
4. Convert to llguidance JSON schema

**Output preview**:
```
Step 1: Initializing Ananke engines...
  ✓ Clew, Braid, and Ariadne initialized

Step 2: Extracting constraints from Python code...
  ✓ Extracted 12 constraints in 6ms

Step 3: Compiling constraints to ConstraintIR...
  ✓ Compiled in 8ms
  ...
```

---

### 3. zig_custom_patterns.zig

**What it demonstrates**:
- Creating custom user-defined constraints
- Setting priority levels and severity
- Compiling custom patterns to IR
- Security constraint examples

**Runtime**: 5-15ms  
**Lines**: 140  
**Complexity**: Intermediate

**Custom constraints created**:
- No console.log in production
- Require error handling in async functions
- Input validation for public APIs
- No SQL string concatenation
- API timeout requirements

---

### 4. rust_orchestrator.rs

**What it demonstrates**:
- Configuring MazeOrchestrator
- Setting up Modal inference service
- Creating generation requests with context
- Monitoring cache statistics
- Full code generation workflow

**Runtime**: 1-5 seconds (with Modal)  
**Lines**: 200  
**Complexity**: Intermediate

**Workflow**:
1. Configure Modal and Maze
2. Create orchestrator
3. Define constraints (from Zig)
4. Build generation context
5. Generate code with constraints
6. Display results and metrics

**Note**: Requires `MODAL_ENDPOINT` and `MODAL_API_KEY` environment variables.

---

### 5. rust_modal_client.rs

**What it demonstrates**:
- Direct ModalClient usage
- Health checks and service monitoring
- Listing available models
- Retry logic with exponential backoff
- Error handling patterns

**Runtime**: 500ms - 3 seconds  
**Lines**: 130  
**Complexity**: Beginner

**Operations shown**:
- Configuration from environment
- Health check endpoint
- Model listing
- Inference request (with mock endpoint)

---

### 6. rust_ffi_integration.rs

**What it demonstrates**:
- Converting between Rust and Zig types
- FFI pointer management
- Round-trip conversions (Rust → FFI → Rust)
- Memory safety patterns
- Complete Zig ↔ Rust workflow simulation

**Runtime**: <1ms (no I/O)  
**Lines**: 180  
**Complexity**: Advanced

**Conversions demonstrated**:
- ConstraintIR creation and conversion
- Intent structure handling
- GenerationResult FFI export
- Proper memory cleanup

---

## Running Examples

### Prerequisites

**Zig**:
- Zig 0.15.1 or later
- Ananke package in import path

**Rust**:
- Rust 1.80 or later
- Tokio async runtime
- ananke-maze crate

### With Project Build System

If running from the main Ananke project:

```bash
# Zig (via build.zig)
zig build examples-zig

# Rust (via Cargo)
cd maze
cargo build --examples
cargo run --example rust_orchestrator
```

### Standalone

Each example can be compiled standalone:

```bash
# Zig
zig build-exe example.zig -I/path/to/ananke/src

# Rust
rustc example.rs --edition 2021
```

---

## Environment Setup

### For Rust Examples

```bash
# Required for Modal integration
export MODAL_ENDPOINT="https://your-app.modal.run"
export MODAL_API_KEY="sk-your-api-key"

# Optional
export MODAL_MODEL="meta-llama/Llama-3.1-8B-Instruct"
```

### For Zig Examples with Claude

```bash
# Optional: Enable Claude semantic analysis
export CLAUDE_API_KEY="sk-ant-your-key"
```

---

## Example Complexity Guide

**Beginner**:
- Single component focus
- Minimal error handling
- Clear step-by-step flow

**Intermediate**:
- Multiple components
- Full workflows
- Realistic error handling

**Advanced**:
- FFI integration
- Complex type conversions
- Memory management patterns

---

## Next Steps

After running these examples:

1. **Read the full API references**:
   - [Zig API Reference](../API_REFERENCE_ZIG.md)
   - [Rust API Reference](../API_REFERENCE_RUST.md)

2. **Check the quick reference**:
   - [API Quick Reference](../API_QUICK_REFERENCE.md)

3. **Explore the architecture**:
   - [System Architecture](../ARCHITECTURE.md)

4. **Try the tutorials**:
   - [Tutorials Directory](../tutorials/)

---

## Troubleshooting

### Common Issues

**Zig: "module not found"**
```bash
# Add Ananke to import path
zig build-exe example.zig --pkg-begin ananke /path/to/ananke/src/root.zig --pkg-end
```

**Rust: "MODAL_ENDPOINT not set"**
```bash
# Set environment variables
export MODAL_ENDPOINT="https://example.modal.run"
export MODAL_API_KEY="your-key"
```

**Rust: "connection refused"**
- Check Modal endpoint is running
- Verify network connectivity
- Check API key validity

### Performance Issues

**Zig extraction slow**:
- Check file size (>2000 lines may take 50ms+)
- Disable Claude if not needed
- Use arena allocators

**Rust generation slow**:
- Check network latency to Modal
- Try smaller `max_tokens`
- Lower temperature (0.3 vs 0.7)

---

## Contributing Examples

When adding new examples:

1. **Follow naming convention**: `{lang}_{topic}.{ext}`
2. **Include header comment** with description
3. **Add to this README** with overview
4. **Test compilation** before committing
5. **Include expected output** in comments

---

## Example File Sizes

| File | Lines | Size | Complexity |
|------|-------|------|------------|
| zig_basic_extraction.zig | 120 | 3.4 KB | Beginner |
| zig_full_pipeline.zig | 180 | 5.6 KB | Intermediate |
| zig_custom_patterns.zig | 140 | 3.7 KB | Intermediate |
| rust_orchestrator.rs | 200 | 6.1 KB | Intermediate |
| rust_modal_client.rs | 130 | 3.0 KB | Beginner |
| rust_ffi_integration.rs | 180 | 5.2 KB | Advanced |

---

**Examples Collection**: 6 files, 950 lines total, 27.2 KB
