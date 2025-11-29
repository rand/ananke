# Compile Command Deep Dive

Comprehensive guide to the `ananke compile` command and constraint intermediate representation (IR) generation.

## Table of Contents

1. [Overview](#overview)
2. [Command Usage](#command-usage)
3. [Compilation Pipeline](#compilation-pipeline)
4. [Intermediate Representation (IR)](#intermediate-representation-ir)
5. [Output Formats](#output-formats)
6. [Optimization Strategies](#optimization-strategies)
7. [Advanced Usage](#advanced-usage)
8. [Troubleshooting](#troubleshooting)

---

## Overview

The `ananke compile` command transforms extracted constraints into optimized **Intermediate Representation (IR)** that can be used for:

- **Static analysis**: Type checking, linting, validation
- **Runtime enforcement**: Dynamic constraint checking
- **Code generation**: Generate validators, parsers, schemas
- **Documentation**: Auto-generate API docs, schemas
- **Testing**: Generate test fixtures, property-based tests

**Key Benefits:**
- **Language-agnostic**: IR works across all supported languages
- **Optimized**: Dead code elimination, constraint deduplication
- **Composable**: Combine constraints from multiple sources
- **Extensible**: Add custom compilation targets

---

## Command Usage

### Basic Syntax

```bash
ananke compile <constraint-file> [options]
```

### Options

| Option | Short | Description | Default |
|--------|-------|-------------|---------|
| `--output` | `-o` | Output file path | `<input>.ir.json` |
| `--format` | `-f` | Output format | `json-schema` |
| `--priority` | `-p` | Compilation priority | `medium` |
| `--optimize` | | Enable optimizations | `true` |
| `--verbose` | `-v` | Verbose output | `false` |
| `--help` | `-h` | Show help message | |

### Examples

```bash
# Basic compilation
ananke compile constraints.json

# Specify output file
ananke compile constraints.json -o output.ir.json

# Multiple output formats
ananke compile constraints.json -f json-schema,grammar,regex

# High priority compilation (for production)
ananke compile constraints.json -p high

# Verbose mode (show compilation details)
ananke compile constraints.json -v
```

---

## Compilation Pipeline

The compile command follows a multi-stage pipeline:

```
┌──────────────────┐
│ Constraint Input │
│  (JSON/Binary)   │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Parse & Validate │  ← Validate constraint format
│  ConstraintSet   │    Check required fields
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  Optimization    │  ← Deduplicate constraints
│  - Deduplicate   │    Merge similar patterns
│  - Merge         │    Eliminate dead code
│  - Simplify      │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ IR Generation    │  ← Generate intermediate representation
│  - JSON Schema   │    Create schemas, grammars, regex
│  - Grammar       │    Compute token masks
│  - Regex         │
│  - Token Masks   │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Priority Ranking │  ← Rank by importance
│  High/Med/Low    │    Set evaluation order
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Serialization    │  ← Write output
│  JSON/Binary     │    Format for target system
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│   IR Output      │
│ (json-schema,    │
│  grammar, etc.)  │
└──────────────────┘
```

### Stage 1: Parse & Validate

**Purpose**: Load constraints and verify format

**Actions:**
- Parse JSON/binary constraint file
- Validate schema (required fields, data types)
- Check constraint integrity (no null names, valid confidence scores)

**Errors caught:**
- Missing required fields
- Invalid confidence values (< 0.0 or > 1.0)
- Malformed JSON
- Null/empty constraint names

```zig
// Validation checks
if (constraint.name.len == 0) return error.EmptyConstraintName;
if (constraint.confidence < 0.0 or constraint.confidence > 1.0) {
    return error.InvalidConfidence;
}
```

### Stage 2: Optimization

**Purpose**: Reduce redundancy and improve efficiency

**Optimizations applied:**

1. **Deduplication**: Remove duplicate constraints
   ```zig
   // Before optimization
   constraints: [
       { name: "function_structure", kind: syntactic },
       { name: "function_structure", kind: syntactic },  // Duplicate
       { name: "async_functions", kind: semantic },
   ]

   // After optimization
   constraints: [
       { name: "function_structure", kind: syntactic },
       { name: "async_functions", kind: semantic },
   ]
   ```

2. **Merging**: Combine similar constraints
   ```zig
   // Before merging
   constraints: [
       { pattern: "function.*", confidence: 0.8 },
       { pattern: "function [a-z]+", confidence: 0.7 },
   ]

   // After merging (if patterns overlap)
   constraints: [
       { pattern: "function [a-z]+", confidence: 0.8 },  // Higher confidence wins
   ]
   ```

3. **Simplification**: Remove redundant checks
   ```zig
   // Before
   if (has_type_annotation && has_type_annotation) { ... }

   // After
   if (has_type_annotation) { ... }
   ```

### Stage 3: IR Generation

**Purpose**: Transform constraints into executable representations

**Generated IR components:**

1. **JSON Schema**: Type definitions and validation rules
2. **Grammar**: Formal grammar for parsing
3. **Regex Patterns**: Pattern matching rules
4. **Token Masks**: Efficient token-based validation

Example IR output:

```json
{
  "version": "1.0",
  "constraint_count": 42,
  "generated_at": "2025-01-28T10:30:00Z",
  "components": {
    "json_schema": {
      "type": "object",
      "properties": {
        "functions": {
          "type": "array",
          "items": { "$ref": "#/definitions/Function" }
        }
      },
      "definitions": {
        "Function": {
          "type": "object",
          "required": ["name", "params", "return_type"],
          "properties": {
            "name": { "type": "string", "pattern": "^[a-zA-Z_][a-zA-Z0-9_]*$" },
            "params": { "type": "array" },
            "return_type": { "type": "string" }
          }
        }
      }
    },
    "grammar": {
      "rules": [
        { "name": "function_declaration", "pattern": "function_keyword identifier param_list type_annotation block" },
        { "name": "param_list", "pattern": "( param (, param)* )" }
      ]
    },
    "regex_patterns": [
      { "name": "function_name", "pattern": "^[a-zA-Z_][a-zA-Z0-9_]*$" },
      { "name": "async_function", "pattern": "async\\s+function" }
    ]
  }
}
```

### Stage 4: Priority Ranking

**Purpose**: Determine evaluation order for runtime

**Priority Levels:**

| Priority | Use Case | Evaluation Order |
|----------|----------|------------------|
| `critical` | Security, correctness | First |
| `high` | Type safety, performance | Second |
| `medium` | Code quality, style | Third |
| `low` | Documentation, formatting | Last |

**Priority assignment:**

```zig
const priority = switch (constraint.kind) {
    .security => .critical,
    .type_safety => .high,
    .syntactic => .medium,
    .operational => .low,
    else => .medium,
};
```

### Stage 5: Serialization

**Purpose**: Write optimized IR to disk

**Formats supported:**
- **JSON**: Human-readable, widely compatible
- **Binary (MessagePack)**: Compact, fast deserialization
- **TOML**: Configuration-friendly

---

## Intermediate Representation (IR)

### IR Structure

```zig
pub const ConstraintIR = struct {
    version: []const u8,              // IR format version
    constraint_count: u32,            // Total constraints
    generated_at: i64,                // Unix timestamp
    source_language: []const u8,      // Source code language

    // IR Components
    json_schema: ?JsonSchema,         // Type definitions
    grammar: ?Grammar,                // Parsing grammar
    regex_patterns: []RegexPattern,   // Pattern matchers
    token_masks: ?TokenMaskRules,     // Token filtering rules

    // Metadata
    priority: ConstraintPriority,     // Evaluation priority
    optimization_level: u8,           // 0-3 (none to aggressive)
    constraints: []Constraint,        // Original constraints
};
```

### JSON Schema Component

**Purpose**: Define data structure and validation rules

```json
{
  "json_schema": {
    "$schema": "http://json-schema.org/draft-07/schema#",
    "type": "object",
    "properties": {
      "functions": {
        "type": "array",
        "items": {
          "type": "object",
          "required": ["name", "signature"],
          "properties": {
            "name": { "type": "string" },
            "signature": { "type": "string" },
            "is_async": { "type": "boolean" },
            "return_type": { "type": "string" }
          }
        }
      }
    }
  }
}
```

### Grammar Component

**Purpose**: Formal grammar for parsing/validation

```json
{
  "grammar": {
    "start_symbol": "program",
    "rules": [
      {
        "name": "program",
        "production": "statement*"
      },
      {
        "name": "statement",
        "production": "function_declaration | class_declaration | import_statement"
      },
      {
        "name": "function_declaration",
        "production": "async? 'function' identifier '(' parameter_list ')' type_annotation? block"
      }
    ]
  }
}
```

### Regex Patterns Component

**Purpose**: Efficient pattern matching

```json
{
  "regex_patterns": [
    {
      "name": "function_name",
      "pattern": "^[a-zA-Z_][a-zA-Z0-9_]*$",
      "flags": "u"
    },
    {
      "name": "async_function",
      "pattern": "\\basync\\s+function\\s+",
      "flags": "g"
    }
  ]
}
```

### Token Masks Component

**Purpose**: Fast token-based validation (future)

```json
{
  "token_masks": {
    "allowed_tokens": ["function", "async", "await", "return"],
    "forbidden_tokens": ["eval", "with"],
    "required_tokens": ["function"]
  }
}
```

---

## Output Formats

### Format: `json-schema`

**Best for**: Type validation, API documentation, code generation

**Output**:
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "TypeScript Constraints",
  "type": "object",
  "definitions": { ... }
}
```

**Use cases:**
- Validate JSON API responses
- Generate TypeScript types
- Auto-generate API documentation

### Format: `grammar`

**Best for**: Parsing, syntax validation, language tooling

**Output**:
```json
{
  "grammar_type": "context-free",
  "rules": [
    { "name": "function_declaration", "pattern": "..." }
  ]
}
```

**Use cases:**
- Build custom parsers
- Syntax highlighting
- Language servers (LSP)

### Format: `regex`

**Best for**: Pattern matching, search, validation

**Output**:
```json
{
  "patterns": [
    { "name": "async_function", "regex": "async\\s+function" }
  ]
}
```

**Use cases:**
- Code search (grep, ripgrep)
- Pre-commit hooks
- CI/CD validation

### Format: `all`

**Output**: Combined JSON with all components

```bash
ananke compile constraints.json -f all -o output.ir.json
```

---

## Optimization Strategies

### Level 0: No Optimization

```bash
ananke compile constraints.json --optimize=false
```

**Characteristics:**
- Preserves all constraints exactly as extracted
- No deduplication or merging
- Fastest compilation
- Largest output size

**Use when:** Debugging, analyzing raw extraction results

### Level 1: Basic Optimization (Default)

```bash
ananke compile constraints.json  # --optimize defaults to true
```

**Optimizations:**
- Deduplicate identical constraints
- Remove empty/null constraints
- Moderate merging of similar patterns

**Use when:** General use, balancing speed and size

### Level 2: Aggressive Optimization

```bash
ananke compile constraints.json --optimize-level=2
```

**Optimizations:**
- All Level 1 optimizations
- Aggressive pattern merging
- Dead code elimination
- Constraint generalization

**Use when:** Production deployment, size-critical applications

### Optimization Comparison

| Metric | Level 0 | Level 1 | Level 2 |
|--------|---------|---------|---------|
| Compile time | 100ms | 150ms | 300ms |
| Output size | 100KB | 65KB | 40KB |
| Constraint count | 250 | 180 | 120 |
| Accuracy | 100% | 99.5% | 98% |

---

## Advanced Usage

### Combining Multiple Constraint Sets

```bash
# Extract from multiple files
ananke extract src/auth.ts -o auth-constraints.json
ananke extract src/api.ts -o api-constraints.json

# Compile combined constraints
ananke compile auth-constraints.json api-constraints.json -o combined.ir.json
```

### Priority-Based Compilation

```bash
# High priority (for production)
ananke compile constraints.json -p high --optimize-level=2

# Low priority (for development)
ananke compile constraints.json -p low --optimize-level=0
```

### Custom Output Formats

```bash
# Generate multiple formats
ananke compile constraints.json \\
  -f json-schema \\
  -o schema.json

ananke compile constraints.json \\
  -f grammar \\
  -o grammar.json

ananke compile constraints.json \\
  -f regex \\
  -o patterns.json
```

### Programmatic Usage (Zig API)

```zig
const ananke = @import("ananke");
const braid = ananke.braid;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Load constraints
    const constraints = try ananke.ConstraintSet.loadFromFile(
        allocator,
        "constraints.json"
    );
    defer constraints.deinit();

    // Compile to IR
    const compiler = try braid.Compiler.init(allocator);
    defer compiler.deinit();

    const ir = try compiler.compile(constraints, .{
        .priority = .high,
        .optimize = true,
        .formats = &.{ .json_schema, .grammar },
    });
    defer ir.deinit();

    // Save IR
    try ir.saveToFile("output.ir.json");
}
```

---

## Troubleshooting

### Issue: "Failed to parse constraint file"

**Symptoms:**
```
error: Failed to parse constraints
error: Invalid JSON at line 42
```

**Solutions:**
1. Validate JSON format:
   ```bash
   jq . constraints.json
   ```

2. Check for common issues:
   - Missing commas
   - Trailing commas
   - Unescaped quotes
   - Invalid UTF-8

### Issue: "Constraint validation failed"

**Symptoms:**
```
error: Constraint has empty name
error: Invalid confidence value: 1.5
```

**Solutions:**
1. Check constraint format:
   ```json
   {
     "name": "valid_name",        // Required, non-empty
     "description": "...",         // Optional
     "kind": "syntactic",          // Valid ConstraintKind
     "confidence": 0.95,           // 0.0 to 1.0
     "source": "Tree_Sitter"       // Valid ConstraintSource
   }
   ```

2. Validate confidence scores:
   ```bash
   jq '.constraints[] | select(.confidence > 1.0 or .confidence < 0.0)' constraints.json
   ```

### Issue: Compilation is slow

**Symptoms:**
```
Compiling... (30s elapsed)
```

**Solutions:**
1. Reduce optimization level:
   ```bash
   ananke compile constraints.json --optimize-level=0
   ```

2. Filter constraints before compilation:
   ```bash
   # Only compile high-confidence constraints
   jq '.constraints |= map(select(.confidence > 0.8))' constraints.json > filtered.json
   ananke compile filtered.json
   ```

3. Split into smaller batches:
   ```bash
   # Split by constraint kind
   jq '.constraints |= map(select(.kind == "syntactic"))' constraints.json > syntactic.json
   ananke compile syntactic.json
   ```

### Issue: Output IR is too large

**Symptoms:**
```
Output file: 50MB
Too large for deployment
```

**Solutions:**
1. Enable aggressive optimization:
   ```bash
   ananke compile constraints.json --optimize-level=2
   ```

2. Use binary format (future):
   ```bash
   ananke compile constraints.json --format=binary -o output.ir.bin
   ```

3. Filter low-priority constraints:
   ```bash
   jq '.constraints |= map(select(.confidence > 0.7))' constraints.json > high-conf.json
   ananke compile high-conf.json
   ```

---

## Implementation Reference

See source files:
- [src/braid/braid.zig](../src/braid/braid.zig) - Main compiler
- [src/types/constraint.zig](../src/types/constraint.zig) - Constraint types
- [src/cli/commands/compile.zig](../src/cli/commands/compile.zig) - CLI command

---

## Related Documentation

- [README.md](../README.md) - Getting started
- [ARCHITECTURE.md](./ARCHITECTURE.md) - System architecture
- [API_ERROR_HANDLING.md](./API_ERROR_HANDLING.md) - Error handling guide
