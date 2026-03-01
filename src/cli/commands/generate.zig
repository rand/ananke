// Generate command - Generate code with constraints
const std = @import("std");
const args_mod = @import("cli_args");
const config_mod = @import("cli_config");
const cli_error = @import("cli_error");

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

const Backend = enum {
    modal,
    sglang,
};

pub const usage =
    \\Usage: ananke generate <prompt> [options]
    \\
    \\Generate code with constraints using an inference backend.
    \\
    \\Arguments:
    \\  <prompt>                Natural language prompt describing what to generate
    \\
    \\Options:
    \\  --backend <name>        Backend: "sglang" or "modal" (default: auto-detect)
    \\  --constraints, -c <file> Load constraints from file
    \\  --context <file>        Source file for rich context (types, imports, signatures)
    \\  --language <lang>       Target language (default: from config)
    \\  --output, -o <file>     Write generated code to file instead of stdout
    \\  --max-tokens <n>        Maximum tokens to generate (default: 4096)
    \\  --temperature <f>       Sampling temperature 0.0-1.0 (default: 0.7)
    \\  --model <name>          Model name for sglang backend
    \\  --endpoint <url>        Override endpoint URL
    \\  --verbose, -v           Verbose output
    \\  --help, -h              Show this help message
    \\
    \\Examples:
    \\  ananke generate "create auth handler" -c rules.json --backend sglang
    \\  ananke generate "add validation" --context src/models/user.py --backend sglang
    \\  ananke generate "implement binary search" --language rust
    \\  ananke generate "add tests" --backend modal --endpoint https://custom.modal.run
    \\
    \\Backends:
    \\  sglang   Connects to sglang server with --grammar-backend ananke.
    \\           Sends constraint_spec for multi-domain constrained decoding.
    \\  modal    Connects to Modal-deployed Maze inference endpoint.
    \\           Uses constraint_ir for syntax-only constrained generation.
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
    const context_file = parsed_args.getFlag("context");
    const language = parsed_args.getFlagOr("language", config.default_language);
    const output_file = parsed_args.getFlag("output") orelse parsed_args.getFlag("o");
    const max_tokens = try parsed_args.getFlagInt("max-tokens", u32) orelse config.max_tokens;
    const temperature = try parsed_args.getFlagFloat("temperature", f32) orelse config.temperature;
    const verbose = parsed_args.hasFlag("verbose") or parsed_args.hasFlag("v");
    const model_name = parsed_args.getFlag("model");

    // Determine backend
    const backend = blk: {
        if (parsed_args.getFlag("backend")) |name| {
            if (std.mem.eql(u8, name, "sglang")) break :blk Backend.sglang;
            if (std.mem.eql(u8, name, "modal")) break :blk Backend.modal;
            cli_error.printError("Unknown backend: \"{s}\". Use \"sglang\" or \"modal\".", .{name});
            return error.InvalidBackend;
        }
        // Auto-detect: prefer sglang if configured, fall back to modal
        if (config.sglang_endpoint != null) break :blk Backend.sglang;
        if (config.modal_endpoint != null) break :blk Backend.modal;
        break :blk Backend.modal;
    };

    // Resolve endpoint URL
    const endpoint_override = parsed_args.getFlag("endpoint");
    const endpoint_url = blk: {
        if (endpoint_override) |url| break :blk url;
        switch (backend) {
            .sglang => {
                if (config.sglang_endpoint) |url| break :blk url;
                cli_error.printError(
                    \\sglang endpoint not configured. Please either:
                    \\  1. Add to .ananke.toml:
                    \\     [sglang]
                    \\     endpoint = "http://localhost:30000/v1/chat/completions"
                    \\
                    \\  2. Set environment variable:
                    \\     export ANANKE_SGLANG_ENDPOINT="http://localhost:30000/v1/chat/completions"
                    \\
                    \\  3. Pass --endpoint flag:
                    \\     ananke generate "..." --backend sglang --endpoint "http://..."
                , .{});
                return error.NoSglangEndpoint;
            },
            .modal => {
                if (config.modal_endpoint) |url| break :blk url;
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
                , .{});
                return error.NoModalEndpoint;
            },
        }
    };

    if (verbose) {
        const backend_name = switch (backend) {
            .sglang => "sglang",
            .modal => "modal",
        };
        cli_error.printInfo("Generating code for: \"{s}\"", .{prompt});
        cli_error.printInfo("Backend: {s}", .{backend_name});
        cli_error.printInfo("Language: {s}", .{language});
        cli_error.printInfo("Parameters: max_tokens={d}, temperature={d:.2}", .{ max_tokens, temperature });
        cli_error.printInfo("Endpoint: {s}", .{endpoint_url});
        if (constraints_file) |path| {
            cli_error.printInfo("Loading constraints from: {s}", .{path});
        }
    }

    // Load constraints — from explicit file or auto-extracted from context
    const ananke_mod = @import("ananke");
    var constraint_ir: ?[]const u8 = null;
    var auto_extracted_ir: bool = false;
    if (constraints_file) |path| {
        const constraints_json = std.fs.cwd().readFileAlloc(allocator, path, 10 * 1024 * 1024) catch |err| {
            cli_error.printFileError(err, path);
            return err;
        };
        constraint_ir = constraints_json;

        if (verbose) {
            cli_error.printInfo("Constraints loaded from: {s}", .{path});
        }
    } else if (context_file != null) {
        // One-shot pipeline: auto-extract constraints from context file
        constraint_ir = autoExtractConstraintIR(allocator, context_file.?, language, verbose);
        if (constraint_ir != null) auto_extracted_ir = true;
    }
    defer if (constraint_ir) |ir| allocator.free(ir);

    // Extract rich context from source file for sglang's multi-domain decoding
    var rich_context: ?ananke_mod.types.constraint.RichContext = null;
    if (backend == .sglang and context_file != null) {
        rich_context = extractRichContextFromFile(allocator, context_file.?, language, verbose);
    }
    defer if (rich_context) |*rc| rc.deinit(allocator);

    // Call the appropriate backend
    const generated_code = switch (backend) {
        .sglang => try callSglangInference(
            allocator,
            endpoint_url,
            prompt,
            language,
            constraint_ir,
            if (rich_context) |*rc| rc else null,
            max_tokens,
            temperature,
            model_name,
            verbose,
        ),
        .modal => try callModalInference(
            allocator,
            endpoint_url,
            prompt,
            constraint_ir,
            max_tokens,
            temperature,
            verbose,
        ),
    };
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

