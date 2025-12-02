# Test Infrastructure Fix Plan

## Summary of Findings

### Baseline Failures: NOT Confounded
The baseline failures are **legitimate quality issues**, not infrastructure problems:
- LLM generates duplicate function implementations
- Embedded markdown code fences (` ```typescript `) in source code
- Multiple code blocks concatenated together
- ~7000 bytes of rambling output vs ~800 bytes of focused constrained output

**Conclusion**: No fix needed - this is exactly what constraints are meant to prevent.

---

## 5 Tasks with Test Infrastructure Issues

### Issue 1: Python Test File Naming Mismatch

**Affected Tasks**:
- `csv_parser` (Python)
- `config_parser` (Python)

**Root Cause**:
- Test runner `run_tests.sh` line 209 expects: `test_<module>.py` (prefix)
- Actual files use: `<module>_test.py` (suffix)

```bash
# Current code (line 209):
local module_name="${test_basename#test_}"

# This transforms:
#   test_csv_parser.py → csv_parser.py  ✅ Works
#   csv_parser_test.py → csv_parser_test.py  ❌ Wrong!
```

**Fix Options**:
1. **Option A**: Rename test files to match expected pattern
   - `csv_parser_test.py` → `test_csv_parser.py`
   - `system_config_parser_test.py` → `test_config_parser.py`

2. **Option B**: Update test runner to handle both patterns
   - Check for `_test.py` suffix first, then `test_` prefix

**Recommended**: Option A - simpler, follows pytest convention

---

### Issue 2: Missing Type Exports in Constraints

**Affected Tasks**:
- `json_validator` (TypeScript)
- `url_parser` (TypeScript)

**Root Cause**:
Test imports expect multiple exports, but constraints only specify the main function:

```typescript
// Test expects:
import { validateJSON, Schema } from './json_validator';

// Constraint only specifies:
"grammar": "export function validateJSON(data: any, schema: Schema): {valid: boolean, errors: string[]}"
// Missing: export interface Schema { ... }
```

**Fix**:
Update constraint grammar to include type exports:
```json
"grammar": "export interface Schema { properties: Record<string, {type: string}>; required?: string[] }\nexport function validateJSON(data: any, schema: Schema): {valid: boolean, errors: string[]}"
```

---

### Issue 3: LRU Cache Anomaly

**Affected Task**: `lru_cache` (TypeScript)

**Observation**:
- Constrained code: 9138 bytes (suspiciously large)
- Baseline code: 940 bytes (suspiciously small)
- This is inverted from expected pattern

**Possible Causes**:
1. Constrained generation may have included explanations
2. The complex grammar (class with methods) may confuse the model
3. The constraint uses signature-only grammar without body hints

**Investigation Needed**:
- Examine actual generated code
- Check if grammar format is causing issues
- May need to simplify constraint or add explicit code generation hints

---

## Implementation Priority

### Phase 1: Quick Wins (High Impact, Low Effort)
1. Rename Python test files to `test_*.py` convention
2. Update json_validator constraint to export Schema type
3. Update url_parser constraint to export necessary types

### Phase 2: Test Runner Improvements
1. Add support for both `test_*.py` and `*_test.py` naming
2. Add debug logging for pytest similar to jest
3. Handle missing pytest-json-report gracefully

### Phase 3: Constraint Refinement
1. Review LRU cache constraint and generated code
2. Consider adding type definitions to all TypeScript constraints
3. Test each constraint in isolation before full run

---

## Expected Outcomes After Fixes

| Task | Before | After (Expected) |
|------|--------|------------------|
| csv_parser | 0/0 | Tests detected |
| config_parser | 0/0 | Tests detected |
| json_validator | 0/0 | 15+/X tests |
| url_parser | 0/0 | 10+/X tests |
| lru_cache | 0/0 | Investigate first |

---

## Validation Criteria

Before declaring fixes complete:
1. Run reference implementations through test runner manually
2. Verify test detection for all 5 tasks
3. Re-run full evaluation
4. Confirm constrained > baseline for all working tasks
