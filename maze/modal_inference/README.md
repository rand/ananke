# Ananke Modal Inference Service

Production-ready GPU inference service for constrained code generation using vLLM 0.11.0 with llguidance. Deployed on Modal with scale-to-zero architecture.

## Architecture

```
┌────────────────────────────────────────────────────────────────┐
│              Ananke Modal Inference Service                    │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  ┌─────────────────┐          ┌──────────────────┐            │
│  │  FastAPI Web    │          │   AnankeLLM      │            │
│  │  Endpoints      │─────────▶│   Class Method   │            │
│  │  (HTTP Layer)   │          │   (GPU Instance) │            │
│  └─────────────────┘          └──────────────────┘            │
│                                        │                       │
│                                        ▼                       │
│                     ┌─────────────────────────────┐            │
│                     │  vLLM 0.11.0 Engine         │            │
│                     │  + llguidance 0.7.11-0.8.0  │            │
│                     │  + CUDA 12.4.1              │            │
│                     └─────────────────────────────┘            │
│                                        │                       │
│                                        ▼                       │
│                     Qwen2.5-Coder-32B-Instruct                 │
│                     (A100-80GB GPU)                            │
│                                                                │
├────────────────────────────────────────────────────────────────┤
│  Endpoints                                                     │
│  • GET  /health        - Health check                          │
│  • POST /generate_api  - Constrained generation                │
└────────────────────────────────────────────────────────────────┘
```

## Features

- **Fast GPU Inference**: vLLM with paged attention on A100-80GB
- **Constraint Enforcement**: llguidance for token-level masking (~50μs overhead)
- **Scale-to-Zero**: Environment-based cost controls (dev/demo/prod modes)
- **Multiple Constraint Types**:
  - JSON Schema constraints (V1 structured outputs API)
  - Context-free grammar constraints
  - Regex pattern constraints
- **Production Ready**: Proven configuration, error handling, retries, monitoring
- **Performance**: 22.3 tokens/sec throughput with constrained generation

## Quick Start

### 1. Install Dependencies

```bash
pip install -r requirements.txt
```

### 2. Authenticate with Modal

```bash
modal token new
```

This opens a browser to authenticate with your Modal account.

### 3. Deploy the Service

Choose your deployment mode based on usage:

```bash
# Development mode (2 min scaledown, cost-optimized)
MODAL_MODE=dev modal deploy inference.py

# Demo mode (10 min scaledown, for presentations)
MODAL_MODE=demo modal deploy inference.py

# Production mode (5 min scaledown, balanced)
MODAL_MODE=prod modal deploy inference.py
```

Or use the automated script:

```bash
./deploy.sh
```

Deployment typically takes 1-2 minutes. You'll receive endpoint URLs like:
- Health: `https://your-username--ananke-inference-health.modal.run`
- Generate: `https://your-username--ananke-inference-generate-api.modal.run`

### 4. Test the Service

```bash
# Set the endpoint URL (from deployment output)
export MODAL_ENDPOINT="https://your-username--ananke-inference-generate-api.modal.run"

# Test with client
python client.py
```

## Usage Examples

### Python Client - Simple Generation

```python
from client import AnankeClient

# Create client
client = AnankeClient("https://your-username--ananke-inference-generate-api.modal.run")

# Simple code generation
response = client.generate(
    prompt="Write a Python function to add two numbers:",
    max_tokens=100,
    temperature=0.7,
)

print(f"Generated: {response.generated_text}")
print(f"Performance: {response.tokens_generated} tokens in {response.generation_time_ms}ms")
print(f"Throughput: {response.metadata['tokens_per_sec']:.1f} tokens/sec")
```

### Python Client - JSON Schema Constraints

This demonstrates the key feature: constrained generation that guarantees valid JSON output.

```python
from client import AnankeClient

client = AnankeClient("https://your-username--ananke-inference-generate-api.modal.run")

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
                "role": {"type": "string", "enum": ["admin", "user", "guest"]}
            },
            "required": ["name", "age"],
        }
    },
    max_tokens=100,
)

# Output is guaranteed to be valid JSON matching the schema
print(f"Generated JSON: {response.generated_text}")
print(f"Constraint satisfied: {response.constraint_satisfied}")
```

