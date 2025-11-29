// Extract command - Extract constraints from source code
const std = @import("std");
const ananke = @import("ananke");
const args_mod = @import("cli_args");
const output = @import("cli_output");
const config_mod = @import("cli_config");
const cli_error = @import("cli_error");
const error_help = @import("cli_error_help");
const path_validator = @import("path_validator");

pub const usage =
    \\Usage: ananke extract <file> [options]
    \\
    \\Extract constraints from source code using pattern matching and optional LLM analysis.
    \\
    \\Arguments:
    \\  <file>                  Source file to extract constraints from
    \\
    \\Options:
    \\  --language <lang>       Source language (auto-detected if not specified)
    \\  --format <fmt>          Output format: json, yaml, pretty, ariadne (default: pretty)
    \\  --output, -o <file>     Write output to file instead of stdout
    \\  --confidence <min>      Minimum confidence threshold (0.0-1.0, default: 0.5)
    \\  --use-claude            Enable Claude API for semantic analysis
    \\  --verbose, -v           Verbose output
    \\  --help, -h              Show this help message
    \\
    \\Examples:
    \\  ananke extract src/main.ts
    \\  ananke extract src/auth.py --use-claude --format json -o constraints.json
    \\  ananke extract lib.rs --confidence 0.7 --format ariadne
;

