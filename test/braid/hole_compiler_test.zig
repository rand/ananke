const std = @import("std");
const testing = std.testing;
const ananke = @import("ananke");
const braid = @import("braid");

const HoleCompiler = braid.HoleCompiler;
const Hole = ananke.Hole;
const HoleSet = ananke.HoleSet;
const HoleScale = ananke.HoleScale;
const HoleOrigin = ananke.HoleOrigin;

test "HoleCompiler compiles holes to ConstraintIR" {
    var hole_set = HoleSet.init(testing.allocator);
    defer hole_set.deinit();

    const test_hole = Hole{
        .id = 1,
        .name = "test_hole",
        .scale = .expression,
        .origin = .user_marked,
        .expected_type = "int",
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

    try hole_set.add(test_hole);

    var compiler = HoleCompiler.init(testing.allocator);
    const ir = try compiler.compile(&hole_set);
    defer {
        if (ir.hole_specs.len > 0) {
            testing.allocator.free(ir.hole_specs);
        }
    }

    try testing.expectEqual(@as(usize, 1), ir.hole_specs.len);
    try testing.expect(ir.supports_refinement);
    try testing.expectEqual(@as(u64, 1), ir.hole_specs[0].hole_id);
}

test "HoleCompiler handles empty HoleSet" {
    var hole_set = HoleSet.init(testing.allocator);
    defer hole_set.deinit();

    var compiler = HoleCompiler.init(testing.allocator);
    const ir = try compiler.compile(&hole_set);
    defer {
        if (ir.hole_specs.len > 0) {
            testing.allocator.free(ir.hole_specs);
        }
    }

    try testing.expectEqual(@as(usize, 0), ir.hole_specs.len);
    try testing.expect(ir.supports_refinement);
}

test "HoleCompiler compiles multiple holes" {
    var hole_set = HoleSet.init(testing.allocator);
    defer hole_set.deinit();

    const hole1 = Hole{
        .id = 1,
        .scale = .expression,
        .origin = .user_marked,
        .expected_type = "int",
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

    const hole2 = Hole{
        .id = 2,
        .scale = .statement,
        .origin = .user_marked,
        .expected_type = "string",
        .location = .{
            .file_path = "test.zig",
            .start_line = 20,
            .start_column = 5,
            .end_line = 20,
            .end_column = 15,
        },
        .provenance = .{
            .created_at = std.time.timestamp(),
            .created_by = "test",
        },
    };

    try hole_set.add(hole1);
    try hole_set.add(hole2);

    var compiler = HoleCompiler.init(testing.allocator);
    const ir = try compiler.compile(&hole_set);
    defer {
        if (ir.hole_specs.len > 0) {
            testing.allocator.free(ir.hole_specs);
        }
    }

    try testing.expectEqual(@as(usize, 2), ir.hole_specs.len);
    try testing.expectEqual(@as(u64, 1), ir.hole_specs[0].hole_id);
    try testing.expectEqual(@as(u64, 2), ir.hole_specs[1].hole_id);
}
