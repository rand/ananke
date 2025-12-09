const std = @import("std");
const testing = std.testing;
const ananke = @import("ananke");

const Hole = ananke.Hole;
const HoleSet = ananke.HoleSet;
const HoleScale = ananke.HoleScale;
const HoleOrigin = ananke.HoleOrigin;
const Confidence = ananke.types.hole.Confidence;

test "HoleScale complexity increases exponentially" {
    try testing.expectEqual(@as(u32, 1), HoleScale.expression.complexity());
    try testing.expectEqual(@as(u32, 4), HoleScale.statement.complexity());
    try testing.expectEqual(@as(u32, 16), HoleScale.block.complexity());
    try testing.expectEqual(@as(u32, 64), HoleScale.function.complexity());
    try testing.expectEqual(@as(u32, 256), HoleScale.module.complexity());
    try testing.expectEqual(@as(u32, 1024), HoleScale.specification.complexity());
}

test "HoleScale requiresDecomposition" {
    try testing.expect(!HoleScale.expression.requiresDecomposition());
    try testing.expect(!HoleScale.statement.requiresDecomposition());
    try testing.expect(!HoleScale.block.requiresDecomposition());
    try testing.expect(HoleScale.function.requiresDecomposition());
    try testing.expect(HoleScale.module.requiresDecomposition());
    try testing.expect(HoleScale.specification.requiresDecomposition());
}

test "Confidence computation" {
    var conf = Confidence{
        .score = 0.0,
        .type_match = 0.9,
        .constraint_satisfaction = 0.8,
        .context_coherence = 0.7,
        .example_similarity = 0.6,
    };

    conf.compute();

    // Expected: 0.9*0.3 + 0.8*0.4 + 0.7*0.2 + 0.6*0.1 = 0.27 + 0.32 + 0.14 + 0.06 = 0.79
    try testing.expectApproxEqRel(@as(f32, 0.79), conf.score, 0.01);
    try testing.expect(!conf.isHighConfidence());
}

test "Confidence high threshold" {
    var conf = Confidence{
        .score = 0.0,
        .type_match = 1.0,
        .constraint_satisfaction = 1.0,
        .context_coherence = 1.0,
        .example_similarity = 1.0,
    };

    conf.compute();

    try testing.expectApproxEqRel(@as(f32, 1.0), conf.score, 0.01);
    try testing.expect(conf.isHighConfidence());
}

test "HoleSet initialization and cleanup" {
    var set = HoleSet.init(testing.allocator);
    defer set.deinit();

    try testing.expectEqual(@as(usize, 0), set.holes.items.len);
}

test "HoleSet add and retrieve holes" {
    var set = HoleSet.init(testing.allocator);
    defer set.deinit();

    const test_hole = Hole{
        .id = 1,
        .scale = .expression,
        .origin = .user_marked,
        .location = .{
            .file_path = "test.zig",
            .start_line = 10,
            .start_column = 5,
            .end_line = 10,
            .end_column = 15,
        },
        .provenance = .{
            .created_at = std.time.timestamp(),
            .created_by = "test",
        },
    };

    try set.add(test_hole);
    try testing.expectEqual(@as(usize, 1), set.holes.items.len);
    try testing.expectEqual(@as(u64, 1), set.holes.items[0].id);
}

test "Hole isResolved checks fill and confidence" {
    const unresolved_hole = Hole{
        .id = 1,
        .scale = .expression,
        .origin = .user_marked,
        .location = .{
            .file_path = "test.zig",
            .start_line = 10,
            .start_column = 5,
            .end_line = 10,
            .end_column = 15,
        },
        .provenance = .{
            .created_at = std.time.timestamp(),
            .created_by = "test",
        },
    };

    try testing.expect(!unresolved_hole.isResolved());

    const resolved_hole = Hole{
        .id = 2,
        .scale = .expression,
        .origin = .user_marked,
        .current_fill = "42",
        .confidence = .{ .score = 0.9 },
        .location = .{
            .file_path = "test.zig",
            .start_line = 10,
            .start_column = 5,
            .end_line = 10,
            .end_column = 15,
        },
        .provenance = .{
            .created_at = std.time.timestamp(),
            .created_by = "test",
        },
    };

    try testing.expect(resolved_hole.isResolved());
}

test "Hole canAutoResolve respects strategy and scale" {
    const auto_resolvable = Hole{
        .id = 1,
        .scale = .expression,
        .origin = .user_marked,
        .resolution_strategy = .llm_complete,
        .location = .{
            .file_path = "test.zig",
            .start_line = 10,
            .start_column = 5,
            .end_line = 10,
            .end_column = 15,
        },
        .provenance = .{
            .created_at = std.time.timestamp(),
            .created_by = "test",
        },
    };

    try testing.expect(auto_resolvable.canAutoResolve());

    const human_required = Hole{
        .id = 2,
        .scale = .expression,
        .origin = .user_marked,
        .resolution_strategy = .human_required,
        .location = .{
            .file_path = "test.zig",
            .start_line = 10,
            .start_column = 5,
            .end_line = 10,
            .end_column = 15,
        },
        .provenance = .{
            .created_at = std.time.timestamp(),
            .created_by = "test",
        },
    };

    try testing.expect(!human_required.canAutoResolve());

    const spec_hole = Hole{
        .id = 3,
        .scale = .specification,
        .origin = .user_marked,
        .resolution_strategy = .llm_complete,
        .location = .{
            .file_path = "test.zig",
            .start_line = 10,
            .start_column = 5,
            .end_line = 10,
            .end_column = 15,
        },
        .provenance = .{
            .created_at = std.time.timestamp(),
            .created_by = "test",
        },
    };

    try testing.expect(!spec_hole.canAutoResolve());
}
