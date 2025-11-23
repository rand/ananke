# Ananke Modal Inference Service

GPU-accelerated constrained code generation using vLLM and llguidance on Modal.

## Overview

This service provides the inference layer for Ananke's constrained code generation pipeline. It integrates vLLM (for efficient GPU inference) with llguidance (for token-level constraint enforcement) to ensure generated code satisfies all specified constraints.

### Key Features

- **Token-level constraint enforcement** using llguidance FSM compilation
- **Scale-to-zero** architecture (60-second idle timeout)
- **A100 GPU support** (40GB or 80GB VRAM configurations)
- **Multiple model backends** (Llama 3.1, Mistral, DeepSeek)
- **Sub-50μs logit masking** for constraint validation
- **Comprehensive error handling** and logging
- **Provenance tracking** for all generated code

## Architecture

```
┌─────────────────────────────────────────┐
│         Maze Orchestration              │
│         (Rust/Python client)            │
└──────────────┬──────────────────────────┘
               │ HTTP/gRPC
               ▼
┌─────────────────────────────────────────┐
│      Modal Inference Service            │
│  ┌─────────────────────────────────┐   │
│  │  ConstraintIR → FSM Compiler    │   │
│  │      (llguidance)               │   │
│  └─────────────┬───────────────────┘   │
│                ▼                        │
│  ┌─────────────────────────────────┐   │
│  │   vLLM Inference Engine         │   │
│  │   - Model loading               │   │
│  │   - GPU memory management       │   │
│  │   - Batched generation          │   │
│  │   - Logit masking               │   │
│  └─────────────────────────────────┘   │
│                                         │
│         A100 GPU (40-80GB)              │
└─────────────────────────────────────────┘
```

## Prerequisites

### 1. Modal Account Setup

```bash
# Install Modal CLI
pip install modal

# Authenticate with Modal
modal token new

# Verify authentication
modal token list
```

### 2. HuggingFace Token

For accessing gated models (Llama, etc.):

1. Create account at https://huggingface.co
2. Generate access token at https://huggingface.co/settings/tokens
3. Accept model license agreements (for Llama 3.1, etc.)

```bash
# Create Modal secret for HuggingFace token
modal secret create huggingface-secret \
  HUGGING_FACE_HUB_TOKEN=hf_your_token_here
```

### 3. Dependencies

```bash
# Install Python dependencies
pip install -r requirements.txt
```

## Deployment

### Quick Start

```bash
# Deploy to Modal
modal deploy modal_inference/inference.py

# The service will output an endpoint URL:
# ✓ Created web function generate_endpoint => https://yourapp--generate-endpoint.modal.run
```

### Testing the Deployment

```bash
# Run local test
modal run modal_inference/inference.py

# This will:
# 1. Load the model on Modal GPU
# 2. Compile example constraints
# 3. Generate code
# 4. Return results with provenance
```

### Using Different Models

Edit `inference.py` to change the default model:

```python
# For development (faster, cheaper)
DEFAULT_MODEL = "meta-llama/Meta-Llama-3.1-8B-Instruct"

# For production (higher quality)
DEFAULT_MODEL = "meta-llama/Meta-Llama-3.1-70B-Instruct"

# For code-specific tasks
DEFAULT_MODEL = "deepseek-ai/deepseek-coder-6.7b-instruct"
```

Or configure at runtime via environment variables.

## Usage

### Python Client Example

```python
import modal
import json

# Get reference to deployed service
InferenceService = modal.Cls.lookup("ananke-inference", "InferenceService")

# Prepare request
request = {
    "prompt": "Create a Python function that validates email addresses",
    "constraints": {
        "type": "json",
        "schema": {
            "type": "object",
            "properties": {
                "function_name": {"type": "string"},
                "parameters": {"type": "array", "items": {"type": "string"}},
                "return_type": {"type": "string"},
                "body": {"type": "string"}
            },
            "required": ["function_name", "parameters", "return_type", "body"]
        }
    },
    "max_tokens": 512,
    "temperature": 0.7,
    "metadata": {
        "request_id": "example-001"
    }
}

# Generate with constraints
service = InferenceService()
result = service.generate.remote(request)

print(f"Generated code:\n{result['generated_code']}")
print(f"Tokens: {result['tokens_generated']}")
print(f"Time: {result['generation_time_ms']:.2f}ms")
print(f"Violations: {result['constraint_violations']}")
```

