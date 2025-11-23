# Ananke Zig Test Infrastructure Strategy

**Date**: November 23, 2025  
**Status**: Comprehensive Strategy Document  
**Target**: Zig constraint-driven code generation engine

---

## Executive Summary

This document defines a comprehensive test infrastructure strategy for the Ananke Zig project. The strategy balances unit testing for correctness, integration testing for end-to-end validation, and performance testing to maintain target latency benchmarks (<100ms extraction, <50ms compilation).

The Ananke project comprises three core subsystems:
- **Clew**: Constraint extraction engine
- **Braid**: Constraint compilation engine  
- **Ariadne**: Constraint DSL compiler (optional)

Supported by:
- **Types**: Core constraint and intent types
- **API**: Claude client and HTTP integration
- **FFI**: C ABI bridge for Rust Maze integration

---

## 1. Unit Test Strategy

### 1.1 Test Organization

```
test/
├── types/
│   ├── constraint_tests.zig          # Constraint type tests
│   └── intent_tests.zig               # Intent type tests
├── clew/
│   ├── extraction_tests.zig           # Constraint extraction
│   ├── cache_tests.zig                # Extraction caching
│   ├── type_analysis_tests.zig        # Type constraint detection
│   └── syntax_analysis_tests.zig      # Syntactic constraint detection
├── braid/
│   ├── compilation_tests.zig          # IR compilation
│   ├── graph_tests.zig                # Dependency graph analysis
│   ├── conflict_detection_tests.zig   # Conflict identification
│   ├── conflict_resolution_tests.zig  # Resolution strategies
│   └── schema_generation_tests.zig    # llguidance schema output
├── ariadne/
│   ├── parser_tests.zig               # Ariadne DSL parsing
│   ├── compiler_tests.zig             # DSL compilation
│   └── error_tests.zig                # Error handling
├── api/
│   ├── claude_client_tests.zig        # Claude API integration
│   └── http_tests.zig                 # HTTP primitives
└── integration/
    ├── full_pipeline_tests.zig        # End-to-end pipeline
    ├── cache_behavior_tests.zig       # Multi-component caching
    └── error_propagation_tests.zig    # Error handling across layers
```

### 1.2 Naming Conventions

Test files follow the pattern: `{module}_tests.zig`

Test functions follow behavior-oriented naming:
```zig
test "constraint: creation with default values" { ... }
test "constraint: serialization roundtrip" { ... }
test "extraction: syntactic constraints from simple code" { ... }
test "extraction: cache hit returns identical result" { ... }
test "compilation: dependency graph construction" { ... }
test "compilation: conflict detection is O(n²/k)" { ... }
test "braid: converts constraints to json schema" { ... }
```

Test organization within files:
```zig
const std = @import("std");
const testing = std.testing;
const ananke = @import("ananke");

// Setup fixtures
const SAMPLE_CODE_TS = @embedFile("fixtures/sample.ts");

// Group tests by behavior
test "module: feature - behavior description" { ... }

// Helper functions for common operations
fn setupAllocator() std.mem.Allocator { ... }
fn createSampleConstraint() Constraint { ... }
```

### 1.3 Coverage Targets by Module

#### **Types Module** (100% coverage)
- Constraint creation and initialization
- Enum variants (ConstraintKind, Severity, ConstraintSource)
- Struct field validation
- ConstraintSet operations (add, iteration)
- ConstraintIR serialization
- TokenMaskRules application
- Union type handling (ConstraintSource variants)

**Rationale**: Types are the foundation; any bug propagates everywhere.

#### **Clew Module** (>90% coverage)
- `extractFromCode()`: Syntactic, type, and semantic constraints
- `extractFromTests()`: Test assertion parsing and conversion
- `extractFromTelemetry()`: Telemetry-based constraint generation
- Cache operations: get, put, hit rates
- Claude API integration (mocked)
- Language-specific patterns (TypeScript, Python, Rust, etc.)
- Edge cases: empty code, malformed input, large files
- Performance constraints: <100ms for typical files

**Out of scope for unit tests**:
- Actual Tree-sitter integration (disabled pending Zig 0.15.x fix)
- Real Claude API calls (use mocks)

#### **Braid Module** (>90% coverage)
- Dependency graph construction
- Conflict detection (all conflict types)
- Conflict resolution strategies (default + Claude-assisted)
- IR compilation from constraints
- JSON schema generation
- Grammar rule compilation
- Regex pattern extraction
- Token mask generation
- llguidance schema serialization
- Caching behavior

**Target**: Validate compilation correctness and performance (<50ms).

#### **Ariadne Module** (>80% coverage)
- DSL parsing (when enabled)
- Constraint compilation from DSL
- Error reporting
- Integration with Clew/Braid

