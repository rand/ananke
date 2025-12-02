# Task Creation Workflow Guide

This guide documents the complete workflow for creating evaluation benchmark tasks.

## Overview

Each task requires 4 files:
1. **Task definition** (JSON) - Specification and metadata
2. **Reference implementation** - Gold standard solution
3. **Test suite** - Comprehensive tests (>80% coverage)
4. **Constraints** - Extracted rules for constrained generation

## Workflow Steps

### 1. Task Definition (`eval/tasks/definitions/*.json`)

Create a JSON file with the following structure:

```json
{
  "id": "category_NNN_name",
  "title": "Human-readable task name",
  "description": "What to implement",
  "category": "algorithms|api|data_processing|web_components|system_utilities|security",
  "language": "typescript|python",
  "difficulty": "simple|moderate|complex",
  "requirements": [
    "Specific requirement 1",
    "Specific requirement 2"
  ],
  "reference_impl_path": "eval/tasks/fixtures/category/name.ext",
  "test_suite_path": "eval/tasks/fixtures/category/name.test.ext",
  "constraint_path": "eval/tasks/constraints/category_name.json",
  "expected_loc": 20,
  "few_shot_examples": [
    {
      "prompt": "Related task description",
      "code": "Example solution code"
    }
  ]
}
```

**Key Guidelines:**
- Use descriptive, unique IDs: `{category}_{number}_{name}`
- Be specific in requirements (function names, parameters, return types)
- Include 3-5 few-shot examples from same category
- Set realistic `expected_loc` based on reference implementation

### 2. Reference Implementation (`eval/tasks/fixtures/`)

Write production-quality reference code that:
- Follows all requirements exactly
- Demonstrates best practices
- Includes proper types and error handling
- Has clear, documented code structure

**TypeScript Example:**
```typescript
/**
 * Function description
 * @param param1 - Description
 * @returns Description
 */
export function functionName(param1: Type): ReturnType {
  // Implementation
}
```

**Python Example:**
```python
from typing import List, Optional

def function_name(param1: Type) -> ReturnType:
    """Function description.

    Args:
        param1: Description

    Returns:
        Description
    """
    # Implementation
```

### 3. Test Suite (`eval/tasks/fixtures/*.test.*`)

Create comprehensive tests covering:
- **Basic functionality** (happy paths)
- **Edge cases** (empty inputs, boundaries, single elements)
- **Error conditions** (invalid inputs, out of range)
- **Performance** (for algorithm tasks, verify complexity)
- **Type safety** (for TypeScript)

**Aim for >80% code coverage** across:
- All code paths
- All branches
- All edge cases
- Common user errors

**TypeScript Test Structure:**
```typescript
import { describe, it, expect } from '@jest/globals';
import { functionName } from './module';

describe('functionName', () => {
  it('should handle basic case', () => {
    expect(functionName(input)).toBe(expected);
  });

  it('should handle edge case', () => {
    expect(functionName(edge)).toBe(expected);
  });

  // More tests...
});
```

### 4. Constraints (`eval/tasks/constraints/*.json`)

Extract or manually define constraints:

```json
{
  "task_id": "category_NNN_name",
  "constraints": {
    "grammar": "Function signature and structure",
    "type_constraints": {
      "parameters": [...],
      "return_type": "type"
    },
    "naming_constraints": {
      "function_name": "exactName",
      "variable_patterns": ["required", "variables"]
    },
    "structural_constraints": {
      "must_use": ["required patterns"],
      "must_not_use": ["forbidden patterns"]
    }
  },
  "extracted_from": "path/to/reference",
  "extraction_method": "clew|manual",
  "verified": true
}
```

**Constraint Types:**
- **Type constraints**: Parameter types, return types, generics
- **Naming constraints**: Function names, variable names, patterns
- **Structural constraints**: Required/forbidden language features
- **Complexity constraints**: Big-O requirements (for algorithms)

## Task Categories

### Algorithms & Data Structures (10 tasks)
**Difficulty:** Simple (6), Moderate (3), Complex (1)
**Examples:** Binary search, sorting, tree traversal, graph algorithms, dynamic programming
**Language:** TypeScript (7), Python (3)

### API Development (10 tasks)
**Difficulty:** Simple (3), Moderate (5), Complex (2)
**Examples:** REST endpoint validation, error handling, authentication, rate limiting
**Language:** TypeScript (6), Python (4)

### Data Processing (10 tasks)
**Difficulty:** Simple (4), Moderate (4), Complex (2)
**Examples:** CSV/JSON parsing, data transformation, aggregation, filtering
**Language:** Python (6), TypeScript (4)

### Web Components (10 tasks)
**Difficulty:** Simple (3), Moderate (5), Complex (2)
**Examples:** Form validation, event handling, state management, async operations
**Language:** TypeScript (10)

### System Utilities (10 tasks)
**Difficulty:** Simple (4), Moderate (4), Complex (2)
**Examples:** File I/O, config parsing, logging, CLI argument parsing
**Language:** Python (6), TypeScript (4)

### Security-Critical (5 tasks)
**Difficulty:** Moderate (3), Complex (2)
**Examples:** Input sanitization, SQL injection prevention, XSS protection, credential handling
**Language:** TypeScript (3), Python (2)

## Quality Standards

### Reference Implementation
- ✅ Follows language conventions
- ✅ Proper error handling
- ✅ Clear documentation
- ✅ Type annotations (TypeScript) or type hints (Python)
- ✅ No security vulnerabilities

### Test Suite
- ✅ >80% code coverage
- ✅ Tests all requirements
- ✅ Edge cases covered
- ✅ Performance tests (for algorithms)
- ✅ All tests pass

### Constraints
- ✅ Accurately represent reference code patterns
- ✅ Allow valid implementations
- ✅ Prevent trivial solutions
- ✅ Enable constraint-based generation

## Example: Binary Search Task

**Complete file structure:**
```
eval/tasks/
├── definitions/
│   └── algorithms_binary_search.json         # Task specification
├── fixtures/
│   └── algorithms/
│       ├── binary_search.ts                   # Reference implementation
│       └── binary_search.test.ts              # Test suite
└── constraints/
    └── algorithms_binary_search.json          # Extracted constraints
```

See these files for a complete working example of the task creation workflow.

## Validation Checklist

Before marking a task complete:
- [ ] Task definition JSON is valid and complete
- [ ] Reference implementation follows all requirements
- [ ] All tests pass (`npm test` or `pytest`)
- [ ] Test coverage >80%
- [ ] Constraints accurately represent reference code
- [ ] Few-shot examples are relevant and high-quality
- [ ] Expected LOC matches actual reference implementation (±20%)

## Automation Opportunities

Future improvements:
- **Constraint extraction**: Use Clew to automatically extract constraints from reference code
- **Test generation**: Generate basic test scaffolds from requirements
- **Coverage validation**: Automated coverage reporting
- **Constraint validation**: Verify constraints allow reference implementation
