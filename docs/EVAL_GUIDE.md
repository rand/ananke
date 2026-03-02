# Evaluation Framework

The eval framework measures whether Ananke's constraints improve code generation. Every evaluation is a paired comparison: the same task, same model, same prompt -- once with constraints (Ananke) and once without. The question is simple: do constraints help, hurt, or not matter? And can we trust the answer?

Short version: look at the pass@1 delta. Positive means constraints help. Check p < 0.05 before believing it.

## Metrics

### Pass@k (Primary)

Pass@k is the probability that at least 1 of k samples passes all tests. The formula is the unbiased estimator from Chen et al. (2021):

```
pass@k = 1 - C(n-c, k) / C(n, k)
```

where n = total samples, c = correct samples (passed all tests), k = samples to consider. Computed in log space for numerical stability.

Default: 5 samples per task (`EvaluationConfig.evaluation.samples_per_task`). Pass@1 is the headline number. Pass@5 shows the ceiling -- what you get if you can cherry-pick. Pass@10 is computed but rarely reported with only 5 samples (it extrapolates).

Each `MultiSampleResult` carries a `PassAtKResults` with pass@1, pass@5, and pass@10 pre-computed.

### Correctness Score (60% of Overall)

Code that doesn't work is worthless. The scoring reflects this:

```
overall = 0.60 * correctness + 0.40 * quality_metrics
```

Correctness itself is:

```
correctness = 0.60 * test_pass_rate + 0.20 * compiles + 0.10 * valid_ast + 0.10 * exports_present
```

Each component scores 0-100. A function that compiles, has valid AST, exports correctly, but fails all tests scores 40. A function that passes every test scores 100. The weights are not subtle about their priorities.

### Quality Score (40% of Overall)

The quality score averages four sub-scores, each 0-100:

**Constraint Adherence** -- Does the generated code match the structural constraints? Checks: `signature_match`, `type_match`, `naming_match`, `structure_match`. Scored against the constraint JSON. Code generated without constraints gets a 75 baseline to avoid biasing the comparison.

**Pattern Conformity** -- Does the code follow language idioms? Three components: `style_consistency`, `idiom_usage`, `naming_conventions`. Language-specific checks:
- TypeScript: `const` usage, arrow functions (`=>`), `export` statements, type annotations (`: `)
- Python: `def` presence, type hints (`->`), decorators, `if __name__` patterns

**Code Quality** -- `readability`, `complexity`, `conciseness`. Nesting deeper than 4 levels hurts readability. Functions over 50 LOC hurt conciseness. The scorer also tracks cognitive complexity (SonarQube-style), cyclomatic complexity (McCabe), and a maintainability index. Code smells are counted: long functions, deep nesting, magic numbers, duplicate blocks, missing error handling, unused variables, long parameter lists (>5 params), poor naming (single-char variables outside loops).

**Security** -- Starts at 100 and subtracts. Detected dangerous patterns:
- `eval()`: -30 points
- `new Function()`: -25 points
- SQL concatenation (string interpolation in SELECT/INSERT/DELETE): -25 points
- Hardcoded secrets (`password =`, `api_key =`, `secret =`, and uppercase variants): -20 points

Input validation and error handling each add 10 points back (capped at 100).

### Winner Determination

Two thresholds, depending on where you're looking:

- **Quality scorer** (`ComparativeAnalysis`): 2% threshold. If the delta between constrained and unconstrained overall scores is less than 2 points, it's a tie.
- **Pass@k winner** (`MultiSampleEvaluationResult.getWinner()`): 5% threshold on pass@1 delta. Constrained wins only if its pass@1 exceeds unconstrained by more than 0.05.

### Statistical Tests

**Paired t-test**: Applied when n >= 5 samples. Returns t-statistic, p-value (two-tailed), 95% confidence interval, and Cohen's d effect size. Significance threshold: p < 0.05.

