// Version command - Show version information
const std = @import("std");
const args_mod = @import("../args.zig");
const config_mod = @import("../config.zig");
const output = @import("../output.zig");

pub const VERSION = "0.1.0";
pub const BUILD_DATE = "November 2025";
pub const ZIG_VERSION = "0.15.1";

pub const usage =
    \\Usage: ananke version [options]
    \\
    \\Show version information for Ananke and its components.
    \\
    \\Options:
    \\  --verbose, -v           Show detailed version information
    \\  --help, -h              Show this help message
;

pub fn run(allocator: std.mem.Allocator, parsed_args: args_mod.Args, config: config_mod.Config) !void {
    _ = allocator;
    _ = config;

    if (parsed_args.hasFlag("help") or parsed_args.hasFlag("h")) {
        std.debug.print("{s}\n", .{usage});
        return;
    }

    const verbose = parsed_args.hasFlag("verbose") or parsed_args.hasFlag("v");

    if (output.use_colors) {
        std.debug.print("{s}Ananke{s} v{s}\n", .{
            output.Color.bold.code(),
            output.Color.reset.code(),
            VERSION,
        });
    } else {
        std.debug.print("Ananke v{s}\n", .{VERSION});
    }

    std.debug.print("Constraint-driven code generation system\n", .{});

    if (verbose) {
        std.debug.print("\n", .{});
        std.debug.print("Build Information:\n", .{});
        std.debug.print("  Build Date: {s}\n", .{BUILD_DATE});
        std.debug.print("  Zig Version: {s}\n", .{ZIG_VERSION});
        std.debug.print("\n", .{});
        std.debug.print("Components:\n", .{});
        std.debug.print("  Clew:    Constraint extraction engine\n", .{});
        std.debug.print("  Braid:   Constraint compilation engine\n", .{});
        std.debug.print("  Maze:    Inference orchestrator (Rust)\n", .{});
        std.debug.print("  Ariadne: DSL compiler (optional)\n", .{});
        std.debug.print("\n", .{});
        std.debug.print("Website: https://github.com/your-org/ananke\n", .{});
    }
}