**Key Point**: The `json` parameter in `StructuredOutputsParams` (not `json_schema`) is critical for vLLM 0.11.0. This was a major lesson learned during deployment.

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

## Cost Controls and Environment Modes

The service uses environment-based cost controls via `MODAL_MODE`:

### Development Mode (Default)
```bash
MODAL_MODE=dev modal deploy inference.py
```
- **Scaledown**: 2 minutes (aggressive cost savings)
- **GPU Cost**: $4/hour A100-80GB (only when active)
- **Use case**: Development, testing, low-frequency usage
- **Monthly cost**: ~$5-20 depending on usage

### Demo Mode
```bash
MODAL_MODE=demo modal deploy inference.py
```
- **Scaledown**: 10 minutes (presentation-friendly)
- **GPU Cost**: $4/hour A100-80GB (only when active)
- **Use case**: Demos, presentations, workshops
- **Monthly cost**: ~$20-50 depending on demo frequency

### Production Mode
```bash
MODAL_MODE=prod modal deploy inference.py
```
- **Scaledown**: 5 minutes (balanced)
- **GPU Cost**: $4/hour A100-80GB (only when active)
- **Use case**: Production deployments with moderate traffic
- **Monthly cost**: Variable based on request patterns

### Cost Examples

| Usage Pattern | Mode | Monthly Cost (Est.) |
|---------------|------|---------------------|
| 10 requests/day, 500 tokens each | dev | $5-10 |
| 100 requests/day, 1000 tokens each | dev/prod | $20-50 |
| 1000 requests/day, 2000 tokens each | prod | $100-200 |
| 24/7 warm (no scaledown) | N/A | ~$2,880 |

**Note**: Modal scales to zero when idle, so you only pay for active inference time.

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

### Measured Performance (Qwen2.5-Coder-32B on A100-80GB)

**Throughput**:
- **Tokens/sec**: 22.3 tokens/sec (measured with JSON schema constraints)
- **Concurrent requests**: Up to 10 per container
- **Auto-scaling**: Scales up to configured max containers

**Latency**:
- **First cold start** (model download): 10-15 minutes (one-time, ~60GB model)
- **Subsequent cold starts** (cached model): 30-60 seconds
- **Warm requests**: 50-100ms overhead + generation time
- **Per token**: ~45ms average (22.3 tokens/sec)
- **Constraint masking**: ~50μs per token (llguidance overhead)

**Generation Time Examples**:
- 50 tokens: ~2-3 seconds
- 100 tokens: ~4-5 seconds
- 500 tokens: ~20-25 seconds
- 2000 tokens: ~90 seconds

### Constraint Overhead

Measured additional latency from constraint enforcement:

- **JSON schema**: ~50-100μs per token (negligible)
- **Grammar**: ~50-100μs per token
- **Regex**: ~20-50μs per token

The constraint overhead is minimal (<0.5%) compared to model inference time.

## Supported Models

**Currently Deployed**: `Qwen/Qwen2.5-Coder-32B-Instruct`

This model was chosen for superior code generation capabilities compared to Llama alternatives.

**Alternative Models** (edit `model_name` in `inference.py`):
- `meta-llama/Llama-3.1-8B-Instruct` - Faster, smaller, general purpose
- `meta-llama/Llama-3.1-70B-Instruct` - Better quality, requires more GPU memory
- `deepseek-ai/deepseek-coder-33b-instruct` - Alternative code model

**GPU Requirements**:
- 8B models: A100-40GB or A10G
- 32B models: A100-80GB (current config)
- 70B models: A100-80GB with reduced batch size

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

## Troubleshooting Guide

### Common Issues and Solutions

#### Issue 1: vLLM Parameter Error - `json_schema` Not Recognized

**Error**: `TypeError: __init__() got an unexpected keyword argument 'json_schema'`

