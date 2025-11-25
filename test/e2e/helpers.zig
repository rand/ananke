//! E2E Test Utilities and Helper Functions
//!
//! Provides a comprehensive test context for running full pipeline tests
//! including extraction, compilation, and generation phases.

const std = @import("std");
const testing = std.testing;
const ananke = @import("ananke");
const Clew = @import("clew").Clew;
const Braid = @import("braid").Braid;

const Allocator = std.mem.Allocator;
const ConstraintSet = ananke.ConstraintSet;
const ConstraintIR = ananke.ConstraintIR;
const Constraint = ananke.Constraint;

/// E2E Test Context manages the complete test environment
pub const E2ETestContext = struct {
    allocator: Allocator,
    temp_dir: testing.TmpDir,
    clew: *Clew,
    braid: *Braid,
    temp_path: []u8,

    /// Initialize a new E2E test context
    pub fn init(allocator: Allocator) !E2ETestContext {
        var temp_dir = testing.tmpDir(.{});

        const clew = try allocator.create(Clew);
        clew.* = try Clew.init(allocator);

        const braid = try allocator.create(Braid);
        braid.* = try Braid.init(allocator);

        // Get the temp directory path for file operations
        const temp_buffer = try allocator.alloc(u8, 256);
        defer allocator.free(temp_buffer);

        const path_len = (try temp_dir.dir.realpath(".", temp_buffer)).len;
        const temp_path = try allocator.dupe(u8, temp_buffer[0..path_len]);

        return E2ETestContext{
            .allocator = allocator,
            .temp_dir = temp_dir,
            .clew = clew,
            .braid = braid,
            .temp_path = temp_path,
        };
    }

    /// Clean up the test context
    pub fn deinit(self: *E2ETestContext) void {
        self.clew.deinit();
        self.allocator.destroy(self.clew);

        self.braid.deinit();
        self.allocator.destroy(self.braid);

        self.allocator.free(self.temp_path);
        self.temp_dir.cleanup();
    }

    /// Pipeline result structure
    pub const PipelineResult = struct {
        constraints: ConstraintSet,
        ir: ConstraintIR,

        pub fn deinit(self: *PipelineResult, allocator: Allocator) void {
            self.constraints.deinit();
            self.ir.deinit(allocator);
        }
    };

    /// Run the full extraction and compilation pipeline
    pub fn runPipeline(
        self: *E2ETestContext,
        source_file: []const u8,
    ) !PipelineResult {
        // Detect language from file extension
        const language = detectLanguage(source_file) orelse
            return error.UnknownLanguage;

        // Determine the full path to the source file
        // If it's a relative path, prepend temp_path; if absolute, use as-is
        const full_path = if (std.fs.path.isAbsolute(source_file))
            source_file
        else blk: {
            const path = try std.fs.path.join(
                self.allocator,
                &[_][]const u8{ self.temp_path, source_file },
            );
            break :blk path;
        };
        defer {
            if (!std.fs.path.isAbsolute(source_file)) {
                self.allocator.free(full_path);
            }
        }

        // Read the source file
        const source = try std.fs.cwd().readFileAlloc(
            self.allocator,
            full_path,
            1024 * 1024, // 1MB max
        );
        defer self.allocator.free(source);

        // Extract constraints using Clew
        var constraints = try self.clew.extractFromCode(source, language);
        errdefer constraints.deinit();

        // Compile to IR using Braid
        const ir = try self.braid.compile(constraints.constraints.items);

        return PipelineResult{
            .constraints = constraints,
            .ir = ir,
        };
    }

    /// Create a test source file in the temp directory
    pub fn createSourceFile(
        self: *E2ETestContext,
        path: []const u8,
        content: []const u8,
    ) !void {
        const file = try self.temp_dir.dir.createFile(path, .{});
        defer file.close();

        try file.writeAll(content);
    }

    /// Assert that two constraint sets match
    pub fn assertConstraintsMatch(
        expected: ConstraintSet,
        actual: ConstraintSet,
    ) !void {
        // Check count
        try testing.expectEqual(expected.constraints.items.len, actual.constraints.items.len);

        // Compare each constraint
        for (expected.constraints.items, 0..) |exp_constraint, i| {
            const act_constraint = actual.constraints.items[i];

            // Compare name
            try testing.expectEqualStrings(
                exp_constraint.name,
                act_constraint.name,
            );

            // Compare type
            try testing.expectEqual(
                exp_constraint.kind,
                act_constraint.kind,
            );
        }
    }

    /// Load expected constraints from JSON file
    pub fn loadExpectedConstraints(
        self: *E2ETestContext,
        json_path: []const u8,
    ) !ConstraintSet {
        const json = try std.fs.cwd().readFileAlloc(
            self.allocator,
            json_path,
            1024 * 1024,
        );
        defer self.allocator.free(json);

        const parsed = try std.json.parseFromSlice(
            ConstraintSetJson,
            self.allocator,
            json,
            .{},
        );
        defer parsed.deinit();

        return constraintSetFromJson(self.allocator, parsed.value);
    }

    /// Measure extraction performance
    pub fn measureExtractionTime(
        self: *E2ETestContext,
        source_file: []const u8,
    ) !i64 {
        const start = std.time.milliTimestamp();

        var result = try self.runPipeline(source_file);
        defer result.deinit(self.allocator);

        return std.time.milliTimestamp() - start;
    }

};

