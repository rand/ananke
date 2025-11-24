// Configuration file support for Ananke CLI
const std = @import("std");

pub const Config = struct {
    allocator: std.mem.Allocator,

    // Modal configuration
    modal_endpoint: ?[]const u8 = null,
    modal_api_key: ?[]const u8 = null,

    // Claude API configuration
    claude_api_key: ?[]const u8 = null,
    claude_endpoint: ?[]const u8 = null,
    claude_model: []const u8 = "claude-sonnet-4-5-20250929",

    // Default settings
    default_language: []const u8 = "typescript",
    max_tokens: u32 = 4096,
    temperature: f32 = 0.7,
    confidence_threshold: f32 = 0.5,
    output_format: []const u8 = "pretty",

    // Extract settings
    extract_patterns: []const []const u8 = &.{"all"},
    use_claude: bool = false,

    // Compile settings
    compile_priority: []const u8 = "medium",
    compile_formats: []const []const u8 = &.{"json-schema"},

    pub fn init(allocator: std.mem.Allocator) Config {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Config) void {
        if (self.modal_endpoint) |endpoint| {
            self.allocator.free(endpoint);
        }
        if (self.modal_api_key) |key| {
            self.allocator.free(key);
        }
        if (self.claude_api_key) |key| {
            self.allocator.free(key);
        }
        if (self.claude_endpoint) |endpoint| {
            self.allocator.free(endpoint);
        }
        // Note: Other fields are string literals or owned by caller
    }

    /// Load configuration from file
    pub fn loadFromFile(allocator: std.mem.Allocator, path: []const u8) !Config {
        var config = Config.init(allocator);

        const file = std.fs.cwd().openFile(path, .{}) catch |err| {
            if (err == error.FileNotFound) {
                // Config file doesn't exist, use defaults
                return config;
            }
            return err;
        };
        defer file.close();

        const content = try file.readToEndAlloc(allocator, 1024 * 1024);
        defer allocator.free(content);

        try config.parseToml(content);

        return config;
    }

    /// Load configuration from default locations
    pub fn loadDefault(allocator: std.mem.Allocator) !Config {
        var config = Config.init(allocator);

        // Try .ananke.toml in current directory
        const local_config = std.fs.cwd().openFile(".ananke.toml", .{}) catch |err| {
            if (err != error.FileNotFound) return err;
            null;
        };

        if (local_config) |file| {
            defer file.close();
            const content = try file.readToEndAlloc(allocator, 1024 * 1024);
            defer allocator.free(content);
            try config.parseToml(content);
        }

        // Override with environment variables
        try config.loadFromEnv();

        return config;
    }

    /// Load configuration from environment variables
    pub fn loadFromEnv(self: *Config) !void {
        if (std.process.getEnvVarOwned(self.allocator, "ANANKE_MODAL_ENDPOINT")) |endpoint| {
            if (self.modal_endpoint) |old| {
                self.allocator.free(old);
            }
            self.modal_endpoint = endpoint;
        } else |_| {}

        if (std.process.getEnvVarOwned(self.allocator, "ANANKE_MODAL_API_KEY")) |key| {
            if (self.modal_api_key) |old| {
                self.allocator.free(old);
            }
            self.modal_api_key = key;
        } else |_| {}

        // Check for Claude API key with standard Anthropic environment variable
        if (std.process.getEnvVarOwned(self.allocator, "ANTHROPIC_API_KEY")) |key| {
            if (self.claude_api_key) |old| {
                self.allocator.free(old);
            }
            self.claude_api_key = key;
            // If API key is present, enable Claude by default
            self.use_claude = true;
        } else |_| {
            // Also check for ANANKE-prefixed variable
            if (std.process.getEnvVarOwned(self.allocator, "ANANKE_CLAUDE_API_KEY")) |key| {
                if (self.claude_api_key) |old| {
                    self.allocator.free(old);
                }
                self.claude_api_key = key;
                self.use_claude = true;
            } else |_| {}
        }

        if (std.process.getEnvVarOwned(self.allocator, "ANANKE_CLAUDE_ENDPOINT")) |endpoint| {
            if (self.claude_endpoint) |old| {
                self.allocator.free(old);
            }
            self.claude_endpoint = endpoint;
        } else |_| {}

        if (std.process.getEnvVarOwned(self.allocator, "ANANKE_LANGUAGE")) |lang| {
            self.default_language = lang;
        } else |_| {}
    }

    /// Parse TOML configuration (simplified parser)
    pub fn parseToml(self: *Config, content: []const u8) !void {
        var lines = std.mem.splitSequence(u8, content, "\n");
        var current_section: ?[]const u8 = null;

        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t\r");

            // Skip empty lines and comments
            if (trimmed.len == 0 or trimmed[0] == '#') continue;

            // Section headers
            if (trimmed[0] == '[' and trimmed[trimmed.len - 1] == ']') {
                current_section = trimmed[1 .. trimmed.len - 1];
                continue;
            }

            // Key-value pairs
            if (std.mem.indexOf(u8, trimmed, "=")) |eq_pos| {
                const key = std.mem.trim(u8, trimmed[0..eq_pos], " \t");
                var value = std.mem.trim(u8, trimmed[eq_pos + 1 ..], " \t");

                // Remove quotes from string values
                if (value.len >= 2 and value[0] == '"' and value[value.len - 1] == '"') {
                    value = value[1 .. value.len - 1];
                }

                try self.setConfigValue(current_section, key, value);
            }
        }
    }

    /// Set a configuration value based on section and key
    fn setConfigValue(self: *Config, section: ?[]const u8, key: []const u8, value: []const u8) !void {
        if (section) |sec| {
            if (std.mem.eql(u8, sec, "modal")) {
                if (std.mem.eql(u8, key, "endpoint")) {
                    self.modal_endpoint = try self.allocator.dupe(u8, value);
                } else if (std.mem.eql(u8, key, "api_key")) {
                    self.modal_api_key = try self.allocator.dupe(u8, value);
                }
            } else if (std.mem.eql(u8, sec, "claude")) {
                if (std.mem.eql(u8, key, "api_key")) {
                    self.claude_api_key = try self.allocator.dupe(u8, value);
                    self.use_claude = true; // Enable if API key is configured
                } else if (std.mem.eql(u8, key, "endpoint")) {
                    self.claude_endpoint = try self.allocator.dupe(u8, value);
                } else if (std.mem.eql(u8, key, "model")) {
                    self.claude_model = value;
                } else if (std.mem.eql(u8, key, "enabled")) {
                    self.use_claude = std.mem.eql(u8, value, "true");
                }
            } else if (std.mem.eql(u8, sec, "defaults")) {
                if (std.mem.eql(u8, key, "language")) {
                    self.default_language = value;
                } else if (std.mem.eql(u8, key, "max_tokens")) {
                    self.max_tokens = try std.fmt.parseInt(u32, value, 10);
                } else if (std.mem.eql(u8, key, "temperature")) {
                    self.temperature = try std.fmt.parseFloat(f32, value);
                } else if (std.mem.eql(u8, key, "confidence_threshold")) {
                    self.confidence_threshold = try std.fmt.parseFloat(f32, value);
                } else if (std.mem.eql(u8, key, "output_format")) {
                    self.output_format = value;
                }
            } else if (std.mem.eql(u8, sec, "extract")) {
                if (std.mem.eql(u8, key, "use_claude")) {
                    self.use_claude = std.mem.eql(u8, value, "true");
                }
            } else if (std.mem.eql(u8, sec, "compile")) {
                if (std.mem.eql(u8, key, "priority")) {
                    self.compile_priority = value;
                }
            }
        }
    }

    /// Save configuration to file
    pub fn saveToFile(self: *const Config, path: []const u8) !void {
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        var buf: [4096]u8 = undefined;
        var writer = file.writer(&buf);

        try writer.interface.writeAll("# Ananke Configuration File\n\n");

        // Modal section
        try writer.interface.writeAll("[modal]\n");
        if (self.modal_endpoint) |endpoint| {
            try writer.interface.print("endpoint = \"{s}\"\n", .{endpoint});
        } else {
            try writer.interface.writeAll("# endpoint = \"https://your-app.modal.run\"\n");
        }
        try writer.interface.writeAll("# API key should be stored in environment variable ANANKE_MODAL_API_KEY\n");
        try writer.interface.writeAll("# or set here (not recommended for security)\n");
        if (self.modal_api_key) |_| {
            try writer.interface.writeAll("# api_key = \"your-key-here\"\n");
        }
        try writer.interface.writeAll("\n");

        // Claude section
        try writer.interface.writeAll("[claude]\n");
        try writer.interface.writeAll("# Claude API configuration for semantic analysis\n");
        try writer.interface.writeAll("# API key should be stored in environment variable ANTHROPIC_API_KEY\n");
        try writer.interface.writeAll("# or set here (not recommended for security)\n");
        if (self.claude_api_key) |_| {
            try writer.interface.writeAll("# api_key = \"sk-ant-...\"\n");
        }
        if (self.claude_endpoint) |endpoint| {
            try writer.interface.print("endpoint = \"{s}\"\n", .{endpoint});
        } else {
            try writer.interface.writeAll("# endpoint = \"https://api.anthropic.com/v1/messages\"\n");
        }
        try writer.interface.print("model = \"{s}\"\n", .{self.claude_model});
        try writer.interface.print("enabled = {s}\n", .{if (self.use_claude) "true" else "false"});
        try writer.interface.writeAll("\n");

        // Defaults section
        try writer.interface.writeAll("[defaults]\n");
        try writer.interface.print("language = \"{s}\"\n", .{self.default_language});
        try writer.interface.print("max_tokens = {d}\n", .{self.max_tokens});
        try writer.interface.print("temperature = {d:.1}\n", .{self.temperature});
        try writer.interface.print("confidence_threshold = {d:.1}\n", .{self.confidence_threshold});
        try writer.interface.print("output_format = \"{s}\"\n", .{self.output_format});
        try writer.interface.writeAll("\n");

        // Extract section
        try writer.interface.writeAll("[extract]\n");
        try writer.interface.print("use_claude = {s}\n", .{if (self.use_claude) "true" else "false"});
        try writer.interface.writeAll("patterns = [\"all\"]\n");
        try writer.interface.writeAll("\n");

        // Compile section
        try writer.interface.writeAll("[compile]\n");
        try writer.interface.print("priority = \"{s}\"\n", .{self.compile_priority});
        try writer.interface.writeAll("formats = [\"json-schema\"]\n");

        try writer.interface.flush();
    }

    /// Create a default configuration file
    pub fn createDefault(allocator: std.mem.Allocator, path: []const u8) !void {
        const config = Config.init(allocator);
        try config.saveToFile(path);
    }
};

