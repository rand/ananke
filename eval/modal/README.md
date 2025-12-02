# Ananke Evaluation Inference Service

Modal-based inference service for the Ananke evaluation framework using vLLM and Qwen/Qwen2.5-Coder-32B-Instruct.

## Setup

### Prerequisites

1. Install Modal CLI:
```bash
pip install modal
```

2. Authenticate with Modal:
```bash
modal token new
```

### Deploy the Service

Deploy to Modal cloud:

```bash
cd eval/modal
modal deploy inference_service.py
```

This will:
- Create a Modal app named `ananke-eval-inference`
- Download and cache the Qwen/Qwen2.5-Coder-32B-Instruct model
- Deploy two web endpoints for code generation

### Get Endpoint URLs

After deployment, Modal will output the endpoint URLs:

```
✓ Created web function generate_constrained_endpoint => https://yourorg--ananke-eval-inference-generate-constrained-endpoint.modal.run
✓ Created web function generate_unconstrained_endpoint => https://yourorg--ananke-eval-inference-generate-unconstrained-endpoint.modal.run
```

Save these URLs - you'll need them to configure the Zig evaluation runner.

## API Reference

### POST /generate/constrained

Generate code with Ananke constraints.

**Request:**
```json
{
  "prompt": "Implement a function that checks if a number is prime",
  "constraints": {
    "grammar": "function isPrime(n: number): boolean",
    "type_constraints": {
      "parameters": [{"name": "n", "type": "number"}],
      "return_type": "boolean"
    },
    "naming_constraints": {
      "function_name": "isPrime"
    },
    "structural_constraints": {
      "must_use": ["for loop or while loop"],
      "must_not_use": ["external libraries"]
    },
    "complexity_constraints": {
      "time_complexity": "O(sqrt(n))",
      "space_complexity": "O(1)"
    }
  },
  "model": "Qwen/Qwen2.5-Coder-32B-Instruct"
}
```

**Response:**
```json
{
  "code": "function isPrime(n: number): boolean {\n  if (n <= 1) return false;\n  if (n <= 3) return true;\n  if (n % 2 === 0 || n % 3 === 0) return false;\n  \n  for (let i = 5; i * i <= n; i += 6) {\n    if (n % i === 0 || n % (i + 2) === 0) {\n      return false;\n    }\n  }\n  \n  return true;\n}",
  "metadata": {
    "tokens_used": 145,
    "generation_time_ms": 1234,
    "model": "Qwen/Qwen2.5-Coder-32B-Instruct"
  }
}
```

### POST /generate/unconstrained

Generate code with few-shot examples (baseline).

**Request:**
```json
{
  "prompt": "Implement a function that checks if a number is prime",
  "few_shot_examples": [
    {
      "prompt": "Implement a function to check if a number is even",
      "code": "function isEven(n: number): boolean {\n  return n % 2 === 0;\n}"
    },
    {
      "prompt": "Implement a function to find the maximum of two numbers",
      "code": "function max(a: number, b: number): number {\n  return a > b ? a : b;\n}"
    }
  ],
  "model": "Qwen/Qwen2.5-Coder-32B-Instruct"
}
```

**Response:**
```json
{
  "code": "function isPrime(n: number): boolean {\n  // implementation...\n}",
  "metadata": {
    "tokens_used": 156,
    "generation_time_ms": 1189,
    "model": "Qwen/Qwen2.5-Coder-32B-Instruct"
  }
}
```

## Configuration

### Model Settings

The service uses the following configuration:

- **Model:** Qwen/Qwen2.5-Coder-32B-Instruct
- **GPU:** A100 40GB
- **Max Tokens:** 2048
- **Temperature:** 0.2
- **Top P:** 0.95
- **Max Model Length:** 8192 tokens

### Scaling

Modal automatically scales containers based on load:

- **Container Idle Timeout:** 5 minutes
- **GPU Memory Utilization:** 90%
- **Timeout:** 10 minutes per request

## Local Testing

Test endpoints locally before deployment:

```bash
modal serve inference_service.py
```

This starts a local development server at `http://localhost:8000`.

Test with curl:

```bash
# Test constrained generation
curl -X POST http://localhost:8000/generate/constrained \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Implement binary search",
    "constraints": {
      "grammar": "function binarySearch(arr: number[], target: number): number"
    }
  }'

# Test unconstrained generation
curl -X POST http://localhost:8000/generate/unconstrained \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Implement binary search",
    "few_shot_examples": []
  }'
```

## Monitoring

View logs and metrics in the Modal dashboard:

```bash
modal app logs ananke-eval-inference
```

## Cost Optimization

- Modal charges based on GPU usage time
- Containers auto-scale to zero when idle (5 min timeout)
- Model is cached in persistent volume to avoid re-downloads
- Consider using smaller GPUs (A10G, T4) for lower costs if performance allows

## Troubleshooting

### Model Download Issues

If model download fails:

```bash
modal volume ls
modal volume delete ananke-model-cache
# Redeploy to trigger fresh download
modal deploy inference_service.py
```

### Timeout Errors

For very long generations, increase timeout:

```python
@app.cls(
    timeout=1200,  # 20 minutes
    ...
)
```

### Out of Memory

Reduce GPU memory utilization or use larger GPU:

```python
self.llm = LLM(
    gpu_memory_utilization=0.85,  # Reduce from 0.9
    ...
)
```

## Integration with Zig Evaluation Runner

Update the Zig modal client in `eval/core/modal_client.zig`:

```zig
const MODAL_ENDPOINT = "https://yourorg--ananke-eval-inference-generate-constrained-endpoint.modal.run";
```

Run evaluations:

```bash
./zig-out/bin/ananke-eval run --modal-endpoint https://yourorg--ananke-eval-inference-...
```
