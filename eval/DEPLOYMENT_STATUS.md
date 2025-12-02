# Modal Inference Service Deployment Status

**Date**: 2025-12-01 (Updated)
**Status**: DEPLOYED - INITIALIZATION WORKING, STABILITY ISSUE IDENTIFIED

## Summary

The Modal inference service has been fixed and redeployed using the working `maze/modal_inference/inference.py` pattern. The model loads and initializes correctly, but there's a stability issue where the engine core dies after the first request.

## What Was Fixed

### Key Changes from Broken to Working Configuration

| Issue | Broken Config | Fixed Config |
|-------|---------------|--------------|
| vLLM Version | 0.11.2 | **0.11.0** (matches maze) |
| llguidance | >=0.7.30 | **>=0.7.11,<0.8.0** |
| Base Image | `debian_slim` | **`nvidia/cuda:12.4.1-devel-ubuntu22.04`** |
| Rust Compiler | Missing | **Installed** (required for llguidance) |
| API Pattern | `guided_decoding_backend="llguidance"` | **`structured_outputs_config={"backend": "guidance"}`** |
| Endpoint Decorator | `@modal.web_endpoint` (deprecated) | **`@modal.fastapi_endpoint`** |
| Package Manager | `.pip_install()` | **`.uv_pip_install()`** |
| GPU | A100-40GB | **A100-80GB** |
| Volumes | 1 cache volume | **2 volumes** (model + torch cache) |

### Deployment Details

- **App ID**: `ap-rQFcknkndA06saRlO1qo0L`
- **App Name**: `ananke-eval-inference`
- **Status**: deployed
- **Deployment Time**: 1.834s

### Endpoint URLs

- **Health**: `https://<YOUR_MODAL_WORKSPACE>--ananke-eval-inference-health.modal.run`
- **Constrained**: `https://<YOUR_MODAL_WORKSPACE>--ananke-eval-inference-generate-constrained-endpoint.modal.run`
- **Unconstrained**: `https://<YOUR_MODAL_WORKSPACE>--ananke-eval-inference-generate-unconstrained-endpoint.modal.run`

## Current Status

### Working

1. **Deployment**: Service deploys successfully
2. **Health Check**: Returns `{"status": "healthy", "service": "ananke-eval-inference", "version": "2.0.0"}`
3. **Model Loading**: Qwen2.5-Coder-32B-Instruct loads in ~42 seconds
4. **Model Size**: 61.0355 GiB loaded to GPU
5. **CUDA Graphs**: Captured successfully (67 prefill-decode, 35 decode)
6. **First Request**: Processes successfully (~54 tok/s input, ~22 tok/s output)
7. **Structured Outputs**: V1 API with llguidance backend initialized correctly

### Issue: Engine Core Instability

**Symptom**: After processing the first request, the engine core dies unexpectedly:
```
ERROR 12-01 23:08:02 [core_client.py:564] Engine core proc EngineCore_DP0 died unexpectedly, shutting down client.
```

**Likely Causes**:
1. **Memory pressure**: 32B model (61 GiB) + KV cache (8.6 GiB) + CUDA graphs (1.3 GiB) leaves minimal headroom on A100-80GB
2. **Timeout issues**: Modal's internal timeouts may be triggering before response returns
3. **Container lifecycle**: Request may be timing out and triggering container restart

**Evidence**:
- Model loads and first request processes (logs show tokens generated)
- Container restarts after the crash (new CUDA banner appears in logs)
- Health endpoint continues working (lightweight, no GPU)

## Recommended Next Steps

### Immediate (Fix Stability)

1. **Option A: Reduce Model Size**
   - Use `Qwen/Qwen2.5-Coder-7B-Instruct` instead of 32B
   - Will fit easily in A100-80GB with ample headroom
   - Trade-off: Lower quality generation

2. **Option B: Increase GPU Memory**
   - Use `H100` GPU (80GB, faster memory bandwidth)
   - More expensive but handles 32B model better

3. **Option C: Disable CUDA Graphs**
   - Add `use_cudagraph=False` to reduce memory usage
   - Trade-off: Slightly slower inference

### Short-Term

4. **Add Request Timeout Handling**
   - Increase HTTP timeout on client side
   - Add retry logic for cold starts

5. **Pre-warm Container**
   - Send a warmup request after deployment
   - Keep container warm during testing

## Configuration Reference

### Current inference_service.py Settings
```python
MODEL_NAME = "Qwen/Qwen2.5-Coder-32B-Instruct"
GPU_CONFIG = "A100-80GB"
VLLM_VERSION = "0.11.0"

LLM(
    model=MODEL_NAME,
    tensor_parallel_size=1,
    gpu_memory_utilization=0.90,
    max_model_len=8192,
    dtype="bfloat16",
    structured_outputs_config={"backend": "guidance"},
)
```

### Working maze/modal_inference/inference.py Reference
The working configuration in `maze/modal_inference/inference.py` uses identical settings and successfully handles requests. The key difference may be in request patterns or container lifecycle.

## Test Commands

```bash
# Health check
curl https://<YOUR_MODAL_WORKSPACE>--ananke-eval-inference-health.modal.run

# Constrained generation (may need extended timeout)
curl --max-time 600 -X POST \
  https://<YOUR_MODAL_WORKSPACE>--ananke-eval-inference-generate-constrained-endpoint.modal.run \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Add two numbers", "constraints": {"grammar": "function add(a: number, b: number): number"}}'

# Check logs
modal app logs ananke-eval-inference
```

## Timeline

- **23:00 UTC**: Fixed configuration deployed
- **23:01 UTC**: Container started, model loading began
- **23:05 UTC**: Model loaded, CUDA graphs captured
- **23:06 UTC**: First request processed successfully
- **23:08 UTC**: Engine core died after first request
- **23:09 UTC**: Container restarted, model reloading

## Files Modified

- `eval/modal/inference_service.py` - Complete rewrite using maze pattern
- `eval/DEPLOYMENT_STATUS.md` - This file (updated)
