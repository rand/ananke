# Ananke Evaluation Suite Guide

This guide covers how to run, extend, and interpret the Ananke evaluation framework. The eval suite compares constrained code generation (using Ananke constraints) against unconstrained baseline generation.

## Prerequisites

### Required Tools

1. **Zig 0.15+** - For building the eval runner
   ```bash
   brew install zig  # macOS
   # or download from https://ziglang.org/download/
   ```

2. **Modal** - For GPU inference service
   ```bash
   pip install modal
   modal token set
   ```

3. **Language runtimes** (for test execution):
   - Node.js 20+ (TypeScript/JavaScript)
   - Python 3.11+
   - Rust/cargo
   - Go 1.21+
   - GCC/Clang (C/C++)
   - Java 17+

## Quick Start

```bash
# 1. Build the eval binary
zig build eval

# 2. Deploy inference service to Modal
modal deploy eval/modal/inference_service.py

# 3. Run eval on all 60 tasks
./zig-out/bin/ananke-eval run \
  --endpoint "https://<YOUR_MODAL_WORKSPACE>--ananke-eval-inference-inferenceservice-fastapi-app.modal.run" \
  --output "eval/results_$(date +%Y%m%d_%H%M%S)"

# 4. List available tasks
./zig-out/bin/ananke-eval list

# 5. Run specific tasks
./zig-out/bin/ananke-eval run \
  --endpoint "<ENDPOINT_URL>" \
  --tasks "algorithms_binary_search,rust_result_handling"
```

## Directory Structure

```
eval/
├── core/                    # Zig evaluation framework
│   ├── evaluator.zig       # Main orchestrator
│   ├── task_spec.zig       # Task definitions and types
│   ├── modal_client.zig    # Modal API client
│   ├── test_runner.zig     # Multi-language test execution
│   ├── quality_scorer.zig  # Code quality metrics
│   ├── baseline.zig        # Unconstrained generation
│   └── metrics/            # Statistical metrics
│       ├── pass_at_k.zig
│       ├── constraint_metrics.zig
│       └── statistical_tests.zig
├── modal/                   # Modal inference service
│   └── inference_service.py
├── runner.zig              # CLI runner
├── main.zig                # Entry point
├── tasks/
│   ├── definitions/        # 60 task JSON definitions
│   ├── constraints/        # 60 constraint JSON files
│   └── fixtures/           # Reference implementations + tests
│       ├── typescript/
│       ├── python/
│       ├── rust/
│       ├── go/
│       ├── zig/
│       ├── javascript/
│       ├── c/
│       ├── cpp/
│       └── java/
└── results*/               # Output directories
```

## Task Definition Format

Each task is a JSON file in `eval/tasks/definitions/`:

```json
{
  "id": "rust_result_handling",
  "title": "Result Error Handling",
  "description": "Implement robust error handling with Result<T, E>...",
  "category": "error_handling",
  "language": "rust",
  "difficulty": "medium",
  "requirements": [
    "Define custom error types using thiserror",
    "Implement From conversions",
    "Use ? operator for propagation"
  ],
  "reference_impl_path": "eval/tasks/fixtures/rust/result_handling.rs",
  "test_suite_path": "eval/tasks/fixtures/rust/result_handling_test.rs",
  "constraint_path": "eval/tasks/constraints/rust_result_handling.json",
  "few_shot_examples": [
    {
      "prompt": "Handle file read errors",
      "code": "fn read_file(path: &str) -> Result<String, io::Error> { ... }"
    }
  ],
  "expected_loc": 50
}
```

### Supported Categories

- `algorithms` - Sorting, searching, graph algorithms
- `api` - Request validation, middleware
- `async` - Rate limiting, concurrency patterns
- `caching` - Memoization, LRU caches
- `concurrency` - Thread pools, actors, workers
- `data_processing` - CSV/JSON parsing
- `data_structures` - Custom data structures
- `error_handling` - Error types, propagation
- `patterns` - Design patterns (Builder, Repository, DI)
- `type_system` - Type safety, generics
- `validation` - Input validation, schema validation

### Supported Languages

