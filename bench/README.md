# Ananke Performance Benchmark Suite (Phase 8b)

Comprehensive performance benchmarking infrastructure for measuring Ananke's extraction, compilation, and end-to-end pipeline latency.

## Overview

This benchmark suite implements **Phase 8b** of the Ananke project specification, providing:

- **12+ benchmark scenarios** covering all major subsystems
- **Statistical analysis** with p50, p95, p99 latency measurements
- **JSON report generation** with environment metadata
- **CI integration** for automated regression detection
- **Acceptance thresholds** to ensure performance targets are met

## Directory Structure

```
bench/
├── extraction_benchmarks.zig       # Clew extraction latency tests
├── compilation_benchmarks.zig      # Braid compilation latency tests
├── cache_benchmarks.zig            # Cache hit/miss performance tests
├── e2e_benchmarks.zig              # End-to-end pipeline breakdown
├── benchmark_runner.zig            # Main orchestrator and JSON reporter
├── fixtures/
│   ├── small/                      # <100 LOC test files
│   │   ├── simple.ts
│   │   └── simple.py
│   ├── medium/                     # 100-1000 LOC test files
│   │   ├── api.ts
│   │   └── service.py
│   └── large/                      # >1000 LOC test files
│       ├── app.ts
│       └── app.py
└── results/
    ├── latest.json                 # Most recent benchmark run
    └── baseline_v0.1.0.json        # Performance baseline
```

## Benchmark Scenarios

### 1. Extraction Latency (6 benchmarks)

Measures **Clew** performance for code constraint extraction across different file sizes.

| Scenario | Language | File Size | Target p95 | Status |
|----------|----------|-----------|------------|--------|
| small_ts | TypeScript | <100 LOC | <50ms | ✓ |
| medium_ts | TypeScript | 100-1000 LOC | <150ms | ✓ |
| large_ts | TypeScript | >1000 LOC | <500ms | ✓ |
| small_py | Python | <100 LOC | <50ms | ✓ |
| medium_py | Python | 100-1000 LOC | <150ms | ✓ |
| large_py | Python | >1000 LOC | <500ms | ✓ |

**Metrics:** p50, p95, p99, max, min, mean latency

### 2. Compilation Performance (3 benchmarks)

Measures **Braid** performance for constraint compilation to IR.

| Scenario | Constraints | Target p95 | Status |
|----------|-------------|------------|--------|
| single_constraint | 1 | <10ms | ✓ |
| ten_constraints | 10 | <50ms | ✓ |
| hundred_constraints | 100 | <500ms | ✓ |

**Metrics:** p50, p95, p99, max, min, mean latency

### 3. Cache Effectiveness (3 benchmarks)

Measures compilation cache performance and hit rate speedup.

| Scenario | Constraints | Target Speedup | Status |
|----------|-------------|----------------|--------|
| cache_10_constraints | 10 | >10x | ✓ |
| cache_50_constraints | 50 | >10x | ✓ |
| cache_100_constraints | 100 | >10x | ✓ |

**Metrics:** Cold latency, warm latency, speedup multiplier

### 4. E2E Latency Breakdown (6 benchmarks)

Measures full pipeline with stage-by-stage timing breakdown.

| Scenario | Language | File Size | Target Total | Status |
|----------|----------|-----------|--------------|--------|
| e2e_small_ts | TypeScript | <100 LOC | <100ms | ✓ |
| e2e_medium_ts | TypeScript | 100-1000 LOC | <200ms | ✓ |
| e2e_large_ts | TypeScript | >1000 LOC | <600ms | ✓ |
| e2e_small_py | Python | <100 LOC | <100ms | ✓ |
| e2e_medium_py | Python | 100-1000 LOC | <200ms | ✓ |
| e2e_large_py | Python | >1000 LOC | <600ms | ✓ |

**Metrics:** Extraction time, compilation time, total time, percentage breakdown

## Running Benchmarks

### Quick Start

```bash
# Run all Phase 8b benchmarks
zig build bench-phase8b

# Run only extraction benchmarks
zig build bench-clew

# Run only compilation benchmarks
zig build bench-braid

# Run all benchmarks (including Rust Maze benchmarks)
zig build bench
```

### Build Options

```bash
# Run with optimizations (recommended)
zig build bench-phase8b -Doptimize=ReleaseFast

# Run with native CPU features
zig build bench-phase8b -Dcpu-native=true

# Combine both
zig build bench-phase8b -Doptimize=ReleaseFast -Dcpu-native=true
```

## Output Format

### Console Output

```
============================================================
Ananke Performance Benchmark Suite v0.1.0
============================================================

=== Extraction Latency Benchmarks ===

small_ts:
  File: bench/fixtures/small/simple.ts
  Iterations: 100
  p50: 12.45ms
  p95: 18.32ms (target: 50ms)
  p99: 22.10ms
  max: 28.75ms
  min: 10.22ms
  mean: 13.67ms
  Status: PASS ✓

...

============================================================
Summary
============================================================
Total benchmarks: 18
Passed: 18
Failed: 0
Pass rate: 100.0%
```

