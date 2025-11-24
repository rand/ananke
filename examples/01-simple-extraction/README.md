# Example 01: Simple Constraint Extraction

This example demonstrates basic constraint extraction from TypeScript code using Ananke's Clew engine, without any LLM assistance.

## What This Example Shows

- **Pure static analysis**: Extract constraints using tree-sitter and pattern matching
- **No external services**: Runs entirely locally without Claude or other APIs
- **Basic constraint types**: Syntactic and type-level constraints
- **Fast extraction**: Sub-second constraint discovery

## Files

```
01-simple-extraction/
├── README.md           # This file
├── main.zig            # Extraction program (70 lines)
├── sample.ts           # TypeScript auth code (122 lines)
├── sample_go.go        # Go example
├── sample_python.py    # Python example
├── sample_rust.rs      # Rust example
├── build.zig           # Build configuration
└── build.zig.zon       # Dependencies
```

## Prerequisites

- Zig 0.15.2 or later
- No external dependencies
- No API keys required

## Building and Running

```bash
# From this directory
zig build run

# Or from the ananke root
cd examples/01-simple-extraction
zig build run
```

Expected build time: ~5 seconds
Expected run time: ~100ms

## Expected Output

```
=== Ananke Example 01: Simple Constraint Extraction ===

Analyzing file: sample.ts
File size: 3515 bytes

Extracting constraints (without Claude)...

Found 15 constraints:

Constraint 1: Export statement
  Kind: architectural
  Severity: info
  Description: Export statement detected at line 8 in typescript code
  Source: AST_Pattern
  Confidence: 0.85

Constraint 2: Class declaration
  Kind: syntactic
  Severity: info
  Description: Class declaration detected at line 8 in typescript code
  Source: AST_Pattern
  Confidence: 0.85

Constraint 3: Number type annotation
  Kind: type_safety
  Severity: info
  Description: Number type annotation detected at line 9 in typescript code
  Source: AST_Pattern
  Confidence: 0.85

[... 12 more constraints ...]

=== Summary by Kind ===
  syntactic: 5
  type_safety: 6
  semantic: 3
  architectural: 1

=== Extraction Complete ===

Key Insights:
- Static analysis detected function signatures and return types
- Type safety patterns identified (explicit types, optional fields)
- Security patterns noted (password handling, authentication)
- No LLM required for basic structural constraints
```

The output shows:

1. **Syntactic Constraints** (5 found)
   - Function definitions detected
   - Explicit return types found
   - Code structure patterns

2. **Type Safety Constraints** (6 found)
   - Explicit type annotations
   - Optional field handling
   - Enum usage for roles

3. **Architectural Constraints** (1 found)
   - Class-based organization
   - Separation of concerns
   - Interface definitions

4. **Semantic Constraints** (3 found)
   - Async/await patterns
   - Error handling (try/catch)
   - Promise usage

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

## Code Walkthrough

Let's look at how the extraction program works:

### Step 1: Initialize Allocator (lines 5-7)

```zig
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
defer _ = gpa.deinit();
const allocator = gpa.allocator();
```

Creates a general-purpose allocator for memory management. The `defer` ensures cleanup happens automatically.

### Step 2: Read Source File (lines 12-14)

```zig
const file_path = "sample.ts";
const source_code = try std.fs.cwd().readFileAlloc(allocator, file_path, 1024 * 1024);
defer allocator.free(source_code);
```

Reads the entire TypeScript file into memory (up to 1MB). Memory is freed on scope exit.

### Step 3: Initialize Clew Engine (lines 21-22)

```zig
var clew = try ananke.clew.Clew.init(allocator);
defer clew.deinit();
```

Creates the constraint extraction engine. Clew uses tree-sitter for parsing and 60+ regex patterns for constraint detection.

### Step 4: Extract Constraints (line 27)

```zig
const constraints = try clew.extractFromCode(source_code, "typescript");
```

This single call:
1. Parses TypeScript into an AST using tree-sitter
2. Walks the AST to find patterns
3. Applies 60+ constraint detection rules
4. Returns a ConstraintSet with all findings

### Step 5: Display Results (lines 36-42)

