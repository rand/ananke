const std = @import("std");
const ananke = @import("ananke");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== Ananke Example 02: Claude-Enhanced Analysis ===\n\n", .{});

    // Read the sample Python file
    const file_path = "sample.py";
    const source_code = try std.fs.cwd().readFileAlloc(allocator, file_path, 1024 * 1024);
    defer allocator.free(source_code);

    std.debug.print("Analyzing file: {s}\n", .{file_path});
    std.debug.print("File size: {} bytes\n\n", .{source_code.len});

    // First: Extract WITHOUT Claude (static analysis only)
    std.debug.print("=== Phase 1: Static Analysis (No LLM) ===\n\n", .{});

    var clew_static = try ananke.clew.Clew.init(allocator);
    defer clew_static.deinit();

    var static_constraints = try clew_static.extractFromCode(source_code, "python");
    defer static_constraints.deinit();

    std.debug.print("Static analysis found {} constraints\n\n", .{static_constraints.constraints.items.len});

    // Display static constraints
    for (static_constraints.constraints.items, 0..) |constraint, i| {
        std.debug.print("Static Constraint {}: {s}\n", .{ i + 1, constraint.name });
        std.debug.print("  Kind: {s}\n", .{@tagName(constraint.kind)});
        std.debug.print("  Description: {s}\n\n", .{constraint.description});
    }

    // Second: Extract WITH Claude (semantic analysis)
    std.debug.print("\n=== Phase 2: With Claude Analysis ===\n\n", .{});

    // Check for API key
    const api_key = std.posix.getenv("ANTHROPIC_API_KEY");

    if (api_key == null) {
        std.debug.print("ANTHROPIC_API_KEY not set - skipping Claude analysis\n", .{});
        std.debug.print("\nTo run with Claude:\n", .{});
        std.debug.print("  export ANTHROPIC_API_KEY='your-key-here'\n", .{});
        std.debug.print("  zig build run\n\n", .{});

        std.debug.print("=== What Claude Would Find ===\n\n", .{});
        print_expected_semantic_constraints();
    } else {
        std.debug.print("Claude API key found - semantic analysis enabled\n\n", .{});

        // Initialize Clew with Claude client
        var clew_semantic = try ananke.clew.Clew.init(allocator);
        defer clew_semantic.deinit();

        // TODO: In a real implementation, this would make Claude API calls
        // For now, we demonstrate what it WOULD extract
        std.debug.print("Note: Claude integration is placeholder - showing expected output\n\n", .{});
        print_expected_semantic_constraints();
    }

    // Compare the two approaches
    std.debug.print("\n=== Comparison: Static vs. Semantic Analysis ===\n\n", .{});

    std.debug.print("Static Analysis (No LLM):\n", .{});
    std.debug.print("  ✓ Fast (< 100ms)\n", .{});
    std.debug.print("  ✓ Deterministic\n", .{});
    std.debug.print("  ✓ Free\n", .{});
    std.debug.print("  ✓ Finds syntactic patterns\n", .{});
    std.debug.print("  ✗ Misses business rules\n", .{});
    std.debug.print("  ✗ Can't understand intent\n", .{});
    std.debug.print("  ✗ Limited semantic understanding\n\n", .{});

    std.debug.print("Semantic Analysis (With Claude):\n", .{});
    std.debug.print("  ✓ Understands business logic\n", .{});
    std.debug.print("  ✓ Extracts implicit constraints\n", .{});
    std.debug.print("  ✓ Infers intent from comments\n", .{});
    std.debug.print("  ✓ Recognizes domain patterns\n", .{});
    std.debug.print("  ✗ Slower (~2 seconds)\n", .{});
    std.debug.print("  ✗ Costs per request\n", .{});
    std.debug.print("  ✗ Non-deterministic\n\n", .{});

    std.debug.print("=== Recommended Approach ===\n\n", .{});
    std.debug.print("Use BOTH:\n", .{});
    std.debug.print("1. Static analysis for fast, reliable structural constraints\n", .{});
    std.debug.print("2. Claude for semantic understanding of complex business logic\n", .{});
    std.debug.print("3. Combine results for comprehensive constraint extraction\n", .{});
}

fn print_expected_semantic_constraints() void {
    std.debug.print("Semantic constraints Claude would extract:\n\n", .{});

    std.debug.print("1. Business Rule: High-Value Payment Threshold\n", .{});
    std.debug.print("   - Payments over $10,000 require additional verification\n", .{});
    std.debug.print("   - Confidence: 0.95 (explicitly stated in comment)\n", .{});
    std.debug.print("   - Kind: operational\n\n", .{});

    std.debug.print("2. Security Rule: Rate Limiting Policy\n", .{});
    std.debug.print("   - 3 failed attempts within 24 hours triggers rate limit\n", .{});
    std.debug.print("   - Confidence: 0.90 (implied by code + comment)\n", .{});
    std.debug.print("   - Kind: security\n\n", .{});

    std.debug.print("3. Compliance Rule: PCI-DSS\n", .{});
    std.debug.print("   - Never log full card numbers\n", .{});
    std.debug.print("   - Confidence: 1.0 (explicit comment)\n", .{});
    std.debug.print("   - Kind: security\n\n", .{});

    std.debug.print("4. Business Rule: Refund Window\n", .{});
    std.debug.print("   - Refunds only allowed within 90 days\n", .{});
    std.debug.print("   - Confidence: 0.92 (stated in docstring)\n", .{});
    std.debug.print("   - Kind: operational\n\n", .{});

    std.debug.print("5. Business Rule: Supported Currencies\n", .{});
    std.debug.print("   - Only USD, EUR, GBP accepted\n", .{});
    std.debug.print("   - Confidence: 0.88 (from code + comment)\n", .{});
    std.debug.print("   - Kind: semantic\n\n", .{});

    std.debug.print("6. Performance Constraint: Fraud Detection\n", .{});
    std.debug.print("   - Must complete in < 100ms\n", .{});
    std.debug.print("   - Confidence: 0.85 (from comment)\n", .{});
    std.debug.print("   - Kind: operational\n\n", .{});

    std.debug.print("7. Data Flow Constraint: Idempotency\n", .{});
    std.debug.print("   - Payment processing must be idempotent\n", .{});
    std.debug.print("   - Confidence: 0.80 (implied by comment)\n", .{});
    std.debug.print("   - Kind: semantic\n\n", .{});

    std.debug.print("8. Security Constraint: TLS Required\n", .{});
    std.debug.print("   - Payment gateway calls must use secure connection\n", .{});
    std.debug.print("   - Confidence: 0.95 (from comment)\n", .{});
    std.debug.print("   - Kind: security\n\n", .{});
}
