// Tests for the generate command
const std = @import("std");
const testing = std.testing;
const generate = @import("generate");
const config_mod = @import("config");
const args_mod = @import("args");

// Mock HTTP server for testing
const MockServer = struct {
    allocator: std.mem.Allocator,
    server: *std.net.Server,
    thread: std.Thread,
    port: u16,
    response_status: u16 = 200,
    response_body: []const u8,
    should_timeout: bool = false,

    pub fn init(allocator: std.mem.Allocator) !*MockServer {
        var self = try allocator.create(MockServer);
        self.allocator = allocator;
        self.response_body =
            \\{"generated_text": "// Test generated code\nfunction test() { return 42; }", "tokens_generated": 15, "stats": {"inference_time_ms": 123.4}}
        ;
        self.should_timeout = false;

        // Start server on random port
        const address = try std.net.Address.parseIp("127.0.0.1", 0);
        self.server = try address.listen(.{
            .reuse_address = true,
        });

        // Get assigned port
        const server_addr = try self.server.getLocalAddress();
        self.port = server_addr.getPort();

        // Start server thread
        self.thread = try std.Thread.spawn(.{}, serverThread, .{self});

        return self;
    }

    pub fn deinit(self: *MockServer) void {
        self.server.deinit();
        self.thread.join();
        self.allocator.destroy(self);
    }

    pub fn getUrl(self: *MockServer, allocator: std.mem.Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{self.port});
    }

    fn serverThread(self: *MockServer) void {
        while (true) {
            const conn = self.server.accept() catch break;
            defer conn.stream.close();

            if (self.should_timeout) {
                // Simulate timeout by not responding
                std.time.sleep(100 * std.time.ns_per_ms);
                continue;
            }

            // Read request (simple parsing)
            var buf: [4096]u8 = undefined;
            _ = conn.stream.read(&buf) catch continue;

            // Send response
            const response = std.fmt.allocPrint(
                self.allocator,
                "HTTP/1.1 {d} OK\r\nContent-Type: application/json\r\nContent-Length: {d}\r\n\r\n{s}",
                .{ self.response_status, self.response_body.len, self.response_body },
            ) catch continue;
            defer self.allocator.free(response);

            conn.stream.writeAll(response) catch continue;
        }
    }
};

test "generate: successful inference request" {
    const allocator = testing.allocator;

    // Start mock server
    var mock = try MockServer.init(allocator);
    defer mock.deinit();

    const endpoint_url = try mock.getUrl(allocator);
    defer allocator.free(endpoint_url);

    // Create test config
    var config = config_mod.Config.init(allocator);
    defer config.deinit();

    // Parse test arguments
    const argv = [_][:0]const u8{
        "ananke",
        "generate",
        "create a test function",
        "--endpoint",
        endpoint_url,
        "--max-tokens",
        "100",
        "--temperature",
        "0.5",
    };
    var args = try args_mod.parse(allocator, argv[0..]);
    defer args.deinit();

    // Create temp output file
    const temp_dir = testing.tmpDir(.{});
    defer temp_dir.cleanup();

    const output_path = try std.fmt.allocPrint(allocator, "{s}/generated.js", .{temp_dir.dir.path});
    defer allocator.free(output_path);

    // Update args to include output file
    try args.flags.put("output", output_path);

    // Run generate command
    try generate.run(allocator, args, config);

    // Verify output file was created
    const file = try temp_dir.dir.openFile("generated.js", .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024);
    defer allocator.free(content);

    try testing.expect(std.mem.indexOf(u8, content, "function test()") != null);
}

test "generate: handle 429 rate limit" {
    const allocator = testing.allocator;

    // Start mock server with rate limit response
    var mock = try MockServer.init(allocator);
    defer mock.deinit();
    mock.response_status = 429;
    mock.response_body = "Rate limit exceeded";

    const endpoint_url = try mock.getUrl(allocator);
    defer allocator.free(endpoint_url);

    var config = config_mod.Config.init(allocator);
    defer config.deinit();

    const argv = [_][:0]const u8{
        "ananke",
        "generate",
        "test prompt",
        "--endpoint",
        endpoint_url,
    };
    var args = try args_mod.parse(allocator, argv[0..]);
    defer args.deinit();

    // Should return RateLimited error
    const result = generate.run(allocator, args, config);
    try testing.expectError(error.RateLimited, result);
}

test "generate: handle 500 server error" {
    const allocator = testing.allocator;

    // Start mock server with error response
    var mock = try MockServer.init(allocator);
    defer mock.deinit();
    mock.response_status = 500;
    mock.response_body = "Internal server error";

    const endpoint_url = try mock.getUrl(allocator);
    defer allocator.free(endpoint_url);

    var config = config_mod.Config.init(allocator);
    defer config.deinit();

    const argv = [_][:0]const u8{
        "ananke",
        "generate",
        "test prompt",
        "--endpoint",
        endpoint_url,
    };
    var args = try args_mod.parse(allocator, argv[0..]);
    defer args.deinit();

    // Should return ServiceError
    const result = generate.run(allocator, args, config);
    try testing.expectError(error.ServiceError, result);
}

