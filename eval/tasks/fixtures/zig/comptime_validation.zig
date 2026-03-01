//! Comptime Validation Implementation
//! Demonstrates compile-time validation and type checking in Zig

const std = @import("std");

/// Validates that a type is a struct with required fields
pub fn validateStructFields(comptime T: type, comptime required_fields: []const []const u8) bool {
    const info = @typeInfo(T);
    if (info != .@"struct") return false;

    const fields = info.@"struct".fields;
    inline for (required_fields) |required| {
        var found = false;
        inline for (fields) |field| {
            if (std.mem.eql(u8, field.name, required)) {
                found = true;
            }
        }
        if (!found) return false;
    }
    return true;
}

/// Validates that a type has specific methods
pub fn hasMethod(comptime T: type, comptime method_name: []const u8) bool {
    return @hasDecl(T, method_name);
}

/// Creates a validated wrapper that ensures constraints at compile time
pub fn Validated(comptime T: type, comptime validator: fn (T) bool) type {
    return struct {
        value: T,

        const Self = @This();

        pub fn init(value: T) !Self {
            if (!validator(value)) {
                return error.ValidationFailed;
            }
            return Self{ .value = value };
        }

        pub fn get(self: Self) T {
            return self.value;
        }
    };
}

/// Compile-time string validation
pub fn isValidIdentifier(comptime s: []const u8) bool {
    if (s.len == 0) return false;

    // First char must be letter or underscore
    const first = s[0];
    if (!std.ascii.isAlphabetic(first) and first != '_') return false;

    // Rest must be alphanumeric or underscore
    for (s[1..]) |c| {
        if (!std.ascii.isAlphanumeric(c) and c != '_') return false;
    }

    return true;
}

/// Validates numeric constraints at compile time
pub fn InRange(comptime T: type, comptime min: T, comptime max: T) type {
    return struct {
        value: T,

        const Self = @This();

        pub fn init(value: T) !Self {
            if (value < min or value > max) {
                return error.OutOfRange;
            }
            return Self{ .value = value };
        }

        pub fn get(self: Self) T {
            return self.value;
        }

        pub const MIN = min;
        pub const MAX = max;
    };
}

/// Non-empty string type
pub fn NonEmpty(comptime max_len: usize) type {
    return struct {
        data: [max_len]u8,
        len: usize,

        const Self = @This();

        pub fn init(s: []const u8) !Self {
            if (s.len == 0) return error.EmptyString;
            if (s.len > max_len) return error.StringTooLong;

            var result = Self{
                .data = undefined,
                .len = s.len,
            };
            @memcpy(result.data[0..s.len], s);
            return result;
        }

        pub fn slice(self: *const Self) []const u8 {
            return self.data[0..self.len];
        }
    };
}

/// Email validation (basic)
pub fn isValidEmail(comptime email: []const u8) bool {
    var at_pos: ?usize = null;
    var dot_after_at = false;

    for (email, 0..) |c, i| {
        if (c == '@') {
            if (at_pos != null) return false; // Multiple @
            if (i == 0) return false; // @ at start
            at_pos = i;
        }
        if (c == '.' and at_pos != null and i > at_pos.?) {
            dot_after_at = true;
        }
    }

    return at_pos != null and dot_after_at and at_pos.? < email.len - 2;
}

/// Type-safe enum wrapper with string conversion
pub fn EnumValidator(comptime E: type) type {
    const info = @typeInfo(E);
    if (info != .@"enum") @compileError("EnumValidator requires an enum type");

    return struct {
        pub fn fromString(s: []const u8) ?E {
            inline for (info.@"enum".fields) |field| {
                if (std.mem.eql(u8, s, field.name)) {
                    return @enumFromInt(field.value);
                }
            }
            return null;
        }

        pub fn toString(value: E) []const u8 {
            return @tagName(value);
        }

        pub fn isValid(s: []const u8) bool {
            return fromString(s) != null;
        }
    };
}

/// Compile-time array bounds checking
pub fn BoundedArray(comptime T: type, comptime max_size: usize) type {
    return struct {
        items: [max_size]T = undefined,
        len: usize = 0,

        const Self = @This();

        pub fn append(self: *Self, item: T) !void {
            if (self.len >= max_size) return error.ArrayFull;
            self.items[self.len] = item;
            self.len += 1;
        }

        pub fn get(self: *const Self, index: usize) !T {
            if (index >= self.len) return error.IndexOutOfBounds;
            return self.items[index];
        }

        pub fn slice(self: *const Self) []const T {
            return self.items[0..self.len];
        }

        pub fn clear(self: *Self) void {
            self.len = 0;
        }

        pub fn pop(self: *Self) !T {
            if (self.len == 0) return error.ArrayEmpty;
            self.len -= 1;
            return self.items[self.len];
        }
    };
}

/// Type constraint checking
pub fn isNumeric(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .int, .float, .comptime_int, .comptime_float => true,
        else => false,
    };
}

pub fn isSignedInt(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .int => |info| info.signedness == .signed,
        else => false,
    };
}

pub fn isUnsignedInt(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .int => |info| info.signedness == .unsigned,
        else => false,
    };
}

/// Assert compile-time condition with custom message
pub fn comptimeAssert(comptime condition: bool, comptime message: []const u8) void {
    if (!condition) {
        @compileError(message);
    }
}

/// Optional type unwrapper with default
pub fn unwrapOrDefault(comptime T: type, optional: ?T, default: T) T {
    return optional orelse default;
}
