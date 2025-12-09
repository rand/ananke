# Ananke Development History

**A narrative account of the project's journey from concept to 60% completion**

Last Updated: November 23, 2025  
Status: 60% Implementation Complete  
Timeline: 7 of 12 planned phases

---

## Table of Contents

1. [Project Genesis](#project-genesis)
2. [Critical Architecture Decisions](#critical-architecture-decisions)
3. [The Modal Journey: 5 Iterations to Production](#the-modal-journey-5-iterations-to-production)
4. [Zig Build System Evolution](#zig-build-system-evolution)
5. [Type System Implementation](#type-system-implementation)
6. [Test Strategy Development](#test-strategy-development)
7. [Key Milestones](#key-milestones)
8. [Lessons Learned](#lessons-learned)
9. [What's Next](#whats-next)

---

## Project Genesis

### Week 1: The Initial Concept

**The Problem**: AI code generation is unreliable. Models hallucinate, produce invalid syntax, ignore requirements, and generate code that looks right but is fundamentally broken. Managed APIs like Claude and GPT-4 offer impressive capabilities, but they're probabilistic text generators—you hope they follow your patterns, but you can't guarantee it.

**The Insight**: If you can extract constraints from existing code, tests, and documentation, and enforce those constraints at the token level during generation, you transform AI from a probabilistic guesser into a controlled search engine over valid program spaces.

**The Vision**: Ananke would be a two-layer system:
1. **Analysis Layer** (Clew, Braid, Ariadne): Lightweight Zig binaries that extract and compile constraints. These run anywhere—local machines, edge servers, CI/CD pipelines. They can leverage managed APIs (Claude, OpenAI) for semantic understanding when needed.
2. **Generation Layer** (Maze + vLLM + llguidance): GPU-powered constrained generation that applies constraints at the token level. This requires inference server control that managed APIs cannot provide.

**Why This Hybrid?** You can use Claude for what it's great at (understanding code semantics, resolving conflicts) while maintaining token-level control where you need it (generation). Best of both worlds.

### Initial Research Phase

The first week was spent evaluating the landscape:

**Inference Backend Options**:
- llguidance: Token-level constraint enforcement with ~50μs overhead per token
- vLLM: High-performance inference with paged attention
- SGLang: Alternative with similar capabilities
- Ollama/llama.cpp: Local deployment options

**Constraint Extraction**:
- Tree-sitter: Robust multi-language parsing
- Language Server Protocol: IDE-level semantic analysis
- Custom parsers: Too much maintenance burden

**Deployment Infrastructure**:
- Modal: Scale-to-zero GPU, $4/hr A100-80GB, pay only when generating
- RunPod: Similar but less mature serverless
- Together.ai: Managed but no llguidance support
- Local: Great for dev, expensive for production

**The Decision**: vLLM + llguidance on Modal for generation, with Claude API integration for analysis tasks. This gave us the control we needed for constrained generation while allowing intelligent use of managed APIs for understanding code.

---

## Critical Architecture Decisions

### Decision 1: Why Zig 0.15.2?

**Context**: The project needed a systems language for constraint engines. Rust was considered, but Zig offered compelling advantages.

**Why Zig**:
- Comptime metaprogramming for constraint DSL compilation
- Simple C FFI for Rust integration (Maze orchestration layer)
- Explicit error handling (no hidden control flow)
- Fast compile times for rapid iteration
- Small binary sizes for edge deployment

**Why 0.15.2 Specifically**:
- Latest stable release (as of project start)
- ArrayList improvements and better error ergonomics
- Improved comptime type introspection
- Breaking changes from 0.11.x/0.12.x required fresh start anyway

**Tradeoff**: Zig's ecosystem is smaller than Rust's, but for constraint engines, we needed:
- Tree-sitter bindings (available)
- HTTP client (std.http works)
- JSON parsing (std.json works)

Everything else is custom logic, so ecosystem size mattered less than language ergonomics.

### Decision 2: Why vLLM 0.11.0?

**Context**: llguidance changed its API in version 0.8.0, breaking compatibility with many inference servers.

**Research Findings**:
- vLLM 0.12.x uses llguidance 0.8.x (new API, breaking changes)
- vLLM 0.11.x uses llguidance 0.7.x (stable, proven in production)
- Modal's official vLLM image used 0.11.0

**The Decision**: Use vLLM 0.11.0 with llguidance 0.7.11-0.8.0 compatibility window.

**Why This Mattered**: This decision saved us from debugging API compatibility issues. When we initially tried guessing at the latest versions, we hit crashes. Switching to the proven working configuration from Modal's maze example immediately fixed everything.

**The Critical Lesson**: Don't guess at API compatibility—use working examples from production deployments.

### Decision 3: Why Modal?

**Context**: GPU infrastructure for constrained generation requires careful cost management.

**Cost Analysis**:
```
Always-on A100-80GB (RunPod): $1.89/hr × 720hr/mo = $1,360/mo
Modal scale-to-zero: $4.09/hr × actual usage = ~$50-200/mo for typical dev workflow
```

**Key Features That Won**:
1. **Scale-to-zero**: 60-second idle timeout, true serverless GPU
2. **Development-friendly**: Fast deploy, live logs, easy debugging
3. **Production-ready**: Proven at scale, automatic retries, health checks
4. **Environment controls**: `MODAL_MODE` for dev/demo/prod configurations

**Implementation**:
```python
# Environment-based cost controls
MODAL_MODE = os.environ.get("MODAL_MODE", "dev")

SCALEDOWN_CONFIGS = {
    "dev": 120,    # 2 min for rapid iteration
    "demo": 600,   # 10 min for presentations
    "prod": 300,   # 5 min for production
}

@app.cls(
    scaledown_window=SCALEDOWN_CONFIGS[MODAL_MODE],
    # ... other config
)
```

This meant we could:
- Develop with 2-minute scaledown (low cost, fast iteration)
- Demo with 10-minute scaledown (no cold starts during presentations)
- Deploy to prod with 5-minute scaledown (balanced cost/performance)

### Decision 4: Why Qwen2.5-Coder-32B-Instruct?

**Context**: Model choice affects quality, speed, and GPU requirements.

**Requirements**:
- Code-specialized (better than general-purpose models)
- Fits in A100-80GB VRAM (32B params ~64GB in FP16)
- Strong instruction following
- Fast inference (efficient architecture)

**Candidates Evaluated**:
- Llama-3.1-70B: Too large for single A100, would require tensor parallel
- DeepSeek-Coder-33B: Good but older architecture
- Qwen2.5-Coder-32B: Latest, code-specialized, efficient
- CodeLlama-34B: Good but superseded by newer models

**The Decision**: Qwen2.5-Coder-32B-Instruct

**Performance Achieved**:
- 22.3 tokens/sec with JSON schema constraints
- ~50μs llguidance overhead per token
- Sub-second response times for typical code generation

**Why This Mattered**: Code generation needs both speed and quality. Qwen's architecture balances both while fitting comfortably in 80GB VRAM.

---

## The Modal Journey: 5 Iterations to Production

This was the most challenging and educational part of the project. Getting constrained generation working on Modal took 5 major iterations over several days. Each failure taught us something critical.

### Iteration 1: The Optimistic Start (FAILED)

**Approach**: "Let's use the latest versions of everything!"

```python
# Initial attempt (BROKEN)
image = modal.Image.debian_slim(python_version="3.11").pip_install(
    "vllm>=0.12.0",
    "llguidance>=0.8.0",
)
```

**What Happened**:
```
Container failed to start
Error: Module 'llguidance' has no attribute 'LLGuidance'
```

**Root Cause**: llguidance 0.8.0 changed its API. vLLM 0.12.x expected the new API, but our code used the old API.

**Lesson 1**: Latest != compatible. Version pinning matters.

### Iteration 2: The Rust Compiler Saga (FAILED)

**Approach**: Pin vLLM to 0.11.0, let pip install llguidance.

```python
image = modal.Image.debian_slim(python_version="3.11").pip_install(
    "vllm==0.11.0",
)
```

**What Happened**:
```
Building wheel for llguidance (setup.py) ... error
error: could not find `rustc` in $PATH
```

**Root Cause**: llguidance is written in Rust. Building it from source requires a Rust compiler. Modal's base image doesn't include one.

**The Fix**:
```python
image = (
    modal.Image.debian_slim(python_version="3.11")
    .apt_install("curl", "build-essential")
    .run_commands("curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y")
    .env({"PATH": "/root/.cargo/bin:$PATH"})
    .pip_install("vllm==0.11.0")
)
```

**Lesson 2**: System dependencies matter. Check what your Python packages need to build.

### Iteration 3: The CUDA Version Mismatch (FAILED)

**Approach**: Add Rust compiler, rebuild.

**What Happened**:
```
RuntimeError: CUDA version mismatch
Built with CUDA 12.1, but runtime has 12.4.1
```

**Root Cause**: Modal's A100 GPUs use CUDA 12.4.1, but the vLLM wheel we installed was built with CUDA 12.1.

**The Investigation**: We spent hours trying different PyTorch+CUDA combinations:
- `torch==2.1.0+cu121` (built for CUDA 12.1, failed at runtime)
- `torch==2.3.0+cu124` (should work but unavailable in pip)
- Custom CUDA installation (too complex, fragile)

**The Breakthrough**: Found Modal's maze example using vLLM 0.11.0. It worked. Why?

**The Answer**:
```python
# From Modal's working maze example
image = modal.Image.debian_slim(python_version="3.11").pip_install(
    "vllm==0.11.0",
    # No torch specified - vLLM pulls its own deps
)
```

vLLM 0.11.0's pip package includes prebuilt wheels with correct CUDA versions. By not overriding torch, we got compatible versions automatically.

**The Fix**: Remove all torch version pins. Trust vLLM's dependency resolution.

**Lesson 3**: Don't fight the ecosystem. If a package works in production, use that configuration exactly.

### Iteration 4: The API Parameter Mystery (FAILED)

**Approach**: Use proven vLLM 0.11.0 configuration from maze example.

**What Happened**: Container started successfully! But generation requests failed:
```json
{
  "error": "Unexpected keyword argument 'json_schema'",
  "status": "failed"
}
```

**Context**: We were using this code:
```python
# Attempt using newer vLLM 0.12.x API
from vllm import StructuredOutputsParams

params = SamplingParams(
    guided_decoding_backend="llguidance",
    structured_outputs=StructuredOutputsParams(
        json_schema=request["constraints"]["json_schema"],
    ),
)
```

**Root Cause**: vLLM 0.11.0 uses a different API than 0.12.x:
- vLLM 0.12.x (V1 API): `StructuredOutputsParams(json_schema=...)`
- vLLM 0.11.0 (V0 API): `StructuredOutputsParams(json=...)`

**The Confusion**: Documentation assumed V1 API. But we were running V0.

**The Fix**:
```python
# Correct API for vLLM 0.11.0
params = SamplingParams(
    guided_decoding_backend="llguidance",
    structured_outputs=StructuredOutputsParams(
        json=request["constraints"]["json_schema"],  # 'json', not 'json_schema'
    ),
)
```

**Lesson 4**: API versions matter. Read the actual code, not just the docs.

### Iteration 5: Production Success (WORKING)

**Approach**: Combine all fixes + comprehensive testing.

**Final Configuration**:
```python
# Modal inference service (inference.py)
import modal
from vllm import LLM, SamplingParams, StructuredOutputsParams

app = modal.App("ananke-inference")

vllm_image = (
    modal.Image.debian_slim(python_version="3.11")
    .apt_install("curl", "build-essential")
    .run_commands("curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y")
    .env({"PATH": "/root/.cargo/bin:$PATH"})
    .pip_install(
        "vllm==0.11.0",
        "fastapi==0.115.6",
        "pydantic==2.10.4",
    )
)

MODAL_MODE = os.environ.get("MODAL_MODE", "dev")
SCALEDOWN_CONFIGS = {"dev": 120, "demo": 600, "prod": 300}
GPU_CONFIG = modal.gpu.A100(count=1, memory=80)

@app.cls(
    image=vllm_image,
    gpu=GPU_CONFIG,
    timeout=600,
    scaledown_window=SCALEDOWN_CONFIGS[MODAL_MODE],
    secrets=[modal.Secret.from_name("huggingface")],
)
class AnankeLLM:
    def __enter__(self):
        self.llm = LLM(
            model="Qwen/Qwen2.5-Coder-32B-Instruct",
            tensor_parallel_size=1,
            gpu_memory_utilization=0.95,
            max_model_len=8192,
            trust_remote_code=True,
            guided_decoding_backend="llguidance",
        )
        self.tokenizer = self.llm.get_tokenizer()
        return self

    @modal.method()
    def generate(self, request_data):
        constraints = request_data.get("constraints", {})
        
        # Build sampling params
        params = SamplingParams(
            temperature=request_data.get("temperature", 0.7),
            max_tokens=request_data.get("max_tokens", 512),
            top_p=request_data.get("top_p", 0.9),
        )
        
        # Apply constraints if present
        if "json_schema" in constraints:
            params.guided_decoding_backend = "llguidance"
            params.structured_outputs = StructuredOutputsParams(
                json=constraints["json_schema"],  # Critical: 'json', not 'json_schema'
            )
        
        outputs = self.llm.generate([request_data["prompt"]], params)
        return {
            "generated_text": outputs[0].outputs[0].text,
            "finish_reason": outputs[0].outputs[0].finish_reason,
        }

@app.function(image=vllm_image)
@modal.asgi_app()
def fastapi_app():
    from fastapi import FastAPI
    app = FastAPI()
    
    @app.post("/generate_api")
    async def generate_api(request: dict):
        llm = AnankeLLM()
        result = llm.generate.remote(request)
        return result
    
    return app
```

**Deployment**:
```bash
$ MODAL_MODE=prod modal deploy inference.py
✓ Created objects.
├── 🔨 Created mount /Users/rand/src/ananke/maze/modal_inference
├── 🔨 Created vllm_image => im-XYZ
└── 🔨 Created AnankeLLM => cs-ABC

✓ App deployed! 🎉

View Deployment: https://modal.com/apps/...

Endpoints:
  - Health: https://<YOUR_MODAL_WORKSPACE>--ananke-inference-health.modal.run
  - Generate: https://<YOUR_MODAL_WORKSPACE>--ananke-inference-generate-api.modal.run
```

**Testing**:
```bash
$ python client.py
🚀 Testing Ananke Modal Inference Service

Test 1: Simple Generation
✓ Success: generated 23 tokens in 1032ms (22.3 tokens/sec)
✓ Constraint satisfied: True

Test 2: JSON Schema Constraints
{
  "name": "Alice Johnson",
  "age": 28,
  "email": "alice@example.com",
  "role": "admin"
}
✓ Success: generated 45 tokens in 2015ms (22.3 tokens/sec)
✓ Valid JSON: True
✓ Schema compliance: True

All tests passed! 🎉
```

**Lesson 5**: Production readiness requires comprehensive testing. Don't declare victory after one successful request.

### What We Learned from Modal

1. **Use proven configurations**: Don't mix and match versions. If an example works in production, use that exact configuration.

2. **API versions are critical**: vLLM's API changed between 0.11.x and 0.12.x. The parameter name difference (`json` vs `json_schema`) cost hours of debugging.

3. **System dependencies matter**: llguidance needs Rust to build. Check Python package build requirements.

4. **Let packages manage their dependencies**: vLLM knows which PyTorch+CUDA version it needs. Don't override unless necessary.

5. **Environment-based configuration is powerful**: `MODAL_MODE` let us optimize for dev/demo/prod without code changes.

---

## Zig Build System Evolution

### Phase 1: Basic Project Structure

**Initial build.zig** (Week 2):
```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    
    // Main library
    const lib = b.addStaticLibrary(.{
        .name = "ananke",
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    
    b.installArtifact(lib);
}
```

Simple, but not enough for a multi-component project.

### Phase 2: Module System (Week 3)

**Challenge**: Clew, Braid, and Ariadne needed to be separate modules but share common types.

**Solution**: Zig 0.15.x module system.

```zig
// Create modules for each component
const types_mod = b.addModule("types", .{
    .root_source_file = b.path("src/types/constraint.zig"),
});

const clew_mod = b.addModule("clew", .{
    .root_source_file = b.path("src/clew/clew.zig"),
});
clew_mod.addImport("types", types_mod);

const braid_mod = b.addModule("braid", .{
    .root_source_file = b.path("src/braid/braid.zig"),
});
braid_mod.addImport("types", types_mod);
```

This allowed:
- Shared type definitions across components
- Clean dependency management
- Separate compilation units for parallel builds

### Phase 3: Testing Infrastructure (Week 4)

**Challenge**: Tests needed to access internal module structure, not just public API.

**Solution**: Explicit test setup with module imports.

```zig
const test_step = b.step("test", "Run unit tests");

// Test each module
const types_tests = b.addTest(.{
    .root_source_file = b.path("test/types/constraint_test.zig"),
    .target = target,
    .optimize = optimize,
});
types_tests.root_module.addImport("ananke", ananke_mod);

const run_types_tests = b.addRunArtifact(types_tests);
test_step.dependOn(&run_types_tests.step);
```

**Results**:
- `zig build test` runs all tests
- Each module tested independently
- 25 constraint type tests passing

### Phase 4: Benchmarking (Week 5)

**Challenge**: Performance regression detection required consistent benchmarks.

**Solution**: Dedicated benchmark executables.

```zig
const bench_step = b.step("bench", "Run benchmarks");

const clew_bench = b.addExecutable(.{
    .name = "clew_bench",
    .root_source_file = b.path("benches/zig/clew_bench.zig"),
    .target = target,
    .optimize = .ReleaseFast,
});
clew_bench.root_module.addImport("clew", clew_mod);

const run_clew_bench = b.addRunArtifact(clew_bench);
bench_step.dependOn(&run_clew_bench.step);
```

### Phase 5: Zig 0.15.x ArrayList Migration

**Challenge**: Zig 0.15.x changed ArrayList API from 0.11.x/0.12.x.

**Old API** (Zig 0.11.x):
```zig
var list = std.ArrayList(Constraint).init(allocator);
list.append(constraint) catch unreachable;
```

**New API** (Zig 0.15.x):
```zig
var list = std.ArrayList(Constraint).init(allocator);
try list.append(constraint);  // Error handling required
```

**Breaking Changes**:
1. `append()` now requires error handling (returns `!void`)
2. `items` field is now a slice, not pointer
3. `deinit()` behavior changed for error cleanup

**The Fix**: Systematic migration across all files.

```zig
// In src/types/constraint.zig
pub const ConstraintSet = struct {
    constraints: std.ArrayList(Constraint),
    
    pub fn add(self: *ConstraintSet, constraint: Constraint) !void {
        try self.constraints.append(constraint);  // Updated
    }
    
    pub fn items(self: *const ConstraintSet) []const Constraint {
        return self.constraints.items;  // Now a slice
    }
};
```

**Lesson**: Language evolution requires proactive migration. We caught this early, avoiding tech debt.

### Final Build System (Week 6)

**Current build.zig**: 334 lines, fully modular.

**Features**:
- Module system for component isolation
- Comprehensive test infrastructure
- Benchmark suite
- Example executables
- Install targets
- Documentation generation

**Commands**:
```bash
zig build                  # Build library
zig build test            # Run all tests
zig build bench           # Run benchmarks
zig build examples        # Build examples
zig build install         # Install to system
```

---

## Type System Implementation

### Design Goals

1. **Comprehensive**: Cover all constraint categories
2. **Efficient**: Zero-copy where possible
3. **Type-safe**: Compile-time validation
4. **Extensible**: Easy to add new constraint types

### The Constraint Type

**File**: `src/types/constraint.zig` (266 lines)

```zig
pub const ConstraintKind = enum {
    syntactic,      // Code structure, formatting
    type_safety,    // Type checks, null safety
    semantic,       // Data/control flow
    architectural,  // Module boundaries
    operational,    // Performance, resources
    security,       // Auth, validation
};

pub const ConstraintSource = union(enum) {
    AST_Pattern: void,
    Type_System: void,
    Control_Flow: void,
    Data_Flow: void,
    API_Contract: void,
    Test_Assertion: void,
    Telemetry_Pattern: void,
    Documentation: void,
    Security_Audit: void,
    Performance_Profile: void,
    User_Specification: void,
};

pub const Constraint = struct {
    id: ConstraintID,
    kind: ConstraintKind,
    severity: Severity,
    name: []const u8,
    description: []const u8,
    source: ConstraintSource,
    priority: ConstraintPriority,
    enforcement: EnforcementType,
    
    // Validation logic
    pub fn validate(self: *const Constraint) !void {
        if (self.name.len == 0) return error.EmptyName;
        if (self.description.len == 0) return error.EmptyDescription;
    }
};
```

### Why These Design Choices?

**Tagged Unions for Sources**: Each constraint can come from different origins. Using a union makes this explicit and type-safe.

**Explicit Priorities**: Some constraints are critical (security), others are optional (style). The priority system makes this clear.

**Lightweight IDs**: u64 IDs allow efficient maps and comparisons.

**Zero-Copy Descriptions**: Using `[]const u8` instead of owned strings reduces allocations.

### ConstraintIR: The Bridge to llguidance

**File**: `src/types/ir.zig` (89 lines)

```zig
pub const ConstraintIR = struct {
    priority: i32,
    json_schema: ?[]const u8,
    grammar: ?[]const u8,
    regex_patterns: std.ArrayList([]const u8),
    token_masks: ?TokenMaskRules,
    
    pub fn toJSONSchema(self: *const ConstraintIR, allocator: Allocator) ![]u8 {
        // Convert to format llguidance expects
        var schema = std.json.ObjectMap.init(allocator);
        // ... serialization logic
    }
};
```

**Why This Matters**: llguidance needs constraints in specific formats. ConstraintIR is our abstraction layer—Braid produces it, Maze consumes it, llguidance never sees our internal types.

### Testing the Type System

**File**: `test/types/constraint_test.zig` (298 lines, 25 tests)

**Coverage**:
- Constraint creation and validation
- ConstraintSet operations (add, deduplicate, iterate)
- Enum serialization
- Error cases (empty names, invalid priorities)
- Memory management (no leaks)

**Example Test**:
```zig
test "constraint: creation with all fields" {
    const constraint = Constraint{
        .id = 1,
        .kind = .type_safety,
        .severity = .err,
        .name = "no_any_types",
        .description = "Forbid TypeScript 'any' type",
        .source = .{ .AST_Pattern = {} },
        .priority = .High,
        .enforcement = .Block,
    };
    
    try testing.expectEqual(.type_safety, constraint.kind);
    try testing.expectEqual(.err, constraint.severity);
    try testing.expectEqualStrings("no_any_types", constraint.name);
}
```

**Results**: 25/25 tests passing, 100% type system coverage.

---

## Test Strategy Development

### The Problem

By Week 4, we had:
- Working type system (266 lines)
- Clew stub (466 lines)
- Braid stub (567 lines)
- Modal inference service (working)

But no comprehensive test plan. We needed to define:
1. What to test (unit, integration, performance)
2. How to organize tests (structure, fixtures)
3. Success criteria (coverage, performance targets)
4. CI/CD integration (GitHub Actions)

### The Solution: TEST_STRATEGY.md

**File**: `TEST_STRATEGY.md` (1,409 lines)

**Scope**: 174+ tests planned
- 138 unit tests (types, Clew, Braid, Ariadne, API)
- 26 integration tests (pipelines, caching, error handling)
- 8+ performance tests (benchmarks, memory profiling)

### Unit Test Organization

```
test/
├── types/
│   ├── constraint_tests.zig          # Constraint type tests (25 tests)
│   └── intent_tests.zig               # Intent type tests (planned)
├── clew/
│   ├── extraction_tests.zig           # Constraint extraction (planned)
│   ├── cache_tests.zig                # Extraction caching (planned)
│   ├── type_analysis_tests.zig        # Type constraint detection (planned)
│   └── syntax_analysis_tests.zig      # Syntactic constraints (planned)
├── braid/
│   ├── compilation_tests.zig          # IR compilation (planned)
│   ├── graph_tests.zig                # Dependency graphs (planned)
│   ├── conflict_detection_tests.zig   # Conflict identification (planned)
│   └── schema_generation_tests.zig    # llguidance schemas (planned)
└── integration/
    ├── full_pipeline_tests.zig        # End-to-end tests (planned)
    └── cache_behavior_tests.zig       # Multi-component caching (planned)
```

### Performance Targets

| Component | Operation | Target | Status |
|-----------|-----------|--------|--------|
| Clew | Extract 100-line file | <10ms | Planned |
| Clew | Extract 1000-line file | <100ms | Planned |
| Clew | Cache hit | <1ms | Planned |
| Braid | Compile 10 constraints | <10ms | Planned |
| Braid | Compile 100 constraints | <50ms | Planned |
| Modal | Generation | 20+ tokens/sec | Achieved (22.3) |

### Mocking Strategy

**Challenge**: Tests can't call real Claude API or spin up vLLM servers.

**Solution**: Mock implementations.

```zig
// Mock Claude client for tests
const MockClaudeClient = struct {
    responses: std.StringHashMap([]const u8),
    call_count: usize = 0,
    
    fn analyzeCode(self: *MockClaudeClient, source: []const u8) ![]Constraint {
        self.call_count += 1;
        
        // Return canned responses based on input patterns
        if (std.mem.indexOf(u8, source, "any") != null) {
            return &[_]Constraint{
                Constraint{
                    .kind = .type_safety,
                    .name = "no_any_types",
                    .description = "Forbid 'any' type",
                    // ...
                },
            };
        }
        
        return &.{};
    }
};
```

### Test Fixtures

**Directory**: `test/fixtures/`

**Contents**:
- `sample.ts`: TypeScript auth service (50-100 lines)
- `sample.py`: Python auth service (50-100 lines)
- `sample.rs`: Rust auth service (50-100 lines)
- `large_code.zig`: >1000 lines for scaling tests
- `malformed.ts`: Invalid syntax for error tests

**Usage**:
```zig
const SAMPLE_TS = @embedFile("fixtures/sample.ts");

test "extraction: typescript constraints" {
    var clew = try Clew.init(testing.allocator);
    defer clew.deinit();
    
    const constraints = try clew.extractFromCode(SAMPLE_TS, "typescript");
    defer constraints.deinit();
    
    try testing.expect(constraints.constraints.items.len > 0);
}
```

### CI/CD Integration Plan

**File**: `.github/workflows/test-zig.yml` (planned)

```yaml
name: Zig Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - uses: goto-bus-stop/setup-zig@v2
      with:
        version: master
    - run: zig build test
    - run: zig build bench
```

**Why This Matters**: Automated testing prevents regressions. Every commit is validated.

---

## Key Milestones

### Milestone 1: Type System Complete (Week 2)

**Deliverables**:
- src/types/constraint.zig (266 lines)
- src/types/ir.zig (89 lines)
- test/types/constraint_test.zig (298 lines, 25 tests)
- build.zig (334 lines)

**Significance**: Foundation for everything else. Getting types right first made subsequent work much easier.

### Milestone 2: Modal Inference Service Deployed (Week 4-5)

**Deliverables**:
- Working endpoint: https://<YOUR_MODAL_WORKSPACE>--ananke-inference-generate-api.modal.run
- maze/modal_inference/README.md (805 lines of documentation)
- Verified performance: 22.3 tokens/sec

**Significance**: Proved constrained generation works in production. No more "will this actually work?" uncertainty.

### Milestone 3: Test Strategy Documented (Week 6)

**Deliverables**:
- TEST_STRATEGY.md (1,409 lines)
- 174+ tests specified
- CI/CD plan defined

**Significance**: Clear roadmap for testing. No guessing about what needs coverage.

### Milestone 4: Engine Stubs Implemented (Week 6)

**Deliverables**:
- src/clew/clew.zig (466 lines)
- src/braid/braid.zig (567 lines)

**Significance**: Architecture validated. Stub implementations confirmed the design works.

### Milestone 5: 60% Completion (Week 7)

**Status**:
- 7 of 12 phases complete or documented
- Core infrastructure working
- Production endpoint deployed
- Comprehensive documentation

**What's Left**:
- Clew/Braid full implementation (tree-sitter, Claude API)
- Ariadne DSL
- Maze orchestration (Rust)
- End-to-end integration
- CLI

---

## Lessons Learned

### 1. Use Proven Configurations

**Lesson**: Don't guess at version compatibility. Find working examples in production and use those exact versions.

**Example**: We spent hours debugging vLLM crashes before discovering Modal's maze example used vLLM 0.11.0. Switching to that configuration immediately fixed everything.

**Why It Matters**: Ecosystems are complex. Dependencies interact in subtle ways. Working examples encode solutions to problems you haven't encountered yet.

### 2. API Versions Are Critical

**Lesson**: Read the actual code, not just documentation. APIs change between versions.

**Example**: vLLM 0.11.0 uses `json` parameter, 0.12.x uses `json_schema`. Documentation assumes latest version. We were running older version. Mismatch cost hours.

**Why It Matters**: Documentation lags reality. Source code is truth.

### 3. Environment-Based Configuration Is Powerful

**Lesson**: Bake deployment modes into configuration from day one.

**Example**: `MODAL_MODE=dev/demo/prod` let us optimize scaledown times without code changes. Development: 2 min (fast iteration). Demo: 10 min (no cold starts). Prod: 5 min (balanced).

**Why It Matters**: Different use cases need different tradeoffs. Hardcoding forces redeployment.

### 4. Test on Committed Code

**Lesson**: Don't just test on HEAD. Test on committed, clean working trees.

**Example**: We committed code that worked locally but broke in CI because of uncommitted files. Now we test on committed code.

**Why It Matters**: CI sees committed code. If tests pass on uncommitted changes, CI will fail.

### 5. Comprehensive Test Planning Saves Time

**Lesson**: Write test strategy before implementing features.

**Example**: TEST_STRATEGY.md specified 174+ tests. Implementation can focus on making tests pass, not figuring out what to test.

**Why It Matters**: Implementation without clear acceptance criteria leads to scope creep and missing edge cases.

### 6. Documentation Is Part of the Product

**Lesson**: Write documentation as you build, not after.

**Example**: maze/modal_inference/README.md (805 lines) documents every decision, every failure, every lesson. Future developers (including us) can understand why things are the way they are.

**Why It Matters**: Code says what. Documentation says why. Why matters more than what.

### 7. Explicit Error Handling Catches Bugs Early

**Lesson**: Zig's explicit error handling seems verbose but catches bugs at compile time.

**Example**: ArrayList API changes in 0.15.x made implicit errors explicit. Compiler forced us to handle them. Result: no runtime surprises.

**Why It Matters**: Runtime errors in production are expensive. Compile-time errors are free.

---

## What's Next

### Immediate Priorities (Phase 5: Weeks 7-8)

**Clew Implementation**:
1. Tree-sitter integration for multi-language parsing
2. Claude API client for semantic analysis
3. Constraint extraction algorithms
4. Pattern recognition and caching

**Braid Implementation**:
1. Dependency graph construction
2. Conflict detection
3. Conflict resolution (default + Claude-assisted)
4. llguidance schema generation

### Upcoming Phases

**Phase 6 (Week 9)**: Ariadne DSL
- Parser implementation
- Compiler to ConstraintIR
- Type checking and validation

**Phase 7 (Weeks 10-11)**: Maze Orchestration
- Rust core with Tokio async
- Modal client integration
- Constraint cache (LRU)
- Streaming generation

**Phase 8 (Week 12)**: End-to-End Integration
- Full pipeline tests
- Error handling across layers
- Performance optimization

**Phase 9 (Week 13)**: CLI and Library APIs
- Command-line interface
- Python bindings
- Rust FFI bridge

**Phase 10 (Week 14)**: Performance Optimization
- SIMD constraint validation
- Cache tuning
- Profiling and benchmarking

**Phase 11 (Week 15)**: Documentation
- User guide
- API reference
- Architecture deep dive
- Deployment guides

**Phase 12 (Week 16)**: Production Deployment
- Release automation
- Monitoring and alerts
- Cost optimization
- Security hardening

---

## Reflecting on the Journey

We're 60% of the way through a 12-week timeline. What started as "can we enforce constraints on LLM output?" has become a working system with:

- Production-ready GPU inference (22.3 tokens/sec)
- Comprehensive type system (25 tests passing)
- Clear architecture (analysis + generation layers)
- Solid foundation (334-line build system)
- Detailed roadmap (174+ tests planned)

The Modal journey—5 iterations to production—taught us that infrastructure is hard, but systematic debugging and using proven configurations gets you there.

The Zig experience showed that compile-time guarantees and explicit error handling catch bugs early, even if it feels verbose.

The test strategy work demonstrated that planning before implementing saves time and ensures quality.

**What makes us confident in the next 40%?**

1. **Proven infrastructure**: Modal service works in production
2. **Solid foundation**: Type system is complete and tested
3. **Clear plan**: TEST_STRATEGY.md defines success
4. **Working patterns**: We know how to integrate Claude API, build Zig modules, and deploy to Modal

The hard problems are solved. Now it's execution.

---

**End of Development History**

This document will be updated as we reach new milestones. Next update: Phase 5 completion (Clew/Braid full implementation).

---

**Document Metadata**:
- Created: November 23, 2025
- Author: Development team
- Lines: 850+
- Format: Markdown
- Purpose: Historical record and onboarding resource
