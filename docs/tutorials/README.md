# Ananke Tutorials

Learn Ananke step-by-step through hands-on tutorials.

## Tutorial Series

### 1. Extract Constraints (15 min)
**File**: `01-extract-constraints.md`

Learn how Clew automatically discovers constraints from your code.

- Extract from source files
- Understand constraint types
- View constraint reports
- Save constraints for later use

**Skills**: Basic constraint analysis, understanding patterns

---

### 2. Compile Constraints (15 min)
**File**: `02-compile-constraints.md`

Understand how constraints are compiled and optimized for generation.

- Compile constraints to IR
- Detect conflicting constraints
- Optimize for performance
- Test compiled constraints
- Combine multiple sources

**Skills**: Constraint optimization, conflict resolution

---

### 3. Generate Code (20 min)
**File**: `03-generate-code.md`

Generate code that respects all your constraints.

- Set up Modal service
- Create generation requests
- Validate generated code
- Iterate with feedback
- Handle errors gracefully

**Skills**: Code generation, constraint validation, debugging

---

### 4. Ariadne DSL (20 min)
**File**: `04-ariadne-dsl.md`

Write constraints using Ananke's high-level DSL.

- Ariadne syntax basics
- Write constraint rules
- Compose complex constraints
- Compile DSL to IR
- Compare with JSON approach

**Skills**: Constraint DSL, advanced constraint writing

---

### 5. Integration (20 min)
**File**: `05-integration.md`

Integrate Ananke into your development workflow.

- CI/CD pipeline setup
- Pre-commit hooks
- Code review automation
- Team workflows
- Production deployment

**Skills**: DevOps, team collaboration, automation

---

### 6. Understanding CLaSH Domains (20 min)
**File**: `06-clash-domains.md`

Explore the 5 CLaSH constraint domains and how they compose.

- Extract constraints and see their domain assignments
- Hard vs soft tiers in practice
- Cross-domain morphisms (Types ↔ Imports)
- Adaptive intensity levels
- How hole scale maps to constraint strength

**Skills**: CLaSH algebra, constraint composition, domain understanding

---

### 7. Fill-in-the-Middle for IDE Completions (15 min)
**File**: `07-fim-ide.md`

Use constrained FIM for IDE-quality code completions.

- Standard vs FIM completion
- Basic FIM via CLI
- Constraint-aware FIM with type context
- HoleScale variations
- IDE integration path

**Skills**: FIM constrained decoding, IDE integration, cursor-aware generation

---

## How to Use These Tutorials

### Quick Path (1 hour)
1. Complete Tutorial 1 (extract)
2. Complete Tutorial 2 (compile)
3. Skim Tutorial 3 (generate)

### Full Path (3 hours)
Complete all 7 tutorials in order.

### By Interest
- **Code Analysis**: Tutorials 1, 2
- **Code Generation**: Tutorials 1, 3
- **Advanced Use**: Tutorials 4, 5

---

### By Interest
- **CLaSH Deep Dive**: Tutorials 1, 2, 6
- **IDE Integration**: Tutorials 1, 7
- **Full Understanding**: All 7 tutorials

---

## Prerequisites

- Zig 0.15.2+ installed ([ziglang.org/download](https://ziglang.org/download/))
- Ananke built from source: `git clone --recurse-submodules ... && zig build`
- For generation: Modal account (free tier) or sglang endpoint
- 15-20 minutes per tutorial

---

## What You'll Learn

After all tutorials, you'll know:

- How to extract constraints from code
- How constraints enable safe generation
- How to generate code with confidence
- How to write custom constraints
- How to integrate into your workflow

---

## Getting Help

Stuck on a tutorial?

1. **Check Troubleshooting** section in the tutorial
2. **Read the User Guide** for more context
3. **Open GitHub issue** with your question
4. **Join Discord** for community help

---

**Start with [Tutorial 1: Extract Constraints](01-extract-constraints.md)**
