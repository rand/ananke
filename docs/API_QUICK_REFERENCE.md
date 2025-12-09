# Ananke API Quick Reference

One-page cheat sheet for common operations.

**Version**: 0.1.0 | **Updated**: November 24, 2025

---

## Zig API

### Quick Start

```zig
const ananke = @import("ananke");
const std = @import("std");

var ananke_instance = try ananke.Ananke.init(allocator);
defer ananke_instance.deinit();

var constraints = try ananke_instance.extract(source, "typescript");
defer constraints.deinit();

var ir = try ananke_instance.compile(constraints.constraints.items);
defer ir.deinit(allocator);
```

### Core Operations

| Operation | Code | Time |
|-----------|------|------|
| **Initialize** | `ananke.Ananke.init(allocator)` | ~1ms |
| **Extract** | `extract(source, "typescript")` | 4-7ms |
| **Compile** | `compile(constraints)` | 10ms |
| **llguidance** | `braid.toLLGuidanceSchema(ir)` | <5ms |

### Supported Languages

`"typescript"`, `"javascript"`, `"python"`, `"rust"`, `"go"`, `"zig"`, `"c"`, `"cpp"`, `"java"`

### Constraint Kinds

```zig
.syntactic      // Code structure
.type_safety    // Type annotations
.semantic       // Data/control flow
.architectural  // Module boundaries
.operational    // Performance
.security       // Input validation, auth
```

### Priority Levels

```zig
.Low, .Medium, .High, .Critical
```

### Memory Management

```zig
// Always use defer for cleanup
var instance = try ananke.Ananke.init(allocator);
defer instance.deinit();

// Use arena for temporary allocations
var arena = std.heap.ArenaAllocator.init(allocator);
defer arena.deinit();
```

---

## Rust API

### Quick Start

```rust
use ananke_maze::{MazeOrchestrator, ModalConfig, GenerationRequest};

let config = ModalConfig::from_env()?;
let orchestrator = MazeOrchestrator::new(config)?;

let request = GenerationRequest {
    prompt: "Add validation".to_string(),
    constraints_ir: vec![],
    max_tokens: 500,
    temperature: 0.7,
    context: None,
};

let response = orchestrator.generate(request).await?;
```

### Core Operations

| Operation | Code | Time |
|-----------|------|------|
| **Create** | `MazeOrchestrator::new(config)` | <10ms |
| **Generate** | `orchestrator.generate(request).await` | 1-5s |
| **Compile** | `compile_constraints(&ir).await` | 5-20ms |
| **Cache Hit** | (automatic) | <1ms |

### Configuration

```rust
// From environment
let config = ModalConfig::from_env()?;

// Custom
let config = ModalConfig::new(endpoint, model)
    .with_api_key(key)
    .with_timeout(600);

let maze_config = MazeConfig {
    max_tokens: 2048,
    temperature: 0.7,
    enable_cache: true,
    cache_size_limit: 1000,
    timeout_secs: 300,
};
```

### Environment Variables

```bash
MODAL_ENDPOINT="https://app.modal.run"
MODAL_API_KEY="sk-..."
MODAL_MODEL="meta-llama/Llama-3.1-8B-Instruct"
```

---

## Common Patterns

### Extract from File (Zig)

```zig
const source = try std.fs.cwd().readFileAlloc(allocator, "auth.ts", 10_000_000);
defer allocator.free(source);

var clew = try ananke.clew.Clew.init(allocator);
defer clew.deinit();

var constraints = try clew.extractFromCode(source, "typescript");
defer constraints.deinit();
```

### Full Pipeline (Zig)

```zig
// Extract
var constraints = try ananke_instance.extract(source, lang);
defer constraints.deinit();

// Compile
var ir = try ananke_instance.compile(constraints.constraints.items);
defer ir.deinit(allocator);

// To llguidance
const json = try braid.toLLGuidanceSchema(ir);
defer allocator.free(json);
```

### Generate with Context (Rust)

```rust
let context = GenerationContext {
    current_file: Some("auth.ts".to_string()),
    language: Some("typescript".to_string()),
    project_root: Some("/project".to_string()),
    metadata: HashMap::new(),
};

let request = GenerationRequest {
    prompt: "Add authentication".to_string(),
    constraints_ir: vec![constraint],
    max_tokens: 500,
    temperature: 0.7,
    context: Some(context),
};

let response = orchestrator.generate(request).await?;
println!("{}", response.code);
```

