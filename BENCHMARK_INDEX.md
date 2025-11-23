# Ananke Benchmark Suite Index

## Quick Commands

```bash
# Run everything
./scripts/run_performance_analysis.sh

# Run just Zig
zig build bench-zig -Doptimize=ReleaseFast

# Run just Rust  
cd maze && cargo bench
```

## Benchmark Files

### Zig Benchmarks

| File | Component | What It Measures | Target | Location |
|------|-----------|------------------|--------|----------|
| `clew_bench.zig` | Clew | Constraint extraction from code | <10ms/file | `/Users/rand/src/ananke/benches/zig/clew_bench.zig` |
| `braid_bench.zig` | Braid | IR compilation from constraints | <50ms | `/Users/rand/src/ananke/benches/zig/braid_bench.zig` |
| `ffi_bench.zig` | FFI Bridge | Zig↔Rust type conversion overhead | <1ms/call | `/Users/rand/src/ananke/benches/zig/ffi_bench.zig` |

### Rust Benchmarks

| File | Component | What It Measures | Target | Location |
|------|-----------|------------------|--------|----------|
| `orchestration.rs` | Maze | Constraint compilation & caching | <50ms | `/Users/rand/src/ananke/maze/benches/orchestration.rs` |
| `constraint_compilation.rs` | Maze | Type serialization & conversion | <10ms | `/Users/rand/src/ananke/maze/benches/constraint_compilation.rs` |
| `cache_performance.rs` | Maze | Cache hit/miss latency | <1μs hit | `/Users/rand/src/ananke/maze/benches/cache_performance.rs` |

## Build Configuration

### Zig

Updated in `/Users/rand/src/ananke/build.zig`:

- Added `bench-clew` step
- Added `bench-braid` step
- Added `bench-ffi` step
- Added `bench-zig` step (runs all)
- Added `bench` step (runs Zig + Rust)

All benchmarks compile with `-Doptimize=ReleaseFast`.

### Rust

Updated in `/Users/rand/src/ananke/maze/Cargo.toml`:

- Added `criterion` dependency
- Configured `[[bench]]` targets
- Set `harness = false` for criterion

## Scripts

| Script | Purpose | Location |
|--------|---------|----------|
| `run_performance_analysis.sh` | Runs all benchmarks, generates report | `/Users/rand/src/ananke/scripts/run_performance_analysis.sh` |

## Documentation

| File | Content | Location |
|------|---------|----------|
| `PERFORMANCE.md` | Complete performance guide | `/Users/rand/src/ananke/PERFORMANCE.md` |
| `PERFORMANCE_QUICKSTART.md` | Quick reference | `/Users/rand/src/ananke/PERFORMANCE_QUICKSTART.md` |
| `PERFORMANCE_SUMMARY.md` | Implementation summary | `/Users/rand/src/ananke/PERFORMANCE_SUMMARY.md` |
| `BENCHMARK_INDEX.md` | This file | `/Users/rand/src/ananke/BENCHMARK_INDEX.md` |

## Results

Benchmark results are saved to:

```
/Users/rand/src/ananke/bench_results/
├── zig_YYYYMMDD_HHMMSS.txt
└── rust_YYYYMMDD_HHMMSS.txt
```

## Interpreting Output

### Zig Benchmarks

```
Small file (50 bytes):
  Iterations: 1000
  Average: 2.35ms (2350μs)
  ✓ Within target (<10ms)
```

- Look for `✓ Within target` or `⚠️ WARNING: Exceeds target!`
- Lower is better
- Cache speedup should be >1000x

### Rust Benchmarks (Criterion)

```
constraint_compilation/1
                        time:   [45.123 μs 46.234 μs 47.345 μs]
```

- Criterion shows min/median/max
- Look at median (middle value)
- Compare against targets in table above

## Performance Targets Summary

| Component | Metric | Target | Critical? |
|-----------|--------|--------|-----------|
| Constraint extraction | Latency/file | <10ms | Yes |
| IR compilation | Latency | <50ms | Yes |
| Constraint validation | Per-token | <50μs | Yes |
| FFI overhead | Per-call | <1ms | No |
| Cache hit | Latency | <1μs | Yes |
| End-to-end | Total | <5s | Yes |

## Next Steps

1. **Establish baseline:**
   ```bash
   ./scripts/run_performance_analysis.sh
   ```

2. **Check results:**
   - Look for warnings
   - Compare against targets
   - Identify bottlenecks

3. **Optimize:**
   - See `PERFORMANCE.md` for recommendations
   - Focus on high-impact, easy wins first
   - Re-run benchmarks to verify

4. **Monitor:**
   - Run benchmarks regularly
   - Track trends over time
   - Set up CI/CD alerts

## Questions?

- Quick commands: See `PERFORMANCE_QUICKSTART.md`
- Deep dive: See `PERFORMANCE.md`  
- Summary: See `PERFORMANCE_SUMMARY.md`
- This index: You're reading it
