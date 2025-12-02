# Modal Integration Notes

## Critical Issue: Endpoint Mismatch

### Problem

The `modal_client.zig` and `inference_service.py` have incompatible endpoint structures:

**modal_client.zig expects:**
- Single base URL with `/generate_api` endpoint
- Request format: `{prompt, max_tokens, temperature, top_p, constraints (optional)}`
- Response format: `{generated_text}`

**inference_service.py provides:**
- Two separate Modal web endpoint functions
  - `generate_constrained_endpoint`
  - `generate_unconstrained_endpoint`
- Request format: `{prompt, constraints, model (optional)}` for constrained
- Request format: `{prompt, few_shot_examples, model (optional)}` for unconstrained
- Response format: `{code, metadata: {tokens_used, generation_time_ms, model}}`

### Modal Web Endpoint URLs

Modal web endpoints follow this pattern:
```
https://<username>--<app-name>-<function-name>.modal.run
```

For the deployed `ananke-inference` app (ID: ap-S2QkwxrmOOS94bGU5tnxaa):
- Constrained: `https://<username>--ananke-inference-generate-constrained-endpoint.modal.run`
- Unconstrained: `https://<username>--ananke-inference-generate-unconstrained-endpoint.modal.run`

### Solution Options

#### Option A: Update modal_client.zig (RECOMMENDED)

Modify `eval/core/modal_client.zig` to:
1. Accept two separate endpoint URLs (constrained and unconstrained)
2. Match request format expected by `inference_service.py`
3. Parse response format returned by `inference_service.py`

**Changes needed:**
- Add separate URLs for constrained/unconstrained endpoints
- Update request JSON to include `constraints` object instead of embedding them
- Update response parsing to extract `code` from `{code, metadata}` instead of `generated_text`
- Pass `few_shot_examples` for unconstrained generation

#### Option B: Redeploy Modal Service

Modify `eval/modal/inference_service.py` to:
1. Create a unified `/generate_api` endpoint
2. Accept the format expected by `modal_client.zig`
3. Return `generated_text` in response

**Not recommended** because:
- Requires redeployment
- Current Modal service API is well-designed
- Breaking change to existing deployment

### Recommended Fix

Update `modal_client.zig` to match the deployed Modal service.

**Required changes:**

1. **ModalClient struct:**
```zig
pub const ModalClient = struct {
    allocator: Allocator,
    constrained_endpoint: []const u8,   // Full URL to constrained endpoint
    unconstrained_endpoint: []const u8, // Full URL to unconstrained endpoint
    timeout_ms: u32,
};
```

2. **generateConstrained method:**
```zig
// Request format: {prompt, constraints, model (optional)}
// Response format: {code, metadata: {...}}

// Build request
{
  "prompt": "<task description>",
  "constraints": {<constraints JSON object>},
  "model": "Qwen/Qwen2.5-Coder-32B-Instruct" (optional)
}

// Parse response
const code = result_obj.get("code").?.string;
const metadata = result_obj.get("metadata").?.object;
const tokens_used = metadata.get("tokens_used").?.integer;
const generation_time_ms = metadata.get("generation_time_ms").?.integer;
```

3. **generateUnconstrained method:**
```zig
// Request format: {prompt, few_shot_examples, model (optional)}
// Response format: {code, metadata: {...}}

// Build request
{
  "prompt": "<task description>",
  "few_shot_examples": [{prompt: "...", code: "..."}, ...],
  "model": "Qwen/Qwen2.5-Coder-32B-Instruct" (optional)
}
```

4. **Evaluator integration:**

Update `eval/core/evaluator.zig` to pass separate URLs:
```zig
pub fn init(allocator: Allocator, constrained_url: []const u8, unconstrained_url: []const u8) Evaluator {
    return .{
        .allocator = allocator,
        .baseline_generator = baseline.BaselineGenerator.init(allocator, unconstrained_url),
        .modal_client = modal_client.ModalClient.init(allocator, constrained_url, unconstrained_url),
        // ...
    };
}
```

5. **CLI integration:**

Update `eval/main.zig` to accept both endpoint URLs:
```bash
./zig-out/bin/ananke-eval run \
  --constrained-endpoint https://...--ananke-inference-generate-constrained-endpoint.modal.run \
  --unconstrained-endpoint https://...--ananke-inference-generate-unconstrained-endpoint.modal.run \
  --tasks algo_001_binary_search
```

Or use a base URL and construct the endpoint URLs:
```bash
./zig-out/bin/ananke-eval run \
  --modal-base-url https://...--ananke-inference \
  --tasks algo_001_binary_search

# Internally constructs:
# constrained: {base_url}-generate-constrained-endpoint.modal.run
# unconstrained: {base_url}-generate-unconstrained-endpoint.modal.run
```

### Getting Actual Endpoint URLs

To get the deployed endpoint URLs:

```bash
# Option 1: Modal dashboard
# Visit https://modal.com/apps and click on ananke-inference

# Option 2: Modal CLI (after deployment)
modal deploy eval/modal/inference_service.py
# Output will show:
# ✓ Created web function generate_constrained_endpoint => https://...
# ✓ Created web function generate_unconstrained_endpoint => https://...

# Option 3: Check logs
modal app logs ananke-inference | grep "https://"
```

### Testing the Fix

After updating modal_client.zig:

1. **Unit test with curl:**
```bash
# Test constrained endpoint
curl -X POST https://...--ananke-inference-generate-constrained-endpoint.modal.run \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Implement a function that returns the sum of two numbers",
    "constraints": {
      "grammar": "function add(a: number, b: number): number"
    }
  }'

# Expected response:
# {"code": "function add(a: number, b: number): number {\n  return a + b;\n}", "metadata": {...}}
```

2. **Integration test:**
```bash
# Build with updated modal_client
zig build

# Run single task evaluation
./zig-out/bin/ananke-eval run \
  --constrained-endpoint https://... \
  --unconstrained-endpoint https://... \
  --tasks algo_001_binary_search \
  --output /tmp/eval_test
```

### Status

- [x] Identified endpoint mismatch
- [ ] Get actual deployed endpoint URLs from Modal
- [ ] Update modal_client.zig with correct endpoints and request/response format
- [ ] Update evaluator.zig to pass separate endpoint URLs
- [ ] Update baseline/generator.zig to use unconstrained endpoint
- [ ] Update main.zig CLI to accept endpoint URLs
- [ ] Test with curl
- [ ] Run integration test with single task
- [ ] Run full pilot evaluation

### Notes

- The inference_service.py is well-designed and shouldn't be changed
- Modal web endpoints are stateless HTTP endpoints that can be called directly
- Each endpoint spins up a container with the vLLM model on demand
- Containers auto-scale to zero after 5 minutes of inactivity
- Model weights are cached in Modal volume for fast cold starts
