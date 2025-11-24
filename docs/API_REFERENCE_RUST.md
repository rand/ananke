# Ananke Rust API Reference

Complete API reference for Ananke's Rust components (Maze orchestration layer).

**Version**: 0.1.0  
**Generated**: November 24, 2025  
**Rust Version**: 1.80+

---

## Table of Contents

- [Quick Start](#quick-start)
- [MazeOrchestrator](#mazeorchestrator)
- [ModalClient](#modalclient)
- [FFI Integration](#ffi-integration)
- [Type Reference](#type-reference)
- [Usage Patterns](#usage-patterns)
- [Error Handling](#error-handling)
- [Performance](#performance)

---

## Quick Start

```rust
use ananke_maze::{MazeOrchestrator, ModalConfig, GenerationRequest};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Configure Modal inference service
    let config = ModalConfig::from_env()?;
    
    // Create orchestrator
    let orchestrator = MazeOrchestrator::new(config)?;
    
    // Generate code with constraints
    let request = GenerationRequest {
        prompt: "Implement a secure API handler for user authentication".to_string(),
        constraints_ir: vec![/* ConstraintIR from Zig */],
        max_tokens: 2048,
        temperature: 0.7,
        context: None,
    };
    
    let response = orchestrator.generate(request).await?;
    
    println!("Generated code:\n{}", response.code);
    println!("Tokens generated: {}", response.metadata.tokens_generated);
    println!("Generation time: {}ms", response.metadata.generation_time_ms);
    
    Ok(())
}
```

---

## MazeOrchestrator

Main orchestrator for constrained code generation. Coordinates between Zig constraint engines and GPU inference services.

### Struct Definition

```rust
pub struct MazeOrchestrator {
    modal_client: ModalClient,
    constraint_cache: Arc<Mutex<LruCache<String, CompiledConstraint>>>,
    config: MazeConfig,
}
```

**Fields** (private):
- `modal_client`: Client for Modal inference service
- `constraint_cache`: LRU cache for compiled constraints (O(1) operations)
- `config`: Orchestrator configuration

---

### Methods

#### `new`

Creates a new Maze orchestrator with default configuration.

```rust
pub fn new(modal_config: ModalConfig) -> Result<Self>
```

**Parameters**:
- `modal_config`: Configuration for Modal inference service

**Returns**: `Result<MazeOrchestrator>` - Orchestrator instance or error

**Errors**:
- Invalid Modal configuration
- Network initialization failure

**Example**:
```rust
let config = ModalConfig::from_env()?;
let orchestrator = MazeOrchestrator::new(config)?;
```

---

#### `with_config`

Creates orchestrator with custom configuration.

```rust
pub fn with_config(
    modal_config: ModalConfig, 
    maze_config: MazeConfig
) -> Result<Self>
```

**Parameters**:
- `modal_config`: Modal inference service configuration
- `maze_config`: Maze orchestrator configuration

**Returns**: `Result<MazeOrchestrator>`

**Example**:
```rust
let modal_config = ModalConfig::from_env()?;
let maze_config = MazeConfig {
    max_tokens: 4096,
    temperature: 0.5,
    enable_cache: true,
    cache_size_limit: 500,
    timeout_secs: 600,
};

let orchestrator = MazeOrchestrator::with_config(modal_config, maze_config)?;
```

---

#### `generate`

Generates code with constraint enforcement.

```rust
pub async fn generate(
    &self, 
    request: GenerationRequest
) -> Result<GenerationResponse>
```

**Parameters**:
- `request`: Generation request with prompt and constraints

**Returns**: `Result<GenerationResponse>` - Generated code with metadata

**Errors**:
- Constraint compilation failure
- Modal inference service error
- Network timeout
- Invalid constraint IR

**Pipeline**:
1. Compile constraints to llguidance format (with caching)
2. Send request to Modal inference service
3. Receive constrained generation
4. Build provenance and validation metadata
5. Return response with metrics

**Example**:
```rust
use ananke_maze::{GenerationRequest, GenerationContext};

let request = GenerationRequest {
    prompt: "Add input validation to this function".to_string(),
    constraints_ir: vec![security_constraints, type_constraints],
    max_tokens: 500,
    temperature: 0.7,
    context: Some(GenerationContext {
        current_file: Some("auth.ts".to_string()),
        language: Some("typescript".to_string()),
        project_root: Some("/project".to_string()),
        metadata: Default::default(),
    }),
};

let response = orchestrator.generate(request).await?;

println!("Code: {}", response.code);
println!("All constraints satisfied: {}", response.validation.all_satisfied);
```

**Performance**: Typical generation takes 1-5 seconds depending on token count and model speed.

---

#### `compile_constraints`

Compiles ConstraintIR to llguidance format with caching.

```rust
pub async fn compile_constraints(
    &self, 
    constraints_ir: &[ConstraintIR]
) -> Result<CompiledConstraint>
```

**Parameters**:
- `constraints_ir`: Array of constraint IR from Zig

**Returns**: `Result<CompiledConstraint>` - Compiled constraint ready for llguidance

**Caching**:
- Uses xxHash3 for high-performance hashing (2-3x faster than DefaultHasher)
- LRU eviction policy with O(1) operations
- Cache key based on constraint IR content
- Configurable cache size (default: 1000 entries)

**Example**:
```rust
let compiled = orchestrator.compile_constraints(&constraints_ir).await?;
println!("Cache key: {}", compiled.hash);
println!("Compiled at: {}", compiled.compiled_at);
```

**Performance**: 5-20ms for compilation, <1ms for cache hits.

---

#### `generate_cache_key`

Generates deterministic cache key from constraint IR.

```rust
pub fn generate_cache_key(
    &self, 
    constraints_ir: &[ConstraintIR]
) -> Result<String>
```

**Parameters**:
- `constraints_ir`: Constraints to hash

**Returns**: `Result<String>` - Hex-encoded hash (xxHash3)

**Example**:
```rust
let key = orchestrator.generate_cache_key(&constraints)?;
println!("Cache key: {}", key);
```

---

#### `clear_cache`

Clears the constraint compilation cache.

```rust
pub async fn clear_cache(&self) -> Result<()>
```

**Example**:
```rust
orchestrator.clear_cache().await?;
println!("Cache cleared");
```

**Use Cases**:
- After updating constraint extraction logic
- During development/testing
- Memory management in long-running services

---

#### `cache_stats`

Returns cache statistics.

```rust
pub async fn cache_stats(&self) -> CacheStats
```

**Returns**: Cache size and limit

**Example**:
```rust
let stats = orchestrator.cache_stats().await;
println!("Cache: {}/{} entries", stats.size, stats.limit);
println!("Hit rate: {:.2}%", (stats.hits as f64 / stats.total as f64) * 100.0);
```

---

## ModalClient

HTTP client for communicating with Modal-hosted vLLM + llguidance inference service.

### Struct Definition

```rust
pub struct ModalClient {
    client: reqwest::Client,
    config: ModalConfig,
    base_url: Url,
}
```

---

### Methods

#### `new`

Creates a new Modal client.

```rust
pub fn new(config: ModalConfig) -> Result<Self>
```

**Parameters**:
- `config`: Modal service configuration

**Returns**: `Result<ModalClient>`

**Errors**:
- Invalid endpoint URL
- HTTP client initialization failure

**Example**:
```rust
let config = ModalConfig::new(
    "https://my-app.modal.run".to_string(),
    "meta-llama/Llama-3.1-8B-Instruct".to_string(),
);

let client = ModalClient::new(config)?;
```

---

#### `generate_constrained`

Generates code with constraint enforcement.

```rust
pub async fn generate_constrained(
    &self, 
    request: InferenceRequest
) -> Result<InferenceResponse>
```

**Parameters**:
- `request`: Inference request with prompt and constraints

**Returns**: `Result<InferenceResponse>` - Generated text with statistics

**Retry Logic**:
- Exponential backoff (100ms, 200ms, 400ms, ...)
- Configurable max retries (default: 3)
- Can be disabled via config

**Example**:
```rust
use ananke_maze::modal_client::InferenceRequest;

let request = InferenceRequest {
    prompt: "def validate_email(email):".to_string(),
    constraints: llguidance_schema,
    max_tokens: 100,
    temperature: 0.7,
    context: None,
};

let response = client.generate_constrained(request).await?;
println!("Generated: {}", response.generated_text);
println!("Tokens: {}", response.tokens_generated);
```

---

#### `health_check`

Checks if Modal service is healthy.

```rust
pub async fn health_check(&self) -> Result<bool>
```

**Returns**: `Result<bool>` - true if service is healthy

**Example**:
```rust
if client.health_check().await? {
    println!("Modal service is healthy");
} else {
    println!("Modal service is down");
}
```

---

#### `list_models`

Lists available models from Modal service.

```rust
pub async fn list_models(&self) -> Result<Vec<String>>
```

**Returns**: `Result<Vec<String>>` - List of model identifiers

**Example**:
```rust
let models = client.list_models().await?;
for model in models {
    println!("Available model: {}", model);
}
```

---

#### `generate_stream`

Streaming generation (not yet implemented).

```rust
pub async fn generate_stream(
    &self, 
    request: InferenceRequest
) -> Result<()>
```

**Status**: Planned for future implementation.

---

## FFI Integration

### ConstraintIR

Rust-native constraint IR type matching Zig definition.

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConstraintIR {
    pub name: String,
    pub json_schema: Option<JsonSchema>,
    pub grammar: Option<Grammar>,
    pub regex_patterns: Vec<RegexPattern>,
    pub token_masks: Option<TokenMaskRules>,
    pub priority: u32,
}
```

**Fields**:
- `name`: Constraint identifier
- `json_schema`: JSON Schema for structured data
- `grammar`: Context-free grammar
- `regex_patterns`: Array of regex patterns
- `token_masks`: Token-level masking rules
- `priority`: Conflict resolution priority

#### Methods

##### `from_ffi`

Converts from C FFI representation to Rust.

```rust
pub unsafe fn from_ffi(
    ffi: *const ConstraintIRFFI
) -> Result<Self, String>
```

**Parameters**:
- `ffi`: Pointer to C-compatible ConstraintIR

**Returns**: `Result<ConstraintIR, String>` - Rust constraint IR or error

**Safety**: The FFI pointer must be valid and properly initialized.

**Example**:
```rust
// Called from Zig FFI
unsafe {
    let constraint_ir = ConstraintIR::from_ffi(zig_ir_ptr)?;
    println!("Converted constraint: {}", constraint_ir.name);
}
```

---

##### `to_ffi`

Converts to C FFI representation.

```rust
pub fn to_ffi(&self) -> *mut ConstraintIRFFI
```

**Returns**: Pointer to C-compatible struct (caller must free with `free_constraint_ir_ffi`)

**Example**:
```rust
let ffi_ptr = constraint_ir.to_ffi();
// Pass to Zig...
unsafe {
    free_constraint_ir_ffi(ffi_ptr);
}
```

---

### Intent

User intent for code generation.

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Intent {
    pub raw_input: String,
    pub prompt: String,
    pub current_file: Option<String>,
    pub language: Option<String>,
}
```

#### Methods

##### `from_ffi`

Converts from C FFI representation.

```rust
pub unsafe fn from_ffi(
    ffi: *const IntentFFI
) -> Result<Self, String>
```

**Example**:
```rust
unsafe {
    let intent = Intent::from_ffi(zig_intent_ptr)?;
    println!("Prompt: {}", intent.prompt);
}
```

---

### GenerationResult

Result of code generation.

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GenerationResult {
    pub code: String,
    pub success: bool,
    pub error: Option<String>,
    pub tokens_generated: usize,
    pub generation_time_ms: u64,
}
```

#### Methods

##### `to_ffi`

Converts to C FFI representation.

```rust
pub fn to_ffi(&self) -> *mut GenerationResultFFI
```

**Returns**: Pointer for FFI (caller must free with `free_generation_result_ffi`)

---

### FFI Memory Management

#### `free_constraint_ir_ffi`

Frees a ConstraintIR FFI structure.

```rust
#[no_mangle]
pub unsafe extern "C" fn free_constraint_ir_ffi(
    ptr: *mut ConstraintIRFFI
)
```

**Safety**: Must be called exactly once on pointers from `to_ffi`.

---

#### `free_generation_result_ffi`

Frees a GenerationResult FFI structure.

```rust
#[no_mangle]
pub unsafe extern "C" fn free_generation_result_ffi(
    ptr: *mut GenerationResultFFI
)
```

**Safety**: Must be called exactly once on pointers from `to_ffi`.

---

## Type Reference

### MazeConfig

Configuration for MazeOrchestrator.

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MazeConfig {
    pub max_tokens: usize,
    pub temperature: f32,
    pub enable_cache: bool,
    pub cache_size_limit: usize,
    pub timeout_secs: u64,
}
```

**Default Values**:
```rust
MazeConfig {
    max_tokens: 2048,
    temperature: 0.7,
    enable_cache: true,
    cache_size_limit: 1000,
    timeout_secs: 300,
}
```

---

### ModalConfig

Configuration for Modal inference service.

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ModalConfig {
    pub endpoint_url: String,
    pub api_key: Option<String>,
    pub timeout_secs: u64,
    pub model: String,
    pub enable_retry: bool,
    pub max_retries: usize,
}
```

#### Methods

##### `from_env`

Creates configuration from environment variables.

```rust
pub fn from_env() -> Result<Self>
```

**Environment Variables**:
- `MODAL_ENDPOINT`: Modal service URL (required)
- `MODAL_API_KEY`: API key for authentication (optional)
- `MODAL_MODEL`: Model identifier (default: meta-llama/Llama-3.1-8B-Instruct)

**Example**:
```bash
export MODAL_ENDPOINT="https://my-app.modal.run"
export MODAL_API_KEY="sk-..."
export MODAL_MODEL="meta-llama/Llama-3.1-70B-Instruct"
```

```rust
let config = ModalConfig::from_env()?;
```

---

##### `new`

Creates configuration with defaults.

```rust
pub fn new(endpoint_url: String, model: String) -> Self
```

---

##### `with_api_key`

Builder method to set API key.

```rust
pub fn with_api_key(self, api_key: String) -> Self
```

**Example**:
```rust
let config = ModalConfig::new(endpoint_url, model)
    .with_api_key("sk-...".to_string())
    .with_timeout(600);
```

---

##### `with_timeout`

Builder method to set timeout.

```rust
pub fn with_timeout(self, timeout_secs: u64) -> Self
```

---

### GenerationRequest

Request for code generation.

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GenerationRequest {
    pub prompt: String,
    pub constraints_ir: Vec<ConstraintIR>,
    pub max_tokens: usize,
    pub temperature: f32,
    pub context: Option<GenerationContext>,
}
```

**Fields**:
- `prompt`: User intent / generation prompt
- `constraints_ir`: Compiled constraints from Braid
- `max_tokens`: Maximum tokens to generate
- `temperature`: Sampling temperature (0.0-1.0)
- `context`: Optional context metadata

---

### GenerationContext

Context for code generation.

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GenerationContext {
    pub current_file: Option<String>,
    pub language: Option<String>,
    pub project_root: Option<String>,
    pub metadata: HashMap<String, serde_json::Value>,
}
```

**Example**:
```rust
let context = GenerationContext {
    current_file: Some("src/auth.rs".to_string()),
    language: Some("rust".to_string()),
    project_root: Some("/home/user/project".to_string()),
    metadata: {
        let mut m = HashMap::new();
        m.insert("framework".to_string(), json!("axum"));
        m.insert("version".to_string(), json!("0.7"));
        m
    },
};
```

---

### GenerationResponse

Response from code generation.

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GenerationResponse {
    pub code: String,
    pub provenance: Provenance,
    pub validation: ValidationResult,
    pub metadata: GenerationMetadata,
}
```

**Fields**:
- `code`: Generated code
- `provenance`: Tracking information
- `validation`: Constraint satisfaction results
- `metadata`: Performance metrics

---

### Provenance

Provenance tracking for generated code.

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Provenance {
    pub model: String,
    pub timestamp: i64,
    pub constraints_applied: Vec<String>,
    pub original_intent: String,
    pub parameters: HashMap<String, serde_json::Value>,
}
```

**Purpose**: Enables auditing and debugging of generated code.

**Example**:
```rust
println!("Generated by: {}", response.provenance.model);
println!("At: {}", response.provenance.timestamp);
println!("Constraints: {:?}", response.provenance.constraints_applied);
```

---

### ValidationResult

Constraint validation results.

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ValidationResult {
    pub all_satisfied: bool,
    pub satisfied: Vec<String>,
    pub violated: Vec<String>,
    pub metadata: HashMap<String, serde_json::Value>,
}
```

**Note**: With llguidance, `violated` should always be empty as constraints are enforced during generation.

---

### GenerationMetadata

Performance metrics for generation.

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GenerationMetadata {
    pub tokens_generated: usize,
    pub generation_time_ms: u64,
    pub avg_token_time_us: u64,
    pub constraint_compile_time_ms: u64,
}
```

**Example**:
```rust
let meta = &response.metadata;
println!("Generated {} tokens in {}ms", 
    meta.tokens_generated, meta.generation_time_ms);
println!("Average: {}us per token", meta.avg_token_time_us);
println!("Constraint compilation: {}ms", meta.constraint_compile_time_ms);
```

---

### CompiledConstraint

Compiled constraint ready for llguidance.

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CompiledConstraint {
    pub hash: String,
    pub llguidance_schema: serde_json::Value,
    pub compiled_at: i64,
}
```

---

### CacheStats

Cache statistics.

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CacheStats {
    pub size: usize,
    pub limit: usize,
}
```

---

### InferenceRequest

Request to Modal inference service.

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InferenceRequest {
    pub prompt: String,
    pub constraints: serde_json::Value,
    pub max_tokens: usize,
    pub temperature: f32,
    pub context: Option<GenerationContext>,
}
```

---

### InferenceResponse

Response from Modal inference service.

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InferenceResponse {
    pub generated_text: String,
    pub tokens_generated: usize,
    pub model: String,
    pub stats: GenerationStats,
}
```

---

### GenerationStats

Statistics from Modal inference.

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GenerationStats {
    pub total_time_ms: u64,
    pub time_per_token_us: u64,
    pub constraint_checks: usize,
    pub avg_constraint_check_us: u64,
}
```

---

## Usage Patterns

### Basic Generation

Simple code generation with constraints:

```rust
use ananke_maze::{MazeOrchestrator, ModalConfig, GenerationRequest};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Setup
    let modal_config = ModalConfig::from_env()?;
    let orchestrator = MazeOrchestrator::new(modal_config)?;
    
    // Load constraints from Zig
    let constraints_ir = load_constraints_from_zig()?;
    
    // Generate
    let request = GenerationRequest {
        prompt: "Create a function to validate user email addresses".to_string(),
        constraints_ir,
        max_tokens: 500,
        temperature: 0.7,
        context: None,
    };
    
    let response = orchestrator.generate(request).await?;
    
    // Use generated code
    println!("{}", response.code);
    
    Ok(())
}
```

---

### With Context

Provide context for better generation:

```rust
use ananke_maze::{GenerationRequest, GenerationContext};
use std::collections::HashMap;

let context = GenerationContext {
    current_file: Some("src/api/users.rs".to_string()),
    language: Some("rust".to_string()),
    project_root: Some(env::current_dir()?.to_string_lossy().to_string()),
    metadata: {
        let mut m = HashMap::new();
        m.insert("framework".to_string(), json!("axum"));
        m.insert("database".to_string(), json!("postgres"));
        m.insert("auth".to_string(), json!("jwt"));
        m
    },
};

let request = GenerationRequest {
    prompt: "Add authentication middleware".to_string(),
    constraints_ir: auth_constraints,
    max_tokens: 1000,
    temperature: 0.6,
    context: Some(context),
};

let response = orchestrator.generate(request).await?;
```

---

### Batch Processing

Process multiple generation requests efficiently:

```rust
use tokio::task::JoinSet;

async fn batch_generate(
    orchestrator: &MazeOrchestrator,
    requests: Vec<GenerationRequest>,
) -> anyhow::Result<Vec<GenerationResponse>> {
    let mut set = JoinSet::new();
    
    for request in requests {
        let orch = orchestrator.clone(); // Cheap Arc clone
        set.spawn(async move {
            orch.generate(request).await
        });
    }
    
    let mut results = Vec::new();
    while let Some(result) = set.join_next().await {
        results.push(result??);
    }
    
    Ok(results)
}
```

---

### With Zig FFI

Full pipeline from Zig to Rust:

```rust
use ananke_maze::ffi::{ConstraintIR, Intent};

// Receive from Zig
unsafe {
    let constraint_ir = ConstraintIR::from_ffi(zig_constraint_ptr)?;
    let intent = Intent::from_ffi(zig_intent_ptr)?;
    
    // Generate with Maze
    let modal_config = ModalConfig::from_env()?;
    let orchestrator = MazeOrchestrator::new(modal_config)?;
    
    let request = GenerationRequest {
        prompt: intent.prompt,
        constraints_ir: vec![constraint_ir],
        max_tokens: 2048,
        temperature: 0.7,
        context: Some(GenerationContext {
            current_file: intent.current_file,
            language: intent.language,
            project_root: None,
            metadata: HashMap::new(),
        }),
    };
    
    let response = orchestrator.generate(request).await?;
    
    // Convert back to FFI
    let result = GenerationResult {
        code: response.code,
        success: true,
        error: None,
        tokens_generated: response.metadata.tokens_generated,
        generation_time_ms: response.metadata.generation_time_ms,
    };
    
    let ffi_result = result.to_ffi();
    // Return to Zig...
}
```

---

### Custom Configuration

Fine-tune orchestrator behavior:

```rust
use ananke_maze::{MazeConfig, ModalConfig, MazeOrchestrator};

let modal_config = ModalConfig::new(
    "https://my-modal-app.modal.run".to_string(),
    "meta-llama/Llama-3.1-70B-Instruct".to_string(),
)
.with_api_key(api_key)
.with_timeout(600);

let maze_config = MazeConfig {
    max_tokens: 4096,
    temperature: 0.5,
    enable_cache: true,
    cache_size_limit: 2000,
    timeout_secs: 600,
};

let orchestrator = MazeOrchestrator::with_config(modal_config, maze_config)?;
```

---

### Monitoring and Metrics

Track performance and cache efficiency:

```rust
// Before generation
let stats_before = orchestrator.cache_stats().await;

// Generate
let response = orchestrator.generate(request).await?;

// After generation
let stats_after = orchestrator.cache_stats().await;

// Log metrics
tracing::info!(
    tokens = response.metadata.tokens_generated,
    gen_time_ms = response.metadata.generation_time_ms,
    compile_time_ms = response.metadata.constraint_compile_time_ms,
    cache_size = stats_after.size,
    "Generation completed"
);

// Calculate throughput
let tokens_per_sec = (response.metadata.tokens_generated as f64 / 
    response.metadata.generation_time_ms as f64) * 1000.0;

println!("Throughput: {:.2} tokens/sec", tokens_per_sec);
```

---

### Error Recovery

Handle errors gracefully:

```rust
use anyhow::Context;

let response = orchestrator.generate(request).await
    .context("Failed to generate code")?;

// Or with detailed error handling
let response = match orchestrator.generate(request).await {
    Ok(resp) => resp,
    Err(e) => {
        if e.to_string().contains("timeout") {
            tracing::warn!("Generation timed out, retrying with lower token limit");
            let mut retry_request = request.clone();
            retry_request.max_tokens /= 2;
            orchestrator.generate(retry_request).await?
        } else if e.to_string().contains("compilation") {
            tracing::error!("Constraint compilation failed: {}", e);
            return Err(e);
        } else {
            return Err(e);
        }
    }
};
```

---

### Streaming (Future)

Planned streaming API:

```rust
// Future API (not yet implemented)
let mut stream = client.generate_stream(request).await?;

while let Some(chunk) = stream.next().await {
    let chunk = chunk?;
    print!("{}", chunk.text);
    
    // Check constraint violations in real-time
    if !chunk.constraints_satisfied {
        println!("\nConstraint violation detected!");
        break;
    }
}
```

---

## Error Handling

### Error Types

Maze uses `anyhow::Result` for flexible error handling:

```rust
use anyhow::{Context, Result, anyhow};

pub type Result<T> = anyhow::Result<T>;
```

### Common Errors

**Configuration Errors**:
```rust
let config = ModalConfig::from_env()
    .context("MODAL_ENDPOINT environment variable not set")?;
```

**Network Errors**:
```rust
let response = client.generate_constrained(request).await
    .context("Failed to connect to Modal inference service")?;
```

**Constraint Compilation Errors**:
```rust
let compiled = orchestrator.compile_constraints(&constraints)
    .await
    .context("Failed to compile constraints to llguidance format")?;
```

### Error Context

Add context to errors for better debugging:

```rust
orchestrator.generate(request).await
    .with_context(|| format!(
        "Failed to generate code for prompt: {}", 
        request.prompt.chars().take(50).collect::<String>()
    ))?;
```

### Retry Logic

Modal client includes built-in retry with exponential backoff:

```rust
let config = ModalConfig::new(endpoint, model)
    .with_timeout(300)
    // Retry configuration
    config.enable_retry = true;
    config.max_retries = 3;  // Will retry up to 3 times
    
let client = ModalClient::new(config)?;

// Automatic retry with backoff: 100ms, 200ms, 400ms
let response = client.generate_constrained(request).await?;
```

Disable retries for testing:

```rust
let mut config = ModalConfig::from_env()?;
config.enable_retry = false;
config.max_retries = 1;
```

---

## Performance

### Benchmarks

Typical performance on modern hardware with GPU inference:

**Constraint Compilation**:
- Small set (<10 constraints): 5-10ms
- Medium set (10-50 constraints): 10-20ms
- Large set (50+ constraints): 20-50ms
- Cache hit: <1ms

**Code Generation** (with llguidance):
- Small (50 tokens): 500ms - 2s
- Medium (200 tokens): 2s - 5s
- Large (1000 tokens): 5s - 15s

**Throughput** (tokens/second):
- Llama-3.1-8B: 20-40 tokens/sec
- Llama-3.1-70B: 5-15 tokens/sec

Actual performance depends on:
- Model size
- Constraint complexity
- GPU hardware (A100, H100, etc.)
- Network latency
- Concurrent requests

### Optimization Tips

#### 1. Enable Caching

```rust
let config = MazeConfig {
    enable_cache: true,
    cache_size_limit: 2000,  // Larger cache for more reuse
    ..Default::default()
};
```

#### 2. Reuse Orchestrator

```rust
// BAD: Creating new orchestrator per request
for request in requests {
    let orch = MazeOrchestrator::new(config.clone())?;
    let _ = orch.generate(request).await?;
}

// GOOD: Reuse single instance
let orch = MazeOrchestrator::new(config)?;
for request in requests {
    let _ = orch.generate(request).await?;
}
```

#### 3. Parallel Requests

```rust
use futures::future::join_all;

let futures: Vec<_> = requests.into_iter()
    .map(|req| orchestrator.generate(req))
    .collect();

let results = join_all(futures).await;
```

#### 4. Tune Temperature

Lower temperature for faster, more deterministic generation:

```rust
let request = GenerationRequest {
    temperature: 0.3,  // Lower = faster, more focused
    ..request
};
```

#### 5. Limit Token Count

Request only what you need:

```rust
let request = GenerationRequest {
    max_tokens: 200,  // Don't over-allocate
    ..request
};
```

### Memory Usage

**Orchestrator**: ~10-50 MB depending on cache size

**Per Request**: ~1-5 MB for constraint compilation and serialization

**Cache**: Approximately `cache_size_limit * 10 KB` (typical constraint IR size)

Example: Cache with 1000 entries ≈ 10 MB

### Async Best Practices

#### Use Tokio Runtime

```rust
#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Maze is async-first
}
```

#### Spawn Tasks for Concurrency

```rust
let handle = tokio::spawn(async move {
    orchestrator.generate(request).await
});

let response = handle.await??;
```

#### Set Timeouts

```rust
use tokio::time::{timeout, Duration};

let result = timeout(
    Duration::from_secs(30),
    orchestrator.generate(request)
).await??;
```

---

## See Also

- [Zig API Reference](/Users/rand/src/ananke/docs/API_REFERENCE_ZIG.md) - Clew/Braid engines
- [Architecture](/Users/rand/src/ananke/docs/ARCHITECTURE.md) - System design
- [User Guide](/Users/rand/src/ananke/docs/USER_GUIDE.md) - Getting started
- [Examples](/Users/rand/src/ananke/docs/api_examples/) - Working code examples

---

**API Version**: 0.1.0  
**Last Updated**: November 24, 2025  
**Rust Version**: 1.80+
