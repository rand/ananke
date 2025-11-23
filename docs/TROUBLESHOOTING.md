# Ananke Troubleshooting Guide

Solutions to common problems and how to debug them.

---

## Installation Issues

### Problem: `ModuleNotFoundError: No module named 'ananke'`

**Cause**: Ananke not installed or wrong Python environment

**Solutions**:

```bash
# Check Python version
python --version  # Should be 3.8+

# Reinstall
pip install --upgrade ananke-ai

# Or from source
git clone https://github.com/ananke-ai/ananke.git
cd ananke
pip install -e .

# Verify
python -c "import ananke; print(ananke.__version__)"
```

---

### Problem: `zig: command not found`

**Cause**: Zig not installed or not in PATH

**Solutions**:

```bash
# Check installation
which zig

# Install from https://ziglang.org/download
# Or using package manager:

# macOS
brew install zig

# Ubuntu/Debian
sudo apt-get install zig

# Arch
sudo pacman -S zig

# Verify
zig version  # Should be 0.15.1+
```

---

### Problem: Permission denied building from source

**Cause**: Insufficient permissions

**Solutions**:

```bash
# Use virtual environment
python -m venv venv
source venv/bin/activate  # or venv\Scripts\activate on Windows

# Then install
pip install -e .

# Or use --user flag
pip install --user -e .
```

---

## Modal Service Issues

### Problem: `modal token new` hangs or times out

**Cause**: Network issues or Modal service down

**Solutions**:

```bash
# Check Modal status
curl https://modal.com

# Try again with timeout
timeout 30 modal token new

# Or authenticate manually
export MODAL_TOKEN_ID="your-token-id"
export MODAL_TOKEN_SECRET="your-token-secret"

# Verify
modal token list
```

---

### Problem: `401 Unauthorized` when deploying service

**Cause**: Modal authentication failed

**Solutions**:

```bash
# Check token
modal token list

# If empty, re-authenticate
modal token new --force

# Verify authentication
modal account whoami

# Try deployment again
modal deploy modal_inference/inference.py
```

---

### Problem: Model download fails with `401 Unauthorized`

**Cause**: HuggingFace token not set or invalid

**Solutions**:

```bash
# Check secret exists
modal secret list

# Create if missing
modal secret create huggingface-secret \
  HUGGING_FACE_HUB_TOKEN=hf_your_token

# Verify token is valid
# 1. Go to https://huggingface.co/settings/tokens
# 2. Copy your access token
# 3. Recreate secret:
modal secret create huggingface-secret \
  --force \
  HUGGING_FACE_HUB_TOKEN=hf_your_new_token

# Also accept model license
# Go to https://huggingface.co/meta-llama/Meta-Llama-3.1-8B-Instruct
# Accept license agreement

# Test by deploying
modal deploy modal_inference/inference.py
```

---

### Problem: `Out of Memory (OOM)` on Modal

**Cause**: Model too large for GPU or too many concurrent requests

**Solutions**:

```bash
# Use smaller model
export INFERENCE_MODEL="meta-llama/Meta-Llama-3.1-8B-Instruct"
modal deploy modal_inference/inference.py

# Or reduce GPU memory utilization
# Edit modal_inference/inference.py:
# Change: gpu_memory_utilization=0.90
# To:     gpu_memory_utilization=0.75

# Or reduce batch size
ananke generate "feature" --batch-size 1

# Or reduce max_tokens
ananke generate "feature" --max-tokens 256
```

---

### Problem: Slow cold starts (>10 seconds)

**Cause**: Model needs to load on GPU (normal for first request)

**Solutions**:

```bash
# Increase idle timeout to keep model warm
# Edit modal_inference/inference.py:
# Change: container_idle_timeout=60
# To:     container_idle_timeout=300

# Or batch requests to avoid cold starts
ananke generate --batch requests.yaml

# Or use model caching
# This is automatic - subsequent requests are fast
```

---

### Problem: `Connection refused` calling Modal service

**Cause**: Service not deployed or endpoint wrong

**Solutions**:

```bash
# Verify service is deployed
modal app list
# Should show ananke-inference

# If missing, deploy
modal deploy modal_inference/inference.py

# Check endpoint
modal app list --detailed

# Verify environment variable
echo $MODAL_ENDPOINT

# Set correct endpoint
export MODAL_ENDPOINT="https://yourapp.modal.run"

# Test connection
curl $MODAL_ENDPOINT/health
```

---

## Constraint Issues

### Problem: No constraints extracted

**Cause**: Code doesn't contain extractable patterns

**Solutions**:

```bash
# Check what Clew is looking for
ananke extract sample.py --detailed --verbose

# Make sure code has patterns:
# - Type annotations
# - Docstrings
# - Error handling
# - Decorators

# If intentional, provide manual constraints
cat > constraints.json << 'JSON'
{
  "constraints": {
    "type_safety": {"require": ["explicit_returns"]}
  }
}
JSON
```

---

### Problem: Constraint extraction too slow (>5 seconds)

**Cause**: Large codebase or Claude analysis enabled

**Solutions**:

```bash
# Extract only needed types
ananke extract ./src \
  --types "security,type_safety" \
  --output constraints.json

# Disable Claude
ananke extract ./src \
  --no-claude \
  --output constraints.json

# Extract from smaller subset
ananke extract ./src/handlers ./src/models

# Or parallelize
find ./src -name "*.py" | \
  parallel "ananke extract {} --output {}.json"
```

---

### Problem: Conflicting constraints

**Cause**: Constraints contradict each other

**Solutions**:

```bash
# Show conflicts
ananke constraints validate constraints.json --details

# Try auto-resolution with Claude
ananke constraints validate constraints.json \
  --use-claude \
  --auto-resolve \
  --output resolved.json

# Or manually edit constraints.json

# Or manually resolve
ananke constraints resolve constraints.json \
  --strategy "merge" \
  --output resolved.json
```

---

### Problem: Generated code violates constraints

**Cause**: Constraints not being enforced properly

**Solutions**:

```bash
# Debug which constraint failed
ananke validate generated.py \
  --constraints compiled.cir \
  --debug

# Try with stricter settings
ananke generate "feature" \
  --constraints compiled.cir \
  --temperature 0.1 \
  --strict-mode

# Or check constraint compilation
ananke compile constraints.json \
  --analyze \
  --verbose

# Report as bug with debug output
ANANKE_LOG_LEVEL=debug ananke generate "feature" \
  --constraints compiled.cir > debug.log 2>&1

# Include debug.log in GitHub issue
```

---

## Generation Issues

### Problem: Generation timeout (>30 seconds)

**Cause**: Model is slow or service is overloaded

**Solutions**:

```bash
# Reduce complexity
ananke generate "feature" \
  --max-tokens 128 \
  --temperature 0.3

# Check service health
modal logs ananke-inference | tail -20

# Try smaller model
export INFERENCE_MODEL="meta-llama/Meta-Llama-3.1-8B-Instruct"

# Or increase timeout
ananke generate "feature" --timeout 60
```

---

### Problem: Very high token usage (>1000 tokens for simple code)

**Cause**: Model generating verbose/repetitive code

**Solutions**:

```bash
# Lower temperature (less random)
ananke generate "feature" --temperature 0.3

# Reduce max_tokens
ananke generate "feature" --max-tokens 256

# Be more specific in prompt
ananke generate "Implement validation function. Keep it simple." \
  --max-tokens 200

# Check constraints aren't encouraging verbosity
ananke constraints show constraints.json
```

---

### Problem: Generated code has errors or doesn't run

**Cause**: Model produced invalid syntax

**Solutions**:

```bash
# Use stricter constraints
ananke constraints validate constraints.json --details

# Regenerate with lower temperature
ananke generate "feature" \
  --constraints constraints.json \
  --temperature 0.2

# Use larger model
export INFERENCE_MODEL="meta-llama/Meta-Llama-3.1-70B-Instruct"

# Or provide more context
ananke generate "Implement feature. Follow the pattern in auth.py" \
  --max-tokens 500
```

---

## Performance Issues

### Problem: Constraint compilation too slow

**Cause**: Too many constraints or complex dependencies

**Solutions**:

```bash
# Simplify constraints
ananke constraints prune constraints.json \
  --remove-redundant \
  --output simplified.json

# Check constraint count
jq '.constraints | length' constraints.json

# Split into multiple files
ananke compile security-constraints.json
ananke compile performance-constraints.json

# Or use multiple passes
ananke compile constraints.json --optimize
```

---

### Problem: Generation latency high (>10 seconds)

**Cause**: Normal for constrained generation, check for issues

**Expected**:
- Cold start: 3-5 seconds
- Generation (100 tokens): 3-5 seconds
- Constraint overhead: <50ms

**If higher**:
```bash
# Check network latency
time curl $MODAL_ENDPOINT/health

# Check logs for errors
modal logs ananke-inference

# Profile generation
ANANKE_LOG_LEVEL=debug ananke generate "feature" \
  --constraints compiled.cir

# Consider using smaller model or batch requests
```

---

### Problem: High memory usage

**Cause**: Large constraint cache or model loaded multiple times

**Solutions**:

```bash
# Clear constraint cache
rm -rf ~/.ananke/cache

# Or configure cache size
export ANANKE_CACHE_SIZE="100"  # Smaller cache

# Check memory usage
ps aux | grep ananke

# Reduce model size
export INFERENCE_MODEL="meta-llama/Meta-Llama-3.1-8B-Instruct"
```

---

## Debugging

### Enable Debug Logging

```bash
# All components
export ANANKE_LOG_LEVEL=debug
ananke extract ./src

# Or per-command
ANANKE_LOG_LEVEL=debug ananke generate "feature"

# Save to file
ANANKE_LOG_LEVEL=debug ananke generate "feature" > debug.log 2>&1
```

### Get Detailed Reports

```bash
# Constraint analysis
ananke constraints analyze constraints.json --detailed

# Extraction report
ananke extract ./src --detailed --report report.json

# Generation debug info
ananke generate "feature" --debug --constraints compiled.cir
```

### Check System Health

```bash
# Modal service
modal app list
modal logs ananke-inference

# Environment variables
env | grep -E 'ANANKE|MODAL|ANTHROPIC'

# Python installation
python -c "import ananke; print(ananke.__file__)"

# Zig installation
zig version
zig build-exe --version
```

---

## Getting Help

### Before Opening an Issue

1. Check this troubleshooting guide
2. Read the User Guide
3. Enable debug logging: `ANANKE_LOG_LEVEL=debug`
4. Try the minimal reproduction case

### Opening a GitHub Issue

Include:
- Ananke version: `ananke --version`
- Python version: `python --version`
- OS: `uname -a`
- Error message (full traceback)
- Steps to reproduce
- Debug logs

```bash
# Minimal reproduction
ANANKE_LOG_LEVEL=debug ananke extract minimal.py > debug.log 2>&1
# Attach debug.log to issue
```

### Support Resources

- **GitHub Issues**: Bug reports and feature requests
- **GitHub Discussions**: Questions and community help
- **Documentation**: `/docs/` directory
- **User Guide**: `/docs/USER_GUIDE.md`
- **Email**: support@ananke-ai.dev (paid support)

---

**Still stuck?** Open an issue with your debug logs!
