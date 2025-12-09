// Hole detection for typed holes
const std = @import("std");
const root = @import("ananke");
const Hole = root.types.hole.Hole;
const HoleScale = root.types.hole.HoleScale;
const HoleOrigin = root.types.hole.HoleOrigin;
const HoleSet = root.types.hole.HoleSet;
const Location = root.types.hole.Location;
const Provenance = root.types.hole.Provenance;

// Import tree-sitter and semantic detection
const tree_sitter = @import("tree_sitter");
const SemanticHoleDetector = @import("semantic_hole_detector.zig").SemanticHoleDetector;

/// Configuration for hole detection
pub const HoleDetectorConfig = struct {
    /// Enable AST-based semantic hole detection
    enable_semantic_detection: bool = false,
};

pub const HoleDetector = struct {
    allocator: std.mem.Allocator,
    language: Language,
    config: HoleDetectorConfig,

    pub const Language = enum {
        python,
        typescript,
        zig,
        rust,
        javascript,
        go,
        c,
        cpp,
        java,
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

    const javascript_markers = [_][]const u8{
        "// TODO",
        "// FIXME",
        "throw new Error('TODO')",
        "throw new Error('Not implemented')",
        "throw new Error(\"TODO\")",
        "throw new Error(\"Not implemented\")",
    };

    const go_markers = [_][]const u8{
        "panic(\"not implemented\")",
        "panic(\"TODO\")",
        "panic(\"todo\")",
        "// TODO",
        "// FIXME",
    };

    const c_markers = [_][]const u8{
        "/* TODO */",
        "// TODO",
        "// FIXME",
        "assert(false)",
        "assert(0)",
        "abort()",
    };

    const cpp_markers = [_][]const u8{
        "/* TODO */",
        "// TODO",
        "// FIXME",
        "throw std::logic_error(\"Not implemented\")",
        "throw std::runtime_error(\"TODO\")",
        "assert(false)",
    };

    const java_markers = [_][]const u8{
        "throw new UnsupportedOperationException()",
        "throw new UnsupportedOperationException(\"TODO\")",
        "throw new RuntimeException(\"TODO\")",
        "// TODO",
        "// FIXME",
    };

    pub fn init(allocator: std.mem.Allocator, language: Language) HoleDetector {
        return .{
            .allocator = allocator,
            .language = language,
            .config = .{},
        };
    }

    pub fn initWithConfig(allocator: std.mem.Allocator, language: Language, config: HoleDetectorConfig) HoleDetector {
        return .{
            .allocator = allocator,
            .language = language,
            .config = config,
        };
    }

    /// Detect all holes in source code
    pub fn detectHoles(self: *HoleDetector, source: []const u8, file_path: []const u8) !HoleSet {
        var holes = HoleSet.init(self.allocator);

        // Detect explicit markers (always enabled)
        try self.detectExplicitHoles(source, file_path, &holes);

        // Detect semantic holes if enabled
        if (self.config.enable_semantic_detection) {
            try self.detectSemanticHoles(source, file_path, &holes);
        }

        return holes;
    }

    /// Detect semantic holes using tree-sitter AST analysis
    fn detectSemanticHoles(
        self: *HoleDetector,
        source: []const u8,
        file_path: []const u8,
        holes: *HoleSet,
    ) !void {
        // Map HoleDetector.Language to tree-sitter Language
        const ts_lang: tree_sitter.Language = switch (self.language) {
            .python => .python,
            .typescript => .typescript,
            .zig => .zig,
            .rust => .rust,
            .javascript => .javascript,
            .go => .go,
            .c => .c,
            .cpp => .cpp,
            .java => .java,
        };

        // Initialize tree-sitter parser
        var parser = tree_sitter.TreeSitterParser.init(self.allocator, ts_lang) catch |err| {
            std.log.debug("Tree-sitter parser init failed: {}, skipping semantic detection", .{err});
            return;
        };
        defer parser.deinit();

        // Parse the source
        var tree = parser.parse(source) catch |err| {
            std.log.debug("Tree-sitter parse failed: {}, skipping semantic detection", .{err});
            return;
        };
        defer tree.deinit();

        const root_node = tree.rootNode();

        // Run semantic hole detection
        var semantic_detector = SemanticHoleDetector.init(self.allocator);
        const semantic_holes = try semantic_detector.detectAll(root_node, source, ts_lang);
        defer {
            for (semantic_holes) |*sh| {
                var mut_sh = sh.*;
                mut_sh.deinit(self.allocator);
            }
            self.allocator.free(semantic_holes);
        }

        // Convert semantic holes to typed holes
        for (semantic_holes) |semantic_hole| {
            const scale = semanticKindToScale(semantic_hole.kind);
            const origin = semanticKindToOrigin(semantic_hole.kind);

            const hole = Hole{
                .id = generateHoleId(file_path, semantic_hole.location.start_line, semantic_hole.location.start_column),
                .scale = scale,
                .origin = origin,
                .location = .{
                    .file_path = file_path,
                    .start_line = semantic_hole.location.start_line,
                    .start_column = semantic_hole.location.start_column,
                    .end_line = semantic_hole.location.end_line,
                    .end_column = semantic_hole.location.end_column,
                },
                .provenance = .{
                    .created_at = std.time.timestamp(),
                    .created_by = "clew_semantic",
                    .source_artifact = file_path,
                },
                .confidence = .{ .score = semantic_hole.confidence },
            };
            try holes.add(hole);
        }
    }

    /// Convert SemanticHoleKind to HoleScale
    fn semanticKindToScale(kind: SemanticHoleDetector.SemanticHoleKind) HoleScale {
        return switch (kind) {
            .empty_function_body => .function,
            .unimplemented_method => .function,
            .incomplete_match => .block,
            .missing_type_annotation => .expression,
            .missing_await => .expression,
            .unhandled_error => .statement,
        };
    }

    /// Convert SemanticHoleKind to HoleOrigin
    fn semanticKindToOrigin(kind: SemanticHoleDetector.SemanticHoleKind) HoleOrigin {
        return switch (kind) {
            .empty_function_body => .structural,
            .unimplemented_method => .structural,
            .incomplete_match => .structural,
            .missing_type_annotation => .type_inference_failure,
            .missing_await => .structural,
            .unhandled_error => .structural,
        };
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
            .javascript => &javascript_markers,
            .go => &go_markers,
            .c => &c_markers,
            .cpp => &cpp_markers,
            .java => &java_markers,
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
