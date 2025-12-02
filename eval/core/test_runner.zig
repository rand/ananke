const std = @import("std");
const Allocator = std.mem.Allocator;

pub const TestResult = struct {
    success: bool,
    total_tests: u32,
    passed_tests: u32,
    failed_tests: u32,
    duration_ms: u64,
    coverage_percent: f32,
    error_message: ?[]const u8 = null,

    pub fn deinit(self: *TestResult, allocator: Allocator) void {
        if (self.error_message) |msg| {
            allocator.free(msg);
        }
    }
};

pub const TestRunner = struct {
    allocator: Allocator,
    script_path: []const u8,

    pub fn init(allocator: Allocator) TestRunner {
        return .{
            .allocator = allocator,
            .script_path = "eval/test_runners/run_tests.sh",
        };
    }

    /// Run tests for generated code
    pub fn runTests(
        self: *TestRunner,
        language: []const u8,
        implementation_code: []const u8,
        test_file_path: []const u8,
    ) !TestResult {
        // Create temporary file for generated implementation
        const temp_impl_path = try self.createTempImplementation(language, implementation_code);
        defer self.allocator.free(temp_impl_path);
        defer std.fs.cwd().deleteFile(temp_impl_path) catch {};

        // Create temporary file for test results
        const temp_results_path = try std.fmt.allocPrint(
            self.allocator,
            "/tmp/ananke_test_results_{d}.json",
            .{std.time.milliTimestamp()},
        );
        defer self.allocator.free(temp_results_path);
        defer std.fs.cwd().deleteFile(temp_results_path) catch {};

        // Build command to run test script
        const argv = [_][]const u8{
            self.script_path,
            language,
            test_file_path,
            temp_impl_path,
            temp_results_path,
        };

        std.log.info("Test runner: script={s}", .{self.script_path});
        std.log.info("Test runner: impl={s} (code len: {d})", .{ temp_impl_path, implementation_code.len });
        std.log.info("Test runner: results={s}", .{temp_results_path});

        // Execute test script
        var child = std.process.Child.init(&argv, self.allocator);
        child.stdout_behavior = .Ignore;
        child.stderr_behavior = .Ignore;

        try child.spawn();
        const term = child.wait() catch |err| {
            std.log.err("Test script wait failed: {}", .{err});
            return TestResult{
                .success = false,
                .total_tests = 0,
                .passed_tests = 0,
                .failed_tests = 0,
                .duration_ms = 0,
                .coverage_percent = 0.0,
                .error_message = try self.allocator.dupe(u8, "Script execution failed"),
            };
        };

        // Log exit status
        switch (term) {
            .Exited => |code| {
                if (code != 0) {
                    std.log.warn("Test script exited with code: {}", .{code});
                }
            },
            else => {
                std.log.warn("Test script terminated abnormally", .{});
            },
        }

        // Parse results regardless of exit code (tests might fail but we want metrics)
        const results = try self.parseTestResults(temp_results_path);

        return results;
    }

    fn createTempImplementation(
        self: *TestRunner,
        language: []const u8,
        code: []const u8,
    ) ![]const u8 {
        const extension = if (std.mem.eql(u8, language, "typescript"))
            ".ts"
        else if (std.mem.eql(u8, language, "python"))
            ".py"
        else
            return error.UnsupportedLanguage;

        const filename = try std.fmt.allocPrint(
            self.allocator,
            "/tmp/ananke_impl_{d}{s}",
            .{ std.time.milliTimestamp(), extension },
        );
        errdefer self.allocator.free(filename);

        // Write code to file
        const file = try std.fs.cwd().createFile(filename, .{});
        defer file.close();

        try file.writeAll(code);

        return filename;
    }

    fn parseTestResults(self: *TestRunner, results_path: []const u8) !TestResult {
        std.log.info("Parsing results from: {s}", .{results_path});

        // Read results file
        const file = std.fs.cwd().openFile(results_path, .{}) catch |err| {
            std.log.err("Failed to open test results file: {} at {s}", .{ err, results_path });
            return TestResult{
                .success = false,
                .total_tests = 0,
                .passed_tests = 0,
                .failed_tests = 0,
                .duration_ms = 0,
                .coverage_percent = 0.0,
                .error_message = try self.allocator.dupe(u8, "Failed to read test results"),
            };
        };
        defer file.close();

        const content = try file.readToEndAlloc(self.allocator, 1024 * 1024);
        defer self.allocator.free(content);

        std.log.info("Results content length: {d}", .{content.len});
        if (content.len > 0 and content.len < 500) {
            std.log.info("Results content: {s}", .{content});
        }

        // Parse JSON
        const parsed = try std.json.parseFromSlice(
            std.json.Value,
            self.allocator,
            content,
            .{},
        );
        defer parsed.deinit();

        const root = parsed.value.object;

        // Extract fields
        const success = root.get("success").?.bool;
        const total_tests = if (root.get("total_tests")) |v|
            @as(u32, @intCast(v.integer))
        else
            0;
        const passed_tests = if (root.get("passed_tests")) |v|
            @as(u32, @intCast(v.integer))
        else
            0;
        const failed_tests = if (root.get("failed_tests")) |v|
            @as(u32, @intCast(v.integer))
        else
            0;
        const duration_ms = if (root.get("duration_ms")) |v|
            @as(u64, @intCast(v.integer))
        else
            0;
        const coverage_percent: f32 = if (root.get("coverage_percent")) |v| blk: {
            // Handle both integer (e.g., 0) and float (e.g., 0.0) JSON values
            break :blk switch (v) {
                .float => @as(f32, @floatCast(v.float)),
                .integer => @as(f32, @floatFromInt(v.integer)),
                else => 0.0,
            };
        } else 0.0;

        var error_message: ?[]const u8 = null;
        if (root.get("error")) |err_value| {
            error_message = try self.allocator.dupe(u8, err_value.string);
        }

        return TestResult{
            .success = success,
            .total_tests = total_tests,
            .passed_tests = passed_tests,
            .failed_tests = failed_tests,
            .duration_ms = duration_ms,
            .coverage_percent = coverage_percent,
            .error_message = error_message,
        };
    }
};
