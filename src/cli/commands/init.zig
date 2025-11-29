// Init command - Initialize .ananke.toml configuration
const std = @import("std");
const args_mod = @import("cli_args");
const config_mod = @import("cli_config");
const cli_error = @import("cli_error");

pub const usage =
    \\Usage: ananke init [options]
    \\
    \\Initialize a new .ananke.toml configuration file in the current directory.
    \\
    \\Options:
    \\  --config <file>         Configuration file path (default: .ananke.toml)
    \\  --modal-endpoint <url>  Set Modal inference endpoint
    \\  --force                 Overwrite existing configuration file
    \\  --help, -h              Show this help message
    \\
    \\Examples:
    \\  ananke init
    \\  ananke init --config my-config.toml
    \\  ananke init --modal-endpoint https://my-app.modal.run
;

pub fn run(allocator: std.mem.Allocator, parsed_args: args_mod.Args, config: config_mod.Config) !void {
    _ = config;

    if (parsed_args.hasFlag("help") or parsed_args.hasFlag("h")) {
        std.debug.print("{s}\n", .{usage});
        return;
    }

    const config_file = parsed_args.getFlagOr("config", ".ananke.toml");
    const modal_endpoint = parsed_args.getFlag("modal-endpoint");
    const force = parsed_args.hasFlag("force");

    // Check if file already exists
    if (!force) {
        const file_exists = blk: {
            std.fs.cwd().access(config_file, .{}) catch |err| {
                if (err == error.FileNotFound) {
                    break :blk false;
                }
                break :blk true;
            };
            break :blk true;
        };

        if (file_exists) {
            cli_error.printError("Configuration file already exists: {s}", .{config_file});
            cli_error.printInfo("Use --force to overwrite", .{});
            return error.FileExists;
        }
    }

    // Create configuration
    var new_config = config_mod.Config.init(allocator);
    defer new_config.deinit();

    if (modal_endpoint) |endpoint| {
        new_config.modal_endpoint = try allocator.dupe(u8, endpoint);
    }

    // Save to file
    try new_config.saveToFile(config_file);

    cli_error.printSuccess("Created configuration file: {s}", .{config_file});
    std.debug.print("\n", .{});
    std.debug.print("Next steps:\n", .{});
    std.debug.print("  1. Edit {s} to configure Modal endpoint and preferences\n", .{config_file});
    std.debug.print("  2. Set ANANKE_MODAL_API_KEY environment variable for API access\n", .{});
    std.debug.print("  3. Run 'ananke extract <file>' to start extracting constraints\n", .{});
    std.debug.print("\n", .{});
}
