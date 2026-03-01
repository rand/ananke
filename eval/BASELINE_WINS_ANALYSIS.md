# Analysis: Cases Where Baseline Outperformed Constrained Generation

**Evaluation Run**: December 9, 2025
**Model**: Qwen/Qwen2.5-Coder-7B-Instruct
**Hardware**: NVIDIA H100 (Modal)
**Total Tasks**: 60 | **Baseline Wins**: 11 (18.3%)

---

## Executive Summary

In 11 of 60 tasks (18.3%), unconstrained generation outperformed constrained generation. Analysis reveals three primary failure modes:

1. **Code Quality Collapse** (5 tasks): Constrained outputs scored exactly 50.0 in code quality vs. baseline's 83-89, suggesting the constraint system is forcing suboptimal code patterns.

2. **Constraint Adherence Penalty** (3 tasks): Paradoxically, some constrained outputs score *lower* on constraint adherence (40%) than baseline (50%), indicating the constraints may be malformed or overly restrictive.

3. **Generation Timeout Effects** (3 tasks): Constrained generation took 10-16x longer (53s vs. 3-5s), suggesting the constraint automaton is causing excessive backtracking.

---

## Detailed Task Analysis

### Category 1: Code Quality Collapse (Score = 50.0)

Five tasks show an identical pattern: constrained code quality collapses to exactly 50.0 while baseline achieves 83-89.

| Task | Baseline Quality | Constrained Quality | Delta | Generation Time Ratio |
|------|-----------------|---------------------|-------|----------------------|
| algo_001_binary_search | 86.67 | 50.00 | -36.67 | 16.5x slower |
| algo_002_merge_sort | 86.67 | 50.00 | -36.67 | 0.26x (faster!) |
| algo_003_graph_dfs | 85.33 | 50.00 | -35.33 | 12.2x slower |
| data_001_csv_parser | 89.33 | 50.00 | -39.33 | 10.9x slower |
| math_001_prime_generator | 83.33 | 50.00 | -33.33 | 11.5x slower |

**Observation**: The code quality score of exactly 50.0 across five different tasks suggests a systematic issue rather than task-specific problems. This score likely represents a floor value when the quality scorer cannot properly parse or analyze the constrained output.

**Hypothesis**: The constraint system may be:
1. Truncating outputs mid-function due to constraint violations
2. Forcing non-idiomatic patterns that confuse the quality analyzer
3. Generating valid but malformed code (e.g., missing closing braces that match the regex but fail parsing)

**Evidence supporting truncation**: These five tasks all had constrained generation times of 53+ seconds (except merge_sort), hitting what appears to be a timeout ceiling. When generation times out, partial outputs may receive default scores.

---

### Category 2: Constraint Adherence Paradox

Three tasks show constrained generation scoring *lower* on constraint adherence than baseline:

| Task | Baseline Adherence | Constrained Adherence | Pattern Conformity (B/C) |
|------|-------------------|----------------------|-------------------------|
| string_001_url_parser | 50.00 | 40.00 | 83.33 / 70.00 |
| fileio_001_log_analyzer | 50.00 | 40.00 | 81.67 / 70.00 |
| security_001_input_sanitizer | 50.00 | 40.00 | 81.67 / 70.00 |

**Observation**: This is a critical finding. The constrained mode exists to *improve* constraint adherence, yet these tasks show a 10-point penalty. The pattern conformity drops from ~82 to 70 as well.

**Timing Analysis**:
- `security_001_input_sanitizer`: Constrained took only 452ms (baseline: 7,266ms) - 16x *faster*
- `string_001_url_parser`: Constrained took 555ms (baseline: 8,989ms) - 16x faster
- `fileio_001_log_analyzer`: Constrained took 519ms (baseline: 9,431ms) - 18x faster

**Hypothesis**: The extremely fast constrained generation times suggest the constraint automaton is terminating generation prematurely. A well-formed constraint should guide generation, not truncate it. These constraints may be:
1. Too restrictive, causing immediate rejection of most token sequences
2. Malformed, matching trivial outputs
3. Accepting minimal solutions that satisfy the regex but ignore requirements