### Batch Processing (Rust)

```rust
let futures: Vec<_> = requests.into_iter()
    .map(|req| orchestrator.generate(req))
    .collect();

let results = futures::future::join_all(futures).await;
```

---

## Error Handling

### Zig

```zig
var instance = ananke.Ananke.init(allocator) catch |err| {
    std.debug.print("Error: {}\n", .{err});
    return err;
};
```

### Rust

```rust
use anyhow::Context;

orchestrator.generate(request).await
    .context("Failed to generate code")?;
```

---

## Performance Tips

### Zig

1. **Reuse instances** - Don't create new Clew/Braid per file
2. **Arena allocators** - Use for temporary constraint strings
3. **Cache results** - Hash source + language for caching
4. **Skip Claude** - Use pattern-based extraction in CI/CD

### Rust

1. **Enable caching** - `enable_cache: true`
2. **Reuse orchestrator** - Single instance per service
3. **Parallel requests** - Use `join_all` for batches
4. **Lower temperature** - Faster generation (0.3 vs 0.7)
5. **Limit tokens** - Only request what you need

---

## Type Sizes

| Type | Zig | Rust |
|------|-----|------|
| **Constraint** | ~200 bytes | ~200 bytes |
| **ConstraintIR** | ~100 bytes | ~150 bytes |
| **Orchestrator** | N/A | 10-50 MB |
| **Cache Entry** | ~10 KB | ~10 KB |

---

## Benchmarks

### Zig (M1/M2 Mac, AMD Ryzen 5000+)

| Operation | Small | Medium | Large |
|-----------|-------|--------|-------|
| **Extract** | 2-5ms | 5-15ms | 15-50ms |
| **Compile** | 1-3ms | 3-10ms | 10-30ms |
| **Full** | 5-10ms | 10-25ms | 25-80ms |

Small: <100 lines | Medium: 100-500 lines | Large: 500-2000 lines

### Rust + GPU Inference

| Tokens | Llama-3.1-8B | Llama-3.1-70B |
|--------|--------------|---------------|
| **50** | 0.5-2s | 2-5s |
| **200** | 2-5s | 5-12s |
| **1000** | 5-15s | 15-40s |

Throughput: 8B: 20-40 tok/s | 70B: 5-15 tok/s

---

## Error Codes

### Zig FFI

```zig
Success = 0
NullPointer = 1
AllocationFailure = 2
InvalidInput = 3
ExtractionFailed = 4
CompilationFailed = 5
```

### Rust

Uses `anyhow::Result` - check error messages for details.

---

## FFI Workflow

```
Zig (Clew/Braid) → ConstraintIR → FFI → Rust (Maze) → Modal → Generated Code
     ↑                                              ↓
     Extract/Compile                          GenerationResult → FFI → Zig
```

**Memory**: Always free FFI pointers:
- Zig: `ananke_free_constraint_ir(ptr)`
- Rust: `free_constraint_ir_ffi(ptr)`

---

## Quick Debugging

### Enable Logging (Zig)

```zig
std.log.info("Extracted {} constraints", .{count});
```

### Enable Logging (Rust)

```rust
env_logger::init();  // or tracing_subscriber::fmt::init()

tracing::info!(tokens = n, "Generated");
```

### Check Cache

```rust
let stats = orchestrator.cache_stats().await;
println!("Cache: {}/{}", stats.size, stats.limit);
```

### Profile Performance

```bash
# Zig
zig build -Doptimize=ReleaseFast

# Rust
cargo build --release
cargo flamegraph
```

---

## Common Issues

| Issue | Solution |
|-------|----------|
| **OutOfMemory** | Use arena allocator or reduce batch size |
| **InvalidLanguage** | Check language string is supported |
| **Modal timeout** | Increase `timeout_secs` or reduce `max_tokens` |
| **Cache full** | Increase `cache_size_limit` or call `clear_cache()` |
| **Slow extraction** | Disable Claude, use pattern-based only |

---

## See Also

- [Full Zig API](/Users/rand/src/ananke/docs/API_REFERENCE_ZIG.md)
- [Full Rust API](/Users/rand/src/ananke/docs/API_REFERENCE_RUST.md)
- [Examples](/Users/rand/src/ananke/docs/api_examples/)
- [Architecture](/Users/rand/src/ananke/docs/ARCHITECTURE.md)

---

**Cheat Sheet Version**: 0.1.0 | **Generated**: November 24, 2025
