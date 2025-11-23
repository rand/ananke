# Maze-Zig Integration Architecture

## Overview

This document describes how the Rust Maze orchestration layer integrates with the Zig constraint engines (Clew/Braid/Ariadne) in Ananke.

## System Architecture

```
┌───────────────────────────────────────────────────────────────────┐
│                     Zig Core (Ananke)                             │
│  Location: /Users/rand/src/ananke/src/                            │
├───────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌─────────────┐    ┌──────────────┐    ┌─────────────┐        │
│  │    Clew     │───▶│    Braid     │───▶│  Ariadne    │        │
│  │  (Extract)  │    │  (Compile)   │    │    (DSL)    │        │
│  └─────────────┘    └──────────────┘    └─────────────┘        │
│         │                  │                    │                │
│         └──────────────────┴────────────────────┘                │
│                            │                                     │
│                            ▼                                     │
│                     ConstraintIR                                 │
│                    (Zig structure)                               │
│                                                                   │
└───────────────────────────┬───────────────────────────────────────┘
                            │
                            │ FFI Bridge (C ABI)
                            │
┌───────────────────────────▼───────────────────────────────────────┐
│                  Rust Maze Orchestration                          │
│  Location: /Users/rand/src/ananke/maze/                           │
├───────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  ffi.rs (FFI Layer)                                     │    │
│  │  • ConstraintIRFFI ← → ConstraintIR conversion         │    │
│  │  • IntentFFI ← → Intent conversion                      │    │
│  │  • Memory management (malloc/free)                      │    │
│  │  • Type safety across language boundary                 │    │
│  └────────────────────────┬────────────────────────────────┘    │
│                           │                                      │
│  ┌────────────────────────▼───────────────────────────────┐    │
│  │  lib.rs (Core Orchestration)                           │    │
│  │  • MazeOrchestrator                                    │    │
│  │  • Constraint compilation to llguidance                │    │
│  │  • Constraint caching                                  │    │
│  │  • Provenance tracking                                 │    │
│  └────────────────────────┬───────────────────────────────┘    │
│                           │                                      │
│  ┌────────────────────────▼───────────────────────────────┐    │
│  │  modal_client.rs (Inference Client)                    │    │
│  │  • HTTP client for Modal service                       │    │
│  │  • Request/response handling                           │    │
│  │  • Retry logic & error handling                        │    │
│  └────────────────────────┬───────────────────────────────┘    │
│                           │                                      │
└───────────────────────────┼───────────────────────────────────────┘
                            │
                            │ HTTPS/JSON
                            │
┌───────────────────────────▼───────────────────────────────────────┐
│               Modal Inference Service                             │
│  Location: /Users/rand/src/ananke/modal_inference/                │
├───────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────┐                                                │
│  │   vLLM/      │    ┌──────────────┐                           │
│  │   SGLang     │───▶│  llguidance  │                           │
│  │   Server     │    │   Engine     │                           │
│  └──────────────┘    └──────────────┘                           │
│         │                    │                                   │
│         │                    │                                   │
│         ▼                    ▼                                   │
│  ┌─────────────────────────────────┐                            │
│  │   Llama 3.1 / DeepSeek / etc    │                            │
│  │   (GPU-accelerated inference)    │                            │
│  └─────────────────────────────────┘                            │
│                                                                   │
└───────────────────────────────────────────────────────────────────┘
```

## Data Flow

### 1. Constraint Extraction & Compilation (Zig)

```zig
// In Zig code: src/main.zig
const ananke = @import("root.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Step 1: Extract constraints using Clew
    const clew = ananke.Clew.init(allocator);
    const constraints = try clew.extractFromCode(source_code);

    // Step 2: Compile constraints using Braid
    const braid = ananke.Braid.init(allocator);
    const constraint_ir = try braid.compile(constraints);

    // Step 3: Convert to C-compatible FFI format
    const ffi_constraints = try allocator.alloc(ConstraintIRFFI, constraint_ir.len);
    for (constraint_ir, 0..) |ir, i| {
        ffi_constraints[i] = try ir.toFFI(allocator);
    }

    // Step 4: Call Rust Maze via FFI
    const intent = Intent{
        .raw_input = "Implement secure API handler",
        .prompt = "Implement secure API handler",
        .current_file = "src/api/auth.rs",
        .language = "rust",
    };

    const result = maze_generate(&intent, ffi_constraints.ptr, ffi_constraints.len);
    defer maze_free_result(result);

    if (result.success) {
        std.debug.print("Generated: {s}\n", .{result.code});
    }
}
```

