// Enhanced error messages with context-aware help and documentation links
const std = @import("std");
const output = @import("cli_output");
const cli_error = @import("cli_error");

/// Documentation base URL
pub const DOCS_URL = "https://github.com/ananke-lang/ananke/tree/main/docs";

/// Print API key missing error with detailed setup instructions
pub fn printApiKeyMissingError(api_name: []const u8) void {
    cli_error.printError("API key for {s} not configured", .{api_name});
    std.debug.print("\n", .{});

    if (output.use_colors) {
        std.debug.print("{s}Setup Instructions:{s}\n", .{
            output.Color.cyan.code(),
            output.Color.reset.code()
        });
    } else {
        std.debug.print("Setup Instructions:\n", .{});
    }

    if (std.mem.eql(u8, api_name, "Claude")) {
        std.debug.print("  1. Get your API key from: {s}https://console.anthropic.com/settings/keys{s}\n", .{
            if (output.use_colors) output.Color.blue.code() else "",
            if (output.use_colors) output.Color.reset.code() else "",
        });
        std.debug.print("  2. Set the environment variable:\n", .{});
        std.debug.print("     {s}export ANTHROPIC_API_KEY=sk-ant-...{s}\n", .{
            if (output.use_colors) output.Color.green.code() else "",
            if (output.use_colors) output.Color.reset.code() else "",
        });
        std.debug.print("  3. Or add to .ananke.toml:\n", .{});
        std.debug.print("     {s}[claude]\n", .{
            if (output.use_colors) output.Color.green.code() else "",
        });
        std.debug.print("     # Note: Use environment variable for API key, not config file\n", .{});
        std.debug.print("     enabled = true{s}\n", .{
            if (output.use_colors) output.Color.reset.code() else "",
        });
    } else if (std.mem.eql(u8, api_name, "Modal")) {
        std.debug.print("  1. Create a Modal account: {s}https://modal.com{s}\n", .{
            if (output.use_colors) output.Color.blue.code() else "",
            if (output.use_colors) output.Color.reset.code() else "",
        });
        std.debug.print("  2. Run: {s}modal setup{s}\n", .{
            if (output.use_colors) output.Color.green.code() else "",
            if (output.use_colors) output.Color.reset.code() else "",
        });
        std.debug.print("  3. Deploy your app: {s}modal deploy modal_app.py{s}\n", .{
            if (output.use_colors) output.Color.green.code() else "",
            if (output.use_colors) output.Color.reset.code() else "",
        });
    }

    std.debug.print("\n{s}Documentation:{s} {s}/API_ERROR_HANDLING.md\n", .{
        if (output.use_colors) output.Color.blue.code() else "",
        if (output.use_colors) output.Color.reset.code() else "",
        DOCS_URL,
    });
}

/// Print network error with troubleshooting steps
pub fn printNetworkError(err: anyerror, endpoint: []const u8) void {
    cli_error.printError("Network request failed: {s}", .{@errorName(err)});
    std.debug.print("  Endpoint: {s}\n\n", .{endpoint});

    if (output.use_colors) {
        std.debug.print("{s}Troubleshooting:{s}\n", .{
            output.Color.cyan.code(),
            output.Color.reset.code()
        });
    } else {
        std.debug.print("Troubleshooting:\n", .{});
    }

    switch (err) {
        error.ConnectionRefused => {
            std.debug.print("  1. Check if the service is running\n", .{});
            std.debug.print("  2. Verify the endpoint URL is correct\n", .{});
            std.debug.print("  3. Check firewall settings\n", .{});
        },
        error.ConnectionTimedOut => {
            std.debug.print("  1. Check your internet connection: {s}curl -I https://www.google.com{s}\n", .{
                if (output.use_colors) output.Color.green.code() else "",
                if (output.use_colors) output.Color.reset.code() else "",
            });
            std.debug.print("  2. The service may be slow or overloaded (automatic retry in progress)\n", .{});
            std.debug.print("  3. Try again later or contact support\n", .{});
        },
        error.UnknownHostName, error.TemporarilyUnavailable => {
            std.debug.print("  1. Check DNS resolution: {s}nslookup {s}{s}\n", .{
                if (output.use_colors) output.Color.green.code() else "",
                endpoint,
                if (output.use_colors) output.Color.reset.code() else "",
            });
            std.debug.print("  2. Verify internet connectivity\n", .{});
            std.debug.print("  3. Check proxy/VPN settings if applicable\n", .{});
        },
        else => {
            std.debug.print("  1. Check your internet connection\n", .{});
            std.debug.print("  2. Verify firewall/proxy settings\n", .{});
            std.debug.print("  3. The service may be temporarily unavailable\n", .{});
        },
    }

    std.debug.print("\n{s}Note:{s} Ananke automatically retries failed requests with exponential backoff.\n", .{
        if (output.use_colors) output.Color.blue.code() else "",
        if (output.use_colors) output.Color.reset.code() else "",
    });
    std.debug.print("{s}Documentation:{s} {s}/API_ERROR_HANDLING.md#retry-strategy\n", .{
        if (output.use_colors) output.Color.blue.code() else "",
        if (output.use_colors) output.Color.reset.code() else "",
        DOCS_URL,
    });
}

