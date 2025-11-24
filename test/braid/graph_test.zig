// Tests for Braid constraint graph algorithms
const std = @import("std");
const testing = std.testing;
const ananke = @import("ananke");
const braid = @import("braid");

// Import Braid types
const Constraint = ananke.Constraint;
const ConstraintKind = ananke.ConstraintKind;
const ConstraintSource = ananke.ConstraintSource;
const EnforcementType = ananke.EnforcementType;
const ConstraintPriority = ananke.ConstraintPriority;

test "topological sort: simple linear dependency A -> B -> C" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create constraint graph manually
    var graph = braid.ConstraintGraph.init(allocator);
    defer graph.deinit();

    // Add three nodes
    _ = try graph.addNode(Constraint.init(0, "constraint_a", "First constraint"));
    _ = try graph.addNode(Constraint.init(1, "constraint_b", "Second constraint"));
    _ = try graph.addNode(Constraint.init(2, "constraint_c", "Third constraint"));

    // Add edges: A -> B -> C
    try graph.addEdge(0, 1);
    try graph.addEdge(1, 2);

    // Perform topological sort
    const sorted = try graph.topologicalSort();
    defer allocator.free(sorted);

    // Expected order: A (0), B (1), C (2)
    try testing.expectEqual(@as(usize, 3), sorted.len);
    try testing.expectEqual(@as(usize, 0), sorted[0]);
    try testing.expectEqual(@as(usize, 1), sorted[1]);
    try testing.expectEqual(@as(usize, 2), sorted[2]);
}

test "topological sort: diamond dependency A -> (B,C) -> D" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var graph = braid.ConstraintGraph.init(allocator);
    defer graph.deinit();

    // Add four nodes
    _ = try graph.addNode(Constraint.init(0, "constraint_a", "Root"));
    _ = try graph.addNode(Constraint.init(1, "constraint_b", "Left branch"));
    _ = try graph.addNode(Constraint.init(2, "constraint_c", "Right branch"));
    _ = try graph.addNode(Constraint.init(3, "constraint_d", "Convergence"));

    // Add edges: A -> B, A -> C, B -> D, C -> D
    try graph.addEdge(0, 1);
    try graph.addEdge(0, 2);
    try graph.addEdge(1, 3);
    try graph.addEdge(2, 3);

    const sorted = try graph.topologicalSort();
    defer allocator.free(sorted);

    // Expected: A first, D last, B and C in middle
    try testing.expectEqual(@as(usize, 4), sorted.len);
    try testing.expectEqual(@as(usize, 0), sorted[0]); // A must be first
    try testing.expectEqual(@as(usize, 3), sorted[3]); // D must be last

    // Check that all nodes are present
    var found_count: usize = 0;
    for (sorted) |idx| {
        if (idx < 4) found_count += 1;
    }
    try testing.expectEqual(@as(usize, 4), found_count);
}

test "topological sort: no dependencies (all independent)" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var graph = braid.ConstraintGraph.init(allocator);
    defer graph.deinit();

    // Add five independent nodes
    _ = try graph.addNode(Constraint.init(0, "constraint_0", "Independent 0"));
    _ = try graph.addNode(Constraint.init(1, "constraint_1", "Independent 1"));
    _ = try graph.addNode(Constraint.init(2, "constraint_2", "Independent 2"));
    _ = try graph.addNode(Constraint.init(3, "constraint_3", "Independent 3"));
    _ = try graph.addNode(Constraint.init(4, "constraint_4", "Independent 4"));

    // No edges added - all are independent

    const sorted = try graph.topologicalSort();
    defer allocator.free(sorted);

    // All nodes should be in result
    try testing.expectEqual(@as(usize, 5), sorted.len);

    // Verify all node indices are present
    var found = [_]bool{ false, false, false, false, false };
    for (sorted) |idx| {
        if (idx < 5) {
            found[idx] = true;
        }
    }
    for (found) |f| {
        try testing.expect(f);
    }
}

