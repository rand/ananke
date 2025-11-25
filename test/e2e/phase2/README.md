# Phase 2 E2E Integration Tests

Comprehensive end-to-end tests for Ananke's tree-sitter hybrid extraction pipeline.

## Overview

These tests validate the complete extraction flow from source code to high-quality constraints, covering:

- **Full Pipeline**: End-to-end extraction with real-world code samples
- **Multi-Language**: Cross-language constraint extraction and aggregation
- **Strategy Comparison**: Comparison of all 4 extraction strategies
- **Constraint Quality**: Validation of confidence scores, metadata, and deduplication

## Test Files

### 1. `full_pipeline_test.zig`

Tests the complete extraction pipeline from source → parse → extract → constraints.

**What's Tested:**
- Real-world TypeScript extraction (API service with validation)
- Real-world Python extraction (async rate limiter with decorators)
- Constraint quality verification (confidence scores ≥ 0.90 for AST, ≥ 0.75 for patterns)
- Metadata completeness (names, descriptions, line numbers, frequencies)
- Error handling (empty files, malformed code, very large files)
- Graceful degradation for unsupported languages

**Key Test Cases:**
```zig
test "Full Pipeline: TypeScript real-world code extraction"
test "Full Pipeline: TypeScript constraint quality checks"
test "Full Pipeline: Python real-world code extraction"
test "Full Pipeline: Empty source code"
test "Full Pipeline: Malformed TypeScript"
test "Full Pipeline: Very large source file"
test "Full Pipeline: Confidence score distribution"
```

**Expected Results:**
- TypeScript/Python: Multiple constraints with mixed confidence (0.75-0.95)
- Empty code: Graceful handling, no crashes
- Malformed code: Best-effort extraction without errors
- Large files: Performance degradation within acceptable limits

---

### 2. `multi_language_test.zig`

Tests extraction across multiple programming languages in a single project.

**What's Tested:**
- Language detection and routing (TypeScript, Python, Rust, Go, Zig)
- Consistent constraint extraction across languages
- Cross-language pattern comparison
- Constraint aggregation from multiple files
- Language-specific feature detection

**Key Test Cases:**
```zig
test "Multi-Language: TypeScript detection and extraction"
test "Multi-Language: All supported languages"
test "Multi-Language: Compare TypeScript vs Python patterns"
test "Multi-Language: Aggregate constraints from multiple files"
test "Multi-Language: TypeScript-specific features"
test "Multi-Language: Python-specific features"
```

**Expected Results:**
- TypeScript: Interface, class, async, generic detection
- Python: Dataclass, protocol, decorator detection
- Rust/Go/Zig: Pattern-based fallback (tree-sitter may not be available)
- Cross-language: Similar high-level patterns detected (classes, async)

---

### 3. `strategy_comparison_test.zig`

Compares results from all 4 extraction strategies to verify the hybrid approach.

**What's Tested:**
- `tree_sitter_only`: Pure AST extraction (confidence = 0.95)
- `pattern_only`: Pure regex extraction (confidence = 0.75)
- `tree_sitter_with_fallback`: AST with pattern fallback
- `combined`: Merge AST and patterns for maximum coverage

**Key Test Cases:**
```zig
test "Strategy: tree_sitter_only extracts AST constraints"
test "Strategy: pattern_only extracts pattern constraints"
test "Strategy: tree_sitter_with_fallback prefers AST"
test "Strategy: combined merges AST and patterns"
test "Strategy Comparison: Combined has best coverage"
test "Strategy Comparison: Confidence score distribution"
test "Strategy: Combined deduplicates constraints"
```

**Expected Results:**
- `tree_sitter_only`: High confidence (≥0.90), may fail for unsupported languages
- `pattern_only`: Medium confidence (0.75-0.85), works for all languages
- `combined`: Most constraints (AST + patterns merged), no duplicates
- Fallback: Graceful degradation when tree-sitter unavailable

---

### 4. `constraint_quality_test.zig`

Validates the quality and correctness of extracted constraints.

**What's Tested:**
- Confidence score correctness (AST ≥ 0.90, patterns ≥ 0.75)
- Duplicate detection and merging
- Metadata completeness (names, descriptions, line numbers, frequencies)
- Constraint validation (confidence in [0, 1], non-empty names)
- Constraint kind appropriateness

**Key Test Cases:**
```zig
test "Quality: AST constraints have high confidence"
test "Quality: Pattern constraints have medium confidence"
test "Quality: Duplicate detection in combined mode"
test "Quality: All constraints have names and descriptions"
test "Quality: Line number tracking"
test "Quality: Constraint kind appropriateness"
test "Quality: All constraints pass validation"
```

**Expected Results:**
- AST constraints: confidence ≥ 0.90
- Pattern constraints: confidence 0.70-0.85
- No exact duplicates in combined mode
- All constraints have names, descriptions, valid confidence
- Line numbers tracked for pattern matches

---

## Running the Tests

### Run all Phase 2 E2E tests:
```bash
zig build test
```

### Run individual test files:
```bash
# Full pipeline tests
zig test test/e2e/phase2/full_pipeline_test.zig

# Multi-language tests
zig test test/e2e/phase2/multi_language_test.zig

# Strategy comparison tests
zig test test/e2e/phase2/strategy_comparison_test.zig

# Constraint quality tests
zig test test/e2e/phase2/constraint_quality_test.zig
```