| Language | File Extension | Test Framework |
|----------|---------------|----------------|
| TypeScript | .ts | Jest/Vitest |
| JavaScript | .js | Jest/Vitest |
| Python | .py | pytest |
| Rust | .rs | cargo test |
| Go | .go | go test |
| Zig | .zig | zig test |
| C | .c | assert + make |
| C++ | .cpp | assert + make |
| Java | .java | JUnit |

## Constraint Definition Format

Each constraint file in `eval/tasks/constraints/`:

```json
{
  "task_id": "rust_result_handling",
  "language": "rust",
  "signature": {
    "type": "function_signature",
    "pattern": "pub fn parse_config(path: &str) -> Result<Config, ConfigError>"
  },
  "structural_requirements": [
    {
      "type": "must_use_pattern",
      "pattern": "thiserror::Error"
    },
    {
      "type": "must_implement",
      "trait": "From<io::Error>"
    }
  ],
  "llguidance": {
    "regex": "pub\\s+fn\\s+parse_config.*->\\s*Result<.*>",
    "json_schema": null
  }
}
```

## Adding a New Task

### 1. Create Task Definition

```bash
# Copy a similar task as template
cp eval/tasks/definitions/rust_result_handling.json \
   eval/tasks/definitions/rust_new_task.json
```

Edit the new file with:
- Unique `id`
- Clear `description`
- Specific `requirements`
- Appropriate `category` and `difficulty`

### 2. Create Reference Implementation

```rust
// eval/tasks/fixtures/rust/new_task.rs
pub fn my_function() -> Result<(), Error> {
    // Reference implementation
}
```

### 3. Create Test Suite

```rust
// eval/tasks/fixtures/rust/new_task_test.rs
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_basic() {
        assert!(my_function().is_ok());
    }
}
```

### 4. Create Constraint File

```json
// eval/tasks/constraints/rust_new_task.json
{
  "task_id": "rust_new_task",
  "language": "rust",
  "signature": {
    "type": "function_signature",
    "pattern": "pub fn my_function() -> Result<(), Error>"
  },
  "llguidance": {
    "regex": "pub\\s+fn\\s+my_function.*Result"
  }
}
```

### 5. Validate the Task

```bash
# Rebuild and list tasks
zig build eval
./zig-out/bin/ananke-eval list | grep new_task

# Run just your task
./zig-out/bin/ananke-eval run \
  --endpoint "<URL>" \
  --tasks "rust_new_task"
```

## Adding a New Language

### 1. Update `task_spec.zig`

Add to the `Language` enum:

```zig
pub const Language = enum {
    // ... existing languages
    swift,  // new

    pub fn fromString(s: []const u8) ?Language {
        // ... add mapping
        if (std.mem.eql(u8, s, "swift")) return .swift;
    }

    pub fn fileExtension(self: Language) []const u8 {
        // ... add extension
        .swift => ".swift",
    }

    pub fn testCommand(self: Language) []const u8 {
        // ... add test command
        .swift => "swift test",
    }
};
```

### 2. Update `test_runner.zig`

Add execution logic for the new language:

```zig
fn executeTests(self: *TestRunner, language: []const u8, ...) !TestResult {
    if (std.mem.eql(u8, language, "swift")) {
        // Swift-specific test execution
    }
}
```

### 3. Create Fixtures Directory

```bash
mkdir -p eval/tasks/fixtures/swift
```

### 4. Add Task Definitions

Create task JSON files with `"language": "swift"`.

## Inference Service Configuration

The Modal inference service (`eval/modal/inference_service.py`) uses:

- **Model**: Qwen2.5-Coder-32B-Instruct
- **Backend**: vLLM 0.11.0 + llguidance
- **GPU**: H100 80GB
- **Scaledown**: 60s (dev), 180s (prod), 300s (demo)

### Cost Control

```bash
# Dev mode (aggressive scaledown)
MODAL_MODE=dev modal deploy eval/modal/inference_service.py

# Production mode
MODAL_MODE=prod modal deploy eval/modal/inference_service.py

# Demo mode (keeps warm longer)
MODAL_MODE=demo modal deploy eval/modal/inference_service.py
```

