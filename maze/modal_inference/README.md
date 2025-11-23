# Ananke Modal Inference Service

GPU-based constrained code generation service using vLLM 0.8.2+ with llguidance for token-level constraint enforcement.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│         Ananke Modal Inference Service              │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ┌──────────────┐        ┌──────────────┐         │
│  │   vLLM       │───────▶│  llguidance  │         │
│  │   Server     │        │   Engine     │         │
│  └──────────────┘        └──────────────┘         │
│         │                        │                 │
│         └────────────────────────┘                 │
│                    │                               │
│                    ▼                               │
│         Llama 3.1 / DeepSeek / etc                │
│         (GPU-accelerated inference)                │
│                                                     │
├─────────────────────────────────────────────────────┤
│  HTTP API                                          │
│  • POST /generate_api  - Constrained generation   │
│  • GET  /health        - Health check              │
└─────────────────────────────────────────────────────┘
```

## Features

- **Fast GPU Inference**: vLLM with paged attention on A100 GPU
- **Constraint Enforcement**: llguidance for ~50μs per-token masking
- **Scale-to-Zero**: Automatic scaling with 60s idle timeout
- **Multiple Constraint Types**:
  - JSON Schema constraints
  - Context-free grammar constraints
  - Regex pattern constraints
  - Token mask constraints (experimental)
- **Production Ready**: Error handling, retries, monitoring

## Quick Start

### 1. Install Dependencies

```bash
pip install -r requirements.txt
```

### 2. Authenticate with Modal

```bash
modal token new
```

This will open a browser to authenticate with Modal.

### 3. Deploy the Service

```bash
./deploy.sh
```

Or manually:

```bash
modal deploy inference.py
```

### 4. Test the Service

```bash
# Set the endpoint URL (from deployment output)
export MODAL_ENDPOINT="https://your-app.modal.run"

# Test with client
python client.py
```

## Usage

### Python Client

```python
from client import AnankeClient

# Create client
client = AnankeClient("https://your-app.modal.run")

# Simple generation
response = client.generate(
    prompt="Write a Python function to add two numbers:",
    max_tokens=100,
    temperature=0.7,
)

print(f"Generated: {response.generated_text}")

# Constrained generation with JSON schema
response = client.generate(
    prompt="Generate a user profile:",
    constraints={
        "json_schema": {
            "type": "object",
            "properties": {
                "name": {"type": "string"},
                "age": {"type": "integer"},
                "email": {"type": "string"},
            },
            "required": ["name", "age"],
        }
    },
    max_tokens=100,
)

print(f"Generated JSON: {response.generated_text}")
```

### HTTP API

```bash
# Health check
curl https://your-app.modal.run/health

# Generate with constraints
curl -X POST https://your-app.modal.run/generate_api \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Write a Python function:",
    "constraints": {
      "json_schema": {
        "type": "object",
        "properties": {
          "function_name": {"type": "string"},
          "parameters": {"type": "array"}
        }
      }
    },
    "max_tokens": 200,
    "temperature": 0.7
  }'
```

### Rust Integration

```rust
// In Maze orchestration layer
use maze::{MazeOrchestrator, ModalConfig};

let config = ModalConfig::new(
    "https://your-app.modal.run".to_string(),
    "meta-llama/Llama-3.1-8B-Instruct".to_string(),
);

let orchestrator = MazeOrchestrator::new(config)?;

let response = orchestrator.generate(request).await?;
```

## Configuration

Edit `config.yaml` to customize:

- **Model**: Change model name, size, parameters
- **GPU**: Configure GPU type, count, memory
- **Deployment**: Adjust timeouts, concurrency, scaling
- **Constraints**: Enable/disable constraint types
- **Performance**: Set target latencies, costs

## Development

### Local Testing

```bash
# Test locally (requires Modal authentication)
modal run inference.py

# This will run the test suite locally
```

### Deploy Changes

```bash
# Deploy updates
modal deploy inference.py

# View logs
modal app logs ananke-inference

# Stop the service
modal app stop ananke-inference
```

### Monitoring

```bash
# List deployed apps
modal app list

# View service logs
modal app logs ananke-inference --follow

# Check service status
curl https://your-app.modal.run/health
```

## Cost Optimization

The service uses scale-to-zero to minimize costs:

- **Idle Cost**: $0 (scales to zero after 60s idle)
- **Active Cost**: ~$3.60/hour (A100 40GB)
- **Cold Start**: 3-5 seconds (Model loading)
- **Warm Request**: 2-10 seconds (depending on tokens)

Cost per request depends on:
- Number of tokens generated
- Request frequency (affects cold starts)
- GPU idle time

Example costs:
- 100 requests/day, 500 tokens each: ~$5-10/month
- 1000 requests/day, 1000 tokens each: ~$50-100/month

## Performance Characteristics

### Latency

- **Cold start**: 3-5 seconds (container + model loading)
- **Warm request**: 2-10 seconds (depends on token count)
- **Per token**: ~100-500ms (model dependent)
- **Constraint masking**: ~50μs per token (llguidance)

### Throughput

- **Concurrent requests**: Up to 10 per container
- **Tokens/second**: ~50-100 (depends on model size)
- **Auto-scaling**: Scales up to 10 containers

### Constraint Overhead

- **JSON schema**: ~50μs per token
- **Grammar**: ~50-100μs per token
- **Regex**: ~20-50μs per token

## Supported Models

Default: `meta-llama/Llama-3.1-8B-Instruct`

Alternatives (configure in `config.yaml`):
- `meta-llama/Llama-3.1-70B-Instruct` - Better quality, slower
- `deepseek-ai/deepseek-coder-33b-instruct` - Code-specific
- `codellama/CodeLlama-34b-Instruct-hf` - Legacy code model

## Constraint Types

### JSON Schema

```python
constraints = {
    "json_schema": {
        "type": "object",
        "properties": {
            "name": {"type": "string"},
            "age": {"type": "integer"},
        },
        "required": ["name"],
    }
}
```

### Grammar

```python
constraints = {
    "grammar": "function ::= 'fn' name '(' params ')' block"
}
```

### Regex

```python
constraints = {
    "regex_patterns": [r"Result<.*>", r"Option<.*>"]
}
```

### Token Mask (Experimental)

```python
constraints = {
    "token_mask": {
        "allowed_tokens": [1, 2, 3, ...],
        "forbidden_tokens": [100, 101, ...],
    }
}
```

## Troubleshooting

### Authentication Issues

```bash
# Re-authenticate
modal token new

# Verify authentication
modal token list
```

### Deployment Failures

```bash
# Check logs for errors
modal app logs ananke-inference

# Verify configuration
python -c "import yaml; print(yaml.safe_load(open('config.yaml')))"

# Test locally first
modal run inference.py
```

### Request Timeouts

- Increase `timeout` in client or config
- Reduce `max_tokens` in request
- Check service logs for errors

### Cold Start Issues

- Consider keeping min_containers > 0 for lower latency
- Trade-off between cost and cold start frequency

### Constraint Errors

- Verify JSON schema is valid
- Check grammar syntax
- Test regex patterns separately
- Enable verbose logging

## Security

- Set `require_api_key: true` in config.yaml for production
- Use environment variables for sensitive data
- Consider rate limiting for public endpoints
- Review Modal security best practices

## Support

For issues specific to Modal deployment:
- Check Modal service health first
- Review Modal documentation
- Check service logs: `modal app logs ananke-inference`

For Ananke integration issues:
- See main repository documentation
- Check Rust Maze orchestration layer
- Verify constraint IR format

## License

MIT OR Apache-2.0
