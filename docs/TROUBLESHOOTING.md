# Ananke Troubleshooting Guide

**Version**: 2.0
**Last Updated**: 2025-11-26
**Status**: Comprehensive guide covering v0.1.0

## Table of Contents

1. [Quick Diagnostics](#quick-diagnostics)
2. [Common Issues](#common-issues)
3. [Installation Problems](#installation-problems)
4. [Runtime Errors](#runtime-errors)
5. [Performance Issues](#performance-issues)
6. [Modal & Inference Service Issues](#modal--inference-service-issues)
7. [Debugging Tips](#debugging-tips)
8. [Memory & FFI Issues](#memory--ffi-issues)
9. [Getting Help](#getting-help)

---

## Quick Diagnostics

Before diving into specific issues, run this diagnostic script to understand your environment:

```bash
#!/bin/bash
echo "=== Ananke Diagnostics ==="
echo "Zig version:"
zig version
echo ""
echo "Rust version:"
rustc --version
echo ""
echo "Python version:"
python --version
echo ""
echo "System info:"
uname -a
echo ""
echo "Environment variables:"
env | grep -E 'ANTHROPIC|MODAL|ANANKE' || echo "No Ananke env vars set"
echo ""
echo "Ananke binary:"
which ananke || echo "ananke not in PATH"
echo ""
echo "Available disk space:"
df -h . | tail -1
```

Save as `diagnose.sh`, run with `bash diagnose.sh`, and include output when reporting issues.

---

## Common Issues

### Issue: "Module not found: ananke"

**Symptom**: Python import fails with `ModuleNotFoundError: No module named 'ananke'`

**Causes**:
- Maze Rust library not built
- Library installed to wrong location
- Python path misconfigured

**Solutions**:

1. **Build the library**:
```bash
cd /path/to/ananke/maze
cargo build --release

# Verify the library exists
ls target/release/libmaze.*  # libmaze.so on Linux, libmaze.dylib on macOS
```

2. **Add to Python path**:
```bash
# Option 1: Export PYTHONPATH
export PYTHONPATH="${PYTHONPATH}:/path/to/ananke/maze/target/release"

# Option 2: Install in development mode
cd /path/to/ananke/maze
pip install -e .

# Option 3: Verify installation
python -c "from maze import Maze; print('OK')"
```

3. **Check library compatibility**:
```bash
# Verify library matches your Python version
python -c "import sys; print(sys.version)"

# Rebuild for your Python version
cd maze
maturin develop  # Uses your current Python
```

---

### Issue: "ANANKE_MODAL_ENDPOINT not set"

**Symptom**: Generation fails with `Error: ANANKE_MODAL_ENDPOINT environment variable not set`

**Cause**: Modal endpoint URL not configured

**Solutions**:

1. **Set the endpoint**:
```bash
# Find your Modal endpoint
modal app list  # Lists deployed apps

# Set environment variable
export ANANKE_MODAL_ENDPOINT='https://your-app--endpoint.modal.run'

# Verify
echo $ANANKE_MODAL_ENDPOINT
```

2. **Deploy Modal service if missing**:
```bash
cd /path/to/ananke/maze/modal_inference
modal deploy app.py

# Wait for deployment to complete
# Output will show: https://your-app--endpoint.modal.run
```

3. **Permanent configuration**:
```bash
# Add to ~/.bashrc or ~/.zshrc
echo 'export ANANKE_MODAL_ENDPOINT="https://your-app--endpoint.modal.run"' >> ~/.bashrc
source ~/.bashrc
```

4. **Test the connection**:
```bash
curl -I $ANANKE_MODAL_ENDPOINT/health
# Expected: HTTP/1.1 200 OK
```

---

### Issue: "Health check failing"

**Symptom**: Modal service responds but health endpoint returns error

**Causes**:
- Service still initializing
- Model loading incomplete
- GPU memory issues
- Service crashed

**Diagnosis**:
```bash
# Test endpoint connectivity
curl -v $ANANKE_MODAL_ENDPOINT/health

# Check Modal logs
modal logs -a your-app-name

# Test from Python
python -c "
import requests
url = 'https://your-app--endpoint.modal.run/health'
resp = requests.get(url, timeout=10)
print(f'Status: {resp.status_code}')
print(f'Response: {resp.text}')
"
```

**Solutions**:

1. **Wait for initialization** (first call after deployment):
```bash
# Cold start can take 30-60s
# Retry with exponential backoff
for i in {1..10}; do
    if curl -s $ANANKE_MODAL_ENDPOINT/health; then
        echo "Service ready!"
        break
    fi
    echo "Attempt $i: Service not ready, waiting..."
    sleep $((2 ** i))
done
```

2. **Check Modal deployment status**:
```bash
modal app status

# If "unhealthy", check logs:
modal logs -a your-app-name --follow

# Redeploy if necessary:
modal deploy app.py --name your-app-name
```

3. **GPU memory issues** (if using GPU):
```bash
# In modal_inference/app.py, reduce model size:
@app.function(gpu="A10G")  # Smaller GPU
def inference(...):
    # Use smaller model or adjust batch size
    pass

# Redeploy
modal deploy app.py
```

---

### Issue: "Generation timeouts"

**Symptom**: Generation requests timeout with `Error: Request timed out after 300s`

**Causes**:
- Constraint set is too complex
- Model inference is slow
- Network latency
- Request max_tokens too high

**Solutions**:

1. **Reduce max_tokens**:
```python
from ananke import Maze

maze = Maze(endpoint=endpoint)
result = await maze.generate(
    intent="Add authentication",
    constraints=compiled,
    max_tokens=512,  # Reduce from default 2048
    timeout=60  # Shorter timeout
)
```

2. **Increase timeout** (for legitimate long generations):
```python
result = await maze.generate(
    intent="...",
    constraints=compiled,
    timeout=600,  # 10 minutes
    max_tokens=2048
)
```

3. **Reduce constraint complexity**:
```bash
# Profile constraint compilation time
ananke compile constraints.json --verbose

# Filter high-confidence constraints only:
jq '.[] | select(.confidence > 0.9)' constraints.json > filtered.json
ananke compile filtered.json -o compiled.cir
```

4. **Check network and service health**:
```bash
# Measure latency to Modal
ping $ANANKE_MODAL_ENDPOINT

# Test simple inference
curl -X POST $ANANKE_MODAL_ENDPOINT/generate \
  -H "Content-Type: application/json" \
  -d '{"prompt":"hello","max_tokens":10}'
```

---

### Issue: "Constraint validation errors"

**Symptom**: Compilation fails with `Error: Constraint validation failed`

**Causes**:
- Invalid constraint format
- Conflicting constraints
- Cyclic dependencies
- Unsupported constraint type

**Diagnosis**:
```bash
# Check constraint JSON format
jq . constraints.json  # Must be valid JSON

# Compile with verbose output
ananke compile constraints.json --verbose --debug

# Look for error messages about:
# - Missing required fields
# - Invalid constraint types
# - Conflicting priorities
```

**Solutions**:

1. **Validate constraint format**:
```bash
# Each constraint should have:
# - id (string, unique)
# - kind (string: syntactic, type_safety, semantic, etc.)
# - description (string)
# - severity (string: error, warning, info)

jq '.[] | {id, kind, description, severity}' constraints.json | head -5
```

2. **Fix conflicts**:
```bash
# If you see "Cyclic dependency" warnings:
# - Check constraint priorities
# - Ensure no mutual dependencies
# - Use Claude to resolve conflicts

ananke compile constraints.json \
  --optimize-with-llm \
  --anthropic-api-key "$ANTHROPIC_API_KEY"
```

3. **Remove duplicates**:
```bash
# Remove exact duplicates
jq 'unique_by(.id)' constraints.json > clean.json

# Remove near-duplicates (same kind + description)
jq 'unique_by(.kind + .description)' constraints.json > clean.json
```

---

### Issue: "Cache issues"

**Symptom**: Old constraints used, or cache is out of date

**Causes**:
- Cache not cleared after updates
- Stale constraints in memory
- Distributed cache inconsistency
- Invalid cached compilation

**Solutions**:

1. **Clear cache manually**:
```bash
# Zig/Braid cache
rm -rf zig-cache/

# Python/Maze cache
rm -rf ~/.cache/ananke/
python -c "from maze import Maze; Maze.clear_cache()"

# Complete reset
cd /path/to/ananke
zig clean
cargo clean  # Rust side
```

2. **Disable caching temporarily**:
```bash
# Python
maze = Maze(endpoint=endpoint, cache_enabled=False)

# CLI
ananke compile constraints.json --no-cache
```

3. **Verify cache state**:
```bash
# Check cache directory
ls -la ~/.cache/ananke/

# Check cache size
du -sh ~/.cache/ananke/

# Rebuild cache
ananke compile constraints.json --force-recompile
```

---

## Installation Problems

### Error: "zig: command not found"

**Symptom**: Cannot run `zig build`

**Cause**: Zig not installed or not in PATH

**Solution**:

1. **Install Zig**:
```bash
# macOS (Homebrew)
brew install zig

# Linux (manual install)
cd /tmp
wget https://ziglang.org/download/0.15.2/zig-linux-x86_64-0.15.2.tar.xz
tar -xf zig-linux-x86_64-0.15.2.tar.xz
sudo mv zig-linux-x86_64-0.15.2 /usr/local/zig
export PATH="/usr/local/zig:$PATH"

# Add to ~/.bashrc permanently
echo 'export PATH="/usr/local/zig:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

2. **Verify installation**:
```bash
zig version  # Should show 0.15.2 or higher
zig build --help  # Check it works
```

3. **Update Zig** (if too old):
```bash
# Check your version
zig version

# If < 0.15.2, update:
# macOS
brew upgrade zig

# Linux: Repeat installation steps above with latest version
```

---

### Error: "Maturin build failures"

**Symptom**: `cargo build` or `pip install -e .` fails with maturin errors

**Causes**:
- Python development headers missing
- PyO3 version mismatch
- Rust toolchain issues

**Solutions**:

1. **Install Python development headers**:
```bash
# macOS
brew install python@3.11  # or your preferred version

# Debian/Ubuntu
sudo apt-get install python3-dev python3-pip

# Fedora/CentOS
sudo yum install python3-devel

# Verify headers are present
python -m pip list | grep pyo3  # Should show PyO3
```

2. **Update Rust and maturin**:
```bash
# Update Rust
rustup update

# Install/update maturin
pip install --upgrade maturin

# Rebuild
cd /path/to/ananke/maze
maturin develop
```

3. **Clean and rebuild**:
```bash
cd /path/to/ananke/maze
cargo clean
cargo build --release
```

---

### Error: "Python version incompatibility"

**Symptom**: `Error: Python version 3.X is not supported` or wheel not found

**Causes**:
- Library built for different Python version
- Virtual environment issues
- Wheel file missing for architecture

**Solutions**:

1. **Use matching Python version**:
```bash
# Check which Python you're using
which python
python --version

# Use explicit version
python3.11 -c "from maze import Maze"  # Try specific version
```

2. **Rebuild for your Python**:
```bash
# Use maturin develop (automatic Python detection)
cd /path/to/ananke/maze
maturin develop

# Or specify explicitly
maturin develop --python python3.11
```

3. **Check virtual environment**:
```bash
# Ensure you're in the right venv
which python  # Should show your venv path

# If not, activate it
source venv/bin/activate  # Linux/macOS
# or
venv\Scripts\activate  # Windows

# Then rebuild
maturin develop
```

---

### Error: "Missing dependencies"

**Symptom**: Build fails with `undefined reference to` or `ld: symbol not found`

**Causes**:
- System libraries not installed
- Header files missing
- Linker path issues

**Solutions**:

1. **Install system dependencies**:
```bash
# macOS
brew install llvm cmake openssl

# Debian/Ubuntu
sudo apt-get install build-essential cmake llvm clang

# Fedora/CentOS
sudo yum install gcc gcc-c++ cmake llvm clang

# Verify
pkg-config --list-all | grep openssl  # Check for installed packages
```

2. **Set library paths**:
```bash
# If system libraries not found, set LDFLAGS
export LDFLAGS="-L/usr/local/lib"
export CFLAGS="-I/usr/local/include"

# Then rebuild
zig build -Doptimize=ReleaseFast
```

---

### Error: "Permission denied during installation"

**Symptom**: `Permission denied: /usr/local/bin/ananke` or similar

**Causes**:
- Installing to protected directory without sudo
- Incorrect file permissions
- User not in required group

**Solutions**:

1. **Install to user directory** (preferred):
```bash
# Install to ~/.local/bin
mkdir -p ~/.local/bin

# Copy binary
cp zig-out/bin/ananke ~/.local/bin/

# Add to PATH
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Verify
~/.local/bin/ananke --version
```

2. **Use sudo carefully**:
```bash
# Only if necessary
sudo cp zig-out/bin/ananke /usr/local/bin/

# Verify permissions
ls -la /usr/local/bin/ananke
sudo chmod 755 /usr/local/bin/ananke
```

---

## Runtime Errors

### Error: "AllocationFailure (error code 2)"

**Symptom**: Extraction or compilation fails with memory allocation error

**Cause**: Out of memory or allocator issue

**Diagnosis**:
```bash
# Check available memory
free -h  # Linux
vm_stat  # macOS

# Run with leak detection
zig build test -Doptimize=Debug
```

**Solutions**:

1. **Reduce input size**:
```bash
# Split large files
wc -l large_file.ts  # Count lines
# Files > 10,000 lines should be split into modules

# Process in smaller chunks
ananke extract part1.ts part2.ts part3.ts
```

2. **Increase available memory**:
```bash
# Temporarily reduce other processes
# Or increase swap (Linux)
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

---

### Error: "ExtractionFailed (error code 4)"

**Symptom**: Pattern extraction fails

**Cause**: Unsupported language or malformed source code

**Diagnosis**:
```bash
# Check supported languages
ananke extract --help  # Lists supported file types

# Verify file encoding
file -bi your_file.ts  # Should show "charset=utf-8"

# Check for syntax errors
node --check your_file.ts  # For TypeScript
python -m py_compile your_file.py  # For Python
```

**Solutions**:

1. **Verify language support**:
```bash
# Supported in v0.1.0: TypeScript, JavaScript, Python
# Not supported: Java, C++, Swift, Kotlin

# Check file extension
ls -la *.{ts,js,py}  # Look for supported extensions
```

2. **Fix encoding issues**:
```bash
# Check encoding
file -bi problem_file.ts

# Convert to UTF-8 if needed
iconv -f ISO-8859-1 -t UTF-8 problem_file.ts > fixed.ts

# Remove BOM if present
sed -i '1s/^\xEF\xBB\xBF//' fixed.ts
```

3. **Validate syntax**:
```bash
# TypeScript
npx tsc --noEmit your_file.ts

# Python
python -m py_compile your_file.py

# If errors, fix them before extraction
```

---

### Error: "CompilationFailed (error code 5)"

**Symptom**: Braid compilation fails

**Cause**: Constraint conflicts or invalid graph

**Diagnosis**:
```bash
# Compile with verbose output
ananke compile constraints.json --verbose --debug

# Check for cyclic dependencies warning
# "Warning: Cyclic dependencies detected"
```

**Solutions**:

1. **Reduce constraint count**:
```bash
# Start with high-confidence only
jq '.[] | select(.confidence > 0.95)' constraints.json > high_conf.json
ananke compile high_conf.json -o compiled.cir

# If that works, gradually add more
jq '.[] | select(.confidence > 0.85)' constraints.json > med_conf.json
```

2. **Check for conflicting constraints**:
```bash
# Constraints should not contradict
# Example: Don't forbid AND require the same token

jq '.[] | select(.kind == "security") | .description' constraints.json
# Look for mutually exclusive requirements
```

3. **Use Claude for conflict resolution**:
```bash
# If you hit conflicts, let Claude help resolve
ananke compile constraints.json \
  --optimize-with-llm \
  --anthropic-api-key "$ANTHROPIC_API_KEY"
```

---

### Error: "ANTHROPIC_API_KEY not set"

**Symptom**: Claude integration fails with environment variable error

**Cause**: API key not configured

**Solutions**:

1. **Set the environment variable**:
```bash
export ANTHROPIC_API_KEY='sk-ant-v7-...'

# Verify it's set
echo $ANTHROPIC_API_KEY

# Make it permanent (add to ~/.bashrc or ~/.zshrc)
echo 'export ANTHROPIC_API_KEY="sk-ant-..."' >> ~/.bashrc
source ~/.bashrc
```

2. **Get or create an API key**:
```bash
# Visit: https://console.anthropic.com/keys
# Create a new API key
# Copy it and set it as above
```

3. **Test Claude integration**:
```bash
zig build examples
cd examples/02-claude-analysis
zig build run
# Should show Claude-enhanced analysis
```

4. **Gracefully fallback** (Claude is optional):
```bash
# If API key not set, extraction still works
# Just without semantic understanding
ananke extract your_file.ts
# Falls back to structural analysis only
```

---

## Performance Issues

### Issue: "Extraction taking >100ms"

**Expected**: 4-7ms for typical files (75 lines)

**Causes**:
1. Very large files (>1000 lines)
2. Complex nested structures
3. Debug build (not optimized)

**Solutions**:

1. **Optimize build**:
```bash
# Use ReleaseFast for production
zig build -Doptimize=ReleaseFast

# Benchmark
zig build test -Doptimize=ReleaseFast
```

2. **Profile code**:
```bash
# Use perf on Linux
perf record zig build test
perf report

# Use Instruments on macOS
# (requires Xcode)
```

3. **Split large files**:
```bash
# For files >10K lines, split into modules
# Ananke performs better on focused files
```

---

### Issue: "Compilation taking >10ms"

**Expected**: 2ms for 10 constraints

**Causes**:
1. Many constraints (>100)
2. Complex dependency graph
3. Inefficient conflict detection

**Solutions**:

1. **Reduce constraint count**:
```zig
// Filter low-confidence constraints
const filtered = try deduplicateConstraints(allocator, raw_constraints);
```

2. **Use caching**:
```rust
// Rust side: Maze has built-in LRU cache
let config = MazeConfig {
    enable_cache: true,
    cache_size_limit: 1000,
    ...
};
```

3. **Profile graph operations**:
```bash
# Add timing instrumentation
zig build test -- --timing
```

---

### Issue: "High memory usage (>1GB)"

**Expected**: <100MB for typical workflows

**Causes**:
1. Memory leaks
2. Large allocations not freed
3. Cache growth unbounded

**Solutions**:

1. **Check for leaks**:
```bash
# Zig GPA detects leaks automatically
zig build test -Doptimize=Debug
# Output should show: "All allocations freed"

# If leaks detected:
# [gpa] (err): memory address 0x... leaked:
```

2. **Limit cache size**:
```rust
// Maze configuration
let config = MazeConfig {
    cache_size_limit: 100,  // Reduce from default 1000
    ...
};
```

3. **Use arena allocators**:
```zig
// For temporary data, use arena
var arena = std.heap.ArenaAllocator.init(allocator);
defer arena.deinit();  // Bulk free
const temp_alloc = arena.allocator();
```

---

## Modal & Inference Service Issues

### Issue: "Connection refused to Modal"

**Symptom**: HTTP connection fails

**Causes**:
1. Modal service not deployed
2. Wrong endpoint URL
3. Network firewall

**Diagnosis**:
```bash
# Test endpoint directly
curl -v $ANANKE_MODAL_ENDPOINT/health

# Expected response:
# HTTP/1.1 200 OK
```

**Solutions**:

1. **Deploy Modal service**:
```bash
# From modal_service directory
modal deploy app.py

# Note the endpoint URL
# https://your-app--inference-endpoint.modal.run
```

2. **Check URL format**:
```bash
# Should be HTTPS, not HTTP
# Should end with .modal.run
# Should NOT include /generate (that's added by client)
```

3. **Test network**:
```bash
# Check DNS resolution
nslookup your-app.modal.run

# Check network connectivity
ping your-app.modal.run
```

---

### Issue: "Cold start delay (60+ seconds)"

**Symptom**: First request takes 60+ seconds

**Cause**: Modal scale-to-zero cold start

**Solutions**:

1. **Keep instance warm**:
```python
# In Modal deployment
@app.function(
    keep_warm=1,  # Keep 1 instance always running
)
def inference(...):
    ...
```

2. **Use warm pool**:
```bash
# Ping endpoint every 30s
while true; do
    curl $ANANKE_MODAL_ENDPOINT/health
    sleep 30
done
```

3. **Accept cold starts**:
- First request: ~60s
- Subsequent requests: ~1-2s
- Cost savings: Pay only for active time

---

### Issue: "Generation timeout after 300s"

**Symptom**: Long generations fail

**Cause**: Request timeout exceeded

**Solutions**:

1. **Increase timeout**:
```rust
// Rust Maze configuration
let config = ModalConfig::new(endpoint, model)
    .with_timeout(600);  // 10 minutes
```

2. **Reduce generation length**:
```rust
let request = GenerationRequest {
    max_tokens: 1024,  // Reduce from 2048
    ...
};
```

3. **Use streaming** (future):
```rust
// Coming in Phase 10
let stream = client.generate_stream(request).await?;
```

---

## Debugging Tips

### Enable verbose logging

```bash
# Zig compilation with debug info
zig build -Doptimize=Debug

# Verbose constraint extraction
ananke extract your_file.ts --verbose --debug

# Verbose compilation
ananke compile constraints.json --verbose --debug

# Python debugging
python -c "
import logging
logging.basicConfig(level=logging.DEBUG)
from maze import Maze
# ... your code ...
"
```

---

### Check Modal service logs

```bash
# View logs for your Modal app
modal logs -a your-app-name

# Follow logs in real-time
modal logs -a your-app-name --follow

# Get logs from specific timestamp
modal logs -a your-app-name --since="2025-11-26 10:00:00"

# Find errors
modal logs -a your-app-name | grep -i error
```

---

### Verify constraint compilation

```bash
# Check constraint graph
ananke compile constraints.json --verbose

# Show compiled IR (intermediate representation)
ananke compile constraints.json -o compiled.cir --show-ir

# Validate constraints
ananke validate output.py compiled.cir

# Check token masks
jq '.token_masks[]' compiled.cir
```

---

### Test connectivity

```bash
# Test Anthropic API
curl -H "Authorization: Bearer $ANTHROPIC_API_KEY" \
  https://api.anthropic.com/v1/models

# Test Modal endpoint
curl -v $ANANKE_MODAL_ENDPOINT/health

# Test with actual request
curl -X POST $ANANKE_MODAL_ENDPOINT/generate \
  -H "Content-Type: application/json" \
  -d '{"prompt":"test","max_tokens":10}'
```

---

## Memory & FFI Issues

### Memory leak detection

**Built-in GPA Leak Detection**:
```bash
# Debug build automatically uses GPA
zig build test -Doptimize=Debug

# Clean output:
# "test suite passed. 100/100 tests passed. 0 leaked."

# Leak detected:
# [gpa] (err): memory address 0x12345678 leaked:
```

---

### FFI (Zig-Rust) issues

**Null pointer dereference**:
```rust
// Always check for null before dereferencing
unsafe {
    if ir_ptr.is_null() {
        return Err(anyhow!("Null ConstraintIR pointer"));
    }
    let ir = &*ir_ptr;
}
```

**String conversion**:
```rust
use std::ffi::CStr;

unsafe {
    let c_str = CStr::from_ptr(ptr);
    
    // Option 1: Fail on invalid UTF-8
    let s = c_str.to_str()
        .context("Invalid UTF-8 in C string")?;
    
    // Option 2: Lossy conversion
    let s = c_str.to_string_lossy();
}
```

**Use-after-free**:
```rust
// GOOD: Deep copy before free
let ir_ptr = extract_constraints(...);
let ir = ConstraintIR::from_ffi(ir_ptr)?;  // Deep copies data
unsafe { ananke_free_constraint_ir(ir_ptr); }  // Safe to free
// ir owns all its data
```

---

## Getting Help

### Diagnostic Information to Collect

When reporting issues, include:

1. **System info**:
```bash
uname -a  # OS version
zig version  # Zig version
rustc --version  # Rust version
python --version  # Python version
```

2. **Build output**:
```bash
zig build 2>&1 | tee build.log
```

3. **Test output**:
```bash
zig build test 2>&1 | tee test.log
cd maze && cargo test 2>&1 | tee rust_test.log
```

4. **Environment**:
```bash
env | grep -E 'ANTHROPIC|MODAL|ANANKE'
```

5. **Error messages**: Full stack trace, not just summary

---

### Support Channels

- **GitHub Issues**: https://github.com/ananke-ai/ananke/issues
- **Documentation**: `/Users/rand/src/ananke/docs/`
- **API Reference**: Check relevant API docs in `/docs/`
- **Examples**: See `/examples/` for working code samples
- **FFI Contract**: `/Users/rand/src/ananke/test/integration/FFI_CONTRACT.md`

---

### Common Error Messages Reference

| Error | Cause | Solution |
|-------|-------|----------|
| `OutOfMemory` | Allocation failed | Reduce input size, increase available memory |
| `FileNotFound` | Missing test fixture | Run diagnostic script |
| `InvalidCharacter` | Non-UTF-8 encoding | Convert to UTF-8 |
| `Overflow` | Integer overflow | Use checked arithmetic |
| `index out of bounds` | Array access beyond length | Add bounds check |

---

**Document Version**: 2.0
**Maintained By**: Claude Code (docs-writer subagent)
**Last Updated**: 2025-11-26
**Coverage**: v0.1.0 - Beta (Core Ready)
