//! Error Union Implementation
//! Demonstrates error handling patterns with error unions in Zig

const std = @import("std");

/// Custom error set for file operations
pub const FileError = error{
    FileNotFound,
    PermissionDenied,
    IoError,
    InvalidPath,
    FileTooLarge,
};

/// Custom error set for parsing
pub const ParseError = error{
    InvalidFormat,
    UnexpectedToken,
    EndOfInput,
    Overflow,
    InvalidCharacter,
};

/// Combined error set
pub const AppError = FileError || ParseError || error{OutOfMemory};

/// Result type alias for convenience
pub fn Result(comptime T: type) type {
    return union(enum) {
        ok: T,
        err: AppError,

        const Self = @This();

        pub fn isOk(self: Self) bool {
            return self == .ok;
        }

        pub fn isErr(self: Self) bool {
            return self == .err;
        }

        pub fn unwrap(self: Self) T {
            return switch (self) {
                .ok => |v| v,
                .err => unreachable,
            };
        }

        pub fn unwrapOr(self: Self, default: T) T {
            return switch (self) {
                .ok => |v| v,
                .err => default,
            };
        }

        pub fn map(self: Self, comptime f: fn (T) T) Self {
            return switch (self) {
                .ok => |v| .{ .ok = f(v) },
                .err => |e| .{ .err = e },
            };
        }
    };
}

/// Try operation with custom error context
pub fn Context(comptime E: type) type {
    return struct {
        error_value: ?E = null,
        context: []const u8 = "",

        const Self = @This();

        pub fn wrap(err: E, ctx: []const u8) Self {
            return .{
                .error_value = err,
                .context = ctx,
            };
        }

        pub fn getError(self: Self) ?E {
            return self.error_value;
        }

        pub fn getContext(self: Self) []const u8 {
            return self.context;
        }
    };
}

/// Retry logic with error handling
pub fn retry(comptime n: usize, comptime f: anytype) @typeInfo(@TypeOf(f)).@"fn".return_type.? {
    var last_error: @typeInfo(@TypeOf(f)).@"fn".return_type.?.Error = undefined;

    comptime var i: usize = 0;
    inline while (i < n) : (i += 1) {
        if (f()) |result| {
            return result;
        } else |err| {
            last_error = err;
        }
    }

    return last_error;
}

/// Error accumulator for collecting multiple errors
pub fn ErrorAccumulator(comptime E: type, comptime max_errors: usize) type {
    return struct {
        errors: [max_errors]E = undefined,
        count: usize = 0,

        const Self = @This();

        pub fn add(self: *Self, err: E) !void {
            if (self.count >= max_errors) {
                return error.TooManyErrors;
            }
            self.errors[self.count] = err;
            self.count += 1;
        }

        pub fn hasErrors(self: Self) bool {
            return self.count > 0;
        }

        pub fn getErrors(self: *const Self) []const E {
            return self.errors[0..self.count];
        }

        pub fn clear(self: *Self) void {
            self.count = 0;
        }
    };
}

/// Parse an integer with error handling
pub fn parseInt(s: []const u8) ParseError!i64 {
    if (s.len == 0) return ParseError.EndOfInput;

    var result: i64 = 0;
    var negative = false;
    var start: usize = 0;

    if (s[0] == '-') {
        negative = true;
        start = 1;
    } else if (s[0] == '+') {
        start = 1;
    }

    if (start >= s.len) return ParseError.InvalidFormat;

    for (s[start..]) |c| {
        if (c < '0' or c > '9') return ParseError.InvalidCharacter;

        const digit = c - '0';
        const new_result = result *% 10 +% digit;
        if (new_result < result) return ParseError.Overflow;
        result = new_result;
    }

    return if (negative) -result else result;
}

/// Parse a float with error handling
pub fn parseFloat(s: []const u8) ParseError!f64 {
    if (s.len == 0) return ParseError.EndOfInput;

    var result: f64 = 0;
    var negative = false;
    var decimal_place: f64 = 0;
    var start: usize = 0;
    var has_decimal = false;

    if (s[0] == '-') {
        negative = true;
        start = 1;
    } else if (s[0] == '+') {
        start = 1;
    }

    if (start >= s.len) return ParseError.InvalidFormat;

    for (s[start..]) |c| {
        if (c == '.') {
            if (has_decimal) return ParseError.InvalidFormat;
            has_decimal = true;
            decimal_place = 0.1;
            continue;
        }

        if (c < '0' or c > '9') return ParseError.InvalidCharacter;

        const digit: f64 = @floatFromInt(c - '0');
        if (has_decimal) {
            result += digit * decimal_place;
            decimal_place *= 0.1;
        } else {
            result = result * 10 + digit;
        }
    }

    return if (negative) -result else result;
}

/// Validate and open a file path
pub fn validatePath(path: []const u8) FileError!void {
    if (path.len == 0) return FileError.InvalidPath;

    // Check for null bytes
    for (path) |c| {
        if (c == 0) return FileError.InvalidPath;
    }

    // Check for relative path traversal
    if (std.mem.indexOf(u8, path, "..")) |_| {
        return FileError.InvalidPath;
    }
}

/// Chain multiple operations that can fail
pub fn chain(comptime T: type, comptime U: type, value: anyerror!T, f: fn (T) anyerror!U) anyerror!U {
    const v = try value;
    return f(v);
}

/// Map over an error union
pub fn mapError(comptime T: type, comptime E1: type, comptime E2: type, value: E1!T, f: fn (E1) E2) E2!T {
    return value catch |err| return f(err);
}

/// Ensure - run cleanup on error
pub fn ensure(comptime T: type, value: anyerror!T, cleanup: fn () void) anyerror!T {
    return value catch |err| {
        cleanup();
        return err;
    };
}

/// ErrorSet utilities
pub fn errorName(err: anyerror) []const u8 {
    return @errorName(err);
}

pub fn isError(comptime E: type, err: anyerror) bool {
    const error_info = @typeInfo(E);
    if (error_info != .error_set) return false;

    inline for (error_info.error_set.?) |e| {
        if (err == @field(E, e.name)) return true;
    }
    return false;
}
