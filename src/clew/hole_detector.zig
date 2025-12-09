// Hole detection for typed holes
const std = @import("std");
const root = @import("ananke");
const Hole = root.types.hole.Hole;
const HoleScale = root.types.hole.HoleScale;
const HoleOrigin = root.types.hole.HoleOrigin;
const HoleSet = root.types.hole.HoleSet;
const Location = root.types.hole.Location;
const Provenance = root.types.hole.Provenance;

pub const HoleDetector = struct {
    allocator: std.mem.Allocator,
    language: Language,

    pub const Language = enum {
        python,
        typescript,
        zig,
        rust,
    };

    /// Explicit hole markers by language
    const MarkerList = struct {
        markers: []const []const u8,
    };

    const python_markers = [_][]const u8{
        "...",
        "pass",
        "TODO",
        "FIXME",
        "NotImplementedError",
        "raise NotImplementedError",
    };

    const typescript_markers = [_][]const u8{
        "// TODO",
        "// FIXME",
        "throw new Error('TODO')",
        "throw new Error('Not implemented')",
        "undefined as any",
    };

    const zig_markers = [_][]const u8{
        "@panic(\"TODO\")",
        "@panic(\"not implemented\")",
        "unreachable",
        "// TODO",
        "// FIXME",
    };

    const rust_markers = [_][]const u8{
        "todo!()",
        "unimplemented!()",
        "panic!(\"TODO\")",
        "// TODO",
        "// FIXME",
    };

    pub fn init(allocator: std.mem.Allocator, language: Language) HoleDetector {
        return .{
            .allocator = allocator,
            .language = language,
        };
    }

    /// Detect all holes in source code
    pub fn detectHoles(self: *HoleDetector, source: []const u8, file_path: []const u8) !HoleSet {
        var holes = HoleSet.init(self.allocator);

        // Detect explicit markers
        try self.detectExplicitHoles(source, file_path, &holes);

        return holes;
    }

    fn detectExplicitHoles(
        self: *HoleDetector,
        source: []const u8,
        file_path: []const u8,
        holes: *HoleSet,
    ) !void {
        const markers = switch (self.language) {
            .python => &python_markers,
            .typescript => &typescript_markers,
            .zig => &zig_markers,
            .rust => &rust_markers,
        };

        var line_num: u32 = 1;
        var col_num: u32 = 1;
        var i: usize = 0;

        while (i < source.len) {
            for (markers) |marker| {
                if (i + marker.len <= source.len and
                    std.mem.eql(u8, source[i .. i + marker.len], marker))
                {
                    const hole = Hole{
                        .id = generateHoleId(file_path, line_num, col_num),
                        .scale = inferScale(source, i),
                        .origin = .user_marked,
                        .location = .{
                            .file_path = file_path,
                            .start_line = line_num,
                            .start_column = col_num,
                            .end_line = line_num,
                            .end_column = col_num + @as(u32, @intCast(marker.len)),
                        },
                        .provenance = .{
                            .created_at = std.time.timestamp(),
                            .created_by = "clew",
                            .source_artifact = file_path,
                        },
                    };
                    try holes.add(hole);
                }
            }

            if (source[i] == '\n') {
                line_num += 1;
                col_num = 1;
            } else {
                col_num += 1;
            }
            i += 1;
        }
    }

    fn generateHoleId(file_path: []const u8, line: u32, col: u32) u64 {
        var hasher = std.hash.Wyhash.init(0);
        hasher.update(file_path);
        hasher.update(std.mem.asBytes(&line));
        hasher.update(std.mem.asBytes(&col));
        return hasher.final();
    }

    fn inferScale(source: []const u8, pos: usize) HoleScale {
        // Simple heuristic: look at surrounding context
        // For now, default to expression scale
        _ = source;
        _ = pos;
        return .expression;
    }
};
