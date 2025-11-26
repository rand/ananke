# Future Performance Optimization Opportunities

This document outlines potential performance improvements identified during Phase 1 mechanical sympathy optimizations. These are prioritized based on expected impact and implementation complexity.

## Status

Phase 1 mechanical sympathy optimizations (ring buffer, build config, string interning) have been completed and validated. Pipeline performance (0.10-0.18ms) already exceeds original targets (6-9ms) by 33-90x, so these are **optional** enhancements rather than critical needs.

## High-Priority Opportunities (5-15% gains)

### H1: Apply String Interning to Braid Compiler
**Expected Gain**: 8-12%
**Complexity**: Medium
**Status**: Not started

The Braid compiler has 150+ allocation sites for constraint names, descriptions, and IR metadata. Extending the string interning infrastructure to Braid could reduce allocations by 15-25%.

**Implementation**:
- Add `StringInterner` field to `BraidCompiler` struct
- Intern all constraint metadata during compilation
- Intern llguidance IR strings (token names, pattern labels)
- Update `CompilerResult` to reference interned strings

**Risk**: API changes required for Braid consumers

### H2: Memory Pool for Constraint Objects
**Expected Gain**: 10-15%
**Complexity**: High
**Status**: Not started

Constraints are allocated individually, causing fragmentation and poor cache locality. A memory pool could allocate constraints in contiguous blocks.

**Implementation**:
- Create `ConstraintPool` with fixed-size block allocator
- Pre-allocate blocks for common workload sizes (10, 50, 100 constraints)
- Reuse blocks across extraction calls in long-running processes

**Risk**: Memory overhead for small workloads

### H3: SIMD String Matching for Pattern Extractor
**Expected Gain**: 5-8%
**Complexity**: Medium
**Status**: Not started

Pattern matching currently uses simple string search. SIMD instructions could accelerate multi-pattern matching for common keywords (async, interface, class, etc.).

**Implementation**:
- Use Zig's `@Vector` for SIMD string operations
- Batch keyword searches across source lines
- Focus on hot paths in pattern extractor

**Risk**: Platform-specific optimizations may reduce portability

## Medium-Priority Opportunities (2-5% gains)

### M1: Cache Tree-sitter Parse Trees
**Expected Gain**: 3-5% (for repeated extractions)
**Complexity**: Medium
**Status**: Not started

When extracting constraints multiple times from the same file (e.g., watch mode), cache the tree-sitter parse tree.

**Implementation**:
- Add optional `ParseTreeCache` to `Clew`
- Hash source code for cache key
- Invalidate cache on source changes
- LRU eviction for memory bounds

**Risk**: Memory overhead for cache storage

### M2: Lazy Constraint Metadata
**Expected Gain**: 2-4%
**Complexity**: Low
**Status**: Not started

Constraint descriptions and origin metadata are computed eagerly but often unused. Compute them lazily on first access.

**Implementation**:
- Make `description` and `origin_line` optional fields
- Compute on first access via getter methods
- Store computed values for subsequent accesses

**Risk**: API change for constraint consumers

### M3: Vectorized Topological Sort
**Expected Gain**: 2-3%
**Complexity**: High
**Status**: Not started

Current topological sort processes constraints sequentially. Parallel processing could improve throughput for large constraint sets (100+ constraints).

**Implementation**:
- Identify independent constraint subgraphs
- Process subgraphs in parallel using thread pool
- Merge results preserving dependency ordering

**Risk**: Concurrency complexity, potential race conditions

### M4: Incremental Tree-sitter Parsing
**Expected Gain**: 4-5% (for incremental scenarios)
**Complexity**: Medium
**Status**: Not started

Tree-sitter supports incremental parsing when source changes are localized. Leverage this for watch mode or LSP integration.

**Implementation**:
- Track source edits (line/column ranges)
- Pass edit information to tree-sitter re-parse
- Only re-extract constraints from affected subtrees