**Note**: Parser will be in `src/ariadne/test_parser.zig` (already exists).

#### **API Module** (>85% coverage)
- HTTP client basics (mocked)
- Claude client integration (mocked)
- Request construction
- Response parsing
- Error handling
- Retry logic

**Mocking Strategy**: Use `std.testing.allocator` + stubbed API implementations.

---

### 1.4 Mock/Stub Strategies

#### **Claude API Mocking**

```zig
// In tests/api/claude_client_tests.zig

const MockClaudeClient = struct {
    responses: std.StringHashMap([]const u8),
    call_count: usize = 0,
    allocator: std.mem.Allocator,

    fn init(allocator: std.mem.Allocator) !MockClaudeClient {
        return .{
            .allocator = allocator,
            .responses = std.StringHashMap([]const u8).init(allocator),
        };
    }

    fn analyzeCode(self: *MockClaudeClient, source: []const u8, language: []const u8) ![]Constraint {
        self.call_count += 1;
        
        // Return hardcoded responses based on input
        if (std.mem.indexOf(u8, source, "any") != null) {
            return &[_]Constraint{ ... };
        }
        
        return &.{};
    }

    fn deinit(self: *MockClaudeClient) void {
        self.responses.deinit();
    }
};

test "clew: uses claude mock for semantic analysis" {
    var mock = try MockClaudeClient.init(testing.allocator);
    defer mock.deinit();

    var clew = try Clew.init(testing.allocator);
    defer clew.deinit();
    clew.setClaudeClient(@ptrCast(&mock));

    const constraints = try clew.extractFromCode(SOURCE, "typescript");
    try testing.expect(mock.call_count > 0);
    try testing.expect(constraints.constraints.items.len > 0);
}
```

#### **HTTP Client Mocking**

```zig
const MockHttpClient = struct {
    status: u16 = 200,
    body: []const u8 = "",
    delay_ms: u64 = 0,
    fail_after_attempts: ?usize = null,
    attempt_count: usize = 0,

    fn makeRequest(self: *MockHttpClient, ...) ![]const u8 {
        self.attempt_count += 1;
        
        if (self.fail_after_attempts) |limit| {
            if (self.attempt_count > limit) {
                return error.NetworkError;
            }
        }

        // Simulate network delay
        std.time.sleep(self.delay_ms * 1_000_000);
        
        return if (self.status == 200) self.body else error.HttpError;
    }
};
```

#### **Constraint Fixtures**

```zig
// Common test constraints for reuse

const SAMPLE_TYPE_CONSTRAINT = Constraint{
    .kind = .type_safety,
    .severity = .err,
    .name = "no_any_types",
    .description = "Forbid TypeScript 'any' type",
    .source = .{ .static_analysis = {} },
};

const SAMPLE_SYNTAX_CONSTRAINT = Constraint{
    .kind = .syntactic,
    .severity = .warning,
    .name = "function_return_types",
    .description = "All functions must have explicit return types",
    .source = .{ .static_analysis = {} },
};

const CONFLICTING_CONSTRAINTS = &[_]Constraint{
    Constraint{
        .kind = .type_safety,
        .name = "forbid_any",
        .description = "Forbid 'any' type",
        .source = .{ .static_analysis = {} },
    },
    Constraint{
        .kind = .type_safety,
        .name = "allow_any",
        .description = "Allow 'any' type for flexibility",
        .source = .{ .static_analysis = {} },
    },
};
```

---

### 1.5 Test Patterns and Best Practices

#### **Minimal Fixtures**

```zig
test "extraction: syntactic constraints from simple code" {
    var clew = try Clew.init(testing.allocator);
    defer clew.deinit();

    const simple_code = "fn hello() void { }";
    const constraints = try clew.extractFromCode(simple_code, "zig");
    defer constraints.deinit();

    try testing.expect(constraints.constraints.items.len > 0);
    try testing.expectEqualStrings("has_functions", 
        constraints.constraints.items[0].name);
}
```

#### **Realistic but Isolated Tests**

Use embedded fixtures for typical code patterns without external file I/O:

```zig
const SAMPLE_TS_CODE = @embedFile("fixtures/sample.ts");
const SAMPLE_PY_CODE = @embedFile("fixtures/sample.py");
const SAMPLE_RS_CODE = @embedFile("fixtures/sample.rs");
```

Create `test/fixtures/` directory with sample code files:
- `sample.ts`: TypeScript auth service (50-100 lines)
- `sample.py`: Python auth service (50-100 lines)  
- `sample.rs`: Rust auth service (50-100 lines)
- `large_code.zig`: >1000 lines for scaling tests
- `malformed.ts`: Invalid syntax for error handling tests

#### **Deterministic Ordering**

Tests must not depend on execution order:

```zig
// Good: Independent state
test "cache: separate entries for different inputs" {
    var cache = try ConstraintCache.init(testing.allocator);
    defer cache.deinit();

    // Each test sets up its own cache
    try cache.put("input1", constraint_set1);
    try cache.put("input2", constraint_set2);
    // ...
}

// Bad: Depends on other tests running first
// (Zig test runner doesn't guarantee order anyway)
```

#### **Cleanup and Resource Management**

Always use defer for cleanup:

```zig
test "compilation: full pipeline with memory cleanup" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var braid = try Braid.init(allocator);
    defer braid.deinit();

    var constraints = try ConstraintSet.init(allocator, "test");
    defer constraints.deinit();

    // ... test code ...
}
```

---

## 2. Integration Test Strategy

### 2.1 End-to-End Test Scenarios

Integration tests validate complete workflows spanning multiple modules.

#### **Scenario 1: Extract → Compile → Generate**

```zig
test "pipeline: extract typescript, compile, generate schema" {
    var clew = try Clew.init(testing.allocator);
    defer clew.deinit();
    
    var braid = try Braid.init(testing.allocator);
    defer braid.deinit();

    // Step 1: Extract constraints from TypeScript
    const constraints = try clew.extractFromCode(SAMPLE_TS_CODE, "typescript");
    defer constraints.deinit();

    // Step 2: Compile constraints to IR
    const ir = try braid.compile(constraints.constraints.items);

    // Step 3: Generate llguidance schema
    const schema = try braid.toLLGuidanceSchema(ir);
    defer testing.allocator.free(schema);

    // Validation: Schema is valid JSON and contains expected fields
    try testing.expect(std.mem.indexOf(u8, schema, "\"type\"") != null);
    try testing.expect(std.mem.indexOf(u8, schema, "guidance") != null);
}
```

#### **Scenario 2: Test-Driven Constraint Extraction**

```zig
test "pipeline: extract constraints from test assertions" {
    var clew = try Clew.init(testing.allocator);
    defer clew.deinit();

    const test_code = 
        \\test "array: should contain elements" {
        \\    try expect(array.len > 0);
        \\    try expectEqual(array[0], 42);
        \\}
    ;

    const constraints = try clew.extractFromTests(test_code);
    defer constraints.deinit();

    // Should extract "array must have elements" and similar
    try testing.expect(constraints.constraints.items.len > 0);
    
    for (constraints.constraints.items) |c| {
        try testing.expect(c.source == .test_mining);
    }
}
```

#### **Scenario 3: Conflict Resolution Pipeline**

```zig
test "pipeline: detect and resolve conflicting constraints" {
    var braid = try Braid.init(testing.allocator);
    defer braid.deinit();

    var conflicting = std.ArrayList(Constraint).init(testing.allocator);
    defer conflicting.deinit();

    try conflicting.append(Constraint{
        .kind = .type_safety,
        .name = "forbid_any",
        .description = "No 'any' types allowed",
        .source = .{ .static_analysis = {} },
    });
    
    try conflicting.append(Constraint{
        .kind = .type_safety,
        .name = "allow_any",
        .description = "Allow 'any' for flexibility",
        .source = .{ .static_analysis = {} },
    });

    const ir = try braid.compile(conflicting.items);
    
    // One constraint should be disabled
    try testing.expect(ir.priority > 0);
}
```

#### **Scenario 4: Multi-Language Extraction**

```zig
test "pipeline: extract constraints from multiple languages" {
    var clew = try Clew.init(testing.allocator);
    defer clew.deinit();

    const languages = &[_][]const u8{ "typescript", "python", "rust", "zig" };
    const samples = &[_][]const u8{ 
        SAMPLE_TS_CODE, SAMPLE_PY_CODE, SAMPLE_RS_CODE, SAMPLE_ZIG_CODE 
    };

    for (languages, samples) |lang, sample| {
        const constraints = try clew.extractFromCode(sample, lang);
        defer constraints.deinit();

        // Each language should produce some constraints
        try testing.expect(constraints.constraints.items.len > 0);
    }
}
```

#### **Scenario 5: Ananke Root Pipeline**

```zig
test "ananke: full initialization and pipeline" {
    var ananke = try Ananke.init(testing.allocator);
    defer ananke.deinit();

    // Extract constraints
    const constraints = try ananke.extract(SAMPLE_TS_CODE, "typescript");
    defer constraints.deinit();

    // Compile constraints
    const ir = try ananke.compile(constraints.constraints.items);

    // Validate IR produced
    try testing.expect(ir.priority >= 0);
}
```

### 2.2 Test Data Fixtures

Create realistic but minimal sample files:

#### `test/fixtures/sample.ts` (50-80 lines)
```typescript
// Auth service in TypeScript
interface User {
  id: string;
  email: string;
  role: 'admin' | 'user';
}

async function authenticate(email: string, password: string): Promise<User> {
  if (!email || !password) {
    throw new Error('Email and password required');
  }
  
  const user = await db.findUser(email);
  if (!user) {
    return null;
  }
  
  const valid = await bcrypt.compare(password, user.hash);
  return valid ? user : null;
}
```

Expected constraints:
- Type safety: All function parameters typed
- Semantic: Error handling via exceptions
- Architectural: Database separation of concerns

#### `test/fixtures/sample.py` (50-80 lines)
```python
# Auth service in Python
from dataclasses import dataclass
from typing import Optional
import bcrypt

@dataclass
class User:
    id: str
    email: str
    role: str

def authenticate(email: str, password: str) -> Optional[User]:
    """Authenticate user by email and password."""
    if not email or not password:
        raise ValueError("Email and password required")
    
    user = db.find_user(email)
    if not user:
        return None
    
    valid = bcrypt.checkpw(password.encode(), user.hash)
    return user if valid else None
```

#### `test/fixtures/sample.rs` (60-90 lines)
```rust
// Auth service in Rust
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct User {
    pub id: String,
    pub email: String,
    pub role: String,
}

pub async fn authenticate(
    email: &str, 
    password: &str
) -> Result<User, AuthError> {
    if email.is_empty() || password.is_empty() {
        return Err(AuthError::InvalidInput);
    }
    
    let user = db.find_user(email).await?;
    let valid = bcrypt::verify(password, &user.hash)?;
    
    if valid {
        Ok(user)
    } else {
        Err(AuthError::InvalidPassword)
    }
}
```

#### `test/fixtures/large_code.zig` (>1000 lines)
Generated for performance/scaling tests. Repeat a base pattern 10-50 times:
```zig
// Repeated function definitions to test extraction performance
pub fn function_1() void { }
pub fn function_2() i32 { return 0; }
pub fn function_3(x: i32) i32 { return x + 1; }
// ... repeated 100+ times for large file testing
```

#### `test/fixtures/malformed.ts` (invalid syntax)
```typescript
// Intentionally malformed for error handling tests
function broken(: { })
const x = ;
if (true) { else }
```

### 2.3 CI/CD Integration

Add GitHub Actions workflow at `.github/workflows/test-zig.yml`:

```yaml
name: Zig Tests

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - uses: goto-bus-stop/setup-zig@v2
      with:
        version: master  # or specific version
    
    - name: Build
      run: zig build
    
    - name: Run tests
      run: zig build test
      timeout-minutes: 5
    
    - name: Run benchmarks
      run: zig build bench
      continue-on-error: true  # Don't fail CI on bench changes
    
    - name: Check formatting
      run: zig fmt --check src/ test/
```

---

## 3. Performance Test Strategy

### 3.1 Benchmarking Targets

| Component | Operation | Target | Tolerance |
|-----------|-----------|--------|-----------|
| **Clew** | Extract from 100-line file | <10ms | ±20% |
| **Clew** | Extract from 1000-line file | <100ms | ±20% |
| **Clew** | Cache hit retrieval | <1ms | ±50% |
| **Braid** | Compile 10 constraints | <10ms | ±20% |
| **Braid** | Compile 100 constraints | <50ms | ±20% |
| **Braid** | Conflict detection (100 constraints) | <50ms | ±30% |
| **Braid** | Generate llguidance schema | <5ms | ±50% |

### 3.2 Benchmark Implementation

Expand existing bench files with systematic measurements:

#### `benches/zig/clew_bench.zig`

```zig
const std = @import("std");
const Clew = @import("clew").Clew;

const SMALL_CODE = @embedFile("../fixtures/sample.ts");
const LARGE_CODE = @embedFile("../fixtures/large_code.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var clew = try Clew.init(allocator);
    defer clew.deinit();

    std.debug.print("\n=== Clew Extraction Benchmarks ===\n\n", .{});

    // Benchmark: Extract from small file
    try benchmarkExtraction(allocator, &clew, "Small file (50-100 lines)", SMALL_CODE, "typescript", 1000);
    
    // Benchmark: Extract from large file
    try benchmarkExtraction(allocator, &clew, "Large file (1000+ lines)", LARGE_CODE, "zig", 100);

    // Benchmark: Cache performance
    try benchmarkCache(&clew, SMALL_CODE, 10000);

    // Benchmark: Multi-language extraction
    try benchmarkMultiLanguage(&clew, 100);
}

fn benchmarkExtraction(
    allocator: std.mem.Allocator,
    clew: *Clew,
    label: []const u8,
    code: []const u8,
    language: []const u8,
    iterations: u32,
) !void {
    var timer = try std.time.Timer.start();
    
    for (0..iterations) |_| {
        const constraints = try clew.extractFromCode(code, language);
        constraints.deinit();
    }
    
    const elapsed = timer.read();
    const avg_ns = elapsed / iterations;
    const avg_us = avg_ns / 1000;
    
    const target_us = if (std.mem.indexOf(u8, label, "Small") != null) 10000 else 100000;
    const status = if (avg_us <= target_us) "PASS" else "WARN";
    
    std.debug.print(
        "{s}: {d} iterations in {d:.2}us avg ({s})\n",
        .{ label, iterations, @as(f64, @floatFromInt(avg_us)), status },
    );
}

fn benchmarkCache(clew: *Clew, code: []const u8, iterations: u32) !void {
    var timer = try std.time.Timer.start();
    
    // First extraction (cache miss)
    _ = try clew.extractFromCode(code, "typescript");
    
    // Subsequent extractions (cache hits)
    for (0..iterations) |_| {
        _ = try clew.extractFromCode(code, "typescript");
    }
    
    const elapsed = timer.read();
    const avg_ns = elapsed / iterations;
    
    std.debug.print(
        "Cache performance: {d} iterations in {d}ns avg\n",
        .{ iterations, avg_ns },
    );
}
```