test "config initialization" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var config = Config.init(allocator);
    defer config.deinit();

    try testing.expectEqualStrings("typescript", config.default_language);
    try testing.expectEqual(@as(u32, 4096), config.max_tokens);
    try testing.expectEqual(@as(f32, 0.7), config.temperature);
    try testing.expectEqual(@as(bool, false), config.use_claude);
    try testing.expectEqual(@as(?[]const u8, null), config.claude_api_key);
    try testing.expectEqual(@as(?[]const u8, null), config.claude_endpoint);
    try testing.expectEqualStrings("claude-sonnet-4-5-20250929", config.claude_model);
}

test "parse simple toml" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var config = Config.init(allocator);
    defer config.deinit();

    const toml =
        \\[defaults]
        \\language = "python"
        \\max_tokens = 2048
        \\temperature = 0.5
    ;

    try config.parseToml(toml);

    try testing.expectEqualStrings("python", config.default_language);
    try testing.expectEqual(@as(u32, 2048), config.max_tokens);
    try testing.expectEqual(@as(f32, 0.5), config.temperature);
}

test "config parse Claude section" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var config = Config.init(allocator);
    defer config.deinit();

    const toml =
        \\[claude]
        \\api_key = "test-api-key"
        \\endpoint = "https://test.anthropic.com/v1/messages"
        \\model = "claude-haiku-3-5-20241022"
        \\enabled = true
    ;

    try config.parseToml(toml);

    // Check Claude settings
    try testing.expectEqualStrings("test-api-key", config.claude_api_key.?);
    try testing.expectEqualStrings("https://test.anthropic.com/v1/messages", config.claude_endpoint.?);
    try testing.expectEqualStrings("claude-haiku-3-5-20241022", config.claude_model);
    try testing.expectEqual(true, config.use_claude);
}

test "config Claude API key auto-enables use_claude" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var config = Config.init(allocator);
    defer config.deinit();

    const toml =
        \\[claude]
        \\api_key = "sk-ant-test"
    ;

    try config.parseToml(toml);

    // Setting API key should auto-enable use_claude
    try testing.expectEqual(true, config.use_claude);
    try testing.expectEqualStrings("sk-ant-test", config.claude_api_key.?);
}