### 2. FFI Bridge (Rust)

```rust
// In Rust code: maze/src/ffi.rs

// Receives C-compatible structures from Zig
#[no_mangle]
pub extern "C" fn maze_generate(
    intent: *const IntentFFI,
    constraints: *const ConstraintIRFFI,
    constraints_len: usize,
) -> *mut GenerationResultFFI {
    // Convert from C to Rust types
    let intent = unsafe { Intent::from_ffi(intent).unwrap() };
    let constraint_slice = unsafe {
        std::slice::from_raw_parts(constraints, constraints_len)
    };

    let rust_constraints: Vec<ConstraintIR> = constraint_slice
        .iter()
        .map(|c| unsafe { ConstraintIR::from_ffi(c).unwrap() })
        .collect();

    // Call Rust orchestrator
    let runtime = tokio::runtime::Runtime::new().unwrap();
    let result = runtime.block_on(async {
        let config = ModalConfig::from_env().unwrap();
        let orchestrator = MazeOrchestrator::new(config).unwrap();

        let request = GenerationRequest {
            prompt: intent.prompt,
            constraints_ir: rust_constraints,
            max_tokens: 2048,
            temperature: 0.7,
            context: None,
        };

        orchestrator.generate(request).await
    });

    // Convert result to C-compatible format
    match result {
        Ok(response) => {
            GenerationResult {
                code: response.code,
                success: true,
                error: None,
                tokens_generated: response.metadata.tokens_generated,
                generation_time_ms: response.metadata.generation_time_ms,
            }.to_ffi()
        }
        Err(e) => {
            GenerationResult {
                code: String::new(),
                success: false,
                error: Some(e.to_string()),
                tokens_generated: 0,
                generation_time_ms: 0,
            }.to_ffi()
        }
    }
}
```

### 3. Orchestration & Modal Communication (Rust)

```rust
// In Rust code: maze/src/lib.rs

impl MazeOrchestrator {
    pub async fn generate(&self, request: GenerationRequest) -> Result<GenerationResponse> {
        // 1. Compile constraints to llguidance format
        let compiled = self.compile_constraints(&request.constraints_ir).await?;

        // 2. Build Modal request
        let modal_request = InferenceRequest {
            prompt: request.prompt,
            constraints: compiled.llguidance_schema,
            max_tokens: request.max_tokens,
            temperature: request.temperature,
            context: request.context,
        };

        // 3. Send to Modal inference service
        let modal_response = self.modal_client
            .generate_constrained(modal_request)
            .await?;

        // 4. Build response with provenance
        Ok(GenerationResponse {
            code: modal_response.generated_text,
            provenance: /* ... */,
            validation: /* ... */,
            metadata: /* ... */,
        })
    }
}
```

## Type Mappings

### ConstraintIR: Zig ↔ Rust

| Zig Type | FFI Type | Rust Type |
|----------|----------|-----------|
| `[]const u8` (name) | `*const c_char` | `String` |
| `?JsonSchema` | `*const c_char` (JSON) | `Option<JsonSchema>` |
| `?Grammar` | `*const c_char` (JSON) | `Option<Grammar>` |
| `[]const Regex` | `*const *const c_char` + len | `Vec<RegexPattern>` |
| `?TokenMaskRules` | `*const TokenMaskRulesFFI` | `Option<TokenMaskRules>` |
| `u32` (priority) | `uint32_t` | `u32` |

### Memory Layout Example

```c
// C representation (compatible with both Zig and Rust)
typedef struct {
    const char* name;                    // "type_safety"
    const char* json_schema;             // "{\"type\":\"object\",...}" or NULL
    const char* grammar;                 // "{\"rules\":[...],...}" or NULL
    const char** regex_patterns;         // ["Result<.*>", NULL]
    size_t regex_patterns_len;           // 1
    TokenMaskRules* token_masks;         // struct or NULL
    uint32_t priority;                   // 1
} ConstraintIRFFI;

typedef struct {
    const uint32_t* allowed_tokens;      // [1, 2, 3, ...] or NULL
    size_t allowed_tokens_len;           // 0 if NULL
    const uint32_t* forbidden_tokens;    // [100, 101, ...] or NULL
    size_t forbidden_tokens_len;         // 0 if NULL
} TokenMaskRulesFFI;
```