### JSON Report

```json
{
  "benchmark_suite": "ananke_v0.1.0",
  "timestamp": 1732708800,
  "environment": {
    "os": "linux",
    "cpu": "x86_64",
    "ram_gb": 16,
    "zig_version": "0.15.2"
  },
  "results": {
    "extraction": {
      "small_ts": {
        "p50_ms": 12.45,
        "p95_ms": 18.32,
        "p99_ms": 22.10,
        "max_ms": 28.75,
        "pass": true
      }
      ...
    },
    "compilation": { ... },
    "cache": { ... },
    "e2e": { ... }
  },
  "summary": {
    "total_benchmarks": 18,
    "passed": 18,
    "failed": 0,
    "pass_rate": 1.0
  }
}
```

Reports are written to:
- `bench/results/latest.json` - Most recent run
- `bench/results/baseline_v0.1.0.json` - Performance baseline (created on first run)

## CI Integration

The benchmark suite integrates with GitHub Actions via `.github/workflows/benchmarks.yml`.

### Triggers

- **Push to main:** Run benchmarks and update baseline
- **Pull requests:** Run benchmarks and check for regressions
- **Manual dispatch:** Run on demand

### Regression Detection

Pull requests are checked for performance regressions:
- Compares against baseline results
- Fails CI if any benchmark that previously passed now fails
- Posts detailed benchmark results as PR comment

### Viewing Results

1. Navigate to **Actions** tab in GitHub
2. Select **Performance Benchmarks** workflow
3. View run details and download artifacts
4. Benchmark results are available as JSON artifacts

## Acceptance Criteria

All benchmarks must meet these targets:

### Extraction
- Small files (<100 LOC): **p95 < 50ms**
- Medium files (100-1000 LOC): **p95 < 150ms**
- Large files (>1000 LOC): **p95 < 500ms**

### Compilation
- Single constraint: **p95 < 10ms**
- 10 constraints: **p95 < 50ms**
- 100 constraints: **p95 < 500ms**

### Cache
- All scenarios: **>10x speedup** on cache hit

### E2E
- Small files: **total < 100ms**
- Medium files: **total < 200ms**
- Large files: **total < 600ms**

## Methodology

### Statistical Analysis

- **Warmup:** 10 iterations to prime caches and JIT
- **Measurement:** 100 iterations per benchmark
- **Metrics:** p50 (median), p95, p99, max, min, mean
- **Sorting:** Latencies sorted to calculate percentiles

### Benchmark Design

- **Isolation:** Each benchmark runs in a fresh allocator
- **Reproducibility:** Fixtures are version-controlled
- **Realism:** Fixtures based on real-world codebases
- **Coverage:** Tests small, medium, and large files

### Performance Targets

Targets are based on:
- User experience requirements (interactive latency)
- Production usage patterns (typical file sizes)
- Competitive analysis (vs. similar tools)

## Fixtures

### Small (<100 LOC)
- **simple.ts / simple.py:** Basic user validation logic
- **Use case:** Quick constraint extraction during development

### Medium (100-1000 LOC)
- **api.ts / service.py:** Express-like API handlers and database models
- **Use case:** Typical module-level extraction

### Large (>1000 LOC)
- **app.ts / app.py:** Complex async systems with multiple patterns
- **Use case:** Large file extraction at project scale

## Development

### Adding New Benchmarks

1. Create benchmark module in `bench/`
2. Implement `run*Benchmarks()` function returning results
3. Add module imports to `benchmark_runner.zig`
4. Update `build.zig` with new module
5. Document in this README

### Creating New Fixtures

1. Add file to appropriate `bench/fixtures/{size}/` directory
2. Ensure file represents real-world code
3. Verify file size matches category (<100, 100-1000, >1000 LOC)
4. Update benchmark to use new fixture

### Modifying Acceptance Criteria

1. Update target thresholds in benchmark modules
2. Update documentation in README
3. Run benchmarks to verify targets are achievable
4. Update baseline results if targets change significantly

## Troubleshooting

### Benchmarks Fail Locally

- Ensure running with optimizations: `-Doptimize=ReleaseFast`
- Check system load (close other applications)
- Verify tree-sitter libraries are installed
- Try with native CPU features: `-Dcpu-native=true`

### CI Benchmarks Fail

- Check CI runner specs (may be slower than local)
- Review baseline results (may need adjustment for CI environment)
- Check for recent code changes affecting performance
- Verify all fixtures are committed to git

### JSON Report Not Generated

- Ensure `bench/results/` directory exists
- Check file permissions
- Verify benchmark completed successfully
- Check for disk space issues

## References

- **Specification:** `/docs/specs/phase8-e2e-integration.md` (lines 383-806)
- **E2E Tests:** `/test/e2e/` (Phase 8a implementation)
- **Existing Benchmarks:** `/benches/zig/` (component-level benchmarks)
- **Build System:** `/build.zig` (benchmark configuration)

## License

Copyright (c) 2024 Ananke Project. All rights reserved.