test "topological sort: cyclic dependency A -> B -> C -> A (detects cycle)" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var graph = braid.ConstraintGraph.init(allocator);
    defer graph.deinit();

    // Add three nodes
    _ = try graph.addNode(Constraint.init(0, "constraint_a", "In cycle"));
    _ = try graph.addNode(Constraint.init(1, "constraint_b", "In cycle"));
    _ = try graph.addNode(Constraint.init(2, "constraint_c", "In cycle"));

    // Create cycle: A -> B -> C -> A
    try graph.addEdge(0, 1);
    try graph.addEdge(1, 2);
    try graph.addEdge(2, 0);

    // Topological sort should detect cycle but return partial ordering
    const sorted = try graph.topologicalSort();
    defer allocator.free(sorted);

    // Should still return all nodes (with partial ordering)
    try testing.expectEqual(@as(usize, 3), sorted.len);

    // Verify detectCycle also identifies the cycle
    const has_cycle = try graph.detectCycle();
    try testing.expect(has_cycle);
}

test "topological sort: large graph (100 nodes)" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var graph = braid.ConstraintGraph.init(allocator);
    defer graph.deinit();

    const node_count = 100;

    // Add 100 nodes
    var i: u32 = 0;
    while (i < node_count) : (i += 1) {
        var buf: [32]u8 = undefined;
        const name = try std.fmt.bufPrint(&buf, "constraint_{}", .{i});
        _ = try graph.addNode(Constraint.init(i, name, "Large graph test"));
    }

    // Create linear dependency chain for predictability
    i = 0;
    while (i < node_count - 1) : (i += 1) {
        try graph.addEdge(i, i + 1);
    }

    const sorted = try graph.topologicalSort();
    defer allocator.free(sorted);

    // All nodes should be present
    try testing.expectEqual(@as(usize, node_count), sorted.len);

    // Should be in order 0,1,2,...,99
    for (sorted, 0..) |node_idx, order| {
        try testing.expectEqual(order, node_idx);
    }
}

test "cycle detection: simple cycle" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var graph = braid.ConstraintGraph.init(allocator);
    defer graph.deinit();

    // Create simple 2-node cycle
    _ = try graph.addNode(Constraint.init(0, "a", "test"));
    _ = try graph.addNode(Constraint.init(1, "b", "test"));

    try graph.addEdge(0, 1);
    try graph.addEdge(1, 0);

    const has_cycle = try graph.detectCycle();
    try testing.expect(has_cycle);
}

test "cycle detection: no cycle in acyclic graph" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var graph = braid.ConstraintGraph.init(allocator);
    defer graph.deinit();

    // Create acyclic graph: A -> B -> C
    _ = try graph.addNode(Constraint.init(0, "a", "test"));
    _ = try graph.addNode(Constraint.init(1, "b", "test"));
    _ = try graph.addNode(Constraint.init(2, "c", "test"));

    try graph.addEdge(0, 1);
    try graph.addEdge(1, 2);

    const has_cycle = try graph.detectCycle();
    try testing.expect(!has_cycle);
}

test "graph operations: add node and edge" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var graph = braid.ConstraintGraph.init(allocator);
    defer graph.deinit();

    // Add nodes
    const idx0 = try graph.addNode(Constraint.init(0, "test_0", "desc"));
    const idx1 = try graph.addNode(Constraint.init(1, "test_1", "desc"));

    try testing.expectEqual(@as(usize, 0), idx0);
    try testing.expectEqual(@as(usize, 1), idx1);
    try testing.expectEqual(@as(usize, 2), graph.nodes.items.len);

    // Add edge
    try graph.addEdge(0, 1);
    try testing.expectEqual(@as(usize, 1), graph.edges.items.len);

    const edge = graph.edges.items[0];
    try testing.expectEqual(@as(usize, 0), edge.from);
    try testing.expectEqual(@as(usize, 1), edge.to);
}