**Risk**: Requires source change tracking infrastructure

### M5: Optimize llguidance IR Generation
**Expected Gain**: 3-5%
**Complexity**: Medium
**Status**: Not started

Current IR generation allocates many temporary strings. Pre-allocate buffers and reuse across constraint compilations.

**Implementation**:
- Add `IRBufferPool` to `BraidCompiler`
- Reuse buffers for JSON serialization
- Clear buffers between compilations

**Risk**: State management complexity

## Low-Priority Opportunities (0.5-2% gains)

### L1: CPU Prefetch Hints
**Expected Gain**: 0.5-1%
**Complexity**: Low
**Status**: Not started

Add prefetch hints for predictable access patterns in BFS traversal and topological sort.

**Implementation**:
- Use `@prefetch()` builtin for next queue items
- Prefetch next constraint in dependency chain
- Focus on hot loops with predictable access

**Risk**: CPU-specific behavior, may not help on all platforms

### L2: Branch Prediction Hints
**Expected Gain**: 0.5-1%
**Complexity**: Low
**Status**: Not started

Add branch hints for common control flow patterns.

**Implementation**:
- Use `@branchHint()` for error paths (unlikely)
- Mark happy paths as likely in hot loops
- Profile to identify mispredicted branches

**Risk**: Over-optimization may hurt readability

### L3: Compact Constraint Representation
**Expected Gain**: 1-2% (memory bandwidth)
**Complexity**: Medium
**Status**: Not started

Current `Constraint` struct uses 64-bit pointers and full enums. Compact representation could reduce cache pressure.

**Implementation**:
- Use 32-bit offsets instead of pointers for interned strings
- Pack `kind` and `severity` into single byte
- Reduce alignment padding with field reordering

**Risk**: Limits maximum string pool size, API changes

### L4: Deduplicate Pattern Regex Compilation
**Expected Gain**: 1-2%
**Complexity**: Low
**Status**: Not started

Pattern extractors currently compile regexes on each call. Cache compiled regexes globally.

**Implementation**:
- Global hashmap of pattern name -> compiled regex
- Lazy initialization on first use
- Read-only access in extractors (no locking needed)

**Risk**: Global state increases coupling

## Measurement and Validation

Before implementing any optimization:

1. **Benchmark baseline**: Run `zig build bench-pipeline` 10 times, record mean/stddev
2. **Profile hot paths**: Use `perf` or Instruments to identify bottlenecks
3. **Implement optimization**: Make targeted changes
4. **Benchmark again**: Compare to baseline with statistical significance
5. **Validate correctness**: Ensure all 253+ tests still pass
6. **Document results**: Update this document with actual gains

**Acceptance Criteria**:
- Measurable improvement (>2% for medium, >5% for high priority)
- No regression in correctness (all tests pass)
- No significant increase in code complexity
- Memory usage increase <10%

## Non-Recommendations

The following were considered but **not recommended**:

### ❌ Manual Memory Management
Zig's allocator system is already highly optimized. Manual memory management would increase complexity without meaningful gains.

### ❌ Custom Hash Functions
Zig's standard hash functions (Wyhash) are excellent. Custom hashing is unlikely to improve performance.

### ❌ Compressed Constraint Storage
Compression/decompression overhead exceeds memory bandwidth savings for constraint sizes we handle (typically <1MB).

### ❌ Lock-Free Data Structures
Single-threaded extraction is fast enough (0.10-0.18ms). Concurrent extraction adds complexity without clear benefit for typical workloads.

## Conclusion

Phase 1 has already achieved exceptional performance (33-90x faster than target). The optimizations listed here are **optional enhancements** that may be pursued if:

1. Workload characteristics change (e.g., 10,000+ constraint codebases)
2. New use cases emerge (e.g., real-time LSP integration)
3. Marginal improvements become valuable for specific deployments

**Recommendation**: Monitor production usage patterns before investing in further optimizations. Current performance is more than adequate for the designed use case.
