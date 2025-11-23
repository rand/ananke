# Example 04: Full Pipeline (Coming Soon)

This example will demonstrate the complete Ananke pipeline: Extract → Compile → Generate → Validate.

## Status

**Not Yet Available**: Maze (the generation orchestrator) is currently under development.

This example will be completed in Week 5-6 of the implementation plan.

## What This Will Show

### End-to-End Workflow

```
User Intent → Clew (Extract) → Braid (Compile) → Maze (Generate) → Validated Code
```

### Components

1. **Clew**: Extract constraints from existing codebase
2. **Braid**: Compile constraints into optimized ConstraintIR
3. **Maze**: Orchestrate constrained code generation
4. **Validation**: Verify output against constraints

### Example Use Case

Adding a new REST API endpoint with constraints from:
- Existing API patterns (extracted by Clew)
- Security policies (from Ariadne DSL)
- Performance requirements (from telemetry)
- Type safety rules (from TypeScript config)

## Prerequisites for Full Pipeline

### Infrastructure

- **Modal deployment**: vLLM + llguidance inference service
- **Model**: Llama 3.1 70B or similar
- **GPU**: 16GB+ VRAM

### Optional Services

- **Claude API**: For semantic constraint extraction
- **Redis**: For constraint caching
- **Telemetry**: For performance constraints

## Expected Features

### Constrained Generation

```zig
// Extract constraints
var clew = try Clew.init(allocator);
const constraints = try clew.extractFromCode(existing_code, "typescript");

// Compile to IR
var braid = try Braid.init(allocator);
const ir = try braid.compile(constraints);

// Generate with constraints
var maze = try Maze.init(allocator, .{
    .endpoint = "https://ananke-inference.modal.run",
    .model = "llama-3.1-70b",
});

const result = try maze.generate(.{
    .intent = "Add rate limiting to payment endpoint",
    .constraints = ir,
    .temperature = 0.7,
    .max_tokens = 2000,
});

// Validate output
const validation = try maze.validate(result.code, ir);
if (!validation.success) {
    // Attempt repairs
    const repaired = try maze.repair(result.code, validation.violations);
}
```

### Streaming Generation

```zig
const stream = try maze.generateStream(.{
    .intent = intent,
    .constraints = ir,
});

while (try stream.next()) |chunk| {
    // Process chunk by chunk
    std.debug.print("{s}", .{chunk.text});

    // Real-time constraint checking
    if (chunk.violation) |violation| {
        std.debug.print("\nConstraint violated: {s}\n", .{violation.constraint_name});
    }
}
```

### Multi-File Generation

```zig
const result = try maze.generateProject(.{
    .intent = "Add user authentication module",
    .constraints = ir,
    .files = &.{
        "src/auth/handler.ts",
        "src/auth/middleware.ts",
        "tests/auth.test.ts",
    },
});

for (result.files) |file| {
    std.debug.print("Generated: {s}\n", .{file.path});
}
```

### Repair and Iteration

```zig
var code = initial_generation;
var iteration: usize = 0;
const max_iterations = 3;

while (iteration < max_iterations) : (iteration += 1) {
    const validation = try maze.validate(code, ir);

    if (validation.success) break;

    // Attempt automatic repair
    code = try maze.repair(code, validation.violations);
}
```

## Timeline

### Week 5-6: Maze Implementation

- Basic generation orchestration
- Integration with llguidance
- Constraint application layer
- Validation framework

### Week 7: Inference Service

- Modal deployment
- vLLM + llguidance setup
- Model serving infrastructure
- API endpoints

### Week 8: Integration

- End-to-end testing
- Performance optimization
- Error handling
- Example completion

## Placeholder Example

For now, here's what the example will do:

```bash
# Will demonstrate:
cd examples/04-full-pipeline

# 1. Extract constraints from sample project
zig build extract

# 2. Define additional constraints
cat constraints.ariadne

# 3. Compile everything
zig build compile

# 4. Generate code with constraints
zig build generate -- "Add user registration endpoint"

# 5. Validate output
zig build validate

# 6. Run tests on generated code
zig build test
```

## Sample Project Structure

```
04-full-pipeline/
├── README.md (this file)
├── sample-project/
│   ├── src/
│   │   ├── handlers/
│   │   │   └── user.ts       # Existing code to learn from
│   │   ├── middleware/
│   │   │   └── auth.ts       # Authentication patterns
│   │   └── types/
│   │       └── user.ts       # Type definitions
│   └── tests/
│       └── user.test.ts      # Test patterns
├── constraints/
│   ├── extracted.json        # From Clew
│   ├── security.ariadne      # Manual definitions
│   └── performance.ariadne   # Performance budgets
└── main.zig                  # Full pipeline example
```

## Benefits of Full Pipeline

### Confidence

- Code is **proven valid** before it runs
- Constraints enforced at token level
- Sub-0.12% invalid generation rate

### Speed

- Constrained generation faster than unconstrained + validation
- Early pruning of invalid paths
- Efficient token masking (~50μs per token)

### Control

- Specify exactly what you want
- No hoping the model follows instructions
- Deterministic constraint enforcement

### Composability

- Mix extracted, manual, and LLM-derived constraints
- Build constraint libraries
- Reuse across projects

## Alternative: Try Inference Service First

While waiting for this example, you can:

1. Deploy the inference service (see `/modal_inference/`)
2. Try constraint-guided generation manually
3. Experiment with llguidance directly

See `/modal_inference/QUICKSTART.md` for deployment instructions.

## Related Examples

- Example 01: Constraint extraction (Clew)
- Example 02: Semantic analysis (Claude)
- Example 03: Manual constraints (Ariadne DSL)
- Example 05: Mixing approaches

## Questions?

Check the implementation plan:
- `/docs/IMPLEMENTATION_PLAN.md`
- `/ananke_plan_revised/maze_implementation.md`

This example will be updated as Maze development progresses.

---

**Check back after Week 8 for the complete example!**
