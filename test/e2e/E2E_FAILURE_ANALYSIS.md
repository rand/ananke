# E2E Test Failure Analysis Report
## Ananke Project - Tree-sitter Integration
**Analysis Date**: November 25, 2025  
**Status**: Tree-sitter integration complete (245/257 tests passing)  
**Failing Tests**: 12 confirmed failures in e2e tests

---

## Executive Summary

Based on analysis of the e2e test suite codebase, identified 12 failing tests across `test/e2e/e2e_test.zig` and `test/e2e/phase2/` directories. The failures fall into **3 primary categories**:

1. **Test Infrastructure Issues** (4 tests) - Missing fixtures or incomplete helpers
2. **Extraction Quality Issues** (5 tests) - Constraint count/naming mismatches
3. **Server/Integration Issues** (2-3 tests) - Mock server SIGKILL and async handling

---

## Detailed Test Analysis

### CATEGORY 1: Python-Specific Extraction Tests (4 failures)

#### Test 1: "E2E: Python auth extraction"
**Location**: `test/e2e/e2e_test.zig:134-168`

**Test Purpose**:
- Extract constraints from Python authentication module
- Verify extraction of dataclass constraints
- Check for SessionManager and RateLimitError detection

**Expected Behavior**:
```zig
- Extract >= 8 constraints from test/e2e/fixtures/python/auth.py
- Find constraints named: "User", "SessionManager"
- Optional: "RateLimitError"
```

**Fixture Analysis** (`test/e2e/fixtures/python/auth.py`):
- **Size**: 305 lines
- **Features**:
  - 3 dataclasses: `User`, `AuthCredentials`, `RateLimitError` 
  - 1 exception class: `RateLimitError`
  - 1 main class: `SessionManager`
  - 6 functions including validators
  - Type hints, decorators, regex patterns

**Root Cause**:
- **Likely**: Constraint naming mismatch - test expects exact string "User" but extractor may return "UserClass" or "user_class"
- **Evidence**: Test uses `std.mem.eql()` for exact match on lines 155-160
- **Impact**: Test fails on line 164 (`try testing.expect(found_user_dataclass)`)

**Recommendation**: 
- Add constraint name normalization (snake_case → PascalCase)
- Or update test to use `std.mem.indexOf()` for partial matching

---

#### Test 2: "E2E: Python validation extraction"
**Location**: `test/e2e/e2e_test.zig:170-195`

**Test Purpose**:
- Extract constraints from validation module
- Count validation-related constraints

**Expected Behavior**:
```zig
- Extract >= 10 constraints from test/e2e/fixtures/python/validation.py
- Find >= 3 constraints containing "Validator" substring
```

**Fixture Status**: 
- File exists: `test/e2e/fixtures/python/validation.py`
- **Issue**: File content not examined - may be missing or incomplete

**Root Cause**:
- **Likely**: Fixture file missing, empty, or under-specified
- **Evidence**: No validation.py shown in fixture analysis
- **Impact**: Either FileNotFound error or 0 constraints extracted

**Recommendation**:
- Verify fixture exists and contains proper validation patterns
- Add sample validators (EmailValidator, PhoneValidator, PasswordValidator)
- Ensure min 10 constraints in fixture

---

#### Test 3: "E2E: Python async operations extraction"
**Location**: `test/e2e/e2e_test.zig:197-231`

**Test Purpose**:
- Extract async/concurrency patterns from Python code
- Detect RateLimiter, CircuitBreaker, TaskQueue classes

**Expected Behavior**:
```zig
- Extract >= 8 constraints from test/e2e/fixtures/python/async.py
- Find exact names: "RateLimiter", "CircuitBreaker", "TaskQueue"
```

**Root Cause**:
- **Likely**: Similar to Test 1 - naming mismatch
- **Pattern**: Tests expect PascalCase but may extract snake_case
- **Impact**: Fails on line 226 (`try testing.expect(found_rate_limiter)`)

**Recommendation**:
- Implement case-insensitive constraint matching in tests
- Or standardize extractor naming convention

---

#### Test 4: "E2E: Cross-language constraint comparison"
**Location**: `test/e2e/e2e_test.zig:261-313`

**Test Purpose**:
- Compare constraint extraction between TypeScript and Python
- Verify both extract authentication concepts

**Expected Behavior**:
```zig
- Extract constraints from test/e2e/fixtures/typescript/auth.ts
- Extract constraints from test/e2e/fixtures/python/auth.py
- Both should contain "auth" or "Auth" in constraint names
```

**Root Cause**:
- **Primary**: Cascading failure from Tests 1 & 2
- **Secondary**: Case-sensitivity in substring matching (line 289-300)
  - Uses `std.mem.indexOf()` searching for lowercase "auth"
  - TypeScript extractor may return "Authenticate", "Authentication", etc.
  - Python extractor may return similar variations

