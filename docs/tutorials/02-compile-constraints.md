# Tutorial 2: Compile and Optimize Constraints

**Time**: 15 minutes  
**Level**: Intermediate  
**Outcome**: Learn constraint compilation, conflict detection, and optimization

---

## What is Constraint Compilation?

Raw constraints are just data. Before using them for code generation, Ananke must:

1. Build a **dependency graph** (which constraints depend on which)
2. Detect **conflicts** (contradictory constraints)
3. **Optimize** for fast validation
4. Compile to **ConstraintIR** (executable intermediate representation)

---

## Step 1: Create Sample Constraints

Save as `my-constraints.json`:

```json
{
  "project": "payment-service",
  "constraints": {
    "type_safety": {
      "forbid": ["any"],
      "require": ["explicit_returns", "type_annotations"]
    },
    "security": {
      "requires": ["authentication", "input_validation"],
      "forbid": ["eval", "exec"],
      "sql": "parameterized_only"
    },
    "performance": {
      "max_complexity": 10,
      "cache_required": true,
      "timeout_ms": 5000
    }
  }
}
```

## Step 2: Compile Constraints

Compile to optimized IR:

```bash
# Basic compilation
ananke compile my-constraints.json --output compiled.cir

# With analysis
ananke compile my-constraints.json \
  --output compiled.cir \
  --analyze \
  --verbose
```

**Output**: `compiled.cir` is now a machine-optimized representation.

## Step 3: Analyze Dependencies

See the constraint graph:

```bash
# View dependency analysis
ananke constraints analyze my-constraints.json

# Output shows:
# - Constraint dependencies
# - Conflicts (if any)
# - Optimization recommendations
```

## Step 4: Detect and Resolve Conflicts

Check for conflicting constraints:

```bash
# Validate for conflicts
ananke constraints validate my-constraints.json

# If conflicts exist, use Claude to resolve
ananke constraints validate my-constraints.json \
  --use-claude \
  --auto-resolve
```

## Step 5: Optimize Constraints

Optimize for fast validation:

```bash
# Compile with optimization
ananke compile my-constraints.json \
  --optimize \
  --output compiled.cir

# Check optimization report
ananke compile my-constraints.json \
  --optimize \
  --report optimization-report.json
```

## Step 6: Test Compiled Constraints

Verify the compiled constraints work:

```bash
# Create test code
cat > test_code.py << 'PYTHON'
def validate_payment(amount: int, card: str) -> bool:
    if not card:
        raise ValueError("Card required")
    if amount <= 0:
        raise ValueError("Amount must be positive")
    return True
PYTHON

# Check validation
ananke validate test_code.py --constraints compiled.cir
```

Output shows:

```
Validation Results
==================

File: test_code.py

Type Safety:
  ✓ No 'any' types found
  ✓ All functions have return types
  ✓ Parameters are type-annotated

Security:
  ✓ Input validation present
  ✓ No eval/exec found
  ✓ Error handling present

Performance:
  ✓ Complexity score: 6 (limit: 10)

Summary: All constraints satisfied
```

## Step 7: Combine Multiple Sources

Mix automatic extraction with manual constraints:

```bash
# Extract from existing code
ananke extract ./src --output extracted.json

# Create manual overrides
cat > overrides.json << 'OVERRIDE'
{
  "constraints": {
    "security": {
      "requires": ["rate_limiting"]
    }
  }
}
OVERRIDE

# Merge and compile
ananke constraints merge extracted.json overrides.json \
  --output merged.json

# Compile merged constraints
ananke compile merged.json --output final.cir
```

## Step 8: Export and Share

Share compiled constraints with your team:

```bash
# Export as documentation
ananke constraints export compiled.cir \
  --format markdown \
  --output CONSTRAINTS.md

# Commit to version control
git add compiled.cir CONSTRAINTS.md
git commit -m "Update constraints"
```

---

## Troubleshooting

### Compilation fails

**Problem**: "Constraint validation failed"

**Solution**:
```bash
# See detailed errors
ananke compile my-constraints.json --verbose

# Validate syntax
ananke constraints validate my-constraints.json
```

### Conflicts detected

**Problem**: "Conflicting constraints found"

**Solution**:
```bash
# Show conflicts
ananke constraints validate my-constraints.json --details

# Try auto-resolution
ananke constraints resolve my-constraints.json \
  --use-claude \
  --output resolved.json
```

---

**Next**: [Tutorial 3: Generate Code](03-generate-code.md)
