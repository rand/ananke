# Maze Test Suite

Comprehensive test coverage for the Maze orchestration layer.

## Test Structure

### Unit Tests (in `src/`)
- `lib.rs`: Core orchestrator tests (8 tests)
- `ffi.rs`: FFI conversion tests (2 tests)
- `modal_client.rs`: Modal client configuration tests (4 tests)

### Integration Tests (in `tests/`)

#### 1. FFI Tests (`ffi_tests.rs`) - 13 tests
Tests the C-compatible FFI layer for Zig integration:
- ConstraintIR FFI roundtrip conversions
- Complex constraint structures (JSON schema, grammar, regex, token masks)
- Intent FFI conversions
- GenerationResult FFI conversions
- Multiple constraint array handling
- Serialization/deserialization

#### 2. Modal Client Tests (`modal_client_tests.rs`) - 12 tests
Tests HTTP communication with Modal inference service:
- Health check endpoint
- Model listing endpoint
- Generation with constraints
- API key authentication
- Error handling (401, 500)
- Retry logic on failures
- Request/response serialization

#### 3. Orchestrator Tests (`orchestrator_tests.rs`) - 11 tests
Tests core orchestration logic:
- Orchestrator creation and configuration
- Cache operations
- Generation request construction
- Generation context handling
- Constraint management
- Configuration defaults and customization

#### 4. End-to-End Tests (`end_to_end_tests.rs`) - 9 tests
Tests complete pipeline with mocked Modal service:
- Simple generation with constraints
- TypeScript constraint handling
- Python with JSON schema
- Grammar-based constraints
- Token mask constraints
- Constraint caching behavior
- Multiple constraints with priorities
- Failure handling
- Provenance tracking

### Test Fixtures (`fixtures/`)
Sample code files for testing constraint extraction:
- `sample.ts` - TypeScript authentication service
- `sample.py` - Python authentication service
- `sample.rs` - Rust authentication service

## Running Tests

### All Tests
```bash
cargo test --all
```

### Specific Test Suite
```bash
cargo test --test ffi_tests
cargo test --test modal_client_tests
cargo test --test orchestrator_tests
cargo test --test end_to_end_tests
```

### Unit Tests Only
```bash
cargo test --lib
```

### With Output
```bash
cargo test -- --nocapture
```

### With Logging
```bash
RUST_LOG=maze=debug cargo test
```

### Ignored Tests (require Modal service)
```bash
cargo test -- --ignored
```

## Test Coverage Summary

| Component | Unit Tests | Integration Tests | Total |
|-----------|------------|-------------------|-------|
| FFI Layer | 2 | 13 | 15 |
| Modal Client | 4 | 12 | 16 |
| Orchestrator | 8 | 11 | 19 |
| End-to-End | 0 | 9 | 9 |
| **Total** | **14** | **45** | **59** |

## Key Test Scenarios

### FFI Compatibility
- ✓ C ABI compatibility between Rust and Zig
- ✓ Memory management across FFI boundary
- ✓ UTF-8 string handling
- ✓ Complex nested structures
- ✓ Null pointer safety
- ✓ Array pointer handling

### HTTP Communication
- ✓ Health checks
- ✓ API authentication
- ✓ Error handling
- ✓ Retry logic
- ✓ Timeout handling
- ✓ JSON serialization

### Constraint Handling
- ✓ JSON schema constraints
- ✓ Grammar-based constraints
- ✓ Regex pattern constraints
- ✓ Token mask constraints
- ✓ Priority-based ordering
- ✓ Constraint caching

### Generation Pipeline
- ✓ TypeScript generation
- ✓ Python generation
- ✓ Rust generation
- ✓ Multi-language support
- ✓ Context propagation
- ✓ Provenance tracking
- ✓ Metadata collection

## Mock Infrastructure

Tests use `mockito` for HTTP mocking:
- Mock Modal inference service
- Controlled response scenarios
- Error injection
- Retry behavior testing
- Offline testing capability

## Test Data

Fixtures provide realistic code samples:
- **TypeScript**: Class-based authentication service
- **Python**: Dataclass-based authentication service
- **Rust**: Struct-based authentication service

All fixtures include:
- Type annotations
- Async/await patterns
- Error handling
- Documentation comments

## Future Test Additions

### Planned
- [ ] Performance benchmarks
- [ ] Load testing
- [ ] Concurrent request handling
- [ ] Streaming generation tests
- [ ] Real Modal service integration tests (CI)
- [ ] Property-based testing with proptest
- [ ] Fuzz testing for FFI layer
- [ ] Memory leak detection

### Zig Integration
- [ ] Zig-side FFI tests (once Zig code is available)
- [ ] Cross-language integration tests
- [ ] Clew constraint extraction tests
- [ ] Braid constraint compilation tests
- [ ] Ariadne DSL tests

## CI Integration

Tests are run in GitHub Actions:
- On every push to main
- On all pull requests
- Daily scheduled runs
- Multiple platforms (Linux, macOS, Windows)

See `.github/workflows/ci.yml` for CI configuration.

## Troubleshooting

### Test Failures

**FFI Tests Failing**
- Check memory management (free functions called)
- Verify UTF-8 encoding
- Check pointer validity

**Modal Client Tests Failing**
- Ensure mockito server is running
- Check async runtime initialization
- Verify JSON schema compatibility

**E2E Tests Failing**
- Check mock server setup
- Verify constraint compilation
- Check cache behavior

### Performance Issues

If tests are slow:
- Use `cargo test --release`
- Check for network timeouts
- Reduce retry counts in tests
- Use `--test-threads=1` for debugging

## Contributing

When adding new tests:
1. Follow existing test naming conventions
2. Add documentation comments
3. Use descriptive assertion messages
4. Include both success and failure cases
5. Mock external dependencies
6. Update this README with new test counts