// Helper functions

/// Assert performance meets requirements
pub fn assertPerformance(
    actual_ms: i64,
    max_ms: i64,
    test_name: []const u8,
) !void {
    std.debug.print(
        "{s}: {d}ms (max: {d}ms)\n",
        .{ test_name, actual_ms, max_ms },
    );

    if (actual_ms > max_ms) {
        std.debug.print(
            "Performance test failed: {s} took {d}ms (max allowed: {d}ms)\n",
            .{ test_name, actual_ms, max_ms },
        );
        return error.PerformanceTestFailed;
    }
}

fn detectLanguage(file_path: []const u8) ?[]const u8 {
    if (std.mem.endsWith(u8, file_path, ".ts")) return "typescript";
    if (std.mem.endsWith(u8, file_path, ".tsx")) return "typescript";
    if (std.mem.endsWith(u8, file_path, ".py")) return "python";
    if (std.mem.endsWith(u8, file_path, ".rs")) return "rust";
    if (std.mem.endsWith(u8, file_path, ".zig")) return "zig";
    if (std.mem.endsWith(u8, file_path, ".go")) return "go";
    return null;
}

// JSON structures for loading expected constraints

const ConstraintSetJson = struct {
    constraints: []ConstraintJson,
};

const ConstraintJson = struct {
    identifier: []const u8,
    constraint_type: []const u8,
    severity: []const u8,
    description: ?[]const u8 = null,
};

fn constraintSetFromJson(
    allocator: Allocator,
    json: ConstraintSetJson,
) !ConstraintSet {
    var constraint_set = ConstraintSet.init(allocator);
    errdefer constraint_set.deinit();

    for (json.constraints) |json_constraint| {
        const constraint_type = std.meta.stringToEnum(
            ananke.ConstraintType,
            json_constraint.constraint_type,
        ) orelse return error.InvalidConstraintType;

        const severity = std.meta.stringToEnum(
            ananke.Severity,
            json_constraint.severity,
        ) orelse return error.InvalidSeverity;

        const constraint = Constraint{
            .identifier = try allocator.dupe(u8, json_constraint.identifier),
            .constraint_type = constraint_type,
            .severity = severity,
            .description = if (json_constraint.description) |desc|
                try allocator.dupe(u8, desc)
            else
                null,
        };

        try constraint_set.append(constraint);
    }

    return constraint_set;
}

// Test utilities for mock server coordination

/// Start the mock Modal server in a separate thread
pub fn startMockServer(
    allocator: Allocator,
    config: @import("mocks/mock_modal.zig").MockServerConfig,
) !std.Thread {
    const thread = try std.Thread.spawn(
        .{},
        @import("mocks/mock_modal.zig").runMockServer,
        .{ allocator, config },
    );

    // Give the server time to start
    std.Thread.sleep(100 * std.time.ns_per_ms);

    return thread;
}