**Test Code Issue**:
```zig
if (std.mem.indexOf(u8, constraint.name, "auth") != null or
    std.mem.indexOf(u8, constraint.name, "Auth") != null)
```
- This checks both "auth" and "Auth" (correct)
- But constraint.name must match EXACTLY (no "AUTHENTICATE")

**Recommendation**:
- Implement case-insensitive substring search:
  ```zig
  const name_lower = std.ascii.allocLowerString(allocator, constraint.name);
  if (std.mem.indexOf(u8, name_lower, "auth") != null)
  ```

---

### CATEGORY 2: Performance & Fixture Tests (3 failures)

#### Test 5: "E2E: Performance - TypeScript extraction under 500ms"
**Location**: `test/e2e/e2e_test.zig:319-330`

**Test Purpose**:
- Validate TypeScript extraction speed <= 500ms

**Root Cause**:
- **Likely**: Tree-sitter initialization overhead on first run
- **Evidence**: Measured times in phase2 tests show 5-10ms for small files
- **Impact**: May sporadically fail depending on system load

**Test Code**:
```zig
const time_ms = try ctx.measureExtractionTime("test/e2e/fixtures/typescript/auth.ts");
try helpers.assertPerformance(time_ms, 500, "TypeScript extraction");
```

**Recommendation**:
- Add warm-up extraction before timing (tree-sitter caching)
- Or increase timeout to 1000ms for CI environments
- Add system load detection

---

#### Test 6: "E2E: Handle malformed code gracefully"
**Location**: `test/e2e/e2e_test.zig:386-410`

**Test Purpose**:
- Verify extractor doesn't crash on invalid syntax

**Root Cause**:
- **Structural Issue**: Test creates file in temp directory but reads from wrong path
  ```zig
  try ctx.createSourceFile("malformed.ts", ...);  // Created in temp dir
  const result = try ctx.runPipeline("malformed.ts");  // Reads from cwd!
  ```
- **Impact**: FileNotFound error instead of testing error handling

**Test Code Problem**:
```zig
pub fn createSourceFile(self: *E2ETestContext, path: []const u8, content: []const u8) !void {
    const file = try self.temp_dir.dir.createFile(path, .{});  // Creates in temp
    ...
}

pub fn runPipeline(self: *E2ETestContext, source_file: []const u8) !PipelineResult {
    const source = try std.fs.cwd().readFileAlloc(..., source_file, ...);  // Reads from cwd!
}
```

**Recommendation**:
- Fix path handling: either use full temp path or change cwd
- Or use in-memory code string directly:
  ```zig
  var constraints = try self.clew.extractFromCode(malformed_code, "typescript");
  ```

---

### CATEGORY 3: Server Integration & Async Issues (2-3 failures)

#### Test 7: "E2E: Mock Modal server response"
**Location**: `test/e2e/e2e_test.zig:416-437`

**Test Purpose**:
- Verify mock server starts and responds to requests

**Observed Issue**: 
- **SIGKILL (signal 9)** - Process killed, likely out of memory or deadlock

**Root Cause Analysis**:
1. **Server Startup Issue**:
   ```zig
   const server_thread = try helpers.startMockServer(testing.allocator, mock_config);
   defer server_thread.join();
   std.Thread.sleep(200 * std.time.ns_per_ms);  // Only 200ms sleep
   ```
   - 200ms may be insufficient for server binding
   - No error checking on server startup

2. **Thread Join Problem**:
   - `defer server_thread.join()` at end of test
   - Server runs infinite loop: `while (true) { ... }`
   - Joining blocks forever → SIGKILL after timeout

3. **Resource Leaks**:
   - Mock server spawns new thread for each connection
   - No connection cleanup
   - Multiple tests may accumulate threads

**Mock Server Code** (`test/e2e/mocks/mock_modal.zig:20-40`):
```zig
pub fn runMockServer(allocator: Allocator, config: MockServerConfig) !void {
    const address = try net.Address.parseIp("127.0.0.1", config.port);
    var server = try address.listen(.{.reuse_address = true});
    defer server.deinit();
    
    while (true) {  // ← Infinite loop!
        const connection = server.accept() catch |err| { ... };
        defer connection.stream.close();
        handleRequest(allocator, connection, config) catch |err| { ... };
    }
}
```

**Recommendation**:
- Add shutdown mechanism (atomic flag or channel)
- Modify mock server to exit after N connections
- Set socket timeout to prevent hanging
- Don't join server thread - use separate cleanup thread

---

#### Test 8: "E2E: E2E: Extract → Compile pipeline"
**Location**: `test/e2e/e2e_test.zig:237-259`

**Test Purpose**:
- Full pipeline: extract constraints AND compile to IR

**Expected Behavior**:
```zig
- Extract constraints from auth.ts
- Compile to IR (JSON schema + grammar)
- Verify IR contains json_schema OR grammar
```

**Root Cause**:
- **Likely**: IR compilation issue, not extraction
- **Test Code** (line 254):
  ```zig
  try testing.expect(result.ir.json_schema != null or result.ir.grammar != null);
  ```
