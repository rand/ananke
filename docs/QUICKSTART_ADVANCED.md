# Ananke Advanced Quickstart

**Audience**: Developers ready to deploy Ananke in production  
**Time**: 30-45 minutes  
**Prerequisites**: Basic quickstart completed

## Overview

This guide covers:
1. Modal deployment and configuration
2. Environment setup for production
3. API key management and security
4. Performance tuning and optimization
5. Debugging techniques
6. Cost optimization strategies

---

## 1. Modal Deployment

### Prerequisites

```bash
# Install Modal
pip install modal

# Configure Modal account
modal setup

# Verify installation
modal --version
```

### Deploy Inference Service

**Step 1**: Create Modal app structure
```bash
mkdir -p modal_service
cd modal_service
```

**Step 2**: Create `app.py`:
```python
import modal

app = modal.App("ananke-inference")

# GPU configuration
gpu_config = modal.gpu.A100(count=1, memory=40)

# Model configuration
model_name = "deepseek-ai/DeepSeek-Coder-V2-Lite-Instruct"

@app.function(
    gpu=gpu_config,
    timeout=300,  # 5 minutes
    container_idle_timeout=60,  # Scale to zero after 60s
    image=modal.Image.debian_slim()
        .pip_install(
            "vllm==0.11.0",
            "llguidance==0.7.11",
            "transformers",
            "torch",
        ),
)
def inference_endpoint(
    prompt: str,
    constraints: dict,
    max_tokens: int = 2048,
    temperature: float = 0.7,
):
    from vllm import LLM, SamplingParams
    from llguidance import LLGuidance
    
    # Initialize model (cached across requests)
    llm = LLM(model=model_name, gpu_memory_utilization=0.9)
    
    # Apply constraints
    guidance = LLGuidance(constraints)
    
    # Generate with constraints
    sampling_params = SamplingParams(
        temperature=temperature,
        max_tokens=max_tokens,
        logits_processor=[guidance.logits_processor],
    )
    
    outputs = llm.generate([prompt], sampling_params)
    
    return {
        "generated_text": outputs[0].outputs[0].text,
        "tokens_generated": len(outputs[0].outputs[0].token_ids),
        "model": model_name,
        "stats": {
            "total_time_ms": outputs[0].metrics.total_time * 1000,
        }
    }

@app.function()
@modal.web_endpoint(method="POST")
def generate(request: dict):
    """Public endpoint for constrained generation"""
    result = inference_endpoint.remote(
        prompt=request["prompt"],
        constraints=request["constraints"],
        max_tokens=request.get("max_tokens", 2048),
        temperature=request.get("temperature", 0.7),
    )
    return result

@app.function()
@modal.web_endpoint(method="GET")
def health():
    """Health check endpoint"""
    return {"status": "healthy", "model": model_name}
```

**Step 3**: Deploy to Modal
```bash
# Deploy the app
modal deploy app.py

# Output:
# ✓ Created app ananke-inference
# ✓ View app at https://modal.com/apps/your-app
# 
# Endpoints:
#   - https://your-app--generate.modal.run (POST /generate)
#   - https://your-app--health.modal.run (GET /health)
```

**Step 4**: Test deployment
```bash
# Health check
curl https://your-app--health.modal.run

# Test generation
curl -X POST https://your-app--generate.modal.run \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Implement user authentication",
    "constraints": {},
    "max_tokens": 512,
    "temperature": 0.7
  }'
```

### Deployment Options

**Scale-to-Zero (Default)**:
- **Cost**: Pay only for active GPU time (~$0.01/1000 tokens)
- **Latency**: 60s cold start on first request
- **Use Case**: Infrequent use, cost-sensitive

```python
@app.function(
    container_idle_timeout=60,  # Shut down after 60s idle
    keep_warm=0,  # No warm instances
)
```

**Keep-Warm (Production)**:
- **Cost**: Fixed hourly rate + usage (~$2-3/hour)
- **Latency**: <100ms (no cold starts)
- **Use Case**: Production, frequent requests

