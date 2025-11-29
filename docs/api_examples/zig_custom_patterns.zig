//! Custom constraint patterns example
//!
//! Demonstrates creating and using custom constraint patterns.

const std = @import("std");
const ananke = @import("ananke");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== Custom Constraint Patterns Example ===\n\n", .{});

    // Create custom security constraints
    var constraints = std.ArrayList(ananke.Constraint){};
    defer constraints.deinit(allocator);

    // Constraint 1: No console.log in production
    try constraints.append(allocator, ananke.Constraint{
        .id = 1,
        .name = "no_console_log",
        .description = "Avoid console.log statements in production code",
        .kind = .syntactic,
        .source = .User_Defined,
        .severity = .warning,
        .priority = .Medium,
        .confidence = 1.0,
    });

    // Constraint 2: Require error handling
    try constraints.append(allocator, ananke.Constraint{
        .id = 2,
        .name = "require_error_handling",
        .description = "All async functions must have try/catch blocks",
        .kind = .semantic,
        .source = .User_Defined,
        .severity = .err,
        .priority = .High,
        .confidence = 1.0,
    });

    // Constraint 3: Input validation
    try constraints.append(allocator, ananke.Constraint{
        .id = 3,
        .name = "validate_inputs",
        .description = "All public API functions must validate input parameters",
        .kind = .security,
        .source = .User_Defined,
        .severity = .err,
        .priority = .Critical,
        .confidence = 1.0,
    });

    // Constraint 4: No SQL string concatenation
    try constraints.append(allocator, ananke.Constraint{
        .id = 4,
        .name = "no_sql_concat",
        .description = "Avoid SQL query string concatenation (use parameterized queries)",
        .kind = .security,
        .source = .User_Defined,
        .severity = .err,
        .priority = .Critical,
        .confidence = 1.0,
    });

    // Constraint 5: Timeout requirements
    try constraints.append(allocator, ananke.Constraint{
        .id = 5,
        .name = "api_timeout",
        .description = "API calls must complete within 5 seconds",
        .kind = .operational,
        .source = .User_Defined,
        .severity = .warning,
        .priority = .Medium,
        .confidence = 0.8,
    });

    std.debug.print("Created {} custom constraints\n\n", .{constraints.items.len});

    // Display constraints
    for (constraints.items, 0..) |constraint, i| {
        std.debug.print("{}. {s}\n", .{ i + 1, constraint.name });
        std.debug.print("   Kind: {s}, Priority: {s}, Severity: {s}\n", .{ @tagName(constraint.kind), @tagName(constraint.priority), @tagName(constraint.severity) });
        std.debug.print("   Description: {s}\n\n", .{constraint.description});
    }

    // Compile custom constraints
    std.debug.print("Compiling constraints to IR...\n", .{});
    var braid = try ananke.braid.Braid.init(allocator);
    defer braid.deinit();

    var ir = try braid.compile(constraints.items);
    defer ir.deinit(allocator);

    std.debug.print("✓ Compilation complete\n\n", .{});

    // Display IR components
    if (ir.grammar) |grammar| {
        std.debug.print("Generated grammar with {} rules\n", .{grammar.rules.len});
    }

    if (ir.token_masks) |masks| {
        std.debug.print("Token masks generated\n", .{});
        if (masks.forbidden_tokens) |forbidden| {
            std.debug.print("  Forbidden tokens: {}\n", .{forbidden.len});
        }
    }

    std.debug.print("\n✓ Custom pattern example complete\n", .{});
}
