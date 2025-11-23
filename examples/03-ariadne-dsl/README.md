# Example 03: Ariadne DSL

This example demonstrates defining constraints using Ariadne, Ananke's domain-specific language for constraint specification.

## What This Example Shows

- **Declarative constraints**: Define what you want, not how to extract it
- **Composable modules**: Build libraries of reusable constraint definitions
- **Multiple constraint types**: Security, type safety, performance
- **Version control friendly**: Track constraint changes in git
- **Equivalent JSON output**: See how DSL compiles to ConstraintIR

## Files

- `api_security.ariadne` - Security constraints for REST APIs
- `type_safety.ariadne` - Type system requirements
- `performance.ariadne` - Performance budgets and limits
- `main.zig` - Example program showing DSL usage
- `build.zig` - Build configuration
- `build.zig.zon` - Dependencies

## Building and Running

```bash
# From this directory
zig build run

# Or from the ananke root
cd examples/03-ariadne-dsl
zig build run
```

## Ariadne Language Features

### Constraint Definition

```ariadne
constraint no_dangerous_operations {
    id: "security-001",
    name: "no_dangerous_operations",

    enforcement: .Structural({
        pattern: query(javascript) {
            (call_expression
                function: (identifier) @fn
                where @fn in ["eval", "exec", "Function"]
            )
        },
        action: .Forbid
    }),

    failure_mode: .HardBlock,

    provenance: {
        source: .ManualPolicy,
        confidence_score: 1.0
    }
}
```

### Tree-sitter Queries

Embed tree-sitter patterns directly:

```ariadne
pattern: query(javascript) {
    (call_expression
        function: (member_expression
            object: (identifier) @obj
            property: (property_identifier) @method
        )
    )
    where @obj == "db" and @method == "query"
}
```

### Multiple Enforcement Types

**Structural** (pattern matching):
```ariadne
enforcement: .Structural({
    pattern: query(...),
    action: .Forbid
})
```

**Type-based** (type system):
```ariadne
enforcement: .Type({
    signature: {
        functions: {
            "handler": fn(ValidatedRequest) -> Response
        }
    }
})
```

**Semantic** (behavioral):
```ariadne
enforcement: .Semantic({
    property: .Performance({
        constraints: { max_time_ms: 200 }
    }),
    method: .RuntimeMonitoring
})
```

**Syntactic** (grammar):
```ariadne
enforcement: .Syntactic({
    grammar: """
        function = "function" identifier params ":" type "{" body "}"
    """
})
```

### Failure Modes

**HardBlock**: Completely prevent invalid code
```ariadne
failure_mode: .HardBlock
```

**AutoFix**: Attempt automatic repair
```ariadne
failure_mode: .AutoFix({
    repair_strategy: .Synthesize,
    max_attempts: 3
})
```

**SoftWarn**: Allow with warning
```ariadne
failure_mode: .SoftWarn({
    warning_message: "Consider refactoring",
    allow_override: true
})
```

### Repair Strategies

Define how to fix violations:

```ariadne
repair: {
    method: .Rewrite,
    template: """
        // Use parameterized queries
        db.query('SELECT * FROM users WHERE id = ?', [userId])
    """
}
```

### Modules and Imports

Organize constraints into modules:

```ariadne
module api.security

import std.{clew, braid}

// Define constraints...

pub const api_security_constraints = [
    no_dangerous_operations,
    require_input_validation,
    // ...
]
```

### Compilation

Compile constraints to ConstraintIR:

```ariadne
pub fn compile() -> ConstraintIR {
    let graph = braid.graph.new()

    for constraint in api_security_constraints {
        graph.add_node(constraint)
    }

    // Add dependencies
    graph.add_dependency(
        from: "require_input_validation",
        to: "prevent_sql_injection"
    )

    return graph.build({
        parallelization: .Parallel(4),
        failure_strategy: .FailFast
    })
}
```

## Example Constraints

### Security

