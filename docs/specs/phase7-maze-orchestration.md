# Phase 7: Maze Orchestration Layer - Technical Specification

**Version**: 1.0  
**Status**: PROPOSED  
**Author**: spec-author (Claude Code subagent)  
**Date**: 2025-11-25  
**Target Completion**: Weeks 10-11 (from IMPLEMENTATION_PLAN.md)

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Problem Statement](#problem-statement)
3. [Goals and Non-Goals](#goals-and-non-goals)
4. [System Architecture](#system-architecture)
5. [API Specifications](#api-specifications)
6. [FFI Layer Design](#ffi-layer-design)
7. [Implementation Roadmap](#implementation-roadmap)
8. [Success Criteria](#success-criteria)
9. [Open Questions and Risks](#open-questions-and-risks)
10. [Appendices](#appendices)

---

## Executive Summary

Maze is the Rust-based orchestration layer that bridges Ananke's Zig constraint engines (Clew/Braid/Ariadne) with GPU-based inference services (vLLM + llguidance) to perform token-level constrained code generation.

**Current Status (as of 2025-11-25):**
- Core Rust implementation: PRODUCTION READY (43 tests passing)
- FFI bridge: COMPLETE and tested
- Modal client: PRODUCTION DEPLOYED at https://rand--ananke-inference-generate-api.modal.run
- Constraint compilation: IMPLEMENTED with LRU caching
- Missing pieces: **Python bindings for end-user consumption**

**Key Insight**: Most of Phase 7 is already complete. The primary remaining work is exposing Maze functionality through Python bindings for CLI and library usage patterns.

---

## Problem Statement

### Context

Ananke's constraint engines (Clew/Braid in Zig) produce ConstraintIR - a high-level intermediate representation of constraints. To perform **constrained generation** (not just analysis), we need:

1. A way to translate ConstraintIR into llguidance format (JSON Schema, CFG, regex)
2. Communication layer to GPU inference services (Modal/RunPod with vLLM)
3. Token-level constraint enforcement during generation
4. Cross-language interop (Zig ↔ Rust ↔ Python)

### Why Not Use Managed APIs?

**Claude/OpenAI APIs cannot be used for constrained generation** because:
- No access to raw logits (needed for token masking)
- No token-by-token intervention capability
- No real-time constraint application

Constrained generation requires control over the inference process, which only self-hosted or custom inference services provide.

### Why Rust for Maze?

1. **Async/await**: First-class async support for HTTP communication (Tokio)
2. **FFI compatibility**: C-compatible exports for Zig integration
3. **PyO3**: Native Python bindings for end-user APIs
4. **Performance**: Zero-cost abstractions, efficient caching
5. **Error handling**: Rich error context with `anyhow`
6. **Type safety**: Compile-time guarantees for FFI boundary

---

## Goals and Non-Goals

### Goals

1. **Translate ConstraintIR to llguidance format** with 100% fidelity
2. **Communicate reliably** with Modal/RunPod inference services (retry, timeout, error handling)
3. **Provide FFI bridge** between Zig and Rust with safe memory management
4. **Cache compiled constraints** for performance (LRU eviction, configurable size)
5. **Track provenance** for all generated code (model, constraints, timestamps)
6. **Expose Python API** for CLI and library usage
7. **Support streaming generation** (future enhancement)

### Non-Goals

1. **Not a constraint engine**: Maze does not extract or compile constraints (that's Clew/Braid)
2. **Not an inference engine**: Maze does not run models (that's vLLM/Modal)
3. **Not a managed API client**: Maze does not call Claude/OpenAI for generation
4. **Not a local model runner**: Maze communicates with remote services (local inference is future work)

### Constraints

1. **Must work with existing Zig codebase** (81 tests passing)
2. **Must work with deployed Modal service** (https://rand--ananke-inference-generate-api.modal.run)
3. **Must maintain FFI contract** (see /Users/rand/src/ananke/test/integration/FFI_CONTRACT.md)
4. **Must handle inference failures gracefully** (network errors, timeouts, rate limits)
5. **Must support multiple constraint types** (JSON Schema, CFG, regex, token masks)

---

## System Architecture

### High-Level Data Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                    User Application Layer                           │
│  (CLI, IDE Plugin, CI/CD Integration, Web Service)                  │
└───────────────────────┬─────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────────────┐
│                 Python API Layer (NEW - Phase 7)                    │
│                                                                     │
│  from ananke import Ananke                                          │
│  ananke = Ananke(modal_endpoint="...")                              │
│  result = await ananke.generate(intent, constraints)                │
│                                                                     │
└───────────────────────┬─────────────────────────────────────────────┘
                        │ PyO3 Bindings
                        ▼
┌─────────────────────────────────────────────────────────────────────┐
│              Maze Orchestration Layer (Rust)                        │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  MazeOrchestrator                                           │   │
│  │  • compile_constraints() -> llguidance schema               │   │
│  │  • generate() -> GenerationResponse                         │   │
│  │  • LRU cache for compiled constraints                       │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  ModalClient                                                │   │
│  │  • HTTP client with retry logic                             │   │
│  │  • Timeout handling (300s default)                          │   │
│  │  • Error propagation with context                           │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
└───────────────────────┬─────────────────────────────────────────────┘
                        │ FFI Bridge (C-compatible)
                        ▼
┌─────────────────────────────────────────────────────────────────────┐
│                 Ananke Core (Zig)                                   │
│                                                                     │
│  Clew (Extract) → Braid (Compile) → ConstraintIR                   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘

                        │ HTTP/JSON (over network)
                        ▼
┌─────────────────────────────────────────────────────────────────────┐
│           Modal Inference Service (GPU Cloud)                       │
│                                                                     │
│  vLLM 0.11.0 + llguidance 0.7.11                                    │
│  Qwen2.5-Coder-32B-Instruct on A100-80GB                            │
│  • Token-level constraint enforcement (~50μs/token)                 │
│  • 22.3 tokens/sec throughput                                       │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Component Breakdown

#### 1. Rust Core (`maze/src/lib.rs`)

**Status**: COMPLETE (507 lines)

**Responsibilities**:
- Constraint compilation (ConstraintIR → llguidance JSON)
- LRU caching (xxHash3 for keys, O(1) eviction)
- Provenance tracking (model, constraints, timestamps)
- Validation result generation
- Cache statistics and management

**Key Types**:
```rust
pub struct MazeOrchestrator {
    modal_client: ModalClient,
    constraint_cache: Arc<Mutex<LruCache<String, CompiledConstraint>>>,
    config: MazeConfig,
}

pub async fn generate(&self, request: GenerationRequest) -> Result<GenerationResponse>
pub async fn compile_constraints(&self, ir: &[ConstraintIR]) -> Result<CompiledConstraint>
```

#### 2. Modal Client (`maze/src/modal_client.rs`)

**Status**: COMPLETE (374 lines)

**Responsibilities**:
- HTTP communication with Modal service
- Request/response serialization (JSON)
- Retry logic with exponential backoff (3 retries default)
- Timeout handling (300s default)
- Health check and model listing

**Key Types**:
```rust
pub struct ModalClient {
    client: reqwest::Client,
    config: ModalConfig,
    base_url: Url,
}

pub async fn generate_constrained(&self, request: InferenceRequest) -> Result<InferenceResponse>
pub async fn health_check(&self) -> Result<bool>
```

#### 3. FFI Bridge (`maze/src/ffi.rs`)

**Status**: COMPLETE and TESTED

**Responsibilities**:
- C-compatible type definitions
- Safe conversion between Zig and Rust types
- Memory ownership tracking (Zig allocates, Rust reads/copies, Zig frees)
- UTF-8 validation for strings
- Error propagation across FFI boundary

**Key Types** (C-compatible):
```c
// Defined in ffi.rs, callable from Zig
typedef struct ConstraintIR {
    const char* json_schema;      // nullable
    const char* grammar;          // nullable  
    const char** regex_patterns;
    size_t regex_patterns_len;
    TokenMaskRules* token_masks;  // nullable
    uint32_t priority;
    const char* name;
} ConstraintIR;

typedef struct GenerationResult {
    const char* code;
    bool success;
    const char* error;            // nullable
    size_t tokens_generated;
    uint64_t generation_time_ms;
} GenerationResult;
```

#### 4. Python Bindings (NEW - PRIMARY WORK FOR PHASE 7)

**Status**: NOT YET IMPLEMENTED

**Responsibilities**:
- PyO3-based Python API
- Pythonic async/await interface
- Configuration from environment or kwargs
- Error handling with Python exceptions
- Type hints for IDE support

**Proposed API** (see Section 5 for full spec):
```python
from ananke import Ananke, GenerationRequest

async def main():
    ananke = Ananke(modal_endpoint="https://...")
    
    request = GenerationRequest(
        prompt="Implement secure API handler",
        constraints_ir=[...],  # From Zig via FFI or direct construction
        max_tokens=2048,
    )
    
    result = await ananke.generate(request)
    print(result.code)
```

---

## API Specifications

### 5.1 Rust API (Already Implemented)

#### MazeOrchestrator

```rust
pub struct MazeOrchestrator { /* ... */ }

impl MazeOrchestrator {
    /// Create a new orchestrator with Modal configuration
    pub fn new(modal_config: ModalConfig) -> Result<Self>
    
    /// Create with custom Maze configuration
    pub fn with_config(modal_config: ModalConfig, maze_config: MazeConfig) -> Result<Self>
    
    /// Generate code with constraints (main entry point)
    pub async fn generate(&self, request: GenerationRequest) -> Result<GenerationResponse>
    
    /// Compile constraints to llguidance format (with caching)
    pub async fn compile_constraints(&self, ir: &[ConstraintIR]) -> Result<CompiledConstraint>
    
    /// Clear the constraint cache
    pub async fn clear_cache(&self) -> Result<()>
    
    /// Get cache statistics
    pub async fn cache_stats(&self) -> CacheStats
}
```

#### ModalClient

```rust
pub struct ModalClient { /* ... */ }

impl ModalClient {
    /// Create a new Modal client
    pub fn new(config: ModalConfig) -> Result<Self>
    
    /// Generate code with constraints
    pub async fn generate_constrained(&self, request: InferenceRequest) -> Result<InferenceResponse>
    
    /// Check service health
    pub async fn health_check(&self) -> Result<bool>
    
    /// List available models
    pub async fn list_models(&self) -> Result<Vec<String>>
    
    /// Stream generation (future)
    pub async fn generate_stream(&self, request: InferenceRequest) -> Result<()>
}
```

### 5.2 Python API (To Be Implemented)

#### Core Class

```python
from typing import Optional, List, Dict, Any
from dataclasses import dataclass

@dataclass
class GenerationRequest:
    """Request for code generation"""
    prompt: str
    constraints_ir: List[ConstraintIR]
    max_tokens: int = 2048
    temperature: float = 0.7
    context: Optional[GenerationContext] = None

@dataclass
class GenerationResponse:
    """Response from generation"""
    code: str
    provenance: Provenance
    validation: ValidationResult
    metadata: GenerationMetadata

class Ananke:
    """Main Ananke API for constrained code generation"""
    
    def __init__(
        self,
        modal_endpoint: str,
        modal_api_key: Optional[str] = None,
        model: str = "meta-llama/Llama-3.1-8B-Instruct",
        timeout_secs: int = 300,
        enable_cache: bool = True,
        cache_size: int = 1000,
    ):
        """
        Initialize Ananke orchestrator.
        
        Args:
            modal_endpoint: URL of Modal inference service
            modal_api_key: Optional API key for authentication
            model: Model name to use for generation
            timeout_secs: Request timeout in seconds
            enable_cache: Enable constraint compilation caching
            cache_size: Maximum cache entries
        """
        pass
    
    async def generate(
        self,
        request: GenerationRequest,
    ) -> GenerationResponse:
        """
        Generate code with constraints.
        
        Args:
            request: Generation request with prompt and constraints
            
        Returns:
            GenerationResponse with generated code and metadata
            
        Raises:
            AnankeError: If generation fails
            NetworkError: If Modal service is unreachable
            ConstraintError: If constraints are invalid
        """
        pass
    
    async def extract_constraints(
        self,
        source_code: str,
        language: str,
    ) -> List[ConstraintIR]:
        """
        Extract constraints from source code (calls Zig Clew via FFI).
        
        Args:
            source_code: Source code to analyze
            language: Programming language (typescript, python, rust, etc.)
            
        Returns:
            List of extracted constraints
        """
        pass
    
    async def compile_constraints(
        self,
        constraints: List[ConstraintIR],
    ) -> CompiledConstraint:
        """
        Compile constraints to llguidance format.
        
        Args:
            constraints: List of constraints to compile
            
        Returns:
            Compiled constraint ready for inference
        """
        pass
    
    async def health_check(self) -> bool:
        """Check if Modal service is healthy"""
        pass
    
    async def clear_cache(self) -> None:
        """Clear the constraint compilation cache"""
        pass
    
    def cache_stats(self) -> Dict[str, int]:
        """Get cache statistics"""
        pass

# Convenience functions for common patterns
async def extract_and_generate(
    source_code: str,
    language: str,
    intent: str,
    modal_endpoint: str,
) -> GenerationResponse:
    """
    Extract constraints from code and generate new code.
    
    This is a convenience function for the full pipeline:
    1. Extract constraints from source_code
    2. Compile constraints
    3. Generate new code with intent
    """
    pass
```

#### Configuration from Environment

```python
class Ananke:
    @classmethod
    def from_env(cls) -> "Ananke":
        """
        Create Ananke from environment variables.
        
        Expected variables:
        - MODAL_ENDPOINT: Modal inference service URL
        - MODAL_API_KEY: Optional API key
        - MODAL_MODEL: Optional model name
        - ANANKE_CACHE_SIZE: Optional cache size (default: 1000)
        """
        import os
        
        return cls(
            modal_endpoint=os.environ["MODAL_ENDPOINT"],
            modal_api_key=os.getenv("MODAL_API_KEY"),
            model=os.getenv("MODAL_MODEL", "meta-llama/Llama-3.1-8B-Instruct"),
            cache_size=int(os.getenv("ANANKE_CACHE_SIZE", "1000")),
        )
```

#### Example Usage

```python
# Example 1: Simple generation
from ananke import Ananke, GenerationRequest

async def main():
    # Initialize from environment
    ananke = Ananke.from_env()
    
    # Check service health
    if not await ananke.health_check():
        raise RuntimeError("Modal service is not healthy")
    
    # Create request
    request = GenerationRequest(
        prompt="Implement a secure API handler for user authentication",
        constraints_ir=[],  # Can be empty for unconstrained generation
        max_tokens=2048,
        temperature=0.7,
    )
    
    # Generate
    result = await ananke.generate(request)
    print(f"Generated code:\n{result.code}")
    print(f"Tokens: {result.metadata.tokens_generated}")
    print(f"Time: {result.metadata.generation_time_ms}ms")


# Example 2: Full pipeline with constraint extraction
from ananke import extract_and_generate

async def main():
    source_code = """
    async function fetchUser(id: number): Promise<User> {
        const response = await fetch(`/api/users/${id}`);
        return response.json();
    }
    """
    
    result = await extract_and_generate(
        source_code=source_code,
        language="typescript",
        intent="Add error handling and validation",
        modal_endpoint="https://rand--ananke-inference-generate-api.modal.run",
    )
    
    print(f"Generated:\n{result.code}")


# Example 3: Explicit constraint extraction + generation
from ananke import Ananke

async def main():
    ananke = Ananke.from_env()
    
    # Extract constraints from existing code
    constraints = await ananke.extract_constraints(
        source_code="""
        def validate_email(email: str) -> bool:
            import re
            pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
            return re.match(pattern, email) is not None
        """,
        language="python",
    )
    
    # Generate new code with same constraints
    request = GenerationRequest(
        prompt="Implement validate_phone_number function",
        constraints_ir=constraints,
        max_tokens=500,
    )
    
    result = await ananke.generate(request)
    print(result.code)
```

### 5.3 CLI Interface (To Be Implemented)

```bash
# Initialize configuration
ananke config set modal-endpoint https://rand--ananke-inference-generate-api.modal.run

# Extract constraints from codebase
ananke extract ./src --language typescript -o constraints.json

# Compile constraints
ananke compile constraints.json -o compiled.cir

# Generate code with constraints
ananke generate "implement auth handler" \
  --constraints compiled.cir \
  --max-tokens 2048 \
  --output handler.ts

# Full pipeline
ananke gen "add error handling" \
  --from ./src/api.ts \
  --language typescript \
  --output ./src/api_with_errors.ts

# Health check
ananke health

# Cache management
ananke cache stats
ananke cache clear
```

---

## FFI Layer Design

### 6.1 Memory Management Strategy

**Golden Rule**: The allocator that creates memory is responsible for freeing it.

#### Zig → Rust Flow

```
1. Zig allocates ConstraintIR (using GPA)
2. Rust reads ConstraintIR via FFI (makes deep copy if needed)
3. Rust processes and allocates GenerationResult
4. Zig reads GenerationResult via FFI (makes deep copy)
5. Zig calls free_generation_result_ffi()
6. Zig frees original ConstraintIR
```

#### Rust → Zig Flow

```
1. Rust allocates string data (for error messages, etc.)
2. Zig receives pointer via FFI
3. Zig reads/copies data
4. Zig calls Rust free function
5. Rust deallocates
```

### 6.2 FFI Type Definitions

All FFI types are defined in `maze/src/ffi.rs` and must be C-compatible (repr(C)).

#### ConstraintIR (Zig → Rust)

```rust
#[repr(C)]
pub struct ConstraintIR {
    /// JSON schema as string (nullable)
    pub json_schema: *const c_char,
    
    /// Grammar rules as JSON string (nullable)
    pub grammar: *const c_char,
    
    /// Array of regex pattern strings
    pub regex_patterns: *const *const c_char,
    pub regex_patterns_len: usize,
    
    /// Token mask rules (nullable)
    pub token_masks: *const TokenMaskRules,
    
    /// Priority level (0-4: Critical, High, Medium, Low, Optional)
    pub priority: u32,
    
    /// Constraint name (required)
    pub name: *const c_char,
}

#[repr(C)]
pub struct TokenMaskRules {
    pub allowed_tokens: *const *const c_char,
    pub allowed_tokens_len: usize,
    pub forbidden_tokens: *const *const c_char,
    pub forbidden_tokens_len: usize,
}
```

#### GenerationResult (Rust → Zig)

```rust
#[repr(C)]
pub struct GenerationResult {
    /// Generated code (owned by Rust, must be freed)
    pub code: *mut c_char,
    
    /// Success flag
    pub success: bool,
    
    /// Error message if success=false (nullable, owned by Rust)
    pub error: *mut c_char,
    
    /// Number of tokens generated
    pub tokens_generated: usize,
    
    /// Generation time in milliseconds
    pub generation_time_ms: u64,
}
```

#### Intent (Zig → Rust)

```rust
#[repr(C)]
pub struct Intent {
    /// Raw user input
    pub raw_input: *const c_char,
    
    /// Processed prompt for LLM
    pub prompt: *const c_char,
    
    /// Current file path (nullable)
    pub current_file: *const c_char,
    
    /// Programming language (nullable)
    pub language: *const c_char,
}
```

### 6.3 FFI Function Signatures

```rust
/// Initialize Maze (call once at startup)
#[no_mangle]
pub extern "C" fn maze_init() -> c_int

/// Cleanup Maze (call once at shutdown)
#[no_mangle]
pub extern "C" fn maze_deinit()

/// Generate code with constraints
/// Returns: Allocated GenerationResult (must be freed with free_generation_result_ffi)
#[no_mangle]
pub extern "C" fn maze_generate(
    intent: *const Intent,
    constraints: *const ConstraintIR,
    constraints_len: usize,
) -> *mut GenerationResult

/// Free a GenerationResult allocated by Rust
#[no_mangle]
pub extern "C" fn free_generation_result_ffi(result: *mut GenerationResult)

/// Get Maze version string (static, does not need to be freed)
#[no_mangle]
pub extern "C" fn maze_version() -> *const c_char
```

### 6.4 Error Handling Across FFI

**Strategy**: Use error codes + optional error strings.

```rust
// Error codes (defined in both Zig and Rust)
pub const MAZE_SUCCESS: c_int = 0;
pub const MAZE_NULL_POINTER: c_int = 1;
pub const MAZE_ALLOCATION_FAILURE: c_int = 2;
pub const MAZE_INVALID_INPUT: c_int = 3;
pub const MAZE_NETWORK_ERROR: c_int = 4;
pub const MAZE_INFERENCE_ERROR: c_int = 5;
pub const MAZE_CONSTRAINT_ERROR: c_int = 6;

// In GenerationResult
pub struct GenerationResult {
    pub success: bool,
    pub error: *mut c_char,  // Detailed error message if success=false
    // ... other fields
}
```

### 6.5 Thread Safety

**Current Status**: NOT thread-safe (global allocator without synchronization)

**Workarounds**:
1. Serialize access with Mutex
2. Use thread-local instances
3. Process requests sequentially

**Future** (Phase 8): Add per-thread allocators or mutex-protected global state.

### 6.6 Safety Checklist

Before calling across FFI:
- [ ] Validate all pointers are non-null
- [ ] Check string pointers are valid UTF-8
- [ ] Verify array lengths match pointer validity
- [ ] Ensure lifetime: data lives long enough for callee
- [ ] Document memory ownership clearly

---

## Implementation Roadmap

### Phase 7a: Python Bindings Foundation (Week 10, Days 1-3)

**Goal**: Expose core Maze functionality to Python via PyO3.

**Tasks**:
1. Add PyO3 to Cargo.toml dependencies
2. Create `maze/src/python.rs` module
3. Wrap `MazeOrchestrator` in PyO3 class
4. Implement `Ananke.__init__()` and `Ananke.generate()`
5. Add Python type hints
6. Write basic Python test

**Acceptance Criteria**:
- Can create `Ananke()` instance from Python
- Can call `await ananke.generate()` with request
- Errors propagate as Python exceptions
- Type hints work in VS Code/PyCharm

**Implementation Notes**:
```rust
// In maze/src/python.rs
use pyo3::prelude::*;

#[pyclass]
struct Ananke {
    inner: MazeOrchestrator,
}

#[pymethods]
impl Ananke {
    #[new]
    fn new(
        modal_endpoint: String,
        modal_api_key: Option<String>,
        model: String,
    ) -> PyResult<Self> {
        // ...
    }
    
    fn generate<'py>(
        &self,
        py: Python<'py>,
        request: PyGenerationRequest,
    ) -> PyResult<&'py PyAny> {
        // Return a coroutine for async/await
        pyo3_asyncio::tokio::future_into_py(py, async move {
            // ...
        })
    }
}
```

### Phase 7b: Python API Completeness (Week 10, Days 4-5)

**Goal**: Full Python API with all Maze features.

**Tasks**:
1. Implement `extract_constraints()` (calls Zig via FFI)
2. Implement `compile_constraints()`
3. Implement `health_check()`, `clear_cache()`, `cache_stats()`
4. Add `from_env()` class method
5. Create convenience function `extract_and_generate()`
6. Write comprehensive Python docstrings
7. Add Python integration tests

**Acceptance Criteria**:
- All Python API methods work
- Can extract constraints from code
- Can query cache statistics
- Environment variable configuration works
- 10+ Python integration tests passing

### Phase 7c: CLI Implementation (Week 11, Days 1-3)

**Goal**: Command-line interface for Ananke.

**Tasks**:
1. Choose CLI framework (Click or Typer recommended)
2. Implement `ananke config` commands
3. Implement `ananke extract` command
4. Implement `ananke compile` command
5. Implement `ananke generate` command
6. Implement `ananke health` command
7. Add progress bars for long operations
8. Write CLI integration tests

**Acceptance Criteria**:
- Can extract, compile, and generate from command line
- Progress indication for long operations
- Error messages are clear and actionable
- Help text is comprehensive
- 5+ CLI integration tests passing

**CLI Structure**:
```python
# In ananke_cli/main.py
import click
from ananke import Ananke

@click.group()
def cli():
    """Ananke: Constraint-driven code generation"""
    pass

@cli.command()
@click.argument('source', type=click.Path(exists=True))
@click.option('--language', required=True)
@click.option('--output', '-o', type=click.Path())
def extract(source, language, output):
    """Extract constraints from source code"""
    # ...

@cli.command()
@click.argument('prompt')
@click.option('--constraints', type=click.Path(exists=True))
@click.option('--max-tokens', default=2048)
def generate(prompt, constraints, max_tokens):
    """Generate code with constraints"""
    # ...
```

### Phase 7d: Documentation and Examples (Week 11, Days 4-5)

**Goal**: Comprehensive documentation and examples.

**Tasks**:
1. Write Python API reference documentation
2. Write CLI user guide
3. Create 5+ example scripts
4. Update README.md with Python/CLI examples
5. Create video walkthrough (optional)
6. Write troubleshooting guide

**Deliverables**:
- `docs/PYTHON_API.md` - Full API reference
- `docs/CLI_GUIDE.md` - Complete CLI guide  
- `examples/python/` - 5+ working examples
- Updated main README.md
- Troubleshooting FAQ

**Example Scripts**:
1. `simple_generation.py` - Basic unconstrained generation
2. `extract_and_generate.py` - Full pipeline
3. `json_schema_constraint.py` - JSON Schema constraints
4. `batch_processing.py` - Process multiple files
5. `streaming_generation.py` - Streaming (future)

### Dependencies Between Phases

```
Phase 7a (Python Bindings)
    ↓
Phase 7b (API Completeness) ← Depends on 7a
    ↓
Phase 7c (CLI) ← Depends on 7b
    ↓
Phase 7d (Docs) ← Depends on 7a, 7b, 7c
```

---

## Success Criteria

### Functional Requirements

#### Must Have (P0)
1. **Python API works**: Can create `Ananke()` and call `generate()` from Python
2. **FFI bridge stable**: Zero memory leaks, no segfaults
3. **Error handling**: All errors propagate with context
4. **Cache performance**: LRU cache provides 10x+ speedup on cache hits
5. **Modal integration**: Can communicate with deployed Modal service
6. **Constraint compilation**: ConstraintIR → llguidance with 100% fidelity
7. **Provenance tracking**: All generated code has full metadata

#### Should Have (P1)
8. **CLI interface**: Can extract, compile, generate from command line
9. **Environment config**: Can configure from env vars
10. **Health checks**: Can verify Modal service health
11. **Documentation**: Comprehensive API docs and examples
12. **Type hints**: Full Python type annotations

#### Nice to Have (P2)
13. **Streaming generation**: Support for token streaming (future)
14. **Progress bars**: Visual feedback for long operations
15. **Local inference**: Support for local GGUF models (future)
16. **Multi-model**: Ensemble generation (future)

### Performance Requirements

1. **FFI overhead**: <10μs per FFI call
2. **Cache hit latency**: <1μs for cache lookup
3. **Constraint compilation**: <50ms for typical constraint set
4. **Network latency**: <100ms to Modal service (warm)
5. **Memory overhead**: <100MB for Python + Rust runtime
6. **Throughput**: 10+ requests/sec sustained

### Quality Requirements

1. **Test coverage**: >80% for Python bindings
2. **Memory safety**: Zero leaks detected by Valgrind
3. **Error handling**: All error paths tested
4. **Documentation**: All public APIs documented
5. **Type safety**: `mypy --strict` passes for Python code

### Acceptance Tests

#### Test 1: Basic Generation
```python
def test_basic_generation():
    ananke = Ananke.from_env()
    request = GenerationRequest(
        prompt="Implement add function",
        constraints_ir=[],
        max_tokens=100,
    )
    result = await ananke.generate(request)
    assert result.code != ""
    assert result.provenance.model == "meta-llama/Llama-3.1-8B-Instruct"
    assert result.validation.all_satisfied
```

#### Test 2: Constraint Extraction + Generation
```python
def test_extract_and_generate():
    ananke = Ananke.from_env()
    
    # Extract constraints
    constraints = await ananke.extract_constraints(
        source_code="def add(a: int, b: int) -> int: return a + b",
        language="python",
    )
    assert len(constraints) > 0
    
    # Generate with constraints
    request = GenerationRequest(
        prompt="Implement subtract function",
        constraints_ir=constraints,
        max_tokens=100,
    )
    result = await ananke.generate(request)
    assert "def subtract" in result.code
```

#### Test 3: Cache Performance
```python
def test_cache_performance():
    ananke = Ananke.from_env()
    
    constraints = [...]  # Some constraint set
    
    # First compilation (cache miss)
    start = time.time()
    compiled1 = await ananke.compile_constraints(constraints)
    time1 = time.time() - start
    
    # Second compilation (cache hit)
    start = time.time()
    compiled2 = await ananke.compile_constraints(constraints)
    time2 = time.time() - start
    
    assert time2 < time1 / 10  # Cache hit should be 10x faster
    assert compiled1.hash == compiled2.hash
```

#### Test 4: Error Handling
```python
def test_error_handling():
    ananke = Ananke(modal_endpoint="http://invalid-endpoint.example.com")
    
    request = GenerationRequest(prompt="test", constraints_ir=[])
    
    with pytest.raises(NetworkError) as exc:
        await ananke.generate(request)
    
    assert "invalid-endpoint" in str(exc.value)
```

#### Test 5: CLI E2E
```bash
# Extract
ananke extract ./test/fixtures/sample.ts --language typescript -o constraints.json

# Verify output exists
test -f constraints.json

# Generate
ananke generate "add error handling" --constraints constraints.json --output result.ts

# Verify output
test -f result.ts
grep -q "try" result.ts
```

---

## Open Questions and Risks

### Open Questions

1. **Q: Should Python bindings be in the same repo or separate package?**
   - **Recommendation**: Same repo initially (`maze/python/`), separate PyPI package later
   - **Rationale**: Easier to keep FFI and Python in sync during development

2. **Q: How to handle breaking changes in llguidance format?**
   - **Recommendation**: Version the ConstraintIR → llguidance compiler, support multiple versions
   - **Rationale**: Modal service may update llguidance independently

3. **Q: Should we support local inference (llama.cpp/GGUF)?**
   - **Recommendation**: Defer to Phase 8 or later
   - **Rationale**: Modal service is working well, local inference adds complexity

4. **Q: How to handle streaming generation?**
   - **Recommendation**: Design API to support it, implement in Phase 8
   - **Rationale**: Infrastructure is there (Tokio + reqwest), need server-sent events on Modal

5. **Q: Should CLI be a separate package?**
   - **Recommendation**: Separate package `ananke-cli` that depends on `ananke`
   - **Rationale**: Users who only want the Python API shouldn't need Click/Typer

### Risks

#### Risk 1: PyO3 async/await complexity (HIGH)

**Description**: PyO3 async support is evolving, may have edge cases or performance issues.

**Mitigation**:
- Use `pyo3-asyncio` crate (well-tested)
- Start with simple async functions, test thoroughly
- Have fallback sync API if async is problematic

**Owner**: Implementation team

#### Risk 2: Modal service API changes (MEDIUM)

**Description**: Modal may change inference API, breaking Maze client.

**Mitigation**:
- Version the Modal client API
- Write integration tests that run against real Modal service
- Monitor Modal changelog

**Owner**: Modal service owner

#### Risk 3: FFI memory leaks (MEDIUM)

**Description**: Memory leaks across FFI boundary are hard to debug.

**Mitigation**:
- Use Valgrind on all integration tests
- Document memory ownership clearly
- Use Zig GPA leak detection
- Add memory leak tests to CI

**Owner**: FFI layer owner

#### Risk 4: Python packaging complexity (LOW)

**Description**: Building Rust extensions for Python can be tricky across platforms.

**Mitigation**:
- Use `maturin` for Python package building (standard for PyO3)
- Test on Linux, macOS, Windows in CI
- Provide pre-built wheels for common platforms

**Owner**: Release engineering

#### Risk 5: Constraint compilation performance (LOW)

**Description**: Complex constraint sets may take too long to compile.

**Mitigation**:
- Profile compilation with real-world constraint sets
- Implement parallel compilation if needed
- Cache aggressively
- Add compilation timeouts

**Owner**: Performance team

### Assumptions

1. **Modal service remains stable**: We assume the deployed Modal service continues to work
2. **Zig FFI contract unchanged**: We assume the FFI contract from Phase 5 remains stable
3. **Python 3.11+**: We assume users have Python 3.11 or later (for `asyncio` improvements)
4. **Network availability**: We assume network access to Modal service (not offline-first)
5. **Single-user**: We assume single-user/single-machine usage (not distributed)

---

## Appendices

### Appendix A: Technology Stack

**Rust Dependencies**:
- `tokio` (1.35+) - Async runtime
- `reqwest` (0.11+) - HTTP client
- `serde` (1.0+) - JSON serialization
- `anyhow` (1.0+) - Error handling
- `pyo3` (0.20+) - Python bindings
- `pyo3-asyncio` (0.20+) - Python async support
- `lru` (0.12+) - LRU cache
- `xxhash-rust` (0.8+) - High-performance hashing

**Python Dependencies**:
- `asyncio` (stdlib) - Async/await
- `typing` (stdlib) - Type hints
- `click` or `typer` - CLI framework
- `rich` - Terminal formatting (optional)

**Development Dependencies**:
- `maturin` - Python package builder
- `pytest` - Python testing
- `pytest-asyncio` - Async test support
- `mypy` - Type checking
- `black` - Code formatting

### Appendix B: File Structure

```
ananke/
├── maze/                              # Rust orchestration layer
│   ├── src/
│   │   ├── lib.rs                     # ✅ COMPLETE (507 lines)
│   │   ├── ffi.rs                     # ✅ COMPLETE (FFI bridge)
│   │   ├── modal_client.rs            # ✅ COMPLETE (374 lines)
│   │   └── python.rs                  # ❌ NEW (PyO3 bindings)
│   ├── python/                        # ❌ NEW (Python package)
│   │   ├── ananke/
│   │   │   ├── __init__.py
│   │   │   ├── client.py              # Python API
│   │   │   └── types.py               # Python types
│   │   ├── setup.py                   # Or pyproject.toml
│   │   └── tests/
│   │       ├── test_basic.py
│   │       ├── test_extract.py
│   │       └── test_integration.py
│   ├── Cargo.toml                     # ✅ EXISTS (needs pyo3)
│   └── README.md                      # ✅ COMPLETE
│
├── ananke_cli/                        # ❌ NEW (CLI package)
│   ├── ananke_cli/
│   │   ├── __init__.py
│   │   ├── main.py                    # CLI entry point
│   │   └── commands/
│   │       ├── extract.py
│   │       ├── compile.py
│   │       └── generate.py
│   └── setup.py
│
├── docs/
│   ├── specs/
│   │   └── phase7-maze-orchestration.md  # This document
│   ├── PYTHON_API.md                  # ❌ NEW
│   └── CLI_GUIDE.md                   # ❌ NEW (already exists, needs update)
│
└── examples/
    └── python/                        # ❌ NEW
        ├── simple_generation.py
        ├── extract_and_generate.py
        ├── json_schema_constraint.py
        ├── batch_processing.py
        └── README.md
```

### Appendix C: References

**Internal Documentation**:
- `/Users/rand/src/ananke/docs/IMPLEMENTATION_PLAN.md` - Overall project plan
- `/Users/rand/src/ananke/docs/ARCHITECTURE.md` - System architecture
- `/Users/rand/src/ananke/docs/FFI_GUIDE.md` - FFI integration guide
- `/Users/rand/src/ananke/maze/README.md` - Maze component overview
- `/Users/rand/src/ananke/test/integration/FFI_CONTRACT.md` - FFI contract specification

**External Resources**:
- PyO3 Guide: https://pyo3.rs/
- pyo3-asyncio: https://github.com/awestlake87/pyo3-asyncio
- Maturin: https://github.com/PyO3/maturin
- Modal Labs: https://modal.com/docs
- llguidance: https://github.com/microsoft/llguidance

**Deployed Services**:
- Modal Inference: https://rand--ananke-inference-generate-api.modal.run

### Appendix D: Glossary

- **ConstraintIR**: Intermediate representation of constraints, output of Braid
- **llguidance**: Microsoft's library for token-level constraint enforcement
- **Maze**: Rust orchestration layer (this component)
- **Modal**: GPU cloud platform for inference services
- **vLLM**: High-performance inference server for LLMs
- **PyO3**: Rust bindings for Python
- **FFI**: Foreign Function Interface (cross-language calls)
- **LRU**: Least Recently Used (cache eviction policy)

---

## Revision History

| Version | Date       | Author       | Changes                          |
|---------|------------|--------------|----------------------------------|
| 1.0     | 2025-11-25 | spec-author  | Initial specification            |

---

**END OF SPECIFICATION**