```python
@app.function(
    container_idle_timeout=300,  # 5 minutes idle timeout
    keep_warm=1,  # Keep 1 instance always running
)
```

**Auto-Scaling (High Traffic)**:
- **Cost**: Scales with demand
- **Latency**: Variable (cold starts under load)
- **Use Case**: Variable traffic, high availability

```python
@app.function(
    container_idle_timeout=120,
    keep_warm=1,
    concurrency_limit=10,  # Max 10 concurrent requests per instance
)
```

---

## 2. Environment Setup

### Development Environment

```bash
# Create .env file
cat > .env << 'ENV'
# Modal Configuration
MODAL_ENDPOINT=https://your-app--generate.modal.run
MODAL_API_KEY=  # Optional, for authenticated endpoints
MODAL_MODEL=deepseek-ai/DeepSeek-Coder-V2-Lite-Instruct

# Claude Configuration (optional)
ANTHROPIC_API_KEY=sk-ant-...
ANTHROPIC_MODEL=claude-sonnet-4

# Ananke Configuration
ANANKE_CACHE_SIZE=1000
ANANKE_TIMEOUT_SECS=300
ANANKE_LOG_LEVEL=info
ENV

# Load environment
source .env
# Or use direnv: echo "dotenv" > .envrc && direnv allow
```

### Production Environment

**Docker Deployment**:
```dockerfile
# Dockerfile
FROM debian:bookworm-slim

# Install Zig 0.15.2
RUN wget https://ziglang.org/download/0.15.2/zig-linux-x86_64-0.15.2.tar.xz \
    && tar -xf zig-linux-x86_64-0.15.2.tar.xz \
    && mv zig-linux-x86_64-0.15.2 /opt/zig \
    && ln -s /opt/zig/zig /usr/local/bin/zig

# Install Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# Copy Ananke source
WORKDIR /app
COPY . .

# Build
RUN zig build -Doptimize=ReleaseFast
RUN cd maze && cargo build --release

# Runtime environment
ENV MODAL_ENDPOINT=${MODAL_ENDPOINT}
ENV MODAL_API_KEY=${MODAL_API_KEY}

CMD ["/app/zig-out/bin/ananke"]
```

**Kubernetes Deployment**:
```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ananke-service
spec:
  replicas: 3
  selector:
    matchLabels:
      app: ananke
  template:
    metadata:
      labels:
        app: ananke
    spec:
      containers:
      - name: ananke
        image: your-registry/ananke:latest
        env:
        - name: MODAL_ENDPOINT
          valueFrom:
            secretKeyRef:
              name: ananke-secrets
              key: modal-endpoint
        - name: ANTHROPIC_API_KEY
          valueFrom:
            secretKeyRef:
              name: ananke-secrets
              key: anthropic-key
        resources:
          requests:
            memory: "2Gi"
            cpu: "1000m"
          limits:
            memory: "4Gi"
            cpu: "2000m"
```

---

## 3. API Key Management

### Secure Storage

**DO NOT**:
- Commit API keys to version control
- Share keys in plain text
- Use production keys for development

**DO**:
- Use environment variables
- Rotate keys regularly (every 90 days)
- Use separate keys for dev/staging/prod

### Key Rotation

```bash
# 1. Generate new Claude API key
# Go to https://console.anthropic.com/settings/keys

# 2. Update environment
export ANTHROPIC_API_KEY_NEW='sk-ant-new-key'

# 3. Test new key
curl https://api.anthropic.com/v1/messages \
  -H "x-api-key: $ANTHROPIC_API_KEY_NEW" \
  -H "anthropic-version: 2024-01-01" \
  -d '{"model":"claude-sonnet-4","messages":[{"role":"user","content":"test"}]}'

# 4. Update production (zero-downtime)
kubectl set env deployment/ananke-service \
  ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY_NEW

# 5. Revoke old key after 24 hours
```