**No Dangerous Operations**
- Forbids `eval()`, `exec()`, `Function()`
- HardBlock - no exceptions

**SQL Injection Prevention**
- Detects string interpolation in SQL queries
- AutoFix - rewrites to use parameterized queries

**Input Validation**
- Requires validated input for all endpoints
- AutoFix - synthesizes validation code

### Type Safety

**No 'any' Types**
- Forbids TypeScript `any` and `unknown`
- AutoFix - infers specific types

**Null Safety**
- Requires null checks before use
- AutoFix - adds null guards

**Explicit Return Types**
- Functions must declare return types
- SoftWarn - allows override with justification

### Performance

**Complexity Limit**
- Cyclomatic complexity <= 10
- SoftWarn - can override with justification

**Response Time**
- API endpoints must respond in < 200ms (p95)
- Monitored at runtime

**No Sync I/O**
- Forbids synchronous file operations in async code
- AutoFix - converts to async equivalents

## Compilation Output

Ariadne compiles to ConstraintIR (JSON):

```json
{
  "version": "1.0.0",
  "nodes": {
    "security-001": {
      "name": "no_dangerous_operations",
      "enforcement": { "type": "Structural", ... },
      "failure_mode": "HardBlock"
    }
  },
  "adjacency": {
    "security-001": ["type-001"]
  }
}
```

## Benefits of Ariadne

### vs. Static Extraction
- **More precise**: Define exactly what you want
- **No false positives**: Explicit rules
- **Portable**: Same DSL across languages

### vs. Claude Extraction
- **Faster**: No API calls
- **Deterministic**: Same input = same output
- **Free**: No per-request costs
- **Version controlled**: Track changes in git

### vs. JSON Configuration
- **Type-safe**: Compiler checks definitions
- **Expressive**: Rich DSL features
- **Composable**: Import and reuse modules
- **Readable**: Domain language, not JSON

## Use Cases

### Organization-Wide Policies

Define once, enforce everywhere:

```ariadne
// security-policy.ariadne
module company.security

constraint enforce_pci_dss {
    // ... PCI compliance rules
}

constraint enforce_gdpr {
    // ... GDPR requirements
}
```

### Project-Specific Rules

Extend base policies:

```ariadne
module myproject.constraints

import company.security.{enforce_pci_dss}
import company.types.{typescript_standards}

// Add project-specific constraints
constraint api_versioning {
    // ...
}
```

### Framework Constraints

Package constraints with frameworks:

```ariadne
module express.security

constraint helmet_middleware {
    // Require Helmet.js security headers
}

constraint csurf_protection {
    // CSRF protection required
}
```

## Integration with Other Tools

### With Clew (Extraction)

Combine extracted and manual constraints:

```zig
// Extract from codebase
const extracted = try clew.extractFromCode(source);

// Load Ariadne definitions
const manual = try ariadne.compile("constraints.ariadne");

// Merge both
const all_constraints = try merge(extracted, manual);
```

### With Braid (Compilation)

Ariadne output is ConstraintIR:

```zig
const ir = try ariadne.compile("api_security.ariadne");
const compiled = try braid.optimize(ir);
```

### With Maze (Generation)

Use for constrained generation:

```zig
const constraints = try ariadne.compile("constraints.ariadne");
const result = try maze.generate(intent, constraints);
```

## Current Status

Ariadne DSL specification is complete, but the parser/compiler is not yet implemented. This example shows:

- What the DSL looks like
- How it would be used
- What output it produces
- Benefits over alternatives

See `/ananke_documentation/ariadne_language_spec.md` for the full language specification.

## Next Steps

1. Implement Ariadne parser
2. Build constraint compiler
3. Add IDE support (LSP)
4. Create standard library of constraints
5. Integration with Maze for generation

## Related Examples

- Example 01: Static extraction (Clew alone)
- Example 02: Semantic extraction (Clew + Claude)
- Example 05: Mixed mode (Ariadne + JSON + extracted)

Ariadne provides the declarative, maintainable way to define constraints that complement automatic extraction.
