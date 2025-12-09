const std = @import("std");
const testing = std.testing;
const clew_mod = @import("clew");
const ananke = @import("ananke");

const HoleDetector = clew_mod.HoleDetector;
const HoleOrigin = ananke.HoleOrigin;

test "HoleDetector detects Python TODO comments" {
    const source =
        \\def calculate_area(width, height):
        \\    # TODO: implement area calculation
        \\    pass
        \\
    ;

    var detector = HoleDetector.init(testing.allocator, .python);
    var holes = try detector.detectHoles(source, "test.py");
    defer holes.deinit();

    // Should detect both "TODO" and "pass"
    try testing.expect(holes.holes.items.len >= 1);

    // Check that at least one hole has user_marked origin
    var found_user_marked = false;
    for (holes.holes.items) |hole| {
        if (hole.origin == .user_marked) {
            found_user_marked = true;
            break;
        }
    }
    try testing.expect(found_user_marked);
}

test "HoleDetector detects Zig panic TODO" {
    const source =
        \\pub fn process() void {
        \\    @panic("TODO");
        \\}
        \\
    ;

    var detector = HoleDetector.init(testing.allocator, .zig);
    var holes = try detector.detectHoles(source, "test.zig");
    defer holes.deinit();

    try testing.expect(holes.holes.items.len >= 1);
    try testing.expectEqual(HoleOrigin.user_marked, holes.holes.items[0].origin);
}

test "HoleDetector detects Rust todo macro" {
    const source =
        \\fn calculate() -> i32 {
        \\    todo!()
        \\}
        \\
    ;

    var detector = HoleDetector.init(testing.allocator, .rust);
    var holes = try detector.detectHoles(source, "test.rs");
    defer holes.deinit();

    try testing.expect(holes.holes.items.len >= 1);
    try testing.expectEqual(HoleOrigin.user_marked, holes.holes.items[0].origin);
}

test "HoleDetector detects TypeScript TODO comment" {
    const source =
        \\function process(): void {
        \\    // TODO: implement this
        \\}
        \\
    ;

    var detector = HoleDetector.init(testing.allocator, .typescript);
    var holes = try detector.detectHoles(source, "test.ts");
    defer holes.deinit();

    try testing.expect(holes.holes.items.len >= 1);
    try testing.expectEqual(HoleOrigin.user_marked, holes.holes.items[0].origin);
}

test "HoleDetector tracks line and column positions" {
    const source =
        \\def foo():
        \\    TODO
        \\
    ;

    var detector = HoleDetector.init(testing.allocator, .python);
    var holes = try detector.detectHoles(source, "test.py");
    defer holes.deinit();

    try testing.expect(holes.holes.items.len >= 1);

    const hole = holes.holes.items[0];
    try testing.expectEqual(@as(u32, 2), hole.location.start_line);
    try testing.expect(hole.location.start_column > 0);
}

test "HoleDetector handles empty source" {
    const source = "";

    var detector = HoleDetector.init(testing.allocator, .python);
    var holes = try detector.detectHoles(source, "test.py");
    defer holes.deinit();

    try testing.expectEqual(@as(usize, 0), holes.holes.items.len);
}

test "HoleDetector handles source without holes" {
    const source =
        \\def calculate_area(width, height):
        \\    return width * height
        \\
    ;

    var detector = HoleDetector.init(testing.allocator, .python);
    var holes = try detector.detectHoles(source, "test.py");
    defer holes.deinit();

    try testing.expectEqual(@as(usize, 0), holes.holes.items.len);
}