### API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check |
| `/generate/constrained` | POST | Ananke-constrained generation |
| `/generate/unconstrained` | POST | Baseline few-shot generation |

### Request Format (Constrained)

```json
{
  "prompt": "Implement a function to...",
  "constraints": {
    "grammar": "pub fn process(data: &[u8]) -> Result<Vec<u8>, Error>",
    "llguidance": {
      "regex": "pub\\s+fn\\s+process.*"
    }
  }
}
```

### Request Format (Unconstrained)

```json
{
  "prompt": "Implement a function to...",
  "few_shot_examples": [
    {"prompt": "Example task", "code": "fn example() { ... }"}
  ]
}
```

## Understanding Results

Results are saved per-task as JSON:

```json
{
  "task_id": "rust_result_handling",
  "constrained": {
    "code": "pub fn parse_config...",
    "duration_ms": 4523,
    "success": true,
    "timing": {
      "constraint_compilation_ms": 12,
      "generation_ms": 4456,
      "test_execution_ms": 55
    }
  },
  "baseline": {
    "code": "pub fn parse_config...",
    "duration_ms": 4891,
    "success": true
  },
  "constrained_tests": {
    "passed_tests": 8,
    "failed_tests": 0,
    "total_tests": 8
  },
  "baseline_tests": {
    "passed_tests": 6,
    "failed_tests": 2,
    "total_tests": 8
  },
  "comparison": {
    "winner": {
      "overall": "constrained",
      "correctness_delta": 2,
      "time_delta_ms": -368
    }
  }
}
```

### Run Summary

`run_summary.json` contains aggregate statistics:

```json
{
  "statistics": {
    "total_tasks": 60,
    "completed_tasks": 58,
    "failed_tasks": 2,
    "constrained_wins": 42,
    "baseline_wins": 12,
    "ties": 4
  },
  "timing_breakdown": {
    "avg_constraint_compilation_ms": 15,
    "avg_generation_ms_constrained": 4200,
    "avg_generation_ms_baseline": 4350
  }
}
```

## Troubleshooting

### "InvalidCategory" Error

A task definition has an invalid category. Valid categories are listed in `task_spec.zig`. Fix the category in the task JSON.

### "GenerationFailed" Error

1. Check Modal service is deployed: `modal app list`
2. Verify endpoint URL is correct
3. Check Modal logs: `modal app logs ananke-eval-inference`

### Tests Failing

1. Ensure language runtime is installed
2. Check fixture paths exist
3. Run tests manually:
   ```bash
   cd eval/tasks/fixtures/rust
   cargo test --test result_handling_test
   ```

### Cold Start Timeout

GPU containers take ~5-10 min on first start. Subsequent requests are fast (~3s).

### Out of Memory

Reduce `gpu_memory_utilization` in `inference_service.py` or use smaller model.

## Progressive Difficulty Chains

Tasks are organized in chains for progressive difficulty:

| Chain | Position 1 | Position 2 | Position 3 |
|-------|-----------|-----------|-----------|
| validation | Basic input | Schema validation | Cross-field |
| parser | Line parser | JSON parser | DSL parser |
| cache | Memoization | LRU cache | Distributed |
| sort | Basic sort | Custom comparator | External merge |

Chain tasks share common concepts but increase in complexity.

## Metrics Collected

### Correctness
- Tests passed/failed
- Compilation success
- pass@k (with multiple samples)

### Quality
- Cyclomatic complexity
- Maintainability index
- Lines of code

### Constraint Satisfaction
- CSR: Complete Satisfaction Rate
- SSR: Structural Satisfaction Rate
- Pattern matches

### Timing
- Constraint compilation time
- Generation time
- Test execution time
- Total end-to-end time

## Report Generation

Generate HTML/Markdown reports:

```bash
python eval/report_generator.py \
  --results-dir eval/results_20241209_143000 \
  --output report.html
```

## Best Practices

1. **Always rebuild** after modifying Zig code: `zig build eval`
2. **Validate tasks** individually before full runs
3. **Use MODAL_MODE=dev** during development
4. **Monitor costs** on Modal dashboard
5. **Keep fixtures minimal** - focus on testing core functionality
6. **Document constraints** clearly for reproducibility