#### `benches/zig/braid_bench.zig`

```zig
const std = @import("std");
const Braid = @import("braid").Braid;
const Constraint = @import("ananke").types.constraint.Constraint;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var braid = try Braid.init(allocator);
    defer braid.deinit();

    std.debug.print("\n=== Braid Compilation Benchmarks ===\n\n", .{});

    // Benchmark: Compile 10 constraints
    try benchmarkCompilation(&braid, allocator, 10, 1000);
    
    // Benchmark: Compile 100 constraints
    try benchmarkCompilation(&braid, allocator, 100, 100);

    // Benchmark: Conflict detection
    try benchmarkConflictDetection(&braid, allocator, 100, 10);

    // Benchmark: Schema generation
    try benchmarkSchemaGeneration(&braid, allocator, 100);
}

fn benchmarkCompilation(
    braid: *Braid,
    allocator: std.mem.Allocator,
    constraint_count: u32,
    iterations: u32,
) !void {
    // Generate constraint set
    var constraints = std.ArrayList(Constraint).init(allocator);
    defer constraints.deinit();

    for (0..constraint_count) |i| {
        try constraints.append(Constraint{
            .kind = @as(ConstraintKind, @enumFromInt(@mod(i, 6))),
            .severity = .warning,
            .name = "test_constraint",
            .description = "Benchmark constraint",
            .source = .{ .static_analysis = {} },
        });
    }

    var timer = try std.time.Timer.start();
    
    for (0..iterations) |_| {
        const ir = try braid.compile(constraints.items);
        _ = ir;
    }
    
    const elapsed = timer.read();
    const avg_us = elapsed / 1000 / iterations;
    
    const target_us = if (constraint_count <= 10) 10000 else 50000;
    const status = if (avg_us <= target_us) "PASS" else "WARN";
    
    std.debug.print(
        "Compile {d} constraints: {d}us avg ({s})\n",
        .{ constraint_count, avg_us, status },
    );
}
```

### 3.3 Performance Regression Detection

Store baseline benchmarks in `benchmarks/baselines.json`:

```json
{
  "clew_extract_small": {
    "target_us": 10000,
    "tolerance_percent": 20,
    "baseline_us": 9500
  },
  "clew_extract_large": {
    "target_us": 100000,
    "tolerance_percent": 20,
    "baseline_us": 95000
  },
  "braid_compile_10": {
    "target_us": 10000,
    "tolerance_percent": 20,
    "baseline_us": 9000
  },
  "braid_compile_100": {
    "target_us": 50000,
    "tolerance_percent": 20,
    "baseline_us": 48000
  }
}
```

Script to compare: `scripts/compare_benchmarks.zig`

### 3.4 Memory Usage Validation

Add memory profiling tests:

```zig
test "clew: memory usage stays bounded" {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .enable_memory_limit = true,
    }){};
    gpa.setRequestedLimit(50 * 1024 * 1024); // 50 MB limit
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var clew = try Clew.init(allocator);
    defer clew.deinit();

    // Extract from large file multiple times
    for (0..10) |_| {
        const constraints = try clew.extractFromCode(LARGE_CODE, "zig");
        constraints.deinit();
    }

    // If we reach here, memory usage stayed within limit
    const stats = gpa.detectLeaks();
    try testing.expect(!stats);
}
```

---

## 4. Test Fixtures

### 4.1 Directory Structure