### Run with verbose output:
```bash
zig build test 2>&1 | grep "==="
```

---

## Test Coverage

### What's Covered

✅ **Full extraction pipeline** (source → AST → constraints)  
✅ **All 4 extraction strategies** (tree_sitter_only, pattern_only, fallback, combined)  
✅ **Multi-language support** (TypeScript, Python, Rust, Go, Zig)  
✅ **Constraint quality** (confidence scores, metadata, deduplication)  
✅ **Error handling** (empty code, malformed code, unsupported languages)  
✅ **Real-world patterns** (API services, rate limiters, validation logic)  
✅ **Performance** (large files, cross-language aggregation)  

### What's Not Covered (Future Work)

❌ **Compilation to IR** (Braid integration - separate test suite)  
❌ **LLM-assisted extraction** (Claude API integration - requires credentials)  
❌ **Test mining** (extracting constraints from test assertions)  
❌ **Telemetry analysis** (runtime constraint extraction)  
❌ **Visual regression tests** (comparing constraint diffs over time)  

---

## Expected Test Results

When tree-sitter parsers are available (TypeScript, Python):

```
=== TypeScript Full Pipeline Test ===
Extracted 12 constraints from real-world TypeScript
  - interface (kind: type_safety, confidence: 0.95)
  - class (kind: syntactic, confidence: 0.95)
  - async_patterns (kind: semantic, confidence: 0.85)
✓ Found structural patterns (interfaces/classes)

=== Strategy Comparison ===
tree_sitter_only:        8 constraints
pattern_only:            6 constraints
tree_sitter_with_fallback: 8 constraints
combined:                12 constraints
✓ Combined strategy has best coverage

=== Confidence Distribution by Strategy ===
tree_sitter_only:
  Min: 0.95, Max: 0.95, Avg: 0.95

pattern_only:
  Min: 0.75, Max: 0.85, Avg: 0.78

combined:
  Min: 0.75, Max: 0.95, Avg: 0.87
```

When tree-sitter parsers are NOT available:

```
⊘ Tree-sitter not available, skipping test
⊘ Fell back to patterns (tree-sitter unavailable)
✓ Graceful degradation for unsupported language
```

---

## Debugging Test Failures

### Tree-sitter not available

If tests show `tree_sitter_available: false`:

1. **Install tree-sitter libraries:**
   ```bash
   # macOS
   brew install tree-sitter
   
   # Linux
   apt-get install libtree-sitter-dev
   ```

2. **Verify library path:**
   - Check `/opt/homebrew/opt/tree-sitter/` (macOS)
   - Adjust paths in `build.zig` if needed

3. **Expected behavior:**
   - Tests should still pass (fallback to patterns)
   - Some tests will be skipped with warnings

### Low constraint counts

If constraint counts are lower than expected:

1. **Check pattern definitions:** `src/clew/patterns.zig`
2. **Verify extractor logic:** `src/clew/extractors/*.zig`
3. **Enable debug logging:** Add `std.debug.print` to extractors

### Confidence score issues

If confidence scores don't match expectations:

1. **AST constraints should be 0.95:** Check `HybridExtractor.extractWithTreeSitter`
2. **Pattern constraints should be 0.75-0.85:** Check `patterns.zig` confidence values
3. **Verify no mixing:** Combined mode should have distinct scores

---

## Performance Benchmarks

Expected performance on modern hardware:

- **Small file** (<100 lines): <10ms
- **Medium file** (100-500 lines): <50ms
- **Large file** (1000+ lines): <200ms
- **Very large file** (10k+ lines): <1000ms

Performance degradation beyond these limits may indicate:
- Inefficient pattern matching
- Memory allocation issues
- Tree-sitter parsing bottlenecks

---

## Contributing

When adding new E2E tests:

1. **Follow naming convention:** `test "Category: Description"`
2. **Use debug prints:** Help with test output readability
3. **Clean up resources:** Use `defer` for memory management
4. **Test both success and failure:** Include edge cases
5. **Document expectations:** Add comments for complex assertions

Example:
```zig
test "Category: Test description" {
    const allocator = testing.allocator;
    
    // Setup
    var extractor = HybridExtractor.init(allocator, .combined);
    defer extractor.deinit();
    
    // Execute
    var result = try extractor.extract(code, "typescript");
    defer result.deinit(allocator);
    
    // Assert
    std.debug.print("\n=== Test Category ===\n", .{});
    std.debug.print("Result: {}\n", .{result.constraints.len});
    
    try testing.expect(result.constraints.len > 0);
    std.debug.print("✓ Test passed\n", .{});
}
```

---

## Related Documentation

- **Phase 1 Tests:** `test/clew/hybrid_extractor_test.zig` - Unit tests for hybrid extractor
- **Tree-sitter Integration:** `src/clew/tree_sitter.zig` - FFI bindings
- **Pattern Matching:** `src/clew/patterns.zig` - Pattern extraction engine
- **Build Configuration:** `build.zig` - Test registration and compilation

---

## License

Part of the Ananke project. See root LICENSE for details.