```zig
for (constraints.constraints.items, 0..) |constraint, i| {
    std.debug.print("Constraint {}: {s}\n", .{ i + 1, constraint.name });
    std.debug.print("  Kind: {s}\n", .{@tagName(constraint.kind)});
    std.debug.print("  Severity: {s}\n", .{@tagName(constraint.severity)});
    std.debug.print("  Description: {s}\n", .{constraint.description});
    std.debug.print("  Source: {s}\n", .{@tagName(constraint.source)});
    std.debug.print("  Confidence: {d:.2}\n\n", .{constraint.confidence});
}
```

Iterates through extracted constraints and prints detailed information about each one.

### Step 6: Summarize by Kind (lines 47-62)

```zig
var kind_counts = std.AutoHashMap(ananke.types.constraint.ConstraintKind, usize).init(allocator);
defer kind_counts.deinit();

for (constraints.constraints.items) |constraint| {
    const entry = try kind_counts.getOrPut(constraint.kind);
    if (entry.found_existing) {
        entry.value_ptr.* += 1;
    } else {
        entry.value_ptr.* = 1;
    }
}
```

Groups constraints by their kind (syntactic, type_safety, etc.) and counts occurrences.

## Understanding the Output

Each constraint includes:

- **Kind**: syntactic, type_safety, semantic, architectural, operational, or security
- **Severity**: error, warning, info, or hint
- **Name**: Identifier for the constraint
- **Description**: Human-readable explanation
- **Source**: Where the constraint came from (AST_Pattern for static analysis)
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

## Customization

### Analyze Different Languages

The example includes sample files for multiple languages:

```bash
# Modify main.zig to analyze different files
const file_path = "sample_python.py";  # Python
const file_path = "sample_go.go";      # Go
const file_path = "sample_rust.rs";    # Rust
```

Then change the language parameter:

```zig
const constraints = try clew.extractFromCode(source_code, "python");
const constraints = try clew.extractFromCode(source_code, "go");
const constraints = try clew.extractFromCode(source_code, "rust");
```

### Analyze Your Own Code

Replace `sample.ts` with your own file:

```bash
# Copy your file
cp /path/to/your/code.ts sample.ts

# Run extraction
zig build run
```

Or modify `main.zig` to read from any path:

```zig
const file_path = "/absolute/path/to/your/code.ts";
```

### Filter by Constraint Kind

Add filtering after extraction:

```zig
// Only show security constraints
for (constraints.constraints.items) |constraint| {
    if (constraint.kind == .security) {
        // Display constraint
    }
}
```

### Adjust Confidence Threshold

Filter by confidence score:

```zig
// Only show high-confidence constraints
for (constraints.constraints.items) |constraint| {
    if (constraint.confidence >= 0.9) {
        // Display constraint
    }
}
```

## Common Issues

### Issue: Build fails with "unable to find ananke"

**Symptom:**
```
error: dependency 'ananke' not found
```

**Cause:** The build.zig.zon path to the parent ananke project is incorrect.

**Solution:**
```bash
# Check the path in build.zig.zon
cat build.zig.zon

# It should point to the parent directory
# If needed, adjust the path:
.dependencies = .{
    .ananke = .{ .path = "../.." },
},
```

### Issue: File not found error

**Symptom:**
```
Error: FileNotFound
```

**Cause:** Running from the wrong directory.

**Solution:**
```bash
# Always run from the example directory
cd examples/01-simple-extraction
zig build run

# Not from the root
```

### Issue: Out of memory

**Symptom:**
```
error: OutOfMemory
```

**Cause:** File is too large (over 1MB).

**Solution:** Increase the buffer size in main.zig:

```zig
// Change from 1024 * 1024 to larger
const source_code = try std.fs.cwd().readFileAlloc(allocator, file_path, 10 * 1024 * 1024);  // 10MB
```

### Issue: No constraints found

**Symptom:**
```
Found 0 constraints
```

**Cause:** The language may not be supported or the file has no detectable patterns.

**Solution:**
- Verify the language parameter matches the file type
- Check that the file contains actual code (not just comments)
- Try a different sample file

## Performance Notes

Extraction performance on a MacBook Pro M1:

| File Size | Constraints Found | Time    |
|-----------|-------------------|---------|
| 1 KB      | 3-5               | ~10ms   |
| 10 KB     | 20-40             | ~50ms   |
| 100 KB    | 100-200           | ~200ms  |
| 1 MB      | 500-1000          | ~1s     |

Performance is linear with file size. For large codebases, extract files individually or in batches.
