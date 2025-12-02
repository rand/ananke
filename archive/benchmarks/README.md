# Ananke Performance Benchmarks

Comprehensive performance benchmark suite for the Ananke constraint-driven code generation system.

## Quick Reference

```bash
# Run all benchmarks
zig build bench

# Run regression tests only
zig build bench-regression

# Run specific benchmark category
zig build bench-clew          # Constraint extraction
zig build bench-braid         # Constraint compilation
zig build bench-multi-lang    # Multi-language extraction
zig build bench-density       # Varying constraint counts
zig build bench-memory        # Memory usage tracking
zig build bench-ffi-roundtrip # FFI overhead
zig build bench-pipeline      # End-to-end workflow
```

## Directory Structure

```
benchmarks/
├── README.md                   # This file
├── BENCHMARK_GUIDE.md          # Comprehensive guide
├── baselines.json              # Performance baselines for regression testing
└── results/                    # Benchmark output (gitignored)
```

## Performance Targets

| Component | Target | Status |
|-----------|--------|--------|
| TypeScript extraction (75 lines) | 4-7ms | Target |
| Constraint compilation (10) | <2ms | Target |
| FFI roundtrip | <1ms | Target |
| Full pipeline | 6-9ms | Target |
| Cache hit | <1μs | Target |

## Files

- **BENCHMARK_GUIDE.md**: Complete documentation on running, interpreting, and maintaining benchmarks
- **baselines.json**: Established performance baselines for regression detection

## Benchmark Fixtures

Test fixtures are in `test/fixtures/` with realistic code samples:

```
test/fixtures/{language}/{size}/entity_service_{lines}.{ext}

Languages: typescript, python, rust, zig, go
Sizes: small (~100), medium (~500), large (~1000), xlarge (~5000)
```

**Regenerate fixtures:**
```bash
cd test/fixtures && python3 generate_fixtures.py
```

## CI Integration

Regression tests automatically fail builds if performance degrades beyond tolerance (±10%).

Add to `.github/workflows/benchmarks.yml`:

```yaml
- name: Performance Regression Check
  run: zig build bench-regression
```

## Updating Baselines

After legitimate performance improvements:

1. Run benchmarks and verify improvements
2. Update `baselines.json` with new values
3. Commit with explanation: `git commit -m "Update baselines after X optimization"`

## More Information

See **BENCHMARK_GUIDE.md** for:
- Detailed benchmark descriptions
- How to interpret results
- Profiling instructions
- CI integration examples
- Troubleshooting guide

## Support

Questions? Check:
- `BENCHMARK_GUIDE.md` - Complete reference
- `ARCHITECTURE_V2.md` - System design
- `maze/README.md` - Rust orchestration layer