```
test/
├── fixtures/
│   ├── sample.ts                      # Auth service (TypeScript)
│   ├── sample.py                      # Auth service (Python)
│   ├── sample.rs                      # Auth service (Rust)
│   ├── sample.zig                     # Auth service (Zig)
│   ├── large_code.zig                 # >1000 lines for scaling
│   ├── malformed.ts                   # Invalid syntax
│   └── README.md                      # Fixture documentation
├── types/
├── clew/
├── braid/
├── ariadne/
├── api/
└── integration/
```

### 4.2 Fixture Accessibility

Use `@embedFile()` to embed fixtures at compile time (recommended):

```zig
const SAMPLE_TS = @embedFile("fixtures/sample.ts");

test "extraction: sample typescript" {
    // Use embedded code directly
    const constraints = try clew.extractFromCode(SAMPLE_TS, "typescript");
}
```

Alternatively, use file I/O for dynamic fixtures:

```zig
fn loadFixture(allocator: std.mem.Allocator, filename: []const u8) ![]u8 {
    const test_dir = try std.fs.cwd().openDir("test/fixtures", .{});
    defer test_dir.close();
    
    const file = try test_dir.openFile(filename, .{});
    defer file.close();
    
    return file.readToEndAlloc(allocator, 1024 * 1024);
}
```

### 4.3 Expected Outputs for Validation

Create `test/fixtures/expected_outputs.zig`:

```zig
const Constraint = @import("ananke").types.constraint.Constraint;

pub const EXPECTED_TS_CONSTRAINTS = &[_][]const u8{
    "type_safety:no_any_types",      // TypeScript specific
    "type_safety:null_safety",       // Null handling
    "syntactic:has_functions",       // Function definitions
    "syntactic:has_interfaces",      // Interface definitions
    "architectural:module_exports",  // Module structure
};

pub const EXPECTED_PY_CONSTRAINTS = &[_][]const u8{
    "type_safety:type_hints",        // Python 3 type hints
    "syntactic:has_functions",       // Function definitions
    "syntactic:has_classes",         // Class definitions
    "operational:docstring_present", // Documentation
};
```

---

## 5. Testing Tools and Infrastructure

### 5.1 Zig Built-in Test Framework

The Zig test framework is built into the language:

```bash
# Run all tests
zig build test

# Run specific test file
zig test src/root.zig -I src

# Run with logging
zig test src/root.zig --test-filter "constraint"
```

**Features**:
- Built-in assertions via `std.testing`
- Parallel test execution
- Custom test runners
- Test filtering
- Detailed error reporting

### 5.2 Standard Testing Library

```zig
const std = @import("std");
const testing = std.testing;

test "example" {
    // Basic assertions
    try testing.expect(true);
    try testing.expect(value == expected);
    
    // Equality tests
    try testing.expectEqual(5, 5);
    try testing.expectEqualStrings("hello", "hello");
    try testing.expectEqualSlices(u8, slice1, slice2);
    
    // Error handling
    try testing.expectError(error.OutOfMemory, risky_operation());
    
    // String matching
    try testing.expectStringContains(haystack, needle);
}
```

### 5.3 Additional Testing Utilities Needed

Create `test/test_helpers.zig`:

```zig
pub const TestContext = struct {
    allocator: std.mem.Allocator,
    gpa: std.heap.GeneralPurposeAllocator(.{}),

    pub fn init() TestContext {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        return .{
            .allocator = gpa.allocator(),
            .gpa = gpa,
        };
    }

    pub fn deinit(self: *TestContext) void {
        _ = self.gpa.deinit();
    }
};

pub fn expectConstraintKind(constraint: Constraint, kind: ConstraintKind) !void {
    try testing.expectEqual(kind, constraint.kind);
}

pub fn expectConstraintNamed(constraints: []const Constraint, name: []const u8) !void {
    for (constraints) |c| {
        if (std.mem.eql(u8, c.name, name)) return;
    }
    return error.ConstraintNotFound;
}

pub fn dumpConstraints(constraints: []const Constraint) void {
    std.debug.print("Constraints ({d}):\n", .{constraints.len});
    for (constraints) |c| {
        std.debug.print("  - {s} ({s}): {s}\n", .{ c.name, @tagName(c.kind), c.description });
    }
}
```

### 5.4 Continuous Integration Recommendations

#### GitHub Actions Workflow (`.github/workflows/test.yml`)

```yaml
name: Tests

on:
  push:
    branches: [ main, develop ]
    paths: [ 'src/**', 'test/**', 'build.zig' ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    name: Unit & Integration Tests
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - uses: goto-bus-stop/setup-zig@v2
      with:
        version: master
    
    - name: Run tests
      run: zig build test
      timeout-minutes: 5
  
  benchmarks:
    name: Performance Benchmarks
    runs-on: ubuntu-latest
    needs: test
    
    steps:
    - uses: actions/checkout@v3
    
    - uses: goto-bus-stop/setup-zig@v2
    
    - name: Run benchmarks
      run: zig build bench-zig
    
    - name: Compare with baseline
      run: ./scripts/compare_benchmarks.sh
      continue-on-error: true

  format:
    name: Code Formatting
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - uses: goto-bus-stop/setup-zig@v2
    
    - name: Check formatting
      run: zig fmt --check src/ test/
```