/// Call sglang inference endpoint with OpenAI-compatible API + constraint_spec extension.
/// sglang with --grammar-backend ananke dispatches constraint_spec to AnankeBackend
/// for multi-domain constrained decoding.
fn callSglangInference(
    allocator: std.mem.Allocator,
    endpoint_url: []const u8,
    prompt: []const u8,
    language: []const u8,
    constraint_ir: ?[]const u8,
    rich_context: ?*const @import("ananke").types.constraint.RichContext,
    max_tokens: u32,
    temperature: f32,
    model_name: ?[]const u8,
    verbose: bool,
) ![]const u8 {
    const uri = std.Uri.parse(endpoint_url) catch {
        cli_error.printError("Invalid endpoint URL: {s}", .{endpoint_url});
        return InferenceError.InvalidUrl;
    };

    if (verbose) {
        cli_error.printInfo("Connecting to sglang endpoint...", .{});
    }

    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    // Build OpenAI-compatible request with constraint_spec extension
    var json_body = std.ArrayList(u8){};
    const writer = json_body.writer(allocator);

    const escaped_prompt = try escapeJsonString(allocator, prompt);
    defer if (escaped_prompt.ptr != prompt.ptr) allocator.free(escaped_prompt);

    const escaped_language = try escapeJsonString(allocator, language);
    defer if (escaped_language.ptr != language.ptr) allocator.free(escaped_language);

    try writer.writeAll("{");

    // Model field
    if (model_name) |m| {
        const escaped_model = try escapeJsonString(allocator, m);
        defer if (escaped_model.ptr != m.ptr) allocator.free(escaped_model);
        try writer.print("\"model\":\"{s}\",", .{escaped_model});
    } else {
        try writer.writeAll("\"model\":\"default\",");
    }

    // Messages in OpenAI chat format
    try writer.print("\"messages\":[{{\"role\":\"user\",\"content\":\"{s}\"}}],", .{escaped_prompt});

    // Generation parameters
    try writer.print("\"max_tokens\":{d},", .{max_tokens});
    try writer.print("\"temperature\":{d:.2},", .{temperature});

    // constraint_spec extension — this is what AnankeBackend dispatches on
    try writer.writeAll("\"constraint_spec\":{");
    try writer.print("\"language\":\"{s}\"", .{escaped_language});

    // If we have compiled constraint IR, extract json_schema for the syntax domain
    if (constraint_ir) |ir| {
        // Parse the IR to extract json_schema if present
        var parsed_ir = std.json.parseFromSlice(std.json.Value, allocator, ir, .{}) catch null;
        defer if (parsed_ir) |*p| p.deinit();

        if (parsed_ir) |p| {
            if (p.value == .object) {
                if (p.value.object.get("json_schema")) |schema| {
                    if (schema == .string) {
                        const escaped_schema = try escapeJsonString(allocator, schema.string);
                        defer if (escaped_schema.ptr != schema.string.ptr) allocator.free(escaped_schema);
                        try writer.print(",\"json_schema\":\"{s}\"", .{escaped_schema});
                    } else if (schema == .object or schema == .array) {
                        // Schema is already a JSON object/array — serialize inline
                        const schema_str = try std.json.Stringify.valueAlloc(allocator, schema, .{});
                        defer allocator.free(schema_str);
                        try writer.print(",\"json_schema\":{s}", .{schema_str});
                    }
                }
                if (p.value.object.get("grammar")) |grammar| {
                    if (grammar == .string) {
                        const escaped_grammar = try escapeJsonString(allocator, grammar.string);
                        defer if (escaped_grammar.ptr != grammar.string.ptr) allocator.free(escaped_grammar);
                        try writer.print(",\"ebnf\":\"{s}\"", .{escaped_grammar});
                    }
                }
            }
        }
    }

    // Rich context fields — seed all 5 CLaSH domains
    if (rich_context) |rc| {
        // Hard tier: Types, Imports
        if (rc.function_signatures_json) |fs| {
            try writer.print(",\"function_signatures\":{s}", .{fs});
        }
        if (rc.type_bindings_json) |tb| {
            try writer.print(",\"type_bindings\":{s}", .{tb});
        }
        if (rc.class_definitions_json) |cd| {
            try writer.print(",\"class_definitions\":{s}", .{cd});
        }
        if (rc.imports_json) |im| {
            try writer.print(",\"imports\":{s}", .{im});
        }
        // Soft tier: ControlFlow, Semantics
        if (rc.control_flow_json) |cf| {
            try writer.print(",\"control_flow\":{s}", .{cf});
        }
        if (rc.semantic_constraints_json) |sc| {
            try writer.print(",\"semantic_constraints\":{s}", .{sc});
        }
        if (rc.scope_bindings_json) |sb| {
            try writer.print(",\"scope_bindings\":{s}", .{sb});
        }
        if (verbose) {
            cli_error.printInfo("Rich context attached: functions={}, types={}, classes={}, imports={}, scope={}", .{
                rc.function_signatures_json != null,
                rc.type_bindings_json != null,
                rc.class_definitions_json != null,
                rc.imports_json != null,
                rc.scope_bindings_json != null,
            });
        }
    }

    try writer.writeAll("}"); // close constraint_spec
    try writer.writeAll("}"); // close request

    const request_body = try json_body.toOwnedSlice(allocator);
    defer allocator.free(request_body);

    if (verbose) {
        cli_error.printInfo("Request size: {d} bytes", .{request_body.len});
    }

    var req = client.request(.POST, uri, .{
        .extra_headers = &.{
            .{ .name = "Content-Type", .value = "application/json" },
            .{ .name = "Accept", .value = "application/json" },
        },
    }) catch |err| {
        return handleConnectionError(err, endpoint_url);
    };
    defer req.deinit();

    req.transfer_encoding = .{ .content_length = request_body.len };

    var body_writer = try req.sendBodyUnflushed(&.{});
    try body_writer.writer.writeAll(request_body);
    try body_writer.end();
    try req.connection.?.flush();

    var redirect_buffer: [2048]u8 = undefined;
    var response = req.receiveHead(&redirect_buffer) catch |err| {
        if (err == error.HttpConnectionClosedWithoutResponse) {
            cli_error.printError("sglang request timed out", .{});
            return InferenceError.Timeout;
        }
        return handleConnectionError(err, endpoint_url);
    };

    const status = response.head.status;
    if (verbose) {
        cli_error.printInfo("Response status: {d}", .{@intFromEnum(status)});
    }

    var body_list = std.ArrayList(u8){};
    errdefer body_list.deinit(allocator);

    const reader = response.reader(&.{});
    try reader.appendRemainingUnlimited(allocator, &body_list);

    const response_body = try body_list.toOwnedSlice(allocator);
    defer allocator.free(response_body);

    switch (status) {
        .ok => {
            return try parseSglangResponse(allocator, response_body, verbose);
        },
        .bad_request => {
            cli_error.printError("sglang bad request: {s}", .{response_body});
            return InferenceError.InvalidResponse;
        },
        .too_many_requests => {
            cli_error.printError("sglang rate limited, try again later", .{});
            return InferenceError.RateLimited;
        },
        .internal_server_error, .bad_gateway, .service_unavailable => {
            cli_error.printError("sglang service error: {s}", .{response_body});
            return InferenceError.ServiceError;
        },
        else => {
            cli_error.printError("sglang unexpected response (status {d}): {s}", .{ @intFromEnum(status), response_body });
            return InferenceError.InvalidResponse;
        },
    }
}

