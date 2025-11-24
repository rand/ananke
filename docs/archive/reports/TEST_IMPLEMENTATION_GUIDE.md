# Ananke Test Implementation Quick Reference

**Document Date**: November 23, 2025  
**Quick Start**: 15-minute setup guide to start writing tests

---

## 1. Quick Setup (5 minutes)

### Step 1: Create Test Directory Structure

```bash
mkdir -p test/{types,clew,braid,ariadne,api,integration,fixtures}
```

### Step 2: Create Test Fixtures Directory

```bash
# Create empty fixture files (will add content next)
touch test/fixtures/{sample.ts,sample.py,sample.rs,sample.zig}
```

### Step 3: Create Test Helper Module

Create `/Users/rand/src/ananke/test/test_helpers.zig`:

```zig
const std = @import("std");
const testing = std.testing;
const ananke = @import("ananke");

pub fn createTestContext() !std.mem.Allocator {
    // Use testing allocator with leak detection
    return testing.allocator;
}

pub fn createSampleConstraint(
    allocator: std.mem.Allocator,
    name: []const u8,
) ananke.types.constraint.Constraint {
    _ = allocator;
    return .{
        .kind = .syntactic,
        .severity = .warning,
        .name = name,
        .description = "Test constraint",
        .source = .{ .static_analysis = {} },
    };
}

pub fn expectConstraintCount(
    constraints: []const ananke.types.constraint.Constraint,
    expected: usize,
) !void {
    try testing.expectEqual(expected, constraints.len);
}
```

---

## 2. Writing Your First Test (10 minutes)

### Example: Unit Test for Constraint Creation

Create `/Users/rand/src/ananke/test/types/constraint_tests.zig`:

```zig
const std = @import("std");
const testing = std.testing;
const ananke = @import("ananke");

const Constraint = ananke.types.constraint.Constraint;
const ConstraintKind = ananke.types.constraint.ConstraintKind;
const Severity = ananke.types.constraint.Severity;

test "constraint: creation with default values" {
    const constraint = Constraint.init(.syntactic, "test_constraint");
    
    try testing.expectEqual(ConstraintKind.syntactic, constraint.kind);
    try testing.expectEqual(Severity.err, constraint.severity);
    try testing.expectEqualStrings("test_constraint", constraint.name);
}

test "constraint: severity can be set" {
    var constraint = Constraint.init(.type_safety, "no_any");
    constraint.severity = .warning;
    
    try testing.expectEqual(Severity.warning, constraint.severity);
}

test "constraint_set: add constraints" {
    var set = ananke.types.constraint.ConstraintSet.init(
        testing.allocator,
        "test_set"
    );
    defer set.deinit();
    
    const c1 = Constraint.init(.syntactic, "constraint1");
    const c2 = Constraint.init(.type_safety, "constraint2");
    
    try set.add(c1);
    try set.add(c2);
    
    try testing.expectEqual(2, set.constraints.items.len);
    try testing.expectEqualStrings("constraint1", set.constraints.items[0].name);
    try testing.expectEqualStrings("constraint2", set.constraints.items[1].name);
}
```

Run it:
```bash
zig build test
```

---

## 3. Common Test Patterns

### Pattern 1: Testing with Allocators

```zig
test "module: feature - behavior" {
    // Option A: Simple test allocator (good for unit tests)
    const allocator = testing.allocator;
    
    var instance = try SomeType.init(allocator);
    defer instance.deinit();
    
    // Test code here
}
```

```zig
test "module: feature - with memory limits" {
    // Option B: GPA allocator with leak detection
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    var instance = try SomeType.init(allocator);
    defer instance.deinit();
    
    // Test code here
    // GPA will detect leaks on deinit
}
```

### Pattern 2: Testing Error Cases

```zig
test "cache: returns error on bad input" {
    var cache = try ConstraintCache.init(testing.allocator);
    defer cache.deinit();
    
    // Expect an error
    try testing.expectError(error.InvalidInput, cache.get(""));
    
    // Or check error handling
    const result = cache.get("valid_key");
    if (result) |data| {
        // Handle success case
    } else |err| {
        try testing.expectEqual(error.NotFound, err);
    }
}
```

