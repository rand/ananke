# Ananke Troubleshooting Guide

**Version**: 1.0  
**Last Updated**: 2025-11-24

## Table of Contents

1. [Build Errors](#build-errors)
2. [Runtime Errors](#runtime-errors)
3. [Performance Issues](#performance-issues)
4. [Modal Deployment Problems](#modal-deployment-problems)
5. [Memory Leak Debugging](#memory-leak-debugging)
6. [FFI Issues](#ffi-issues)
7. [Common Error Messages](#common-error-messages)

---

## Build Errors

### Error: `zig: command not found`

**Symptom**: Cannot run `zig build`

**Cause**: Zig not installed or not in PATH

**Solution**:
```bash
# macOS (Homebrew)
brew install zig

# Linux (manual install)
wget https://ziglang.org/download/0.15.2/zig-linux-x86_64-0.15.2.tar.xz
tar -xf zig-linux-x86_64-0.15.2.tar.xz
export PATH=$PATH:$(pwd)/zig-linux-x86_64-0.15.2

# Verify
zig version  # Should show 0.15.2 or higher
```

### Error: `error: dependency 'zts' not found`

**Symptom**: Build fails on tree-sitter dependency

**Cause**: Tree-sitter integration disabled but referenced

**Solution**: Tree-sitter is intentionally disabled. If you see this error, check that `tree_sitter_enabled = false` in `src/clew/clew.zig`.

**Workaround**: Pattern-based extraction provides ~80% coverage without tree-sitter.

### Error: `error: use of undeclared identifier 'claude_api'`

**Symptom**: Build fails referencing Claude module

**Cause**: Claude API module not properly imported

**Solution**:
```bash
# Check build.zig has Claude module
grep -A 5 "claude" build.zig

# Ensure the module is available
zig build --help  # Should list all available steps
```

### Error: `lld: error: undefined symbol: ananke_init`

**Symptom**: Rust FFI tests fail to link

**Cause**: Zig library not built before Rust tests

**Solution**:
```bash
# Build Zig library first
zig build

# Then run Rust tests
cd maze && cargo test
```

### Error: `error: cyclic dependency detected`

**Symptom**: Build warns about circular dependencies

**Cause**: Known issue in Braid constraint graph (false positive)

**Status**: Non-blocking, graph still compiles

**Workaround**: Ignore warning (does not affect functionality)

```bash
# This is expected output:
# Warning: Cyclic dependencies detected. Processed 0/3 constraints.
```

---

## Runtime Errors

### Error: `AllocationFailure` (error code 2)

**Symptom**: Extraction or compilation fails with allocation error

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
1. **Reduce input size**: Split large files into smaller chunks
2. **Increase memory**: Ensure 2GB+ available RAM
3. **Check for leaks**: Run tests with GPA allocator (default in debug)

### Error: `ExtractionFailed` (error code 4)

**Symptom**: Pattern extraction fails

**Cause**: Unsupported language or malformed source code

**Diagnosis**:
```bash
# Check language support
grep "getPatternsForLanguage" src/clew/patterns.zig

# Supported: typescript, python, rust, zig, go
# Unsupported: java, c++, swift, kotlin (return null)
```

**Solutions**:
1. **Verify language name**: Must be lowercase, exact match
2. **Check encoding**: Must be UTF-8
3. **Validate syntax**: Malformed code may cause unexpected matches

### Error: `CompilationFailed` (error code 5)

**Symptom**: Braid compilation fails

**Cause**: Constraint conflicts or invalid graph

**Diagnosis**:
```bash
# Enable debug logging
zig build test -- --verbose

# Check for conflict messages
# "Warning: Cyclic dependencies detected"
```

**Solutions**:
1. **Simplify constraints**: Reduce count to isolate issue
2. **Check priorities**: Ensure no all constraints have same priority
3. **Use Claude resolution**: Enable LLM-assisted conflict resolution

### Error: `ANTHROPIC_API_KEY not set`

**Symptom**: Claude integration fails

**Cause**: Environment variable missing

**Solution**:
```bash
# Set API key
export ANTHROPIC_API_KEY='sk-ant-...'

# Verify
echo $ANTHROPIC_API_KEY

# Permanent (add to ~/.bashrc or ~/.zshrc)
echo 'export ANTHROPIC_API_KEY="sk-ant-..."' >> ~/.bashrc
source ~/.bashrc
```

**Alternative**: Disable Claude integration (system still works)

---

## Performance Issues

### Issue: Extraction taking >100ms

**Expected**: 4-7ms for typical files (75 lines)

**Causes**:
1. Very large files (>1000 lines)
2. Complex nested structures
3. Debug build (not optimized)

**Solutions**:

**Optimize build**:
```bash
# Use ReleaseFast for production
zig build -Doptimize=ReleaseFast

# Benchmark
zig build test -Doptimize=ReleaseFast
```

**Profile code**:
```bash
# Use perf on Linux
perf record zig build test
perf report

# Use Instruments on macOS
# (requires Xcode)
```

**Split large files**:
```bash
# For files >10K lines, split into modules
# Ananke performs better on focused files
```

### Issue: Compilation taking >10ms

**Expected**: 2ms for 10 constraints

**Causes**:
1. Many constraints (>100)
2. Complex dependency graph
3. Inefficient conflict detection

**Solutions**:

**Reduce constraint count**:
```zig
// Filter low-confidence constraints
const filtered = try deduplicateConstraints(allocator, raw_constraints);
```

**Use caching**:
```rust
// Rust side: Maze has built-in LRU cache
let config = MazeConfig {
    enable_cache: true,
    cache_size_limit: 1000,
    ...
};
```

**Profile graph operations**:
```bash
# Add timing instrumentation
zig build test -- --timing
```

### Issue: High memory usage (>1GB)

**Expected**: <100MB for typical workflows

**Causes**:
1. Memory leaks
2. Large allocations not freed
3. Cache growth unbounded

**Solutions**:

**Check for leaks**:
```bash
# Zig GPA detects leaks automatically
zig build test -Doptimize=Debug
# Output should show: "All allocations freed"

# If leaks detected:
# [gpa] (err): memory address 0x... leaked:
```

**Limit cache size**:
```rust
// Maze configuration
let config = MazeConfig {
    cache_size_limit: 100,  // Reduce from default 1000
    ...
};
```

**Use arena allocators**:
```zig
// For temporary data, use arena
var arena = std.heap.ArenaAllocator.init(allocator);
defer arena.deinit();  // Bulk free
const temp_alloc = arena.allocator();
```

---

## Modal Deployment Problems

### Issue: `MODAL_ENDPOINT not set`

**Symptom**: Maze cannot connect to Modal

**Cause**: Environment variable missing

**Solution**:
```bash
# Set Modal endpoint
export MODAL_ENDPOINT='https://your-app.modal.run'

# Set API key (if required)
export MODAL_API_KEY='your-key'

# Set model (optional, defaults to Llama-3.1)
export MODAL_MODEL='DeepSeek-Coder-V2-Lite-Instruct'
```

### Issue: `Connection refused` to Modal

**Symptom**: HTTP connection fails

**Causes**:
1. Modal service not deployed
2. Wrong endpoint URL
3. Network firewall

**Diagnosis**:
```bash
# Test endpoint directly
curl -v $MODAL_ENDPOINT/health

# Expected response:
# HTTP/1.1 200 OK
```

**Solutions**:

**Deploy Modal service**:
```bash
# From modal_service directory
modal deploy app.py

# Note the endpoint URL
# https://your-app--inference-endpoint.modal.run
```

**Check URL format**:
```bash
# Should be HTTPS, not HTTP
# Should end with .modal.run
# Should NOT include /generate (that's added by client)
```

**Test network**:
```bash
# Check DNS resolution
nslookup your-app.modal.run

# Check network connectivity
ping your-app.modal.run
```

### Issue: `60s cold start delay`

**Symptom**: First request takes 60+ seconds

**Cause**: Modal scale-to-zero cold start

**Solutions**:

**Keep instance warm**:
```python
# In Modal deployment
@app.function(
    keep_warm=1,  # Keep 1 instance always running
)
def inference(...):
    ...
```

**Use warm pool**:
```bash
# Ping endpoint every 30s
while true; do
    curl $MODAL_ENDPOINT/health
    sleep 30
done
```

**Accept cold starts**:
- First request: ~60s
- Subsequent requests: ~1-2s
- Cost savings: Pay only for active time

### Issue: `Generation timeout after 300s`

**Symptom**: Long generations fail

**Cause**: Request timeout exceeded

**Solutions**:

**Increase timeout**:
```rust
// Rust Maze configuration
let config = ModalConfig::new(endpoint, model)
    .with_timeout(600);  // 10 minutes
```

**Reduce generation length**:
```rust
let request = GenerationRequest {
    max_tokens: 1024,  // Reduce from 2048
    ...
};
```

**Use streaming** (future):
```rust
// Coming in Phase 10
let stream = client.generate_stream(request).await?;
```

---

## Memory Leak Debugging

### Detecting Leaks in Zig

**Built-in GPA Leak Detection**:
```bash
# Debug build automatically uses GPA
zig build test -Doptimize=Debug

# Clean output:
# "test suite passed. 100/100 tests passed. 0 leaked."

# Leak detected:
# [gpa] (err): memory address 0x12345678 leaked:
# [gpa] (err): allocated by:
# [gpa] (err):     at constraint.zig:123
```

**Manual Leak Check**:
```zig
test "check for memory leaks" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        try testing.expect(leaked == .ok);
    }
    
    const allocator = gpa.allocator();
    
    // Your code here
    var clew = try Clew.init(allocator);
    defer clew.deinit();
    
    const constraints = try clew.extractFromCode(source, "typescript");
    defer constraints.deinit();
}
```

### Common Leak Sources

**1. Forgot `defer deinit()`**:
```zig
// BAD: Memory leak
var list = std.ArrayList(u8).init(allocator);
// ... use list ...
// MISSING: defer list.deinit();

// GOOD: Properly freed
var list = std.ArrayList(u8).init(allocator);
defer list.deinit();
```

**2. Early return without cleanup**:
```zig
// BAD: Leaks on error
fn process() !void {
    var data = try allocator.alloc(u8, 100);
    // If error occurs here, data leaks
    try doSomething();
    allocator.free(data);
}

// GOOD: Cleanup on all paths
fn process() !void {
    var data = try allocator.alloc(u8, 100);
    defer allocator.free(data);  // Runs on all paths
    try doSomething();
}
```

**3. Constraint strings not freed**:
```zig
// Clew uses arena allocator for constraint strings
// Arena is freed in bulk on deinit()
// No individual string cleanup needed
```

### Debugging Leaks in Rust

**Valgrind (Linux)**:
```bash
# Build Rust in debug mode
cd maze
cargo build

# Run with valgrind
valgrind --leak-check=full \
         --show-leak-kinds=all \
         ./target/debug/maze_tests

# Output shows leak sources:
# 100 bytes in 1 blocks are definitely lost
#    at malloc
#    at alloc::vec::Vec::push
#    at maze::orchestrator::generate
```

**AddressSanitizer**:
```bash
# Build with ASAN
RUSTFLAGS="-Z sanitizer=address" \
cargo +nightly build

# Run tests
ASAN_OPTIONS=detect_leaks=1 \
./target/debug/maze_tests
```

---

## FFI Issues

### Issue: `Null pointer dereference`

**Symptom**: Segfault or panic in FFI conversion

**Cause**: Passing null pointer where value expected

**Solution**:
```rust
// Always check for null before dereferencing
unsafe {
    if ir_ptr.is_null() {
        return Err(anyhow!("Null ConstraintIR pointer"));
    }
    let ir = &*ir_ptr;
    
    // Check each nullable field
    if !ir.json_schema.is_null() {
        let schema = CStr::from_ptr(ir.json_schema)
            .to_str()?;
        // ... use schema
    }
}
```

### Issue: `String conversion failed (invalid UTF-8)`

**Symptom**: Error converting C strings to Rust Strings

**Cause**: Non-UTF-8 data in C string

**Solutions**:

**Validate before conversion**:
```rust
use std::ffi::CStr;

unsafe {
    let c_str = CStr::from_ptr(ptr);
    
    // Option 1: Fail on invalid UTF-8
    let s = c_str.to_str()
        .context("Invalid UTF-8 in C string")?;
    
    // Option 2: Lossy conversion (replace invalid bytes)
    let s = c_str.to_string_lossy();
}
```

**Check Zig side**:
```zig
// Ensure all strings are valid UTF-8
const str = try allocator.dupeZ(u8, "valid UTF-8");
```

### Issue: `Use-after-free` in FFI

**Symptom**: Corrupted data or segfault after FFI call

**Cause**: Using Zig-allocated memory after freeing

**Solution**:
```rust
// BAD: Using pointer after free
let ir_ptr = extract_constraints(...);
let ir = ConstraintIR::from_ffi(ir_ptr)?;  // Reads data
unsafe { ananke_free_constraint_ir(ir_ptr); }  // Frees Zig memory
// ir now contains dangling references!

// GOOD: Deep copy before free
let ir_ptr = extract_constraints(...);
let ir = ConstraintIR::from_ffi(ir_ptr)?;  // Deep copies data
unsafe { ananke_free_constraint_ir(ir_ptr); }  // Safe to free
// ir owns all its data
```

---

## Common Error Messages

### `error: OutOfMemory`

**Cause**: Allocation failed

**Solutions**:
1. Check available memory: `free -h`
2. Reduce input size
3. Check for memory leaks
4. Increase swap space (last resort)

### `error: FileNotFound`

**Cause**: Test fixture or source file missing

**Solutions**:
```bash
# Verify file exists
ls -la test/fixtures/

# Check @embedFile paths in tests
grep -r "@embedFile" test/

# Regenerate fixtures if needed
cd test/fixtures && ./generate.sh
```

### `error: InvalidCharacter`

**Cause**: Non-UTF-8 encoding in source file

**Solutions**:
```bash
# Check file encoding
file -bi source.ts

# Convert to UTF-8
iconv -f ISO-8859-1 -t UTF-8 source.ts > source_utf8.ts

# Remove BOM if present
sed -i '1s/^\xEF\xBB\xBF//' source.ts
```

### `error: Overflow`

**Cause**: Integer overflow in calculation

**Solutions**:
```zig
// Use checked arithmetic
const result = std.math.add(u32, a, b) catch {
    return error.Overflow;
};

// Or saturating arithmetic
const result = std.math.saturatingAdd(u32, a, b);
```

### `panic: index out of bounds`

**Cause**: Array access beyond length

**Solutions**:
```zig
// Always bounds-check
if (index >= array.len) {
    return error.IndexOutOfBounds;
}
const element = array[index];

// Or use get() which returns optional
const element = array.get(index) orelse return error.NotFound;
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
env | grep -E 'ANTHROPIC|MODAL'
```

5. **Error messages**: Full stack trace, not just summary

### Support Channels

- GitHub Issues: https://github.com/ananke-ai/ananke/issues
- Documentation: `/Users/rand/src/ananke/docs/`
- FFI Contract: `/Users/rand/src/ananke/test/integration/FFI_CONTRACT.md`

---

**Document Version**: 1.0  
**Maintained By**: Claude Code (docs-writer subagent)  
**Last Updated**: 2025-11-24
