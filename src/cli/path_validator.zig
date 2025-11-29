const std = @import("std");

pub const PathValidationError = error{
    PathTraversalAttempt,
    AbsolutePathNotAllowed,
    InvalidPath,
    SymlinkNotAllowed,
    OutsideWorkingDirectory,
};

/// Validate and normalize a user-provided file path
/// Returns canonicalized absolute path or error
pub fn validatePath(
    allocator: std.mem.Allocator,
    user_path: []const u8,
    allow_absolute: bool,
) ![]const u8 {
    // 1. Check for obvious path traversal patterns
    if (std.mem.indexOf(u8, user_path, "..") != null) {
        return PathValidationError.PathTraversalAttempt;
    }

    // 2. Reject null bytes (directory traversal bypass)
    if (std.mem.indexOfScalar(u8, user_path, 0) != null) {
        return PathValidationError.InvalidPath;
    }

    // 3. Check if path is absolute
    const is_absolute = std.fs.path.isAbsolute(user_path);
    if (is_absolute and !allow_absolute) {
        return PathValidationError.AbsolutePathNotAllowed;
    }

    // 4. Resolve to real path (resolves symlinks)
    const real_path = std.fs.cwd().realpathAlloc(
        allocator,
        user_path,
    ) catch |err| {
        return switch (err) {
            error.FileNotFound => err,
            error.AccessDenied => err,
            error.SymLinkLoop => PathValidationError.SymlinkNotAllowed,
            else => PathValidationError.InvalidPath,
        };
    };
    errdefer allocator.free(real_path);

    // 5. Verify resolved path is within cwd (prevents symlink escape)
    const cwd_path = try std.fs.cwd().realpathAlloc(allocator, ".");
    defer allocator.free(cwd_path);

    if (!std.mem.startsWith(u8, real_path, cwd_path)) {
        allocator.free(real_path);
        return PathValidationError.OutsideWorkingDirectory;
    }

    return real_path;
}

/// Validate path for writing (stricter checks)
pub fn validateOutputPath(
    allocator: std.mem.Allocator,
    user_path: []const u8,
) ![]const u8 {
    // Output paths must not exist yet or must be writable files in valid directories
    const dir_path = std.fs.path.dirname(user_path) orelse ".";

    // Validate directory exists and is within cwd
    _ = try validatePath(allocator, dir_path, false);

    // Return the user path if valid (don't resolve file that doesn't exist)
    if (std.mem.indexOf(u8, user_path, "..") != null) {
        return PathValidationError.PathTraversalAttempt;
    }

    return try allocator.dupe(u8, user_path);
}
