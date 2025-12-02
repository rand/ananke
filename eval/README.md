# Ananke Evaluation Framework

A comprehensive benchmarking system to measure the efficacy of constraint-guided code generation compared to unconstrained baseline approaches.

## Overview

This framework evaluates Ananke's constraint-based code generation by:

1. **Generating code in two modes**:
   - **Constrained**: Using Ananke's extracted constraints
   - **Unconstrained**: Using best-practice few-shot prompting (baseline)

2. **Comparing across 5 quality dimensions**:
   - Correctness (test pass rate)
   - Code quality (maintainability, readability)
   - Constraint adherence
   - Generation efficiency (time, tokens)
   - Robustness (edge case handling)

3. **Using a diverse task benchmark**: 50+ programming tasks across 6 categories and 3 difficulty levels

## Architecture

```
eval/
├── core/                    # Core evaluation infrastructure
│   ├── task_spec.zig       # Task specification types
│   ├── modal_client.zig    # Modal inference service client
│   ├── evaluator.zig       # Evaluation orchestrator
│   └── ...
├── baseline/                # Baseline generation (few-shot prompting)
│   └── generator.zig
├── tasks/                   # Task benchmark suite
│   ├── definitions/         # Task specifications (JSON)
│   ├── fixtures/            # Reference implementations & tests
│   └── constraints/         # Extracted constraints
├── runner.zig              # Batch evaluation runner
├── main.zig                # CLI entry point
└── README.md               # This file
```

## Task Benchmark

### Categories

1. **Algorithms & Data Structures** (10 tasks)
   - Binary search, sorting, tree traversal, dynamic programming
   - Languages: TypeScript (7), Python (3)

2. **API Development** (10 tasks)
   - Request validation, error handling, authentication, rate limiting
   - Languages: TypeScript (6), Python (4)

3. **Data Processing** (10 tasks)
   - CSV/JSON parsing, data transformation, aggregation
   - Languages: Python (6), TypeScript (4)

4. **Web Components** (10 tasks)
   - Form validation, event handling, state management
   - Languages: TypeScript (10)

5. **System Utilities** (10 tasks)
   - File I/O, config parsing, logging, CLI arguments
   - Languages: Python (6), TypeScript (4)

6. **Security-Critical** (5 tasks)
   - Input sanitization, XSS prevention, SQL injection prevention
   - Languages: TypeScript (3), Python (2)

### Difficulty Levels

- **Simple**: 20 tasks - Straightforward implementations, basic patterns
- **Moderate**: 22 tasks - Multi-step logic, error handling, edge cases
- **Complex**: 8 tasks - Advanced algorithms, performance optimization

## Task Structure

Each task requires 4 files:

### 1. Task Definition (`tasks/definitions/*.json`)

```json
{
  "id": "category_NNN_name",
  "title": "Human-readable task name",
  "description": "What to implement",
  "category": "algorithms|api|data_processing|...",
  "language": "typescript|python",
  "difficulty": "simple|moderate|complex",
  "requirements": ["Requirement 1", "Requirement 2"],
  "reference_impl_path": "eval/tasks/fixtures/category/name.ext",
  "test_suite_path": "eval/tasks/fixtures/category/name.test.ext",
  "constraint_path": "eval/tasks/constraints/category_name.json",
  "expected_loc": 20,
  "few_shot_examples": [{"prompt": "...", "code": "..."}]
}
```

### 2. Reference Implementation (`tasks/fixtures/`)

Production-quality reference code demonstrating best practices:
- Follows all requirements exactly
- Proper types and error handling
- Clear documentation
- No security vulnerabilities

### 3. Test Suite (`tasks/fixtures/*.test.*`)

Comprehensive tests with >80% coverage:
- Basic functionality (happy paths)
- Edge cases (empty inputs, boundaries)
- Error conditions (invalid inputs)
- Performance tests (for algorithms)

### 4. Constraints (`tasks/constraints/*.json`)

Extracted structural constraints:
```json
{
  "task_id": "category_NNN_name",
  "constraints": {
    "grammar": "Function signature and structure",
    "type_constraints": {...},
    "naming_constraints": {...},
    "structural_constraints": {...}
  },
  "extracted_from": "path/to/reference",
  "extraction_method": "clew|manual",
  "verified": true
}
```

## Usage

### Building

```bash
zig build
```

This builds:
- `ananke-eval` - Evaluation runner CLI
- All supporting libraries

### Running Evaluations

```bash
# List available tasks
./zig-out/bin/ananke-eval list

# Run all tasks
./zig-out/bin/ananke-eval run --modal-endpoint https://your-modal-endpoint.modal.run

# Run specific tasks
./zig-out/bin/ananke-eval run \
  --modal-endpoint https://your-modal-endpoint.modal.run \
  --tasks algo_001_binary_search,api_001_request_validator

# Custom output directory
./zig-out/bin/ananke-eval run \
  --modal-endpoint https://your-modal-endpoint.modal.run \
  --output eval/my_results
```

