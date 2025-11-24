# Integration Tests

This directory contains integration tests for the Ananke constraint-driven code generation engine.

## Test Organization

- **pipeline_tests.zig**: End-to-end tests for Extract → Compile pipeline
  - Tests the full workflow from constraint extraction (Clew) to constraint compilation (Braid)
  - Validates proper integration between modules
  - Ensures ConstraintIR output structure is correct

## Running Tests

Run all integration tests:
```bash
zig build test
```

## Test Patterns

Integration tests follow these patterns:

1. **Initialize both Clew and Braid instances**
   ```zig
   var clew = try Clew.init(testing.allocator);
   defer clew.deinit();
   var braid = try Braid.init(testing.allocator);
   defer braid.deinit();
   ```

2. **Extract constraints with Clew**
   ```zig
   const constraint_set = try clew.extractFromCode(source, language);
   defer constraint_set.deinit();
   ```

3. **Compile constraints with Braid**
   ```zig
   const ir = try braid.compile(constraint_set.constraints.items);
   ```

4. **Validate output**
   ```zig
   try testing.expect(ir.priority >= 0);
   ```

5. **Verify memory cleanup**
   - All tests use `testing.allocator`
   - All allocations are properly freed with `defer`
   - Zero leaks expected

## Test Fixtures

Integration tests use sample code from `/test/fixtures/`:
- `sample.ts` - TypeScript authentication service
- `sample.py` - Python authentication service
- `sample.rs` - Rust authentication service
- `sample.zig` - Zig user service

## Coverage Goals

Integration tests validate:
- Multi-language constraint extraction
- Constraint compilation to IR
- Error propagation across modules
- Empty constraint set handling
- Invalid input handling
- Memory safety (no leaks)