/// Print HTTP status error with specific guidance
pub fn printHttpStatusError(status_code: u16, response_body: []const u8) void {
    cli_error.printError("HTTP {d}: {s}", .{ status_code, getStatusMessage(status_code) });

    if (response_body.len > 0 and response_body.len < 500) {
        std.debug.print("  Response: {s}\n", .{response_body});
    }
    std.debug.print("\n", .{});

    if (output.use_colors) {
        std.debug.print("{s}What this means:{s}\n", .{
            output.Color.cyan.code(),
            output.Color.reset.code()
        });
    } else {
        std.debug.print("What this means:\n", .{});
    }

    switch (status_code) {
        401 => {
            std.debug.print("  Your API key is invalid or missing.\n", .{});
            std.debug.print("\n{s}To fix:{s}\n", .{
                if (output.use_colors) output.Color.green.code() else "",
                if (output.use_colors) output.Color.reset.code() else "",
            });
            std.debug.print("  1. Verify your API key: {s}echo $ANTHROPIC_API_KEY{s}\n", .{
                if (output.use_colors) output.Color.green.code() else "",
                if (output.use_colors) output.Color.reset.code() else "",
            });
            std.debug.print("  2. Get a new key from: https://console.anthropic.com\n", .{});
            std.debug.print("  3. Set it: {s}export ANTHROPIC_API_KEY=sk-ant-...{s}\n", .{
                if (output.use_colors) output.Color.green.code() else "",
                if (output.use_colors) output.Color.reset.code() else "",
            });
        },
        403 => {
            std.debug.print("  You don't have permission to access this resource.\n", .{});
            std.debug.print("\n{s}To fix:{s}\n", .{
                if (output.use_colors) output.Color.green.code() else "",
                if (output.use_colors) output.Color.reset.code() else "",
            });
            std.debug.print("  1. Check if your API key has the required permissions\n", .{});
            std.debug.print("  2. Verify your account subscription level\n", .{});
            std.debug.print("  3. Contact support if you believe this is an error\n", .{});
        },
        404 => {
            std.debug.print("  The API endpoint was not found.\n", .{});
            std.debug.print("\n{s}To fix:{s}\n", .{
                if (output.use_colors) output.Color.green.code() else "",
                if (output.use_colors) output.Color.reset.code() else "",
            });
            std.debug.print("  1. Check your endpoint configuration in .ananke.toml\n", .{});
            std.debug.print("  2. Verify you're using the latest version of Ananke\n", .{});
            std.debug.print("  3. For Modal: ensure your app is deployed: {s}modal app list{s}\n", .{
                if (output.use_colors) output.Color.green.code() else "",
                if (output.use_colors) output.Color.reset.code() else "",
            });
        },
        413 => {
            std.debug.print("  Your request payload is too large.\n", .{});
            std.debug.print("\n{s}To fix:{s}\n", .{
                if (output.use_colors) output.Color.green.code() else "",
                if (output.use_colors) output.Color.reset.code() else "",
            });
            std.debug.print("  1. Reduce the input file size\n", .{});
            std.debug.print("  2. Split large files into smaller chunks\n", .{});
            std.debug.print("  3. Use confidence threshold to filter constraints: {s}--confidence 0.7{s}\n", .{
                if (output.use_colors) output.Color.green.code() else "",
                if (output.use_colors) output.Color.reset.code() else "",
            });
        },
        429 => {
            std.debug.print("  You've hit the rate limit.\n", .{});
            std.debug.print("\n{s}What's happening:{s}\n", .{
                if (output.use_colors) output.Color.yellow.code() else "",
                if (output.use_colors) output.Color.reset.code() else "",
            });
            std.debug.print("  Ananke is automatically retrying with exponential backoff.\n", .{});
            std.debug.print("  Please wait...\n", .{});
            std.debug.print("\n{s}To prevent this:{s}\n", .{
                if (output.use_colors) output.Color.green.code() else "",
                if (output.use_colors) output.Color.reset.code() else "",
            });
            std.debug.print("  1. Reduce request frequency\n", .{});
            std.debug.print("  2. Upgrade your API tier if available\n", .{});
            std.debug.print("  3. Use caching to avoid redundant requests\n", .{});
        },
        500, 502, 503, 504 => {
            std.debug.print("  The server encountered an error or is temporarily unavailable.\n", .{});
            std.debug.print("\n{s}What's happening:{s}\n", .{
                if (output.use_colors) output.Color.yellow.code() else "",
                if (output.use_colors) output.Color.reset.code() else "",
            });
            std.debug.print("  Ananke is automatically retrying (up to 3 attempts).\n", .{});
            std.debug.print("\n{s}If retries fail:{s}\n", .{
                if (output.use_colors) output.Color.green.code() else "",
                if (output.use_colors) output.Color.reset.code() else "",
            });
            std.debug.print("  1. Wait a few minutes and try again\n", .{});
            std.debug.print("  2. Check service status: https://status.anthropic.com\n", .{});
            std.debug.print("  3. For Modal: {s}modal app logs <app-name>{s}\n", .{
                if (output.use_colors) output.Color.green.code() else "",
                if (output.use_colors) output.Color.reset.code() else "",
            });
        },
        else => {
            std.debug.print("  An unexpected HTTP error occurred.\n", .{});
        },
    }

    std.debug.print("\n{s}Documentation:{s} {s}/API_ERROR_HANDLING.md#error-codes\n", .{
        if (output.use_colors) output.Color.blue.code() else "",
        if (output.use_colors) output.Color.reset.code() else "",
        DOCS_URL,
    });
}