### Secrets Management

**AWS Secrets Manager**:
```bash
# Store secret
aws secretsmanager create-secret \
  --name ananke/anthropic-api-key \
  --secret-string "$ANTHROPIC_API_KEY"

# Retrieve in application
aws secretsmanager get-secret-value \
  --secret-id ananke/anthropic-api-key \
  --query SecretString \
  --output text
```

**HashiCorp Vault**:
```bash
# Store secret
vault kv put secret/ananke/api-keys \
  anthropic="$ANTHROPIC_API_KEY" \
  modal="$MODAL_API_KEY"

# Retrieve
vault kv get -field=anthropic secret/ananke/api-keys
```

---

## 4. Performance Tuning

### Zig Optimization

**Build Flags**:
```bash
# Release builds (production)
zig build -Doptimize=ReleaseFast  # Fastest, larger binary
zig build -Doptimize=ReleaseSmall  # Smaller binary, slightly slower
zig build -Doptimize=ReleaseSafe  # Includes safety checks

# Benchmarking
zig build -Doptimize=ReleaseFast test
# Performance: Extract=4ms → 2ms (2x speedup)
```

**CPU-Specific Optimization**:
```bash
# Target specific CPU for maximum performance
zig build -Doptimize=ReleaseFast \
  -Dcpu=native  # Use all available CPU features

# Example gains:
# - SIMD instructions for pattern matching
# - Better branch prediction
# - Improved cache utilization
```

### Rust Optimization

**Cargo Configuration** (`maze/Cargo.toml`):
```toml
[profile.release]
opt-level = 3          # Maximum optimization
lto = "fat"           # Link-time optimization
codegen-units = 1      # Better optimization (slower compile)
panic = "abort"        # Smaller binary
strip = true           # Remove debug symbols

[profile.release-with-debug]
inherits = "release"
debug = true          # Keep debug info for profiling
```

**Build Command**:
```bash
cd maze
cargo build --release
# Binary: target/release/maze (optimized)

# Profile-guided optimization (advanced)
cargo pgo build
cargo pgo test
cargo pgo optimize
```

### Cache Tuning

**Adjust Cache Size**:
```rust
// maze/src/lib.rs
let config = MazeConfig {
    enable_cache: true,
    cache_size_limit: 5000,  // Increase from default 1000
    ...
};
```

**Cache Hit Rate Monitoring**:
```rust
// Check cache effectiveness
let stats = orchestrator.cache_stats().await;
println!("Cache: {}/{} ({}% hit rate)",
    stats.size,
    stats.limit,
    (stats.size as f32 / stats.limit as f32) * 100.0
);

// If hit rate < 50%, consider increasing cache size
```

**Cache Warm-up**:
```rust
// Pre-populate cache with common constraint sets
let common_constraints = load_common_constraints();
for constraint_set in common_constraints {
    orchestrator.compile_constraints(&constraint_set).await?;
}
```

### Network Optimization

**Connection Pooling**:
```rust
// Currently: New connection per request
// Future (Phase 9): Connection pool

// Workaround: Keep Modal service warm
tokio::spawn(async move {
    loop {
        let _ = modal_client.health_check().await;
        tokio::time::sleep(Duration::from_secs(30)).await;
    }
});
```

**Regional Deployment**:
```python
# Deploy Modal in same region as your application
# AWS: us-east-1, us-west-2, eu-west-1
# Reduces network latency from 100ms → 10ms
```

---

## 5. Debugging Techniques

### Enable Debug Logging

**Zig Side**:
```bash
# Build with debug symbols
zig build -Doptimize=Debug test

# Run with logging
ANANKE_LOG_LEVEL=debug zig build test
```

**Rust Side**:
```bash
# Enable logging
export RUST_LOG=maze=debug,info

# Run tests with logging
cd maze && cargo test -- --nocapture
```

### Profiling

