# Phase 8: End-to-End Integration & Production Readiness

**Version**: 1.0  
**Status**: PROPOSED  
**Author**: spec-author (Claude Code subagent)  
**Date**: 2025-11-27  
**Dependencies**: Phase 7 (Maze Orchestration Layer) - COMPLETE  
**Target Completion**: Weeks 12-14

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Problem Statement & Context](#problem-statement--context)
3. [Goals and Non-Goals](#goals-and-non-goals)
4. [Technical Design](#technical-design)
   - [Phase 8a: E2E Integration Tests](#phase-8a-e2e-integration-tests)
   - [Phase 8b: Performance Benchmarking](#phase-8b-performance-benchmarking)
   - [Phase 8c: Production Examples](#phase-8c-production-examples)
   - [Phase 8d: Deployment & Observability](#phase-8d-deployment--observability)
5. [Implementation Plan](#implementation-plan)
6. [Testing Strategy](#testing-strategy)
7. [Acceptance Criteria](#acceptance-criteria)
8. [Open Questions and Risks](#open-questions-and-risks)
9. [Future Phases](#future-phases)
10. [Appendices](#appendices)

---

## Executive Summary

Phase 8 transforms Ananke from a technically complete system into a production-ready platform by delivering:

1. **E2E Integration Tests**: Full pipeline validation (extract → compile → generate) with multi-language test suites
2. **Performance Benchmarking**: Comprehensive latency, throughput, and resource usage measurements
3. **Production Examples**: 5 real-world use cases demonstrating practical value
4. **Deployment Patterns**: Container images, orchestration manifests, CI/CD templates
5. **Observability**: Metrics, tracing, logging, and health monitoring

### Success Metrics

- **Reliability**: E2E test suite with 95%+ success rate
- **Performance**: <5s p95 latency for typical constraints, >10 req/sec throughput
- **Usability**: 5 production examples with <10 minute setup time each
- **Operability**: Full observability stack deployable in <30 minutes

### Timeline Estimate

- **Phase 8a (E2E Tests)**: 4 person-days
- **Phase 8b (Benchmarking)**: 3 person-days
- **Phase 8c (Examples)**: 5 person-days
- **Phase 8d (Deployment)**: 6 person-days
- **Total**: 18 person-days (2.5 weeks for 1 engineer, 1.5 weeks for 2 engineers)

---

## Problem Statement & Context

### Current State (Post-Phase 7)

**What Works:**
- Clew: Constraint extraction from TypeScript/Python (101 patterns, 40+ tests)
- Braid: Constraint compilation with LRU caching (31+ tests, 20x speedup)
- Maze: Rust orchestration with Python bindings (43 Rust tests, 14 Python tests)
- CLI: 5 commands with 12 integration tests
- Modal: Production inference service (22.3 tok/sec, A100-80GB GPU)
- Documentation: 3,577 lines across 3 comprehensive guides

**What's Missing:**
- **E2E Validation**: No tests validating the complete pipeline from source code to generated output
- **Performance Baselines**: No established benchmarks for latency/throughput/resource usage
- **Real-World Proof**: No demonstrations of practical value beyond unit tests
- **Production Patterns**: No deployment templates, monitoring configs, or operational guides
- **Regression Detection**: No automated performance regression testing in CI

### Why This Matters

Without Phase 8, Ananke is:
- **Unproven**: Users can't see real-world applicability
- **Unoptimized**: No performance baselines to guard against regressions
- **Undeployable**: No production patterns to follow
- **Unobservable**: No insight into runtime behavior in production

With Phase 8, Ananke becomes:
- **Battle-Tested**: E2E tests prove the system works end-to-end
- **Performant**: Benchmarks establish expected performance characteristics
- **Practical**: Examples demonstrate concrete value
- **Deployable**: Templates and guides enable production deployment
- **Observable**: Metrics and logs provide operational visibility

---

## Goals and Non-Goals

### Goals

#### Primary (P0) - Must Have
1. **E2E test suite** covering extract → compile → generate flows for TypeScript and Python
2. **Performance benchmarks** measuring latency (p50/p95/p99) and throughput
3. **3 production examples** demonstrating real-world value
4. **Docker images** for all components (Zig core, Rust/Python bindings, CLI)
5. **Observability foundation** with Prometheus metrics and structured logging

#### Secondary (P1) - Should Have
6. **Kubernetes manifests** for production deployment
7. **CI/CD templates** for GitHub Actions and GitLab CI
8. **2 additional examples** (5 total) covering diverse use cases
9. **OpenTelemetry tracing** for distributed request tracking
10. **Performance regression tests** in CI pipeline

#### Tertiary (P2) - Nice to Have
11. **IDE integration example** (VS Code extension skeleton)
12. **Load testing suite** for stress testing
13. **Cost analysis** for Modal inference usage
14. **Grafana dashboards** for visualization

### Non-Goals

1. **Not building a hosted service**: Deployment patterns are for self-hosting
2. **Not adding new features**: Focus is on validating existing capabilities
3. **Not optimizing algorithms**: Performance work focuses on measurement, not optimization
4. **Not creating a UI**: Observability uses standard tools (Prometheus, Grafana)
5. **Not supporting more languages**: TypeScript/Python E2E tests only (Rust/Go/Zig in future)

### Constraints

1. **Must maintain compatibility**: Cannot break existing APIs or CLI interfaces
2. **Must work with existing infrastructure**: Modal service, Zig 0.15.x, Rust 1.70+
3. **Must be reproducible**: All benchmarks must be deterministic and reproducible
4. **Must be self-documenting**: Examples and tests serve as documentation
5. **Must be lightweight**: No heavy dependencies for observability (Prometheus/OpenTelemetry only)

---

## Technical Design

### Phase 8a: E2E Integration Tests

**Objective**: Validate the complete pipeline with automated tests covering extract → compile → generate flows.

#### 8a.1 Test Architecture

```
test/e2e/
├── test_typescript_pipeline.zig       # TypeScript E2E tests
├── test_python_pipeline.zig           # Python E2E tests
├── test_constraint_satisfaction.zig   # Constraint enforcement validation
├── test_multi_constraint.zig          # Complex constraint scenarios
├── test_error_recovery.zig            # Failure mode validation
├── fixtures/
│   ├── typescript/
│   │   ├── api_handler.ts             # Express-like API handler
│   │   ├── react_component.tsx        # React component
│   │   └── validation_schema.ts       # Zod-like schema
│   ├── python/
│   │   ├── fastapi_handler.py         # FastAPI endpoint
│   │   ├── pydantic_model.py          # Pydantic model
│   │   └── pytest_test.py             # Pytest test
│   └── expected_outputs/
│       ├── api_handler_generated.ts
│       ├── fastapi_handler_generated.py
│       └── ...
└── helpers/
    ├── pipeline_runner.zig            # E2E test harness
    ├── constraint_validator.zig       # Validation helpers
    └── fixture_loader.zig             # Test data loading
```

#### 8a.2 Test Scenarios

##### Scenario 1: TypeScript API Handler Generation
```zig
// test/e2e/test_typescript_pipeline.zig
test "E2E: Generate TypeScript API handler with constraints" {
    const allocator = testing.allocator;
    
    // 1. Extract constraints from existing handler
    const source = try std.fs.cwd().readFileAlloc(
        allocator,
        "test/e2e/fixtures/typescript/api_handler.ts",
        1024 * 1024,
    );
    defer allocator.free(source);
    
    var clew = try Clew.init(allocator, null);
    defer clew.deinit();
    
    const constraints = try clew.extractFromCode(source, .typescript);
    defer allocator.free(constraints);
    
    // Validate extraction
    try testing.expect(constraints.len > 0);
    try testing.expectStringContains(constraints[0].name, "api_handler");
    
    // 2. Compile constraints
    var braid = try Braid.init(allocator);
    defer braid.deinit();
    
    const compiled = try braid.compile(constraints);
    defer allocator.free(compiled);
    
    // Validate compilation
    try testing.expect(compiled.json_schema != null);
    
    // 3. Generate new code via Maze
    const intent = "Create a POST /users endpoint with input validation";
    const generated = try generateViaMaze(allocator, intent, compiled);
    defer allocator.free(generated.code);
    
    // 4. Validate generated code
    try testing.expect(generated.success);
    try testing.expectStringContains(generated.code, "POST");
    try testing.expectStringContains(generated.code, "/users");
    try testing.expect(generated.constraint_violations.len == 0);
    
    // 5. Verify constraints satisfied
    try testing.expect(generated.validation.all_satisfied);
}
```

##### Scenario 2: Python Pydantic Model Generation
```zig
test "E2E: Generate Pydantic model from constraints" {
    const allocator = testing.allocator;
    
    // Extract from existing model
    const source = try std.fs.cwd().readFileAlloc(
        allocator,
        "test/e2e/fixtures/python/pydantic_model.py",
        1024 * 1024,
    );
    defer allocator.free(source);
    
    var clew = try Clew.init(allocator, null);
    defer clew.deinit();
    
    const constraints = try clew.extractFromCode(source, .python);
    defer allocator.free(constraints);
    
    // Compile
    var braid = try Braid.init(allocator);
    defer braid.deinit();
    
    const compiled = try braid.compile(constraints);
    defer allocator.free(compiled);
    
    // Generate
    const intent = "Create a User model with email validation";
    const generated = try generateViaMaze(allocator, intent, compiled);
    defer allocator.free(generated.code);
    
    // Validate
    try testing.expectStringContains(generated.code, "class User");
    try testing.expectStringContains(generated.code, "email");
    try testing.expectStringContains(generated.code, "validator");
    try testing.expect(generated.validation.all_satisfied);
}
```

##### Scenario 3: Multi-Constraint Satisfaction
```zig
test "E2E: Multiple constraints enforced simultaneously" {
    const allocator = testing.allocator;
    
    // Define multiple constraints
    const constraints = [_]Constraint{
        .{
            .name = "json_schema",
            .json_schema = 
                \\{"type": "object", "properties": {"id": {"type": "integer"}}}
            ,
        },
        .{
            .name = "naming_convention",
            .regex_patterns = &[_][]const u8{"^[a-z_][a-z0-9_]*$"},
        },
        .{
            .name = "security",
            .forbid_patterns = &[_][]const u8{"eval", "exec", "system"},
        },
    };
    
    // Compile
    var braid = try Braid.init(allocator);
    defer braid.deinit();
    
    const compiled = try braid.compileMultiple(&constraints);
    defer allocator.free(compiled);
    
    // Generate
    const intent = "Create a data validation function";
    const generated = try generateViaMaze(allocator, intent, compiled);
    defer allocator.free(generated.code);
    
    // Validate all constraints satisfied
    try testing.expect(generated.validation.all_satisfied);
    try testing.expect(generated.validation.satisfied.len == 3);
    
    // Verify no forbidden patterns
    try testing.expect(std.mem.indexOf(u8, generated.code, "eval") == null);
    try testing.expect(std.mem.indexOf(u8, generated.code, "exec") == null);
}
```

##### Scenario 4: Error Recovery
```zig
test "E2E: Graceful failure on invalid constraints" {
    const allocator = testing.allocator;
    
    // Invalid JSON schema
    const invalid_constraint = Constraint{
        .name = "broken_schema",
        .json_schema = "{ invalid json",
    };
    
    var braid = try Braid.init(allocator);
    defer braid.deinit();
    
    // Should fail compilation gracefully
    const result = braid.compile(&[_]Constraint{invalid_constraint});
    try testing.expectError(error.InvalidConstraint, result);
}
```

#### 8a.3 Test Infrastructure

##### Pipeline Runner
```zig
// test/e2e/helpers/pipeline_runner.zig
pub const PipelineRunner = struct {
    allocator: Allocator,
    clew: *Clew,
    braid: *Braid,
    maze_endpoint: []const u8,
    
    pub fn init(allocator: Allocator, maze_endpoint: []const u8) !*PipelineRunner {
        // Initialize all components
    }
    
    pub fn runPipeline(
        self: *PipelineRunner,
        source_code: []const u8,
        language: Language,
        intent: []const u8,
    ) !GenerationResult {
        // 1. Extract
        const constraints = try self.clew.extractFromCode(source_code, language);
        defer self.allocator.free(constraints);
        
        // 2. Compile
        const compiled = try self.braid.compile(constraints);
        defer self.allocator.free(compiled);
        
        // 3. Generate
        return try generateViaMaze(self.allocator, intent, compiled);
    }
    
    pub fn deinit(self: *PipelineRunner) void {
        // Cleanup
    }
};
```

#### 8a.4 Acceptance Criteria

**Must Pass:**
1. All E2E tests execute successfully with 95%+ pass rate
2. Tests complete in <60s total execution time
3. Tests are deterministic (same input → same output)
4. Coverage includes TypeScript and Python extraction
5. Tests validate constraint satisfaction in generated code

**Test Counts:**
- TypeScript pipeline: 5 tests
- Python pipeline: 5 tests
- Multi-constraint: 3 tests
- Error recovery: 3 tests
- **Total**: 16 E2E tests

---

### Phase 8b: Performance Benchmarking

**Objective**: Establish performance baselines and regression tests for latency, throughput, and resource usage.

#### 8b.1 Benchmark Architecture

```
bench/
├── extraction_benchmarks.zig          # Clew extraction performance
├── compilation_benchmarks.zig         # Braid compilation performance
├── generation_benchmarks.zig          # Maze generation performance
├── e2e_benchmarks.zig                 # Full pipeline performance
├── cache_benchmarks.zig               # Cache hit/miss performance
├── fixtures/
│   ├── small/                         # <100 LOC files
│   ├── medium/                        # 100-1000 LOC files
│   └── large/                         # >1000 LOC files
└── results/
    ├── baseline_v0.1.0.json           # Baseline measurements
    ├── regression_report.html         # Regression visualization
    └── benchmark_history.csv          # Historical trends
```

#### 8b.2 Benchmark Scenarios

##### Benchmark 1: Extraction Latency
```zig
// bench/extraction_benchmarks.zig
pub fn benchmarkExtraction() !void {
    const allocator = std.heap.page_allocator;
    
    const test_cases = [_]struct {
        name: []const u8,
        file: []const u8,
        expected_p95_ms: u64,
    }{
        .{ .name = "small_ts", .file = "fixtures/small/simple.ts", .expected_p95_ms = 50 },
        .{ .name = "medium_ts", .file = "fixtures/medium/api.ts", .expected_p95_ms = 150 },
        .{ .name = "large_ts", .file = "fixtures/large/app.ts", .expected_p95_ms = 500 },
        .{ .name = "small_py", .file = "fixtures/small/simple.py", .expected_p95_ms = 50 },
        .{ .name = "medium_py", .file = "fixtures/medium/service.py", .expected_p95_ms = 150 },
        .{ .name = "large_py", .file = "fixtures/large/app.py", .expected_p95_ms = 500 },
    };
    
    var results = std.ArrayList(BenchmarkResult).init(allocator);
    defer results.deinit();
    
    for (test_cases) |case| {
        const source = try std.fs.cwd().readFileAlloc(allocator, case.file, 10 * 1024 * 1024);
        defer allocator.free(source);
        
        var clew = try Clew.init(allocator, null);
        defer clew.deinit();
        
        // Warmup
        _ = try clew.extractFromCode(source, .typescript);
        
        // Measure
        var latencies = std.ArrayList(u64).init(allocator);
        defer latencies.deinit();
        
        var i: usize = 0;
        while (i < 100) : (i += 1) {
            const start = std.time.nanoTimestamp();
            _ = try clew.extractFromCode(source, .typescript);
            const end = std.time.nanoTimestamp();
            const latency_ns = @intCast(u64, end - start);
            try latencies.append(latency_ns);
        }
        
        const stats = calculateStats(latencies.items);
        
        try results.append(.{
            .name = case.name,
            .p50_ms = stats.p50 / 1_000_000,
            .p95_ms = stats.p95 / 1_000_000,
            .p99_ms = stats.p99 / 1_000_000,
            .max_ms = stats.max / 1_000_000,
            .pass = stats.p95 / 1_000_000 <= case.expected_p95_ms,
        });
    }
    
    try writeResults("results/extraction_benchmarks.json", results.items);
    try printResults(results.items);
}
```

##### Benchmark 2: Compilation Performance
```zig
pub fn benchmarkCompilation() !void {
    const allocator = std.heap.page_allocator;
    
    const test_cases = [_]struct {
        name: []const u8,
        constraint_count: usize,
        expected_p95_ms: u64,
    }{
        .{ .name = "single_constraint", .constraint_count = 1, .expected_p95_ms = 10 },
        .{ .name = "ten_constraints", .constraint_count = 10, .expected_p95_ms = 50 },
        .{ .name = "hundred_constraints", .constraint_count = 100, .expected_p95_ms = 500 },
    };
    
    var braid = try Braid.init(allocator);
    defer braid.deinit();
    
    for (test_cases) |case| {
        const constraints = try generateConstraints(allocator, case.constraint_count);
        defer allocator.free(constraints);
        
        // Warmup
        _ = try braid.compile(constraints);
        
        // Measure
        var latencies = std.ArrayList(u64).init(allocator);
        defer latencies.deinit();
        
        var i: usize = 0;
        while (i < 100) : (i += 1) {
            const start = std.time.nanoTimestamp();
            _ = try braid.compile(constraints);
            const end = std.time.nanoTimestamp();
            try latencies.append(@intCast(u64, end - start));
        }
        
        const stats = calculateStats(latencies.items);
        // Record results...
    }
}
```

##### Benchmark 3: Generation Throughput
```zig
pub fn benchmarkGenerationThroughput() !void {
    const allocator = std.heap.page_allocator;
    
    // Test different constraint complexities
    const test_cases = [_]struct {
        name: []const u8,
        constraint_file: []const u8,
        expected_tokens_per_sec: f64,
    }{
        .{ .name = "unconstrained", .constraint_file = null, .expected_tokens_per_sec = 30.0 },
        .{ .name = "json_schema", .constraint_file = "fixtures/constraints/json.json", .expected_tokens_per_sec = 20.0 },
        .{ .name = "complex_multi", .constraint_file = "fixtures/constraints/complex.json", .expected_tokens_per_sec = 15.0 },
    };
    
    for (test_cases) |case| {
        const compiled = if (case.constraint_file) |file|
            try loadAndCompileConstraints(allocator, file)
        else
            null;
        defer if (compiled) |c| allocator.free(c);
        
        const intent = "Write a function that processes user data";
        
        var total_tokens: u64 = 0;
        var total_time_ns: u64 = 0;
        
        var i: usize = 0;
        while (i < 10) : (i += 1) {
            const start = std.time.nanoTimestamp();
            const generated = try generateViaMaze(allocator, intent, compiled);
            const end = std.time.nanoTimestamp();
            defer allocator.free(generated.code);
            
            total_tokens += generated.tokens_generated;
            total_time_ns += @intCast(u64, end - start);
        }
        
        const tokens_per_sec = @intToFloat(f64, total_tokens) / 
                               (@intToFloat(f64, total_time_ns) / 1_000_000_000.0);
        
        std.debug.print("{s}: {d:.2} tokens/sec (expected: {d:.2})\n", .{
            case.name,
            tokens_per_sec,
            case.expected_tokens_per_sec,
        });
    }
}
```

##### Benchmark 4: Cache Effectiveness
```zig
pub fn benchmarkCacheEffectiveness() !void {
    const allocator = std.heap.page_allocator;
    
    var braid = try Braid.init(allocator);
    defer braid.deinit();
    
    const constraints = try loadConstraints(allocator, "fixtures/constraints/api.json");
    defer allocator.free(constraints);
    
    // Cold cache (first compilation)
    const cold_start = std.time.nanoTimestamp();
    const compiled1 = try braid.compile(constraints);
    const cold_end = std.time.nanoTimestamp();
    const cold_latency_us = @intCast(u64, cold_end - cold_start) / 1000;
    
    // Warm cache (repeated compilation)
    const warm_start = std.time.nanoTimestamp();
    const compiled2 = try braid.compile(constraints);
    const warm_end = std.time.nanoTimestamp();
    const warm_latency_us = @intCast(u64, warm_end - warm_start) / 1000;
    
    const speedup = @intToFloat(f64, cold_latency_us) / @intToFloat(f64, warm_latency_us);
    
    std.debug.print("Cache speedup: {d:.1}x\n", .{speedup});
    std.debug.print("  Cold: {d}μs\n", .{cold_latency_us});
    std.debug.print("  Warm: {d}μs\n", .{warm_latency_us});
    
    // Target: >10x speedup
    try std.testing.expect(speedup >= 10.0);
}
```

##### Benchmark 5: E2E Latency Breakdown
```zig
pub fn benchmarkE2ELatencyBreakdown() !void {
    const allocator = std.heap.page_allocator;
    
    const source = try std.fs.cwd().readFileAlloc(
        allocator,
        "fixtures/medium/api.ts",
        1024 * 1024,
    );
    defer allocator.free(source);
    
    // Measure each stage
    const extraction_start = std.time.nanoTimestamp();
    var clew = try Clew.init(allocator, null);
    defer clew.deinit();
    const constraints = try clew.extractFromCode(source, .typescript);
    const extraction_end = std.time.nanoTimestamp();
    defer allocator.free(constraints);
    
    const compilation_start = std.time.nanoTimestamp();
    var braid = try Braid.init(allocator);
    defer braid.deinit();
    const compiled = try braid.compile(constraints);
    const compilation_end = std.time.nanoTimestamp();
    defer allocator.free(compiled);
    
    const generation_start = std.time.nanoTimestamp();
    const generated = try generateViaMaze(
        allocator,
        "Create a new endpoint",
        compiled,
    );
    const generation_end = std.time.nanoTimestamp();
    defer allocator.free(generated.code);
    
    const extraction_ms = @intCast(u64, extraction_end - extraction_start) / 1_000_000;
    const compilation_ms = @intCast(u64, compilation_end - compilation_start) / 1_000_000;
    const generation_ms = @intCast(u64, generation_end - generation_start) / 1_000_000;
    const total_ms = extraction_ms + compilation_ms + generation_ms;
    
    std.debug.print("E2E Latency Breakdown:\n", .{});
    std.debug.print("  Extraction:   {d}ms ({d:.1}%)\n", .{
        extraction_ms,
        @intToFloat(f64, extraction_ms) / @intToFloat(f64, total_ms) * 100.0,
    });
    std.debug.print("  Compilation:  {d}ms ({d:.1}%)\n", .{
        compilation_ms,
        @intToFloat(f64, compilation_ms) / @intToFloat(f64, total_ms) * 100.0,
    });
    std.debug.print("  Generation:   {d}ms ({d:.1}%)\n", .{
        generation_ms,
        @intToFloat(f64, generation_ms) / @intToFloat(f64, total_ms) * 100.0,
    });
    std.debug.print("  Total:        {d}ms\n", .{total_ms});
    
    // Target: <5000ms for medium files
    try std.testing.expect(total_ms < 5000);
}
```

#### 8b.3 Benchmark Reporting

##### JSON Output Format
```json
{
  "benchmark_suite": "ananke_v0.1.0",
  "timestamp": "2025-11-27T10:30:00Z",
  "environment": {
    "os": "linux",
    "cpu": "AMD EPYC 7763",
    "ram_gb": 64,
    "zig_version": "0.15.1"
  },
  "results": {
    "extraction": {
      "small_ts": {
        "p50_ms": 15,
        "p95_ms": 45,
        "p99_ms": 60,
        "max_ms": 75,
        "pass": true
      },
      "medium_ts": {
        "p50_ms": 80,
        "p95_ms": 140,
        "p99_ms": 180,
        "max_ms": 200,
        "pass": true
      }
    },
    "compilation": {
      "single_constraint": {
        "p50_ms": 2,
        "p95_ms": 8,
        "p99_ms": 12,
        "pass": true
      }
    },
    "generation": {
      "unconstrained": {
        "tokens_per_sec": 32.5,
        "pass": true
      },
      "json_schema": {
        "tokens_per_sec": 22.3,
        "pass": true
      }
    },
    "cache": {
      "speedup": 23.4,
      "cold_us": 45000,
      "warm_us": 1923,
      "pass": true
    },
    "e2e": {
      "extraction_ms": 140,
      "compilation_ms": 35,
      "generation_ms": 2800,
      "total_ms": 2975,
      "pass": true
    }
  },
  "summary": {
    "total_benchmarks": 12,
    "passed": 12,
    "failed": 0,
    "pass_rate": 1.0
  }
}
```

#### 8b.4 CI Integration

```yaml
# .github/workflows/benchmarks.yml
name: Performance Benchmarks

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  benchmark:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Zig
        uses: goto-bus-stop/setup-zig@v2
        with:
          version: 0.15.1
      
      - name: Run Benchmarks
        run: |
          zig build bench
          
      - name: Check for Regressions
        run: |
          python scripts/check_regressions.py \
            bench/results/latest.json \
            bench/results/baseline_v0.1.0.json \
            --threshold 1.2  # Allow 20% slowdown
          
      - name: Upload Results
        uses: actions/upload-artifact@v3
        with:
          name: benchmark-results
          path: bench/results/
          
      - name: Comment PR with Results
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v6
        with:
          script: |
            const fs = require('fs');
            const results = JSON.parse(fs.readFileSync('bench/results/latest.json'));
            const comment = `## Performance Benchmark Results\n\n` +
              `**Extraction**: ${results.results.extraction.medium_ts.p95_ms}ms (p95)\n` +
              `**Compilation**: ${results.results.compilation.single_constraint.p95_ms}ms (p95)\n` +
              `**Generation**: ${results.results.generation.json_schema.tokens_per_sec} tok/sec\n` +
              `**Cache Speedup**: ${results.results.cache.speedup}x\n\n` +
              `[Full Report](https://github.com/${{github.repository}}/actions/runs/${{github.run_id}})`;
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: comment
            });
```

#### 8b.5 Acceptance Criteria

**Must Achieve:**
1. **Extraction**: p95 < 500ms for files up to 1000 LOC
2. **Compilation**: p95 < 50ms for 10 constraints
3. **Generation**: >15 tokens/sec with JSON schema constraints
4. **Cache**: >10x speedup on cache hit
5. **E2E**: p95 < 5000ms for typical constraint sets

**Deliverables:**
- Benchmark suite with 12+ scenarios
- JSON report format with historical tracking
- CI integration with regression detection
- Performance regression threshold: 20% slowdown fails CI

---

### Phase 8c: Production Examples

**Objective**: Demonstrate real-world value with 5 complete, documented examples covering diverse use cases.

#### 8c.1 Example Architecture

```
examples/production/
├── 01-openapi-route-generation/
│   ├── README.md                      # Setup and usage guide
│   ├── input/
│   │   ├── openapi.yaml               # API spec
│   │   └── existing_routes.ts         # Example routes
│   ├── constraints/
│   │   └── api_constraints.json       # Extracted constraints
│   ├── run.sh                         # One-command execution
│   ├── output/
│   │   └── generated_routes.ts        # Generated code
│   └── tests/
│       └── test_generated.ts          # Validation tests
├── 02-database-migration-generator/
├── 03-react-component-generator/
├── 04-cli-tool-generator/
└── 05-test-generator/
```

#### 8c.2 Example 1: OpenAPI Route Generation

**Use Case**: Generate Express/FastAPI routes from OpenAPI specs with automatic validation, error handling, and type safety.

**Value Proposition**: Eliminates boilerplate, ensures spec compliance, reduces manual errors.

**Setup Time**: <5 minutes

##### Input: OpenAPI Spec
```yaml
# examples/production/01-openapi-route-generation/input/openapi.yaml
openapi: 3.0.0
info:
  title: User API
  version: 1.0.0
paths:
  /users/{id}:
    get:
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: User found
          content:
            application/json:
              schema:
                type: object
                properties:
                  id:
                    type: integer
                  name:
                    type: string
                  email:
                    type: string
                    format: email
                required: [id, name, email]
        '404':
          description: User not found
```

##### Constraints from Existing Code
```typescript
// examples/production/01-openapi-route-generation/input/existing_routes.ts
app.get('/products/:id', async (req, res) => {
  const id = parseInt(req.params.id);
  if (isNaN(id)) {
    return res.status(400).json({ error: 'Invalid ID' });
  }
  
  try {
    const product = await db.products.findById(id);
    if (!product) {
      return res.status(404).json({ error: 'Not found' });
    }
    res.json(product);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  }
});
```

##### Execution Script
```bash
#!/bin/bash
# examples/production/01-openapi-route-generation/run.sh
set -e

echo "OpenAPI Route Generation Example"
echo "================================="

# 1. Extract constraints from existing routes
echo "1. Extracting constraints from existing code..."
ananke extract input/existing_routes.ts \
  --language typescript \
  -o constraints/extracted.json

# 2. Add OpenAPI constraints
echo "2. Merging with OpenAPI spec constraints..."
python scripts/openapi_to_constraints.py \
  input/openapi.yaml \
  constraints/extracted.json \
  -o constraints/api_constraints.json

# 3. Generate new route
echo "3. Generating /users/{id} route..."
ananke generate "Implement GET /users/:id route with validation and error handling" \
  --constraints constraints/api_constraints.json \
  --max-tokens 2048 \
  -o output/generated_routes.ts

# 4. Validate generated code
echo "4. Validating generated code..."
npm run test

echo ""
echo "✓ Generated route available at: output/generated_routes.ts"
echo "✓ All validations passed"
```

##### Expected Output
```typescript
// examples/production/01-openapi-route-generation/output/generated_routes.ts
app.get('/users/:id', async (req: Request, res: Response) => {
  // Validate path parameter
  const id = parseInt(req.params.id);
  if (isNaN(id) || id < 0) {
    return res.status(400).json({ error: 'Invalid user ID' });
  }
  
  try {
    // Fetch user from database
    const user = await db.users.findById(id);
    
    // Handle not found
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    // Validate response schema
    const response = {
      id: user.id,
      name: user.name,
      email: user.email,
    };
    
    // Return validated response
    res.json(response);
  } catch (error) {
    console.error('Error fetching user:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});
```

##### Validation Tests
```typescript
// examples/production/01-openapi-route-generation/tests/test_generated.ts
import { describe, it, expect } from 'vitest';
import { validateOpenAPICompliance } from './helpers';
import generatedRoute from '../output/generated_routes';

describe('Generated Route', () => {
  it('handles valid user ID', async () => {
    const response = await generatedRoute({ params: { id: '123' } });
    expect(response.status).toBe(200);
    expect(response.body).toHaveProperty('id');
    expect(response.body).toHaveProperty('name');
    expect(response.body).toHaveProperty('email');
  });
  
  it('returns 400 for invalid ID', async () => {
    const response = await generatedRoute({ params: { id: 'invalid' } });
    expect(response.status).toBe(400);
  });
  
  it('returns 404 for non-existent user', async () => {
    const response = await generatedRoute({ params: { id: '999999' } });
    expect(response.status).toBe(404);
  });
  
  it('complies with OpenAPI spec', () => {
    expect(validateOpenAPICompliance(generatedRoute, '/users/{id}')).toBe(true);
  });
});
```

#### 8c.3 Example 2: Database Migration Generator

**Use Case**: Generate type-safe database migration scripts from schema changes.

**Value Proposition**: Ensures schema consistency, prevents migration errors, automates repetitive SQL.

**Key Features:**
- Extract constraints from existing schema
- Generate up/down migrations
- Type-safe column definitions
- Automatic rollback support

##### Sample Input
```sql
-- examples/production/02-database-migration-generator/input/schema_v1.sql
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  email VARCHAR(255) NOT NULL UNIQUE,
  created_at TIMESTAMP DEFAULT NOW()
);
```

##### Desired Change
```
Add 'name' and 'updated_at' columns, add index on email
```

##### Generated Migration
```sql
-- examples/production/02-database-migration-generator/output/migration_001.sql
-- Migration: Add user name and update tracking
-- Generated: 2025-11-27 10:30:00

-- Up
ALTER TABLE users ADD COLUMN name VARCHAR(255) NOT NULL;
ALTER TABLE users ADD COLUMN updated_at TIMESTAMP DEFAULT NOW();
CREATE INDEX idx_users_email ON users(email);

-- Down
DROP INDEX IF EXISTS idx_users_email;
ALTER TABLE users DROP COLUMN IF EXISTS updated_at;
ALTER TABLE users DROP COLUMN IF EXISTS name;
```

#### 8c.4 Example 3: React Component Generator

**Use Case**: Generate React components with TypeScript, prop validation, and accessibility.

**Value Proposition**: Enforces best practices, reduces boilerplate, ensures accessibility compliance.

**Key Features:**
- Extract design patterns from existing components
- Generate with TypeScript types
- Include accessibility attributes
- Generate tests

##### Sample Input
```tsx
// examples/production/03-react-component-generator/input/Button.tsx
interface ButtonProps {
  label: string;
  onClick: () => void;
  variant?: 'primary' | 'secondary';
  disabled?: boolean;
}

export function Button({ label, onClick, variant = 'primary', disabled = false }: ButtonProps) {
  return (
    <button
      onClick={onClick}
      disabled={disabled}
      className={`btn btn-${variant}`}
      aria-label={label}
    >
      {label}
    </button>
  );
}
```

##### Generation Request
```
Create an Input component with label, validation, and error message
```

##### Generated Component
```tsx
// examples/production/03-react-component-generator/output/Input.tsx
interface InputProps {
  label: string;
  value: string;
  onChange: (value: string) => void;
  type?: 'text' | 'email' | 'password';
  required?: boolean;
  error?: string;
  disabled?: boolean;
}

export function Input({
  label,
  value,
  onChange,
  type = 'text',
  required = false,
  error,
  disabled = false,
}: InputProps) {
  const inputId = `input-${label.toLowerCase().replace(/\s+/g, '-')}`;
  const errorId = error ? `${inputId}-error` : undefined;
  
  return (
    <div className="input-group">
      <label htmlFor={inputId} className="input-label">
        {label}
        {required && <span aria-label="required">*</span>}
      </label>
      <input
        id={inputId}
        type={type}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        disabled={disabled}
        required={required}
        aria-invalid={!!error}
        aria-describedby={errorId}
        className={`input ${error ? 'input-error' : ''}`}
      />
      {error && (
        <span id={errorId} role="alert" className="input-error-message">
          {error}
        </span>
      )}
    </div>
  );
}
```

#### 8c.5 Example 4: CLI Tool Generator

**Use Case**: Generate CLI tool with argument parsing, help text, and error handling.

**Value Proposition**: Consistent CLI patterns, automatic help generation, robust error handling.

**Key Features:**
- Extract CLI patterns from existing tools
- Generate with Click/Typer/Cobra
- Include --help text
- Error handling and validation

##### Sample Input
```python
# examples/production/04-cli-tool-generator/input/existing_cli.py
@click.command()
@click.argument('input_file', type=click.Path(exists=True))
@click.option('--output', '-o', type=click.Path(), help='Output file')
@click.option('--verbose', '-v', is_flag=True, help='Verbose output')
def process(input_file, output, verbose):
    """Process an input file."""
    if verbose:
        click.echo(f'Processing {input_file}...')
    
    # Process file
    result = do_processing(input_file)
    
    if output:
        with open(output, 'w') as f:
            f.write(result)
    else:
        click.echo(result)
```

##### Generation Request
```
Create a 'validate' command that checks a JSON file against a schema
```

##### Generated CLI
```python
# examples/production/04-cli-tool-generator/output/validate_command.py
@click.command()
@click.argument('json_file', type=click.Path(exists=True), metavar='JSON_FILE')
@click.argument('schema_file', type=click.Path(exists=True), metavar='SCHEMA_FILE')
@click.option('--strict', is_flag=True, help='Enable strict validation mode')
@click.option('--output', '-o', type=click.Path(), help='Write validation report to file')
@click.option('--verbose', '-v', is_flag=True, help='Show detailed validation output')
def validate(json_file, schema_file, strict, output, verbose):
    """Validate a JSON file against a JSON Schema.
    
    Examples:
        validate data.json schema.json
        validate data.json schema.json --strict -o report.txt
    """
    try:
        # Load JSON file
        with open(json_file, 'r') as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        click.secho(f'Error: Invalid JSON in {json_file}: {e}', fg='red', err=True)
        sys.exit(1)
    except IOError as e:
        click.secho(f'Error: Could not read {json_file}: {e}', fg='red', err=True)
        sys.exit(1)
    
    try:
        # Load schema file
        with open(schema_file, 'r') as f:
            schema = json.load(f)
    except json.JSONDecodeError as e:
        click.secho(f'Error: Invalid JSON Schema in {schema_file}: {e}', fg='red', err=True)
        sys.exit(1)
    
    if verbose:
        click.echo(f'Validating {json_file} against {schema_file}...')
    
    # Validate
    from jsonschema import validate as jsonschema_validate, ValidationError
    try:
        jsonschema_validate(instance=data, schema=schema)
        result = f'✓ Validation passed: {json_file} conforms to schema'
        click.secho(result, fg='green')
        
        if output:
            with open(output, 'w') as f:
                f.write(result + '\n')
                
    except ValidationError as e:
        result = f'✗ Validation failed:\n{e.message}'
        if strict:
            click.secho(result, fg='red', err=True)
            sys.exit(1)
        else:
            click.secho(result, fg='yellow')
        
        if output:
            with open(output, 'w') as f:
                f.write(result + '\n')
```

#### 8c.6 Example 5: Test Generator from Specification

**Use Case**: Generate comprehensive tests from function specifications or documentation.

**Value Proposition**: Ensures test coverage, reduces test writing time, enforces testing patterns.

**Key Features:**
- Extract test patterns from existing tests
- Generate edge case tests
- Include mock setup and teardown
- Follow testing framework conventions

##### Sample Input
```python
# examples/production/05-test-generator/input/function_spec.py
def calculate_discount(price: float, discount_percent: float) -> float:
    """Calculate discounted price.
    
    Args:
        price: Original price (must be > 0)
        discount_percent: Discount percentage (0-100)
    
    Returns:
        Discounted price
    
    Raises:
        ValueError: If price <= 0 or discount_percent not in [0, 100]
    """
    if price <= 0:
        raise ValueError("Price must be positive")
    if not 0 <= discount_percent <= 100:
        raise ValueError("Discount percent must be between 0 and 100")
    
    return price * (1 - discount_percent / 100)
```

##### Generated Tests
```python
# examples/production/05-test-generator/output/test_calculate_discount.py
import pytest
from mymodule import calculate_discount

class TestCalculateDiscount:
    """Tests for calculate_discount function."""
    
    def test_no_discount(self):
        """Test with 0% discount."""
        result = calculate_discount(100.0, 0.0)
        assert result == 100.0
    
    def test_full_discount(self):
        """Test with 100% discount."""
        result = calculate_discount(100.0, 100.0)
        assert result == 0.0
    
    def test_partial_discount(self):
        """Test with 50% discount."""
        result = calculate_discount(100.0, 50.0)
        assert result == 50.0
    
    def test_small_price(self):
        """Test with small price value."""
        result = calculate_discount(0.01, 10.0)
        assert abs(result - 0.009) < 1e-10
    
    def test_large_price(self):
        """Test with large price value."""
        result = calculate_discount(1_000_000.0, 25.0)
        assert result == 750_000.0
    
    def test_negative_price_raises(self):
        """Test that negative price raises ValueError."""
        with pytest.raises(ValueError, match="Price must be positive"):
            calculate_discount(-10.0, 50.0)
    
    def test_zero_price_raises(self):
        """Test that zero price raises ValueError."""
        with pytest.raises(ValueError, match="Price must be positive"):
            calculate_discount(0.0, 50.0)
    
    def test_negative_discount_raises(self):
        """Test that negative discount raises ValueError."""
        with pytest.raises(ValueError, match="must be between 0 and 100"):
            calculate_discount(100.0, -10.0)
    
    def test_discount_over_100_raises(self):
        """Test that discount > 100 raises ValueError."""
        with pytest.raises(ValueError, match="must be between 0 and 100"):
            calculate_discount(100.0, 150.0)
    
    @pytest.mark.parametrize("price,discount,expected", [
        (100.0, 10.0, 90.0),
        (50.0, 20.0, 40.0),
        (200.0, 5.0, 190.0),
    ])
    def test_various_combinations(self, price, discount, expected):
        """Test various price/discount combinations."""
        result = calculate_discount(price, discount)
        assert abs(result - expected) < 1e-10
```

#### 8c.7 Example Documentation Template

Each example includes:

```markdown
# Example N: [Title]

## Overview
[2-3 sentence description of what this example demonstrates]

## Value Proposition
[Why this is useful in production, what problem it solves]

## Prerequisites
- Software/tools required
- API keys or services needed
- Estimated setup time

## Quick Start
```bash
cd examples/production/0N-example-name
./run.sh
```

## Step-by-Step Guide

### 1. Input Preparation
[How to prepare input files/data]

### 2. Constraint Extraction
[How constraints are extracted]

### 3. Code Generation
[How to trigger generation]

### 4. Validation
[How to validate generated code]

## Expected Output
[What the generated code should look like]

## Customization
[How to adapt this example for your use case]

## Troubleshooting
[Common issues and solutions]

## Next Steps
[What to try after this example]
```

#### 8c.8 Acceptance Criteria

**Must Deliver:**
1. 5 complete production examples
2. Each example runs in <10 minutes from `git clone` to working output
3. Each example includes README, input fixtures, constraints, output, and tests
4. Each example demonstrates practical value (not toy examples)
5. Examples cover TypeScript and Python (3 TS, 2 Python minimum)

**Quality Gates:**
- All examples execute successfully in CI
- Generated code passes included validation tests
- Documentation is clear and complete
- Examples demonstrate diverse use cases

---

### Phase 8d: Deployment & Observability

**Objective**: Enable production deployment with Docker, Kubernetes, CI/CD templates, and observability.

#### 8d.1 Containerization

##### Dockerfile for Zig Core
```dockerfile
# deployment/docker/Dockerfile.ananke-core
FROM alpine:3.19 AS builder

# Install Zig
RUN apk add --no-cache curl xz
RUN curl -L https://ziglang.org/download/0.15.1/zig-linux-x86_64-0.15.1.tar.xz | tar -xJ
ENV PATH="/zig-linux-x86_64-0.15.1:${PATH}"

# Build Ananke
WORKDIR /build
COPY . .
RUN zig build -Doptimize=ReleaseFast

FROM alpine:3.19
RUN apk add --no-cache libgcc libstdc++
COPY --from=builder /build/zig-out/bin/ananke /usr/local/bin/ananke
ENTRYPOINT ["/usr/local/bin/ananke"]
```

##### Dockerfile for Python API
```dockerfile
# deployment/docker/Dockerfile.ananke-python
FROM python:3.11-slim AS builder

# Install Rust for building
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# Install maturin
RUN pip install maturin

# Build Python bindings
WORKDIR /build
COPY maze/ maze/
WORKDIR /build/maze
RUN maturin build --release

FROM python:3.11-slim
COPY --from=builder /build/maze/target/wheels/*.whl /tmp/
RUN pip install /tmp/*.whl && rm /tmp/*.whl

# Install CLI
COPY maze/python/ /app/
WORKDIR /app
RUN pip install -e .

ENTRYPOINT ["ananke"]
```

##### Docker Compose for Development
```yaml
# deployment/docker/docker-compose.yml
version: '3.8'

services:
  ananke-core:
    build:
      context: ../..
      dockerfile: deployment/docker/Dockerfile.ananke-core
    volumes:
      - ./workdir:/workdir
    environment:
      - ANANKE_MODAL_ENDPOINT=${ANANKE_MODAL_ENDPOINT}
      - ANANKE_MODAL_API_KEY=${ANANKE_MODAL_API_KEY}
    command: ["--help"]
  
  ananke-python:
    build:
      context: ../..
      dockerfile: deployment/docker/Dockerfile.ananke-python
    volumes:
      - ./workdir:/workdir
    environment:
      - MODAL_ENDPOINT=${ANANKE_MODAL_ENDPOINT}
      - MODAL_API_KEY=${ANANKE_MODAL_API_KEY}
    ports:
      - "8000:8000"
    command: ["--help"]
  
  prometheus:
    image: prom/prometheus:latest
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
    ports:
      - "9090:9090"
  
  grafana:
    image: grafana/grafana:latest
    volumes:
      - ./monitoring/grafana-dashboards:/etc/grafana/provisioning/dashboards
      - ./monitoring/grafana-datasources.yml:/etc/grafana/provisioning/datasources/datasources.yml
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
```

#### 8d.2 Kubernetes Deployment

##### Core Deployment
```yaml
# deployment/kubernetes/ananke-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ananke-api
  labels:
    app: ananke
    component: api
spec:
  replicas: 3
  selector:
    matchLabels:
      app: ananke
      component: api
  template:
    metadata:
      labels:
        app: ananke
        component: api
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9091"
        prometheus.io/path: "/metrics"
    spec:
      containers:
      - name: ananke
        image: ananke/ananke-python:0.1.0
        ports:
        - containerPort: 8000
          name: http
        - containerPort: 9091
          name: metrics
        env:
        - name: MODAL_ENDPOINT
          valueFrom:
            secretKeyRef:
              name: ananke-secrets
              key: modal-endpoint
        - name: MODAL_API_KEY
          valueFrom:
            secretKeyRef:
              name: ananke-secrets
              key: modal-api-key
        - name: ANANKE_LOG_LEVEL
          value: "info"
        - name: ANANKE_CACHE_SIZE
          value: "10000"
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "2000m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8000
          initialDelaySeconds: 10
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: ananke-api
  labels:
    app: ananke
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 8000
    name: http
  - port: 9091
    targetPort: 9091
    name: metrics
  selector:
    app: ananke
    component: api
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: ananke-api-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: ananke-api
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

##### Secrets Management
```yaml
# deployment/kubernetes/ananke-secrets.yaml
apiVersion: v1
kind: Secret
metadata:
  name: ananke-secrets
type: Opaque
stringData:
  modal-endpoint: "https://rand--ananke-inference-generate-api.modal.run"
  modal-api-key: "CHANGE_ME"  # Replace in production
```

#### 8d.3 CI/CD Templates

##### GitHub Actions
```yaml
# deployment/ci-cd/github-actions.yml
name: Ananke Production Deployment

on:
  push:
    branches: [main, production]
    tags: ['v*']

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Zig
        uses: goto-bus-stop/setup-zig@v2
        with:
          version: 0.15.1
      
      - name: Run Unit Tests
        run: zig build test
      
      - name: Run E2E Tests
        run: zig build test-e2e
        env:
          ANANKE_MODAL_ENDPOINT: ${{ secrets.MODAL_ENDPOINT }}
          ANANKE_MODAL_API_KEY: ${{ secrets.MODAL_API_KEY }}
      
      - name: Run Benchmarks
        run: zig build bench
      
      - name: Check for Regressions
        run: python scripts/check_regressions.py
  
  build-core:
    needs: test
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    steps:
      - uses: actions/checkout@v3
      
      - name: Log in to Container Registry
        uses: docker/login-action@v2
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      
      - name: Extract Metadata
        id: meta
        uses: docker/metadata-action@v4
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}-core
      
      - name: Build and Push
        uses: docker/build-push-action@v4
        with:
          context: .
          file: deployment/docker/Dockerfile.ananke-core
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
  
  build-python:
    needs: test
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    steps:
      - uses: actions/checkout@v3
      
      - name: Log in to Container Registry
        uses: docker/login-action@v2
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      
      - name: Extract Metadata
        id: meta
        uses: docker/metadata-action@v4
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}-python
      
      - name: Build and Push
        uses: docker/build-push-action@v4
        with:
          context: .
          file: deployment/docker/Dockerfile.ananke-python
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
  
  deploy-staging:
    needs: [build-core, build-python]
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup kubectl
        uses: azure/setup-kubectl@v3
      
      - name: Configure kubeconfig
        run: |
          echo "${{ secrets.KUBE_CONFIG_STAGING }}" | base64 -d > kubeconfig
          export KUBECONFIG=kubeconfig
      
      - name: Deploy to Staging
        run: |
          kubectl apply -f deployment/kubernetes/
          kubectl rollout status deployment/ananke-api -n staging
      
      - name: Run Smoke Tests
        run: |
          export ANANKE_ENDPOINT="https://staging.ananke.example.com"
          python tests/smoke_tests.py
  
  deploy-production:
    needs: deploy-staging
    runs-on: ubuntu-latest
    environment: production
    if: startsWith(github.ref, 'refs/tags/v')
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup kubectl
        uses: azure/setup-kubectl@v3
      
      - name: Configure kubeconfig
        run: |
          echo "${{ secrets.KUBE_CONFIG_PROD }}" | base64 -d > kubeconfig
          export KUBECONFIG=kubeconfig
      
      - name: Deploy to Production
        run: |
          kubectl apply -f deployment/kubernetes/
          kubectl rollout status deployment/ananke-api -n production
      
      - name: Run Production Health Check
        run: |
          export ANANKE_ENDPOINT="https://api.ananke.example.com"
          python tests/health_check.py
```

##### GitLab CI
```yaml
# deployment/ci-cd/gitlab-ci.yml
stages:
  - test
  - build
  - deploy-staging
  - deploy-production

variables:
  DOCKER_TLS_CERTDIR: "/certs"
  REGISTRY: $CI_REGISTRY
  IMAGE_NAME: $CI_REGISTRY_IMAGE

test:unit:
  stage: test
  image: alpine:3.19
  script:
    - apk add --no-cache curl xz
    - curl -L https://ziglang.org/download/0.15.1/zig-linux-x86_64-0.15.1.tar.xz | tar -xJ
    - export PATH="$PWD/zig-linux-x86_64-0.15.1:$PATH"
    - zig build test

test:e2e:
  stage: test
  script:
    - zig build test-e2e
  variables:
    ANANKE_MODAL_ENDPOINT: $MODAL_ENDPOINT
    ANANKE_MODAL_API_KEY: $MODAL_API_KEY

test:bench:
  stage: test
  script:
    - zig build bench
  artifacts:
    paths:
      - bench/results/
    expire_in: 30 days

build:core:
  stage: build
  image: docker:latest
  services:
    - docker:dind
  script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
    - docker build -t $IMAGE_NAME-core:$CI_COMMIT_SHORT_SHA -f deployment/docker/Dockerfile.ananke-core .
    - docker push $IMAGE_NAME-core:$CI_COMMIT_SHORT_SHA
  only:
    - main
    - tags

build:python:
  stage: build
  image: docker:latest
  services:
    - docker:dind
  script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
    - docker build -t $IMAGE_NAME-python:$CI_COMMIT_SHORT_SHA -f deployment/docker/Dockerfile.ananke-python .
    - docker push $IMAGE_NAME-python:$CI_COMMIT_SHORT_SHA
  only:
    - main
    - tags

deploy:staging:
  stage: deploy-staging
  image: bitnami/kubectl:latest
  script:
    - echo "$KUBE_CONFIG_STAGING" | base64 -d > kubeconfig
    - export KUBECONFIG=kubeconfig
    - kubectl apply -f deployment/kubernetes/
    - kubectl rollout status deployment/ananke-api -n staging
  environment:
    name: staging
    url: https://staging.ananke.example.com
  only:
    - main

deploy:production:
  stage: deploy-production
  image: bitnami/kubectl:latest
  script:
    - echo "$KUBE_CONFIG_PROD" | base64 -d > kubeconfig
    - export KUBECONFIG=kubeconfig
    - kubectl apply -f deployment/kubernetes/
    - kubectl rollout status deployment/ananke-api -n production
  environment:
    name: production
    url: https://api.ananke.example.com
  when: manual
  only:
    - tags
```

#### 8d.4 Observability

##### Prometheus Metrics
```rust
// maze/src/metrics.rs
use prometheus::{IntCounterVec, HistogramVec, Registry, Opts, register_int_counter_vec, register_histogram_vec};

lazy_static! {
    pub static ref REGISTRY: Registry = Registry::new();
    
    pub static ref REQUESTS_TOTAL: IntCounterVec = register_int_counter_vec!(
        Opts::new("ananke_requests_total", "Total number of requests"),
        &["operation", "status"]
    ).unwrap();
    
    pub static ref REQUEST_DURATION: HistogramVec = register_histogram_vec!(
        "ananke_request_duration_seconds",
        "Request duration in seconds",
        &["operation"],
        vec![0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1.0, 5.0, 10.0]
    ).unwrap();
    
    pub static ref CACHE_HITS: IntCounterVec = register_int_counter_vec!(
        Opts::new("ananke_cache_hits_total", "Total cache hits"),
        &["cache_type"]
    ).unwrap();
    
    pub static ref CACHE_MISSES: IntCounterVec = register_int_counter_vec!(
        Opts::new("ananke_cache_misses_total", "Total cache misses"),
        &["cache_type"]
    ).unwrap();
    
    pub static ref GENERATION_TOKENS: HistogramVec = register_histogram_vec!(
        "ananke_generation_tokens",
        "Number of tokens generated",
        &["model"],
        vec![10.0, 50.0, 100.0, 500.0, 1000.0, 2000.0, 5000.0]
    ).unwrap();
    
    pub static ref CONSTRAINT_VIOLATIONS: IntCounterVec = register_int_counter_vec!(
        Opts::new("ananke_constraint_violations_total", "Total constraint violations"),
        &["constraint_type"]
    ).unwrap();
}

pub fn record_request(operation: &str, status: &str) {
    REQUESTS_TOTAL.with_label_values(&[operation, status]).inc();
}

pub fn record_duration(operation: &str, duration_secs: f64) {
    REQUEST_DURATION.with_label_values(&[operation]).observe(duration_secs);
}

pub fn record_cache_hit(cache_type: &str) {
    CACHE_HITS.with_label_values(&[cache_type]).inc();
}

pub fn record_cache_miss(cache_type: &str) {
    CACHE_MISSES.with_label_values(&[cache_type]).inc();
}
```

##### Prometheus Configuration
```yaml
# deployment/monitoring/prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'ananke-api'
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
      - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        regex: ([^:]+)(?::\d+)?;(\d+)
        replacement: $1:$2
        target_label: __address__
      - action: labelmap
        regex: __meta_kubernetes_pod_label_(.+)
```

##### OpenTelemetry Tracing
```rust
// maze/src/tracing.rs
use opentelemetry::{global, KeyValue};
use opentelemetry::sdk::trace::{self, Tracer};
use opentelemetry_otlp::WithExportConfig;
use tracing_subscriber::{layer::SubscriberExt, Registry};
use tracing_opentelemetry::OpenTelemetryLayer;

pub fn init_telemetry() -> Result<(), Box<dyn std::error::Error>> {
    let tracer = opentelemetry_otlp::new_pipeline()
        .tracing()
        .with_exporter(
            opentelemetry_otlp::new_exporter()
                .tonic()
                .with_endpoint("http://otel-collector:4317")
        )
        .with_trace_config(
            trace::config().with_resource(opentelemetry::sdk::Resource::new(vec![
                KeyValue::new("service.name", "ananke-api"),
                KeyValue::new("service.version", env!("CARGO_PKG_VERSION")),
            ]))
        )
        .install_batch(opentelemetry::runtime::Tokio)?;
    
    let telemetry_layer = OpenTelemetryLayer::new(tracer);
    let subscriber = Registry::default().with(telemetry_layer);
    tracing::subscriber::set_global_default(subscriber)?;
    
    Ok(())
}

#[tracing::instrument(skip(request))]
pub async fn generate_with_tracing(request: GenerationRequest) -> Result<GenerationResponse> {
    let span = tracing::span!(tracing::Level::INFO, "generate", 
        constraint_count = request.constraints_ir.len(),
        max_tokens = request.max_tokens
    );
    
    let _enter = span.enter();
    
    // Generate code
    let response = generate_internal(request).await?;
    
    tracing::info!(
        tokens_generated = response.metadata.tokens_generated,
        duration_ms = response.metadata.generation_time_ms,
        "Generation completed"
    );
    
    Ok(response)
}
```

##### Structured Logging
```rust
// maze/src/logging.rs
use serde_json::json;
use tracing::{info, warn, error};

pub fn log_request_start(request_id: &str, operation: &str, params: serde_json::Value) {
    info!(
        request_id = request_id,
        operation = operation,
        params = %params,
        "Request started"
    );
}

pub fn log_request_end(request_id: &str, operation: &str, duration_ms: u64, status: &str) {
    info!(
        request_id = request_id,
        operation = operation,
        duration_ms = duration_ms,
        status = status,
        "Request completed"
    );
}

pub fn log_cache_hit(cache_type: &str, key: &str) {
    info!(
        cache_type = cache_type,
        key = key,
        "Cache hit"
    );
}

pub fn log_constraint_violation(constraint_name: &str, violation: &str) {
    warn!(
        constraint_name = constraint_name,
        violation = violation,
        "Constraint violation detected"
    );
}

pub fn log_generation_error(request_id: &str, error: &str) {
    error!(
        request_id = request_id,
        error = error,
        "Generation failed"
    );
}
```

##### Grafana Dashboard
```json
// deployment/monitoring/grafana-dashboards/ananke-overview.json
{
  "dashboard": {
    "title": "Ananke Overview",
    "panels": [
      {
        "title": "Request Rate",
        "targets": [{
          "expr": "rate(ananke_requests_total[5m])"
        }]
      },
      {
        "title": "Request Duration (p95)",
        "targets": [{
          "expr": "histogram_quantile(0.95, rate(ananke_request_duration_seconds_bucket[5m]))"
        }]
      },
      {
        "title": "Cache Hit Rate",
        "targets": [{
          "expr": "rate(ananke_cache_hits_total[5m]) / (rate(ananke_cache_hits_total[5m]) + rate(ananke_cache_misses_total[5m]))"
        }]
      },
      {
        "title": "Generation Tokens/sec",
        "targets": [{
          "expr": "rate(ananke_generation_tokens[5m])"
        }]
      },
      {
        "title": "Constraint Violations",
        "targets": [{
          "expr": "rate(ananke_constraint_violations_total[5m])"
        }]
      }
    ]
  }
}
```

#### 8d.5 Health Checks

```python
# maze/python/ananke/health.py
from typing import Dict, Any
import asyncio
from datetime import datetime

class HealthChecker:
    """Health check implementation for Ananke."""
    
    def __init__(self, ananke: Ananke):
        self.ananke = ananke
    
    async def check_health(self) -> Dict[str, Any]:
        """Perform comprehensive health check."""
        checks = {
            "modal_service": await self._check_modal_service(),
            "cache": await self._check_cache(),
            "memory": self._check_memory(),
        }
        
        overall_healthy = all(check["healthy"] for check in checks.values())
        
        return {
            "status": "healthy" if overall_healthy else "unhealthy",
            "timestamp": datetime.utcnow().isoformat(),
            "checks": checks
        }
    
    async def _check_modal_service(self) -> Dict[str, Any]:
        """Check Modal inference service connectivity."""
        try:
            healthy = await self.ananke.health_check()
            return {
                "healthy": healthy,
                "message": "Modal service is reachable" if healthy else "Modal service unavailable"
            }
        except Exception as e:
            return {
                "healthy": False,
                "message": f"Modal service check failed: {e}"
            }
    
    async def _check_cache(self) -> Dict[str, Any]:
        """Check cache status."""
        try:
            stats = await self.ananke.cache_stats()
            usage_percent = (stats['size'] / stats['limit']) * 100 if stats['limit'] > 0 else 0
            
            return {
                "healthy": usage_percent < 95,  # Unhealthy if >95% full
                "message": f"Cache usage: {usage_percent:.1f}%",
                "size": stats['size'],
                "limit": stats['limit']
            }
        except Exception as e:
            return {
                "healthy": False,
                "message": f"Cache check failed: {e}"
            }
    
    def _check_memory(self) -> Dict[str, Any]:
        """Check memory usage."""
        import psutil
        memory = psutil.virtual_memory()
        
        return {
            "healthy": memory.percent < 90,  # Unhealthy if >90% used
            "message": f"Memory usage: {memory.percent:.1f}%",
            "used_mb": memory.used / (1024 * 1024),
            "total_mb": memory.total / (1024 * 1024)
        }
```

#### 8d.6 Graceful Degradation

```python
# maze/python/ananke/degradation.py
from typing import Optional
import asyncio

class DegradationStrategy:
    """Handle service degradation gracefully."""
    
    def __init__(self, ananke: Ananke):
        self.ananke = ananke
        self.fallback_mode = False
    
    async def generate_with_fallback(
        self,
        request: PyGenerationRequest,
        timeout_secs: int = 30
    ) -> PyGenerationResponse:
        """Generate with automatic fallback on timeout/error."""
        try:
            # Try primary generation with timeout
            response = await asyncio.wait_for(
                self.ananke.generate(request),
                timeout=timeout_secs
            )
            return response
            
        except asyncio.TimeoutError:
            # Fallback 1: Retry with fewer constraints
            if request.constraints_ir:
                reduced_request = self._reduce_constraints(request)
                try:
                    return await asyncio.wait_for(
                        self.ananke.generate(reduced_request),
                        timeout=timeout_secs // 2
                    )
                except:
                    pass
            
            # Fallback 2: Generate without constraints
            unconstrained_request = PyGenerationRequest(
                prompt=request.prompt,
                constraints_ir=[],
                max_tokens=request.max_tokens,
                temperature=request.temperature
            )
            
            return await self.ananke.generate(unconstrained_request)
        
        except Exception as e:
            # Log error and re-raise
            print(f"Generation failed: {e}")
            raise
    
    def _reduce_constraints(self, request: PyGenerationRequest) -> PyGenerationRequest:
        """Reduce constraint complexity for fallback."""
        # Keep only high-priority constraints
        essential = [c for c in request.constraints_ir if "critical" in c.name.lower()]
        
        return PyGenerationRequest(
            prompt=request.prompt,
            constraints_ir=essential,
            max_tokens=request.max_tokens,
            temperature=request.temperature,
            context=request.context
        )
```

#### 8d.7 Acceptance Criteria

**Must Deliver:**
1. Docker images for Zig core and Python API
2. Kubernetes deployment manifests with HPA and health checks
3. CI/CD templates for GitHub Actions and GitLab CI
4. Prometheus metrics with 8+ key metrics
5. Grafana dashboard for operational visibility
6. Structured logging with JSON format
7. Health check endpoint with comprehensive checks

**Quality Gates:**
- Docker images build successfully in CI
- Kubernetes manifests deploy without errors
- Metrics are exposed and scrapable by Prometheus
- Health checks return accurate status
- Logs are structured and queryable

---

## Implementation Plan

### Timeline Overview

```
Phase 8a: E2E Tests (4 person-days)
├── Day 1: Test infrastructure and TypeScript tests
├── Day 2: Python tests and multi-constraint tests
├── Day 3: Error recovery and test automation
└── Day 4: CI integration and documentation

Phase 8b: Benchmarking (3 person-days)
├── Day 1: Extraction and compilation benchmarks
├── Day 2: Generation and E2E benchmarks
└── Day 3: CI integration and regression detection

Phase 8c: Production Examples (5 person-days)
├── Day 1: Example 1 (OpenAPI routes)
├── Day 2: Example 2 (DB migrations)
├── Day 3: Example 3 (React components)
├── Day 4: Examples 4-5 (CLI, tests)
└── Day 5: Documentation and polish

Phase 8d: Deployment (6 person-days)
├── Day 1: Docker images
├── Day 2: Kubernetes manifests
├── Day 3: CI/CD templates
├── Day 4: Prometheus metrics
├── Day 5: OpenTelemetry tracing and logging
└── Day 6: Health checks and documentation
```

### Dependencies

```
Phase 7 (Complete) → Phase 8a (E2E Tests)
                   → Phase 8b (Benchmarking)
                   → Phase 8c (Examples)
                   → Phase 8d (Deployment)

Phase 8a + 8b → CI regression detection
Phase 8c → User-facing documentation
Phase 8d → Production deployment guides
```

### Parallelization Strategy

**Week 1:**
- Engineer 1: Phase 8a (E2E Tests) - Days 1-4
- Engineer 2: Phase 8b (Benchmarking) - Days 1-3
- Engineer 2: Phase 8c (Examples) - Days 4-5

**Week 2:**
- Engineer 1: Phase 8c (Examples continued) - Days 1-2
- Engineer 1: Phase 8d (Deployment) - Days 3-5
- Engineer 2: Phase 8d (Deployment) - Days 1-5

**Week 3:**
- Both: Final integration, testing, documentation - Days 1-3

### Resource Requirements

**Human Resources:**
- 1-2 engineers with Zig/Rust/Python experience
- 0.5 DevOps engineer for deployment infrastructure
- 0.25 technical writer for documentation review

**Infrastructure:**
- GitHub/GitLab CI runners
- Kubernetes cluster for deployment testing
- Prometheus/Grafana for observability testing
- Modal account for E2E testing

**Tools:**
- Docker, Kubernetes (kubectl, helm)
- Prometheus, Grafana, OpenTelemetry
- GitHub Actions or GitLab CI

---

## Testing Strategy

### Test Pyramid

```
        /\
       /E2E\          16 E2E tests (extract → compile → generate)
      /______\
     /        \
    / Integration\   26 integration tests (existing)
   /____________\
  /              \
 /   Unit Tests   \  71+ unit tests (existing)
/__________________\
```

### Test Coverage Targets

| Component | Unit Tests | Integration Tests | E2E Tests | Total |
|-----------|-----------|-------------------|-----------|-------|
| Clew (extraction) | 40 | 8 | 8 | 56 |
| Braid (compilation) | 31 | 6 | 4 | 41 |
| Maze (generation) | 0* | 12 | 4 | 16 |
| CLI | 0* | 12 | 0 | 12 |
| **Total** | **71** | **38** | **16** | **125** |

*Rust/Python tests counted separately

### Performance Test Criteria

| Metric | Target | Measurement |
|--------|--------|-------------|
| Extraction latency (p95) | <500ms | Benchmarks |
| Compilation latency (p95) | <50ms | Benchmarks |
| Generation throughput | >15 tok/sec | Benchmarks |
| Cache speedup | >10x | Benchmarks |
| E2E latency (p95) | <5000ms | E2E tests |

### CI Test Execution

```yaml
# Executed on every PR
- Unit tests (71 tests) - <30s
- Integration tests (38 tests) - <60s
- E2E tests (16 tests) - <120s (requires Modal)
- Benchmarks (12 scenarios) - <180s
- Total: <390s (~6.5 minutes)
```

### Acceptance Test Scenarios

**Scenario 1: TypeScript API Handler**
- Input: Express.js handler code
- Constraints: Extracted patterns + JSON schema
- Output: New handler with validation
- Validation: Generated code passes TypeScript compiler and runtime tests

**Scenario 2: Python Pydantic Model**
- Input: Existing Pydantic model
- Constraints: Type annotations + validators
- Output: New model with similar structure
- Validation: Generated code passes mypy and Pydantic validation

**Scenario 3: Multi-Language Consistency**
- Input: TypeScript and Python codebases
- Constraints: Shared patterns
- Output: Consistent code across languages
- Validation: Both outputs satisfy constraints

---

## Acceptance Criteria

### Phase 8a: E2E Integration Tests

**Functional Requirements:**
- [ ] 16 E2E tests covering TypeScript and Python pipelines
- [ ] Tests validate extract → compile → generate flow
- [ ] Tests execute in <120s total
- [ ] 95%+ test pass rate
- [ ] Tests run in CI on every commit

**Quality Requirements:**
- [ ] Tests are deterministic (no flaky tests)
- [ ] Test fixtures are realistic (not toy examples)
- [ ] Test failures provide actionable error messages
- [ ] Tests cover happy path and error scenarios

### Phase 8b: Performance Benchmarking

**Functional Requirements:**
- [ ] 12+ benchmark scenarios measuring latency and throughput
- [ ] Baseline measurements recorded for v0.1.0
- [ ] CI detects >20% performance regressions
- [ ] Results exported to JSON format

**Performance Targets:**
- [ ] Extraction: p95 < 500ms for 1000 LOC files
- [ ] Compilation: p95 < 50ms for 10 constraints
- [ ] Generation: >15 tokens/sec with JSON schema
- [ ] Cache: >10x speedup on hit
- [ ] E2E: p95 < 5000ms

### Phase 8c: Production Examples

**Functional Requirements:**
- [ ] 5 complete production examples
- [ ] Each example runs end-to-end in <10 minutes
- [ ] Each example includes README, inputs, outputs, tests
- [ ] Examples cover TypeScript (3) and Python (2)

**Quality Requirements:**
- [ ] Generated code passes included validation tests
- [ ] Documentation is clear and complete
- [ ] Examples demonstrate real-world value
- [ ] Each example has <5 prerequisite steps

### Phase 8d: Deployment & Observability

**Functional Requirements:**
- [ ] Docker images for core and Python API
- [ ] Kubernetes manifests with HPA and probes
- [ ] CI/CD templates for GitHub Actions and GitLab CI
- [ ] Prometheus metrics (8+ metrics)
- [ ] Grafana dashboard with 5+ panels
- [ ] Structured JSON logging
- [ ] Health check endpoint

**Quality Requirements:**
- [ ] Images build in CI without errors
- [ ] Kubernetes deploys successfully
- [ ] Metrics are accurate and useful
- [ ] Logs are queryable and structured
- [ ] Health checks detect actual issues

---

## Open Questions and Risks

### Open Questions

1. **Q: Should we support local inference (llama.cpp) in Phase 8?**
   - **Recommendation**: No, defer to Phase 9
   - **Rationale**: Modal service is working well, local inference adds complexity

2. **Q: Should E2E tests require Modal access in CI?**
   - **Recommendation**: Yes, but make it optional for community forks
   - **Rationale**: Critical to validate full pipeline, but shouldn't block external contributors

3. **Q: Should we include cost analysis in benchmarks?**
   - **Recommendation**: Yes, as secondary metric
   - **Rationale**: Useful for production planning, but not a blocker

4. **Q: Should examples be in separate repository?**
   - **Recommendation**: No, keep in main repo under `examples/production/`
   - **Rationale**: Easier to maintain version synchronization

5. **Q: Should we provide Helm charts or raw Kubernetes manifests?**
   - **Recommendation**: Start with raw manifests, add Helm in Phase 9
   - **Rationale**: Simpler for initial adoption, Helm adds complexity

### Risks

#### Risk 1: E2E Test Flakiness (MEDIUM)

**Description**: E2E tests may be flaky due to network issues, Modal service variability, or non-deterministic generation.

**Mitigation:**
- Use deterministic temperature (0.0) in tests
- Implement retry logic for network failures
- Mock Modal responses for fast tests, real service for nightly runs
- Set generous timeouts

**Owner**: Phase 8a lead

#### Risk 2: Performance Regression Detection False Positives (MEDIUM)

**Description**: Benchmark variance may trigger false regression alerts.

**Mitigation:**
- Set threshold at 20% to allow for variance
- Run benchmarks multiple times and average
- Compare against rolling average, not single baseline
- Manual review of flagged regressions

**Owner**: Phase 8b lead

#### Risk 3: Example Complexity Creep (LOW)

**Description**: Examples may become too complex or time-consuming to run.

**Mitigation:**
- Enforce <10 minute setup time requirement
- Keep examples focused on single use case
- Provide "quick start" and "detailed" paths
- Test examples in CI

**Owner**: Phase 8c lead

#### Risk 4: Kubernetes Deployment Complexity (MEDIUM)

**Description**: Kubernetes manifests may not work across different clusters/versions.

**Mitigation:**
- Test on multiple Kubernetes versions (1.27-1.29)
- Use stable API versions only
- Provide troubleshooting guide
- Include minimal deployment (no HPA/monitoring) option

**Owner**: Phase 8d lead

#### Risk 5: Observability Overhead (LOW)

**Description**: Metrics/tracing may impact performance.

**Mitigation:**
- Use sampling for high-frequency operations
- Make observability optional (compile-time feature)
- Benchmark with/without observability
- Document overhead in metrics

**Owner**: Phase 8d lead

### Assumptions

1. **Modal service remains stable**: Deployment endpoint doesn't change during Phase 8
2. **Zig 0.15.x compatibility**: No breaking changes in Zig compiler
3. **Network access in CI**: GitHub/GitLab runners can reach Modal service
4. **Kubernetes access**: Users have access to Kubernetes cluster for deployment testing
5. **Community interest**: Users value production deployment patterns

---

## Future Phases

### Phase 9: Advanced Features (Q1 2026)

**Potential Scope:**
1. **Streaming Generation**: Token-by-token streaming via SSE
2. **Local Inference**: llama.cpp/GGUF support for offline usage
3. **Multi-Model Ensemble**: Generate from multiple models and merge
4. **IDE Integration**: VS Code extension with inline generation
5. **Web UI**: Browser-based constraint editor and generation interface

**Dependencies**: Phase 8 completion

### Phase 10: Scale & Optimization (Q2 2026)

**Potential Scope:**
1. **Distributed Caching**: Redis/Memcached for multi-instance deployments
2. **Horizontal Scaling**: Load balancing across multiple Maze instances
3. **GPU Pool Management**: Dynamic GPU allocation for burst traffic
4. **Advanced Metrics**: Request tracing, dependency analysis
5. **Cost Optimization**: Token usage tracking and optimization

**Dependencies**: Phase 8d (Deployment) + Phase 9 (if applicable)

### Phase 11: Ecosystem & Integrations (Q3 2026)

**Potential Scope:**
1. **GitHub Actions Integration**: Pre-built workflows for code generation
2. **VS Code Marketplace**: Published extension
3. **Constraint Marketplace**: Community-contributed constraint libraries
4. **Language Packs**: Rust, Go, Zig extraction support
5. **Cloud Integrations**: AWS Lambda, Google Cloud Functions support

**Dependencies**: Phase 8c (Examples) + Phase 9

---

## Appendices

### Appendix A: File Structure

```
ananke/
├── test/
│   ├── e2e/                           # NEW - Phase 8a
│   │   ├── test_typescript_pipeline.zig
│   │   ├── test_python_pipeline.zig
│   │   ├── test_constraint_satisfaction.zig
│   │   ├── test_multi_constraint.zig
│   │   ├── test_error_recovery.zig
│   │   ├── fixtures/
│   │   │   ├── typescript/
│   │   │   ├── python/
│   │   │   └── expected_outputs/
│   │   └── helpers/
│   │       ├── pipeline_runner.zig
│   │       └── constraint_validator.zig
│   └── ... (existing test directories)
├── bench/                             # NEW - Phase 8b
│   ├── extraction_benchmarks.zig
│   ├── compilation_benchmarks.zig
│   ├── generation_benchmarks.zig
│   ├── e2e_benchmarks.zig
│   ├── cache_benchmarks.zig
│   ├── fixtures/
│   │   ├── small/
│   │   ├── medium/
│   │   └── large/
│   └── results/
│       ├── baseline_v0.1.0.json
│       └── benchmark_history.csv
├── examples/production/               # NEW - Phase 8c
│   ├── 01-openapi-route-generation/
│   │   ├── README.md
│   │   ├── input/
│   │   ├── constraints/
│   │   ├── output/
│   │   ├── tests/
│   │   └── run.sh
│   ├── 02-database-migration-generator/
│   ├── 03-react-component-generator/
│   ├── 04-cli-tool-generator/
│   └── 05-test-generator/
├── deployment/                        # NEW - Phase 8d
│   ├── docker/
│   │   ├── Dockerfile.ananke-core
│   │   ├── Dockerfile.ananke-python
│   │   └── docker-compose.yml
│   ├── kubernetes/
│   │   ├── ananke-deployment.yaml
│   │   ├── ananke-secrets.yaml
│   │   └── ananke-service.yaml
│   ├── ci-cd/
│   │   ├── github-actions.yml
│   │   └── gitlab-ci.yml
│   └── monitoring/
│       ├── prometheus.yml
│       ├── grafana-dashboards/
│       └── otel-collector-config.yaml
├── maze/
│   └── src/
│       ├── metrics.rs                 # NEW - Phase 8d
│       ├── tracing.rs                 # NEW - Phase 8d
│       └── logging.rs                 # NEW - Phase 8d
└── docs/
    ├── specs/
    │   └── phase8-e2e-integration.md  # This document
    └── DEPLOYMENT_GUIDE.md            # NEW - Phase 8d
```

### Appendix B: Metrics Reference

| Metric Name | Type | Labels | Description |
|-------------|------|--------|-------------|
| `ananke_requests_total` | Counter | `operation`, `status` | Total requests |
| `ananke_request_duration_seconds` | Histogram | `operation` | Request latency |
| `ananke_cache_hits_total` | Counter | `cache_type` | Cache hits |
| `ananke_cache_misses_total` | Counter | `cache_type` | Cache misses |
| `ananke_generation_tokens` | Histogram | `model` | Tokens generated |
| `ananke_constraint_violations_total` | Counter | `constraint_type` | Constraint violations |
| `ananke_extraction_latency_seconds` | Histogram | `language` | Extraction time |
| `ananke_compilation_latency_seconds` | Histogram | `constraint_count` | Compilation time |

### Appendix C: Example Checklist

For each production example:

**Setup:**
- [ ] README with clear overview
- [ ] Prerequisites clearly stated
- [ ] Setup time ≤ 10 minutes
- [ ] One-command execution (`./run.sh`)

**Content:**
- [ ] Realistic input fixtures
- [ ] Constraint files
- [ ] Expected output
- [ ] Validation tests
- [ ] Documentation of all steps

**Quality:**
- [ ] Tests pass in CI
- [ ] Generated code compiles/runs
- [ ] Constraints are satisfied
- [ ] Example demonstrates clear value

### Appendix D: CI/CD Checklist

**GitHub Actions:**
- [ ] Test job (unit, integration, E2E)
- [ ] Benchmark job (performance tests)
- [ ] Build job (Docker images)
- [ ] Deploy staging job
- [ ] Deploy production job (manual)
- [ ] Smoke tests after deployment

**GitLab CI:**
- [ ] test:unit stage
- [ ] test:e2e stage
- [ ] test:bench stage
- [ ] build:core stage
- [ ] build:python stage
- [ ] deploy:staging stage
- [ ] deploy:production stage (manual)

### Appendix E: Glossary

- **E2E Test**: End-to-end test validating full pipeline (extract → compile → generate)
- **Benchmark**: Performance test measuring latency, throughput, or resource usage
- **Production Example**: Complete, documented example demonstrating real-world use case
- **Deployment Manifest**: Kubernetes YAML or Docker Compose configuration
- **Observability**: Metrics, logs, and traces for understanding system behavior
- **HPA**: Horizontal Pod Autoscaler (Kubernetes)
- **Prometheus**: Open-source monitoring and alerting toolkit
- **OpenTelemetry**: Observability framework for distributed tracing
- **Grafana**: Visualization and analytics platform

### Appendix F: References

**Internal Documentation:**
- [Phase 7 Specification](/Users/rand/src/ananke/docs/specs/phase7-maze-orchestration.md)
- [Architecture Guide](/Users/rand/src/ananke/docs/ARCHITECTURE.md)
- [CLI Guide](/Users/rand/src/ananke/docs/CLI_GUIDE.md)
- [Python API Reference](/Users/rand/src/ananke/docs/PYTHON_API.md)

**External Resources:**
- [Prometheus Documentation](https://prometheus.io/docs/)
- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Docker Documentation](https://docs.docker.com/)

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-11-27 | spec-author | Initial specification |

---

**END OF SPECIFICATION**