/// Print file not found error with directory context
pub fn printFileNotFoundError(path: []const u8, allocator: std.mem.Allocator) void {
    cli_error.printError("File not found: {s}", .{path});

    // Show current directory for context
    var cwd_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const cwd = std.fs.cwd().realpath(".", &cwd_buffer) catch ".";

    std.debug.print("  Current directory: {s}\n\n", .{cwd});

    if (output.use_colors) {
        std.debug.print("{s}Suggestions:{s}\n", .{
            output.Color.cyan.code(),
            output.Color.reset.code()
        });
    } else {
        std.debug.print("Suggestions:\n", .{});
    }

    std.debug.print("  1. Check if the file exists: {s}ls {s}{s}\n", .{
        if (output.use_colors) output.Color.green.code() else "",
        path,
        if (output.use_colors) output.Color.reset.code() else "",
    });
    std.debug.print("  2. Verify the file path is correct (relative to current directory)\n", .{});
    std.debug.print("  3. Check for typos in the filename\n", .{});

    // Try to find similar files
    const dir_path = std.fs.path.dirname(path) orelse ".";
    const basename = std.fs.path.basename(path);

    std.debug.print("\n{s}Looking for similar files in {s}...{s}\n", .{
        if (output.use_colors) output.Color.gray.code() else "",
        dir_path,
        if (output.use_colors) output.Color.reset.code() else "",
    });

    findSimilarFiles(dir_path, basename, allocator) catch {};
}