### Pattern 3: Integration Test Pattern

```zig
test "pipeline: extract and compile" {
    // Setup both components
    var clew = try Clew.init(testing.allocator);
    defer clew.deinit();
    
    var braid = try Braid.init(testing.allocator);
    defer braid.deinit();
    
    // Step 1: Extract
    const constraints = try clew.extractFromCode(sample_code, "typescript");
    defer constraints.deinit();
    
    // Validate intermediate result
    try testing.expect(constraints.constraints.items.len > 0);
    
    // Step 2: Compile
    const ir = try braid.compile(constraints.constraints.items);
    
    // Validate final result
    try testing.expect(ir.priority >= 0);
}
```

### Pattern 4: Mock API Testing

```zig
const MockClaudeClient = struct {
    call_count: usize = 0,
    
    pub fn analyzeCode(
        self: *MockClaudeClient,
        _: []const u8,
        _: []const u8,
    ) ![]ananke.types.constraint.Constraint {
        self.call_count += 1;
        return &.{};  // Return empty constraints
    }
};

test "clew: uses claude client when available" {
    var clew = try Clew.init(testing.allocator);
    defer clew.deinit();
    
    var mock = MockClaudeClient{};
    clew.setClaudeClient(@ptrCast(&mock));
    
    const constraints = try clew.extractFromCode(sample_code, "typescript");
    defer constraints.deinit();
    
    try testing.expect(mock.call_count > 0);
}
```

---

## 4. Test Fixtures - Quick Setup

### Create Sample Files

#### `test/fixtures/sample.ts`
```typescript
// Minimal TypeScript example
interface User {
  id: string;
  email: string;
}

async function getUser(id: string): Promise<User | null> {
  if (!id) {
    throw new Error("ID required");
  }
  return await db.findUser(id);
}
```

#### `test/fixtures/sample.py`
```python
# Minimal Python example
from typing import Optional

class User:
    def __init__(self, id: str, email: str):
        self.id = id
        self.email = email

def get_user(id: str) -> Optional[User]:
    if not id:
        raise ValueError("ID required")
    return db.find_user(id)
```

### Use Fixtures in Tests

```zig
const SAMPLE_TS = @embedFile("fixtures/sample.ts");

test "extraction: sample typescript code" {
    var clew = try Clew.init(testing.allocator);
    defer clew.deinit();
    
    const constraints = try clew.extractFromCode(SAMPLE_TS, "typescript");
    defer constraints.deinit();
    
    try testing.expect(constraints.constraints.items.len > 0);
}
```

---

## 5. Testing Checklist by Module

### Types Module (Start Here!)
- [ ] Create `test/types/constraint_tests.zig`
- [ ] Test `Constraint.init()`
- [ ] Test `ConstraintSet` operations
- [ ] Test all `ConstraintKind` variants
- [ ] Test all `Severity` variants
- [ ] Test `TokenMaskRules.apply()`

**Example Command**:
```bash
zig test src/types/constraint.zig -I src -L test
```

### Clew Module
- [ ] Create `test/clew/extraction_tests.zig`
- [ ] Test `Clew.init()` and `deinit()`
- [ ] Test `extractFromCode()` with sample.ts
- [ ] Test `extractFromCode()` with sample.py
- [ ] Test `extractFromCode()` with sample.rs
- [ ] Test cache behavior
- [ ] Test error handling (malformed input)

### Braid Module
- [ ] Create `test/braid/compilation_tests.zig`
- [ ] Test `Braid.init()` and `deinit()`
- [ ] Test `compile()` with simple constraints
- [ ] Test `toLLGuidanceSchema()`
- [ ] Test conflict detection
- [ ] Test conflict resolution

### Integration
- [ ] Create `test/integration/pipeline_tests.zig`
- [ ] Test extract → compile → generate flow
- [ ] Test with multiple languages
- [ ] Test error propagation

---

## 6. Running Tests

### Basic Commands

```bash
# Run all tests
cd /Users/rand/src/ananke
zig build test

# Run and show all output
zig build test -- --verbose

# Run specific test pattern
zig test src/types/constraint.zig -I src

# Run with verbose timing
zig build test 2>&1 | tee test_results.txt
```

