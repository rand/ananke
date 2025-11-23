# Ananke Modal Inference - Quick Start Guide

Get up and running with the Ananke inference service in 5 minutes.

## Prerequisites

- Python 3.11 or later
- Modal account (free tier available)
- HuggingFace account (for model access)

## Step 1: Install Modal

```bash
pip install modal
```

## Step 2: Authenticate

```bash
# Create Modal account and authenticate
modal token new

# This will open a browser to complete authentication
# Follow the prompts
```

## Step 3: Set Up HuggingFace Access

```bash
# 1. Get your HuggingFace token from:
#    https://huggingface.co/settings/tokens

# 2. Accept the Llama 3.1 license at:
#    https://huggingface.co/meta-llama/Meta-Llama-3.1-8B-Instruct

# 3. Create Modal secret
modal secret create huggingface-secret \
  HUGGING_FACE_HUB_TOKEN=hf_your_token_here
```

## Step 4: Deploy

```bash
# Option A: Use deployment script (recommended)
./modal_inference/deploy.sh

# Option B: Manual deployment
modal deploy modal_inference/inference.py
```

## Step 5: Test

```bash
# Run the built-in test
modal run modal_inference/inference.py

# This will:
# - Load the model on a GPU
# - Run an example generation
# - Show results and performance metrics
```

## Step 6: Use It

### Python API

```python
import modal

# Get service reference
InferenceService = modal.Cls.lookup("ananke-inference", "InferenceService")

# Create request
request = {
    "prompt": "Generate a Python function that validates email addresses:",
    "constraints": {
        "type": "json",
        "schema": {
            "type": "object",
            "properties": {
                "function_name": {"type": "string"},
                "parameters": {"type": "array"},
                "body": {"type": "string"}
            },
            "required": ["function_name", "body"]
        }
    },
    "max_tokens": 512,
    "temperature": 0.7
}

# Generate
service = InferenceService()
result = service.generate.remote(request)

print(result["generated_code"])
```

### HTTP API

```bash
# Get endpoint URL from deployment output or:
modal app list

# Make request
curl -X POST https://yourapp--generate-endpoint.modal.run \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Generate a function",
    "constraints": {"type": "regex", "pattern": "def .*"},
    "max_tokens": 256
  }'
```

## Next Steps

1. **Run Examples**: `python modal_inference/example_usage.py`
2. **Run Tests**: `modal run modal_inference/test_inference.py`
3. **Read Full Docs**: See `modal_inference/README.md`
4. **Configure**: Edit `modal_inference/config.yaml`
5. **Integrate**: Connect with Maze orchestration layer

## Common Issues

### Model Download Fails

```bash
# Check HuggingFace token
modal secret list

# Verify model access
# Go to https://huggingface.co/meta-llama/Meta-Llama-3.1-8B-Instruct
# Make sure you've accepted the license
```

### Out of Memory

```python
# In inference.py, reduce memory utilization:
gpu_memory_utilization=0.85  # Instead of 0.90

# Or use smaller model:
DEFAULT_MODEL = "meta-llama/Meta-Llama-3.1-8B-Instruct"
```

### Slow Performance

```python
# Keep container warm longer:
container_idle_timeout=300  # 5 minutes

# Or increase concurrent requests:
allow_concurrent_inputs=20
```

## Cost Optimization

- **Development**: Use 8B model (~$0.01/request)
- **Production**: Use 70B model (~$0.05/request)
- **Scale to zero**: Automatic after 60s idle
- **Batch requests**: Use Maze orchestration layer

## Getting Help

- Full documentation: `modal_inference/README.md`
- Modal docs: https://modal.com/docs
- Ananke implementation plan: `docs/IMPLEMENTATION_PLAN.md`
- Issues: File on GitHub

## What's Next?

Once your inference service is running:

1. **Connect Maze**: Integrate with the Maze orchestration layer
2. **Add Constraints**: Use Clew and Braid to generate ConstraintIR
3. **Build Pipeline**: Connect all Ananke components
4. **Deploy to Production**: Scale up with 70B model

See the main implementation plan for the complete architecture.