**CPU Profiling (Linux)**:
```bash
# Record execution
perf record -g zig build test

# Analyze results
perf report
# Shows hotspots: pattern matching, graph construction, etc.
```

**Memory Profiling (macOS)**:
```bash
# Use Instruments (requires Xcode)
instruments -t Allocations zig-out/bin/test_runner

# Or use heaptrack on Linux
heaptrack zig-out/bin/test_runner
heaptrack --analyze heaptrack.test_runner.*.gz
```

### Trace Debugging

**Add Instrumentation**:
```zig
// In src/clew/clew.zig
pub fn extractFromCode(self: *Clew, source: []const u8, language: []const u8) !ConstraintSet {
    const start = std.time.milliTimestamp();
    defer {
        const elapsed = std.time.milliTimestamp() - start;
        std.debug.print("Extraction took {}ms\n", .{elapsed});
    }
    
    // ... rest of function
}
```

**Conditional Breakpoints** (GDB):
```bash
# Build with debug info
zig build -Doptimize=Debug

# Run in debugger
gdb zig-out/bin/test_runner

# Set conditional breakpoint
break clew.zig:100 if constraint_count > 100
run
```

---

## 6. Cost Optimization

### Modal Costs

**Pricing Model**:
- GPU time: ~$2-3/hour (A100 40GB)
- Idle time: ~$0.10/hour (keep-warm instances)
- Network: Free (egress <100GB/month)

**Cost Calculation**:
```python
# Example usage
requests_per_day = 1000
avg_tokens_per_request = 1500
avg_generation_time_sec = 1.5

# Daily GPU seconds
gpu_seconds_per_day = requests_per_day * avg_generation_time_sec
gpu_hours_per_day = gpu_seconds_per_day / 3600

# Daily cost
daily_cost = gpu_hours_per_day * 2.5  # $2.50/hour
monthly_cost = daily_cost * 30

print(f"Monthly Modal cost: ${monthly_cost:.2f}")
# Output: Monthly Modal cost: $31.25
```

**Optimization Strategies**:

1. **Reduce Token Generation**:
```rust
// Generate only what's needed
let request = GenerationRequest {
    max_tokens: 512,  // Instead of 2048
    ...
};
```

2. **Batch Requests**:
```rust
// Process multiple prompts together
let requests = vec![req1, req2, req3];
let results = client.generate_batch(requests).await?;
// Saves on cold start costs
```

3. **Use Smaller Models**:
```python
# In Modal app.py
model_name = "meta-llama/Llama-3.1-8B-Instruct"  # Instead of 70B
# 3-4x cheaper, acceptable quality for many use cases
```

4. **Implement Request Throttling**:
```rust
use governor::{Quota, RateLimiter};

// Limit to 10 requests per second
let limiter = RateLimiter::direct(Quota::per_second(
    NonZeroU32::new(10).unwrap()
));

// Before each request
limiter.until_ready().await;
let result = orchestrator.generate(request).await?;
```

### Claude API Costs

**Pricing** (as of 2025):
- Claude Sonnet 4: $3/million input tokens, $15/million output tokens
- Typical semantic analysis: ~2K input, ~500 output tokens
- Cost per analysis: ~$0.015

**Optimization**:

1. **Cache Semantic Analysis**:
```zig
// In Clew, cache Claude results aggressively
const cache_key = try self.buildCacheKey(source, true);
if (self.cache.get(cache_key)) |cached| {
    return cached;  // Avoid Claude API call
}
```

2. **Use Batch API** (coming soon):
```python
# Process multiple files together
files = [file1, file2, file3]
results = claude.analyze_batch(files)
# 50% cheaper than individual requests
```

3. **Disable for Low-Value Code**:
```bash
# Only use Claude for critical files
if [ "$file_criticality" = "high" ]; then
    export ANTHROPIC_API_KEY=$KEY
else
    unset ANTHROPIC_API_KEY  # Fall back to pattern matching
fi
```

