# FFI Contract Documentation

## Overview

This document defines the contract between Zig (Clew/Braid) and Rust (Maze) components via C FFI.

## Architecture

```
┌──────────────────┐         ┌──────────────────┐         ┌─────────────────┐
│   Zig (Clew)     │────────>│   C FFI Layer    │────────>│  Rust (Maze)    │
│  Extraction      │         │   (zig_ffi.zig)  │         │  Orchestration  │
└──────────────────┘         └──────────────────┘         └─────────────────┘
         │                            │                             │
         v                            v                             v
┌──────────────────┐         ┌──────────────────┐         ┌─────────────────┐
│  Zig (Braid)     │         │ ConstraintIRFFI  │         │  Modal Client   │
│  Compilation     │         │    (C struct)    │         │    (HTTP)       │
└──────────────────┘         └──────────────────┘         └─────────────────┘
```

## Data Structures

### ConstraintIRFFI

C-compatible representation of compiled constraints.

**C Definition (Zig):**
```zig
pub const ConstraintIRFFI = extern struct {
    json_schema: ?[*:0]const u8,        // Null-terminated JSON string
    grammar: ?[*:0]const u8,            // Null-terminated JSON string  
    regex_patterns: ?[*]const [*:0]const u8,  // Array of null-terminated strings
    regex_patterns_len: usize,
    token_masks: ?*anyopaque,           // Opaque pointer to TokenMaskRulesFFI
    priority: u32,
    name: ?[*:0]const u8,
};
```

**Rust Definition:**
```rust
#[repr(C)]
pub struct ConstraintIRFFI {
    pub json_schema: *const c_char,
    pub grammar: *const c_char,
    pub regex_patterns: *const *const c_char,
    pub regex_patterns_len: usize,
    pub token_masks: *const TokenMaskRulesFFI,
    pub priority: u32,
    pub name: *const c_char,
}
```

**Field Specifications:**

- `json_schema`: Optional JSON schema as null-terminated string. Represents structured data constraints compatible with JSON Schema Draft-07.

- `grammar`: Optional context-free grammar as null-terminated JSON string. Format:
  ```json
  {
    "rules": [
      {"lhs": "S", "rhs": ["E"]},
      {"lhs": "E", "rhs": ["T", "+", "E"]}
    ],
    "start_symbol": "S"
  }
  ```

- `regex_patterns`: Array of null-terminated regex pattern strings. Each pattern is a valid regex compatible with PCRE/Rust regex syntax.

- `regex_patterns_len`: Number of regex patterns in array.

- `token_masks`: Pointer to token masking rules (for llguidance integration).

- `priority`: Conflict resolution priority (0-255, higher = more important).

- `name`: Constraint identifier as null-terminated string.

### TokenMaskRulesFFI

**C Definition (Zig):**
```zig
pub const TokenMaskRulesFFI = extern struct {
    allowed_tokens: ?[*]const u32,
    allowed_tokens_len: usize,
    forbidden_tokens: ?[*]const u32,
    forbidden_tokens_len: usize,
};
```

**Rust Definition:**
```rust
#[repr(C)]
pub struct TokenMaskRulesFFI {
    pub allowed_tokens: *const u32,
    pub allowed_tokens_len: usize,
    pub forbidden_tokens: *const u32,
    pub forbidden_tokens_len: usize,
}
```

## Memory Ownership Rules

### Allocation

1. **Zig Allocates**: All FFI structures returned from Zig functions are allocated by Zig's global allocator.

2. **Rust Allocates**: When Rust creates FFI structures to pass to Zig, Rust owns the memory.

3. **String Ownership**: All strings crossing the FFI boundary are owned by the allocator that created them.

### Deallocation

1. **Zig-Allocated Memory**: Must be freed using `ananke_free_constraint_ir()` or equivalent Zig cleanup functions.

2. **Rust-Allocated Memory**: Must be freed using Rust's `free_constraint_ir_ffi()` or equivalent.

3. **Rule of Thumb**: The allocator that creates the memory is responsible for freeing it.

### Example: Safe Memory Usage

**Zig Side:**
```zig
export fn ananke_extract_constraints(
    source: [*:0]const u8,
    language: [*:0]const u8,
    out_ir: *?*ConstraintIRFFI,
) callconv(.c) c_int {
    // Allocate IR using Zig allocator
    const ir_ffi = gpa.create(ConstraintIRFFI) catch {
        return @intFromEnum(AnankeError.AllocationFailure);
    };
    
    // Populate fields...
    
    out_ir.* = ir_ffi;
    return @intFromEnum(AnankeError.Success);
}

export fn ananke_free_constraint_ir(ir: ?*ConstraintIRFFI) callconv(.c) void {
    if (ir) |ptr| {
        // Free all nested allocations
        if (ptr.name) |name| {
            gpa.free(std.mem.span(name));
        }
        // ... free other fields ...
        gpa.destroy(ptr);
    }
}
```

**Rust Side:**
```rust
pub fn extract_constraints(source: &str, language: &str) -> Result<ConstraintIR> {
    let source_c = CString::new(source)?;
    let language_c = CString::new(language)?;
    
    let mut out_ir: *mut ConstraintIRFFI = std::ptr::null_mut();
    
    unsafe {
        let result = ananke_extract_constraints(
            source_c.as_ptr(),
            language_c.as_ptr(),
            &mut out_ir
        );
        
        if result != 0 {
            return Err(anyhow!("Extraction failed: {}", result));
        }
        
        // Convert to Rust-owned structure
        let ir = ConstraintIR::from_ffi(out_ir)?;
        
        // Free Zig-allocated memory
        ananke_free_constraint_ir(out_ir);
        
        Ok(ir)
    }
}
```