/// Print invalid format error with examples
pub fn printInvalidFormatError(format: []const u8, valid_formats: []const []const u8) void {
    cli_error.printError("Invalid format: '{s}'", .{format});
    std.debug.print("\n", .{});

    if (output.use_colors) {
        std.debug.print("{s}Valid formats:{s}\n", .{
            output.Color.cyan.code(),
            output.Color.reset.code()
        });
    } else {
        std.debug.print("Valid formats:\n", .{});
    }

    for (valid_formats) |valid_fmt| {
        std.debug.print("  • {s}{s}{s}\n", .{
            if (output.use_colors) output.Color.green.code() else "",
            valid_fmt,
            if (output.use_colors) output.Color.reset.code() else "",
        });
    }

    std.debug.print("\n{s}Example:{s}\n", .{
        if (output.use_colors) output.Color.cyan.code() else "",
        if (output.use_colors) output.Color.reset.code() else "",
    });
    std.debug.print("  ananke extract src/main.ts {s}--format {s}{s}\n", .{
        if (output.use_colors) output.Color.green.code() else "",
        valid_formats[0],
        if (output.use_colors) output.Color.reset.code() else "",
    });
}

/// Print compilation error with phase information
pub fn printCompilationError(phase: []const u8, details: []const u8) void {
    cli_error.printError("Compilation failed during {s}", .{phase});
    std.debug.print("  {s}\n\n", .{details});

    if (output.use_colors) {
        std.debug.print("{s}What went wrong:{s}\n", .{
            output.Color.cyan.code(),
            output.Color.reset.code()
        });
    } else {
        std.debug.print("What went wrong:\n", .{});
    }

    if (std.mem.eql(u8, phase, "parsing")) {
        std.debug.print("  The constraint file has invalid JSON/YAML syntax.\n", .{});
        std.debug.print("\n{s}To fix:{s}\n", .{
            if (output.use_colors) output.Color.green.code() else "",
            if (output.use_colors) output.Color.reset.code() else "",
        });
        std.debug.print("  1. Validate JSON: {s}jq . constraints.json{s}\n", .{
            if (output.use_colors) output.Color.green.code() else "",
            if (output.use_colors) output.Color.reset.code() else "",
        });
        std.debug.print("  2. Check for missing commas, quotes, or brackets\n", .{});
        std.debug.print("  3. Ensure valid UTF-8 encoding\n", .{});
    } else if (std.mem.eql(u8, phase, "validation")) {
        std.debug.print("  The constraints have invalid values or missing required fields.\n", .{});
        std.debug.print("\n{s}To fix:{s}\n", .{
            if (output.use_colors) output.Color.green.code() else "",
            if (output.use_colors) output.Color.reset.code() else "",
        });
        std.debug.print("  1. Ensure all constraints have 'name' field\n", .{});
        std.debug.print("  2. Check confidence values are between 0.0 and 1.0\n", .{});
        std.debug.print("  3. Verify constraint kinds are valid (syntactic, semantic, etc.)\n", .{});
    } else if (std.mem.eql(u8, phase, "IR generation")) {
        std.debug.print("  Failed to generate intermediate representation.\n", .{});
        std.debug.print("\n{s}To fix:{s}\n", .{
            if (output.use_colors) output.Color.green.code() else "",
            if (output.use_colors) output.Color.reset.code() else "",
        });
        std.debug.print("  1. Try reducing optimization level: {s}--optimize-level 0{s}\n", .{
            if (output.use_colors) output.Color.green.code() else "",
            if (output.use_colors) output.Color.reset.code() else "",
        });
        std.debug.print("  2. Filter low-confidence constraints: {s}--confidence 0.7{s}\n", .{
            if (output.use_colors) output.Color.green.code() else "",
            if (output.use_colors) output.Color.reset.code() else "",
        });
        std.debug.print("  3. Check for circular dependencies in constraints\n", .{});
    }

    std.debug.print("\n{s}Documentation:{s} {s}/COMPILE_COMMAND.md#troubleshooting\n", .{
        if (output.use_colors) output.Color.blue.code() else "",
        if (output.use_colors) output.Color.reset.code() else "",
        DOCS_URL,
    });
}