---

## 7. Production Checklist

### Pre-Deployment

- [ ] All tests passing (`zig build test`, `cargo test`)
- [ ] No memory leaks detected (GPA, Valgrind)
- [ ] Release build optimized (`-Doptimize=ReleaseFast`)
- [ ] Modal service deployed and tested
- [ ] API keys in secure storage (Vault, Secrets Manager)
- [ ] Environment variables configured
- [ ] Monitoring and logging configured
- [ ] Error alerting set up
- [ ] Cost monitoring enabled
- [ ] Backup and disaster recovery plan

### Post-Deployment

- [ ] Smoke tests passed
- [ ] Performance benchmarks met (see below)
- [ ] Cache hit rate >50%
- [ ] Modal cold starts <90s (scale-to-zero)
- [ ] End-to-end latency <2.5s (p95)
- [ ] Memory usage <500MB per instance
- [ ] No error rate spikes (should be <0.1%)
- [ ] Cost within budget

### Performance Targets

| Metric | Target (p95) | Alert Threshold |
|--------|--------------|-----------------|
| Extraction time | <10ms | >50ms |
| Compilation time | <5ms | >20ms |
| FFI conversion | <2ms | >10ms |
| Cache lookup | <1ms | >5ms |
| Modal API call | <2s | >5s |
| End-to-end latency | <2.5s | >10s |
| Memory usage | <500MB | >2GB |
| Error rate | <0.1% | >1% |

---

## 8. Advanced Examples

### Example 1: Custom Constraint Pipeline

```rust
use maze::{MazeOrchestrator, ModalConfig, GenerationRequest};
use anyhow::Result;

async fn custom_pipeline(source_code: &str) -> Result<String> {
    // 1. Extract constraints from Zig
    let constraints = extract_with_zig(source_code, "typescript")?;
    
    // 2. Add custom security constraints
    let mut all_constraints = constraints;
    all_constraints.push(security_constraint());
    
    // 3. Initialize orchestrator with custom config
    let config = ModalConfig::from_env()?
        .with_timeout(600);  // 10 minutes
    let orchestrator = MazeOrchestrator::new(config)?;
    
    // 4. Generate with all constraints
    let request = GenerationRequest {
        prompt: "Implement secure authentication".to_string(),
        constraints_ir: all_constraints,
        max_tokens: 2048,
        temperature: 0.5,  // Lower for more deterministic output
        context: Some(build_context()),
    };
    
    let result = orchestrator.generate(request).await?;
    
    // 5. Validate result
    assert!(result.validation.all_satisfied);
    assert!(result.metadata.tokens_generated > 0);
    
    Ok(result.code)
}
```

### Example 2: Constraint Merging from Multiple Sources

```zig
// Merge constraints from code, tests, and config
var code_constraints = try clew.extractFromCode(source, "rust");
var test_constraints = try clew.extractFromTests(test_source);
var config_constraints = try loadConstraintsFromJSON("constraints.json");

var merged = try mergeConstraints(
    allocator,
    code_constraints,
    test_constraints,
);
merged = try mergeConstraints(allocator, merged, config_constraints);

// Compile merged constraints
var braid = try Braid.init(allocator);
defer braid.deinit();
const ir = try braid.compile(merged.constraints.items);
```

---

## Reference Links

- **Main Documentation**: `/Users/rand/src/ananke/docs/`
- **Architecture**: `/Users/rand/src/ananke/docs/ARCHITECTURE_V2.md`
- **FFI Contract**: `/Users/rand/src/ananke/test/integration/FFI_CONTRACT.md`
- **Pattern Reference**: `/Users/rand/src/ananke/docs/PATTERN_REFERENCE.md`
- **Troubleshooting**: `/Users/rand/src/ananke/docs/TROUBLESHOOTING.md`

**Document Version**: 1.0  
**Maintained By**: Claude Code (docs-writer subagent)  
**Last Updated**: 2025-11-24
