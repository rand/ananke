// Error handling and formatting for Ananke CLI
const std = @import("std");
const output = @import("output.zig");

/// Standard exit codes
pub const ExitCode = enum(u8) {
    success = 0,
    user_error = 1,
    system_error = 2,
    not_found = 3,
    permission_denied = 4,
    validation_failed = 5,

    pub fn toInt(self: ExitCode) u8 {
        return @intFromEnum(self);
    }
};

/// CLI error types
pub const CliError = error{
    MissingArgument,
    InvalidArgument,
    FileNotFound,
    PermissionDenied,
    ValidationFailed,
    CompilationFailed,
    ExtractionFailed,
    GenerationFailed,
    ConfigError,
    NetworkError,
    ApiError,
};

/// Print an error message with formatting
pub fn printError(comptime fmt: []const u8, args: anytype) void {
    if (output.use_colors) {
        std.debug.print("{s}Error:{s} ", .{ output.Color.red.code(), output.Color.reset.code() });
    } else {
        std.debug.print("Error: ", .{});
    }
    std.debug.print(fmt, args);
    std.debug.print("\n", .{});
}

/// Print a warning message with formatting
pub fn printWarning(comptime fmt: []const u8, args: anytype) void {
    if (output.use_colors) {
        std.debug.print("{s}Warning:{s} ", .{ output.Color.yellow.code(), output.Color.reset.code() });
    } else {
        std.debug.print("Warning: ", .{});
    }
    std.debug.print(fmt, args);
    std.debug.print("\n", .{});
}

/// Print an info message with formatting
pub fn printInfo(comptime fmt: []const u8, args: anytype) void {
    if (output.use_colors) {
        std.debug.print("{s}Info:{s} ", .{ output.Color.blue.code(), output.Color.reset.code() });
    } else {
        std.debug.print("Info: ", .{});
    }
    std.debug.print(fmt, args);
    std.debug.print("\n", .{});
}

/// Print a success message with formatting
pub fn printSuccess(comptime fmt: []const u8, args: anytype) void {
    if (output.use_colors) {
        std.debug.print("{s}✓{s} ", .{ output.Color.green.code(), output.Color.reset.code() });
    } else {
        std.debug.print("Success: ", .{});
    }
    std.debug.print(fmt, args);
    std.debug.print("\n", .{});
}

/// Handle an error and return appropriate exit code
pub fn handleError(err: anyerror) ExitCode {
    switch (err) {
        error.MissingArgument, error.InvalidArgument => {
            return .user_error;
        },
        error.FileNotFound => {
            return .not_found;
        },
        error.AccessDenied => {
            return .permission_denied;
        },
        error.ValidationFailed => {
            return .validation_failed;
        },
        else => {
            printError("Unexpected error: {s}", .{@errorName(err)});
            return .system_error;
        },
    }
}

/// Print error with suggestion
pub fn printErrorWithSuggestion(
    comptime error_msg: []const u8,
    error_args: anytype,
    comptime suggestion: []const u8,
    suggestion_args: anytype,
) void {
    printError(error_msg, error_args);
    if (output.use_colors) {
        std.debug.print("  {s}Suggestion:{s} ", .{ output.Color.cyan.code(), output.Color.reset.code() });
    } else {
        std.debug.print("  Suggestion: ", .{});
    }
    std.debug.print(suggestion, suggestion_args);
    std.debug.print("\n", .{});
}

/// Print a formatted error box for critical errors
pub fn printErrorBox(title: []const u8, message: []const u8) void {
    const max_width = 70;

    if (output.use_colors) {
        std.debug.print("\n{s}", .{output.Color.red.code()});
    } else {
        std.debug.print("\n", .{});
    }

    std.debug.print("╔{'═'}╗\n", .{'=' ** max_width});
    std.debug.print("║ {s: <68} ║\n", .{title});
    std.debug.print("╠{'═'}╣\n", .{'=' ** max_width});

    // Word wrap the message
    var words = std.mem.split(u8, message, " ");
    var current_line = std.ArrayList(u8){};
    defer current_line.deinit();

    while (words.next()) |word| {
        if (current_line.items.len + word.len + 1 > 66) {
            std.debug.print("║ {s: <68} ║\n", .{current_line.items});
            current_line.clearRetainingCapacity();
        }

        if (current_line.items.len > 0) {
            current_line.appendSlice(" ") catch {};
        }
        current_line.appendSlice(word) catch {};
    }

    if (current_line.items.len > 0) {
        std.debug.print("║ {s: <68} ║\n", .{current_line.items});
    }

    std.debug.print("╚{'═'}╝", .{'=' ** max_width});

    if (output.use_colors) {
        std.debug.print("{s}\n\n", .{output.Color.reset.code()});
    } else {
        std.debug.print("\n\n", .{});
    }
}

/// Print file-related error with path
pub fn printFileError(err: anyerror, path: []const u8) void {
    switch (err) {
        error.FileNotFound => {
            printErrorWithSuggestion(
                "File not found: {s}",
                .{path},
                "Check that the file path is correct and the file exists",
                .{},
            );
        },
        error.AccessDenied => {
            printErrorWithSuggestion(
                "Permission denied: {s}",
                .{path},
                "Check that you have read permissions for this file",
                .{},
            );
        },
        error.IsDir => {
            printErrorWithSuggestion(
                "Path is a directory: {s}",
                .{path},
                "Specify a file path, not a directory",
                .{},
            );
        },
        else => {
            printError("Error accessing file '{s}': {s}", .{ path, @errorName(err) });
        },
    }
}

/// Print validation error summary
pub fn printValidationSummary(errors: usize, warnings: usize) void {
    std.debug.print("\n", .{});
    std.debug.print("━" ** 70, .{});
    std.debug.print("\n", .{});

    if (errors == 0 and warnings == 0) {
        printSuccess("Validation passed: No violations found", .{});
    } else {
        if (errors > 0) {
            printError("Validation failed: {d} error(s) found", .{errors});
        }
        if (warnings > 0) {
            printWarning("{d} warning(s) found", .{warnings});
        }
    }
}