### Test Output Example

```
test "constraint: creation with default values" ... ok
test "constraint: severity can be set" ... ok
test "constraint_set: add constraints" ... ok

All tests passed.
```

---

## 7. Benchmarking Quick Start

Create `/Users/rand/src/ananke/benches/zig/simple_bench.zig`:

```zig
const std = @import("std");
const Clew = @import("clew").Clew;

const SAMPLE = "pub fn hello() void { }";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var clew = try Clew.init(allocator);
    defer clew.deinit();

    var timer = try std.time.Timer.start();
    
    const iterations = 1000;
    for (0..iterations) |_| {
        const c = try clew.extractFromCode(SAMPLE, "zig");
        c.deinit();
    }
    
    const elapsed = timer.read();
    const avg_us = elapsed / iterations / 1000;
    
    std.debug.print("Average extraction: {d}us\n", .{avg_us});
}
```

Run it:
```bash
zig build bench-clew
./zig-out/bin/clew_bench
```

---

## 8. Test File Template

Create any new test file from this template:

```zig
//! Tests for [Module Name]
//! Covers: [brief description of what's tested]

const std = @import("std");
const testing = std.testing;
const ananke = @import("ananke");

// Import what we're testing
const ModuleType = ananke.module.ModuleType;

// ============================================================================
// Fixtures and Constants
// ============================================================================

const SAMPLE_INPUT = "example input";
const EXPECTED_OUTPUT = "expected output";

// ============================================================================
// Tests
// ============================================================================

test "module: feature - expected behavior" {
    // Arrange
    var instance = try ModuleType.init(testing.allocator);
    defer instance.deinit();
    
    // Act
    const result = try instance.method(SAMPLE_INPUT);
    
    // Assert
    try testing.expectEqual(EXPECTED_OUTPUT, result);
}

test "module: error case - returns error" {
    var instance = try ModuleType.init(testing.allocator);
    defer instance.deinit();
    
    try testing.expectError(error.SomeError, instance.badMethod());
}

// ============================================================================
// Helper Functions
// ============================================================================

fn createFixture() !ModuleType {
    return try ModuleType.init(testing.allocator);
}
```

---

## 9. Common Errors and Fixes

### Error: "module not found"
```
error: module not found: 'ananke'
```
**Fix**: Make sure you run from project root:
```bash
cd /Users/rand/src/ananke
zig build test
```

### Error: "duplicate field"
```
error: duplicate field 'name' in struct initializer
```
**Fix**: Check you're not initializing the same field twice.

### Error: "expected type '[]const u8' found '[*:0]const u8'"
**Fix**: Use explicit slice:
```zig
const str: []const u8 = try allocator.dupeZ(u8, cstring);
```

### Test Hangs or Times Out
**Cause**: Infinite loop or deadlock  
**Fix**: Add debug prints to narrow down location:
```zig
std.debug.print("checkpoint 1\n", .{});
// Code that might hang
std.debug.print("checkpoint 2\n", .{});
```

---

## 10. Next Steps

1. **Start with Types**: Create `test/types/constraint_tests.zig`
2. **Then Clew**: Create `test/clew/extraction_tests.zig`
3. **Then Braid**: Create `test/braid/compilation_tests.zig`
4. **Then Integration**: Create `test/integration/pipeline_tests.zig`
5. **Add Benchmarks**: Expand benchmark files
6. **Setup CI**: Create `.github/workflows/test.yml`

**Estimated Timeline**: 
- Week 1-2: Unit tests (138 tests)
- Week 2-3: Integration tests (26 tests)
- Week 3: Performance tests
- Week 4: CI/CD integration

---

## Quick Command Reference

```bash
# Run all tests
zig build test

# Run specific test module
zig test src/types/constraint.zig -I src

# Run benchmarks
zig build bench-zig

# Format check
zig fmt --check src/ test/

# Show test output
zig build test -- --nocapture

# Run with verbose timing
zig build test --verbose

# Clean build
zig build clean && zig build test

# Check for memory leaks
ASAN_OPTIONS=detect_leaks=1 zig build test
```

---

**Ready to Start?** Begin with Section 2 "Writing Your First Test" and follow the patterns in Section 3. Good luck!
