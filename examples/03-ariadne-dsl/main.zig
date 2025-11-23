const std = @import("std");
const ananke = @import("ananke");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== Ananke Example 03: Ariadne DSL ===\n\n", .{});

    std.debug.print("This example demonstrates defining constraints using the Ariadne DSL.\n\n", .{});

    // Read the Ariadne constraint files
    const security_dsl = try std.fs.cwd().readFileAlloc(allocator, "api_security.ariadne", 1024 * 1024);
    defer allocator.free(security_dsl);

    const type_dsl = try std.fs.cwd().readFileAlloc(allocator, "type_safety.ariadne", 1024 * 1024);
    defer allocator.free(type_dsl);

    const perf_dsl = try std.fs.cwd().readFileAlloc(allocator, "performance.ariadne", 1024 * 1024);
    defer allocator.free(perf_dsl);

    std.debug.print("=== Loaded Ariadne DSL Files ===\n\n", .{});
    std.debug.print("1. api_security.ariadne ({} bytes)\n", .{security_dsl.len});
    std.debug.print("2. type_safety.ariadne ({} bytes)\n", .{type_dsl.len});
    std.debug.print("3. performance.ariadne ({} bytes)\n\n", .{perf_dsl.len});

    // Initialize Ariadne compiler
    std.debug.print("=== Compiling Ariadne to ConstraintIR ===\n\n", .{});

    var ariadne_compiler = try ananke.ariadne.AriadneCompiler.init(allocator);
    defer ariadne_compiler.deinit();

    std.debug.print("Note: Ariadne parser is not yet implemented.\n", .{});
    std.debug.print("This example shows what the DSL looks like and the expected workflow.\n\n", .{});

    // Show what the compiled output would look like
    print_expected_constraint_ir();

    std.debug.print("\n=== DSL Benefits ===\n\n", .{});

    std.debug.print("Ariadne DSL vs. Manual Extraction:\n\n", .{});

    std.debug.print("1. Declarative:\n", .{});
    std.debug.print("   - Express constraints in domain language\n", .{});
    std.debug.print("   - No need to write extraction code\n", .{});
    std.debug.print("   - Clear separation of concerns\n\n", .{});

    std.debug.print("2. Composable:\n", .{});
    std.debug.print("   - Import and combine constraint modules\n", .{});
    std.debug.print("   - Build libraries of reusable constraints\n", .{});
    std.debug.print("   - Mix extracted and manual constraints\n\n", .{});

    std.debug.print("3. Versioned:\n", .{});
    std.debug.print("   - Track constraint changes in git\n", .{});
    std.debug.print("   - Review constraint updates\n", .{});
    std.debug.print("   - Rollback if needed\n\n", .{});

    std.debug.print("4. Type-Safe:\n", .{});
    std.debug.print("   - Compiler checks constraint definitions\n", .{});
    std.debug.print("   - Catches errors at build time\n", .{});
    std.debug.print("   - IDE support for authoring\n\n", .{});

    std.debug.print("5. Portable:\n", .{});
    std.debug.print("   - Same DSL works across languages\n", .{});
    std.debug.print("   - Platform-independent\n", .{});
    std.debug.print("   - Easy to share and reuse\n\n", .{});

    std.debug.print("=== Use Cases ===\n\n", .{});

    std.debug.print("Security Policies:\n", .{});
    std.debug.print("  - Define organization-wide security constraints\n", .{});
    std.debug.print("  - Enforce across all projects\n", .{});
    std.debug.print("  - Example: api_security.ariadne\n\n", .{});

    std.debug.print("Type System Requirements:\n", .{});
    std.debug.print("  - Codify type safety standards\n", .{});
    std.debug.print("  - Ensure consistent typing\n", .{});
    std.debug.print("  - Example: type_safety.ariadne\n\n", .{});

    std.debug.print("Performance Budgets:\n", .{});
    std.debug.print("  - Set performance constraints\n", .{});
    std.debug.print("  - Monitor against SLAs\n", .{});
    std.debug.print("  - Example: performance.ariadne\n\n", .{});

    std.debug.print("=== Comparison with Other Approaches ===\n\n", .{});

    print_comparison_table();

    std.debug.print("\n=== Next Steps ===\n\n", .{});
    std.debug.print("Once Ariadne parser is implemented:\n", .{});
    std.debug.print("1. Compile .ariadne files to ConstraintIR\n", .{});
    std.debug.print("2. Combine with extracted constraints\n", .{});
    std.debug.print("3. Use in code generation (Maze)\n", .{});
    std.debug.print("4. Validate generated code\n\n", .{});

    std.debug.print("See Example 05 for mixing Ariadne with JSON constraints.\n", .{});
}

fn print_expected_constraint_ir() void {
    std.debug.print("Expected ConstraintIR (JSON format):\n\n", .{});
    std.debug.print(
        \\{{
        \\  "version": "1.0.0",
        \\  "nodes": {{
        \\    "security-001": {{
        \\      "id": "security-001",
        \\      "name": "no_dangerous_operations",
        \\      "enforcement": {{
        \\        "type": "Structural",
        \\        "pattern": "(call_expression function: (identifier) @fn ...)",
        \\        "action": "Forbid"
        \\      }},
        \\      "failure_mode": "HardBlock",
        \\      "provenance": {{
        \\        "source": "ManualPolicy",
        \\        "confidence_score": 1.0
        \\      }}
        \\    }},
        \\    "type-001": {{
        \\      "id": "type-001",
        \\      "name": "no_any_type",
        \\      "enforcement": {{
        \\        "type": "Type",
        \\        "forbidden_types": ["any", "unknown"]
        \\      }},
        \\      "failure_mode": "AutoFix"
        \\    }},
        \\    "perf-001": {{
        \\      "id": "perf-001",
        \\      "name": "max_cyclomatic_complexity",
        \\      "enforcement": {{
        \\        "type": "Semantic",
        \\        "property": {{
        \\          "type": "Performance",
        \\          "constraints": {{ "max_complexity": 10 }}
        \\        }}
        \\      }},
        \\      "failure_mode": "SoftWarn"
        \\    }}
        \\  }},
        \\  "adjacency": {{
        \\    "security-001": [],
        \\    "type-001": ["security-001"],
        \\    "perf-001": []
        \\  }}
        \\}}
        \\
    , .{});
}

fn print_comparison_table() void {
    std.debug.print("Approach          | Pros                    | Cons\n", .{});
    std.debug.print("------------------+-------------------------+----------------------\n", .{});
    std.debug.print("Static Extract    | Fast, deterministic     | Limited semantics\n", .{});
    std.debug.print("Claude Extract    | Rich semantics          | Slow, costly\n", .{});
    std.debug.print("Ariadne DSL       | Declarative, versioned  | Must define manually\n", .{});
    std.debug.print("JSON Config       | Simple, portable        | Verbose\n", .{});
    std.debug.print("Mixed Mode        | Best of all worlds      | More complex\n", .{});
}
