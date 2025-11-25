//! Mock Modal Server for E2E Testing
//!
//! Simulates Modal API endpoints for deterministic testing
//! without external dependencies.

const std = @import("std");
const net = std.net;
const http = std.http;

const Allocator = std.mem.Allocator;

pub const MockServerConfig = struct {
    port: u16 = 8899,
    response_delay_ms: u32 = 0,
    should_fail: bool = false,
    error_code: u16 = 500,
    max_requests: ?u32 = null, // null = unlimited (for manual testing), or set a limit for tests
};

/// Run the mock Modal server
pub fn runMockServer(allocator: Allocator, config: MockServerConfig) !void {
    const address = try net.Address.parseIp("127.0.0.1", config.port);
    var server = try address.listen(.{
        .reuse_address = true,
    });
    defer server.deinit();

    std.debug.print("Mock Modal server listening on port {d}\n", .{config.port});

    var requests_handled: u32 = 0;
    while (true) {
        // Check if we've reached the request limit
        if (config.max_requests) |max| {
            if (requests_handled >= max) {
                std.debug.print("Mock server reached max_requests limit ({d}), shutting down\n", .{max});
                break;
            }
        }

        const connection = server.accept() catch |err| {
            std.debug.print("Accept error: {}\n", .{err});
            continue;
        };
        defer connection.stream.close();

        // Handle the request
        handleRequest(allocator, connection, config) catch |err| {
            std.debug.print("Request handling error: {}\n", .{err});
        };

        requests_handled += 1;
    }
}

fn handleRequest(
    allocator: Allocator,
    connection: net.Server.Connection,
    config: MockServerConfig,
) !void {
    var recv_buf: [4096]u8 = undefined;
    const recv_len = try connection.stream.read(&recv_buf);

    if (recv_len == 0) return;

    // Parse the request (simplified)
    const request = recv_buf[0..recv_len];

    // Add configurable delay
    if (config.response_delay_ms > 0) {
        std.Thread.sleep(config.response_delay_ms * std.time.ns_per_ms);
    }

    // Check if we should simulate an error
    if (config.should_fail) {
        const error_response = try std.fmt.allocPrint(
            allocator,
            "HTTP/1.1 {d} Internal Server Error\r\n" ++
            "Content-Type: application/json\r\n" ++
            "Content-Length: {d}\r\n" ++
            "\r\n" ++
            "{{\"error\": \"Mock server configured to fail\"}}",
            .{ config.error_code, 39 },
        );
        defer allocator.free(error_response);

        _ = try connection.stream.write(error_response);
        return;
    }

    // Determine endpoint from request
    if (std.mem.indexOf(u8, request, "POST /v1/constraints/validate")) |_| {
        try handleValidateConstraints(allocator, connection);
    } else if (std.mem.indexOf(u8, request, "POST /v1/generate")) |_| {
        try handleGenerate(allocator, connection);
    } else if (std.mem.indexOf(u8, request, "GET /v1/status")) |_| {
        try handleStatus(allocator, connection);
    } else {
        try handleNotFound(allocator, connection);
    }
}

fn handleValidateConstraints(
    allocator: Allocator,
    connection: net.Server.Connection,
) !void {
    const response_body =
        \\{
        \\  "valid": true,
        \\  "constraints": {
        \\    "total": 10,
        \\    "valid": 10,
        \\    "invalid": 0
        \\  },
        \\  "suggestions": []
        \\}
    ;

    const response = try std.fmt.allocPrint(
        allocator,
        "HTTP/1.1 200 OK\r\n" ++
        "Content-Type: application/json\r\n" ++
        "Content-Length: {d}\r\n" ++
        "X-Request-ID: mock-{d}\r\n" ++
        "\r\n" ++
        "{s}",
        .{
            response_body.len,
            std.crypto.random.int(u32),
            response_body,
        },
    );
    defer allocator.free(response);

    _ = try connection.stream.write(response);
}

fn handleGenerate(
    allocator: Allocator,
    connection: net.Server.Connection,
) !void {
    const response_body =
        \\{
        \\  "success": true,
        \\  "generated_code": "// Generated code from constraints\nfunction validate(input) {\n  return true;\n}",
        \\  "metadata": {
        \\    "model": "mock-model",
        \\    "tokens_used": 150,
        \\    "generation_time_ms": 250
        \\  }
        \\}
    ;

    const response = try std.fmt.allocPrint(
        allocator,
        "HTTP/1.1 200 OK\r\n" ++
        "Content-Type: application/json\r\n" ++
        "Content-Length: {d}\r\n" ++
        "X-Request-ID: mock-{d}\r\n" ++
        "\r\n" ++
        "{s}",
        .{
            response_body.len,
            std.crypto.random.int(u32),
            response_body,
        },
    );
    defer allocator.free(response);

    _ = try connection.stream.write(response);
}

fn handleStatus(
    allocator: Allocator,
    connection: net.Server.Connection,
) !void {
    const response_body =
        \\{
        \\  "status": "healthy",
        \\  "version": "mock-1.0.0",
        \\  "uptime_seconds": 3600
        \\}
    ;

    const response = try std.fmt.allocPrint(
        allocator,
        "HTTP/1.1 200 OK\r\n" ++
        "Content-Type: application/json\r\n" ++
        "Content-Length: {d}\r\n" ++
        "\r\n" ++
        "{s}",
        .{ response_body.len, response_body },
    );
    defer allocator.free(response);

    _ = try connection.stream.write(response);
}

fn handleNotFound(
    allocator: Allocator,
    connection: net.Server.Connection,
) !void {
    const response_body =
        \\{"error": "Endpoint not found"}
    ;

    const response = try std.fmt.allocPrint(
        allocator,
        "HTTP/1.1 404 Not Found\r\n" ++
        "Content-Type: application/json\r\n" ++
        "Content-Length: {d}\r\n" ++
        "\r\n" ++
        "{s}",
        .{ response_body.len, response_body },
    );
    defer allocator.free(response);

    _ = try connection.stream.write(response);
}

/// Mock constraint validation response
pub const ValidationResponse = struct {
    valid: bool,
    constraints: struct {
        total: u32,
        valid: u32,
        invalid: u32,
    },
    suggestions: []const u8,
};

/// Mock generation response
pub const GenerationResponse = struct {
    success: bool,
    generated_code: []const u8,
    metadata: struct {
        model: []const u8,
        tokens_used: u32,
        generation_time_ms: u32,
    },
};

// Test helpers for mock server

/// Check if the mock server is running
pub fn isServerRunning(port: u16) bool {
    const address = net.Address.parseIp("127.0.0.1", port) catch return false;

    var client = std.net.tcpConnectToAddress(address) catch return false;
    defer client.close();

    return true;
}

/// Send a test request to the mock server
pub fn sendTestRequest(
    allocator: Allocator,
    port: u16,
    endpoint: []const u8,
) ![]u8 {
    const address = try net.Address.parseIp("127.0.0.1", port);
    var client = try std.net.tcpConnectToAddress(address);
    defer client.close();

    const request = try std.fmt.allocPrint(
        allocator,
        "GET {s} HTTP/1.1\r\n" ++
        "Host: localhost:{d}\r\n" ++
        "Connection: close\r\n" ++
        "\r\n",
        .{ endpoint, port },
    );
    defer allocator.free(request);

    _ = try client.write(request);

    var response = std.ArrayList(u8).init(allocator);
    var buf: [1024]u8 = undefined;

    while (true) {
        const n = try client.read(&buf);
        if (n == 0) break;
        try response.appendSlice(buf[0..n]);
    }

    return response.toOwnedSlice();
}