## Build Integration

### Zig builds Rust as part of its build

```zig
// build.zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    // ... Zig compilation ...

    // Build Rust Maze
    const maze_build = b.addSystemCommand(&.{
        "cargo",
        "build",
        "--release",
        "--manifest-path",
        "maze/Cargo.toml",
    });

    // Link Rust library
    exe.linkLibC();
    exe.addLibraryPath(.{ .path = "maze/target/release" });
    exe.linkSystemLibrary("maze");
}
```

### Rust links to Zig library

```rust
// build.rs
fn main() {
    // Link to Zig-compiled Ananke core
    println!("cargo:rustc-link-search=native=../zig-out/lib");
    println!("cargo:rustc-link-lib=static=ananke");
}
```

## Error Handling

### Zig Error Propagation

```zig
const result = maze_generate(&intent, constraints.ptr, constraints.len);
defer maze_free_result(result);

if (!result.success) {
    const error_msg = std.mem.span(result.error);
    std.debug.print("Error: {s}\n", .{error_msg});
    return error.MazeGenerationFailed;
}
```

### Rust Error Context

```rust
// Detailed error chain available in Rust
Err(e) => {
    tracing::error!("Generation failed: {:#}", e);
    // e contains full context:
    // - Network error details
    // - Modal API error
    // - Constraint compilation errors
}
```

## Performance Considerations

### Constraint Caching

The Rust layer caches compiled constraints to avoid redundant llguidance compilation:

```rust
// First call: ~10-50ms (compilation)
let result1 = orchestrator.generate(request).await?;

// Subsequent calls with same constraints: ~1μs (cache hit)
let result2 = orchestrator.generate(request).await?;
```

### FFI Overhead

- **Type conversion**: ~10-100μs per constraint
- **Memory allocation**: ~1-10μs per allocation
- **String copying**: ~1μs per 1KB of text

Total FFI overhead is typically <1ms and negligible compared to inference latency (2-10s).

## Testing

### Unit Tests (Rust)

```bash
cd maze
cargo test
```

### Integration Tests (Zig + Rust)

```bash
# From project root
zig build test

# This will:
# 1. Build Zig constraint engines
# 2. Build Rust Maze
# 3. Run FFI integration tests
# 4. Verify end-to-end pipeline
```

### Mock Modal Service

For testing without GPU infrastructure:

```rust
// In tests
use mockito::mock;

#[tokio::test]
async fn test_generation_with_mock() {
    let _m = mock("POST", "/generate")
        .with_status(200)
        .with_body(r#"{"generated_text":"fn main() {}","tokens_generated":10}"#)
        .create();

    // Test orchestrator with mock
}
```

## Deployment

### Development

```bash
# Terminal 1: Run local inference (if available)
modal serve modal_inference.modal_inference

# Terminal 2: Set environment
export MODAL_ENDPOINT=http://localhost:8000
export RUST_LOG=maze=debug

# Terminal 3: Run Zig CLI
zig build run -- generate "implement feature"
```

### Production

```bash
# Deploy Modal service
modal deploy modal_inference.modal_inference

# Configure Zig CLI
export MODAL_ENDPOINT=https://your-app.modal.run
export MODAL_API_KEY=your-api-key

# Build release binaries
zig build -Doptimize=ReleaseFast

# Distribute
./zig-out/bin/ananke generate "implement feature"
```

## Troubleshooting

### FFI Issues

**Symptom**: Segfault or memory corruption

**Solutions**:
1. Verify pointer validity: `if ptr.is_null() { return error; }`
2. Check string encoding: UTF-8 required
3. Ensure proper memory ownership
4. Use Valgrind/AddressSanitizer

### Build Issues

**Symptom**: Linking errors

**Solutions**:
1. Verify Zig built first: `zig build`
2. Check library paths in `build.rs`
3. Ensure compatible target triples
4. Check platform-specific linker flags

### Runtime Issues

**Symptom**: "MODAL_ENDPOINT not set"

**Solution**: Set environment variables or use config file

**Symptom**: "Connection refused"

**Solution**: Verify Modal service is deployed and accessible

## Future Work

- [ ] Add streaming generation support
- [ ] Implement constraint visualization
- [ ] Add performance profiling
- [ ] Support local GGUF models
- [ ] Optimize FFI type conversions
- [ ] Add constraint merging strategies