**Effect size interpretation** (Cohen's d): |d| < 0.2 negligible, 0.2-0.5 small, 0.5-0.8 medium, >= 0.8 large.

**Wilcoxon signed-rank test**: Non-parametric alternative, also available, requires n >= 5 non-zero differences.

**Bootstrap CI**: 95% confidence interval via resampling. Useful for small samples where t-test assumptions are shaky.

### CodeIF Constraint Metrics

Four-tier constraint satisfaction from CodeIF research:
- **CSR** (Complete Satisfaction Rate): Fraction of tasks where *all* constraints are fully met
- **SSR** (Soft Satisfaction Rate): Average proportion of constraints satisfied per task
- **RSR** (Rigorous Satisfaction Rate): Weighted by constraint criticality (low=0.5x, medium=1x, high=2x, critical=4x)
- **CCSR** (Consistent Continuity Rate): How consistently constraints are satisfied across multiple samples

## Running Evals

### Configuration

`EvaluationConfig` captures everything needed for reproducibility:

| Parameter | Default |
|-----------|---------|
| `model.name` | `Qwen/Qwen2.5-Coder-7B-Instruct` |
| `model.provider` | `vLLM` |
| `hardware.gpu_type` | `NVIDIA H100` |
| `hardware.platform` | `Modal` |
| `constraint_system.backend` | `llguidance` |
| `constraint_system.integration` | `vLLM regex-guided decoding` |
| `constraint_system.compiler` | `Braid` |
| `evaluation.temperature` | `0.0` (deterministic) |
| `evaluation.top_p` | `0.95` |
| `evaluation.max_tokens_multiplier` | `20` (max_tokens = expected_loc * 20) |
| `evaluation.max_tokens_cap` | `4096` |
| `evaluation.samples_per_task` | `5` |
| `evaluation.random_seed` | `null` (random) |

The `run_id` is an ISO 8601 timestamp. Framework version is `"1.0.0"`.

### Evaluation API

```zig
// Single-sample paired evaluation
var evaluator = Evaluator.init(allocator, endpoint_url);
const pair = try evaluator.evaluateTask(task);
// pair.comparison has constrained vs unconstrained deltas

// Multi-sample pass@k evaluation
var multi = MultiSampleEvaluator.init(allocator, endpoint_url, config);
const result = try multi.evaluateTask(task);
// result.getWinner() -> .constrained | .unconstrained | .tie

// Batch evaluation across many tasks
const batch = try multi.evaluateBatch(tasks);
// batch.passAt1Delta(), batch.isSignificant(), batch.effectSizeInterpretation()
```

The `Evaluator` runs one sample per mode. The `MultiSampleEvaluator` runs `samples_per_task` samples per mode and computes pass@k. Use `MultiSampleEvaluator` for any result you plan to publish or act on.

### Timing

Every generation records a `TimingBreakdown`:

| Field | What it measures |
|-------|-----------------|
| `constraint_compilation_ms` | Braid compilation (0 for baseline) |
| `generation_ms` | vLLM inference API call |
| `test_execution_ms` | Running tests on generated code |
| `total_ms` | End-to-end wall time |
| `overhead_ms` | total - (compilation + generation + tests) |

The overhead is network, JSON parsing, prompt construction. If it's large relative to generation time, your bottleneck isn't the model.

## Interpreting Results

`BatchEvaluationResult` is what you get from evaluating many tasks:

- `passAt1Delta()` -- mean(constrained pass@1) - mean(unconstrained pass@1). Positive = constraints help.
- `isSignificant()` -- p < 0.05 from the paired t-test across tasks.
- `effectSizeInterpretation()` -- "negligible", "small", "medium", or "large".

A positive pass@1 delta with p < 0.05 and a medium-or-larger effect size is a solid result. A positive delta with p > 0.05 means you might be seeing noise -- get more tasks. A negative delta means constraints are actively hurting, which is worth investigating (over-constraining? bad constraint specs?).

`MultiSampleEvaluationResult` gives per-task detail:

- `getWinner()` -- based on pass@1 with 5% tie threshold
- `constraint_comparison` -- CodeIF metrics showing constraint satisfaction rates

## Task Specification

### Task Spec Format

Tasks are defined in JSON and loaded via `TaskSpec.fromJson()`:

```json
{
  "id": "task-001",
  "title": "Implement binary search",
  "description": "Write a binary search function...",
  "category": "algorithms",
  "language": "typescript",
  "difficulty": "medium",
  "requirements": ["Must handle empty arrays", "Must return -1 for not found"],
  "reference_impl_path": "eval/tasks/reference/binary_search.ts",
  "test_suite_path": "eval/tasks/tests/binary_search.test.ts",
  "constraint_path": "eval/tasks/constraints/binary_search.json",
  "few_shot_examples": [],
  "expected_loc": 15
}
```

`TaskSpec.validate()` checks that `reference_impl_path`, `test_suite_path`, and `constraint_path` all point to files that exist. Call it before running evals unless you enjoy debugging file-not-found errors during a long batch run.

### Categories and Difficulties

24 task categories: `algorithms`, `api`, `async`, `caching`, `concurrency`, `data_processing`, `data_structures`, `database`, `error_handling`, `file_io`, `mathematics`, `memory_management`, `messaging`, `parsing`, `patterns`, `performance`, `resilience`, `security`, `string_processing`, `system_utilities`, `type_system`, `utilities`, `validation`, `web_components`.

4 difficulty levels: `simple`, `medium`, `moderate`, `complex`.

2 target languages: TypeScript, Python.

### Adding a Task

1. Write a reference implementation. This is ground truth.
2. Write a test suite that the reference implementation passes.
3. Write a constraint file in the eval constraint JSON format.
4. Create the task spec JSON pointing to all three files.
5. Run `TaskSpec.validate()` to confirm paths resolve.

The reference implementation and test suite are required for pass@k. The constraint file is required for constrained mode. The `expected_loc` field controls max token budget: `max_tokens = min(expected_loc * max_tokens_multiplier, max_tokens_cap)`.

## Source Files

| File | Contents |
|------|----------|
| `eval/core/evaluator.zig` | `Evaluator`, `MultiSampleEvaluator`, `BatchEvaluationResult`, `EvaluationConfig` |
| `eval/core/task_spec.zig` | `TaskSpec`, `TaskCategory`, `DifficultyLevel`, `Language`, `TimingBreakdown` |
| `eval/core/quality_scorer.zig` | `QualityScorer`, `QualityScore`, `ComparativeAnalysis`, `CodeSmells` |
| `eval/core/metrics/pass_at_k.zig` | `computePassAtK`, `PassAtKResults`, `AggregatePassAtK`, `SampleResult` |
| `eval/core/metrics/statistical_tests.zig` | `pairedTTest`, `wilcoxonSignedRank`, `bootstrapCI`, `ComparisonResult` |
| `eval/core/metrics/constraint_metrics.zig` | `CodeIFMetrics`, `ConstraintComparison`, `TaskConstraintResult` |
| `eval/core/modal_client.zig` | Modal inference API client |
| `eval/core/test_runner.zig` | Test execution for generated code |
| `eval/core/eval_constraint_compiler.zig` | Constraint compilation for eval format |
| `eval/core/failure_analyzer.zig` | Failure analysis and diagnostics |
| `eval/core/prompt_normalizer.zig` | Prompt normalization and comparison |