---

### Category 3: Language-Specific Challenges

Three tasks involve non-TypeScript languages where constrained generation underperforms:

| Task | Language | Overall Delta | Code Quality (B/C) | Notes |
|------|----------|---------------|-------------------|-------|
| go_002_http_middleware | Go | -5.12 | 75.22 / 54.73 | Same adherence scores |
| javascript_001_async_queue | JavaScript | -2.75 | 78.23 / 67.24 | Minimal timing difference |
| zig_003_error_union | Zig | -2.44 | 86.00 / 76.23 | Comparable everything |

**Observation**: These three tasks show smaller deltas (-2.4 to -5.1) and more balanced metrics. Unlike Category 1, code quality doesn't collapse to 50.0. Unlike Category 2, timing is reasonable.

**Analysis by language**:

**Go (go_002_http_middleware)**:
- Code quality drop of 20.5 points (75.22 → 54.73)
- Same constraint adherence (50.00) in both modes
- Suggests the constraint patterns may not be well-suited to Go's syntax

**JavaScript (javascript_001_async_queue)**:
- Smallest delta (-2.75) of all baseline wins
- Code quality drop of 11 points (78.23 → 67.24)
- Async patterns may be inherently harder to constrain

**Zig (zig_003_error_union)**:
- Code quality drop of 10 points (86.00 → 76.23)
- Error handling idioms (errdefer, catch, try) may not map well to regex constraints
- Zig's unique syntax may require specialized constraint patterns

---

## Pattern Analysis

### Timing Bimodality

The constrained generation times fall into two distinct clusters:

**Cluster A: Timeout Zone (50-56 seconds)**
- algo_001_binary_search: 53,581ms
- algo_002_merge_sort: 56,193ms
- algo_003_graph_dfs: 53,655ms
- data_001_csv_parser: 53,608ms
- math_001_prime_generator: 53,311ms

**Cluster B: Fast Termination (450-900ms)**
- security_001_input_sanitizer: 452ms
- string_001_url_parser: 555ms
- fileio_001_log_analyzer: 519ms

**Interpretation**: Cluster A suggests the constraint automaton is causing excessive exploration/backtracking before timing out. Cluster B suggests premature acceptance of minimal outputs.

### Code Quality Score Distribution

| Score Range | Count | Tasks |
|-------------|-------|-------|
| 50.00 | 5 | algo_001, algo_002, algo_003, data_001, math_001 |
| 54-68 | 2 | go_002 (54.73), javascript_001 (67.24) |
| 76-84 | 4 | zig_003 (76.23), string_001 (83.33), fileio_001 (83.33), security_001 (83.33) |

---

## Root Cause Hypotheses

### 1. Constraint Compilation Quality

The Braid constraint compiler may be generating suboptimal automata for certain pattern types:
- **Algorithmic tasks**: Complex function signatures with generic types may produce explosive state spaces
- **Parsing tasks**: String manipulation constraints may be too permissive or too strict

### 2. Quality Scorer Limitations

The code quality scorer may have blind spots:
- **Partial outputs**: Truncated code may receive default 50.0 scores
- **Non-standard patterns**: Constrained outputs may use valid but unusual constructs
- **Language coverage**: Go, JavaScript, and Zig quality scoring may be less mature

### 3. Constraint Design Issues

The constraint JSON files for affected tasks may have issues:
- **Over-constraining**: Patterns too specific, rejecting valid solutions
- **Under-constraining**: Patterns too loose, accepting trivial solutions
- **Missing negative constraints**: No "must not contain" patterns for common failure modes

---

## Recommendations

### Immediate Actions

1. **Audit the 50.0-scoring tasks**: Examine actual generated code to determine if it's truncated, malformed, or simply non-idiomatic.

2. **Review fast-terminating constraints**: The 400-600ms generation times for URL parser, log analyzer, and input sanitizer suggest the constraints are matching too early.

