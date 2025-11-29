// Help command - Show help for commands
const std = @import("std");
const args_mod = @import("cli_args");
const config_mod = @import("cli_config");
const output = @import("cli_output");

const extract = @import("cli/commands/extract");
const compile = @import("cli/commands/compile");
const generate = @import("cli/commands/generate");
const validate = @import("cli/commands/validate");
const init = @import("cli/commands/init");
const version = @import("cli/commands/version");

pub const usage =
    \\Usage: ananke help [command]
    \\
    \\Show help information for a specific command.
    \\
    \\Available commands:
    \\  extract   - Extract constraints from source code
    \\  compile   - Compile constraints to IR
    \\  generate  - Generate code with constraints
    \\  validate  - Validate code against constraints
    \\  init      - Initialize configuration file
    \\  version   - Show version information
    \\  help      - Show this help message
    \\
    \\Examples:
    \\  ananke help
    \\  ananke help extract
    \\  ananke help compile
;

pub fn run(allocator: std.mem.Allocator, parsed_args: args_mod.Args, config: config_mod.Config) !void {
    _ = allocator;
    _ = config;

    const command = parsed_args.getPositional(0) catch {
        printGeneralHelp();
        return;
    };

    if (std.mem.eql(u8, command, "extract")) {
        std.debug.print("{s}\n", .{extract.usage});
    } else if (std.mem.eql(u8, command, "compile")) {
        std.debug.print("{s}\n", .{compile.usage});
    } else if (std.mem.eql(u8, command, "generate")) {
        std.debug.print("{s}\n", .{generate.usage});
    } else if (std.mem.eql(u8, command, "validate")) {
        std.debug.print("{s}\n", .{validate.usage});
    } else if (std.mem.eql(u8, command, "init")) {
        std.debug.print("{s}\n", .{init.usage});
    } else if (std.mem.eql(u8, command, "version")) {
        std.debug.print("{s}\n", .{version.usage});
    } else if (std.mem.eql(u8, command, "help")) {
        std.debug.print("{s}\n", .{usage});
    } else {
        if (output.use_colors) {
            std.debug.print("{s}Unknown command:{s} {s}\n", .{
                output.Color.red.code(),
                output.Color.reset.code(),
                command,
            });
        } else {
            std.debug.print("Unknown command: {s}\n", .{command});
        }
        std.debug.print("\n", .{});
        printGeneralHelp();
        return error.UnknownCommand;
    }
}

fn printGeneralHelp() void {
    if (output.use_colors) {
        std.debug.print("{s}Ananke{s} - Constraint-driven code generation system\n\n", .{
            output.Color.bold.code(),
            output.Color.reset.code(),
        });
    } else {
        std.debug.print("Ananke - Constraint-driven code generation system\n\n", .{});
    }

    std.debug.print("Usage: ananke <command> [options]\n\n", .{});
    std.debug.print("Commands:\n", .{});
    std.debug.print("  extract   Extract constraints from source code\n", .{});
    std.debug.print("  compile   Compile constraints to intermediate representation\n", .{});
    std.debug.print("  generate  Generate code with constraints (requires Modal)\n", .{});
    std.debug.print("  validate  Validate code against constraints\n", .{});
    std.debug.print("  init      Initialize .ananke.toml configuration file\n", .{});
    std.debug.print("  version   Show version information\n", .{});
    std.debug.print("  help      Show help for a specific command\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("Global Options:\n", .{});
    std.debug.print("  --config <file>  Use specified configuration file\n", .{});
    std.debug.print("  --no-color       Disable colored output\n", .{});
    std.debug.print("  --version        Show version and exit\n", .{});
    std.debug.print("  --help           Show this help message\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("Examples:\n", .{});
    std.debug.print("  ananke extract src/main.ts --format json\n", .{});
    std.debug.print("  ananke compile constraints.json -o compiled.cir\n", .{});
    std.debug.print("  ananke validate src/auth.ts -c rules.json\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("For more information on a specific command, run:\n", .{});
    std.debug.print("  ananke help <command>\n", .{});
}
