# Example 05: Mixed-Mode Constraints

This example demonstrates the most powerful pattern: combining extracted, JSON-configured, and DSL-defined constraints into a unified constraint system.

## What This Example Shows

- **Three constraint sources**: Extraction + JSON + Ariadne DSL
- **Composition**: How different constraint types work together
- **Layered approach**: Foundation → Configuration → Domain rules
- **Best practices**: When to use each approach
- **Real-world workflow**: Production-ready constraint management

## Files

- `sample.ts` - Payment handler with various patterns to extract
- `constraints.json` - JSON configuration for simple rules
- `custom.ariadne` - Domain-specific business logic in DSL
- `main.zig` - Program demonstrating mixed-mode composition
- `build.zig` - Build configuration
- `build.zig.zon` - Dependencies

## Building and Running

```bash
# From this directory
zig build run

# Or from the ananke root
cd examples/05-mixed-mode
zig build run
```

## The Three Sources

### 1. Extracted Constraints (Clew)

Automatically discovered from `sample.ts`:

- Function signatures with explicit types
- Interface definitions (StandardResponse, Payment)
- Error handling patterns (try-catch, error responses)
- Null safety (optional fields)
- Async/Promise patterns

**Characteristics:**
- Automatic, always up-to-date
- Reflects actual code patterns
- Good for consistency enforcement

### 2. JSON Configuration

From `constraints.json`:

**json-001: Environment Variables**
- Requires DATABASE_URL, REDIS_URL, API_KEY
- Simple structural check
- Soft warning if missing

**json-002: Error Logging Format**
- Enforces consistent error logging
- Forbids logging secrets
- Auto-fix available

**json-003: Test Coverage**
- Minimum 85% coverage
- Quality gate
- Soft warning

**Characteristics:**
- Simple and portable
- Easy to generate programmatically
- Language-agnostic

### 3. Ariadne DSL

From `custom.ariadne`:

**custom-001: Retry Logic**
- Database transactions must include retry
- Detects deadlock handling
- Auto-synthesizes retry wrapper

**custom-002: Standard Response**
- All handlers return StandardResponse<T>
- Type-safe enforcement
- Auto-fix for compliance

**custom-003: Payment Validation**
- Amount must be positive
- Maximum 2 decimal places
- Hard block on violation

**Characteristics:**
- Expressive and type-safe
- Rich query language
- Domain-specific rules

## Constraint Layers

Think of constraints as layers of a cake:

```
┌────────────────────────────────────┐
│  Layer 3: Domain Rules (Ariadne)  │  Business logic
│  - Retry patterns                  │  Company-specific
│  - Response formats                │  Domain knowledge
│  - Payment rules                   │
├────────────────────────────────────┤
│  Layer 2: Configuration (JSON)    │  Organizational
│  - Environment setup               │  Cross-project
│  - Logging standards               │  Policy enforcement
│  - Quality gates                   │
├────────────────────────────────────┤
│  Layer 1: Foundation (Extracted)   │  Automatic
│  - Type signatures                 │  Pattern discovery
│  - Error handling                  │  Consistency
│  - Code structure                  │
└────────────────────────────────────┘
```

All layers compile into a single ConstraintIR for enforcement.

## When to Use Each

### Use Extraction (Clew) When:

- Starting a new project and learning from existing code
- Want to maintain consistency automatically
- Need to discover implicit patterns
- Code is the source of truth

**Example:**
```zig
// Learn from existing codebase
const baseline = try clew.extractFromCode("src/", "typescript");
```

### Use JSON When:

- Simple configuration needed
- Generating constraints programmatically
- Integrating with other tools
- Need language-agnostic format

**Example:**
```json
{
  "id": "require-env-var",
  "enforcement": {
    "type": "Structural",
    "pattern": "process.env.DATABASE_URL"
  }
}
```

### Use Ariadne When:

- Complex business rules
- Query-based pattern matching
- Type-safe constraint definitions
- Building reusable constraint libraries

**Example:**
```ariadne
constraint require_retry_logic {
    enforcement: .Semantic({
        property: .Correctness({
            invariant: "Transactions must handle deadlocks"
        })
    })
}
```

## Composition Workflow

### Step 1: Extract Baseline

```zig
var clew = try Clew.init(allocator);
const extracted = try clew.extractFromCode(source, "typescript");
```

Gives you:
- Type signatures
- Structural patterns
- Implicit conventions

### Step 2: Add Configuration

```zig
const json_constraints = try loadJsonConstraints("constraints.json");
```

Adds:
- Environment requirements
- Logging standards
- Quality gates