---

## 6. Test Execution and Reporting

### 6.1 Running Tests Locally

```bash
# All tests
zig build test

# Specific module
zig test src/clew/clew.zig -I src

# With custom allocator for debugging
ASAN_OPTIONS=detect_leaks=1 zig test ...

# Verbose output
zig build test 2>&1 | tee test_output.txt
```

### 6.2 Test Summary Format

Generate a test report after execution:

```
╔════════════════════════════════════════════╗
║         Ananke Test Summary                 ║
╚════════════════════════════════════════════╝

UNIT TESTS
  Types Module................... 24 / 24 ✓
  Clew Module.................... 38 / 38 ✓
  Braid Module................... 42 / 42 ✓
  Ariadne Module................. 18 / 18 ✓
  API Module..................... 16 / 16 ✓
  ────────────────────────────────────────
  Subtotal...................... 138 / 138 ✓

INTEGRATION TESTS
  Pipeline Tests................. 12 / 12 ✓
  Error Handling................. 8 / 8   ✓
  Cache Behavior................. 6 / 6   ✓
  ────────────────────────────────────────
  Subtotal...................... 26 / 26  ✓

PERFORMANCE TESTS
  Clew Extraction................ PASS (9.8ms < 10ms)
  Braid Compilation............. PASS (48ms < 50ms)
  Cache Operations.............. PASS (0.8ms < 1ms)
  ────────────────────────────────────────
  Subtotal...................... 3 / 3   ✓

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
TOTAL.......................... 167 / 167 ✓
Execution Time...................... 3.2s
Coverage......................... 92.3%
Status.......................... PASS ✓
```

### 6.3 Coverage Measurement

While Zig doesn't have built-in coverage tools like Rust's `tarpaulin`, track coverage manually:

```bash
# Create coverage tracking file: scripts/track_coverage.sh
#!/bin/bash

echo "Module,Lines,Tested,Coverage%" > coverage.csv

for module in types clew braid ariadne api; do
    lines=$(wc -l < src/$module/$module.zig)
    # Count test blocks and assertions as proxy
    tested=$(grep -c "^test " test/$module/*.zig 2>/dev/null || echo 0)
    coverage=$((tested * 100 / $(grep -c "^pub fn\|^pub const" src/$module/$module.zig)))
    echo "$module,$lines,$tested,$coverage%" >> coverage.csv
done

cat coverage.csv
```

---

## 7. Testing Checklist

### Phase 1: Unit Tests (Week 1-2)

- [ ] **Types Tests** (constraint_tests.zig)
  - [ ] Constraint creation and initialization
  - [ ] ConstraintKind enum variants
  - [ ] Severity levels
  - [ ] ConstraintSource union types
  - [ ] ConstraintSet operations
  - [ ] ConstraintIR serialization
  - [ ] TokenMaskRules.apply()

- [ ] **Clew Tests** (extraction_tests.zig, etc.)
  - [ ] extractFromCode() with TypeScript, Python, Rust
  - [ ] Syntactic constraints extraction
  - [ ] Type constraints extraction
  - [ ] Cache hit/miss behavior
  - [ ] Large file handling
  - [ ] Malformed input handling
  - [ ] Claude API mocking

- [ ] **Braid Tests** (compilation_tests.zig, etc.)
  - [ ] Dependency graph construction
  - [ ] Conflict detection
  - [ ] Conflict resolution (default + Claude-assisted)
  - [ ] IR compilation
  - [ ] Schema generation
  - [ ] Topological sorting

### Phase 2: Integration Tests (Week 2-3)

- [ ] **Pipeline Tests** (full_pipeline_tests.zig)
  - [ ] Extract → Compile → Generate schema
  - [ ] Test-driven extraction
  - [ ] Multi-language support
  - [ ] Conflict resolution E2E
  - [ ] Ananke root initialization

- [ ] **Fixture Tests** (test/fixtures/)
  - [ ] Create sample.ts, sample.py, sample.rs
  - [ ] Create large_code.zig for scaling
  - [ ] Create malformed.ts for error handling
  - [ ] Document expected constraints

### Phase 3: Performance Tests (Week 3)

- [ ] **Clew Benchmarks**
  - [ ] Small file extraction (<10ms)
  - [ ] Large file extraction (<100ms)
  - [ ] Cache performance (<1ms)

- [ ] **Braid Benchmarks**
  - [ ] 10-constraint compilation (<10ms)
  - [ ] 100-constraint compilation (<50ms)
  - [ ] Conflict detection (<50ms)

