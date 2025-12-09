# Phase 8c: Production Examples - Implementation Plan

**Version**: 1.0  
**Status**: READY FOR IMPLEMENTATION  
**Author**: spec-author (Claude Code subagent)  
**Date**: 2025-11-27  
**Dependencies**: Phase 8a (E2E Tests) - COMPLETE, Phase 8b (Benchmarks) - COMPLETE  
**Estimated Effort**: 5 person-days (parallelizable to 1-2 days with 5 agents)

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Context & Requirements](#context--requirements)
3. [Example Architecture](#example-architecture)
4. [Implementation Breakdown](#implementation-breakdown)
   - [Example 1: OpenAPI Route Generation](#example-1-openapi-route-generation)
   - [Example 2: Database Migration Generator](#example-2-database-migration-generator)
   - [Example 3: React Component Generator](#example-3-react-component-generator)
   - [Example 4: CLI Tool Generator](#example-4-cli-tool-generator)
   - [Example 5: Test Generator from Specification](#example-5-test-generator-from-specification)
5. [Parallel Execution Strategy](#parallel-execution-strategy)
6. [Implementation Order](#implementation-order)
7. [Acceptance Criteria](#acceptance-criteria)
8. [Testing Strategy](#testing-strategy)
9. [Common Infrastructure](#common-infrastructure)
10. [Appendices](#appendices)

---

## Executive Summary

Phase 8c delivers 5 production-ready examples demonstrating Ananke's real-world value across diverse use cases. Unlike the existing tutorial examples (01-05), these are complete, runnable production scenarios that developers can clone, customize, and deploy.

### Key Deliverables

1. **OpenAPI Route Generation** - Generate Express/FastAPI routes from OpenAPI specs (TypeScript, P0)
2. **Database Migration Generator** - Create type-safe migrations from schema changes (SQL/TypeScript, P0)
3. **React Component Generator** - Build accessible components following design patterns (TypeScript/React, P1)
4. **CLI Tool Generator** - Generate robust CLI tools with argument parsing (Python/Click, P1)
5. **Test Generator** - Create comprehensive test suites from specifications (Python/pytest, P0)

### Success Metrics

- **Setup Time**: Each example runs in <10 minutes from git clone
- **Completeness**: Each includes input, constraints, output, tests, and README
- **Value**: Demonstrates practical ROI (time saved, errors prevented, consistency enforced)
- **Diversity**: Covers TypeScript (3 examples) and Python (2 examples)
- **CI Integration**: All examples execute successfully in automated CI pipeline

### Parallelization Potential

All 5 examples are **fully independent** and can be implemented in parallel:
- No shared state or dependencies between examples
- Common infrastructure (helper scripts, test harnesses) can be scaffolded first
- Each example has a dedicated worktree and implementation agent

**Timeline**: 
- Sequential: 5 person-days
- Parallel (5 agents): 1-2 days wall-clock time

---

## Context & Requirements

### Reference Specification

From `/Users/rand/src/ananke/docs/specs/phase8-e2e-integration.md` (lines 808-1407):

**Objective**: Demonstrate real-world value with 5 complete, documented examples covering diverse use cases.

**Requirements**:
1. Each example must run in <10 minutes from fresh clone
2. Include comprehensive README with setup, usage, customization
3. Provide realistic input fixtures (not toy examples)
4. Generate validated output with included test suite
5. Cover both TypeScript and Python (3 TS minimum, 2 Python minimum)
6. Execute successfully in CI without manual intervention

### Existing Tutorial Examples (For Contrast)

Current examples (`/Users/rand/src/ananke/examples/01-05`) are **educational**:
- Focus: Teaching Ananke concepts (extraction, analysis, DSL, pipeline)
- Scope: Narrow, single-concept demonstrations
- Runtime: 50-200ms, no generation step (extraction/compilation only)
- Audience: Developers learning Ananke

Phase 8c examples are **production-oriented**:
- Focus: Demonstrating business value and ROI
- Scope: Complete workflows with real-world complexity
- Runtime: <10 minutes including full generation
- Audience: Developers evaluating Ananke for adoption

### Directory Structure

```
examples/production/
├── README.md                           # Production examples overview
├── common/
│   ├── test_helpers.zig               # Shared test utilities
│   ├── validation.zig                 # Output validation helpers
│   └── scripts/
│       ├── openapi_to_constraints.py  # OpenAPI → constraints converter
│       └── schema_diff.py             # Database schema diff tool
├── 01-openapi-route-generation/
│   ├── README.md
│   ├── run.sh                         # One-command execution
│   ├── input/
│   │   ├── openapi.yaml
│   │   └── existing_routes.ts
│   ├── constraints/
│   │   ├── extracted.json
│   │   └── api_constraints.json
│   ├── output/
│   │   └── generated_routes.ts        # Generated code
│   ├── tests/
│   │   ├── test_generated.ts          # Validation tests
│   │   └── helpers.ts
│   └── package.json                   # TypeScript dependencies
├── 02-database-migration-generator/
├── 03-react-component-generator/
├── 04-cli-tool-generator/
└── 05-test-generator/
```

---

## Example Architecture

### Common Pattern (All Examples)

Each example follows a consistent 4-phase workflow:

```bash
#!/bin/bash
# run.sh template

set -e

echo "=== Example N: [Title] ==="
echo ""

# Phase 1: Extract constraints from existing code
echo "1/4 Extracting constraints from existing code..."
ananke extract input/existing_code.ext \
  --language [typescript|python] \
  -o constraints/extracted.json

# Phase 2: Merge with domain-specific constraints (optional)
echo "2/4 Merging with domain constraints..."
[domain-specific script] \
  input/spec.yaml \
  constraints/extracted.json \
  -o constraints/merged.json

# Phase 3: Generate new code
echo "3/4 Generating code..."
ananke generate "[generation prompt]" \
  --constraints constraints/merged.json \
  --max-tokens [appropriate size] \
  -o output/generated.[ext]

# Phase 4: Validate output
echo "4/4 Validating generated code..."
[test command]

echo ""
echo "✓ Complete! See output/generated.[ext]"
```

### File Manifest Template

Every example includes:

1. **README.md** (required)
   - Overview and value proposition
   - Prerequisites and setup
   - Quick start (run.sh)
   - Step-by-step guide
   - Expected output
   - Customization guide
   - Troubleshooting

2. **run.sh** (required)
   - Executable script with clear phases
   - Error handling (set -e)
   - Progress indicators
   - Success/failure messages

3. **input/** (required)
   - Realistic sample files (not toy examples)
   - Existing code demonstrating patterns
   - Specifications or schemas

4. **constraints/** (generated)
   - extracted.json (from input code)
   - [domain]_constraints.json (merged)

5. **output/** (generated)
   - generated_[artifact].[ext]
   - Should pass validation tests

6. **tests/** (required)
   - Validation tests for generated code
   - Test helpers if needed
   - Expected to pass on first run

7. **package.json or requirements.txt** (language-specific)
   - Dependencies for tests/validation
   - Minimal, production-quality deps


## Implementation Breakdown

### Example 1: OpenAPI Route Generation

**Priority**: P0 (Must Have)  
**Language**: TypeScript  
**Complexity**: Medium (3-4 hours)  
**Value Prop**: Eliminates route boilerplate, ensures API spec compliance, reduces manual errors

#### Use Case

Generate Express.js API routes from OpenAPI 3.0 specifications with:
- Automatic request validation (path params, query params, body)
- Type-safe response handling
- Consistent error patterns
- OpenAPI spec compliance

#### Files to Create

```
examples/production/01-openapi-route-generation/
├── README.md                          # 200-300 lines, comprehensive guide
├── run.sh                             # 50 lines, 4-phase execution
├── input/
│   ├── openapi.yaml                   # 100 lines, realistic User API spec
│   └── existing_routes.ts             # 50 lines, example /products route
├── constraints/
│   └── .gitkeep                       # Generated files go here
├── output/
│   └── .gitkeep                       # Generated route goes here
├── tests/
│   ├── test_generated.ts              # 80 lines, comprehensive validation
│   └── helpers.ts                     # 40 lines, OpenAPI compliance checker
├── scripts/
│   └── openapi_to_constraints.py      # 150 lines, converts OpenAPI → constraints
└── package.json                       # vitest, typescript, express types
```

#### Input: OpenAPI Spec (Abbreviated)

```yaml
openapi: 3.0.0
info:
  title: User API
paths:
  /users/{id}:
    get:
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: integer
            minimum: 1
      responses:
        '200':
          description: User found
        '404':
          description: User not found
```

#### Implementation Steps

1. Create directory structure (5 min)
2. Write README.md (30 min) - comprehensive guide
3. Create input fixtures (20 min) - openapi.yaml + existing_routes.ts
4. Write openapi_to_constraints.py (45 min) - converts spec to constraints
5. Create run.sh (20 min) - orchestrates 4 phases
6. Write validation tests (40 min) - test_generated.ts + helpers.ts
7. Create package.json (5 min) - dependencies
8. Test end-to-end (30 min) - ensure run.sh works
9. Iterate on quality (30 min) - refine README, edge cases

**Total**: ~3.5 hours

---

### Example 2: Database Migration Generator

**Priority**: P0 (Must Have)  
**Language**: SQL + TypeScript  
**Complexity**: Medium (3-4 hours)  
**Value Prop**: Ensures schema consistency, prevents migration errors, automates repetitive SQL

#### Use Case

Generate type-safe database migration scripts from schema changes with:
- Up/down migrations
- Automatic rollback support
- Index creation
- Type-safe column definitions
- Timestamp metadata

#### Files to Create

```
examples/production/02-database-migration-generator/
├── README.md
├── run.sh
├── input/
│   ├── schema_v1.sql                  # Current schema
│   ├── existing_migrations/           # Example migrations showing pattern
│   │   ├── 001_initial_schema.sql
│   │   └── 002_add_users_index.sql
│   └── change_request.txt             # Desired schema changes
├── constraints/
│   └── .gitkeep
├── output/
│   └── .gitkeep                       # migration_003.sql generated here
├── tests/
│   ├── test_migration.ts              # Validates up/down work correctly
│   └── helpers.ts                     # SQL parsing and validation
├── scripts/
│   └── schema_diff.py                 # Compares schemas, generates constraints
└── package.json                       # pg, vitest for testing
```

#### Implementation Steps

1. Create directory structure (5 min)
2. Write README.md (30 min)
3. Create input fixtures (25 min) - schema + migrations + change request
4. Write schema_diff.py (60 min) - parses SQL, generates constraints
5. Create run.sh (20 min)
6. Write validation tests (45 min)
7. Create package.json (5 min)
8. Test end-to-end (30 min)
9. Refine quality (30 min)

**Total**: ~4 hours

---

### Example 3: React Component Generator

**Priority**: P1 (Should Have)  
**Language**: TypeScript + React  
**Complexity**: Medium-High (4-5 hours)  
**Value Prop**: Enforces accessibility best practices, reduces boilerplate, ensures design system consistency

#### Use Case

Generate React components with:
- TypeScript interfaces
- Accessibility attributes (ARIA, semantic HTML)
- Design system integration
- Prop validation
- Component tests

#### Files to Create

```
examples/production/03-react-component-generator/
├── README.md
├── run.sh
├── input/
│   ├── Button.tsx                     # Example component showing pattern
│   ├── design_system.json             # Design tokens (colors, spacing)
│   └── component_spec.md              # Request for new Input component
├── constraints/
│   └── .gitkeep
├── output/
│   └── .gitkeep                       # Input.tsx generated here
├── tests/
│   ├── test_generated.tsx             # Component tests
│   ├── accessibility.test.tsx         # ARIA compliance tests
│   └── helpers.tsx
├── scripts/
│   └── design_tokens_to_constraints.py
└── package.json                       # react, @testing-library/react, vitest
```

#### Implementation Steps

1. Create directory structure (5 min)
2. Write README.md (35 min)
3. Create input fixtures (30 min) - Button.tsx, spec, design tokens
4. Write design_tokens_to_constraints.py (40 min)
5. Create run.sh (20 min)
6. Write validation tests (60 min) - component + accessibility tests
7. Create package.json (5 min)
8. Test end-to-end (35 min)
9. Refine quality (30 min)

**Total**: ~4.5 hours

---

### Example 4: CLI Tool Generator

**Priority**: P1 (Should Have)  
**Language**: Python  
**Complexity**: Medium (3-4 hours)  
**Value Prop**: Consistent CLI patterns, automatic help generation, robust error handling

#### Use Case

Generate Python CLI tools using Click with:
- Argument and option parsing
- Help text generation
- Input validation
- Error handling
- Output formatting

#### Files to Create

```
examples/production/04-cli-tool-generator/
├── README.md
├── run.sh
├── input/
│   ├── existing_cli.py                # Example Click CLI showing pattern
│   └── command_spec.md                # Specification for validate command
├── constraints/
│   └── .gitkeep
├── output/
│   └── .gitkeep                       # validate_command.py generated here
├── tests/
│   ├── test_generated.py              # CLI behavior tests
│   └── helpers.py
└── requirements.txt                   # click, pytest
```

#### Implementation Steps

1. Create directory structure (5 min)
2. Write README.md (30 min)
3. Create input fixtures (20 min) - existing_cli.py, command_spec.md
4. Create run.sh (15 min)
5. Write validation tests (45 min)
6. Create requirements.txt (5 min)
7. Test end-to-end (30 min)
8. Refine quality (30 min)

**Total**: ~3 hours

---

### Example 5: Test Generator from Specification

**Priority**: P0 (Must Have)  
**Language**: Python  
**Complexity**: Medium (3-4 hours)  
**Value Prop**: Ensures test coverage, reduces test writing time, enforces testing patterns

#### Use Case

Generate comprehensive pytest test suites from function docstrings with:
- Edge case coverage
- Error condition tests
- Parametrized tests
- Type checking
- Documentation

#### Files to Create

```
examples/production/05-test-generator/
├── README.md
├── run.sh
├── input/
│   ├── function_spec.py               # Function with comprehensive docstring
│   └── existing_tests.py              # Example tests showing patterns
├── constraints/
│   └── .gitkeep
├── output/
│   └── .gitkeep                       # test_calculate_discount.py generated
├── tests/
│   ├── test_generated_tests.py        # Meta-test: validate generated tests
│   └── helpers.py
└── requirements.txt                   # pytest
```

#### Implementation Steps

1. Create directory structure (5 min)
2. Write README.md (30 min)
3. Create input fixtures (25 min) - function_spec.py, existing_tests.py
4. Create run.sh (15 min)
5. Write validation tests (40 min)
6. Create requirements.txt (5 min)
7. Test end-to-end (30 min)
8. Refine quality (30 min)

**Total**: ~3 hours

---

## Parallel Execution Strategy

### Independence Analysis

All 5 examples are **fully independent**:

| Example | Dependencies | Shared Resources | Can Parallelize? |
|---------|-------------|------------------|------------------|
| 01-openapi | None | common/scripts/openapi_to_constraints.py | Yes |
| 02-database | None | common/scripts/schema_diff.py | Yes |
| 03-react | None | common/scripts/design_tokens_to_constraints.py | Yes |
| 04-cli | None | common/test_helpers.py (optional) | Yes |
| 05-test | None | common/test_helpers.py (optional) | Yes |

**Shared Infrastructure** (create first):
- `examples/production/README.md` (overview)
- `examples/production/common/` directory (optional helpers)

**Parallelization Strategy**:

1. **Phase 0: Scaffold** (30 min, single agent)
   - Create `examples/production/` directory
   - Create `examples/production/README.md`
   - Create `examples/production/common/` with placeholder files
   - Commit scaffold

2. **Phase 1: Parallel Implementation** (1-2 days wall-clock, 5 agents)
   - Agent 1: Example 01 (OpenAPI) - 3.5 hours
   - Agent 2: Example 02 (Database) - 4 hours
   - Agent 3: Example 03 (React) - 4.5 hours
   - Agent 4: Example 04 (CLI) - 3 hours
   - Agent 5: Example 05 (Test) - 3 hours
   
   Each agent works in its own worktree:
   ```bash
   git worktree add ../example-01-openapi feature/example-01-openapi
   git worktree add ../example-02-database feature/example-02-database
   git worktree add ../example-03-react feature/example-03-react
   git worktree add ../example-04-cli feature/example-04-cli
   git worktree add ../example-05-test feature/example-05-test
   ```

3. **Phase 2: Integration** (30 min, single agent)
   - Merge all branches
   - Create CI workflow for production examples
   - Update main README.md with production examples section
   - Smoke test all 5 examples

### Worktree Management

```bash
# Setup (run once)
git worktree add ../example-01-openapi -b feature/example-01-openapi
git worktree add ../example-02-database -b feature/example-02-database
git worktree add ../example-03-react -b feature/example-03-react
git worktree add ../example-04-cli -b feature/example-04-cli
git worktree add ../example-05-test -b feature/example-05-test

# Each agent works in isolation
cd ../example-01-openapi
# ... implement ...
git commit -m "Add OpenAPI route generation example"
git push origin feature/example-01-openapi

# Cleanup (after merge)
git worktree remove ../example-01-openapi
git branch -d feature/example-01-openapi
```

---

## Implementation Order

### Priority Tiers

**P0 (Must Have)** - Critical for Phase 8c acceptance:
1. Example 01: OpenAPI Route Generation (TypeScript)
2. Example 02: Database Migration Generator (SQL/TypeScript)
3. Example 05: Test Generator (Python)

**P1 (Should Have)** - Important for demonstrating breadth:
4. Example 03: React Component Generator (TypeScript/React)
5. Example 04: CLI Tool Generator (Python)

### Sequential Implementation Order

If implementing sequentially (1 agent):

1. **Example 05: Test Generator** (3 hours) - Simplest, establishes pattern
2. **Example 01: OpenAPI Route** (3.5 hours) - Core TypeScript example
3. **Example 04: CLI Tool** (3 hours) - Second Python example
4. **Example 02: Database Migration** (4 hours) - More complex constraints
5. **Example 03: React Component** (4.5 hours) - Most complex (UI + accessibility)

**Rationale**: Start simple to establish patterns, alternate languages for variety, save most complex for last when patterns are well-established.

### Parallel Implementation Order

If implementing in parallel (5 agents):

**Start simultaneously**:
- All 5 examples can begin at the same time
- Each agent follows their example's implementation steps
- No synchronization needed until final integration

**Merge order** (doesn't matter, but suggestion):
1. Example 05 (simplest, good first merge)
2. Example 01 (core TypeScript example)
3. Example 04 (core Python example)
4. Example 02 (SQL complexity)
5. Example 03 (most complex)

---

## Acceptance Criteria

### Per-Example Criteria

Each example must:

1. **Completeness**
   - [ ] README.md exists (200+ lines, comprehensive)
   - [ ] run.sh exists and is executable
   - [ ] Input fixtures are realistic (not toy examples)
   - [ ] Output directory contains .gitkeep
   - [ ] Constraints directory contains .gitkeep
   - [ ] Tests directory contains validation tests
   - [ ] Language-specific dependency file exists (package.json or requirements.txt)

2. **Functionality**
   - [ ] `./run.sh` executes without errors
   - [ ] Generates expected output files
   - [ ] Validation tests pass on first run
   - [ ] Completes in <10 minutes from git clone

3. **Quality**
   - [ ] README includes clear setup instructions
   - [ ] README explains value proposition
   - [ ] README has troubleshooting section
   - [ ] Generated code follows best practices
   - [ ] Tests cover edge cases and error conditions

4. **Documentation**
   - [ ] Step-by-step guide in README
   - [ ] Expected output documented
   - [ ] Customization guide included
   - [ ] Prerequisites clearly listed

### Overall Phase 8c Criteria

1. **Coverage**
   - [ ] 5 examples total
   - [ ] At least 3 TypeScript examples
   - [ ] At least 2 Python examples
   - [ ] Diverse use cases (API, DB, UI, CLI, Testing)

2. **Integration**
   - [ ] `examples/production/README.md` provides overview
   - [ ] All examples listed in main project README
   - [ ] CI workflow validates all examples
   - [ ] Examples pass in CI without manual intervention

3. **Usability**
   - [ ] Each example has <10 minute setup time
   - [ ] Clear progression from simple to complex
   - [ ] Real-world applicability demonstrated
   - [ ] Value proposition clearly articulated

---

## Testing Strategy

### Per-Example Testing

Each example includes 3 levels of tests:

1. **Syntax Validation** (fast, <1s)
   ```bash
   # TypeScript examples
   npx tsc --noEmit output/generated.ts
   
   # Python examples
   python -m py_compile output/generated.py
   ```

2. **Functional Tests** (medium, 5-30s)
   ```bash
   # Run included test suite
   npm test  # or pytest
   ```

3. **End-to-End Smoke Test** (slow, 1-10 min)
   ```bash
   # Run the full example
   ./run.sh
   ```

### CI Integration

Create `.github/workflows/production-examples.yml` with jobs for each example:

```yaml
name: Production Examples

on:
  push:
    paths:
      - 'examples/production/**'
  pull_request:
    paths:
      - 'examples/production/**'

jobs:
  example-01-openapi:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - name: Run Example 01
        run: |
          cd examples/production/01-openapi-route-generation
          npm install
          ./run.sh
          npm test
  
  # Similar jobs for examples 02-05
```

### Manual Testing Checklist

Before marking Phase 8c complete:

- [ ] Clone fresh repo
- [ ] Run each example from scratch
- [ ] Verify <10 minute setup time
- [ ] Check generated output quality
- [ ] Validate all tests pass
- [ ] Review README clarity
- [ ] Test customization instructions
- [ ] Verify value proposition is clear

---

## Common Infrastructure

### Shared Helper Scripts

Create these in `examples/production/common/scripts/`:

1. **openapi_to_constraints.py** (150 lines)
   - Parses OpenAPI YAML
   - Extracts parameter types, validation rules
   - Merges with extracted constraints
   - Outputs unified constraint JSON

2. **schema_diff.py** (120 lines)
   - Compares two SQL schema files
   - Identifies added/removed/modified columns
   - Generates constraint representation
   - Used by Example 02

3. **design_tokens_to_constraints.py** (100 lines)
   - Reads design system JSON (colors, spacing, etc.)
   - Converts to constraints format
   - Used by Example 03

### Shared Test Utilities

Create in `examples/production/common/`:

1. **test_helpers.zig** (optional, 50 lines)
   - Common assertion helpers
   - File comparison utilities
   - Output validation functions

2. **validation.zig** (optional, 50 lines)
   - Syntax validation wrappers
   - Test runner helpers

**Note**: These are optional - examples should be self-contained. Only create if multiple examples need identical logic.

---

## Appendices

### Appendix A: README Template

Every example README should follow this structure:

```markdown
# Example N: [Title]

## Overview

[2-3 sentences describing what this example demonstrates and why it's valuable]

## Value Proposition

**Problem**: [What problem does this solve?]
**Solution**: [How does Ananke help?]
**ROI**: [Quantify time saved, errors prevented, or consistency gained]

## Prerequisites

- Node.js 18+ / Python 3.11+ (depending on example)
- Zig 0.15.1+ (for Ananke CLI)
- [Any other dependencies]
- **Setup Time**: <10 minutes

## Quick Start

```bash
cd examples/production/0N-example-name
./run.sh
```

## Step-by-Step Guide

### 1. Input Preparation

[Explain the input files and what they represent]

### 2. Constraint Extraction

[How constraints are extracted from existing code]

```bash
ananke extract input/existing_code.ext \
  --language [lang] \
  -o constraints/extracted.json
```

### 3. Domain Constraint Merging (Optional)

[How domain-specific constraints are added]

### 4. Code Generation

[How to trigger generation with appropriate prompt]

```bash
ananke generate "[prompt]" \
  --constraints constraints/merged.json \
  -o output/generated.ext
```

### 5. Validation

[How to validate the generated code]

```bash
npm test  # or pytest
```

## Expected Output

[Show what the generated code should look like with annotations]

## Customization

### Adapt for Your Use Case

1. **Replace input files** with your own specs/schemas
2. **Modify constraints** to match your patterns
3. **Adjust generation prompt** for your requirements
4. **Extend validation tests** for your edge cases

### Example Modifications

[Specific examples of how to customize]

## Troubleshooting

### Issue: [Common problem 1]

**Symptoms**: [What you see]
**Cause**: [Why it happens]
**Solution**: [How to fix]

### Issue: [Common problem 2]

...

## Next Steps

- Try customizing the input for your use case
- Explore [related example]
- Read [relevant documentation]

## Learn More

- [Link to Ananke docs]
- [Link to relevant API docs]
- [Link to related examples]
```

---

### Appendix B: run.sh Template

```bash
#!/bin/bash
# Example N: [Title]
# Demonstrates: [Brief description]

set -e  # Exit on error

# Color output helpers
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "========================================="
echo "Example N: [Title]"
echo "========================================="
echo ""

# Check prerequisites
echo -e "${BLUE}Checking prerequisites...${NC}"
if ! command -v ananke &> /dev/null; then
    echo -e "${RED}Error: ananke CLI not found${NC}"
    echo "Please install Ananke first: cd ../../ && zig build"
    exit 1
fi

# Phase 1: Extract constraints
echo ""
echo -e "${BLUE}[1/4] Extracting constraints from existing code...${NC}"
ananke extract input/existing_code.ext \
  --language [lang] \
  -o constraints/extracted.json
echo -e "${GREEN}✓ Extracted constraints${NC}"

# Phase 2: Merge domain constraints (if applicable)
echo ""
echo -e "${BLUE}[2/4] Merging with domain constraints...${NC}"
python ../common/scripts/[script].py \
  input/spec.yaml \
  constraints/extracted.json \
  -o constraints/merged.json
echo -e "${GREEN}✓ Merged constraints${NC}"

# Phase 3: Generate code
echo ""
echo -e "${BLUE}[3/4] Generating code...${NC}"
ananke generate "[generation prompt]" \
  --constraints constraints/merged.json \
  --max-tokens [appropriate size] \
  -o output/generated.ext
echo -e "${GREEN}✓ Generated code${NC}"

# Phase 4: Validate
echo ""
echo -e "${BLUE}[4/4] Validating generated code...${NC}"
[test command]
echo -e "${GREEN}✓ Validation passed${NC}"

# Success message
echo ""
echo "========================================="
echo -e "${GREEN}✓ Example complete!${NC}"
echo "========================================="
echo ""
echo "Generated code: output/generated.ext"
echo "Validation tests: tests/"
echo ""
echo "Next steps:"
echo "  - Review the generated code"
echo "  - Try customizing the input"
echo "  - Read the full README.md"
```

---

### Appendix C: Estimated Timeline

**Sequential Implementation** (1 engineer):

| Day | Morning (4h) | Afternoon (4h) | Total |
|-----|-------------|---------------|-------|
| 1 | Scaffold + Ex 05 (3h) | Ex 05 complete + Ex 01 start (1.5h) | 8h |
| 2 | Ex 01 complete (2h) + Ex 04 start (2h) | Ex 04 complete (1h) + Ex 02 start (3h) | 8h |
| 3 | Ex 02 complete (1h) + Ex 03 start (3h) | Ex 03 complete (1.5h) + Integration (0.5h) | 5h |

**Total**: 21 hours = 2.6 days

**Parallel Implementation** (5 engineers):

| Time | Activity | Duration |
|------|----------|----------|
| T+0h | Scaffold (1 engineer) | 30 min |
| T+0.5h | All 5 examples start (5 engineers) | 4-5 hours |
| T+5h | Integration (1 engineer) | 30 min |

**Total Wall-Clock**: 6 hours (can be split across 2 days)

---

### Appendix D: File Manifest Summary

**Example 1: OpenAPI Route Generation**
- Files: 10 (README, run.sh, 2 input, 2 constraints, 1 output, 3 tests, 1 package.json)
- Lines: ~650 total
- Key Script: openapi_to_constraints.py (150 lines)

**Example 2: Database Migration Generator**
- Files: 12 (README, run.sh, 4 input, 2 constraints, 1 output, 2 tests, 1 package.json, 1 script)
- Lines: ~700 total
- Key Script: schema_diff.py (120 lines)

**Example 3: React Component Generator**
- Files: 11 (README, run.sh, 3 input, 2 constraints, 1 output, 3 tests, 1 package.json, 1 script)
- Lines: ~750 total
- Key Script: design_tokens_to_constraints.py (100 lines)

**Example 4: CLI Tool Generator**
- Files: 9 (README, run.sh, 2 input, 2 constraints, 1 output, 2 tests, 1 requirements.txt)
- Lines: ~600 total
- Key Script: None (uses common helpers)

**Example 5: Test Generator**
- Files: 9 (README, run.sh, 2 input, 2 constraints, 1 output, 2 tests, 1 requirements.txt)
- Lines: ~550 total
- Key Script: None (uses common helpers)

**Total Deliverables**:
- Files: 51
- Lines of Code: ~3,250
- Helper Scripts: 3 (370 lines)
- README Documentation: ~1,200 lines

---

### Appendix E: Quality Checklist

Before marking each example complete:

**Functional Requirements**:
- [ ] Executes `./run.sh` successfully
- [ ] Generates expected output
- [ ] All validation tests pass
- [ ] Completes in <10 minutes
- [ ] Works on fresh clone without manual setup

**Documentation Requirements**:
- [ ] README is comprehensive (200+ lines)
- [ ] Value proposition is clear
- [ ] Prerequisites are listed
- [ ] Step-by-step guide is included
- [ ] Expected output is documented
- [ ] Customization instructions exist
- [ ] Troubleshooting section included

**Code Quality**:
- [ ] Generated code follows best practices
- [ ] Tests cover edge cases
- [ ] Error handling is robust
- [ ] No hardcoded paths or secrets
- [ ] Comments explain non-obvious logic

**Integration Requirements**:
- [ ] Listed in production examples README
- [ ] CI job configured
- [ ] Passes CI without manual intervention
- [ ] No conflicts with other examples

---

## Summary

Phase 8c delivers 5 production-ready examples that demonstrate Ananke's practical value across diverse real-world use cases. Each example is complete, runnable in <10 minutes, and showcases a different application domain.

### Key Success Factors

1. **Examples are production-oriented**, not educational toys
2. **Complete documentation** enables immediate adoption
3. **Realistic input** demonstrates practical applicability
4. **Comprehensive tests** ensure correctness and reliability
5. **Parallel implementation** enables rapid delivery

### Implementation Roadmap

**Phase 0: Scaffold** (30 min)
- Create directory structure
- Write overview README
- Set up common infrastructure

**Phase 1: Parallel Implementation** (1-2 days wall-clock)
- 5 agents work independently in separate worktrees
- Each implements their assigned example
- No coordination needed during implementation

**Phase 2: Integration** (30 min)
- Merge all branches
- Configure CI
- Smoke test all examples
- Update main documentation

### Next Actions

1. **Review this specification** - Approve or request changes
2. **Create scaffold** - Set up directory structure and overview README
3. **Delegate to agents** - Assign one example per agent with worktree
4. **Implement in parallel** - All 5 examples simultaneously
5. **Integrate and validate** - Merge, test, and document

### Expected Outcome

After Phase 8c:
- Developers can evaluate Ananke with realistic examples
- Production use cases are well-documented
- ROI is clearly demonstrated
- Adoption friction is minimized
- Real-world value is proven

This specification provides everything needed to implement Phase 8c with confidence, whether sequentially or in parallel.

---

**End of Specification**