### Step 3: Include Domain Rules

```zig
var ariadne = try Ariadne.init(allocator);
const dsl_constraints = try ariadne.compile("custom.ariadne");
```

Adds:
- Business logic
- Domain-specific validation
- Company policies

### Step 4: Merge Everything

```zig
var all_constraints = std.ArrayList(Constraint).init(allocator);
try all_constraints.appendSlice(extracted.constraints.items);
try all_constraints.appendSlice(json_constraints);
try all_constraints.appendSlice(dsl_constraints);
```

### Step 5: Compile to IR

```zig
var braid = try Braid.init(allocator);
const ir = try braid.compile(all_constraints.items);
```

Result: Single ConstraintIR with all rules.

### Step 6: Use in Generation

```zig
const result = try maze.generate(.{
    .intent = "Add refund endpoint",
    .constraints = ir,
});
```

Generated code satisfies all constraints from all sources.

## Real-World Example

### Scenario

Building a payment processing API with:
- Company security policies (JSON)
- Industry compliance rules (Ariadne)
- Existing code patterns (extracted)

### Setup

1. **Extract from existing payments code**:
   ```bash
   ananke extract src/payments/ --output baseline.json
   ```

2. **Define company policies**:
   ```json
   // company-policies.json
   {
     "nodes": {
       "security-logging": { ... },
       "rate-limiting": { ... }
     }
   }
   ```

3. **Add financial domain rules**:
   ```ariadne
   // financial-compliance.ariadne
   constraint pci_dss_logging { ... }
   constraint two_decimal_places { ... }
   ```

4. **Merge and use**:
   ```zig
   const all = try merge(baseline, company, financial);
   const ir = try braid.compile(all);
   const code = try maze.generate(intent, ir);
   ```

Result: Code that follows your patterns, company policies, AND industry regulations.

## Benefits

### Flexibility

Pick the right tool for each constraint:
- Simple rules → JSON
- Complex patterns → Ariadne
- Existing patterns → Extraction

### Maintainability

Different teams can own different layers:
- Developers: Extracted constraints
- Ops: JSON configuration
- Architects: Ariadne DSL

### Scalability

Build constraint libraries:
```
constraints/
├── extracted/
│   └── current.json          # Auto-generated
├── company/
│   ├── security.json
│   └── logging.json
└── domain/
    ├── payments.ariadne
    └── user-auth.ariadne
```

### Evolution

Constraints evolve with code:
- Extraction keeps up automatically
- JSON updates are simple
- Ariadne can be version controlled

## Common Patterns

### Pattern 1: Organizational Standards

```
Extracted (code patterns)
  + JSON (org policies)
  = Consistent, policy-compliant code
```

### Pattern 2: Domain Compliance

```
Extracted (existing code)
  + Ariadne (regulatory rules)
  = Industry-compliant generation
```

### Pattern 3: Full Stack

```
Extracted (patterns)
  + JSON (simple rules)
  + Ariadne (complex logic)
  = Complete constraint coverage
```

## Tips

### Start Simple

1. Begin with extraction only
2. Add JSON for obvious rules
3. Graduate to Ariadne for complex cases

### Avoid Duplication

Don't define the same constraint in multiple places:
- If Clew extracts it, don't duplicate in JSON
- If JSON covers it, don't repeat in Ariadne

### Layer Appropriately

- **Foundation (Extracted)**: Code structure, types
- **Configuration (JSON)**: Environment, tooling
- **Domain (Ariadne)**: Business rules, compliance

### Version Control

Track constraint changes:
```bash
git log constraints.json
git log custom.ariadne
git diff HEAD~1 constraints/
```

## Performance

### Extraction
- Fast: ~100ms for large files
- Cached: Repeated extractions instant

### JSON Loading
- Instant: Simple JSON parsing
- Small overhead

### Ariadne Compilation
- One-time: Compile at build time
- Cached: Store compiled IR

### Total Overhead
- First run: ~2 seconds
- Cached: < 100ms

Well worth it for comprehensive constraint coverage.

## Related Examples

- Example 01: Pure extraction (Clew)
- Example 02: Semantic analysis (Claude)
- Example 03: Pure DSL (Ariadne)
- Example 04: Full pipeline (when ready)

Mixed-mode is the recommended approach for production systems.

## Next Steps

Try building your own mixed-mode system:

1. Extract from your codebase
2. Add JSON for simple rules
3. Define domain rules in Ariadne
4. Compile and use for generation

This gives you the best of automatic discovery, simple configuration, and expressive domain rules.
