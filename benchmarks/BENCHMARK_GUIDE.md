# Ananke Performance Benchmark Guide

Comprehensive guide to running, interpreting, and maintaining performance benchmarks for the Ananke constraint-driven code generation system.

## Quick Start

```bash
# Run all benchmarks (Zig + Rust)
zig build bench

# Run only Zig benchmarks
zig build bench-zig

# Run only Rust benchmarks
zig build bench-rust

# Run regression tests
zig build bench-regression
```

## Benchmark Categories

### 1. Clew Extraction Benchmarks

Tests constraint extraction from source code across all supported languages.

```bash
# Basic extraction benchmark
zig build bench-clew

# Multi-language comprehensive benchmark
zig build bench-multi-lang
```

**What it measures:**
- Time to parse and extract constraints from source files
- Throughput (lines/second)
- Performance across TypeScript, Python, Rust, Zig, and Go
- Scaling with file size (100, 500, 1000, 5000 lines)

**Performance targets:**
- TypeScript (75 lines): 4-7ms
- Small files (100 lines): <10ms
- Medium files (500 lines): <30ms
- Large files (1000 lines): <50ms

### 2. Braid Compilation Benchmarks

Tests constraint compilation to IR (JSON Schema, EBNF, regex, token masks).

```bash
# Basic compilation benchmark
zig build bench-braid

# Constraint density benchmark
zig build bench-density
```

**What it measures:**
- Time to compile constraints to IR
- Performance with varying constraint counts (5, 20, 50, 100, 250)
- Per-constraint compilation cost
- Conflict detection overhead

**Performance targets:**
- 10 constraints: <2ms
- 50 constraints: <10ms
- 100 constraints: <20ms
- 250 constraints: <50ms

### 3. Memory Usage Benchmarks

Tracks allocation patterns and peak memory usage.

```bash
zig build bench-memory
```

**What it measures:**
- Total bytes allocated
- Peak memory usage
- Allocation count
- Memory per line of code / per constraint

**Key metrics:**
- Small file extraction: <100KB peak
- Medium file extraction: <500KB peak
- Constraint compilation: <10KB per constraint

### 4. FFI Overhead Benchmarks

Measures Zig↔Rust boundary crossing costs.

```bash
# Zig benchmarks
zig build bench-ffi
zig build bench-ffi-roundtrip

# Rust benchmarks
cd maze && cargo bench --bench ffi_overhead
```

**What it measures:**
- Structure serialization/deserialization
- String marshaling
- Array/vector conversion
- Roundtrip latency

**Performance targets:**
- Simple struct roundtrip: <100μs
- String copy (100 bytes): <1μs
- Vector marshaling (100 items): <10μs
- Total FFI overhead: <1ms

### 5. End-to-End Pipeline Benchmarks

Tests full extract→compile workflow.

```bash
zig build bench-pipeline
```

**What it measures:**
- Combined extraction + compilation time
- Real-world workflow performance
- Per-language pipeline efficiency

**Performance targets:**
- TypeScript small: 6-9ms total
- Python small: 7-10ms total
- Rust small: 8-12ms total

### 6. Rust Maze Benchmarks

Tests orchestration layer performance.

```bash
cd maze && cargo bench
```

**Benchmark suites:**
- `orchestration`: End-to-end orchestration overhead
- `cache_performance`: LRU cache hit/miss latency
- `constraint_compilation`: Constraint serialization
- `ffi_overhead`: FFI conversion costs

**Performance targets:**
- Cache hit latency: <1μs
- Cache miss latency: <1ms
- Hash generation: <10μs
- llguidance schema generation: <100μs

## Running Specific Benchmarks

### Individual Zig Benchmarks

```bash
# Clew extraction
zig build bench-clew

# Braid compilation
zig build bench-braid

# Multi-language extraction
zig build bench-multi-lang

# Constraint density
zig build bench-density

# Memory usage
zig build bench-memory

# FFI benchmarks
zig build bench-ffi
zig build bench-ffi-roundtrip

# Pipeline
zig build bench-pipeline
```

### Individual Rust Benchmarks

```bash
cd maze

# All benchmarks
cargo bench

# Specific benchmark
cargo bench --bench orchestration
cargo bench --bench cache_performance
cargo bench --bench constraint_compilation
cargo bench --bench ffi_overhead
```

## Performance Regression Testing

The regression test suite compares current performance against established baselines.

```bash
# Run regression tests
zig build bench-regression
```

**How it works:**
1. Loads baselines from `benchmarks/baselines.json`
2. Runs key benchmarks
3. Compares results with ±10% tolerance
4. **Fails build** if regression detected

### Updating Baselines

When legitimate performance improvements are made:

```bash
# Run benchmarks and capture output
zig build bench > benchmarks/new_results.txt

# Manually update benchmarks/baselines.json with new values
# Then commit the updated baselines
git add benchmarks/baselines.json
git commit -m "Update performance baselines after optimization"
```

## Interpreting Results

### Zig Benchmark Output

```
typescript (small, 88 lines): 4.23ms (20805 lines/s)
```

- **4.23ms**: Average execution time
- **20805 lines/s**: Throughput

### Rust Criterion Output

