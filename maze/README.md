# Maze - Orchestration Layer for Constrained Code Generation

Maze is the Rust orchestration layer for Ananke that coordinates between Zig-based constraint engines (Clew/Braid/Ariadne) and GPU-based inference services (vLLM + llguidance) to perform token-level constrained code generation.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│              Ananke Core (Zig)                          │
│                                                         │
│  Clew (Extract) → Braid (Compile) → ConstraintIR       │
│                                                         │
└────────────────────┬────────────────────────────────────┘
                     │ FFI Bridge
                     ▼
┌─────────────────────────────────────────────────────────┐
│              Maze Orchestration (Rust)                  │
│                                                         │
│  • Constraint compilation to llguidance format          │
│  • Constraint caching for performance                   │
│  • Modal/inference client management                    │
│  • Provenance tracking                                  │
│  • Error handling and retry logic                       │
│                                                         │
└────────────────────┬────────────────────────────────────┘
                     │ HTTP/API
                     ▼
┌─────────────────────────────────────────────────────────┐
│        Modal/RunPod/Local Inference Service             │
│                                                         │
│  vLLM/SGLang + llguidance                               │
│  • Token-level constraint enforcement                   │
│  • ~50μs per token masking                              │
│  • Grammar/schema validation                            │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## Python API & CLI

Maze provides Python bindings via PyO3 and a comprehensive CLI for easy integration:

### Quick Start - Python

```bash
# Install Python package
cd python
pip install -e .

# Set endpoint
export ANANKE_MODAL_ENDPOINT="https://your-inference-service.modal.run"
```

```python
import asyncio
from ananke import Ananke, PyGenerationRequest, PyGenerationContext

async def main():
    # Initialize from environment
    ananke = Ananke.from_env()

    # Create request
    request = PyGenerationRequest(
        prompt="def fibonacci(n):\n    '''Calculate nth Fibonacci number'''",
        constraints_ir=[],
        max_tokens=200,
        temperature=0.7,
        context=PyGenerationContext(
            current_file="example.py",
            language="python",
            project_root="."
        )
    )

    # Generate
    response = await ananke.generate(request)
    print(response.code)

asyncio.run(main())
```

### Quick Start - CLI

```bash
# Install CLI
pip install -e .

# Check configuration
ananke config

# Health check
ananke health

# Generate code
ananke generate "def hello_world():" --max-tokens 50

# Generate with JSON Schema constraints
cat > user_schema.json << 'EOF'
{
  "type": "object",
  "properties": {
    "name": {"type": "string"},
    "age": {"type": "integer"}
  },
  "required": ["name"]
}
EOF

ananke generate "Create a user:" --constraints user_schema.json --max-tokens 100

# View cache stats
ananke cache

# Clear cache
ananke cache --clear
```

### Documentation

- **[Python API Reference](../docs/PYTHON_API.md)** - Complete Python API documentation
- **[CLI User Guide](../docs/CLI_GUIDE.md)** - Command-line interface guide
- **[Troubleshooting Guide](../docs/TROUBLESHOOTING.md)** - Common issues and solutions
- **[Python Examples](./examples/python/)** - 6+ runnable examples

## Key Responsibilities

### 1. **Constraint Compilation**
Converts ConstraintIR from Braid into llguidance-compatible formats:
- JSON schemas for structured constraints
- Context-free grammars for syntax constraints
- Regex patterns for pattern matching
- Token masks for direct token control

### 2. **Inference Orchestration**
Manages communication with inference services:
- HTTP client for Modal/RunPod endpoints
- Request/response serialization
- Timeout and retry handling
- Streaming support (future)

### 3. **FFI Bridge**
Provides C-compatible interface for Zig integration:
- Type-safe conversion between Zig and Rust types
- Memory management for cross-language calls
- Error propagation across FFI boundary

### 4. **Caching & Performance**
Optimizes repeated operations:
- Constraint compilation caching
- LRU eviction policy
- Configurable cache sizes