**Root Cause**: vLLM 0.11.0's `StructuredOutputsParams` uses `json` parameter, not `json_schema`.

**Solution**:
```python
# WRONG (vLLM 0.10.x syntax)
StructuredOutputsParams(json_schema=schema)

# CORRECT (vLLM 0.11.0 syntax)
StructuredOutputsParams(json=schema)
```

This was fixed in commit `fb05f45`.

#### Issue 2: llguidance Compilation Fails

**Error**: `error: failed to run custom build command for 'llguidance'`

**Root Cause**: Missing Rust compiler needed for llguidance source compilation.

**Solution**: Install Rust in the Modal container image:
```python
.run_commands(
    "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y",
    "echo 'source $HOME/.cargo/env' >> $HOME/.bashrc",
)
```

Also requires system dependencies:
```python
.apt_install("build-essential", "pkg-config", "libssl-dev")
```

#### Issue 3: CUDA Version Mismatch

**Error**: `CUDA error: no kernel image is available for execution`

**Root Cause**: Incompatible CUDA version for vLLM/flashinfer kernels.

**Solution**: Use CUDA 12.4.1 specifically:
```python
modal.Image.from_registry(
    "nvidia/cuda:12.4.1-devel-ubuntu22.04",  # Proven stable
    add_python="3.12"
)
```

Avoid CUDA 12.6+ which can cause kernel compilation issues.

#### Issue 4: First Request Takes Too Long (3-5 Minutes)

**Symptom**: First generation request times out or takes several minutes.

**Root Cause**: Model download from HuggingFace (Qwen2.5-Coder-32B is ~60GB).

**Solutions**:
1. **Use persistent volumes** (already configured):
   ```python
   volumes={
       "/cache": modal.Volume.from_name("ananke-model-cache", create_if_missing=True),
   }
   ```
2. **Increase timeout** for first request:
   ```python
   timeout=3600  # 1 hour for first-time download
   ```
3. **Pre-warm the cache**: Run test generation after deployment to download model.

#### Issue 5: pip vs uv Installation Performance

**Symptom**: Slow container image builds (10+ minutes for dependency installation).

**Root Cause**: Using `pip_install` instead of `uv_pip_install`.

**Solution**: Use Modal's uv-based installer for 5-10x faster builds:
```python
# SLOW (traditional pip)
.pip_install("vllm==0.11.0", "transformers==4.55.2")

# FAST (uv-based pip)
.uv_pip_install("vllm==0.11.0", "transformers==4.55.2")
```

This reduced our image build time from ~15 minutes to ~3 minutes.

#### Issue 6: Environment Variable Not Recognized

**Symptom**: `MODAL_MODE` environment variable not affecting scaledown window.

**Root Cause**: Environment variable must be set before Python imports the module.

**Solution**:
```bash
# CORRECT: Set before modal command
MODAL_MODE=demo modal deploy inference.py

# WRONG: Export doesn't work with modal CLI in all shells
export MODAL_MODE=demo
modal deploy inference.py
```

### Performance Troubleshooting

#### Slow Generation (< 10 tokens/sec)

Check these factors:
1. **GPU utilization**: Should be 70-90% during generation
2. **Temperature settings**: Lower temperature = faster (less sampling)
3. **Max tokens**: Smaller max_tokens = faster completion
4. **Constraint complexity**: Complex JSON schemas add overhead

Expected throughput: 20-30 tokens/sec for Qwen2.5-Coder-32B on A100-80GB.

#### Container Cold Starts

**Expected**:
- First cold start (model download): 10-15 minutes
- Subsequent cold starts (cached model): 30-60 seconds
- Warm starts: < 100ms

**If slower**:
1. Check Modal volume is properly attached
2. Verify model is cached in `/cache/models`
3. Check Modal logs for download errors

### Deployment Troubleshooting

#### Authentication Issues

```bash
# Re-authenticate
modal token new

# Verify authentication
modal token list

# Check current profile
modal profile current
```

#### Deployment Fails

```bash
# Check logs for errors
modal app logs ananke-inference

# Stop existing deployment
modal app stop ananke-inference

# Redeploy
modal deploy inference.py
```

