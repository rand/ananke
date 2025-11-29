//! Full pipeline example: Extract → Compile → Generate llguidance schema
//!
//! Demonstrates the complete workflow from source code to llguidance-ready IR.
//!
//! Build: zig build-exe zig_full_pipeline.zig
//! Run: ./zig_full_pipeline

const std = @import("std");
const ananke = @import("ananke");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== Ananke Full Pipeline Example ===\n\n", .{});

    // Sample Python code with security requirements
    const python_source =
        \\def process_payment(amount: float, user_id: str, card_token: str) -> dict:
        \\    """Process a payment transaction with security checks."""
        \\    
        \\    # Input validation
        \\    if amount <= 0:
        \\        raise ValueError("Amount must be positive")
        \\    
        \\    if not user_id or len(user_id) < 10:
        \\        raise ValueError("Invalid user ID")
        \\    
        \\    # Rate limiting check
        \\    if is_rate_limited(user_id):
        \\        raise RateLimitError("Too many requests")
        \\    
        \\    # Verify user authentication
        \\    user = authenticate_user(user_id)
        \\    if not user.is_verified:
        \\        raise AuthenticationError("User not verified")
        \\    
        \\    # Process payment with external service
        \\    try:
        \\        result = payment_gateway.charge(
        \\            amount=amount,
        \\            token=card_token,
        \\            user_id=user_id
        \\        )
        \\        
        \\        # Log transaction
        \\        log_transaction(user_id, amount, result.transaction_id)
        \\        
        \\        return {
        \\            "success": True,
        \\            "transaction_id": result.transaction_id,
        \\            "amount": amount
        \\        }
        \\    except PaymentError as e:
        \\        log_error(user_id, str(e))
        \\        raise
    ;

    // Step 1: Initialize Ananke
    std.debug.print("Step 1: Initializing Ananke engines...\n", .{});
    var ananke_instance = try ananke.Ananke.init(allocator);
    defer ananke_instance.deinit();
    std.debug.print("  ✓ Clew, Braid, and Ariadne initialized\n\n", .{});

    // Step 2: Extract constraints
    std.debug.print("Step 2: Extracting constraints from Python code...\n", .{});
    const start_extract = std.time.milliTimestamp();

    var constraint_set = try ananke_instance.extract(python_source, "python");
    defer constraint_set.deinit();

    const extract_time = std.time.milliTimestamp() - start_extract;
    std.debug.print("  ✓ Extracted {} constraints in {}ms\n\n", .{ constraint_set.constraints.items.len, extract_time });

    // Display extracted constraints
    std.debug.print("  Extracted constraints:\n", .{});
    for (constraint_set.constraints.items, 0..) |constraint, i| {
        std.debug.print("    {}. {s} ({s})\n", .{ i + 1, constraint.name, @tagName(constraint.kind) });
    }
    std.debug.print("\n", .{});

    // Step 3: Compile constraints to IR
    std.debug.print("Step 3: Compiling constraints to ConstraintIR...\n", .{});
    const start_compile = std.time.milliTimestamp();

    var ir = try ananke_instance.compile(constraint_set.constraints.items);
    defer ir.deinit(allocator);

    const compile_time = std.time.milliTimestamp() - start_compile;
    std.debug.print("  ✓ Compiled in {}ms\n\n", .{compile_time});

    // Display IR components
    std.debug.print("  ConstraintIR components:\n", .{});

    if (ir.json_schema) |schema| {
        std.debug.print("    • JSON Schema: type={s}\n", .{schema.type});
    } else {
        std.debug.print("    • JSON Schema: none\n", .{});
    }

    if (ir.grammar) |grammar| {
        std.debug.print("    • Grammar: {} rules, start={s}\n", .{ grammar.rules.len, grammar.start_symbol });
    } else {
        std.debug.print("    • Grammar: none\n", .{});
    }

    std.debug.print("    • Regex patterns: {}\n", .{ir.regex_patterns.len});

    if (ir.token_masks) |_| {
        std.debug.print("    • Token masks: present\n", .{});
    } else {
        std.debug.print("    • Token masks: none\n", .{});
    }

    std.debug.print("    • Priority: {}\n\n", .{ir.priority});

    // Step 4: Convert to llguidance format
    std.debug.print("Step 4: Converting to llguidance schema...\n", .{});
    const braid = &ananke_instance.braid_engine;
    const llguidance_json = try braid.toLLGuidanceSchema(ir);
    defer allocator.free(llguidance_json);

    std.debug.print("  ✓ Generated llguidance schema\n\n", .{});

    // Display schema (first 500 chars)
    const display_len = @min(llguidance_json.len, 500);
    std.debug.print("  Schema preview ({} bytes total):\n", .{llguidance_json.len});
    std.debug.print("  {s}", .{llguidance_json[0..display_len]});
    if (llguidance_json.len > display_len) {
        std.debug.print("...\n", .{});
    } else {
        std.debug.print("\n", .{});
    }

    // Summary
    std.debug.print("\n" ++ "=" ** 60 ++ "\n", .{});
    std.debug.print("Pipeline Summary:\n", .{});
    std.debug.print("  Total time: {}ms\n", .{extract_time + compile_time});
    std.debug.print("  Constraints: {}\n", .{constraint_set.constraints.items.len});
    std.debug.print("  llguidance schema: {} bytes\n", .{llguidance_json.len});
    std.debug.print("=" ** 60 ++ "\n", .{});

    std.debug.print("\n✓ Full pipeline complete - ready for constrained generation!\n", .{});
}