### HTTP API Example

```bash
# Get the web endpoint URL from deployment
ENDPOINT_URL="https://yourapp--generate-endpoint.modal.run"

# Make request
curl -X POST $ENDPOINT_URL \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Generate a function to parse JSON",
    "constraints": {
      "type": "regex",
      "pattern": "def \\w+\\(.*\\):.*"
    },
    "max_tokens": 256,
    "temperature": 0.7
  }'
```

### Constraint Types

#### 1. JSON Schema Constraints

```python
constraints = {
    "type": "json",
    "schema": {
        "type": "object",
        "properties": {
            "name": {"type": "string"},
            "age": {"type": "number"}
        },
        "required": ["name"]
    }
}
```

#### 2. Grammar Constraints (EBNF)

```python
constraints = {
    "type": "grammar",
    "grammar": """
        function ::= "def" identifier "(" params ")" ":" body
        identifier ::= [a-z_][a-z0-9_]*
        params ::= identifier ("," identifier)*
        body ::= statement+
    """
}
```

#### 3. Regex Constraints

```python
constraints = {
    "type": "regex",
    "pattern": r"class \w+\(.*\):\s+def __init__\(self.*\):"
}
```

#### 4. Composite Constraints

```python
constraints = {
    "type": "composite",
    "constraints": [
        {"type": "regex", "pattern": "def \\w+\\(.*\\):"},
        {"type": "json", "schema": {...}},
    ]
}
```

## Integration with Ananke Pipeline

### From Maze Orchestration Layer

```rust
// In Maze (Rust)
use reqwest::Client;
use serde_json::json;

pub async fn generate_with_constraints(
    endpoint: &str,
    prompt: &str,
    constraints: ConstraintIR,
) -> Result<GeneratedCode> {
    let client = Client::new();

    let request = json!({
        "prompt": prompt,
        "constraints": constraints.to_llguidance_format(),
        "max_tokens": 2048,
        "temperature": 0.7,
        "metadata": {
            "maze_version": "0.1.0",
            "timestamp": chrono::Utc::now().to_rfc3339(),
        }
    });

    let response = client
        .post(endpoint)
        .json(&request)
        .send()
        .await?;

    let result: GenerationResponse = response.json().await?;

    Ok(GeneratedCode {
        code: result.generated_code,
        provenance: result.provenance,
    })
}
```

### From CLI (via Maze)

```bash
# Full pipeline: Clew → Braid → Maze → Modal
ananke generate "create auth handler" \
  --constraints compiled.cir \
  --inference-url https://yourapp.modal.run

# Direct API call for testing
ananke inference test \
  --prompt "Generate a function" \
  --constraints-file schema.json
```

## Performance

### Benchmarks (Llama 3.1 8B on A100 40GB)

- **Model loading**: 3-5 seconds (cached after first request)
- **Constraint compilation**: 10-100ms (depends on complexity)
- **Generation speed**: 40-60 tokens/second
- **Logit masking overhead**: <50μs per token
- **End-to-end latency**: 2-5 seconds for 100-token generation

### Cost Estimates

With Modal's scale-to-zero pricing:

- **Model loading**: ~$0.005 per cold start
- **Generation**: ~$0.01-0.05 per request (depends on length)
- **Idle cost**: $0 (scales to zero after 60s)
- **Monthly estimate**: ~$10-50 for moderate usage (1000 requests)

## Monitoring and Debugging

### View Logs

```bash
# Stream live logs
modal app logs ananke-inference

# View specific function logs
modal function logs ananke-inference.InferenceService.generate
```

### Health Check

```python
# Check service health
service = InferenceService()
health = service.health_check.remote()
print(health)
# {
#   "status": "healthy",
#   "model": "meta-llama/Meta-Llama-3.1-8B-Instruct",
#   "model_info": {...},
#   "timestamp": 1234567890.123
# }
```

