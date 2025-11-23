// Claude Integration Example
// Demonstrates how to use Claude API for semantic analysis and conflict resolution

const std = @import("std");
const claude_api = @import("claude");
const http = @import("http");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.log.info("=== Ananke Claude Integration Example ===\n", .{});

    // Get API key from environment
    const api_key = std.process.getEnvVarOwned(allocator, "ANTHROPIC_API_KEY") catch |err| {
        std.log.err("Error: ANTHROPIC_API_KEY environment variable not set", .{});
        std.log.err("Please set it with: export ANTHROPIC_API_KEY=your-api-key-here", .{});
        return err;
    };
    defer allocator.free(api_key);

    std.log.info("API key loaded from environment\n", .{});

    // Initialize Claude client
    const config = claude_api.ClaudeConfig{
        .api_key = api_key,
        .max_tokens = 2048,
        .temperature = 0.7,
    };

    var client = try claude_api.ClaudeClient.init(allocator, config);
    defer client.deinit();

    std.log.info("Claude client initialized\n", .{});

    // Example 1: Analyze code for semantic constraints
    try example1_analyzeCode(&client, allocator);

    std.log.info("\n", .{});

    // Example 2: Analyze test intent
    try example2_analyzeTests(&client, allocator);

    std.log.info("\n", .{});

    // Example 3: Resolve constraint conflicts
    try example3_resolveConflicts(&client, allocator);

    std.log.info("\n=== All examples completed successfully ===\n", .{});
}

fn example1_analyzeCode(client: *claude_api.ClaudeClient, allocator: std.mem.Allocator) !void {
    std.log.info("--- Example 1: Analyzing TypeScript Code ---\n", .{});

    const typescript_code =
        \\function processUser(user: any) {
        \\    if (user.name == null) {
        \\        throw new Error("Name is required");
        \\    }
        \\    return user.name.toUpperCase();
        \\}
    ;

    std.log.info("Code to analyze:\n{s}\n", .{typescript_code});

    const constraints = try client.analyzeCode(typescript_code, "typescript");
    defer allocator.free(constraints);

    std.log.info("Found {d} constraints:\n", .{constraints.len});

    for (constraints, 0..) |constraint, i| {
        std.log.info("  {d}. [{s}] {s}: {s}", .{
            i + 1,
            @tagName(constraint.severity),
            constraint.name,
            constraint.description,
        });
        std.log.info("     (confidence: {d:.2})\n", .{constraint.confidence});
    }
}

fn example2_analyzeTests(client: *claude_api.ClaudeClient, allocator: std.mem.Allocator) !void {
    std.log.info("--- Example 2: Analyzing Test Intent ---\n", .{});

    const test_code =
        \\test "user name must not be null" {
        \\    const user = User{ .name = null, .age = 25 };
        \\    try expect(user.name != null);
        \\}
        \\
        \\test "user name should be at least 2 characters" {
        \\    const user = User{ .name = "A", .age = 25 };
        \\    try expect(user.name.len >= 2);
        \\}
    ;

    std.log.info("Test code to analyze:\n{s}\n", .{test_code});

    const analysis = try client.analyzeTestIntent(test_code);
    defer {
        allocator.free(analysis.constraints);
        allocator.free(analysis.intent_description);
    }

    std.log.info("Test intent: {s}\n", .{analysis.intent_description});
    std.log.info("Extracted {d} constraints:\n", .{analysis.constraints.len});

    for (analysis.constraints, 0..) |constraint, i| {
        std.log.info("  {d}. [{s}] {s}: {s}", .{
            i + 1,
            @tagName(constraint.severity),
            constraint.name,
            constraint.description,
        });
        std.log.info("     (confidence: {d:.2})\n", .{constraint.confidence});
    }
}

fn example3_resolveConflicts(client: *claude_api.ClaudeClient, allocator: std.mem.Allocator) !void {
    std.log.info("--- Example 3: Resolving Constraint Conflicts ---\n", .{});

    // Create some example conflicts
    const conflicts = [_]claude_api.ConflictDescription{
        .{
            .constraint_a_name = "strict_null_checks",
            .constraint_a_desc = "All values must be checked for null before use",
            .constraint_b_name = "performance_optimization",
            .constraint_b_desc = "Skip null checks for performance-critical paths",
            .issue = "Null checking adds overhead but is required for safety",
        },
        .{
            .constraint_a_name = "use_any_type",
            .constraint_a_desc = "Allow 'any' type for flexible interfaces",
            .constraint_b_name = "strict_typing",
            .constraint_b_desc = "All types must be explicitly defined, no 'any'",
            .issue = "Type safety conflicts with interface flexibility",
        },
    };

    std.log.info("Conflicts to resolve:\n", .{});
    for (conflicts, 0..) |conflict, i| {
        std.log.info("  {d}. {s} vs {s}", .{ i + 1, conflict.constraint_a_name, conflict.constraint_b_name });
        std.log.info("     Issue: {s}\n", .{conflict.issue});
    }

    const resolution = try client.suggestResolution(&conflicts);
    defer allocator.free(resolution.actions);

    std.log.info("\nSuggested resolutions ({d} actions):\n", .{resolution.actions.len});

    for (resolution.actions, 0..) |action, i| {
        std.log.info("  {d}. Action: {s}", .{ i + 1, @tagName(action) });

        switch (action) {
            .disable_a => |info| {
                std.log.info("     Disable constraint A for conflict {d}", .{info.conflict_index});
                std.log.info("     Reasoning: {s}\n", .{info.reasoning});
            },
            .disable_b => |info| {
                std.log.info("     Disable constraint B for conflict {d}", .{info.conflict_index});
                std.log.info("     Reasoning: {s}\n", .{info.reasoning});
            },
            .merge => |info| {
                std.log.info("     Merge constraints for conflict {d}", .{info.conflict_index});
                std.log.info("     Reasoning: {s}\n", .{info.reasoning});
            },
            .modify_a => |info| {
                std.log.info("     Modify constraint A for conflict {d}", .{info.conflict_index});
                std.log.info("     Reasoning: {s}\n", .{info.reasoning});
            },
            .modify_b => |info| {
                std.log.info("     Modify constraint B for conflict {d}", .{info.conflict_index});
                std.log.info("     Reasoning: {s}\n", .{info.reasoning});
            },
        }
    }
}