test "generate: handle invalid JSON response" {
    const allocator = testing.allocator;

    // Start mock server with invalid JSON
    var mock = try MockServer.init(allocator);
    defer mock.deinit();
    mock.response_body = "not valid json";

    const endpoint_url = try mock.getUrl(allocator);
    defer allocator.free(endpoint_url);

    var config = config_mod.Config.init(allocator);
    defer config.deinit();

    const argv = [_][:0]const u8{
        "ananke",
        "generate",
        "test prompt",
        "--endpoint",
        endpoint_url,
    };
    var args = try args_mod.parse(allocator, argv[0..]);
    defer args.deinit();

    // Should return InvalidResponse error
    const result = generate.run(allocator, args, config);
    try testing.expectError(error.InvalidResponse, result);
}

test "generate: load constraints from file" {
    const allocator = testing.allocator;

    // Create test constraints file
    const temp_dir = testing.tmpDir(.{});
    defer temp_dir.cleanup();

    const constraints_path = try std.fmt.allocPrint(allocator, "{s}/constraints.json", .{temp_dir.dir.path});
    defer allocator.free(constraints_path);

    const constraints_file = try temp_dir.dir.createFile("constraints.json", .{});
    defer constraints_file.close();
    try constraints_file.writeAll(
        \\{"rules": [{"type": "type_safety", "enabled": true}]}
    );

    // Start mock server
    var mock = try MockServer.init(allocator);
    defer mock.deinit();

    const endpoint_url = try mock.getUrl(allocator);
    defer allocator.free(endpoint_url);

    var config = config_mod.Config.init(allocator);
    defer config.deinit();

    const argv = [_][:0]const u8{
        "ananke",
        "generate",
        "test with constraints",
        "--constraints",
        constraints_path,
        "--endpoint",
        endpoint_url,
    };
    var args = try args_mod.parse(allocator, argv[0..]);
    defer args.deinit();

    // Should successfully load and use constraints
    try generate.run(allocator, args, config);
}

test "generate: use config defaults" {
    const allocator = testing.allocator;

    // Start mock server
    var mock = try MockServer.init(allocator);
    defer mock.deinit();

    const endpoint_url = try mock.getUrl(allocator);
    defer allocator.free(endpoint_url);

    // Create config with custom defaults
    var config = config_mod.Config.init(allocator);
    defer config.deinit();
    config.modal_endpoint = try allocator.dupe(u8, endpoint_url);
    config.max_tokens = 2048;
    config.temperature = 0.3;
    config.default_language = "python";

    const argv = [_][:0]const u8{
        "ananke",
        "generate",
        "test with defaults",
    };
    var args = try args_mod.parse(allocator, argv[0..]);
    defer args.deinit();

    // Should use config defaults
    try generate.run(allocator, args, config);
}

test "generate: verbose output shows stats" {
    const allocator = testing.allocator;

    // Start mock server with detailed response
    var mock = try MockServer.init(allocator);
    defer mock.deinit();
    mock.response_body =
        \\{
        \\  "generated_text": "// Code",
        \\  "tokens_generated": 42,
        \\  "stats": {
        \\    "inference_time_ms": 567.8,
        \\    "model": "test-model"
        \\  }
        \\}
    ;

    const endpoint_url = try mock.getUrl(allocator);
    defer allocator.free(endpoint_url);

    var config = config_mod.Config.init(allocator);
    defer config.deinit();

    const argv = [_][:0]const u8{
        "ananke",
        "generate",
        "test verbose",
        "--endpoint",
        endpoint_url,
        "--verbose",
    };
    var args = try args_mod.parse(allocator, argv[0..]);
    defer args.deinit();

    // Should show verbose stats
    try generate.run(allocator, args, config);
}

test "generate: invalid endpoint URL" {
    const allocator = testing.allocator;

    var config = config_mod.Config.init(allocator);
    defer config.deinit();

    const argv = [_][:0]const u8{
        "ananke",
        "generate",
        "test",
        "--endpoint",
        "not a valid url",
    };
    var args = try args_mod.parse(allocator, argv[0..]);
    defer args.deinit();

    // Should return InvalidUrl error
    const result = generate.run(allocator, args, config);
    try testing.expectError(error.InvalidUrl, result);
}

test "generate: prompt with quotes is properly escaped" {
    const allocator = testing.allocator;

    // Start mock server
    var mock = try MockServer.init(allocator);
    defer mock.deinit();

    const endpoint_url = try mock.getUrl(allocator);
    defer allocator.free(endpoint_url);

    var config = config_mod.Config.init(allocator);
    defer config.deinit();

    // Test with prompt containing quotes
    const argv = [_][:0]const u8{
        "ananke",
        "generate",
        "create a function that returns \"hello world\"",
        "--endpoint",
        endpoint_url,
    };
    var args = try args_mod.parse(allocator, argv[0..]);
    defer args.deinit();

    // Should successfully escape quotes and generate valid JSON
    try generate.run(allocator, args, config);
}

test "generate: prompt with newlines is properly escaped" {
    const allocator = testing.allocator;

    // Start mock server
    var mock = try MockServer.init(allocator);
    defer mock.deinit();

    const endpoint_url = try mock.getUrl(allocator);
    defer allocator.free(endpoint_url);

    var config = config_mod.Config.init(allocator);
    defer config.deinit();

    // Test with prompt containing newlines
    const argv = [_][:0]const u8{
        "ananke",
        "generate",
        "create:\nfunction test()\nwith multiple lines",
        "--endpoint",
        endpoint_url,
    };
    var args = try args_mod.parse(allocator, argv[0..]);
    defer args.deinit();

    // Should successfully escape newlines and generate valid JSON
    try generate.run(allocator, args, config);
}