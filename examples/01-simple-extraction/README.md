# Example 01: Simple Constraint Extraction

This example demonstrates basic constraint extraction from TypeScript code using Ananke's Clew engine, without any LLM assistance.

## What This Example Shows

- **Pure static analysis**: Extract constraints using tree-sitter and pattern matching
- **No external services**: Runs entirely locally without Claude or other APIs
- **Basic constraint types**: Syntactic and type-level constraints
- **Fast extraction**: Sub-second constraint discovery

## Files

- `sample.ts` - Example TypeScript authentication code with various patterns
- `main.zig` - Constraint extraction program
- `build.zig` - Build configuration
- `build.zig.zon` - Dependencies

## Building and Running

```bash
# From this directory
zig build run

# Or from the ananke root
cd examples/01-simple-extraction
zig build run
```

## Expected Output

The program will analyze `sample.ts` and extract constraints such as:

1. **Syntactic Constraints**
   - Function definitions detected
   - Explicit return types found
   - Code structure patterns

2. **Type Safety Constraints**
   - Explicit type annotations
   - Optional field handling
   - Enum usage for roles

3. **Architectural Constraints**
   - Class-based organization
   - Separation of concerns
   - Interface definitions

## What Gets Extracted

Without Claude, Clew uses static analysis to find:

- **Function signatures**: Return types, parameter types
- **Type annotations**: Interface definitions, enum usage
- **Null safety patterns**: Optional types, null checks
- **Code structure**: Class definitions, method organization

## Limitations

Without an LLM, this example cannot:

- Understand semantic intent (e.g., "this function validates credentials")
- Detect complex security patterns beyond keywords
- Infer implicit constraints from context
- Resolve ambiguous patterns

See Example 02 for Claude-enhanced semantic analysis.

## Understanding the Output

Each constraint includes:

- **Kind**: syntactic, type_safety, semantic, architectural, operational, or security
- **Severity**: error, warning, info, or hint
- **Name**: Identifier for the constraint
- **Description**: Human-readable explanation
- **Source**: Where the constraint came from (static_analysis in this case)
- **Confidence**: How certain we are about this constraint (0.0-1.0)

## Next Steps

After extraction, you can:

1. **Compile constraints** → Use Braid to create ConstraintIR
2. **Validate code** → Check if other code follows these patterns
3. **Generate code** → Use constraints to guide generation (requires Maze)

See Example 04 for the full pipeline.

## Key Insights

This example demonstrates that Ananke can extract valuable constraints without any LLM:

- Type systems already encode many constraints
- Static analysis reveals code patterns
- Tree-sitter provides reliable structural information
- Fast, deterministic, and free

LLMs (Example 02) add semantic understanding on top of this foundation.
