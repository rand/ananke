//! Basic constraint extraction example
//!
//! Demonstrates how to extract constraints from source code using Clew.
//!
//! Build: zig build-exe zig_basic_extraction.zig
//! Run: ./zig_basic_extraction

const std = @import("std");
const ananke = @import("ananke");

pub fn main() !void {
    // Setup allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== Ananke Constraint Extraction Example ===\n\n", .{});

    // Sample TypeScript code to analyze
    const typescript_source =
        \\export async function validateUser(email: string, password: string): Promise<User> {
        \\    // Input validation
        \\    if (!email || !email.includes('@')) {
        \\        throw new Error('Invalid email format');
        \\    }
        \\    
        \\    if (!password || password.length < 8) {
        \\        throw new Error('Password must be at least 8 characters');
        \\    }
        \\    
        \\    // Database query
        \\    const user = await database.findUser(email);
        \\    if (!user) {
        \\        throw new Error('User not found');
        \\    }
        \\    
        \\    // Password verification
        \\    const isValid = await bcrypt.compare(password, user.passwordHash);
        \\    if (!isValid) {
        \\        throw new Error('Invalid credentials');
        \\    }
        \\    
        \\    return user;
        \\}
    ;

    // Initialize Clew engine
    std.debug.print("Initializing Clew constraint extractor...\n", .{});
    var clew = try ananke.clew.Clew.init(allocator);
    defer clew.deinit();

    // Extract constraints from TypeScript code
    std.debug.print("Extracting constraints from source code...\n", .{});
    var constraint_set = try clew.extractFromCode(typescript_source, "typescript");
    defer constraint_set.deinit();

    // Print results
    std.debug.print("\n✓ Extracted {} constraints\n\n", .{constraint_set.constraints.items.len});

    // Group constraints by kind
    var by_kind = std.AutoHashMap(ananke.ConstraintKind, std.ArrayList(ananke.Constraint)).init(allocator);
    defer {
        var iter = by_kind.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.deinit(allocator);
        }
        by_kind.deinit();
    }

    for (constraint_set.constraints.items) |constraint| {
        const entry = try by_kind.getOrPut(constraint.kind);
        if (!entry.found_existing) {
            entry.value_ptr.* = std.ArrayList(ananke.Constraint){};
        }
        try entry.value_ptr.append(allocator, constraint);
    }

    // Display grouped results
    std.debug.print("Constraints by category:\n", .{});
    std.debug.print("=" ** 60 ++ "\n", .{});

    var kind_iter = by_kind.iterator();
    while (kind_iter.next()) |entry| {
        const kind = entry.key_ptr.*;
        const constraints = entry.value_ptr.items;

        std.debug.print("\n{s} ({d} constraints):\n", .{ @tagName(kind), constraints.len });

        for (constraints) |constraint| {
            std.debug.print("  • {s}\n", .{constraint.description});
            std.debug.print("    Source: {s}, Confidence: {d:.2}\n", .{ @tagName(constraint.source), constraint.confidence });
        }
    }

    std.debug.print("\n" ++ "=" ** 60 ++ "\n", .{});
    std.debug.print("\n✓ Constraint extraction complete\n", .{});
}