- [ ] **Memory Tests**
  - [ ] Bounded memory growth
  - [ ] No memory leaks
  - [ ] Allocator cleanup verification

### Phase 4: CI/CD Integration (Week 4)

- [ ] Create `.github/workflows/test-zig.yml`
- [ ] Test on multiple Zig versions
- [ ] Generate test reports
- [ ] Set up benchmark baseline tracking
- [ ] Add coverage metrics

---

## 8. Maintenance and Evolution

### 8.1 Test Debt Management

Review monthly:
- Which tests are flaky?
- Which tests are slowest?
- Which modules lack coverage?
- Are fixtures still realistic?

### 8.2 Adding New Tests

When adding features:

1. **Write test first** (TDD):
   ```zig
   test "clew: new_feature - behavior description" {
       // Arrange
       var clew = try Clew.init(testing.allocator);
       defer clew.deinit();
       
       // Act
       const result = try clew.newFeature(input);
       
       // Assert
       try testing.expectEqual(expected, result);
   }
   ```

2. **Classify test**:
   - Unit: Tests single function/method in isolation
   - Integration: Tests interaction between modules
   - Performance: Measures against target metrics

3. **Add fixture if needed**:
   - Small: Use inline string or `@embedFile()`
   - Complex: Add to `test/fixtures/`

### 8.3 Updating Benchmarks

When performance regresses:

```bash
# Save baseline
cp benchmarks/baselines.json benchmarks/baselines.json.bak

# Run new benchmarks
zig build bench-zig

# Compare
diff benchmarks/baselines.json benchmarks/baselines.json.bak
```

If regression is intentional, update baseline with justification in commit message.

---

## 9. Testing Best Practices Summary

### DO
- ✓ Test behavior, not implementation
- ✓ Use descriptive test names
- ✓ Keep tests fast and isolated
- ✓ Use realistic but minimal fixtures
- ✓ Mock external dependencies (Claude API, HTTP)
- ✓ Clean up resources with `defer`
- ✓ Group related tests in same file
- ✓ Document complex test scenarios
- ✓ Run tests before committing
- ✓ Monitor performance trends

### DON'T
- ✗ Test private implementation details
- ✗ Depend on test execution order
- ✗ Share state between tests
- ✗ Use hardcoded paths or file I/O
- ✗ Call real external APIs (use mocks)
- ✗ Create tests with >10ms runtime (unless perf test)
- ✗ Ignore test failures in CI
- ✗ Write tests that are flaky
- ✗ Leave TODOs in test code
- ✗ Test Zig language features

---

## 10. Quick Reference

### Command Cheatsheet

```bash
# Run all tests
zig build test

# Run specific test file
zig test src/clew/clew.zig -I src

# Run benchmarks
zig build bench-zig
zig build bench-braid
zig build bench

# Check formatting
zig fmt --check src/ test/

# Build and test
zig build && zig build test

# Debug test failures
zig test src/root.zig -I src --verbose
```

### File Templates

#### New Unit Test File
```zig
const std = @import("std");
const testing = std.testing;
const ananke = @import("ananke");

test "module: feature - behavior description" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Arrange
    var instance = try Type.init(allocator);
    defer instance.deinit();

    // Act
    const result = try instance.method(input);

    // Assert
    try testing.expectEqual(expected, result);
}
```

#### New Integration Test
```zig
test "pipeline: scenario - expected outcome" {
    var component1 = try Component1.init(testing.allocator);
    defer component1.deinit();

    var component2 = try Component2.init(testing.allocator);
    defer component2.deinit();

    // Test interaction between components
    const intermediate = try component1.process(input);
    const final = try component2.process(intermediate);

    try testing.expectEqual(expected, final);
}
```

---

## Conclusion

This comprehensive test strategy provides:

1. **Clear organization**: Structured test directory mirroring source organization
2. **Detailed coverage targets**: Specific metrics for each module
3. **Robust patterns**: Mock strategies, fixture approaches, test templates
4. **Performance validation**: Benchmarking targets and memory profiling
5. **CI/CD integration**: Ready-to-use GitHub Actions workflow
6. **Practical guidance**: Checklists, best practices, command references

Implementation should proceed in phases:
- **Phase 1 (Week 1-2)**: Unit tests for all modules
- **Phase 2 (Week 2-3)**: Integration tests and fixtures
- **Phase 3 (Week 3)**: Performance benchmarking
- **Phase 4 (Week 4)**: CI/CD integration and reporting

This strategy enables high-confidence testing while maintaining fast iteration speed and excellent performance metrics.

---

**Document Version**: 1.0  
**Status**: Ready for Implementation  
**Last Updated**: November 23, 2025
