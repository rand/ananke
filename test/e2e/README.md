# E2E Integration Tests

Comprehensive end-to-end tests for the Ananke constraint-driven code generation pipeline.

## Overview

This directory contains E2E tests that validate the full Ananke pipeline:
1. **Extract** constraints from source code (Clew)
2. **Compile** constraints to IR (Braid)
3. **Generate** code via Modal (optional)
4. **Validate** generated code satisfies constraints

## Test Suites

### Phase 8a: Pipeline Integration Tests (NEW)

**TypeScript Pipeline** (`test_typescript_pipeline.zig`)
- API handler constraint extraction
- Utility function constraint extraction
- Validation schema constraint extraction
- IR compilation validation

**Python Pipeline** (`test_python_pipeline.zig`)
- API handler constraint extraction
- Data model constraint extraction
- Validation constraint extraction
- IR compilation validation

**Pipeline Runner** (`pipeline_runner.zig`)
- Centralized test harness
- Modal integration support
- Configuration management
- Validation utilities

### Phase 2: Multi-Language Tests

**Full Pipeline** (`phase2/full_pipeline_test.zig`)
- End-to-end extraction and compilation
- Performance measurement
- Multi-language support

**Multi-Language** (`phase2/multi_language_test.zig`)
- Cross-language pattern detection
- Language-specific feature extraction
- Multi-file aggregation

**Strategy Comparison** (`phase2/strategy_comparison_test.zig`)
- AST-only vs Pattern-only vs Hybrid
- Coverage comparison
- Confidence distribution

**Constraint Quality** (`phase2/constraint_quality_test.zig`)
- Metadata validation
- Edge case handling
- Error resilience

### Legacy E2E Tests

**Basic E2E** (`e2e_test.zig`)
- TypeScript auth, validation, async
- Python auth, validation, async
- Performance benchmarks
- Error handling

## Test Fixtures

### TypeScript Fixtures (`fixtures/typescript/`)
- `api_handler.ts` - Express-like route handlers (NEW)
- `utility.ts` - Pure functions and type guards (NEW)
- `auth.ts` - Authentication logic
- `validation.ts` - Validation schemas
- `async.ts` - Async/await patterns

### Python Fixtures (`fixtures/python/`)
- `api_handler.py` - FastAPI-like handlers (NEW)
- `model.py` - Pydantic-like models (NEW)
- `auth.py` - Authentication logic
- `validation.py` - Validators
- `async.py` - Async operations

### Expected Outputs (`fixtures/expected/`)
- Reference outputs for validation

## Running Tests

### Run all E2E tests
```bash
zig build test-e2e
```

### Run specific test suites
```bash
# Phase 2 only
zig build test-phase2

# All tests
zig build test
```

### With Modal integration
```bash
export ANANKE_MODAL_ENDPOINT=https://your-app.modal.run
zig build test-e2e
```

## Test Infrastructure

### `helpers.zig`
Shared utilities for E2E testing:
- `E2ETestContext` - Test environment management
- `PipelineResult` - Pipeline execution results
- Fixture loading and validation
- Assertion helpers

### `pipeline_runner.zig`
Full pipeline test harness:
- `PipelineRunner` - Execute extract→compile→generate
- `PipelineConfig` - Configuration management
- `ValidationResult` - Constraint satisfaction validation
- Modal integration (optional)

### `mocks/mock_modal.zig`
Mock Modal server for testing without real endpoint:
- HTTP server simulation
- Response mocking
- Request validation

## Test Organization

```
test/e2e/
├── README.md                          # This file
├── PHASE8A_IMPLEMENTATION_SUMMARY.md  # Phase 8a details
├── E2E_FAILURE_ANALYSIS.md            # Troubleshooting guide
├── helpers.zig                        # Shared utilities
├── pipeline_runner.zig                # Pipeline harness (NEW)
├── e2e_test.zig                       # Legacy E2E tests
├── test_typescript_pipeline.zig       # TypeScript tests (NEW)
├── test_python_pipeline.zig           # Python tests (NEW)
├── phase2/                            # Phase 2 tests
│   ├── full_pipeline_test.zig
│   ├── multi_language_test.zig
│   ├── strategy_comparison_test.zig
│   └── constraint_quality_test.zig
├── fixtures/                          # Test fixtures
│   ├── typescript/                    # TS samples
│   ├── python/                        # Python samples
│   └── expected/                      # Expected outputs
└── mocks/                             # Mock services
    └── mock_modal.zig
```

## Test Statistics

- **Total Test Files**: 8
- **Total Tests**: 38+
- **Total Fixture Files**: 10
- **Total Fixture Lines**: 1,500+
- **Average Test Execution**: <30 seconds
- **Pass Rate**: 100%

## Adding New Tests

### 1. Create test file
```zig
// test/e2e/test_new_feature.zig
const std = @import("std");
const testing = std.testing;
const helpers = @import("helpers.zig");

test "E2E: New feature test" {
    var ctx = try helpers.E2ETestContext.init(testing.allocator);
    defer ctx.deinit();

    const result = try ctx.runPipeline("test/e2e/fixtures/sample.ts");
    defer {
        var mut_result = result;
        mut_result.deinit(testing.allocator);
    }

    // Assertions
    try testing.expect(result.constraints.constraints.items.len > 0);
}
```

### 2. Create fixture
```typescript
// test/e2e/fixtures/typescript/sample.ts
export function sampleFunction(x: number): string {
    return x.toString();
}
```

### 3. Update build.zig
```zig
const new_test = b.addTest(.{
    .root_module = b.createModule(.{
        .root_source_file = b.path("test/e2e/test_new_feature.zig"),
        // ... module configuration
    }),
});
// ... link libraries
const run_new_test = b.addRunArtifact(new_test);
e2e_test_step.dependOn(&run_new_test.step);
```

### 4. Run tests
```bash
zig build test-e2e
```

## Troubleshooting

### Tests fail with "tree-sitter not found"
```bash
# macOS
brew install tree-sitter

# Linux
apt-get install libtree-sitter-dev
```

### Tests timeout
- Increase timeout in build.zig
- Check Modal endpoint availability
- Verify network connectivity

### Compilation errors
- Ensure Zig 0.15.x installed
- Check module imports
- Verify fixture paths

### Runtime errors
- Check fixture file permissions
- Verify test allocator cleanup
- Enable verbose logging in PipelineConfig

## Performance Benchmarks

Expected performance (on modern hardware):
- TypeScript extraction: <5ms per file
- Python extraction: <5ms per file
- IR compilation: <5ms per file
- Full pipeline: <20ms per file

If tests significantly exceed these times, investigate:
- Disk I/O issues
- Memory pressure
- Parser initialization overhead

## Contributing

When adding E2E tests:
1. Follow existing naming conventions
2. Add comprehensive fixtures
3. Document test purpose
4. Ensure tests are deterministic
5. Add to appropriate test suite
6. Update this README

## See Also

- [Phase 8 Specification](../../docs/specs/phase8-e2e-integration.md)
- [Phase 8a Implementation Summary](PHASE8A_IMPLEMENTATION_SUMMARY.md)
- [Test Failure Analysis](E2E_FAILURE_ANALYSIS.md)
