const std = @import("std");
const testing = std.testing;
const path_validator = @import("../../src/cli/path_validator.zig");

test "path validation - rejects path traversal" {
    const allocator = testing.allocator;

    const test_cases = [_][]const u8{
        "../../../etc/passwd",
        "../../secret.txt",
        "foo/../../../bar",
        "./../../outside",
        "normal/../../../escape",
    };

    for (test_cases) |bad_path| {
        const result = path_validator.validatePath(allocator, bad_path, false);
        try testing.expectError(
            path_validator.PathValidationError.PathTraversalAttempt,
            result,
        );
    }
}

test "path validation - rejects null bytes" {
    const allocator = testing.allocator;

    const bad_path = "file\x00injection";
    const result = path_validator.validatePath(allocator, bad_path, false);
    try testing.expectError(
        path_validator.PathValidationError.InvalidPath,
        result,
    );
}

test "path validation - accepts valid relative paths" {
    const allocator = testing.allocator;

    // Create a test file
    const test_file = "test_valid_path.txt";
    {
        const file = try std.fs.cwd().createFile(test_file, .{});
        defer file.close();
        try file.writeAll("test content");
    }
    defer std.fs.cwd().deleteFile(test_file) catch {};

    const validated = try path_validator.validatePath(allocator, test_file, false);
    defer allocator.free(validated);

    try testing.expect(std.mem.endsWith(u8, validated, test_file));
}

test "path validation - rejects absolute paths when not allowed" {
    const allocator = testing.allocator;

    const abs_path = "/etc/passwd";
    const result = path_validator.validatePath(allocator, abs_path, false);
    try testing.expectError(
        path_validator.PathValidationError.AbsolutePathNotAllowed,
        result,
    );
}

test "path validation - accepts absolute paths when allowed" {
    if (std.builtin.os.tag == .windows) return error.SkipZigTest;

    const allocator = testing.allocator;

    // Use a path that likely exists on Unix systems
    const abs_path = "/tmp";
    const validated = path_validator.validatePath(allocator, abs_path, true) catch |err| {
        // If /tmp doesn't exist or isn't accessible, skip test
        if (err == error.FileNotFound or err == error.AccessDenied) {
            return error.SkipZigTest;
        }
        return err;
    };
    defer allocator.free(validated);

    try testing.expect(std.mem.startsWith(u8, validated, "/tmp"));
}

test "path validation - rejects symlink escape" {
    if (std.builtin.os.tag == .windows) return error.SkipZigTest;

    const allocator = testing.allocator;

    // Create a symlink pointing outside cwd
    std.posix.symlink("/etc/passwd", "escape_link") catch |err| {
        // Skip if we can't create symlinks (permissions)
        if (err == error.AccessDenied) return error.SkipZigTest;
        return err;
    };
    defer std.fs.cwd().deleteFile("escape_link") catch {};

    const result = path_validator.validatePath(allocator, "escape_link", false);
    try testing.expectError(
        path_validator.PathValidationError.OutsideWorkingDirectory,
        result,
    );
}

test "output path validation - rejects traversal" {
    const allocator = testing.allocator;

    const bad_path = "../../output.json";
    const result = path_validator.validateOutputPath(allocator, bad_path);
    try testing.expectError(
        path_validator.PathValidationError.PathTraversalAttempt,
        result,
    );
}

test "output path validation - accepts valid paths" {
    const allocator = testing.allocator;

    const good_path = "output.json";
    const validated = try path_validator.validateOutputPath(allocator, good_path);
    defer allocator.free(validated);

    try testing.expectEqualStrings(good_path, validated);
}

test "output path validation - accepts paths in subdirectories" {
    const allocator = testing.allocator;

    // Create a test directory
    std.fs.cwd().makeDir("test_output_dir") catch {};
    defer std.fs.cwd().deleteDir("test_output_dir") catch {};

    const good_path = "test_output_dir/output.json";
    const validated = try path_validator.validateOutputPath(allocator, good_path);
    defer allocator.free(validated);

    try testing.expectEqualStrings(good_path, validated);
}
