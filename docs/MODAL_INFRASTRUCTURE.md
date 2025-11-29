# Modal Infrastructure Guide

Comprehensive guide to deploying and using Ananke with Modal for scalable constraint compilation.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Quick Start](#quick-start)
4. [Deployment](#deployment)
5. [Configuration](#configuration)
6. [Usage](#usage)
7. [Performance Tuning](#performance-tuning)
8. [Monitoring](#monitoring)
9. [Troubleshooting](#troubleshooting)
10. [Cost Optimization](#cost-optimization)

---

## Overview

**Modal** is a serverless compute platform that allows Ananke to:

- **Scale automatically**: Handle 1 to 10,000 requests without configuration
- **Pay per use**: Only pay for actual compute time
- **Deploy instantly**: No infrastructure management
- **Run anywhere**: Cloud-based, no local resources needed

### Architecture

```
┌─────────────┐
│ Ananke CLI  │
└──────┬──────┘
       │
       │ HTTPS Request
       ▼
┌──────────────────┐
│  Modal Gateway   │  ← API endpoint (modal.run)
└────────┬─────────┘
         │
         │ Routes to
         ▼
┌────────────────────┐
│  Modal Container   │  ← Serverless function
│  ┌──────────────┐  │
│  │ Ananke Core  │  │  ← Constraint compiler
│  │  + Braid     │  │
│  └──────────────┘  │
└────────────────────┘
         │
         │ Returns IR
         ▼
┌──────────────┐
│  Ananke CLI  │  ← Receives compiled IR
└──────────────┘
```

### Use Cases

| Use Case | Local Compilation | Modal Compilation |
|----------|-------------------|-------------------|
| **Development** | ✅ Fast, no network | ❌ Network latency |
| **CI/CD** | ⚠️ Requires Zig install | ✅ No dependencies |
| **Large projects** | ⚠️ Limited by local RAM | ✅ Scales automatically |
| **Team collaboration** | ❌ Version inconsistencies | ✅ Consistent environment |
| **Production** | ⚠️ Server maintenance | ✅ Zero maintenance |

---

## Prerequisites

### 1. Modal Account

Create a free Modal account:

```bash
# Sign up
modal setup

# Login
modal token new
```

**Free tier includes:**
- 30 free compute hours/month
- 10 GB storage
- Unlimited apps

### 2. API Key (Optional)

For production deployments, set up API authentication:

```bash
# Generate Modal API key
modal secret create ananke-api-key --value "your-secret-key"
```

### 3. Ananke Installation

```bash
# Install Ananke
curl -sSL https://ananke.run/install.sh | bash

# Verify installation
ananke --version
```

---

## Quick Start

### 1. Deploy to Modal

```bash
# Clone Ananke repository
git clone https://github.com/your-org/ananke
cd ananke

# Deploy to Modal
modal deploy modal_app.py

# Output:
# ✓ Created app ananke-compiler
# ✓ Deployed function compile_constraints
# ✓ Endpoint: https://your-app--ananke-compiler.modal.run
```

### 2. Configure Ananke

```bash
# Set Modal endpoint
export ANANKE_MODAL_ENDPOINT=https://your-app--ananke-compiler.modal.run

# Optional: Set API key for authentication
export ANANKE_MODAL_API_KEY=your-secret-key
```

Or use configuration file:

```toml
# .ananke.toml
[modal]
endpoint = "https://your-app--ananke-compiler.modal.run"
api_key = "your-secret-key"  # Or use environment variable
```

### 3. Use Modal Compilation

```bash
# Extract constraints
ananke extract src/auth.ts -o constraints.json

# Compile using Modal (automatic)
ananke compile constraints.json --use-modal

# Or explicit
ananke compile constraints.json --modal-endpoint https://your-app.modal.run
```

---

## Deployment

### Modal App Structure

```python
# modal_app.py
import modal

app = modal.App("ananke-compiler")

# Define container image
image = modal.Image.debian_slim().pip_install(
    "ananke-core",  # Ananke Python bindings
    "tree-sitter",
    "tree-sitter-python",
    "tree-sitter-typescript",
)

@app.function(
    image=image,
    cpu=2.0,              # 2 vCPUs
    memory=2048,          # 2 GB RAM
    timeout=300,          # 5 minute timeout
    retries=modal.Retries(
        max_retries=3,
        backoff_coefficient=2.0,
    ),
)
def compile_constraints(constraints_json: str) -> dict:
    """
    Compile constraints to IR format.

    Args:
        constraints_json: JSON string of ConstraintSet

    Returns:
        Compiled IR as dictionary
    """
    import json
    from ananke_core import Compiler

    # Parse constraints
    constraints = json.loads(constraints_json)

    # Compile to IR
    compiler = Compiler()
    ir = compiler.compile(
        constraints,
        formats=["json-schema", "grammar", "regex"],
        optimize=True,
    )

    return ir

@app.local_entrypoint()
def main():
    """Test the function locally."""
    test_constraints = {
        "name": "test",
        "constraints": [
            {
                "name": "function_structure",
                "kind": "syntactic",
                "confidence": 1.0,
                "source": "Pattern",
                "description": "Functions must have names"
            }
        ]
    }

    result = compile_constraints.remote(json.dumps(test_constraints))
    print(f"Compiled IR: {result}")
```

### Deployment Commands

```bash
# Deploy app
modal deploy modal_app.py

# Deploy with specific name
modal deploy modal_app.py --name ananke-compiler-prod

# Update existing deployment
modal deploy modal_app.py --force

# View deployment status
modal app list

# View function logs
modal app logs ananke-compiler
```

### Environment Variables

Set secrets in Modal:

```bash
# Set API key
modal secret create ANTHROPIC_API_KEY sk-ant-...

# Set custom config
modal secret create ANANKE_CONFIG '{"max_tokens": 8192}'

# View secrets
modal secret list
```

Use in Modal app:

```python
@app.function(
    secrets=[
        modal.Secret.from_name("ANTHROPIC_API_KEY"),
        modal.Secret.from_name("ANANKE_CONFIG"),
    ],
)
def compile_with_claude(constraints_json: str) -> dict:
    import os
    api_key = os.environ["ANTHROPIC_API_KEY"]
    # Use API key for semantic analysis
    ...
```

---

## Configuration

### Ananke Configuration

```toml
# .ananke.toml
[modal]
# Modal endpoint URL
endpoint = "https://your-app--ananke-compiler.modal.run"

# Optional: API key for authentication
# Best practice: Use environment variable instead
# api_key = "your-secret-key"

# Timeout for Modal requests (milliseconds)
timeout_ms = 30000

# Retry configuration
max_retries = 3
initial_backoff_ms = 1000

[defaults]
# Use Modal for all compile commands
use_modal = true
```

### Environment Variables

```bash
# Modal configuration
export ANANKE_MODAL_ENDPOINT=https://your-app.modal.run
export ANANKE_MODAL_API_KEY=your-secret-key

# Modal CLI configuration
export MODAL_TOKEN_ID=ak-...
export MODAL_TOKEN_SECRET=as-...
```

### Modal App Configuration

```python
# modal_app.py
import modal

# Resource allocation
COMPILE_RESOURCES = {
    "cpu": 2.0,           # vCPUs (0.25, 0.5, 1.0, 2.0, 4.0, 8.0)
    "memory": 2048,       # MB (128, 256, 512, 1024, 2048, 4096, 8192)
    "timeout": 300,       # seconds
    "concurrency_limit": 10,  # Max concurrent executions
}

@app.function(**COMPILE_RESOURCES)
def compile_constraints(constraints_json: str) -> dict:
    ...
```

---

## Usage

### Basic Usage

```bash
# Compile using Modal
ananke compile constraints.json

# Explicit Modal usage
ananke compile constraints.json --use-modal

# Force local compilation
ananke compile constraints.json --no-modal
```

### Advanced Usage

```bash
# Compile with specific Modal endpoint
ananke compile constraints.json \\
  --modal-endpoint https://custom.modal.run

# Compile with authentication
ananke compile constraints.json \\
  --modal-api-key your-secret-key

# Compile with custom timeout
ananke compile constraints.json \\
  --modal-timeout 60000  # 60 seconds
```

### Programmatic Usage (Python)

```python
import requests
import json

# Load constraints
with open("constraints.json") as f:
    constraints = json.load(f)

# Call Modal endpoint
response = requests.post(
    "https://your-app--ananke-compiler.modal.run",
    json={"constraints": constraints},
    headers={
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    },
    timeout=30,
)

# Get compiled IR
ir = response.json()
print(f"Compiled {len(ir['constraints'])} constraints")
```

### Programmatic Usage (Zig)

```zig
const std = @import("std");
const http = @import("http");

pub fn compileWithModal(
    allocator: std.mem.Allocator,
    constraints_json: []const u8,
    modal_endpoint: []const u8,
) ![]const u8 {
    // Prepare request
    const headers = [_]http.HttpRequest.Header{
        .{ .name = "Content-Type", .value = "application/json" },
        .{ .name = "Authorization", .value = "Bearer your-api-key" },
    };

    // Send request to Modal
    var response = try http.post(
        allocator,
        modal_endpoint,
        &headers,
        constraints_json,
    );
    defer response.deinit();

    if (response.status_code != 200) {
        return error.ModalCompilationFailed;
    }

    // Return IR
    return try allocator.dupe(u8, response.body);
}
```

---

## Performance Tuning

### Resource Allocation

| Project Size | CPU | Memory | Typical Time |
|--------------|-----|--------|--------------|
| Small (< 100 constraints) | 1.0 | 512 MB | < 1s |
| Medium (100-1000) | 2.0 | 1 GB | 1-5s |
| Large (1000-10000) | 4.0 | 2 GB | 5-30s |
| Very Large (> 10000) | 8.0 | 4 GB | 30-120s |

### Optimization Strategies

**1. Batch Processing**

```python
@app.function(cpu=4.0, memory=4096)
def batch_compile(constraint_sets: list[str]) -> list[dict]:
    """Compile multiple constraint sets in parallel."""
    from concurrent.futures import ThreadPoolExecutor

    with ThreadPoolExecutor(max_workers=4) as executor:
        results = list(executor.map(compile_constraints, constraint_sets))

    return results
```

**2. Caching**

```python
from functools import lru_cache

@lru_cache(maxsize=128)
def compile_cached(constraints_hash: str, constraints_json: str) -> dict:
    """Cache compiled IR by content hash."""
    return compile_constraints(constraints_json)
```

**3. Streaming**

```python
@app.function(cpu=2.0, memory=2048)
async def compile_stream(constraints_json: str):
    """Stream compilation progress."""
    from ananke_core import Compiler

    compiler = Compiler()

    # Stream progress updates
    async for progress in compiler.compile_async(constraints_json):
        yield {"progress": progress["percent"], "stage": progress["stage"]}

    # Final result
    yield {"done": True, "ir": compiler.get_result()}
```

---

## Monitoring

### Modal Dashboard

View real-time metrics:

```bash
# Open Modal dashboard
modal app dashboard ananke-compiler

# View function stats
modal stats compile_constraints
```

**Metrics available:**
- Request count
- Average latency
- Error rate
- CPU/memory usage
- Cost per request

### Logs

```bash
# View recent logs
modal app logs ananke-compiler

# Follow logs in real-time
modal app logs ananke-compiler --follow

# Filter by function
modal app logs ananke-compiler --function compile_constraints

# Filter by time
modal app logs ananke-compiler --since 1h
```

### Alerts

Set up alerts for:

```python
# Add to modal_app.py
from modal import Alert

app.alert(
    Alert.on_function_error(
        function="compile_constraints",
        threshold=5,  # Alert after 5 errors
        window="1h",
    )
)

app.alert(
    Alert.on_function_duration(
        function="compile_constraints",
        threshold_seconds=60,  # Alert if > 1 minute
    )
)
```

---

## Troubleshooting

### Issue: "Modal deployment failed"

**Symptoms:**
```
error: Failed to deploy app
error: Invalid token
```

**Solutions:**
1. Verify Modal token:
   ```bash
   modal token new
   ```

2. Check Modal account status:
   ```bash
   modal account info
   ```

3. Verify app configuration:
   ```bash
   modal app validate modal_app.py
   ```

### Issue: "Function timeout"

**Symptoms:**
```
error: Function exceeded timeout of 300s
```

**Solutions:**
1. Increase timeout:
   ```python
   @app.function(timeout=600)  # 10 minutes
   def compile_constraints(...):
       ...
   ```

2. Reduce input size:
   ```bash
   # Filter constraints before sending
   jq '.constraints |= .[0:1000]' large_constraints.json > batch1.json
   ```

3. Enable optimization:
   ```python
   ir = compiler.compile(constraints, optimize=True, level=2)
   ```

### Issue: "High costs"

**Symptoms:**
```
Modal bill: $150 for last month
Expected: ~$20
```

**Solutions:**
1. Check usage:
   ```bash
   modal billing usage --month 2025-01
   ```

2. Reduce resource allocation:
   ```python
   @app.function(cpu=1.0, memory=512)  # Smaller resources
   ```

3. Implement caching:
   ```python
   @lru_cache(maxsize=256)
   def compile_constraints(constraints_json: str):
       ...
   ```

4. Use spot instances (if available):
   ```python
   @app.function(spot=True)  # 70% cheaper, may be interrupted
   ```

---

## Cost Optimization

### Pricing Overview

**Modal Pricing (as of 2025):**
- **Compute**: $0.00005/GB-second
- **Storage**: $0.10/GB-month
- **Requests**: $0.40/million

**Example costs:**

| Scenario | Resources | Time | Cost per Request | 1000 Requests |
|----------|-----------|------|------------------|---------------|
| Small | 0.5 CPU, 512 MB | 0.5s | $0.0000125 | $0.0125 |
| Medium | 2 CPU, 2 GB | 2s | $0.0002 | $0.20 |
| Large | 4 CPU, 4 GB | 10s | $0.002 | $2.00 |

### Cost Reduction Strategies

**1. Right-size Resources**

```python
# Before: Over-provisioned
@app.function(cpu=8.0, memory=8192)  # $0.004/request

# After: Right-sized
@app.function(cpu=2.0, memory=2048)  # $0.0001/request
```

**2. Implement Caching**

```python
# Cache compiled IR
from modal import Dict

cache = Dict.from_name("ir-cache", create_if_missing=True)

@app.function()
def compile_with_cache(constraints_json: str) -> dict:
    import hashlib
    key = hashlib.sha256(constraints_json.encode()).hexdigest()

    if key in cache:
        return cache[key]  # No compute cost!

    ir = compile_constraints(constraints_json)
    cache[key] = ir
    return ir
```

**3. Batch Processing**

```bash
# Instead of 100 individual requests ($0.02)
for file in *.json; do
    ananke compile $file --use-modal
done

# Batch into single request ($0.0005)
ananke compile *.json --use-modal --batch
```

**4. Use Free Tier Efficiently**

- 30 free compute hours/month = ~3.6M CPU-seconds
- Small requests (0.5 CPU × 0.5s) = 14,400 free requests/month
- Plan deployments to stay within free tier during development

---

## Related Documentation

- [README.md](../README.md) - Getting started
- [COMPILE_COMMAND.md](./COMPILE_COMMAND.md) - Compile command reference
- [API_ERROR_HANDLING.md](./API_ERROR_HANDLING.md) - Error handling
- [Modal Docs](https://modal.com/docs) - Official Modal documentation

---

## Support

- **Ananke Issues**: https://github.com/your-org/ananke/issues
- **Modal Support**: https://modal.com/support
- **Modal Community**: https://modal.com/slack
