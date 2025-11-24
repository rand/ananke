// Generate command - Generate code with constraints
const std = @import("std");
const args_mod = @import("../args.zig");
const config_mod = @import("../config.zig");
const cli_error = @import("../error.zig");

pub const usage =
    \\Usage: ananke generate <prompt> [options]
    \\
    \\Generate code with constraints using Modal inference service.
    \\Requires Maze orchestrator to be deployed on Modal.
    \\
    \\Arguments:
    \\  <prompt>                Natural language prompt describing what to generate
    \\
    \\Options:
    \\  --constraints, -c <file> Load constraints from file
    \\  --language <lang>       Target language (default: from config)
    \\  --output, -o <file>     Write generated code to file instead of stdout
    \\  --max-tokens <n>        Maximum tokens to generate (default: 4096)
    \\  --temperature <f>       Sampling temperature 0.0-1.0 (default: 0.7)
    \\  --verbose, -v           Verbose output
    \\  --help, -h              Show this help message
    \\
    \\Examples:
    \\  ananke generate "create auth handler" -c rules.json -o auth.ts
    \\  ananke generate "implement binary search" --language rust
    \\
    \\Note: This command requires the Maze inference service to be deployed.
    \\      See docs/DEPLOYMENT.md for setup instructions.
;

pub fn run(allocator: std.mem.Allocator, parsed_args: args_mod.Args, config: config_mod.Config) !void {
    if (parsed_args.hasFlag("help") or parsed_args.hasFlag("h")) {
        std.debug.print("{s}\n", .{usage});
        return;
    }

    const prompt = parsed_args.getPositional(0) catch {
        cli_error.printError("Missing required argument: <prompt>", .{});
        std.debug.print("\n{s}\n", .{usage});
        return error.MissingArgument;
    };

    const constraints_file = parsed_args.getFlag("constraints") orelse parsed_args.getFlag("c");
    const language = parsed_args.getFlagOr("language", config.default_language);
    const output_file = parsed_args.getFlag("output") orelse parsed_args.getFlag("o");
    const max_tokens = try parsed_args.getFlagInt("max-tokens", u32) orelse config.max_tokens;
    const temperature = try parsed_args.getFlagFloat("temperature", f32) orelse config.temperature;
    const verbose = parsed_args.hasFlag("verbose") or parsed_args.hasFlag("v");

    if (verbose) {
        cli_error.printInfo("Generating code for: \"{s}\"", .{prompt});
        cli_error.printInfo("Language: {s}", .{language});
        cli_error.printInfo("Parameters: max_tokens={d}, temperature={d:.2}", .{ max_tokens, temperature });
        if (constraints_file) |path| {
            cli_error.printInfo("Loading constraints from: {s}", .{path});
        }
    }

    // Check for Modal configuration
    if (config.modal_endpoint == null) {
        cli_error.printErrorBox(
            "Modal Configuration Missing",
            "The generate command requires Modal inference service to be configured. " ++
                "Set ANANKE_MODAL_ENDPOINT environment variable or configure in .ananke.toml",
        );
        cli_error.printInfo("Run 'ananke init' to create a configuration file", .{});
        return error.ConfigError;
    }

    // Load constraints if specified
    if (constraints_file) |path| {
        const constraints_json = std.fs.cwd().readFileAlloc(allocator, path, 10 * 1024 * 1024) catch |err| {
            cli_error.printFileError(err, path);
            return err;
        };
        defer allocator.free(constraints_json);

        if (verbose) {
            cli_error.printInfo("Constraints loaded successfully", .{});
        }
    }

    // Display implementation note
    std.debug.print("\n", .{});
    std.debug.print("━" ** 70, .{});
    std.debug.print("\n", .{});
    cli_error.printInfo("Code generation via Maze orchestrator", .{});
    std.debug.print("━" ** 70, .{});
    std.debug.print("\n\n", .{});

    std.debug.print("This feature requires the Maze inference service deployed on Modal.\n\n", .{});
    std.debug.print("Setup steps:\n", .{});
    std.debug.print("  1. Build Maze: cd maze && cargo build --release\n", .{});
    std.debug.print("  2. Configure Modal: modal setup\n", .{});
    std.debug.print("  3. Deploy service: modal deploy maze/inference.py\n", .{});
    std.debug.print("  4. Set endpoint: export ANANKE_MODAL_ENDPOINT=https://your-app.modal.run\n\n", .{});

    // Mock output for demonstration
    const mock_code = try std.fmt.allocPrint(allocator,
        \\// Generated code (mock)
        \\// Prompt: {s}
        \\// Language: {s}
        \\
        \\export function example() {{
        \\    // TODO: Actual generation requires Maze deployment
        \\    return "Hello, World!";
        \\}}
        \\
    , .{ prompt, language });
    defer allocator.free(mock_code);

    if (output_file) |path| {
        const file = std.fs.cwd().createFile(path, .{}) catch |err| {
            cli_error.printFileError(err, path);
            return err;
        };
        defer file.close();
        try file.writeAll(mock_code);
        cli_error.printSuccess("Generated code written to {s}", .{path});
    } else {
        std.debug.print("{s}", .{mock_code});
    }
}