/// Parse OpenAI-compatible chat completion response from sglang
fn parseSglangResponse(
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
        cli_error.printError("Invalid JSON response from sglang", .{});
        return InferenceError.InvalidResponse;
    };
    defer parsed.deinit();

    const root = parsed.value.object;

    // OpenAI format: choices[0].message.content
    const choices = root.get("choices") orelse {
        cli_error.printError("Missing 'choices' in sglang response", .{});
        return InferenceError.InvalidResponse;
    };

    if (choices != .array or choices.array.items.len == 0) {
        cli_error.printError("Empty 'choices' in sglang response", .{});
        return InferenceError.InvalidResponse;
    }

    const first_choice = choices.array.items[0];
    if (first_choice != .object) {
        cli_error.printError("Invalid choice format in sglang response", .{});
        return InferenceError.InvalidResponse;
    }

    const message = first_choice.object.get("message") orelse {
        cli_error.printError("Missing 'message' in sglang response choice", .{});
        return InferenceError.InvalidResponse;
    };

    if (message != .object) {
        cli_error.printError("Invalid 'message' format in sglang response", .{});
        return InferenceError.InvalidResponse;
    }

    const content = message.object.get("content") orelse {
        cli_error.printError("Missing 'content' in sglang response message", .{});
        return InferenceError.InvalidResponse;
    };

    if (content != .string) {
        cli_error.printError("'content' is not a string in sglang response", .{});
        return InferenceError.InvalidResponse;
    }

    // Show usage stats if verbose
    if (verbose) {
        if (root.get("usage")) |usage_val| {
            if (usage_val == .object) {
                if (usage_val.object.get("completion_tokens")) |tokens| {
                    if (tokens == .integer) {
                        cli_error.printInfo("Completion tokens: {d}", .{tokens.integer});
                    }
                }
            }
        }
    }

    return allocator.dupe(u8, content.string);
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

    // Escape the prompt for JSON
    const escaped_prompt = try escapeJsonString(allocator, prompt);
    defer if (escaped_prompt.ptr != prompt.ptr) allocator.free(escaped_prompt);

    try writer.print("\"prompt\":\"{s}\",", .{escaped_prompt});

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
    var redirect_buffer: [2048]u8 = undefined;
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