## Error Handling Protocol

### Error Codes

```c
enum AnankeError {
    Success = 0,
    NullPointer = 1,
    AllocationFailure = 2,
    InvalidInput = 3,
    ExtractionFailed = 4,
    CompilationFailed = 5,
}
```

### Error Propagation

1. **Zig Functions**: Return `c_int` error codes, with 0 indicating success.

2. **Output Parameters**: Use pointer-to-pointer for returning allocated structures.

3. **Partial Failure**: If a function fails, output parameters remain unchanged (null).

4. **Error Messages**: Detailed error messages should be logged on Zig side; only error codes cross FFI boundary.

### Example Error Handling

**Zig:**
```zig
export fn ananke_extract_constraints(...) callconv(.c) c_int {
    if (out_ir.* != null) {
        return @intFromEnum(AnankeError.InvalidInput);
    }
    
    var clew = Clew.init(gpa) catch {
        return @intFromEnum(AnankeError.AllocationFailure);
    };
    defer clew.deinit();
    
    var constraint_set = clew.extractFromCode(...) catch {
        return @intFromEnum(AnankeError.ExtractionFailed);
    };
    
    // Success path...
    return @intFromEnum(AnankeError.Success);
}
```

**Rust:**
```rust
let result = unsafe {
    ananke_extract_constraints(source, language, &mut out_ir)
};

match result {
    0 => { /* Success */ },
    1 => return Err(anyhow!("Null pointer error")),
    2 => return Err(anyhow!("Allocation failure")),
    3 => return Err(anyhow!("Invalid input")),
    4 => return Err(anyhow!("Extraction failed")),
    5 => return Err(anyhow!("Compilation failed")),
    _ => return Err(anyhow!("Unknown error: {}", result)),
}
```

## Thread Safety

### Current Status

- **NOT Thread-Safe**: The current FFI implementation uses a global allocator and is not designed for concurrent access.

- **Sequential Access Only**: Callers must serialize all FFI calls.

### Future Improvements

To make thread-safe:

1. Use per-thread allocators or arena allocators
2. Add mutex protection around global state
3. Make Clew/Braid instances thread-local

## Performance Characteristics

### Expected Performance

- **Small Files (<10KB)**: <100ms extraction + compilation
- **Medium Files (10-100KB)**: <500ms extraction + compilation
- **Large Files (>100KB)**: <2s extraction + compilation

### Memory Usage

- **Overhead per Constraint**: ~200 bytes
- **Typical ConstraintIR**: 1-10 KB
- **Peak Memory**: 2-5x input file size during extraction

## Known Limitations

### Current Limitations

1. **No Streaming**: Entire source code must be in memory
2. **ASCII/UTF-8 Only**: No support for other encodings
3. **Single-Threaded**: No concurrent extraction
4. **Memory Pooling**: No object pooling or reuse

### Workarounds

1. **Large Files**: Split into smaller compilation units
2. **Memory Pressure**: Use arena allocators, clear between batches
3. **Concurrency**: Create separate Zig instances per thread

## Testing Strategy

### Test Categories

1. **Roundtrip Tests**: Zig → FFI → Rust → FFI → Zig
2. **Memory Leak Tests**: Valgrind/ASAN validation
3. **Stress Tests**: Large files, many constraints
4. **Error Path Tests**: Invalid input, allocation failures
5. **Edge Cases**: Empty constraints, null fields, long strings

### Test Files

- `/Users/rand/src/ananke/test/integration/e2e_pipeline_test.zig`
- `/Users/rand/src/ananke/maze/tests/zig_integration_test.rs`
- `/Users/rand/src/ananke/maze/tests/ffi_tests.rs`

## Version Compatibility

### Current Version

- Zig: 0.15.1
- Rust: 1.75+
- FFI ABI: v1 (stable)

### Breaking Changes

Changes that break FFI contract:

1. Adding/removing fields from FFI structs
2. Changing field types or layouts
3. Modifying function signatures
4. Changing error code meanings

### Non-Breaking Changes

Safe changes:

1. Adding new FFI functions
2. Adding new error codes (at end)
3. Internal implementation changes
4. Performance improvements

## Example Usage

### Complete Example: Extract → Compile → Generate

**Rust Side:**
```rust
use maze::{MazeOrchestrator, ModalConfig};

async fn generate_code(source: &str) -> Result<String> {
    // 1. Extract constraints via Zig FFI
    let constraint_ir = extract_constraints_from_zig(source, "typescript")?;
    
    // 2. Initialize Maze orchestrator
    let config = ModalConfig::from_env()?;
    let mut orchestrator = MazeOrchestrator::new(config);
    
    // 3. Generate code with constraints
    let result = orchestrator.generate_with_constraints(
        "implement user authentication",
        vec![constraint_ir]
    ).await?;
    
    Ok(result.code)
}
```

## Maintenance

### Adding New Fields

1. Add field to both Zig and Rust structs
2. Update conversion functions (`to_ffi`, `from_ffi`)
3. Update cleanup functions
4. Add tests for new field
5. Update this documentation

### Debugging Tips

1. **Memory Leaks**: Run with `valgrind` or Zig's leak detector
2. **Corruption**: Enable ASAN/MSAN in both Zig and Rust
3. **Performance**: Use `perf` or Instruments to profile
4. **Validation**: Add assertions at FFI boundary

## References

- Zig FFI Implementation: `/Users/rand/src/ananke/src/ffi/zig_ffi.zig`
- Rust FFI Implementation: `/Users/rand/src/ananke/maze/src/ffi.rs`
- Constraint Types: `/Users/rand/src/ananke/src/types/constraint.zig`
- Integration Tests: `/Users/rand/src/ananke/test/integration/`