#### Request Timeouts

```bash
# Check if container is running
modal app list

# View live logs
modal app logs ananke-inference --follow

# Test health endpoint
curl https://your-username--ananke-inference-health.modal.run
```

Common timeout causes:
1. First request downloading model (expected, 10-15 min)
2. max_tokens too high (reduce to 1024-2048)
3. Container scaling up (wait 30-60 seconds)
4. Network issues (check Modal status page)

## Security

- Set `require_api_key: true` in config.yaml for production
- Use environment variables for sensitive data
- Consider rate limiting for public endpoints
- Review Modal security best practices

## Lessons Learned

This section documents critical insights from the deployment process to help future developers avoid common pitfalls.

### 1. vLLM 0.11.0 API Changes

**Issue**: The V1 structured outputs API changed parameter names between vLLM versions.

**Key Learning**:
```python
# vLLM 0.10.x (OLD)
StructuredOutputsParams(json_schema=schema)

# vLLM 0.11.0 (CURRENT - use this!)
StructuredOutputsParams(json=schema)  # Note: 'json' not 'json_schema'
```

**Impact**: This caused a day of debugging. The parameter name change wasn't prominently documented.

**Prevention**: Always check the actual source code for API parameter names, not just high-level docs.

### 2. Rust Compiler is Required for llguidance

**Issue**: llguidance must be compiled from source (no pre-built wheels for CUDA environments).

**Key Learning**: Include Rust installation in the Modal image:
```python
.run_commands(
    "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y",
)
```

Plus system dependencies:
```python
.apt_install("build-essential", "pkg-config", "libssl-dev")
```

**Impact**: Without these, llguidance installation fails silently or with cryptic errors.

**Prevention**: Start from a proven working configuration (like our maze example) rather than minimal setups.

### 3. CUDA 12.4.1 is the Proven Stable Version

**Issue**: Newer CUDA versions (12.6+) can cause kernel compilation failures with vLLM/flashinfer.

**Key Learning**: Use the NVIDIA CUDA development image with Python:
```python
modal.Image.from_registry(
    "nvidia/cuda:12.4.1-devel-ubuntu22.04",  # Specific version
    add_python="3.12"
)
```

**Impact**: Wrong CUDA version leads to runtime errors that are hard to debug.

**Prevention**: Pin exact CUDA versions that are proven to work. Don't use "latest".

### 4. Environment-Based Cost Controls Save Money

**Issue**: Different usage patterns need different scaledown windows.

**Key Learning**: Implement mode-based configuration:
```python
MODAL_MODE = os.getenv("MODAL_MODE", "dev").lower()
if MODAL_MODE == "demo":
    SCALEDOWN_WINDOW = 600  # 10 min
elif MODAL_MODE == "prod":
    SCALEDOWN_WINDOW = 300  # 5 min
else:
    SCALEDOWN_WINDOW = 120  # 2 min (dev)
```

**Impact**:
- Dev mode: ~$5-20/month
- Demo mode: Reduces interruptions during presentations
- Prod mode: Balanced cost/performance

**Prevention**: Plan for different usage patterns from day one.

### 5. System Dependencies Matter

**Issue**: Missing system packages cause subtle build failures.

**Key Learning**: Install these system dependencies for vLLM + llguidance:
```python
.apt_install(
    "git",           # For source checkouts
    "wget", "curl",  # For downloads
    "build-essential",  # C/C++ compilers
    "pkg-config",    # For library detection
    "libssl-dev",    # For Rust crypto
)
```

**Impact**: Without these, builds fail with non-obvious errors.

**Prevention**: Use a comprehensive base image and document all dependencies.

### 6. uv_pip_install is 5-10x Faster Than pip_install

**Issue**: Container builds took 15+ minutes with traditional pip.

**Key Learning**: Use Modal's uv-based installer:
```python
# SLOW
.pip_install("vllm==0.11.0")

# FAST (5-10x faster)
.uv_pip_install("vllm==0.11.0")
```