### Results

Results are saved as JSON files in `eval/results/` (or custom output dir):

```
eval/results/
├── algo_001_binary_search_results.json
├── api_001_request_validator_results.json
└── ...
```

Each result file contains:
- Constrained generation (code, metrics, test results)
- Unconstrained generation (code, metrics, test results)
- Comparison metrics

## Evaluation Metrics

### 1. Correctness
- Test pass rate (%)
- Functional completeness
- Edge case handling

### 2. Code Quality
- Readability (cyclomatic complexity, line length)
- Maintainability (modularity, documentation)
- Best practices adherence

### 3. Constraint Adherence
- Type constraints met
- Naming conventions followed
- Structural patterns present
- Forbidden patterns absent

### 4. Efficiency
- Generation time (ms)
- Tokens used
- Lines of code generated

### 5. Robustness
- Error handling coverage
- Null/undefined handling
- Boundary condition tests passed

## Modal Inference Service

The evaluation framework requires a Modal endpoint providing:

### Endpoints

```
POST /generate/constrained
{
  "prompt": "...",
  "constraints": {...},
  "model": "Qwen/Qwen2.5-Coder-32B-Instruct"
}

POST /generate/unconstrained
{
  "prompt": "...",
  "few_shot_examples": [...],
  "model": "Qwen/Qwen2.5-Coder-32B-Instruct"
}
```

### Response Format

```json
{
  "code": "generated code...",
  "metadata": {
    "tokens_used": 1234,
    "generation_time_ms": 567,
    "model": "Qwen/Qwen2.5-Coder-32B-Instruct"
  }
}
```

## Adding New Tasks

See `TASK_CREATION_GUIDE.md` for the complete workflow.

### Quick Steps

1. **Create task definition JSON**
2. **Write reference implementation**
3. **Create comprehensive test suite** (>80% coverage)
4. **Extract or define constraints**
5. **Validate**:
   - Task definition is valid JSON
   - All tests pass
   - Coverage >80%
   - Expected LOC matches actual (±20%)

### Example Tasks

Complete working examples are available:

- `algo_001_binary_search` - Algorithm (TypeScript, simple)
- `api_001_request_validator` - API (TypeScript, simple)
- `data_001_csv_parser` - Data Processing (Python, simple)
- `web_001_form_validator` - Web Component (TypeScript, simple)
- `system_001_config_parser` - System Utility (Python, simple)
- `algo_002_merge_sort` - Algorithm (TypeScript, moderate)
- `security_001_input_sanitizer` - Security (TypeScript, moderate)

## Future Enhancements

- **Automated constraint extraction**: Use Clew to extract constraints from reference code
- **Test generation**: Generate basic test scaffolds from requirements
- **Coverage validation**: Automated coverage reporting
- **Statistical analysis**: Paired t-tests, effect sizes
- **Human evaluation**: UI for side-by-side comparison
- **Metrics computation**: Automated quality scoring

## Research Questions

This framework helps answer:

1. **Does constraint-guided generation improve correctness?**
   - Higher test pass rates?
   - Better edge case handling?

2. **Does it improve code quality?**
   - More maintainable code?
   - Better adherence to best practices?

3. **What's the efficiency trade-off?**
   - Generation time overhead?
   - Token usage comparison?

4. **Which task categories benefit most?**
   - Algorithms vs API vs Security?
   - Simple vs Complex tasks?

5. **How robust is the approach?**
   - Constraint violation rates?
   - Graceful degradation?

## Current Status & Next Steps

### Completed (Phase 1, 2 & 3)

#### Phase 1: Core Infrastructure ✅
- [x] Core evaluation types (`task_spec.zig`)
- [x] Modal HTTP client (`modal_client.zig`)
- [x] Evaluation orchestrator (`evaluator.zig`)
- [x] Baseline generator (`baseline/generator.zig`)
- [x] Batch runner (`runner.zig`)
- [x] CLI entry point (`main.zig`)
- [x] Build system integration
- [x] Fixed Zig 0.15 ArrayList API compatibility

#### Phase 2: Task Benchmark Suite ✅
- [x] 15 task definitions created across multiple categories:
  - Algorithms: Binary Search, Merge Sort, Graph DFS
  - Data Structures: LRU Cache
  - Data Processing: CSV Parser, JSON Validator
  - String Processing: URL Parser
  - Mathematics: Prime Generator
  - File I/O: Log Analyzer
  - Database: SQL Query Builder
  - Concurrency: Rate Limiter
  - API: Request Validator
  - Web: Form Validator
  - Security: Input Sanitizer
- [x] 15 reference implementations with production-quality code
- [x] 15 comprehensive test suites (>80% coverage)
- [x] 15 constraint files extracted and validated

