# Integration Test Suite

Comprehensive end-to-end integration tests for the Ananke pipeline.

## Overview

These tests verify the complete workflow from constraint extraction through compilation to code generation and validation. They build on the existing end-to-end tests with more advanced scenarios covering edge cases, performance, and resilience.

## Test Organization

### Structure

```
tests/integration/
├── README.md                    # This file
├── integration_tests.rs         # Main test suite (12 tests)
├── helpers.rs                   # Test utilities and assertions
├── mocks/
│   ├── mod.rs                  # Mock module
│   └── modal_service.rs        # Modal service mock helpers
└── fixtures/
    ├── complex_auth.rs         # Complex Rust authentication service
    ├── api_handler.ts          # TypeScript API handler with types
    └── data_processor.py       # Python data processor with annotations
```

### Test Files

- **integration_tests.rs**: 12 comprehensive integration tests
- **helpers.rs**: Reusable test utilities, constraint builders, assertions
- **mocks/modal_service.rs**: Mock helpers for Modal inference service
- **fixtures/**: Sample code files for testing constraint extraction

## Test Categories

### Pipeline Integration (4 tests)

Tests that verify the complete data flow through the system:

1. **test_extract_compile_pipeline**: Constraint extraction → Compilation → Cache key generation
2. **test_full_generation_pipeline**: End-to-end with provenance, validation, and metadata
3. **test_constraint_caching_effectiveness**: LRU cache behavior across multiple requests
4. **test_ffi_boundary_data_integrity**: FFI round-trip with complex data structures

### Error Handling & Resilience (2 tests)

Tests that verify graceful degradation and retry logic:

5. **test_error_handling_graceful_degradation**: Retry exhaustion and error reporting
6. **test_concurrent_requests**: Multiple simultaneous requests without race conditions

### Data Integrity (3 tests)

Tests that verify correctness of generated metadata:

7. **test_provenance_tracking_completeness**: Full provenance metadata capture
8. **test_validation_results_accuracy**: Constraint satisfaction validation
9. **test_cache_coherence_across_requests**: Cache consistency verification

### Performance & Scale (3 tests)

Tests that verify system behavior under various loads:

10. **test_cache_lru_eviction**: LRU eviction with size-limited cache
11. **test_large_response_handling**: Large code generation (500+ tokens)
12. **test_cache_invalidation**: Cache clearing and rebuilding

## Running Tests

### All Integration Tests

```bash
cargo test --test integration
```

### Single Threaded (recommended for debugging)

```bash
cargo test --test integration -- --test-threads=1
```

### Specific Test

```bash
cargo test --test integration test_full_generation_pipeline
```

### With Output

```bash
cargo test --test integration -- --nocapture
```

### With Logging

```bash
RUST_LOG=maze=debug cargo test --test integration -- --nocapture
```

## Test Utilities

### Helper Functions

**Constraint Builders:**
- `simple_constraint(name, priority)` - Basic constraint
- `regex_constraint(name, pattern, priority)` - Regex pattern constraint
- `json_schema_constraint(...)` - JSON schema constraint
- `grammar_constraint(...)` - Context-free grammar constraint
- `token_mask_constraint(...)` - Token masking constraint

**Language-Specific Constraints:**
- `rust_constraints()` - Rust: type safety, async, error handling
- `typescript_constraints()` - TypeScript: async functions, type annotations, Promises
- `python_constraints()` - Python: type hints, async def, docstrings
- `security_constraints()` - Security: no unsafe code, validation, auth

**Request Builders:**
- `test_request(prompt, constraints, max_tokens)` - Basic request
- `test_request_with_context(...)` - Request with file/language context

**Assertions:**
- `assert_code_contains(code, patterns)` - Verify code contains patterns
- `assert_valid_provenance(...)` - Verify provenance completeness
- `assert_validation_success(...)` - Verify constraint satisfaction
- `assert_valid_metadata(...)` - Verify metadata calculations

### Mock Service

**MockModalService** provides helpers for mocking Modal responses:

**Scenarios:**
- `MockScenario::Success` - Standard successful generation
- `MockScenario::LargeResponse` - Large code (500+ tokens)
- `MockScenario::ServerError` - HTTP 500 error
- `MockScenario::Timeout` - HTTP 504 timeout
- `MockScenario::RateLimited` - HTTP 429 rate limit

**Custom Responses:**
```rust
let response = MockModalService::custom_response(MockResponse {
    generated_text: "fn example() {}".to_string(),
    tokens_generated: 10,
    model: "llama-3.1-8b".to_string(),
    total_time_ms: 100,
});
```

## Test Coverage

### What's Tested

- ✅ Constraint extraction and compilation
- ✅ FFI boundary data integrity
- ✅ Cache effectiveness (hit rates, LRU eviction)
- ✅ Concurrent request handling
- ✅ Error handling and retries
- ✅ Provenance tracking
- ✅ Validation results
- ✅ Large response handling
- ✅ Cache coherence and invalidation
- ✅ Metadata accuracy

### What's Not Tested (Future Work)

- Real Modal service integration (requires auth)
- Streaming generation
- Network timeouts and connection failures
- Zig FFI integration (requires Zig code)
- Property-based testing
- Fuzzing
- Memory leak detection

## CI Integration

These tests run in GitHub Actions on:
- Every push to main/develop
- All pull requests
- Daily scheduled runs
- Multiple platforms (Linux, macOS)

See `.github/workflows/maze-tests.yml` for CI configuration.

## Performance Notes

### Test Execution Times

- All integration tests: ~0.34s
- Individual tests: 10-50ms each
- Slowest tests: concurrent requests, cache LRU eviction

### Optimization Tips

1. Use `--test-threads=1` only for debugging
2. Mock setup is fast (<1ms per mock)
3. Cache tests generate multiple requests
4. Concurrent tests spawn 5 parallel tasks

## Debugging Failed Tests

### Common Issues

**Test fails with "Generation time is zero":**
- This is expected in tests due to timing precision
- The helper now allows 0 generation time in tests

**Test fails with "Cache should have X entries":**
- Check LRU eviction logic
- Verify constraints are actually different
- Check cache size limit configuration

**Test fails with FFI conversion errors:**
- Verify null pointer handling
- Check UTF-8 encoding
- Ensure proper memory cleanup

**Test fails with "Failed after N attempts":**
- Check retry count configuration
- Verify mock setup (enough failures configured)
- Check exponential backoff timing

### Debugging Commands

```bash
# Run with backtrace
RUST_BACKTRACE=1 cargo test --test integration test_name

# Run with full logging
RUST_LOG=maze=trace cargo test --test integration test_name -- --nocapture

# Run in release mode (faster)
cargo test --test integration --release
```

## Adding New Tests

### Checklist

1. Add test function with `#[tokio::test]` attribute
2. Create mock server with `Server::new_async().await`
3. Set up mocks with `server.mock(...).create_async().await`
4. Use helpers from `helpers.rs` for constraints and assertions
5. Verify test passes in isolation and with all tests
6. Update this README with test description
7. Update test count in main README

### Example Template

```rust
#[tokio::test]
async fn test_my_new_scenario() {
    let mut server = Server::new_async().await;
    
    let response = MockModalService::scenario_response(MockScenario::Success);
    let _m = server.mock("POST", "/generate")
        .with_status(200)
        .with_header("content-type", "application/json")
        .with_body(response.to_string())
        .create_async()
        .await;
    
    let orchestrator = create_test_orchestrator(server.url());
    
    let request = test_request("Test prompt", rust_constraints(), 100);
    let response = orchestrator.generate(request).await.expect("Generation failed");
    
    // Assertions
    assert!(response.validation.all_satisfied);
}
```

## Integration with Existing Tests

These integration tests complement the existing test suite:

| Test Suite | Count | Focus |
|------------|-------|-------|
| Unit tests (lib.rs) | 8 | Core orchestrator logic |
| FFI tests | 13 | FFI boundary and conversions |
| Modal client tests | 12 | HTTP communication |
| Orchestrator tests | 11 | Configuration and setup |
| End-to-end tests | 9 | Basic generation workflows |
| **Integration tests** | **12** | **Advanced scenarios** |
| **Total** | **65** | **Complete coverage** |

## Contributing

When adding tests:
- Keep tests focused and independent
- Use descriptive names (`test_<feature>_<scenario>`)
- Add helpful assertion messages
- Mock external dependencies
- Clean up resources (FFI pointers, etc.)
- Update documentation

## License

Same as parent project (MIT OR Apache-2.0)