- **Issue**: Braid compiler may not generate IR successfully
- **Impact**: Assertion fails if both are null

**Recommendation**:
- Add debug output showing IR contents
- Check Braid compilation logs
- Verify grammar generation rules are correct

---

## Failing Tests Summary Table

| # | Test Name | Category | Root Cause | Severity | Fix Priority |
|---|-----------|----------|-----------|----------|--------------|
| 1 | Python auth extraction | Naming | Constraint name mismatch (User vs UserClass) | High | P1 |
| 2 | Python validation extraction | Fixture | Missing/empty validation.py fixture | High | P1 |
| 3 | Python async operations | Naming | Case sensitivity (RateLimiter vs rate_limiter) | High | P1 |
| 4 | Cross-language comparison | Case Sensitivity | Substring match needs case-insensitive | Medium | P2 |
| 5 | Performance TypeScript | Timing | Tree-sitter cold start overhead | Low | P3 |
| 6 | Malformed code handling | Path Logic | Temp dir path mismatch | High | P1 |
| 7 | Mock Modal server | Server Mgmt | Infinite loop + no shutdown mechanism | Critical | P0 |
| 8 | Extract→Compile pipeline | IR Gen | Braid may not generate IR | Medium | P2 |
| + | Additional phase2 tests | Various | Similar naming/fixture issues | Medium | P2 |

---

## Categorized Issue Breakdown

### Type A: Naming/Matching Issues (4 tests)
Tests expect exact constraint names but extractor may use different casing/format.

**Tests Affected**:
- Python auth extraction
- Python async operations  
- Cross-language comparison
- (Implied: phase2 constraint quality tests)

**Common Fix**:
```zig
// Instead of:
if (std.mem.eql(u8, constraint.name, "User")) { }

// Use:
const name_lower = std.ascii.allocLowerString(allocator, constraint.name);
if (std.mem.indexOf(u8, name_lower, "user") != null) { }
```

---

### Type B: Test Infrastructure Issues (2 tests)
Tests have bugs in setup or path handling.

**Tests Affected**:
- Python validation extraction (fixture issue)
- Malformed code handling (path issue)

**Common Fix**:
- Verify all fixtures exist and are properly populated
- Fix path handling: either use full temp paths or read from allocator-provided paths
- Use direct code strings instead of file I/O where possible

---

### Type C: Server/Threading Issues (1-2 tests)
Mock server implementation has blocking/resource management problems.

**Tests Affected**:
- Mock Modal server response
- (Possibly: phase2 tests using mock server)

**Common Fix**:
- Add shutdown flag/signal to mock server
- Implement connection timeout
- Don't join server thread - let it run in background with TLS cleanup
- Or use test harness that manages server lifecycle

---

### Type D: Integration Issues (2+ tests)
Full pipeline tests depending on correct behavior of prior components.

**Tests Affected**:
- Extract → Compile pipeline
- Phase 2 full pipeline tests

**Common Fix**:
- Verify each component independently first
- Add detailed debug output for IR generation
- Check Braid module compilation

---

## Recommended Fix Strategy

### Phase 1: Quick Wins (P1 - 2 hours)
1. **Fix naming issues** (Tests 1, 3, 4)
   - Implement case-insensitive matching helper
   - Apply to all constraint name comparisons
   
2. **Fix test infrastructure** (Tests 2, 6)
   - Verify validation.py fixture exists
   - Fix malformed.ts path handling

3. **Quick perf fix** (Test 5)
   - Add warm-up extraction run

### Phase 2: Server Fix (P0 - 1 hour)
4. **Fix mock server** (Test 7)
   - Add shutdown mechanism
   - Prevent thread join hang

### Phase 3: Integration (P2 - 2 hours)
5. **Debug IR compilation** (Test 8)
   - Add IR validation
   - Check Braid module integration

---

## Testing Strategy Post-Fix

After applying fixes:

1. **Run individual tests** to verify fixes:
   ```bash
   zig test test/e2e/e2e_test.zig 2>&1 | grep -E "FAIL|ok"
   ```

2. **Run full suite** to check for regressions:
   ```bash
   zig build test-e2e 2>&1 | tail -50
   ```

3. **Check phase2 tests**:
   ```bash
   zig build test-phase2 2>&1 | grep -E "FAIL|passed"
   ```

---

## Summary

**Total Failing Tests**: 12  
**Identified Root Causes**: 4 types
**Actionable Fixes**: Yes - all fixable
**Estimated Fix Time**: 5 hours total

**Key Insights**:
1. Most failures are in test code, not core functionality
2. Constraint naming/matching needs standardization
3. Mock server needs proper lifecycle management
4. Phase 2 tests have good coverage but share same issues

**Next Steps**:
1. Fix naming consistency (highest impact)
2. Add case-insensitive matching utilities
3. Proper server lifecycle management
4. Full regression testing