3. **Add constraint timeout detection**: Log when constrained generation hits time limits to distinguish timeout failures from successful completions.

### Constraint Improvements

1. **Add length minimums**: Require generated code to exceed a minimum token count based on task complexity.

2. **Include structural anchors**: Ensure constraints require key structural elements (function signatures, return statements, error handling).

3. **Test constraint discriminativeness**: Verify constraints reject obviously wrong solutions (empty functions, stub implementations).

### Evaluation Framework

1. **Add intermediate metrics**: Track "constraint satisfaction without truncation" separately.

2. **Include generation length**: Report token counts to identify truncation.

3. **Manual review queue**: Flag tasks where constrained and baseline diverge by >5 points for human review.

---

## Conclusion

The 11 baseline wins reveal two distinct failure modes in constrained generation:

1. **Timeout failures** (5 tasks): Constraints cause excessive backtracking, leading to timeouts and truncated outputs scored at 50.0.

2. **Premature termination** (3 tasks): Constraints match too aggressively, accepting minimal outputs that score poorly on adherence.

3. **Language gaps** (3 tasks): Non-TypeScript languages show moderate quality degradation, suggesting constraint patterns need language-specific tuning.

The overall win rate of 81.7% for constrained generation is encouraging, but these failure cases highlight the importance of constraint quality. A well-designed constraint should guide generation toward better solutions, not create pathological behavior at either extreme.

---

## Appendix: Raw Data

### Full Results Table

| Task ID | Delta | Winner | Baseline Quality | Constrained Quality | Baseline Time | Constrained Time |
|---------|-------|--------|------------------|---------------------|---------------|------------------|
| algo_001_binary_search | -9.17 | unconstrained | 86.67 | 50.00 | 3,243ms | 53,581ms |
| data_001_csv_parser | -9.17 | unconstrained | 89.33 | 50.00 | 4,908ms | 53,608ms |
| algo_002_merge_sort | -9.17 | unconstrained | 86.67 | 50.00 | 215,330ms | 56,193ms |
| math_001_prime_generator | -8.33 | unconstrained | 83.33 | 50.00 | 4,625ms | 53,311ms |
| algo_003_graph_dfs | -8.17 | unconstrained | 85.33 | 50.00 | 4,379ms | 53,655ms |
| security_001_input_sanitizer | -6.50 | unconstrained | 88.00 | 83.33 | 7,266ms | 452ms |
| go_002_http_middleware | -5.12 | unconstrained | 75.22 | 54.73 | 16,791ms | 14,737ms |
| string_001_url_parser | -4.72 | unconstrained | 79.56 | 83.33 | 8,989ms | 555ms |
| fileio_001_log_analyzer | -4.06 | unconstrained | 78.23 | 83.33 | 9,431ms | 519ms |
| javascript_001_async_queue | -2.75 | unconstrained | 78.23 | 67.24 | 6,684ms | 8,832ms |
| zig_003_error_union | -2.44 | unconstrained | 86.00 | 76.23 | 10,623ms | 11,943ms |

### Constraint Adherence Comparison

| Task ID | Baseline | Constrained | Difference |
|---------|----------|-------------|------------|
| algo_001_binary_search | 50.00 | 60.00 | +10.00 |
| data_001_csv_parser | 50.00 | 60.00 | +10.00 |
| algo_002_merge_sort | 50.00 | 60.00 | +10.00 |
| math_001_prime_generator | 50.00 | 60.00 | +10.00 |
| algo_003_graph_dfs | 50.00 | 60.00 | +10.00 |
| security_001_input_sanitizer | 50.00 | 40.00 | -10.00 |
| go_002_http_middleware | 50.00 | 50.00 | 0.00 |
| string_001_url_parser | 50.00 | 40.00 | -10.00 |
| fileio_001_log_analyzer | 50.00 | 40.00 | -10.00 |
| javascript_001_async_queue | 50.00 | 50.00 | 0.00 |
| zig_003_error_union | 50.00 | 50.00 | 0.00 |