/// Extract rich context from a source file. Returns null on any error.
/// Auto-extract constraint IR from a context file (one-shot pipeline).
/// Runs extract → compile and serializes the IR as JSON.
fn autoExtractConstraintIR(
    allocator: std.mem.Allocator,
    path: []const u8,
    language: []const u8,
    verbose: bool,
) ?[]const u8 {
    const ananke_mod = @import("ananke");
    const output_mod = @import("cli_output");

    const source = std.fs.cwd().readFileAlloc(allocator, path, 10 * 1024 * 1024) catch |err| {
        cli_error.printFileError(err, path);
        return null;
    };
    defer allocator.free(source);

    var engine = ananke_mod.Ananke.init(allocator) catch return null;
    defer engine.deinit();

    var constraint_set = engine.extract(source, language) catch return null;
    defer constraint_set.deinit();

    if (verbose) {
        cli_error.printInfo("Auto-extracted {d} constraints from: {s}", .{ constraint_set.constraints.items.len, path });
    }

    if (constraint_set.constraints.items.len == 0) return null;

    var ir = engine.compile(constraint_set.constraints.items) catch return null;
    defer ir.deinit(allocator);

    const ir_json = output_mod.formatIRJson(allocator, ir) catch return null;

    if (verbose) {
        cli_error.printInfo("Compiled constraint IR (priority={d})", .{ir.priority});
    }

    return ir_json;
}