```
constraint_compilation/5
                        time:   [1.8234 ms 1.8567 ms 1.8912 ms]
                        change: [-2.45% +0.12% +2.71%]
```

- **time**: [min, mean, max] execution time
- **change**: Performance change vs previous run
- Criterion detects performance regressions automatically

### Status Indicators

- `✓ OK` / `✓ PASS`: Within performance targets
- `⚠ SLOW` / `⚠ WARNING`: Exceeds targets but not critical
- `✗ FAIL`: Performance regression detected

## Performance Targets Summary

| Component | Operation | Target | Critical |
|-----------|-----------|--------|----------|
| Clew | TS extraction (75 lines) | 4-7ms | <10ms |
| Clew | Small file (100 lines) | <10ms | <20ms |
| Clew | Medium file (500 lines) | <30ms | <60ms |
| Braid | 10 constraints | <2ms | <5ms |
| Braid | 50 constraints | <10ms | <20ms |
| FFI | Roundtrip | <1ms | <2ms |
| Pipeline | Extract + Compile | 6-9ms | <15ms |
| Cache | Hit latency | <1μs | <10μs |
| Cache | Miss latency | <1ms | <5ms |

## Profiling for Deep Analysis

### Zig Profiling

```bash
# Build with profiling enabled
zig build -Doptimize=ReleaseFast

# Use external profilers
valgrind --tool=callgrind ./zig-out/bin/clew_bench
perf record -g ./zig-out/bin/clew_bench
perf report
```

### Rust Profiling

```bash
# Flamegraph
cargo install flamegraph
cargo flamegraph --bench orchestration

# perf profiling
perf record -g cargo bench --bench orchestration
perf report

# Criterion HTML reports
cargo bench
# Open target/criterion/report/index.html
```

## CI Integration

### GitHub Actions Example

```yaml
name: Performance Benchmarks

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  benchmarks:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Zig
        uses: goto-bus-stop/setup-zig@v2
        with:
          version: 0.15.0
      
      - name: Run Regression Tests
        run: zig build bench-regression
      
      - name: Run Full Benchmark Suite
        run: zig build bench
        
      - name: Archive Benchmark Results
        uses: actions/upload-artifact@v3
        with:
          name: benchmark-results
          path: benchmarks/results/
```

## Benchmark Fixtures

Test fixtures are auto-generated in `test/fixtures/`:

```
test/fixtures/
├── typescript/
│   ├── small/entity_service_100.ts      (~88 lines)
│   ├── medium/entity_service_500.ts     (~452 lines)
│   ├── large/entity_service_1000.ts     (~928 lines)
│   └── xlarge/entity_service_5000.ts    (~4652 lines)
├── python/
├── rust/
├── zig/
└── go/
```

**Regenerate fixtures:**
```bash
cd test/fixtures
python3 generate_fixtures.py
```

## Troubleshooting

### Benchmark Fails with "File not found"

Ensure fixtures are generated:
```bash
cd test/fixtures && python3 generate_fixtures.py
```

### Inconsistent Results

- Run benchmarks multiple times
- Close background applications
- Use `ReleaseFast` optimization
- Check CPU governor: `cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor`
- Set to performance: `sudo cpupower frequency-set -g performance`

### Regression Tests Fail After Valid Changes

Update baselines after verifying improvements:
1. Review performance changes
2. Update `benchmarks/baselines.json`
3. Commit updated baselines with explanation

## Best Practices

1. **Run benchmarks on consistent hardware** - Results vary across machines
2. **Minimize system load** - Close unnecessary applications
3. **Run multiple iterations** - Statistical significance requires >100 iterations
4. **Document performance changes** - Commit messages should explain improvements/regressions
5. **Update baselines deliberately** - Only after verification and code review
6. **Profile before optimizing** - Measure to find actual bottlenecks
7. **Test at scale** - Benchmark with realistic workload sizes

## Baseline File Format

`benchmarks/baselines.json`:

```json
{
  "zig": {
    "typescript_extraction_100": {
      "mean_ns": 4500000,
      "std_dev_ns": 200000
    },
    "constraint_compilation_10": {
      "mean_ns": 2000000,
      "std_dev_ns": 100000
    },
    "ffi_roundtrip": {
      "mean_ns": 500000,
      "std_dev_ns": 50000
    },
    "pipeline_e2e": {
      "mean_ns": 7000000,
      "std_dev_ns": 700000
    }
  },
  "rust": {
    "orchestrator_full_workflow": {
      "mean_ns": 8000000,
      "std_dev_ns": 300000
    },
    "cache_hit": {
      "mean_ns": 500,
      "std_dev_ns": 50
    },
    "cache_miss": {
      "mean_ns": 800000,
      "std_dev_ns": 80000
    }
  }
}
```

## Support

For questions or issues:
- Check `ARCHITECTURE_V2.md` for system design
- Review `maze/README.md` for Rust orchestration details
- Open an issue with benchmark results attached

## Next Steps

- Implement GPU-accelerated inference benchmarks (when Modal integration complete)
- Add memory leak detection
- Create visualization dashboard for historical performance trends
- Integrate with continuous benchmarking service (e.g., Bencher.dev)