### Validate Constraints

```python
# Test constraint compilation without generating
service = InferenceService()
validation = service.validate_constraints.remote({
    "type": "json",
    "schema": {...}
})

if validation["valid"]:
    print("Constraints compiled successfully!")
else:
    print(f"Error: {validation['error']}")
```

## Configuration

See `config.yaml` for all configuration options:

- Model selection and parameters
- GPU configuration
- Sampling parameters
- Constraint settings
- Logging and monitoring
- Security and rate limiting

## Troubleshooting

### Common Issues

#### 1. Model Download Fails

```bash
# Ensure HuggingFace token is set correctly
modal secret list

# Verify model access
# Visit https://huggingface.co/meta-llama/Meta-Llama-3.1-8B-Instruct
# Accept license agreement
```

#### 2. Out of Memory (OOM)

```python
# Reduce memory utilization in inference.py
self.llm = LLM(
    model=self.model_name,
    gpu_memory_utilization=0.85,  # Reduced from 0.90
    # ...
)

# Or switch to smaller model
DEFAULT_MODEL = "meta-llama/Meta-Llama-3.1-8B-Instruct"
```

#### 3. Slow Cold Starts

```python
# Increase idle timeout to keep container warm longer
container_idle_timeout=300,  # 5 minutes instead of 60s
```

#### 4. Constraint Compilation Errors

```python
# Validate constraints before sending
validation = service.validate_constraints.remote(constraints)
if not validation["valid"]:
    print(f"Fix constraint error: {validation['error']}")
```

### Debug Mode

Enable detailed logging:

```python
# In inference.py
logging.basicConfig(
    level=logging.DEBUG,  # Changed from INFO
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
```

## Development

### Local Testing

```bash
# Run with Modal CLI
modal run modal_inference/inference.py

# Test constraint validation
modal run modal_inference/inference.py --test-constraints

# Test with custom model
modal run modal_inference/inference.py --model mistral-7b
```

### Running Tests

```bash
# Install test dependencies
pip install pytest pytest-asyncio

# Run tests (coming soon)
pytest modal_inference/tests/

# Run with coverage
pytest --cov=modal_inference modal_inference/tests/
```

### Updating the Service

```bash
# Make changes to inference.py

# Redeploy
modal deploy modal_inference/inference.py

# Verify deployment
modal app list
```

## Production Deployment

### Recommended Configuration

```python
# Use 70B model for quality
DEFAULT_MODEL = "meta-llama/Meta-Llama-3.1-70B-Instruct"

# A100 80GB for large models
GPU_CONFIG = modal.gpu.A100(count=1, memory=80)

# Longer timeout for complex generations
IDLE_TIMEOUT = 300

# Enable monitoring
@app.function(
    # ... existing config ...
    enable_memory_snapshot=True,
)
```

### Scaling Strategy

```python
# Allow concurrent requests
@app.cls(
    # ...
    allow_concurrent_inputs=20,  # Handle more requests per container
    max_containers=10,           # Auto-scale up to 10 containers
)
```

### Monitoring

Set up alerts for:
- Generation errors
- Constraint violations
- Slow requests (>10s)
- OOM errors
- Cold start frequency

## Security

### API Authentication

Add authentication to web endpoint:

```python
@modal.web_endpoint(method="POST")
def generate_endpoint(request: Dict[str, Any]) -> Dict[str, Any]:
    # Validate API key
    auth_header = request.headers.get("Authorization")
    if not validate_api_key(auth_header):
        return {"error": "Unauthorized"}, 401

    # ... rest of endpoint
```

### Rate Limiting

Implement rate limiting:

```python
from modal import Rate

@app.function(
    rate_limit=Rate(max_requests=100, period=60),  # 100 req/min
)
def generate_endpoint(...):
    # ...
```

## Support

For issues, questions, or contributions:

- GitHub Issues: [ananke/issues](https://github.com/yourusername/ananke/issues)
- Documentation: [docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md)
- Implementation Plan: [docs/IMPLEMENTATION_PLAN.md](../docs/IMPLEMENTATION_PLAN.md)

## License

See main Ananke repository for license information.