fn extractRichContextFromFile(
    allocator: std.mem.Allocator,
    path: []const u8,
    language: []const u8,
    verbose: bool,
) ?@import("ananke").types.constraint.RichContext {
    const ananke_mod = @import("ananke");

    const source = std.fs.cwd().readFileAlloc(allocator, path, 10 * 1024 * 1024) catch |err| {
        cli_error.printFileError(err, path);
        return null;
    };
    defer allocator.free(source);

    var clew = ananke_mod.clew.Clew.init(allocator) catch {
        return null;
    };
    defer clew.deinit();

    const ctx = clew.extractRichContext(source, language) catch {
        return null;
    };

    if (verbose and ctx.hasData()) {
        cli_error.printInfo("Extracted rich context from: {s}", .{path});
    }

    return ctx;
}

/// Escape a string for JSON encoding
/// Returns an allocated string if escaping was needed, otherwise returns the original
/// Caller must free the returned slice if it differs from the input
fn escapeJsonString(allocator: std.mem.Allocator, s: []const u8) ![]const u8 {
    // First pass: check if we need to escape anything
    var needs_escape = false;
    var extra_bytes: usize = 0;

    for (s) |c| {
        switch (c) {
            '"', '\\' => {
                needs_escape = true;
                extra_bytes += 1; // Each becomes 2 chars (\", \\)
            },
            '\n', '\r', '\t' => {
                needs_escape = true;
                extra_bytes += 1; // Each becomes 2 chars (\n, \r, \t)
            },
            0x00...0x08, 0x0B...0x0C, 0x0E...0x1F => {
                // Other control characters (excluding \t, \n, \r which are handled above)
                needs_escape = true;
                extra_bytes += 5; // Becomes \uXXXX (6 chars total)
            },
            else => {},
        }
    }

    // Fast path: no escaping needed
    if (!needs_escape) {
        return s;
    }

    // Allocate buffer for escaped string
    const escaped = try allocator.alloc(u8, s.len + extra_bytes);
    var i: usize = 0;

    for (s) |c| {
        switch (c) {
            '"' => {
                escaped[i] = '\\';
                escaped[i + 1] = '"';
                i += 2;
            },
            '\\' => {
                escaped[i] = '\\';
                escaped[i + 1] = '\\';
                i += 2;
            },
            '\n' => {
                escaped[i] = '\\';
                escaped[i + 1] = 'n';
                i += 2;
            },
            '\r' => {
                escaped[i] = '\\';
                escaped[i + 1] = 'r';
                i += 2;
            },
            '\t' => {
                escaped[i] = '\\';
                escaped[i + 1] = 't';
                i += 2;
            },
            0x00...0x08, 0x0B...0x0C, 0x0E...0x1F => {
                // Escape other control characters as \uXXXX
                const hex_digits = "0123456789abcdef";
                escaped[i] = '\\';
                escaped[i + 1] = 'u';
                escaped[i + 2] = '0';
                escaped[i + 3] = '0';
                escaped[i + 4] = hex_digits[(c >> 4) & 0x0F];
                escaped[i + 5] = hex_digits[c & 0x0F];
                i += 6;
            },
            else => {
                escaped[i] = c;
                i += 1;
            },
        }
    }

    return escaped;
}

