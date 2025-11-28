//! Test IR cache behavior and performance characteristics

const std = @import("std");
const testing = std.testing;
const Braid = @import("braid").Braid;
const Constraint = @import("ananke").Constraint;

test "IR cache: performance scaling with constraint count" {
    const allocator = testing.allocator;
    
    var braid = try Braid.init(allocator);
    defer braid.deinit();
    
    // Test with increasing constraint counts
    const counts = [_]usize{ 1, 10, 50, 100, 500, 1000 };
    
    std.debug.print("\n=== IR Cache Performance Scaling Test ===\n", .{});
    
    for (counts) |count| {
        const constraints = try generateConstraints(allocator, count);
        defer {
            for (constraints) |*c| {
                allocator.free(c.description);
            }
            allocator.free(constraints);
        }
        
        // Cold cache (first compilation)
        const cold_start = std.time.nanoTimestamp();
        var cold_ir = try braid.compile(constraints);
        const cold_end = std.time.nanoTimestamp();
        cold_ir.deinit(allocator);
        
        const cold_us = @divTrunc(cold_end - cold_start, 1000);
        
        // Warm cache (second compilation)
        const warm_start = std.time.nanoTimestamp();
        var warm_ir = try braid.compile(constraints);
        const warm_end = std.time.nanoTimestamp();
        warm_ir.deinit(allocator);
        
        const warm_us = @divTrunc(warm_end - warm_start, 1000);
        const speedup = @as(f64, @floatFromInt(cold_us)) / @as(f64, @floatFromInt(warm_us));
        
        std.debug.print("{} constraints: cold={d}μs, warm={d}μs, speedup={d:.1}x\n", 
            .{count, cold_us, warm_us, speedup});
    }
}

fn generateConstraints(allocator: std.mem.Allocator, count: usize) ![]Constraint {
    var constraints = try std.ArrayList(Constraint).initCapacity(allocator, count);
    errdefer constraints.deinit(allocator);

    for (0..count) |i| {
        const name = try std.fmt.allocPrint(allocator, "constraint_{}", .{i});
        const desc = try std.fmt.allocPrint(allocator, "Test constraint number {}", .{i});
        const constraint = Constraint{
            .name = name,
            .description = desc,
            .kind = .syntactic,
            .priority = .Medium,
            .severity = .err,
        };
        try constraints.append(allocator, constraint);
    }

    return try constraints.toOwnedSlice(allocator);
}
