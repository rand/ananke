// Ananke CLI - Command-line interface for constraint-driven code generation
const std = @import("std");

// Import CLI modules
const args_mod = @import("cli/args.zig");
const output = @import("cli/output.zig");
const config_mod = @import("cli/config.zig");
const cli_error = @import("cli/error.zig");

// Import command modules
const extract = @import("cli/commands/extract.zig");
const compile = @import("cli/commands/compile.zig");
const generate = @import("cli/commands/generate.zig");
const validate = @import("cli/commands/validate.zig");
const init = @import("cli/commands/init.zig");
const version = @import("cli/commands/version.zig");
const help = @import("cli/commands/help.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse command-line arguments
    const argv = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, argv);

    // Parse arguments
    var parsed_args = try args_mod.parse(allocator, argv);
    defer parsed_args.deinit();

    // Handle global flags
    if (parsed_args.hasFlag("no-color")) {
        output.setColorEnabled(false);
    }

    if (parsed_args.hasFlag("version")) {
        std.debug.print("Ananke v{s}\n", .{version.VERSION});
        return;
    }

    if (parsed_args.hasFlag("help") and parsed_args.command.len == 0) {
        return help.run(allocator, parsed_args, undefined);
    }

    // Load configuration
    const config_file = parsed_args.getFlagOr("config", ".ananke.toml");
    var config = blk: {
        const loaded_config = config_mod.Config.loadFromFile(allocator, config_file) catch |err| {
            if (err != error.FileNotFound) {
                cli_error.printError("Failed to load configuration: {s}", .{@errorName(err)});
            }
            // Use default config if file doesn't exist
            break :blk config_mod.Config.init(allocator);
        };
        break :blk loaded_config;
    };
    defer config.deinit();

    // Override with environment variables
    try config.loadFromEnv();

    // Show help if no command specified
    if (parsed_args.command.len == 0) {
        return help.run(allocator, parsed_args, config);
    }

    // Route to appropriate command
    const exit_code = runCommand(allocator, parsed_args, config) catch |err| {
        return cli_error.handleError(err);
    };

    if (exit_code != .success) {
        std.process.exit(exit_code.toInt());
    }
}

fn runCommand(
    allocator: std.mem.Allocator,
    parsed_args: args_mod.Args,
    config: config_mod.Config,
) !cli_error.ExitCode {
    const command = parsed_args.command;

    if (std.mem.eql(u8, command, "extract")) {
        try extract.run(allocator, parsed_args, config);
    } else if (std.mem.eql(u8, command, "compile")) {
        try compile.run(allocator, parsed_args, config);
    } else if (std.mem.eql(u8, command, "generate")) {
        try generate.run(allocator, parsed_args, config);
    } else if (std.mem.eql(u8, command, "validate")) {
        try validate.run(allocator, parsed_args, config);
    } else if (std.mem.eql(u8, command, "init")) {
        try init.run(allocator, parsed_args, config);
    } else if (std.mem.eql(u8, command, "version") or std.mem.eql(u8, command, "--version")) {
        try version.run(allocator, parsed_args, config);
    } else if (std.mem.eql(u8, command, "help") or std.mem.eql(u8, command, "--help")) {
        try help.run(allocator, parsed_args, config);
    } else {
        cli_error.printError("Unknown command: {s}", .{command});
        std.debug.print("\n", .{});
        try help.run(allocator, parsed_args, config);
        return cli_error.ExitCode.user_error;
    }

    return cli_error.ExitCode.success;
}
