# Ananke FFI Integration Guide

**Version**: 1.0  
**Last Updated**: 2025-11-24  
**Audience**: Third-party developers integrating with Ananke

## Overview

This guide explains how to integrate Ananke's Zig constraint engines (Clew/Braid) from other languages via C FFI. The FFI layer provides a stable C-compatible API that can be called from Rust, C, C++, Go, Python, and any language with C interop support.

**See Also**: [`/Users/rand/src/ananke/test/integration/FFI_CONTRACT.md`](../test/integration/FFI_CONTRACT.md) for detailed FFI contract specification.

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Integration from Rust](#integration-from-rust)
3. [Integration from C/C++](#integration-from-cc)
4. [Integration from Go](#integration-from-go)
5. [Integration from Python](#integration-from-python)
6. [Memory Management Best Practices](#memory-management-best-practices)
7. [Error Handling Patterns](#error-handling-patterns)
8. [Performance Optimization](#performance-optimization)
9. [Thread Safety](#thread-safety)

---

## Quick Start

### Building the FFI Library

```bash
# Build Zig library
cd /Users/rand/src/ananke
zig build -Doptimize=ReleaseFast

# Output: zig-out/lib/libananke.a (static library)
#         zig-out/lib/libananke.so (dynamic library, Linux)
#         zig-out/lib/libananke.dylib (dynamic library, macOS)
```

### Header File

The FFI functions are declared in `src/ffi/zig_ffi.zig` and automatically export C-compatible symbols. Generate a header file:

```bash
# Extract function signatures to header
cat > ananke.h << 'HEADER'
#ifndef ANANKE_H
#define ANANKE_H

#include <stdint.h>
#include <stddef.h>

// Error codes
typedef enum {
    ANANKE_SUCCESS = 0,
    ANANKE_NULL_POINTER = 1,
    ANANKE_ALLOCATION_FAILURE = 2,
    ANANKE_INVALID_INPUT = 3,
    ANANKE_EXTRACTION_FAILED = 4,
    ANANKE_COMPILATION_FAILED = 5,
} AnankeError;

// Opaque constraint IR structure
typedef struct ConstraintIRFFI ConstraintIRFFI;

// Initialize Ananke (call once at startup)
int ananke_init(void);

// Cleanup Ananke (call once at shutdown)
void ananke_deinit(void);

// Extract constraints from source code
// source: null-terminated source code string
// language: null-terminated language name ("typescript", "python", etc.)
// out_ir: pointer to receive allocated ConstraintIRFFI (must be freed)
// Returns: error code (0 = success)
int ananke_extract_constraints(
    const char* source,
    const char* language,
    ConstraintIRFFI** out_ir
);

// Free a ConstraintIRFFI structure
void ananke_free_constraint_ir(ConstraintIRFFI* ir);

// Get version string (does not need to be freed)
const char* ananke_version(void);

#endif // ANANKE_H
HEADER
```

### Basic Usage (C)

```c
#include "ananke.h"
#include <stdio.h>
#include <stdlib.h>

int main() {
    // 1. Initialize
    int result = ananke_init();
    if (result != 0) {
        fprintf(stderr, "Failed to initialize Ananke\n");
        return 1;
    }
    
    // 2. Extract constraints
    const char* source = "function add(a: number, b: number): number { return a + b; }";
    const char* language = "typescript";
    ConstraintIRFFI* ir = NULL;
    
    result = ananke_extract_constraints(source, language, &ir);
    if (result != 0) {
        fprintf(stderr, "Extraction failed: %d\n", result);
        ananke_deinit();
        return 1;
    }
    
    // 3. Use constraint IR
    printf("Extracted constraints successfully\n");
    
    // 4. Cleanup
    ananke_free_constraint_ir(ir);
    ananke_deinit();
    
    return 0;
}
```

Compile:
```bash
gcc -o example example.c \
    -I/Users/rand/src/ananke/zig-out/include \
    -L/Users/rand/src/ananke/zig-out/lib \
    -lananke
```

---

## Integration from Rust

### Setup

**Cargo.toml**:
```toml
[dependencies]
anyhow = "1.0"
libc = "0.2"
```

**Build script** (`build.rs`):
```rust
fn main() {
    // Link against Ananke library
    println!("cargo:rustc-link-search=native=/Users/rand/src/ananke/zig-out/lib");
    println!("cargo:rustc-link-lib=static=ananke");
}
```

### FFI Declarations

```rust
use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_int};
use anyhow::{Result, anyhow};

// Error codes
const ANANKE_SUCCESS: c_int = 0;
const ANANKE_EXTRACTION_FAILED: c_int = 4;

// Opaque IR structure
#[repr(C)]
pub struct ConstraintIRFFI {
    _private: [u8; 0],
}

extern "C" {
    fn ananke_init() -> c_int;
    fn ananke_deinit();
    fn ananke_extract_constraints(
        source: *const c_char,
        language: *const c_char,
        out_ir: *mut *mut ConstraintIRFFI,
    ) -> c_int;
    fn ananke_free_constraint_ir(ir: *mut ConstraintIRFFI);
    fn ananke_version() -> *const c_char;
}
```

### Safe Wrapper

```rust
pub struct Ananke {
    initialized: bool,
}

impl Ananke {
    pub fn new() -> Result<Self> {
        unsafe {
            let result = ananke_init();
            if result != ANANKE_SUCCESS {
                return Err(anyhow!("Failed to initialize Ananke: {}", result));
            }
        }
        Ok(Ananke { initialized: true })
    }
    
    pub fn extract_constraints(
        &self,
        source: &str,
        language: &str,
    ) -> Result<ConstraintIR> {
        if !self.initialized {
            return Err(anyhow!("Ananke not initialized"));
        }
        
        let source_c = CString::new(source)?;
        let language_c = CString::new(language)?;
        let mut ir_ptr: *mut ConstraintIRFFI = std::ptr::null_mut();
        
        unsafe {
            let result = ananke_extract_constraints(
                source_c.as_ptr(),
                language_c.as_ptr(),
                &mut ir_ptr,
            );
            
            if result != ANANKE_SUCCESS {
                return Err(anyhow!("Extraction failed: {}", result));
            }
            
            // Convert to Rust-owned structure
            let ir = self.convert_ir(ir_ptr)?;
            
            // Free Zig memory
            ananke_free_constraint_ir(ir_ptr);
            
            Ok(ir)
        }
    }
    
    fn convert_ir(&self, ffi_ptr: *const ConstraintIRFFI) -> Result<ConstraintIR> {
        // Convert FFI structure to Rust types
        // (Full implementation in maze/src/ffi.rs)
        unimplemented!("See maze/src/ffi.rs for full implementation")
    }
    
    pub fn version(&self) -> String {
        unsafe {
            let version_ptr = ananke_version();
            CStr::from_ptr(version_ptr)
                .to_string_lossy()
                .into_owned()
        }
    }
}

impl Drop for Ananke {
    fn drop(&mut self) {
        if self.initialized {
            unsafe {
                ananke_deinit();
            }
            self.initialized = false;
        }
    }
}

// Rust-friendly constraint IR
pub struct ConstraintIR {
    pub json_schema: Option<String>,
    pub grammar: Option<String>,
    pub regex_patterns: Vec<String>,
    pub priority: u32,
    pub name: String,
}
```

### Usage Example

```rust
use anyhow::Result;

fn main() -> Result<()> {
    // Initialize Ananke
    let ananke = Ananke::new()?;
    
    println!("Ananke version: {}", ananke.version());
    
    // Extract constraints
    let source = r#"
        function authenticate(user: string, password: string): boolean {
            return validateCredentials(user, password);
        }
    "#;
    
    let ir = ananke.extract_constraints(source, "typescript")?;
    
    println!("Extracted {} patterns", ir.regex_patterns.len());
    
    Ok(())
}
```

**Complete Implementation**: See `/Users/rand/src/ananke/maze/src/ffi.rs` for production-ready Rust FFI wrapper.

---

## Integration from C/C++

### C Example (Complete)

**example.c**:
```c
#include "ananke.h"
#include <stdio.h>
#include <string.h>
#include <assert.h>

int main() {
    // Initialize
    int result = ananke_init();
    assert(result == ANANKE_SUCCESS);
    
    // Get version
    const char* version = ananke_version();
    printf("Ananke version: %s\n", version);
    
    // Extract constraints from TypeScript code
    const char* typescript_code = 
        "async function fetchUser(id: number): Promise<User> {\n"
        "    const response = await fetch(`/api/users/${id}`);\n"
        "    return response.json();\n"
        "}\n";
    
    ConstraintIRFFI* ir = NULL;
    result = ananke_extract_constraints(
        typescript_code,
        "typescript",
        &ir
    );
    
    if (result != ANANKE_SUCCESS) {
        fprintf(stderr, "Extraction failed: %d\n", result);
        ananke_deinit();
        return 1;
    }
    
    printf("Constraints extracted successfully\n");
    
    // Cleanup
    ananke_free_constraint_ir(ir);
    ananke_deinit();
    
    return 0;
}
```

### C++ Example (RAII Wrapper)

**ananke_wrapper.hpp**:
```cpp
#ifndef ANANKE_WRAPPER_HPP
#define ANANKE_WRAPPER_HPP

#include "ananke.h"
#include <string>
#include <memory>
#include <stdexcept>

namespace ananke {

class Exception : public std::runtime_error {
public:
    Exception(int code, const std::string& msg)
        : std::runtime_error(msg), code_(code) {}
    
    int code() const { return code_; }
    
private:
    int code_;
};

class ConstraintIR {
public:
    explicit ConstraintIR(ConstraintIRFFI* ptr) : ptr_(ptr) {}
    
    ~ConstraintIR() {
        if (ptr_) {
            ananke_free_constraint_ir(ptr_);
        }
    }
    
    // Move-only
    ConstraintIR(ConstraintIR&& other) noexcept
        : ptr_(other.ptr_) {
        other.ptr_ = nullptr;
    }
    
    ConstraintIR& operator=(ConstraintIR&& other) noexcept {
        if (this != &other) {
            if (ptr_) {
                ananke_free_constraint_ir(ptr_);
            }
            ptr_ = other.ptr_;
            other.ptr_ = nullptr;
        }
        return *this;
    }
    
    // Delete copy
    ConstraintIR(const ConstraintIR&) = delete;
    ConstraintIR& operator=(const ConstraintIR&) = delete;
    
private:
    ConstraintIRFFI* ptr_;
};

class Ananke {
public:
    Ananke() {
        int result = ananke_init();
        if (result != ANANKE_SUCCESS) {
            throw Exception(result, "Failed to initialize Ananke");
        }
    }
    
    ~Ananke() {
        ananke_deinit();
    }
    
    std::string version() const {
        return ananke_version();
    }
    
    ConstraintIR extract_constraints(
        const std::string& source,
        const std::string& language
    ) {
        ConstraintIRFFI* ir = nullptr;
        int result = ananke_extract_constraints(
            source.c_str(),
            language.c_str(),
            &ir
        );
        
        if (result != ANANKE_SUCCESS) {
            throw Exception(result, "Extraction failed");
        }
        
        return ConstraintIR(ir);
    }
};

} // namespace ananke

#endif // ANANKE_WRAPPER_HPP
```

**Usage**:
```cpp
#include "ananke_wrapper.hpp"
#include <iostream>

int main() {
    try {
        ananke::Ananke ananke;
        
        std::cout << "Version: " << ananke.version() << std::endl;
        
        std::string source = R"(
            fn calculate(x: i32, y: i32) -> i32 {
                x + y
            }
        )";
        
        auto ir = ananke.extract_constraints(source, "rust");
        
        std::cout << "Constraints extracted" << std::endl;
        
    } catch (const ananke::Exception& e) {
        std::cerr << "Error: " << e.what() << " (code " << e.code() << ")" << std::endl;
        return 1;
    }
    
    return 0;
}
```

---

## Integration from Go

### Setup

**Create Go module**:
```bash
mkdir ananke-go
cd ananke-go
go mod init github.com/youruser/ananke-go
```

### CGo Bindings

**ananke.go**:
```go
package ananke

/*
#cgo CFLAGS: -I/Users/rand/src/ananke/zig-out/include
#cgo LDFLAGS: -L/Users/rand/src/ananke/zig-out/lib -lananke

#include <stdlib.h>

typedef struct ConstraintIRFFI ConstraintIRFFI;

int ananke_init(void);
void ananke_deinit(void);
int ananke_extract_constraints(
    const char* source,
    const char* language,
    ConstraintIRFFI** out_ir
);
void ananke_free_constraint_ir(ConstraintIRFFI* ir);
const char* ananke_version(void);
*/
import "C"

import (
    "errors"
    "unsafe"
)

// Error codes
const (
    Success            = 0
    NullPointer        = 1
    AllocationFailure  = 2
    InvalidInput       = 3
    ExtractionFailed   = 4
    CompilationFailed  = 5
)

type ConstraintIR struct {
    handle *C.ConstraintIRFFI
}

type Ananke struct {
    initialized bool
}

// New creates and initializes a new Ananke instance
func New() (*Ananke, error) {
    result := C.ananke_init()
    if result != Success {
        return nil, errors.New("failed to initialize Ananke")
    }
    return &Ananke{initialized: true}, nil
}

// Close cleans up Ananke resources
func (a *Ananke) Close() {
    if a.initialized {
        C.ananke_deinit()
        a.initialized = false
    }
}

// Version returns the Ananke version string
func (a *Ananke) Version() string {
    version := C.ananke_version()
    return C.GoString(version)
}

// ExtractConstraints extracts constraints from source code
func (a *Ananke) ExtractConstraints(source, language string) (*ConstraintIR, error) {
    if !a.initialized {
        return nil, errors.New("Ananke not initialized")
    }
    
    cSource := C.CString(source)
    defer C.free(unsafe.Pointer(cSource))
    
    cLanguage := C.CString(language)
    defer C.free(unsafe.Pointer(cLanguage))
    
    var handle *C.ConstraintIRFFI
    result := C.ananke_extract_constraints(cSource, cLanguage, &handle)
    
    if result != Success {
        return nil, errors.New("extraction failed")
    }
    
    return &ConstraintIR{handle: handle}, nil
}

// Free releases the constraint IR resources
func (ir *ConstraintIR) Free() {
    if ir.handle != nil {
        C.ananke_free_constraint_ir(ir.handle)
        ir.handle = nil
    }
}
```

### Usage Example

**main.go**:
```go
package main

import (
    "fmt"
    "log"
    
    "github.com/youruser/ananke-go"
)

func main() {
    // Initialize Ananke
    a, err := ananke.New()
    if err != nil {
        log.Fatal(err)
    }
    defer a.Close()
    
    fmt.Println("Ananke version:", a.Version())
    
    // Extract constraints
    source := `
    func authenticate(username, password string) bool {
        return validateUser(username, password)
    }
    `
    
    ir, err := a.ExtractConstraints(source, "go")
    if err != nil {
        log.Fatal(err)
    }
    defer ir.Free()
    
    fmt.Println("Constraints extracted successfully")
}
```

**Run**:
```bash
go run main.go
```

---

## Integration from Python

### Setup with ctypes

**ananke.py**:
```python
import ctypes
from pathlib import Path
from typing import Optional

# Load library
lib_path = Path("/Users/rand/src/ananke/zig-out/lib/libananke.dylib")  # macOS
# lib_path = Path("/Users/rand/src/ananke/zig-out/lib/libananke.so")  # Linux
lib = ctypes.CDLL(str(lib_path))

# Define error codes
SUCCESS = 0
EXTRACTION_FAILED = 4

# Define function signatures
lib.ananke_init.restype = ctypes.c_int
lib.ananke_init.argtypes = []

lib.ananke_deinit.restype = None
lib.ananke_deinit.argtypes = []

lib.ananke_extract_constraints.restype = ctypes.c_int
lib.ananke_extract_constraints.argtypes = [
    ctypes.c_char_p,  # source
    ctypes.c_char_p,  # language
    ctypes.POINTER(ctypes.c_void_p),  # out_ir
]

lib.ananke_free_constraint_ir.restype = None
lib.ananke_free_constraint_ir.argtypes = [ctypes.c_void_p]

lib.ananke_version.restype = ctypes.c_char_p
lib.ananke_version.argtypes = []

class AnankeError(Exception):
    pass

class ConstraintIR:
    def __init__(self, handle):
        self.handle = handle
    
    def __del__(self):
        if self.handle:
            lib.ananke_free_constraint_ir(self.handle)
            self.handle = None

class Ananke:
    def __init__(self):
        result = lib.ananke_init()
        if result != SUCCESS:
            raise AnankeError(f"Failed to initialize: {result}")
        self.initialized = True
    
    def __del__(self):
        if self.initialized:
            lib.ananke_deinit()
            self.initialized = False
    
    def __enter__(self):
        return self
    
    def __exit__(self, *args):
        self.__del__()
    
    def version(self) -> str:
        return lib.ananke_version().decode('utf-8')
    
    def extract_constraints(self, source: str, language: str) -> ConstraintIR:
        if not self.initialized:
            raise AnankeError("Ananke not initialized")
        
        source_bytes = source.encode('utf-8')
        language_bytes = language.encode('utf-8')
        handle = ctypes.c_void_p()
        
        result = lib.ananke_extract_constraints(
            source_bytes,
            language_bytes,
            ctypes.byref(handle)
        )
        
        if result != SUCCESS:
            raise AnankeError(f"Extraction failed: {result}")
        
        return ConstraintIR(handle)
```

### Usage Example

**main.py**:
```python
from ananke import Ananke

def main():
    with Ananke() as ananke:
        print(f"Ananke version: {ananke.version()}")
        
        source = """
        def calculate(x: int, y: int) -> int:
            return x + y
        """
        
        ir = ananke.extract_constraints(source, "python")
        print("Constraints extracted successfully")

if __name__ == "__main__":
    main()
```

---

## Memory Management Best Practices

### Golden Rule

**The allocator that creates memory is responsible for freeing it.**

### Zig → Other Language

```
1. Zig allocates (ananke_extract_constraints)
2. Other language converts to owned types (deep copy)
3. Other language calls ananke_free_constraint_ir
4. Zig deallocates
```

### Common Pitfalls

**❌ Using pointer after free**:
```rust
let ir_ptr = extract_constraints(...);
let ir = convert_ir(ir_ptr);  // Reads from pointer
free_constraint_ir(ir_ptr);   // Frees pointer
// ir now contains dangling pointers!
```

**✅ Deep copy before free**:
```rust
let ir_ptr = extract_constraints(...);
let ir = convert_ir_deep_copy(ir_ptr);  // Owns all data
free_constraint_ir(ir_ptr);  // Safe to free
// ir is independent of Zig memory
```

### Leak Detection

**Zig side** (automatic):
```bash
# GPA automatically detects leaks
zig build test -Doptimize=Debug
# Output: "All allocations freed" or leak report
```

**Rust side** (Valgrind):
```bash
cd maze
cargo build
valgrind --leak-check=full ./target/debug/maze_tests
```

---

## Error Handling Patterns

### Check All Return Values

```c
int result = ananke_extract_constraints(source, language, &ir);
if (result != ANANKE_SUCCESS) {
    // Handle error
    switch (result) {
        case ANANKE_NULL_POINTER:
            fprintf(stderr, "Null pointer passed\n");
            break;
        case ANANKE_EXTRACTION_FAILED:
            fprintf(stderr, "Extraction failed\n");
            break;
        default:
            fprintf(stderr, "Unknown error: %d\n", result);
    }
    return result;
}
```

### Validate Pointers

```rust
unsafe {
    if out_ptr.is_null() {
        return Err(anyhow!("Null output pointer"));
    }
    
    if (*out_ptr).json_schema.is_null() {
        // json_schema is optional, this is okay
    } else {
        // Convert non-null field
        let schema = CStr::from_ptr((*out_ptr).json_schema)
            .to_str()
            .context("Invalid UTF-8 in JSON schema")?;
    }
}
```

### Resource Cleanup

**C (error paths)**:
```c
ConstraintIRFFI* ir = NULL;
int result = ananke_extract_constraints(source, language, &ir);
if (result != ANANKE_SUCCESS) {
    // ir is still NULL, no cleanup needed
    return result;
}

// Use ir...

// Always cleanup on success path
ananke_free_constraint_ir(ir);
```

**Rust (RAII)**:
```rust
struct AnankeGuard(*mut ConstraintIRFFI);

impl Drop for AnankeGuard {
    fn drop(&mut self) {
        unsafe {
            ananke_free_constraint_ir(self.0);
        }
    }
}

// Automatic cleanup on scope exit
let guard = AnankeGuard(ir_ptr);
```

---

## Performance Optimization

### Minimize FFI Crossings

**❌ Multiple calls**:
```rust
for file in files {
    let ir = extract_constraints(file, "typescript")?;
    process(ir);
}
// Many FFI crossings (slow)
```

**✅ Batch processing**:
```rust
// Merge files, extract once
let combined = files.join("\n\n");
let ir = extract_constraints(&combined, "typescript")?;
// Single FFI crossing (fast)
```

### Reuse Ananke Instance

**❌ Create/destroy per request**:
```rust
for request in requests {
    let ananke = Ananke::new()?;  // Expensive
    let ir = ananke.extract(...)?;
    drop(ananke);  // Expensive
}
```

**✅ Single instance**:
```rust
let ananke = Ananke::new()?;
for request in requests {
    let ir = ananke.extract(...)?;  // Fast
}
```

### Cache Compiled Constraints

See Maze implementation (`maze/src/lib.rs`) for production LRU cache.

---

## Thread Safety

### Current Status

**NOT thread-safe**: Ananke uses a global allocator without synchronization.

### Workarounds

**Option 1: Serialize access**:
```rust
lazy_static! {
    static ref ANANKE_MUTEX: Mutex<Ananke> = Mutex::new(Ananke::new().unwrap());
}

// In worker thread
let ananke = ANANKE_MUTEX.lock().unwrap();
let ir = ananke.extract_constraints(source, language)?;
```

**Option 2: Thread-local instances**:
```rust
thread_local! {
    static ANANKE: RefCell<Ananke> = RefCell::new(Ananke::new().unwrap());
}

// In worker thread
ANANKE.with(|ananke| {
    ananke.borrow().extract_constraints(source, language)
})?;
```

### Future: Thread-Safe API

Phase 8 will add thread-safe FFI with per-thread allocators or mutex-protected global state.

---

## Complete Examples

See repository for complete working examples:

- **Rust**: `/Users/rand/src/ananke/maze/src/ffi.rs`
- **Rust Tests**: `/Users/rand/src/ananke/maze/tests/zig_integration_test.rs`
- **Zig Tests**: `/Users/rand/src/ananke/test/integration/e2e_pipeline_test.zig`

---

## References

- **FFI Contract**: `/Users/rand/src/ananke/test/integration/FFI_CONTRACT.md`
- **FFI Implementation**: `/Users/rand/src/ananke/src/ffi/zig_ffi.zig`
- **Rust FFI Bridge**: `/Users/rand/src/ananke/maze/src/ffi.rs`
- **E2E Tests**: `/Users/rand/src/ananke/test/integration/E2E_TEST_REPORT.md`

**Document Version**: 1.0  
**Maintained By**: Claude Code (docs-writer subagent)  
**Last Updated**: 2025-11-24