**Impact**: Reduced build time from ~15 minutes to ~3 minutes.

**Prevention**: Always use `uv_pip_install` for Modal images.

### 7. First-Time Model Download Needs Long Timeout

**Issue**: Qwen2.5-Coder-32B is ~60GB and takes 10-15 minutes to download.

**Key Learning**: Set generous timeout for first request:
```python
timeout=3600,  # 1 hour for first-time download
```

Use persistent volumes:
```python
volumes={
    "/cache": modal.Volume.from_name("ananke-model-cache", create_if_missing=True),
}
```

**Impact**: Without this, first requests time out and fail.

**Prevention**: Document cold start expectations and use volumes for caching.

### 8. Start From Proven Working Configuration

**Issue**: Building from scratch led to days of debugging.

**Key Learning**: We based this on `/Users/rand/src/maze/deployment/modal/modal_app.py` which had a proven working configuration.

**Impact**: Once we matched that configuration exactly, everything worked.

**Prevention**:
1. Don't reinvent the wheel
2. Copy working configs and modify incrementally
3. Document what works and why

### 9. Version Pinning is Critical

**Issue**: Dependency version mismatches caused crashes.

**Key Learning**: Pin exact versions:
```python
VLLM_VERSION = "0.11.0"
TRANSFORMERS_VERSION = "4.55.2"
FASTAPI_VERSION = "0.115.12"
```

llguidance version range:
```python
llguidance>=0.7.11,<0.8.0  # vLLM 0.11.0 requires <0.8.0
```

**Impact**: Unpinned versions led to incompatibility errors.

**Prevention**: Pin versions in production, document compatibility requirements.

### 10. Modal Class Methods Handle Lifecycle Automatically

**Issue**: Initially tried to initialize vLLM in the web endpoint function.

**Key Learning**: Use Modal's class pattern with `@modal.enter()`:
```python
@app.cls(gpu=GPU_CONFIG, ...)
class AnankeLLM:
    @modal.enter()
    def initialize_model(self):
        self.llm = LLM(...)  # Initialized once per container

    @modal.method()
    def generate(self, ...):
        return self.llm.generate(...)  # Reuses initialized model

# Web endpoint just forwards
@app.function(...)
def generate_api(request):
    llm = AnankeLLM()
    return llm.generate.remote(request)  # Modal handles lifecycle
```

**Impact**: This pattern enables model caching and proper GPU resource management.

**Prevention**: Follow Modal's documented patterns for stateful services.

## Configuration Reference

The service configuration is defined in `inference.py`:

- **Model**: Line 186 - `model_name = "Qwen/Qwen2.5-Coder-32B-Instruct"`
- **GPU**: Line 32 - `GPU_CONFIG = "A100-80GB"`
- **Environment modes**: Lines 35-48 - `MODAL_MODE` handling
- **Versions**: Lines 51-53 - Pinned dependency versions
- **Image setup**: Lines 57-108 - CUDA, Rust, dependencies
- **Container config**: Lines 161-177 - Timeouts, scaling, volumes

To customize, edit these sections and redeploy.

## Support

For issues specific to Modal deployment:
- Check Modal service health first
- Review Modal documentation: https://modal.com/docs
- Check service logs: `modal app logs ananke-inference`
- Modal status page: https://status.modal.com

For Ananke integration issues:
- See main repository documentation
- Check Rust Maze orchestration layer
- Verify constraint IR format

For vLLM/llguidance issues:
- vLLM docs: https://docs.vllm.ai
- llguidance: https://github.com/guidance-ai/llguidance

## Related Documentation

- `/Users/rand/src/ananke/maze/modal_inference/DEPLOYMENT_REPORT.md` - Original deployment notes
- `/Users/rand/src/ananke/maze/modal_inference/BUG_FIX_REPORT.md` - Issues encountered and fixed
- `/Users/rand/src/ananke/maze/modal_inference/inference.py` - Main service implementation
- `/Users/rand/src/maze/deployment/modal/modal_app.py` - Proven working configuration we based this on

## License

MIT OR Apache-2.0
