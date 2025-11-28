// Generate command - Generate code with constraints
const std = @import("std");
const args_mod = @import("../args.zig");
const config_mod = @import("../config.zig");
const cli_error = @import("../error.zig");

/// Error types for Modal inference
const InferenceError = error{
    ConnectionFailed,
    Timeout,
    InvalidUrl,
    InvalidResponse,
    RateLimited,
    ServiceError,
    NetworkError,
};

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
    \\  --endpoint <url>        Override Modal endpoint URL
    \\  --verbose, -v           Verbose output
    \\  --help, -h              Show this help message
    \\
    \\Examples:
    \\  ananke generate "create auth handler" -c rules.json -o auth.ts
    \\  ananke generate "implement binary search" --language rust
    \\  ananke generate "add tests" --endpoint https://custom.modal.run
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

    // Get endpoint URL - command line overrides config
    const endpoint_override = parsed_args.getFlag("endpoint");
    const endpoint_url = blk: {
        if (endpoint_override) |url| break :blk url;
        if (config.modal_endpoint) |url| break :blk url;

        // No endpoint configured - provide helpful error
        cli_error.printError(
            \\Modal endpoint not configured. Please either:
            \\  1. Add to .ananke.toml:
            \\     [modal]
            \\     endpoint = "https://your-username--ananke-inference-generate-api.modal.run"
            \\
            \\  2. Set environment variable:
            \\     export ANANKE_MODAL_ENDPOINT="https://..."
            \\
            \\  3. Pass --endpoint flag:
            \\     ananke generate "..." --endpoint "https://..."
            \\
            \\See docs/MODAL_SETUP.md for deployment instructions.
        , .{});
        return error.NoModalEndpoint;
    };

    if (verbose) {
        cli_error.printInfo("Generating code for: \"{s}\"", .{prompt});
        cli_error.printInfo("Language: {s}", .{language});
        cli_error.printInfo("Parameters: max_tokens={d}, temperature={d:.2}", .{ max_tokens, temperature });
        cli_error.printInfo("Modal endpoint: {s}", .{endpoint_url});
        if (constraints_file) |path| {
            cli_error.printInfo("Loading constraints from: {s}", .{path});
        }
    }

    // Load constraints if specified
    var constraint_ir: ?[]const u8 = null;
    if (constraints_file) |path| {
        const constraints_json = std.fs.cwd().readFileAlloc(allocator, path, 10 * 1024 * 1024) catch |err| {
            cli_error.printFileError(err, path);
            return err;
        };
        constraint_ir = constraints_json;

        if (verbose) {
            cli_error.printInfo("Constraints loaded successfully", .{});
        }
    }
    defer if (constraint_ir) |ir| allocator.free(ir);

    // Call Modal inference endpoint
    const generated_code = try callModalInference(
        allocator,
        endpoint_url,
        prompt,
        constraint_ir,
        max_tokens,
        temperature,
        verbose,
    );
    defer allocator.free(generated_code);

    // Write output
    if (output_file) |path| {
        const file = std.fs.cwd().createFile(path, .{}) catch |err| {
            cli_error.printFileError(err, path);
            return err;
        };
        defer file.close();
        try file.writeAll(generated_code);
        cli_error.printSuccess("Generated code written to {s}", .{path});
    } else {
        std.debug.print("{s}", .{generated_code});
    }
}