### 5. **Provenance Tracking**
Records generation metadata:
- Model used
- Constraints applied
- Timestamps
- Token counts and timing

## Integration with Zig

### Data Flow

1. **Zig → Rust**: ConstraintIR + Intent
   ```zig
   // Zig side (src/braid/braid.zig)
   const ir = try braid.compile(constraints);
   const result = try maze_generate(intent, ir);
   ```

2. **Rust Processing**: Compile & Send to Modal
   ```rust
   // Rust side (maze/src/lib.rs)
   let llguidance_schema = compile_to_llguidance(&constraint_ir)?;
   let response = modal_client.generate_constrained(request).await?;
   ```

3. **Rust → Zig**: GenerationResult
   ```zig
   // Zig receives result via FFI
   std.debug.print("Generated: {s}\n", .{result.code});
   ```

### FFI Types

#### ConstraintIR (C-compatible)
```c
typedef struct {
    const char* json_schema;      // JSON string (nullable)
    const char* grammar;          // JSON string (nullable)
    const char** regex_patterns;  // Array of patterns
    size_t regex_patterns_len;
    TokenMaskRules* token_masks;  // Token IDs (nullable)
    uint32_t priority;
    const char* name;             // Constraint name
} ConstraintIR;
```

#### Intent (C-compatible)
```c
typedef struct {
    const char* raw_input;
    const char* prompt;
    const char* current_file;  // nullable
    const char* language;      // nullable
} Intent;
```

#### GenerationResult (C-compatible)
```c
typedef struct {
    const char* code;
    bool success;
    const char* error;         // nullable
    size_t tokens_generated;
    uint64_t generation_time_ms;
} GenerationResult;
```

### Memory Management

**Zig allocates → Rust reads → Zig frees**
- Zig owns ConstraintIR memory
- Rust makes temporary copies for processing
- Zig calls `free_constraint_ir_ffi` when done

**Rust allocates → Zig reads → Rust frees**
- Rust owns GenerationResult memory
- Zig extracts values
- Rust calls `free_generation_result_ffi` when done

## Usage

### From Rust

```rust
use maze::{MazeOrchestrator, ModalConfig, GenerationRequest};
use maze::ffi::ConstraintIR;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Configure Modal endpoint
    let config = ModalConfig::from_env()?;
    let orchestrator = MazeOrchestrator::new(config)?;

    // Create generation request
    let request = GenerationRequest {
        prompt: "Implement secure API handler".to_string(),
        constraints_ir: vec![/* ... */],
        max_tokens: 2048,
        temperature: 0.7,
        context: None,
    };

    // Generate with constraints
    let response = orchestrator.generate(request).await?;
    println!("Generated: {}", response.code);

    Ok(())
}
```

### From Zig (via FFI)

```zig
// In src/maze/maze.zig
const std = @import("std");

extern fn maze_generate(
    intent: *const Intent,
    constraints: [*]const ConstraintIR,
    constraints_len: usize,
) *GenerationResult;

pub fn generate(
    intent: Intent,
    constraints: []const ConstraintIR,
) !GenerationResult {
    const result_ptr = maze_generate(&intent, constraints.ptr, constraints.len);
    defer free_generation_result_ffi(result_ptr);

    if (!result_ptr.success) {
        return error.GenerationFailed;
    }

    return GenerationResult{
        .code = std.mem.span(result_ptr.code),
        .tokens_generated = result_ptr.tokens_generated,
        .generation_time_ms = result_ptr.generation_time_ms,
    };
}
```

## Configuration

### Environment Variables

```bash
# Required
export MODAL_ENDPOINT="https://ananke-inference.modal.run"

# Optional
export MODAL_API_KEY="your-api-key"
export MODAL_MODEL="meta-llama/Llama-3.1-70B-Instruct"
export RUST_LOG="maze=debug"
```

