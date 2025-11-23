# Tutorial 4: Ariadne DSL - High-Level Constraints

**Time**: 20 minutes  
**Level**: Advanced  
**Outcome**: Write and compile constraints using Ananke's DSL

---

## What is Ariadne?

Ariadne is a domain-specific language for expressing constraints in a way that's closer to natural language while remaining precise and compilable.

Instead of writing JSON:

```json
{
  "security": {
    "requires": ["authentication", "input_validation"],
    "forbid": ["eval", "exec"]
  }
}
```

Write in Ariadne:

```ariadne
constraint secure_handlers {
    requires: authentication, input_validation;
    forbid: eval, exec;
}
```

---

## Step 1: Create an Ariadne Constraint File

Save as `.ananke/security.ariadne`:

```ariadne
# Security constraints for API handlers

constraint authentication_required {
    # All API endpoints require authentication
    requires: authentication;
    forbid: unprotected_endpoints;
    
    # Error handling
    on_violation: "reject";
    message: "All endpoints must require authentication";
}

constraint input_validation {
    # All user input must be validated
    requires: input_validation;
    forbid: unsafe_eval, dynamic_sql;
    
    # Timeout for validation
    max_time: 100ms;
    
    on_violation: "warn";  # or "reject", "suggest"
}

constraint rate_limiting {
    # Rate limiting required for all endpoints
    requires: rate_limiter;
    
    # Specific rules
    rules {
        anonymous: 100_per_hour;
        authenticated: 10000_per_hour;
    }
}
```

## Step 2: Learn Ariadne Syntax

### Basic Structure

```ariadne
constraint <name> {
    # Properties go here
}
```

### Common Properties

```ariadne
constraint example {
    # What must be present
    requires: auth, validation, logging;
    
    # What must not be present
    forbid: eval, exec, system_calls;
    
    # Performance bounds
    max_complexity: 10;
    max_tokens: 512;
    max_time: 1s;
    
    # Code patterns that must match
    pattern: "def .*validate.*:";
    
    # Error handling
    on_violation: "reject";  # or "warn", "suggest"
}
```

### Advanced Features

```ariadne
# Inheritance - extend existing constraints
constraint strict_security inherits authentication_required {
    # Add more requirements
    additional_requires: csrf_token;
}

# Composition - combine constraints
constraint api_endpoint {
    includes: authentication_required, input_validation, rate_limiting;
    
    # Can override
    forbid: pickle_dumps;
}

# Conditional rules
constraint payment_handler {
    requires: authentication;
    
    # If amount > 100, require additional checks
    if amount > 100 {
        requires: additional_verification;
    }
}
```

---

## Step 3: Organize Constraints

Create a constraint directory:

```bash
mkdir -p .ananke/constraints
```

Split constraints by category:

`.ananke/constraints/security.ariadne`:
```ariadne
constraint authentication {
    requires: auth;
    forbid: hardcoded_secrets;
}
```

`.ananke/constraints/performance.ariadne`:
```ariadne
constraint fast_queries {
    max_complexity: 10;
    requires: indexes;
    forbid: full_table_scans;
}
```

`.ananke/constraints/typing.ariadne`:
```ariadne
constraint strict_types {
    forbid: any, unknown;
    requires: explicit_types;
}
```

---

## Step 4: Compile Ariadne Constraints

```bash
# Compile single file
ananke compile .ananke/security.ariadne --output compiled.cir

# Compile entire directory
ananke compile .ananke/constraints/ --output compiled.cir

# With analysis
ananke compile .ananke/constraints/ \
  --output compiled.cir \
  --analyze \
  --verbose
```

---

## Step 5: Use Compiled Constraints

```bash
# Generate with DSL constraints
ananke generate "Add user endpoint" \
  --constraints compiled.cir \
  --max-tokens 400

# Validate code
ananke validate generated.py --constraints compiled.cir

# It works just like JSON constraints!
```

---

## Step 6: Mix Ariadne with JSON

Combine both approaches:

```bash
# Compile both
ananke compile .ananke/constraints/ manual.json \
  --output final.cir

# Ariadne + JSON in one command
ananke compile .ananke/*.ariadne ./constraints.json \
  --output final.cir
```

---

## Real-World Example

### Complete Constraint Set

`.ananke/api-service.ariadne`:

```ariadne
# API Service Constraints

constraint base {
    # Fundamental requirements
    requires: type_annotations, error_handling;
    forbid: bare_except;
}

constraint auth {
    requires: authentication, authorization;
    forbid: hardcoded_credentials;
}

constraint data_validation {
    requires: input_validation, output_validation;
    forbid: unsafe_serialization;
    
    # Pattern matching
    pattern: "if not.*validate";
}

constraint performance {
    # Query optimization
    forbid: n_plus_one_queries;
    requires: connection_pooling, caching;
    
    # Bounds
    max_response_time: 5s;
    max_memory: 256MB;
}

constraint pagination {
    requires: page_size_limit;
    max_items_per_page: 100;
    min_items_per_page: 1;
}

constraint api_endpoint {
    # Compose constraints
    includes: base, auth, data_validation, performance, pagination;
    
    # API-specific rules
    requires: http_status_codes, cors_headers;
    
    # Response structure
    response {
        must_have: status, data;
        may_have: errors, metadata;
    }
}
```

### Validate Against It

```bash
# Compile
ananke compile .ananke/api-service.ariadne --output api.cir

# Generate
ananke generate "Create user endpoint that lists all users with pagination" \
  --constraints api.cir

# Validate
ananke validate generated.py --constraints api.cir --detailed
```

---

## Ariadne vs JSON

### When to Use Each

**Use Ariadne when**:
- Constraints are complex
- You want inheritance/composition
- You want pattern-based rules
- Readability is important

**Use JSON when**:
- Constraints are simple
- You're auto-generating constraints
- You want strict validation
- You need to parse programmatically

### Converting Between Formats

**JSON to Ariadne**:
```bash
# Export JSON as Ariadne template
ananke constraints export constraints.json --format ariadne
```

**Ariadne to JSON**:
```bash
# Compile then export
ananke compile constraints.ariadne --output compiled.cir
ananke constraints export compiled.cir --format json --output constraints.json
```

---

## Best Practices

1. **Organize by concern**: security.ariadne, performance.ariadne, etc.
2. **Use inheritance**: Build complex constraints from simple ones
3. **Comment extensively**: Explain why each constraint exists
4. **Version control**: Commit to Git
5. **Test frequently**: Validate code against constraints
6. **Share templates**: Create reusable constraint sets

---

## Troubleshooting

### Syntax errors

**Problem**: "Invalid constraint syntax"

**Solution**:
```bash
# Check syntax
ananke compile constraints.ariadne --verbose

# Fix based on error message
# Common mistakes:
# - Missing semicolons
# - Mismatched braces
# - Invalid property names
```

### Constraints won't compile

**Problem**: "Constraint compilation failed"

**Solution**:
```bash
# Validate
ananke constraints validate constraints.ariadne --details

# Try simpler version
constraint simple {
    requires: auth;
}

# Then add complexity
constraint more_complex {
    includes: simple;
    additional_requires: validation;
}
```

---

## Next Steps

- **Tutorial 5**: Integrate into CI/CD
- **User Guide**: Detailed reference
- **Examples**: Real-world constraint sets

---

**Next**: [Tutorial 5: Integration](05-integration.md)