pub fn run(allocator: std.mem.Allocator, parsed_args: args_mod.Args, config: config_mod.Config) !void {
    // Check for help flag
    if (parsed_args.hasFlag("help") or parsed_args.hasFlag("h")) {
        std.debug.print("{s}\n", .{usage});
        return;
    }

    // Get required file argument
    const file_path = parsed_args.getPositional(0) catch {
        cli_error.printError("Missing required argument: <file>", .{});
        std.debug.print("\n{s}\n", .{usage});
        return error.MissingArgument;
    };

    // Parse options
    const language_override = parsed_args.getFlag("language");
    const format_str = parsed_args.getFlagOr("format", config.output_format);
    const output_file = parsed_args.getFlag("output") orelse parsed_args.getFlag("o");
    const confidence_threshold = try parsed_args.getFlagFloat("confidence", f32) orelse config.confidence_threshold;
    const use_claude = parsed_args.hasFlag("use-claude") or config.use_claude;
    const verbose = parsed_args.hasFlag("verbose") or parsed_args.hasFlag("v");

    // Validate format
    const format = output.OutputFormat.fromString(format_str) orelse {
        const valid_formats = &[_][]const u8{ "json", "yaml", "pretty", "ariadne" };
        error_help.printInvalidFormatError(format_str, valid_formats);
        return error.InvalidArgument;
    };

    // Validate confidence threshold
    if (confidence_threshold < 0.0 or confidence_threshold > 1.0) {
        cli_error.printError("Confidence threshold must be between 0.0 and 1.0", .{});
        return error.InvalidArgument;
    }

    if (verbose) {
        cli_error.printInfo("Extracting constraints from: {s}", .{file_path});
        if (use_claude) {
            cli_error.printInfo("Claude semantic analysis: enabled", .{});
        }
        cli_error.printInfo("Confidence threshold: {d:.1}%", .{confidence_threshold * 100});
    }

    // Validate and resolve file path (security: prevent path traversal)
    const validated_path = path_validator.validatePath(
        allocator,
        file_path,
        false, // Don't allow absolute paths by default
    ) catch |err| {
        if (err == path_validator.PathValidationError.PathTraversalAttempt) {
            cli_error.printError("Path traversal attempt detected: {s}", .{file_path});
            cli_error.printInfo("Only relative paths within the current directory are allowed.", .{});
            return error.InvalidPath;
        }
        if (err == error.FileNotFound) {
            error_help.printFileNotFoundError(file_path, allocator);
        } else {
            cli_error.printFileError(err, file_path);
        }
        return err;
    };
    defer allocator.free(validated_path);

    // Read source file
    const source = std.fs.cwd().readFileAlloc(allocator, validated_path, 10 * 1024 * 1024) catch |err| {
        if (err == error.FileNotFound) {
            error_help.printFileNotFoundError(validated_path, allocator);
        } else {
            cli_error.printFileError(err, validated_path);
        }
        return err;
    };
    defer allocator.free(source);

    // Detect or use specified language
    const language = language_override orelse detectLanguage(file_path);

    if (verbose) {
        cli_error.printInfo("Detected language: {s}", .{language});
    }

    // Initialize Ananke
    var ananke_instance = try ananke.Ananke.init(allocator);
    defer ananke_instance.deinit();

    // Initialize Claude client if requested and API key is available
    var claude_client_opt: ?ananke.api.claude.ClaudeClient = null;
    defer if (claude_client_opt) |*client| client.deinit();

    if (use_claude) {
        if (config.claude_api_key.slice()) |api_key| {
            const claude_config = ananke.api.claude.ClaudeConfig{
                .api_key = api_key,
                .endpoint = config.claude_endpoint orelse "https://api.anthropic.com/v1/messages",
                .model = config.claude_model,
                .max_tokens = config.max_tokens,
                .temperature = config.temperature,
                .timeout_ms = 30000,
            };

            claude_client_opt = try ananke.api.claude.ClaudeClient.init(allocator, claude_config);
            if (claude_client_opt) |*client| {
                ananke_instance.clew_engine.setClaudeClient(client);
            }

            if (verbose) {
                cli_error.printInfo("Claude client initialized with model: {s}", .{config.claude_model});
            }
        } else {
            // API key missing - provide detailed setup instructions
            error_help.printApiKeyMissingError("Claude");
            if (!verbose) {
                std.debug.print("\n", .{});
                cli_error.printWarning("Proceeding without semantic analysis", .{});
            }
        }
    }

    // Extract constraints
    var spinner = output.Spinner.init("Extracting constraints...");
    var constraint_set = try ananke_instance.extract(source, language);
    defer constraint_set.deinit();
    spinner.finish("Extraction complete");

    // Filter by confidence threshold
    const original_count = constraint_set.constraints.items.len;
    var i: usize = 0;
    while (i < constraint_set.constraints.items.len) {
        if (constraint_set.constraints.items[i].confidence < confidence_threshold) {
            _ = constraint_set.constraints.orderedRemove(i);
        } else {
            i += 1;
        }
    }

    const filtered_count = original_count - constraint_set.constraints.items.len;
    if (filtered_count > 0 and verbose) {
        cli_error.printInfo("Filtered {d} constraints below confidence threshold", .{filtered_count});
    }

    std.debug.print("Extracted {d} constraints\n", .{constraint_set.constraints.items.len});

    // Check for empty constraint set
    if (constraint_set.constraints.items.len == 0) {
        cli_error.printWarning("No constraints extracted from source file", .{});
        cli_error.printInfo("This could mean:", .{});
        cli_error.printInfo("  - The source file is empty or minimal", .{});
        cli_error.printInfo("  - The language is not fully supported", .{});
        cli_error.printInfo("  - The confidence threshold is too high", .{});
        if (!use_claude) {
            cli_error.printInfo("  - Try using --use-claude for semantic analysis", .{});
        }
        return;
    }

    // Format output
    const output_text = switch (format) {
        .json => try output.formatJson(allocator, constraint_set),
        .yaml => try output.formatYaml(allocator, constraint_set),
        .pretty => try output.formatPretty(allocator, constraint_set),
        .ariadne => try output.formatAriadne(allocator, constraint_set),
    };
    defer allocator.free(output_text);

    // Write output
    if (output_file) |path| {
        const file = std.fs.cwd().createFile(path, .{}) catch |err| {
            cli_error.printFileError(err, path);
            return err;
        };
        defer file.close();

        try file.writeAll(output_text);
        cli_error.printSuccess("Output written to {s}", .{path});
    } else {
        std.debug.print("\n{s}", .{output_text});
    }
}

fn detectLanguage(file_path: []const u8) []const u8 {
    if (std.mem.endsWith(u8, file_path, ".ts") or std.mem.endsWith(u8, file_path, ".tsx")) {
        return "typescript";
    } else if (std.mem.endsWith(u8, file_path, ".js") or std.mem.endsWith(u8, file_path, ".jsx")) {
        return "javascript";
    } else if (std.mem.endsWith(u8, file_path, ".py")) {
        return "python";
    } else if (std.mem.endsWith(u8, file_path, ".rs")) {
        return "rust";
    } else if (std.mem.endsWith(u8, file_path, ".go")) {
        return "go";
    } else if (std.mem.endsWith(u8, file_path, ".java")) {
        return "java";
    } else if (std.mem.endsWith(u8, file_path, ".zig")) {
        return "zig";
    } else if (std.mem.endsWith(u8, file_path, ".c")) {
        return "c";
    } else if (std.mem.endsWith(u8, file_path, ".cpp") or std.mem.endsWith(u8, file_path, ".cc")) {
        return "cpp";
    }
    return "unknown";
}