### Programmatic Configuration

```rust
use maze::{MazeOrchestrator, ModalConfig, MazeConfig};

let modal_config = ModalConfig::new(
    "https://ananke-inference.modal.run".to_string(),
    "meta-llama/Llama-3.1-8B-Instruct".to_string(),
)
.with_api_key("your-key".to_string())
.with_timeout(300);

let maze_config = MazeConfig {
    max_tokens: 4096,
    temperature: 0.7,
    enable_cache: true,
    cache_size_limit: 1000,
    timeout_secs: 300,
};

let orchestrator = MazeOrchestrator::with_config(modal_config, maze_config)?;
```

## Building

### Standalone Rust Build

```bash
cd maze
cargo build --release
```

### Integrated with Zig

```bash
# From Ananke root
zig build

# This will:
# 1. Build Zig constraint engines (Clew/Braid)
# 2. Build Rust Maze orchestration
# 3. Link them together via FFI
```

### Running Examples

```bash
# Set up Modal endpoint first
export MODAL_ENDPOINT="https://your-inference-service.modal.run"

# Run simple generation example
cargo run --example simple_generation
```

## Testing

```bash
# Unit tests
cargo test

# Integration tests (requires Modal service)
cargo test --test integration -- --ignored

# With logging
RUST_LOG=maze=debug cargo test
```

## Performance Characteristics

### Constraint Compilation
- **Cache hit**: ~1μs (hash lookup)
- **Cache miss**: ~10-50ms (depending on complexity)
- **Cache size**: Default 1000 entries, configurable

### Inference Latency
- **Cold start**: 3-5 seconds (Modal container startup)
- **Warm request**: 2-10 seconds (depending on token count)
- **Per-token**: ~100-500ms (model dependent)
- **Constraint masking**: ~50μs per token (llguidance)

### Memory Usage
- **Base**: ~10MB (Rust runtime + tokio)
- **Per request**: ~1-5MB (depending on constraint complexity)
- **Cache**: ~100KB per cached constraint

## Error Handling

Maze uses `anyhow` for error propagation and provides detailed error contexts:

```rust
match orchestrator.generate(request).await {
    Ok(response) => {
        // Success
    }
    Err(e) => {
        // e contains full error chain
        eprintln!("Generation failed: {:#}", e);

        // Root cause available
        if let Some(source) = e.source() {
            eprintln!("Caused by: {}", source);
        }
    }
}
```

Common error scenarios:
- **Network errors**: Connection timeout, DNS failure
- **Modal errors**: 429 rate limit, 503 service unavailable
- **Constraint errors**: Invalid schema, conflicting constraints
- **FFI errors**: Invalid pointer, UTF-8 conversion failure

## Future Enhancements

### Planned Features
- [ ] Streaming generation support
- [ ] Multi-model ensemble generation
- [ ] Local GGUF model support (llama.cpp integration)
- [ ] Constraint suggestion from examples
- [ ] Real-time constraint validation during generation
- [ ] Incremental constraint learning

### Research Areas
- [ ] Constraint synthesis from few-shot examples
- [ ] Probabilistic constraint relaxation
- [ ] Cross-language constraint transfer
- [ ] Formal verification of constraint satisfaction

## Dependencies

### Core
- `tokio` - Async runtime
- `reqwest` - HTTP client
- `serde` - Serialization
- `anyhow` - Error handling

### FFI
- `libc` - C compatibility
- Platform-specific linker flags

### Development
- `tracing` - Structured logging
- `mockito` - HTTP mocking for tests

## License

MIT OR Apache-2.0

## Contributing

Maze is part of the Ananke project. See the main repository for contribution guidelines.

## Support

For issues specific to Maze orchestration:
- Check Modal service health first
- Enable debug logging: `RUST_LOG=maze=debug`
- Review FFI memory management if using from Zig
- Validate constraint IR serialization

For general Ananke issues, see the main repository.
