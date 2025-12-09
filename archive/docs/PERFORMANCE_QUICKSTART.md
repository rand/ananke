# Performance Benchmarking Quick Start

## Run All Benchmarks

```bash
./scripts/run_performance_analysis.sh
```

Results will be saved to `bench_results/` with timestamp.

## Run Specific Benchmarks

### Zig Components

```bash
# Clew extraction performance
zig build bench-clew -Doptimize=ReleaseFast

# Braid compilation performance  
zig build bench-braid -Doptimize=ReleaseFast

# FFI bridge overhead
zig build bench-ffi -Doptimize=ReleaseFast

# All Zig benchmarks
zig build bench-zig -Doptimize=ReleaseFast
```

### Rust Components

```bash
cd maze

# Orchestration benchmarks
cargo bench --bench orchestration

# Constraint compilation
cargo bench --bench constraint_compilation

# Cache performance
cargo bench --bench cache_performance

# All Rust benchmarks
cargo bench
```

## Performance Targets

| Component | Target | Command to Verify |
|-----------|--------|-------------------|
| Clew extraction | <10ms | `zig build bench-clew` |
| Braid compilation | <50ms | `zig build bench-braid` |
| FFI overhead | <1ms | `zig build bench-ffi` |
| Cache hit | <1μs | `cargo bench --bench cache_performance` |

## Quick Optimizations

### 1. Build with Optimizations

```bash
# Zig
zig build -Doptimize=ReleaseFast

# Rust
cargo build --release
```

### 2. Check Current Performance

```bash
# Run benchmarks and check if targets are met
./scripts/run_performance_analysis.sh

# Look for warnings:
# ⚠️  WARNING: Exceeds target!
# ✓ Within target
```

### 3. Profile Hot Paths

```bash
# Zig profiling
zig build -Doptimize=ReleaseFast
perf record ./zig-out/bin/ananke-profiled <args>
perf report

# Rust profiling
cargo build --release
cargo flamegraph --bench <benchmark_name>
```

## Interpreting Results

### Clew Benchmarks

```
Small file (50 bytes):
  Average: 2.35ms (2350μs)
  ✓ Within target (<10ms)
```

- Look for "Within target" confirmation
- Cache speedup should be >1000x
- Memory usage should be <10x source size

### Braid Benchmarks

```
10 constraints:
  Average: 15.42ms (15420μs)
  Throughput: 648 constraints/sec
  ✓ Within target (<50ms)
```

- Should scale roughly O(n²) due to conflict detection
- 25+ constraints may approach or exceed target
- Throughput should be >100 constraints/sec

### Cache Benchmarks

```
Cache Performance:
  Cache miss: 2.35ms
  Cache hit: 0.15μs
  Speedup: 15666.7x
```

- Hit latency must be <1μs
- Miss latency should be close to full compilation time
- Speedup should be >10,000x

## Troubleshooting

### Benchmarks Run Too Slow

1. Ensure building with optimizations: `-Doptimize=ReleaseFast`
2. Check if running in debug mode
3. Profile to find actual bottleneck

### Benchmarks Fail to Build

1. Check that all dependencies are available
2. Verify Zig version: `zig version` (should be 0.15.x or higher)
3. Update Rust: `rustup update`

### Results Inconsistent

1. Run multiple times to account for variance
2. Close other applications to reduce noise
3. Use `nice -n -20` for higher priority
4. Pin to specific CPU cores if needed

## Next Steps

See [PERFORMANCE.md](PERFORMANCE.md) for:
- Detailed benchmark descriptions
- Optimization recommendations
- Profiling integration
- Continuous monitoring setup