// Tests for JSON escaping
const testing = std.testing;

test "escapeJsonString: no special characters" {
    const allocator = testing.allocator;
    const input = "hello world";

    const result = try escapeJsonString(allocator, input);
    defer if (result.ptr != input.ptr) allocator.free(result);

    // Should return the same string (no allocation)
    try testing.expectEqual(input.ptr, result.ptr);
    try testing.expectEqualStrings(input, result);
}

test "escapeJsonString: empty string" {
    const allocator = testing.allocator;
    const input = "";

    const result = try escapeJsonString(allocator, input);
    defer if (result.ptr != input.ptr) allocator.free(result);

    try testing.expectEqual(input.ptr, result.ptr);
    try testing.expectEqualStrings("", result);
}

test "escapeJsonString: double quotes" {
    const allocator = testing.allocator;
    const input = "hello \"world\"";

    const result = try escapeJsonString(allocator, input);
    defer if (result.ptr != input.ptr) allocator.free(result);

    try testing.expectEqualStrings("hello \\\"world\\\"", result);
}

test "escapeJsonString: backslashes" {
    const allocator = testing.allocator;
    const input = "path\\to\\file";

    const result = try escapeJsonString(allocator, input);
    defer if (result.ptr != input.ptr) allocator.free(result);

    try testing.expectEqualStrings("path\\\\to\\\\file", result);
}

test "escapeJsonString: newlines" {
    const allocator = testing.allocator;
    const input = "line1\nline2\nline3";

    const result = try escapeJsonString(allocator, input);
    defer if (result.ptr != input.ptr) allocator.free(result);

    try testing.expectEqualStrings("line1\\nline2\\nline3", result);
}

test "escapeJsonString: carriage returns" {
    const allocator = testing.allocator;
    const input = "line1\rline2";

    const result = try escapeJsonString(allocator, input);
    defer if (result.ptr != input.ptr) allocator.free(result);

    try testing.expectEqualStrings("line1\\rline2", result);
}

test "escapeJsonString: tabs" {
    const allocator = testing.allocator;
    const input = "col1\tcol2\tcol3";

    const result = try escapeJsonString(allocator, input);
    defer if (result.ptr != input.ptr) allocator.free(result);

    try testing.expectEqualStrings("col1\\tcol2\\tcol3", result);
}

test "escapeJsonString: mixed special characters" {
    const allocator = testing.allocator;
    const input = "She said: \"It's in C:\\temp\"\nNext line\ttabbed";

    const result = try escapeJsonString(allocator, input);
    defer if (result.ptr != input.ptr) allocator.free(result);

    try testing.expectEqualStrings("She said: \\\"It's in C:\\\\temp\\\"\\nNext line\\ttabbed", result);
}

test "escapeJsonString: control characters" {
    const allocator = testing.allocator;
    // Test a control character (0x01)
    const input = "hello\x01world";

    const result = try escapeJsonString(allocator, input);
    defer if (result.ptr != input.ptr) allocator.free(result);

    try testing.expectEqualStrings("hello\\u0001world", result);
}

test "escapeJsonString: null byte" {
    const allocator = testing.allocator;
    const input = "hello\x00world";

    const result = try escapeJsonString(allocator, input);
    defer if (result.ptr != input.ptr) allocator.free(result);

    try testing.expectEqualStrings("hello\\u0000world", result);
}

test "escapeJsonString: multiple control characters" {
    const allocator = testing.allocator;
    const input = "\x00\x01\x02\x1F";

    const result = try escapeJsonString(allocator, input);
    defer if (result.ptr != input.ptr) allocator.free(result);

    try testing.expectEqualStrings("\\u0000\\u0001\\u0002\\u001f", result);
}