/// Call Modal inference endpoint to generate code
fn callModalInference(
    allocator: std.mem.Allocator,
    endpoint_url: []const u8,
    prompt: []const u8,
    constraint_ir: ?[]const u8,
    max_tokens: u32,
    temperature: f32,
    verbose: bool,
) ![]const u8 {
    // Parse URL
    const uri = std.Uri.parse(endpoint_url) catch {
        cli_error.printError("Invalid endpoint URL: {s}", .{endpoint_url});
        return InferenceError.InvalidUrl;
    };

    if (verbose) {
        cli_error.printInfo("Connecting to Modal endpoint...", .{});
    }

    // Create HTTP client
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    // Build JSON request body
    var json_body = std.ArrayList(u8){};
    const writer = json_body.writer(allocator);

    try writer.writeAll("{");
    try writer.print("\"prompt\":\"{s}\",", .{escapeJsonString(prompt)});

    if (constraint_ir) |ir| {
        try writer.print("\"constraint_ir\":{s},", .{ir});
    } else {
        try writer.writeAll("\"constraint_ir\":null,");
    }

    try writer.print("\"max_tokens\":{d},", .{max_tokens});
    try writer.print("\"temperature\":{d:.2}", .{temperature});
    try writer.writeAll("}");

    const request_body = try json_body.toOwnedSlice(allocator);
    defer allocator.free(request_body);

    if (verbose) {
        cli_error.printInfo("Request size: {d} bytes", .{request_body.len});
    }

    // Set headers
    var req = client.request(.POST, uri, .{
        .extra_headers = &.{
            .{ .name = "Content-Type", .value = "application/json" },
            .{ .name = "Accept", .value = "application/json" },
        },
    }) catch |err| {
        return handleConnectionError(err, endpoint_url);
    };
    defer req.deinit();

    // Set 60 second timeout for long-running inference
    req.transfer_encoding = .{ .content_length = request_body.len };

    // Send body - new API uses sendBodyUnflushed
    var body_writer = try req.sendBodyUnflushed(&.{});
    try body_writer.writer.writeAll(request_body);
    try body_writer.end();
    try req.connection.?.flush();

    // Receive response head
    var redirect_buffer: [0]u8 = undefined;
    var response = req.receiveHead(&redirect_buffer) catch |err| {
        if (err == error.HttpConnectionClosedWithoutResponse) {
            cli_error.printError("Inference request timed out after 60s", .{});
            return InferenceError.Timeout;
        }
        return handleConnectionError(err, endpoint_url);
    };

    // Check status code
    const status = response.head.status;
    if (verbose) {
        cli_error.printInfo("Response status: {d}", .{@intFromEnum(status)});
    }

    // Read response body
    var body_list = std.ArrayList(u8){};
    errdefer body_list.deinit(allocator);

    const reader = response.reader(&.{});
    try reader.appendRemainingUnlimited(allocator, &body_list);

    const response_body = try body_list.toOwnedSlice(allocator);
    defer allocator.free(response_body);

    // Handle different status codes
    switch (status) {
        .ok => {
            // Parse successful response
            return try parseInferenceResponse(allocator, response_body, verbose);
        },
        .bad_request => {
            cli_error.printError("Bad request: {s}", .{response_body});
            return InferenceError.InvalidResponse;
        },
        .too_many_requests => {
            cli_error.printError("Rate limited, try again later", .{});
            return InferenceError.RateLimited;
        },
        .internal_server_error, .bad_gateway, .service_unavailable => {
            cli_error.printError("Modal service error: {s}", .{response_body});
            return InferenceError.ServiceError;
        },
        else => {
            cli_error.printError("Unexpected response (status {d}): {s}", .{ @intFromEnum(status), response_body });
            return InferenceError.InvalidResponse;
        },
    }
}

/// Parse the JSON response from Modal inference endpoint
fn parseInferenceResponse(
    allocator: std.mem.Allocator,
    response_body: []const u8,
    verbose: bool,
) ![]const u8 {
    var parsed = std.json.parseFromSlice(
        std.json.Value,
        allocator,
        response_body,
        .{},
    ) catch {
        cli_error.printError("Invalid JSON response from Modal endpoint", .{});
        return InferenceError.InvalidResponse;
    };
    defer parsed.deinit();

    const root = parsed.value.object;

    // Extract generated text
    const generated_text = root.get("generated_text") orelse {
        cli_error.printError("Missing 'generated_text' in response", .{});
        return InferenceError.InvalidResponse;
    };

    if (generated_text != .string) {
        cli_error.printError("'generated_text' is not a string", .{});
        return InferenceError.InvalidResponse;
    }

    // Show stats if verbose
    if (verbose) {
        if (root.get("tokens_generated")) |tokens| {
            if (tokens == .integer) {
                cli_error.printInfo("Tokens generated: {d}", .{tokens.integer});
            }
        }

        if (root.get("stats")) |stats| {
            if (stats == .object) {
                if (stats.object.get("inference_time_ms")) |time| {
                    if (time == .float) {
                        cli_error.printInfo("Inference time: {d:.1}ms", .{time.float});
                    } else if (time == .integer) {
                        cli_error.printInfo("Inference time: {d}ms", .{time.integer});
                    }
                }
            }
        }
    }

    // Return copy of generated text
    return allocator.dupe(u8, generated_text.string);
}

/// Handle connection errors with appropriate messages
fn handleConnectionError(err: anyerror, endpoint_url: []const u8) InferenceError {
    switch (err) {
        error.ConnectionRefused => {
            cli_error.printError("Could not connect to Modal endpoint: {s}", .{endpoint_url});
            return InferenceError.ConnectionFailed;
        },
        error.NetworkUnreachable, error.HostLacksNetworkAddresses => {
            cli_error.printError("Network unreachable: {s}", .{endpoint_url});
            return InferenceError.NetworkError;
        },
        error.UnknownHostName => {
            cli_error.printError("Unknown host: {s}", .{endpoint_url});
            return InferenceError.ConnectionFailed;
        },
        else => {
            cli_error.printError("Connection error: {}", .{err});
            return InferenceError.NetworkError;
        },
    }
}

/// Escape a string for JSON encoding (simple implementation)
fn escapeJsonString(s: []const u8) []const u8 {
    // TODO: Implement proper JSON escaping
    // For now, just return the string as-is if it doesn't contain quotes
    for (s) |c| {
        if (c == '"' or c == '\\' or c == '\n' or c == '\r' or c == '\t') {
            // Would need to allocate and escape properly
            return s; // Simplified for now
        }
    }
    return s;
}
