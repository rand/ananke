# Ananke Python API Reference

Complete API documentation for Ananke's Python bindings. Ananke is a constrained code generation system that uses Modal's vLLM + llguidance for GPU-accelerated token-level constraint enforcement.

**Version**: 0.1.0 (Phase 7b) | **Updated**: November 26, 2025

---

## Table of Contents

1. [Overview](#overview)
2. [Installation](#installation)
3. [Quick Start](#quick-start)
4. [API Reference](#api-reference)
   - [Ananke Class](#ananke-class)
   - [PyModalConfig Class](#pymodalconfig-class)
   - [PyGenerationRequest Class](#pygenerationrequest-class)
   - [PyGenerationResponse Class](#pygenerationresponse-class)
   - [PyConstraintIR Class](#pyconstraintir-class)
   - [PyGenerationContext Class](#pygenerationcontext-class)
   - [PyProvenance Class](#pyprovenance-class)
   - [PyValidationResult Class](#pyvalidationresult-class)
   - [PyGenerationMetadata Class](#pygenerationmetadata-class)
5. [Usage Examples](#usage-examples)
6. [Type Signatures](#type-signatures)
7. [Error Handling](#error-handling)

---

## Overview

The Ananke Python API provides a high-level interface to the Maze orchestration layer, enabling constrained code generation with GPU-accelerated inference via Modal's inference service.

### Key Features

- **Constrained Generation**: Enforce constraints at the token level during generation
- **Async/Await**: Full async support for non-blocking inference
- **Caching**: LRU-based constraint compilation caching for performance
- **Health Checks**: Built-in service health monitoring
- **Comprehensive Metadata**: Detailed performance metrics and provenance tracking

### Architecture

```
Python API Layer (PyO3 bindings)
    ↓
Rust Orchestrator (MazeOrchestrator)
    ↓
Modal Inference Client
    ↓
Modal Service (vLLM + llguidance on GPU)
```

---

## Installation

### From Source with Maturin

Install the Ananke Python package using `maturin` (Python build backend for Rust):

```bash
# Install build dependencies
pip install maturin

# Build and install the package
cd /path/to/ananke/maze
maturin develop

# Or build for release
maturin build --release
pip install ./target/wheels/ananke-*.whl
```

### Requirements

- Python 3.8 or later
- Rust 1.70 or later (for building from source)
- Modal account with inference service deployed (for runtime)

### Verify Installation

```python
from ananke import Ananke
print(Ananke)  # Should print class reference
```

---

## Quick Start

### Basic Usage

```python
import asyncio
from ananke import Ananke, PyGenerationRequest, PyConstraintIR

async def main():
    # Initialize Ananke (reads MODAL_ENDPOINT from environment)
    ananke = Ananke.from_env()
    
    # Create a generation request
    request = PyGenerationRequest(
        prompt="Write a Python function that validates email addresses",
        max_tokens=500,
        temperature=0.7
    )
    
    # Generate code
    response = await ananke.generate(request)
    
    # Access results
    print(f"Generated code:\n{response.code}")
    print(f"Tokens generated: {response.metadata.tokens_generated}")
    print(f"Generation time: {response.metadata.generation_time_ms}ms")
    print(f"Constraints satisfied: {response.validation.all_satisfied}")

# Run the async function
asyncio.run(main())
```

### With Constraints

```python
import asyncio
from ananke import Ananke, PyGenerationRequest, PyConstraintIR

async def main():
    ananke = Ananke.from_env()
    
    # Create constraints
    constraints = [
        PyConstraintIR(
            name="json_output",
            json_schema='{"type": "object", "properties": {"result": {"type": "string"}}}',
            grammar=None,
            regex_patterns=[]
        )
    ]
    
    # Create request with constraints
    request = PyGenerationRequest(
        prompt="Generate valid JSON output",
        constraints_ir=constraints,
        max_tokens=1000,
        temperature=0.5
    )
    
    response = await ananke.generate(request)
    print(f"Output: {response.code}")
    print(f"Validation: {response.validation.satisfied}")

asyncio.run(main())
```

---

## API Reference

### Ananke Class

Main orchestrator for constrained code generation. This is the primary entry point for the API.

#### `__init__`

Initialize a new Ananke orchestrator instance.

```python
def __init__(
    modal_endpoint: str,
    modal_api_key: Optional[str] = None,
    model: str = "meta-llama/Llama-3.1-8B-Instruct",
    timeout_secs: int = 300,
    enable_cache: bool = True,
    cache_size: int = 1000
) -> None
```

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `modal_endpoint` | `str` | Required | URL of Modal inference service (e.g., `https://your-app.modal.run`) |
| `modal_api_key` | `Optional[str]` | `None` | Optional API key for authentication |
| `model` | `str` | `"meta-llama/Llama-3.1-8B-Instruct"` | Model name to use for generation |
| `timeout_secs` | `int` | `300` | Request timeout in seconds (5 minutes default) |
| `enable_cache` | `bool` | `True` | Enable constraint compilation caching |
| `cache_size` | `int` | `1000` | Maximum cached compiled constraints (LRU eviction) |

**Returns:** `Ananke` - An initialized orchestrator instance

**Raises:** `RuntimeError` - If initialization fails (invalid URL, connection error, etc.)

**Example:**

```python
from ananke import Ananke

# With explicit parameters
ananke = Ananke(
    modal_endpoint="https://<YOUR_MODAL_WORKSPACE>--ananke-inference-generate-api.modal.run",
    model="meta-llama/Llama-3.1-8B-Instruct",
    enable_cache=True,
    cache_size=1000
)

# With authentication
ananke = Ananke(
    modal_endpoint="https://your-app.modal.run",
    modal_api_key="your-secret-api-key"
)
```

---

#### `from_env` (static method)

Create Ananke from environment variables. Useful for containerized deployments and CI/CD pipelines.

```python
@staticmethod
def from_env() -> Ananke
```

**Expected Environment Variables:**

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `MODAL_ENDPOINT` | Yes | N/A | Modal inference service URL |
| `MODAL_API_KEY` | No | N/A | API key for authentication |
| `MODAL_MODEL` | No | `"meta-llama/Llama-3.1-8B-Instruct"` | Model name |
| `ANANKE_CACHE_SIZE` | No | `1000` | Cache size limit |

**Returns:** `Ananke` - An initialized orchestrator instance

**Raises:** `RuntimeError` - If `MODAL_ENDPOINT` is not set or configuration fails

**Example:**

```python
import os
from ananke import Ananke

os.environ["MODAL_ENDPOINT"] = "https://your-app.modal.run"
os.environ["MODAL_API_KEY"] = "your-api-key"
os.environ["ANANKE_CACHE_SIZE"] = "2000"

ananke = Ananke.from_env()
```

---

#### `generate`

Generate code with constraints using the Modal inference service (async).

This is the main entry point for constrained code generation. Performs token-level constraint enforcement using vLLM + llguidance on GPU infrastructure.

```python
async def generate(request: PyGenerationRequest) -> PyGenerationResponse
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `request` | `PyGenerationRequest` | Generation request containing prompt, constraints, and settings |

**Returns:** `PyGenerationResponse` - Generation result with code, provenance, validation, and metrics

**Raises:** 
- `RuntimeError` - If generation fails (network error, timeout, inference error)
- `PyRuntimeError` - For other runtime failures

**Example:**

```python
import asyncio
from ananke import Ananke, PyGenerationRequest, PyConstraintIR

async def generate_code():
    ananke = Ananke.from_env()
    
    request = PyGenerationRequest(
        prompt="Implement a secure user authentication handler",
        constraints_ir=[],
        max_tokens=500,
        temperature=0.7
    )
    
    result = await ananke.generate(request)
    
    print(f"Generated: {result.code}")
    print(f"Tokens: {result.metadata.tokens_generated}")
    print(f"Time: {result.metadata.generation_time_ms}ms")
    print(f"Constraints satisfied: {result.validation.all_satisfied}")

asyncio.run(generate_code())
```

---

#### `compile_constraints`

Compile constraints to llguidance format (async).

Converts constraint specifications into optimized llguidance schemas for efficient token-level enforcement. Results are cached for performance.

```python
async def compile_constraints(
    constraints: List[PyConstraintIR]
) -> Dict[str, Any]
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `constraints` | `List[PyConstraintIR]` | List of constraints to compile |

**Returns:** `Dict[str, Any]` - Compilation result with keys:
- `hash` (str): Deterministic hash of the compiled constraints
- `compiled_at` (int): Unix timestamp of compilation
- `schema` (str): llguidance schema as string

**Raises:** `RuntimeError` - If compilation fails

**Example:**

```python
import asyncio
from ananke import Ananke, PyConstraintIR

async def compile_constraints():
    ananke = Ananke.from_env()
    
    constraints = [
        PyConstraintIR(
            name="json_output",
            json_schema='{"type": "object"}',
            grammar=None,
            regex_patterns=[]
        )
    ]
    
    result = await ananke.compile_constraints(constraints)
    print(f"Hash: {result['hash']}")
    print(f"Compiled at: {result['compiled_at']}")
    print(f"Schema: {result['schema']}")

asyncio.run(compile_constraints())
```

**Cache Behavior:**

- Identical constraint sets produce identical hashes (deterministic)
- Compiled results are cached if `enable_cache=True`
- Cache uses LRU eviction when limit is reached
- Cache can be cleared with `clear_cache()`

---

#### `health_check`

Check if Modal inference service is healthy (async).

Verifies connectivity and health of the Modal inference service.

```python
async def health_check() -> bool
```

**Returns:** `bool` - `True` if service is healthy, `False` otherwise

**Raises:** `RuntimeError` - For catastrophic failures

**Example:**

```python
import asyncio
from ananke import Ananke

async def check_service():
    ananke = Ananke.from_env()
    is_healthy = await ananke.health_check()
    print(f"Service healthy: {is_healthy}")

asyncio.run(check_service())
```

---

#### `clear_cache`

Clear the constraint compilation cache (async).

Removes all cached compiled constraints and resets the cache. Useful for memory cleanup or testing.

```python
async def clear_cache() -> None
```

**Returns:** `None`

**Raises:** `RuntimeError` - If cache clear fails

**Example:**

```python
import asyncio
from ananke import Ananke

async def cleanup():
    ananke = Ananke.from_env()
    await ananke.clear_cache()
    print("Cache cleared")

asyncio.run(cleanup())
```

---

#### `cache_stats`

Get cache statistics (async).

Returns current cache usage and configuration.

```python
async def cache_stats() -> Dict[str, int]
```

**Returns:** `Dict[str, int]` - Cache statistics:
- `size` (int): Current number of cached items
- `limit` (int): Maximum cache size limit

**Raises:** `RuntimeError` - If stats retrieval fails

**Example:**

```python
import asyncio
from ananke import Ananke

async def monitor_cache():
    ananke = Ananke.from_env(cache_size=500)
    
    stats = await ananke.cache_stats()
    print(f"Cache: {stats['size']}/{stats['limit']} entries")
    
    if stats['size'] > stats['limit'] * 0.8:
        print("Cache nearly full, clearing...")
        await ananke.clear_cache()

asyncio.run(monitor_cache())
```

---

### PyModalConfig Class

Configuration for Modal inference service connection.

```python
class PyModalConfig:
    def __init__(
        self,
        endpoint_url: str,
        model: str = "meta-llama/Llama-3.1-8B-Instruct",
        api_key: Optional[str] = None,
        timeout_secs: int = 300,
        max_retries: int = 3
    ) -> None
```

**Attributes:**

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `endpoint_url` | `str` | Required | Modal service URL |
| `model` | `str` | `"meta-llama/Llama-3.1-8B-Instruct"` | Model name |
| `api_key` | `Optional[str]` | `None` | API key for authentication |
| `timeout_secs` | `int` | `300` | Request timeout |
| `max_retries` | `int` | `3` | Maximum retry attempts |

**Static Methods:**

#### `from_env`

Create config from environment variables.

```python
@staticmethod
def from_env() -> PyModalConfig
```

**Example:**

```python
config = PyModalConfig.from_env()
```

---

### PyGenerationRequest Class

Request payload for code generation.

```python
class PyGenerationRequest:
    def __init__(
        self,
        prompt: str,
        constraints_ir: List[PyConstraintIR] = [],
        max_tokens: int = 2048,
        temperature: float = 0.7,
        context: Optional[PyGenerationContext] = None
    ) -> None
```

**Attributes:**

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `prompt` | `str` | Required | User intent or code generation prompt |
| `constraints_ir` | `List[PyConstraintIR]` | `[]` | List of constraints to enforce |
| `max_tokens` | `int` | `2048` | Maximum tokens to generate |
| `temperature` | `float` | `0.7` | Sampling temperature (0.0-1.0) |
| `context` | `Optional[PyGenerationContext]` | `None` | Additional context (file, language, etc.) |

**Example:**

```python
from ananke import PyGenerationRequest, PyGenerationContext

request = PyGenerationRequest(
    prompt="Write a Python function for binary search",
    constraints_ir=[],
    max_tokens=1000,
    temperature=0.5,
    context=PyGenerationContext(
        current_file="algorithms.py",
        language="python",
        project_root="/home/user/project"
    )
)
```

---

### PyGenerationResponse Class

Response from code generation with results and metrics.

```python
class PyGenerationResponse:
    code: str
    provenance: PyProvenance
    validation: PyValidationResult
    metadata: PyGenerationMetadata
```

**Read-only Attributes:**

| Attribute | Type | Description |
|-----------|------|-------------|
| `code` | `str` | Generated source code |
| `provenance` | `PyProvenance` | Tracking information (model, timestamp, constraints) |
| `validation` | `PyValidationResult` | Constraint satisfaction results |
| `metadata` | `PyGenerationMetadata` | Performance metrics |

**Example:**

```python
response = await ananke.generate(request)

print(f"Code:\n{response.code}")
print(f"Generated by: {response.provenance.model}")
print(f"Tokens: {response.metadata.tokens_generated}")
print(f"Time: {response.metadata.generation_time_ms}ms")
print(f"All satisfied: {response.validation.all_satisfied}")
```

---

### PyConstraintIR Class

Constraint specification in intermediate representation (IR) format.

```python
class PyConstraintIR:
    def __init__(
        self,
        name: str,
        json_schema: Optional[str] = None,
        grammar: Optional[str] = None,
        regex_patterns: List[str] = []
    ) -> None
```

**Attributes:**

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `name` | `str` | Required | Constraint identifier |
| `json_schema` | `Optional[str]` | `None` | JSON Schema constraint as string |
| `grammar` | `Optional[str]` | `None` | EBNF/PEG grammar constraint as string |
| `regex_patterns` | `List[str]` | `[]` | Regular expression patterns to enforce |

**Example:**

```python
from ananke import PyConstraintIR

# JSON Schema constraint
json_constraint = PyConstraintIR(
    name="user_data",
    json_schema='{"type": "object", "properties": {"id": {"type": "integer"}, "name": {"type": "string"}}}',
    grammar=None,
    regex_patterns=[]
)

# Grammar constraint
grammar_constraint = PyConstraintIR(
    name="json_output",
    json_schema=None,
    grammar='root: "{" (key ":" value ("," key ":" value)*)? "}"',
    regex_patterns=[]
)

# Regex constraint
regex_constraint = PyConstraintIR(
    name="email_format",
    json_schema=None,
    grammar=None,
    regex_patterns=[r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$']
)
```

---

### PyGenerationContext Class

Additional context for code generation (file, language, project info).

```python
class PyGenerationContext:
    def __init__(
        self,
        current_file: Optional[str] = None,
        language: Optional[str] = None,
        project_root: Optional[str] = None
    ) -> None
```

**Attributes:**

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `current_file` | `Optional[str]` | `None` | Path to current source file |
| `language` | `Optional[str]` | `None` | Programming language (e.g., "python", "typescript") |
| `project_root` | `Optional[str]` | `None` | Root directory of project |

**Example:**

```python
from ananke import PyGenerationContext

context = PyGenerationContext(
    current_file="src/utils/parser.py",
    language="python",
    project_root="/home/user/my-project"
)
```

---

### PyProvenance Class

Tracking information for generated code (model, timestamp, constraints applied).

```python
class PyProvenance:
    model: str
    timestamp: int
    constraints_applied: List[str]
    original_intent: str
```

**Read-only Attributes:**

| Attribute | Type | Description |
|-----------|------|-------------|
| `model` | `str` | Model name used for generation |
| `timestamp` | `int` | Unix timestamp of generation |
| `constraints_applied` | `List[str]` | List of constraint names applied |
| `original_intent` | `str` | Original prompt/intent |

**Example:**

```python
provenance = response.provenance
print(f"Model: {provenance.model}")
print(f"Generated at: {provenance.timestamp}")
print(f"Constraints: {provenance.constraints_applied}")
print(f"Original intent: {provenance.original_intent}")
```

---

### PyValidationResult Class

Constraint satisfaction validation results.

```python
class PyValidationResult:
    all_satisfied: bool
    satisfied: List[str]
    violated: List[str]
```

**Read-only Attributes:**

| Attribute | Type | Description |
|-----------|------|-------------|
| `all_satisfied` | `bool` | Whether all constraints were satisfied |
| `satisfied` | `List[str]` | Names of satisfied constraints |
| `violated` | `List[str]` | Names of violated constraints |

**Example:**

```python
validation = response.validation
print(f"All satisfied: {validation.all_satisfied}")
print(f"Passed: {validation.satisfied}")
print(f"Failed: {validation.violated}")

if not validation.all_satisfied:
    print(f"Failed constraints: {validation.violated}")
```

---

### PyGenerationMetadata Class

Performance metrics for generation (tokens, timing, constraint compilation time).

```python
class PyGenerationMetadata:
    tokens_generated: int
    generation_time_ms: int
    avg_token_time_us: int
    constraint_compile_time_ms: int
```

**Read-only Attributes:**

| Attribute | Type | Description |
|-----------|------|-------------|
| `tokens_generated` | `int` | Total tokens generated |
| `generation_time_ms` | `int` | Total generation time in milliseconds |
| `avg_token_time_us` | `int` | Average time per token in microseconds |
| `constraint_compile_time_ms` | `int` | Time spent compiling constraints |

**Example:**

```python
metadata = response.metadata
print(f"Tokens: {metadata.tokens_generated}")
print(f"Generation: {metadata.generation_time_ms}ms")
print(f"Avg token: {metadata.avg_token_time_us}us")
print(f"Compilation: {metadata.constraint_compile_time_ms}ms")

# Calculate throughput
tokens_per_sec = (metadata.tokens_generated / metadata.generation_time_ms) * 1000
print(f"Throughput: {tokens_per_sec:.2f} tokens/sec")
```

---

## Usage Examples

### Example 1: Simple Code Generation

Generate Python code without constraints.

```python
import asyncio
from ananke import Ananke, PyGenerationRequest

async def simple_generation():
    ananke = Ananke.from_env()
    
    request = PyGenerationRequest(
        prompt="Write a function that calculates Fibonacci numbers",
        max_tokens=500,
        temperature=0.7
    )
    
    response = await ananke.generate(request)
    print(response.code)

asyncio.run(simple_generation())
```

### Example 2: Constrained JSON Output

Generate code that must output valid JSON.

```python
import asyncio
import json
from ananke import Ananke, PyGenerationRequest, PyConstraintIR

async def json_output():
    ananke = Ananke.from_env()
    
    json_constraint = PyConstraintIR(
        name="json_format",
        json_schema='{"type": "object", "properties": {"result": {"type": "string"}, "status": {"type": "integer"}}}',
        grammar=None,
        regex_patterns=[]
    )
    
    request = PyGenerationRequest(
        prompt="Parse the input string and return a JSON object with result and status",
        constraints_ir=[json_constraint],
        max_tokens=1000,
        temperature=0.5
    )
    
    response = await ananke.generate(request)
    
    # Should be valid JSON
    result = json.loads(response.code)
    print(f"Parsed: {result}")
    print(f"Validation: {response.validation}")

asyncio.run(json_output())
```

### Example 3: With Context

Generate code with file and language context.

```python
import asyncio
from ananke import Ananke, PyGenerationRequest, PyGenerationContext

async def with_context():
    ananke = Ananke.from_env()
    
    context = PyGenerationContext(
        current_file="src/api/handlers.py",
        language="python",
        project_root="/home/user/my-api"
    )
    
    request = PyGenerationRequest(
        prompt="Implement a handler for user authentication",
        max_tokens=800,
        temperature=0.7,
        context=context
    )
    
    response = await ananke.generate(request)
    print(f"Generated at: {response.provenance.original_intent}")
    print(f"Time: {response.metadata.generation_time_ms}ms")

asyncio.run(with_context())
```

### Example 4: Cache Management

Monitor and manage constraint compilation cache.

```python
import asyncio
from ananke import Ananke, PyConstraintIR

async def cache_management():
    ananke = Ananke(
        modal_endpoint="https://your-app.modal.run",
        enable_cache=True,
        cache_size=100
    )
    
    # Check initial stats
    stats = await ananke.cache_stats()
    print(f"Initial cache: {stats['size']}/{stats['limit']}")
    
    # Compile some constraints
    constraints = [
        PyConstraintIR(
            name="test1",
            json_schema='{"type": "string"}',
            grammar=None,
            regex_patterns=[]
        ),
        PyConstraintIR(
            name="test2",
            json_schema='{"type": "number"}',
            grammar=None,
            regex_patterns=[]
        )
    ]
    
    for i, constraint in enumerate(constraints):
        result = await ananke.compile_constraints([constraint])
        print(f"Compiled constraint {i+1}: {result['hash'][:8]}...")
    
    # Check stats after compilation
    stats = await ananke.cache_stats()
    print(f"After compilation: {stats['size']}/{stats['limit']}")
    
    # Clear cache
    await ananke.clear_cache()
    stats = await ananke.cache_stats()
    print(f"After clear: {stats['size']}/{stats['limit']}")

asyncio.run(cache_management())
```

### Example 5: Error Handling

Handle common errors gracefully.

```python
import asyncio
from ananke import Ananke, PyGenerationRequest

async def error_handling():
    try:
        ananke = Ananke(
            modal_endpoint="https://your-app.modal.run",
            timeout_secs=30
        )
    except RuntimeError as e:
        print(f"Failed to initialize: {e}")
        return
    
    request = PyGenerationRequest(
        prompt="Generate a Python function",
        max_tokens=500
    )
    
    try:
        response = await ananke.generate(request)
        print(response.code)
    except RuntimeError as e:
        print(f"Generation failed: {e}")
    except TimeoutError as e:
        print(f"Request timed out: {e}")

asyncio.run(error_handling())
```

### Example 6: Batch Generation

Generate multiple code snippets efficiently.

```python
import asyncio
from ananke import Ananke, PyGenerationRequest

async def batch_generation():
    ananke = Ananke.from_env()
    
    prompts = [
        "Write a function that reverses a string",
        "Write a function that checks if a string is a palindrome",
        "Write a function that counts vowels in a string"
    ]
    
    tasks = [
        ananke.generate(PyGenerationRequest(
            prompt=prompt,
            max_tokens=300,
            temperature=0.7
        ))
        for prompt in prompts
    ]
    
    results = await asyncio.gather(*tasks)
    
    for i, result in enumerate(results):
        print(f"\n--- Result {i+1} ---")
        print(result.code)
        print(f"Time: {result.metadata.generation_time_ms}ms")

asyncio.run(batch_generation())
```

---

## Type Signatures

Complete Python type signatures for all API methods.

```python
from typing import Optional, List, Dict, Any
from ananke import (
    Ananke,
    PyModalConfig,
    PyGenerationRequest,
    PyGenerationResponse,
    PyConstraintIR,
    PyGenerationContext,
    PyProvenance,
    PyValidationResult,
    PyGenerationMetadata,
)

# Ananke class
class Ananke:
    def __init__(
        self,
        modal_endpoint: str,
        modal_api_key: Optional[str] = None,
        model: str = "meta-llama/Llama-3.1-8B-Instruct",
        timeout_secs: int = 300,
        enable_cache: bool = True,
        cache_size: int = 1000
    ) -> None: ...
    
    @staticmethod
    def from_env() -> Ananke: ...
    
    async def generate(
        self,
        request: PyGenerationRequest
    ) -> PyGenerationResponse: ...
    
    async def compile_constraints(
        self,
        constraints: List[PyConstraintIR]
    ) -> Dict[str, Any]: ...
    
    async def health_check(self) -> bool: ...
    
    async def clear_cache(self) -> None: ...
    
    async def cache_stats(self) -> Dict[str, int]: ...

# PyModalConfig class
class PyModalConfig:
    def __init__(
        self,
        endpoint_url: str,
        model: str = "meta-llama/Llama-3.1-8B-Instruct",
        api_key: Optional[str] = None,
        timeout_secs: int = 300,
        max_retries: int = 3
    ) -> None: ...
    
    @staticmethod
    def from_env() -> PyModalConfig: ...

# PyGenerationRequest class
class PyGenerationRequest:
    def __init__(
        self,
        prompt: str,
        constraints_ir: List[PyConstraintIR] = [],
        max_tokens: int = 2048,
        temperature: float = 0.7,
        context: Optional[PyGenerationContext] = None
    ) -> None: ...
    
    prompt: str
    constraints_ir: List[PyConstraintIR]
    max_tokens: int
    temperature: float
    context: Optional[PyGenerationContext]

# PyGenerationResponse class
class PyGenerationResponse:
    code: str
    provenance: PyProvenance
    validation: PyValidationResult
    metadata: PyGenerationMetadata

# PyConstraintIR class
class PyConstraintIR:
    def __init__(
        self,
        name: str,
        json_schema: Optional[str] = None,
        grammar: Optional[str] = None,
        regex_patterns: List[str] = []
    ) -> None: ...
    
    name: str
    json_schema: Optional[str]
    grammar: Optional[str]
    regex_patterns: List[str]

# PyGenerationContext class
class PyGenerationContext:
    def __init__(
        self,
        current_file: Optional[str] = None,
        language: Optional[str] = None,
        project_root: Optional[str] = None
    ) -> None: ...
    
    current_file: Optional[str]
    language: Optional[str]
    project_root: Optional[str]

# PyProvenance class
class PyProvenance:
    model: str
    timestamp: int
    constraints_applied: List[str]
    original_intent: str

# PyValidationResult class
class PyValidationResult:
    all_satisfied: bool
    satisfied: List[str]
    violated: List[str]

# PyGenerationMetadata class
class PyGenerationMetadata:
    tokens_generated: int
    generation_time_ms: int
    avg_token_time_us: int
    constraint_compile_time_ms: int
```

---

## Error Handling

### Common Exceptions

#### RuntimeError

Raised when operations fail at runtime (network errors, timeouts, inference errors).

```python
try:
    ananke = Ananke(modal_endpoint="invalid://url")
except RuntimeError as e:
    print(f"Initialization failed: {e}")
```

Possible causes:
- Invalid Modal endpoint URL
- Network connectivity issues
- Modal service unreachable
- Authentication failure (invalid API key)
- Generation timeout
- Constraint compilation failure

### Error Recovery Patterns

#### Retry with Exponential Backoff

```python
import asyncio
from ananke import Ananke, PyGenerationRequest

async def generate_with_retry(ananke: Ananke, request: PyGenerationRequest, max_retries: int = 3):
    for attempt in range(max_retries):
        try:
            return await ananke.generate(request)
        except RuntimeError as e:
            if attempt == max_retries - 1:
                raise
            wait_time = 2 ** attempt  # Exponential backoff
            print(f"Attempt {attempt + 1} failed: {e}. Retrying in {wait_time}s...")
            await asyncio.sleep(wait_time)

# Usage
ananke = Ananke.from_env()
request = PyGenerationRequest(prompt="Your prompt here")
response = await generate_with_retry(ananke, request)
```

#### Health Check Before Operation

```python
async def safe_generate(ananke: Ananke, request: PyGenerationRequest):
    # Check service health first
    healthy = await ananke.health_check()
    if not healthy:
        raise RuntimeError("Modal service is not healthy")
    
    return await ananke.generate(request)
```

#### Graceful Degradation

```python
async def generate_or_fallback(ananke: Ananke, request: PyGenerationRequest, fallback_code: str = ""):
    try:
        return await ananke.generate(request)
    except RuntimeError as e:
        print(f"Generation failed: {e}")
        print("Falling back to default code")
        from ananke import PyGenerationResponse
        # Return a minimal response with fallback code
        return fallback_code
```

### Best Practices

1. **Always await async methods**: Generation, compilation, and health checks are async

```python
# Correct
response = await ananke.generate(request)

# Wrong - will raise TypeError
response = ananke.generate(request)
```

2. **Set appropriate timeouts**: Configure `timeout_secs` based on your use case

```python
# For interactive applications (quick response)
ananke = Ananke(
    modal_endpoint="...",
    timeout_secs=30
)

# For batch processing (allow longer)
ananke = Ananke(
    modal_endpoint="...",
    timeout_secs=300
)
```

3. **Monitor cache to prevent memory issues**:

```python
stats = await ananke.cache_stats()
if stats['size'] > stats['limit'] * 0.9:
    await ananke.clear_cache()
```

4. **Validate constraints before generation**:

```python
# Compile constraints separately to catch errors early
compiled = await ananke.compile_constraints(constraints)
print(f"Compiled: {compiled['hash']}")

# Then use in generation
request = PyGenerationRequest(prompt="...", constraints_ir=constraints)
response = await ananke.generate(request)
```

5. **Check validation results**:

```python
response = await ananke.generate(request)
if not response.validation.all_satisfied:
    print(f"Some constraints violated: {response.validation.violated}")
    # Log for analysis or retry with different parameters
```

---

## Environment Variables Reference

### Required

| Variable | Example | Description |
|----------|---------|-------------|
| `MODAL_ENDPOINT` | `https://your-app.modal.run` | Modal inference service URL |

### Optional

| Variable | Default | Description |
|----------|---------|-------------|
| `MODAL_API_KEY` | N/A | API key for authentication |
| `MODAL_MODEL` | `meta-llama/Llama-3.1-8B-Instruct` | Model name |
| `ANANKE_CACHE_SIZE` | `1000` | Constraint compilation cache size |

### Example .env File

```bash
# Required
MODAL_ENDPOINT=https://<YOUR_MODAL_WORKSPACE>--ananke-inference-generate-api.modal.run

# Optional
MODAL_API_KEY=your-secret-api-key
MODAL_MODEL=meta-llama/Llama-3.1-8B-Instruct
ANANKE_CACHE_SIZE=2000
```

---

## Performance Considerations

### Generation Time Breakdown

Typical generation time consists of:

1. **Request serialization**: <1ms
2. **Network latency**: 10-50ms (depends on Modal region)
3. **Inference**: 100-500ms (depends on token count and model)
4. **Constraint enforcement**: Token-level, overhead <10%
5. **Response deserialization**: <1ms

**Total**: 150-600ms typical for small-to-medium prompts

### Optimization Tips

1. **Reuse Ananke instances**: Don't create new instances per request
2. **Batch requests**: Use `asyncio.gather()` for parallel requests
3. **Enable caching**: Compiled constraints are cached by default
4. **Tune temperature**: Lower temperature (0.3-0.5) faster, higher (0.7-1.0) creative
5. **Limit max_tokens**: Only generate what you need

### Throughput Example

```python
import time
import asyncio
from ananke import Ananke, PyGenerationRequest

async def measure_throughput():
    ananke = Ananke.from_env()
    
    num_requests = 10
    start = time.time()
    
    tasks = [
        ananke.generate(PyGenerationRequest(
            prompt=f"Generate code snippet {i}",
            max_tokens=200
        ))
        for i in range(num_requests)
    ]
    
    results = await asyncio.gather(*tasks)
    elapsed = time.time() - start
    
    total_tokens = sum(r.metadata.tokens_generated for r in results)
    throughput = total_tokens / elapsed
    
    print(f"Generated {num_requests} requests")
    print(f"Total tokens: {total_tokens}")
    print(f"Time: {elapsed:.2f}s")
    print(f"Throughput: {throughput:.0f} tokens/sec")

asyncio.run(measure_throughput())
```

---

## Troubleshooting

### Connection Errors

**Problem**: `RuntimeError: Failed to initialize Maze orchestrator`

**Causes**:
- Invalid `modal_endpoint` URL
- Modal service not running
- Network connectivity issue

**Solution**:
```python
# Verify endpoint is correct
import os
print(f"Endpoint: {os.environ['MODAL_ENDPOINT']}")

# Test with health_check
healthy = await ananke.health_check()
print(f"Service healthy: {healthy}")
```

### Timeout Errors

**Problem**: `RuntimeError: Generation failed: timeout`

**Solution**:
```python
# Increase timeout
ananke = Ananke(
    modal_endpoint="...",
    timeout_secs=600  # 10 minutes
)
```

### Cache Issues

**Problem**: Memory usage growing over time

**Solution**:
```python
# Monitor and clear cache periodically
stats = await ananke.cache_stats()
if stats['size'] > 100:
    await ananke.clear_cache()
```

### Constraint Compilation Errors

**Problem**: `RuntimeError: Failed to compile constraints`

**Causes**:
- Invalid JSON Schema
- Invalid grammar syntax
- Invalid regex patterns

**Solution**:
```python
# Validate constraints before use
try:
    compiled = await ananke.compile_constraints(constraints)
    print(f"OK: {compiled['hash']}")
except RuntimeError as e:
    print(f"Invalid constraint: {e}")
```

---

## Version History

### Phase 7b (Current)

- Added `compile_constraints()` method
- Added `health_check()` method
- Added `clear_cache()` method
- Added `cache_stats()` method
- Comprehensive Python API documentation

### Phase 7a

- Initial Python API with `generate()` method
- PyO3 bindings for core types
- Modal inference service integration

---

## Related Documentation

- [User Guide](USER_GUIDE.md) - High-level usage patterns
- [Architecture Guide](ARCHITECTURE.md) - System design and components
- [FFI Guide](FFI_GUIDE.md) - Foreign function interface details
- [Troubleshooting](TROUBLESHOOTING.md) - Common issues and solutions

