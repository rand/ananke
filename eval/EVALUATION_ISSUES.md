# Ananke Evaluation Framework - Critical Issues and Remediation Plan

## Executive Summary

The evaluation methodology has **fundamental flaws** that undermine the validity of comparing grammar-constrained vs unconstrained code generation. The current results (81.8% constrained vs 100% baseline on working tasks, but baseline fails to run on 8/15 tasks) reflect **infrastructure issues and information asymmetry**, not the efficacy of grammar constraints.

---

## Critical Issues

### Issue 1: Information Asymmetry (CRITICAL - Invalidates Study)

**Problem**: The comparison is not fair.

| Method | Information Provided |
|--------|---------------------|
| Constrained | Task description + **EXACT function signature including `export`** |
| Unconstrained | Task description + few-shot examples (pattern, not explicit signature) |

**Evidence**:
- `inference_service.py:151-174`: Constrained prompt includes `REQUIRED SIGNATURE: {grammar}`
- `inference_service.py:176-200`: Unconstrained only shows examples

**Impact**: We're measuring "explicit signature helps" not "grammar constraints help"

**Fix Options**:
1. **Option A**: Add explicit signature to unconstrained prompt (makes comparison fair)
2. **Option B**: Remove signature from constrained, use only grammar enforcement
3. **Option C**: Reframe study as "signature specification" vs "pattern learning"

### Issue 2: Grammar Not Actually Constraining Generation (CRITICAL)

**Problem**: The "grammar" fields are NOT valid JSON schemas.

**Evidence** from constraint files:
```json
"grammar": "export function binarySearch(arr: number[], target: number): number {\n..."
```

This is a **string signature**, not a JSON schema. vLLM's llguidance cannot enforce this.

**Code path** (`inference_service.py:294-300`):
```python
try:
    json.loads(grammar)  # This FAILS for string signatures
except:
    constraint_type_used = "prompt_enforced"  # Falls back to prompt only
```

**Impact**: "Grammar-constrained generation" is actually "prompt engineering with signature"

**Fix**: Convert all constraint files to valid JSON schemas OR acknowledge this is prompt-based comparison

### Issue 3: Baseline Missing Export Keyword (CONFIRMED)

**Problem**: Baseline code lacks `export` even when all 3 few-shot examples have it.

**Evidence** from `/tmp/ananke_impl_*.ts`:
- Baseline: `function binarySearch(...)`
- Constrained: `export function binarySearch(...)`

**Root Cause**: Prompt says "Generate ONLY the code" but doesn't explicitly require `export`

**Fix**: Add to unconstrained prompt:
```
IMPORTANT: All functions and classes must be exported using the 'export' keyword.
```

### Issue 4: Python Test Runner Early Exit (CRITICAL)

**Problem**: `set -euo pipefail` causes script to exit when pytest returns non-zero

**Evidence**: `run_tests.sh:16` sets strict mode, but pytest returns 1 on test failures

**Impact**: Result JSON never created, shows 0/0 tests

**Fix** (`run_tests.sh:238-248`):
```bash
# Change from:
if pytest ...; then

# To:
local exit_code=0
pytest ... || exit_code=$?
```

### Issue 5: TypeScript Code Contains Markdown Fences

**Problem**: Generated code still contains ` ```typescript` markers

**Evidence**: `/tmp/ananke_impl_*.ts` files show markdown in actual code

**Impact**: TypeScript compilation fails, 0/0 tests

**Fix**: Enhance `_extract_code()` to strip ALL markdown artifacts

### Issue 6: Duplicate Code in Constrained Output

**Problem**: Constrained generation for complex tasks produces duplicate implementations

**Evidence**: `lru_cache.ts` is 9138 bytes with multiple `class LRUCache` definitions

**Impact**: TypeScript error TS2300: Duplicate identifier

**Fix**: Detect and truncate at first complete implementation

### Issue 7: No Generated Code Preservation

**Problem**: Cannot inspect what code was generated after test failures

**Evidence**: `test_runner.zig:41` deletes temp files immediately

**Fix**: Save failed implementations to results directory

---

## Remediation Plan

### Phase 1: Fix Fair Comparison (Priority: BLOCKER)

**Goal**: Ensure both methods receive equivalent information

**Tasks**:
1. [ ] Decide: Add signature to baseline OR remove from constrained
2. [ ] Modify `_build_unconstrained_prompt()` to include explicit export instruction
3. [ ] Verify prompts provide equivalent information content

**Files to modify**:
- `eval/modal/inference_service.py` (lines 176-200)

### Phase 2: Fix Test Infrastructure (Priority: CRITICAL)

**Goal**: All tests run and report results correctly

**Tasks**:
1. [ ] Fix Python test runner exit handling (`run_tests.sh:234-248`)
2. [ ] Enhance code extraction to remove ALL markdown (`inference_service.py:215-230`)
3. [ ] Handle duplicate code detection
4. [ ] Add generated code preservation on failure

**Files to modify**:
- `eval/test_runners/run_tests.sh`
- `eval/modal/inference_service.py`
- `eval/core/test_runner.zig`

### Phase 3: Verify Grammar Constraints (Priority: HIGH)

**Goal**: Confirm whether we're actually using grammar-constrained generation

**Tasks**:
1. [ ] Review all constraint files for JSON schema validity
2. [ ] Add logging to show `constraint_type_used` in results
3. [ ] Consider converting to actual JSON schemas OR reframing study

**Files to modify**:
- `eval/tasks/constraints/*.json`
- `eval/modal/inference_service.py`

### Phase 4: Add Variance Measurement (Priority: MEDIUM)

**Goal**: Statistical validity for claims

**Tasks**:
1. [ ] Run each task multiple times (3-5 runs)
2. [ ] Calculate mean and standard deviation
3. [ ] Add confidence intervals to results

### Phase 5: Documentation and Replication (Priority: MEDIUM)

**Goal**: Others can replicate and verify

**Tasks**:
1. [ ] Save ALL generated code (both methods)
2. [ ] Document exact prompts used
3. [ ] Create reproducibility instructions

---

## Recommended Immediate Actions

1. **STOP** publishing or relying on current results
2. **FIX** information asymmetry first (most critical)
3. **FIX** test runner exit handling
4. **RE-RUN** evaluation with fixed infrastructure
5. **VERIFY** what "constrained" actually means in practice

---

## File Reference

| File | Lines | Issue |
|------|-------|-------|
| `eval/modal/inference_service.py` | 151-200 | Prompt asymmetry |
| `eval/modal/inference_service.py` | 215-230 | Code extraction |
| `eval/modal/inference_service.py` | 294-300 | Grammar validation |
| `eval/test_runners/run_tests.sh` | 16 | Strict mode |
| `eval/test_runners/run_tests.sh` | 234-248 | Pytest handling |
| `eval/core/test_runner.zig` | 40-41 | File deletion |
| `eval/tasks/constraints/*.json` | grammar field | Not JSON schema |