#### Phase 3: Evaluation Infrastructure ✅
- [x] Modal inference service (`eval/modal/inference_service.py`)
  - vLLM-based serving with Qwen/Qwen2.5-Coder-32B-Instruct
  - `/generate/constrained` endpoint for Ananke constraints
  - `/generate/unconstrained` endpoint for baseline few-shot
  - Deployment configuration and documentation
- [x] Test execution infrastructure
  - TypeScript test runner (Jest) - `eval/test_runners/run_tests.sh`
  - Python test runner (pytest) - `eval/test_runners/run_tests.sh`
  - Test result parser - `eval/core/test_runner.zig`
  - Integration with evaluator - automatic test execution
  - Comprehensive documentation - `eval/test_runners/README.md`

### Immediate Next Steps (Phase 2 Completion)

#### 1. Reference Implementations (15 remaining)
Create production-quality reference implementations for:
- `datastructures_lru_cache.ts`
- `algorithms_graph_dfs.ts`
- `data_json_validator.ts`
- `concurrency_rate_limiter.ts`
- `string_url_parser.ts`
- `math_prime_generator.ts`
- `fileio_log_analyzer.ts`
- `database_query_builder.ts`
- And 7 previously defined tasks

**Priority**: High - Required for test validation and constraint verification

#### 2. Test Suites (15 remaining)
Create comprehensive test suites (>80% coverage) for all tasks:
- Use Jest for TypeScript tasks
- Use pytest for Python tasks
- Cover: happy paths, edge cases, error conditions, performance
- Minimum 15 test cases per task

**Priority**: High - Required for correctness evaluation

#### 3. Expand Task Benchmark (35 more tasks)
Target: 50+ total tasks across 6 categories

**Breakdown by Category**:
- Algorithms & Data Structures: 7 more tasks
- API Development: 10 tasks (all new)
- Data Processing: 8 more tasks
- Web Components: 10 tasks (all new)
- System Utilities: 10 tasks (all new)
- Security-Critical: 5 tasks (all new)

**Priority**: Medium - Can be done iteratively

### Phase 3: Evaluation Execution

#### 4. Modal Inference Service Deployment
- [ ] Create Modal app definition
- [ ] Implement `/generate/constrained` endpoint
- [ ] Implement `/generate/unconstrained` endpoint
- [ ] Deploy to Modal cloud
- [ ] Test endpoints with sample tasks
- [ ] Configure API authentication
- [ ] Set up rate limiting

**Priority**: High - Blocking for evaluation runs

#### 5. Test Execution Infrastructure
- [ ] Implement test runner for TypeScript (Jest)
- [ ] Implement test runner for Python (pytest)
- [ ] Parse test results and extract metrics
- [ ] Handle test failures gracefully
- [ ] Capture test output and error messages
- [ ] Timeout handling for long-running tests

**Priority**: High - Core evaluation capability

#### 6. Quality Metrics Computation
- [ ] Implement cyclomatic complexity calculation
- [ ] Implement readability metrics (line length, nesting depth)
- [ ] Implement constraint adherence checker
- [ ] Implement AST-based pattern matching
- [ ] Implement efficiency metrics (tokens, time, LOC)
- [ ] Aggregate metrics across tasks

**Priority**: Medium - Enhances evaluation depth

### Phase 4: Analysis & Reporting

#### 7. Statistical Analysis
- [ ] Implement paired comparison tests
- [ ] Calculate effect sizes (Cohen's d)
- [ ] Generate confidence intervals
- [ ] Category-level aggregation
- [ ] Difficulty-level aggregation
- [ ] Export results to CSV for R/Python analysis

**Priority**: Medium - Required for research findings

#### 8. End-to-End Testing
- [ ] Test complete pipeline with 2-3 tasks
- [ ] Verify Modal integration
- [ ] Verify test execution
- [ ] Verify metrics computation
- [ ] Fix any integration issues
- [ ] Performance profiling and optimization

**Priority**: High - Validate entire system

#### 9. Documentation & Tooling
- [ ] Add example evaluation run walkthrough
- [ ] Document Modal setup process
- [ ] Add troubleshooting guide
- [ ] Create result visualization scripts
- [ ] Add CI/CD for evaluation runs
- [ ] Archive and version control results

**Priority**: Low - Quality of life improvements

### Quick Start for Contributors

To continue development:

1. **Add more tasks**: Follow `TASK_CREATION_GUIDE.md`
2. **Create reference implementations**: See `eval/tasks/fixtures/` for examples
3. **Write test suites**: Aim for >80% coverage
4. **Extract constraints**: Use Clew or manual extraction
5. **Test the task**: Validate definition, tests, and constraints

### Timeline Estimate

- **Phase 2 Completion**: 3-4 weeks (reference impls + tests for 15 tasks + 35 new tasks)
- **Phase 3**: 2-3 weeks (Modal deployment + test infrastructure + metrics)
- **Phase 4**: 1-2 weeks (statistical analysis + end-to-end testing)

**Total**: 6-9 weeks to full production-ready evaluation framework

## License

Part of the Ananke project.
