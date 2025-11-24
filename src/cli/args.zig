// CLI argument parsing for Ananke commands
const std = @import("std");

pub const ArgsError = error{
    MissingArgument,
    InvalidArgument,
    UnknownFlag,
    InvalidValue,
};

/// Parsed command-line arguments
pub const Args = struct {
    allocator: std.mem.Allocator,
    command: []const u8,
    positional: std.ArrayList([]const u8),
    flags: std.StringHashMap([]const u8),

    pub fn init(allocator: std.mem.Allocator) Args {
        return .{
            .allocator = allocator,
            .command = "",
            .positional = std.ArrayList([]const u8){},
            .flags = std.StringHashMap([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *Args) void {
        self.positional.deinit(self.allocator);
        self.flags.deinit();
    }

    /// Get a required positional argument by index
    pub fn getPositional(self: *const Args, index: usize) ![]const u8 {
        if (index >= self.positional.items.len) {
            return ArgsError.MissingArgument;
        }
        return self.positional.items[index];
    }

    /// Get an optional flag value
    pub fn getFlag(self: *const Args, name: []const u8) ?[]const u8 {
        return self.flags.get(name);
    }

    /// Check if a boolean flag is present
    pub fn hasFlag(self: *const Args, name: []const u8) bool {
        return self.flags.contains(name);
    }

    /// Get a flag value or return a default
    pub fn getFlagOr(self: *const Args, name: []const u8, default: []const u8) []const u8 {
        return self.getFlag(name) orelse default;
    }

    /// Parse an integer flag value
    pub fn getFlagInt(self: *const Args, name: []const u8, comptime T: type) !?T {
        if (self.getFlag(name)) |value| {
            return std.fmt.parseInt(T, value, 10) catch return ArgsError.InvalidValue;
        }
        return null;
    }

    /// Parse a float flag value
    pub fn getFlagFloat(self: *const Args, name: []const u8, comptime T: type) !?T {
        if (self.getFlag(name)) |value| {
            return std.fmt.parseFloat(T, value) catch return ArgsError.InvalidValue;
        }
        return null;
    }
};

/// Parse command-line arguments
pub fn parse(allocator: std.mem.Allocator, argv: []const [:0]u8) !Args {
    var args = Args.init(allocator);
    errdefer args.deinit();

    if (argv.len < 2) {
        return args; // No command specified
    }

    // First argument is the command
    args.command = argv[1];

    // Parse remaining arguments
    var i: usize = 2;
    while (i < argv.len) {
        const arg = argv[i];

        if (std.mem.startsWith(u8, arg, "--")) {
            // Long flag
            const flag_name = arg[2..];

            if (std.mem.indexOf(u8, flag_name, "=")) |eq_pos| {
                // --flag=value format
                const name = flag_name[0..eq_pos];
                const value = flag_name[eq_pos + 1 ..];
                try args.flags.put(name, value);
            } else if (i + 1 < argv.len and !std.mem.startsWith(u8, argv[i + 1], "-")) {
                // --flag value format (next arg is value if not a flag)
                i += 1;
                try args.flags.put(flag_name, argv[i]);
            } else {
                // Boolean flag
                try args.flags.put(flag_name, "true");
            }
        } else if (std.mem.startsWith(u8, arg, "-") and arg.len > 1) {
            // Short flag
            const flag_char = arg[1..];

            if (i + 1 < argv.len and !std.mem.startsWith(u8, argv[i + 1], "-")) {
                // -f value format
                i += 1;
                try args.flags.put(flag_char, argv[i]);
            } else {
                // Boolean flag
                try args.flags.put(flag_char, "true");
            }
        } else {
            // Positional argument
            try args.positional.append(allocator, arg);
        }

        i += 1;
    }

    return args;
}

/// Validate that required positional arguments are present
pub fn requirePositional(args: *const Args, count: usize, usage: []const u8) !void {
    if (args.positional.items.len < count) {
        std.debug.print("Error: Missing required arguments\n", .{});
        std.debug.print("{s}\n", .{usage});
        return ArgsError.MissingArgument;
    }
}

/// Validate that a flag value is one of the allowed values
pub fn validateFlagEnum(args: *const Args, flag: []const u8, allowed: []const []const u8) !void {
    if (args.getFlag(flag)) |value| {
        for (allowed) |allowed_value| {
            if (std.mem.eql(u8, value, allowed_value)) {
                return;
            }
        }
        std.debug.print("Error: Invalid value '{s}' for flag --{s}\n", .{ value, flag });
        std.debug.print("Allowed values: {s}\n", .{allowed});
        return ArgsError.InvalidValue;
    }
}

test "parse basic arguments" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var argv = [_][:0]const u8{ "ananke", "extract", "file.ts", "--format", "json" };
    var args = try parse(allocator, &argv);
    defer args.deinit();

    try testing.expectEqualStrings("extract", args.command);
    try testing.expectEqual(@as(usize, 1), args.positional.items.len);
    try testing.expectEqualStrings("file.ts", args.positional.items[0]);
    try testing.expectEqualStrings("json", args.getFlag("format").?);
}

test "parse boolean flags" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var argv = [_][:0]const u8{ "ananke", "extract", "--use-claude", "--verbose" };
    var args = try parse(allocator, &argv);
    defer args.deinit();

    try testing.expect(args.hasFlag("use-claude"));
    try testing.expect(args.hasFlag("verbose"));
}

test "parse flag with equals" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var argv = [_][:0]const u8{ "ananke", "compile", "--output=/tmp/out.cir" };
    var args = try parse(allocator, &argv);
    defer args.deinit();

    try testing.expectEqualStrings("/tmp/out.cir", args.getFlag("output").?);
}