/// Print progress bar for long operations
pub const ProgressBar = struct {
    total: usize,
    current: usize,
    message: []const u8,
    width: usize = 40,

    pub fn init(total: usize, message: []const u8) ProgressBar {
        return .{
            .total = total,
            .current = 0,
            .message = message,
        };
    }

    pub fn update(self: *ProgressBar, current: usize) void {
        self.current = current;
        if (!output.use_colors) return;

        const percent = if (self.total > 0)
            @as(usize, @intFromFloat(@as(f64, @floatFromInt(current)) / @as(f64, @floatFromInt(self.total)) * 100))
        else
            0;
        const filled = if (self.total > 0)
            @as(usize, @intFromFloat(@as(f64, @floatFromInt(current)) / @as(f64, @floatFromInt(self.total)) * @as(f64, @floatFromInt(self.width))))
        else
            0;

        std.debug.print("\r{s} [{s}", .{ self.message, output.Color.green.code() });
        var i: usize = 0;
        while (i < self.width) : (i += 1) {
            if (i < filled) {
                std.debug.print("█", .{});
            } else {
                std.debug.print("░", .{});
            }
        }
        std.debug.print("{s}] {d}%", .{ output.Color.reset.code(), percent });
    }

    pub fn finish(self: *ProgressBar) void {
        if (output.use_colors) {
            std.debug.print("\r{s}✓{s} {s} [{s}complete{s}]\n", .{
                output.Color.green.code(),
                output.Color.reset.code(),
                self.message,
                output.Color.green.code(),
                output.Color.reset.code(),
            });
        } else {
            std.debug.print("{s} [complete]\n", .{self.message});
        }
    }
};

// Helper functions

fn getStatusMessage(status_code: u16) []const u8 {
    return switch (status_code) {
        400 => "Bad Request",
        401 => "Unauthorized",
        403 => "Forbidden",
        404 => "Not Found",
        413 => "Payload Too Large",
        429 => "Too Many Requests (Rate Limited)",
        500 => "Internal Server Error",
        502 => "Bad Gateway",
        503 => "Service Unavailable",
        504 => "Gateway Timeout",
        else => "Unknown Error",
    };
}

fn findSimilarFiles(dir_path: []const u8, target: []const u8, allocator: std.mem.Allocator) !void {
    _ = allocator;

    var dir = std.fs.cwd().openDir(dir_path, .{ .iterate = true }) catch |err| {
        std.debug.print("  (Could not list directory: {s})\n", .{@errorName(err)});
        return;
    };
    defer dir.close();

    var iter = dir.iterate();
    var found_count: usize = 0;

    while (try iter.next()) |entry| {
        if (entry.kind == .file) {
            // Simple similarity check: case-insensitive prefix match
            if (std.ascii.startsWithIgnoreCase(entry.name, target[0..@min(3, target.len)])) {
                if (found_count == 0) {
                    std.debug.print("  {s}Did you mean one of these?{s}\n", .{
                        if (output.use_colors) output.Color.yellow.code() else "",
                        if (output.use_colors) output.Color.reset.code() else "",
                    });
                }
                std.debug.print("    • {s}{s}{s}\n", .{
                    if (output.use_colors) output.Color.green.code() else "",
                    entry.name,
                    if (output.use_colors) output.Color.reset.code() else "",
                });
                found_count += 1;
                if (found_count >= 5) break; // Limit to 5 suggestions
            }
        }
    }

    if (found_count == 0) {
        std.debug.print("  (No similar files found)\n", .{});
    }
}
