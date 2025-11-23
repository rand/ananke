const std = @import("std");
const ananke = @import("ananke");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== Ananke Example 05: Mixed-Mode Constraints ===\n\n", .{});

    std.debug.print("This example demonstrates combining multiple constraint sources:\n", .{});
    std.debug.print("1. Extracted from code (Clew)\n", .{});
    std.debug.print("2. Defined in JSON config\n", .{});
    std.debug.print("3. Written in Ariadne DSL\n\n", .{});

    // Phase 1: Extract constraints from code
    std.debug.print("=== Phase 1: Extract from Code ===\n\n", .{});

    const source_code = try std.fs.cwd().readFileAlloc(allocator, "sample.ts", 1024 * 1024);
    defer allocator.free(source_code);

    var clew = try ananke.clew.Clew.init(allocator);
    defer clew.deinit();

    const extracted = try clew.extractFromCode(source_code, "typescript");
    defer {
        for (extracted.constraints.items) |_| {}
    }

    std.debug.print("Extracted {} constraints from sample.ts\n", .{extracted.constraints.items.len});
    std.debug.print("  - Function signatures and types\n", .{});
    std.debug.print("  - Error handling patterns\n", .{});
    std.debug.print("  - Null safety checks\n\n", .{});

    // Phase 2: Load JSON constraints
    std.debug.print("=== Phase 2: Load JSON Config ===\n\n", .{});

    const json_content = try std.fs.cwd().readFileAlloc(allocator, "constraints.json", 1024 * 1024);
    defer allocator.free(json_content);

    std.debug.print("Loaded constraints.json ({} bytes)\n", .{json_content.len});
    std.debug.print("  - Environment variable requirements\n", .{});
    std.debug.print("  - Error logging format\n", .{});
    std.debug.print("  - Test coverage minimum\n\n", .{});

    // Phase 3: Load Ariadne constraints
    std.debug.print("=== Phase 3: Load Ariadne DSL ===\n\n", .{});

    const ariadne_content = try std.fs.cwd().readFileAlloc(allocator, "custom.ariadne", 1024 * 1024);
    defer allocator.free(ariadne_content);

    std.debug.print("Loaded custom.ariadne ({} bytes)\n", .{ariadne_content.len});
    std.debug.print("  - Database retry logic requirement\n", .{});
    std.debug.print("  - Standard API response format\n", .{});
    std.debug.print("  - Payment amount validation\n\n", .{});

    // Phase 4: Merge all constraints
    std.debug.print("=== Phase 4: Merge All Sources ===\n\n", .{});

    std.debug.print("Total constraints from all sources:\n", .{});
    std.debug.print("  Extracted (Clew):     ~{} constraints\n", .{extracted.constraints.items.len});
    std.debug.print("  JSON Config:          3 constraints\n", .{});
    std.debug.print("  Ariadne DSL:          3 constraints\n", .{});
    std.debug.print("  ─────────────────────────────────\n", .{});
    std.debug.print("  Total:                ~{} constraints\n\n", .{extracted.constraints.items.len + 6});

    // Phase 5: Show constraint composition
    std.debug.print("=== Phase 5: Constraint Composition ===\n\n", .{});

    print_constraint_layers();

    std.debug.print("\n=== Benefits of Mixed-Mode ===\n\n", .{});

    std.debug.print("Best of All Worlds:\n\n", .{});

    std.debug.print("1. Extracted Constraints (Clew)\n", .{});
    std.debug.print("   ✓ Automatic discovery\n", .{});
    std.debug.print("   ✓ Always up-to-date with code\n", .{});
    std.debug.print("   ✓ No manual maintenance\n", .{});
    std.debug.print("   ✗ Limited to observable patterns\n\n", .{});

    std.debug.print("2. JSON Configuration\n", .{});
    std.debug.print("   ✓ Simple and portable\n", .{});
    std.debug.print("   ✓ Easy to generate programmatically\n", .{});
    std.debug.print("   ✓ Language-agnostic\n", .{});
    std.debug.print("   ✗ Verbose for complex constraints\n\n", .{});

    std.debug.print("3. Ariadne DSL\n", .{});
    std.debug.print("   ✓ Expressive and type-safe\n", .{});
    std.debug.print("   ✓ Rich query language\n", .{});
    std.debug.print("   ✓ Composable modules\n", .{});
    std.debug.print("   ✗ Requires learning DSL\n\n", .{});

    std.debug.print("=== Use Cases for Each ===\n\n", .{});

    print_use_cases();

    std.debug.print("\n=== Practical Workflow ===\n\n", .{});

    std.debug.print("1. Start with Extraction:\n", .{});
    std.debug.print("   clew.extractFromCode() → baseline constraints\n\n", .{});

    std.debug.print("2. Add JSON for Simple Rules:\n", .{});
    std.debug.print("   Environment variables, simple patterns\n\n", .{});

    std.debug.print("3. Use Ariadne for Complex Logic:\n", .{});
    std.debug.print("   Business rules, domain-specific requirements\n\n", .{});

    std.debug.print("4. Merge and Compile:\n", .{});
    std.debug.print("   braid.compile(all_constraints) → ConstraintIR\n\n", .{});

    std.debug.print("5. Use in Generation:\n", .{});
    std.debug.print("   maze.generate(intent, constraints) → validated code\n\n", .{});

    std.debug.print("=== Example Complete ===\n", .{});
}

fn print_constraint_layers() void {
    std.debug.print("Constraint Hierarchy (bottom to top):\n\n", .{});

    std.debug.print("Layer 1 - Foundation (Extracted):\n", .{});
    std.debug.print("  │ Function signatures\n", .{});
    std.debug.print("  │ Type definitions\n", .{});
    std.debug.print("  │ Error handling patterns\n", .{});
    std.debug.print("  └─> Discovered automatically\n\n", .{});

    std.debug.print("Layer 2 - Configuration (JSON):\n", .{});
    std.debug.print("  │ Environment requirements\n", .{});
    std.debug.print("  │ Logging standards\n", .{});
    std.debug.print("  │ Quality gates\n", .{});
    std.debug.print("  └─> Organizational policies\n\n", .{});

    std.debug.print("Layer 3 - Domain Rules (Ariadne):\n", .{});
    std.debug.print("  │ Retry logic\n", .{});
    std.debug.print("  │ Response formats\n", .{});
    std.debug.print("  │ Payment validation\n", .{});
    std.debug.print("  └─> Business logic\n\n", .{});

    std.debug.print("All layers compose into single ConstraintIR for enforcement.\n", .{});
}

fn print_use_cases() void {
    std.debug.print("When to Use Each:\n\n", .{});

    std.debug.print("Use Extraction When:\n", .{});
    std.debug.print("  - Learning from existing codebase\n", .{});
    std.debug.print("  - Maintaining consistency automatically\n", .{});
    std.debug.print("  - Pattern discovery needed\n\n", .{});

    std.debug.print("Use JSON When:\n", .{});
    std.debug.print("  - Simple configuration needed\n", .{});
    std.debug.print("  - Programmatic generation required\n", .{});
    std.debug.print("  - Tool integration important\n\n", .{});

    std.debug.print("Use Ariadne When:\n", .{});
    std.debug.print("  - Complex business rules\n", .{});
    std.debug.print("  - Query-based patterns\n", .{});
    std.debug.print("  - Type-safe definitions needed\n\n", .{});

    std.debug.print("Use All Three When:\n", .{});
    std.debug.print("  - Building production system\n", .{});
    std.debug.print("  - Need comprehensive coverage\n", .{});
    std.debug.print("  - Balancing automation and control\n", .{});
}
