// HTTP client utilities for Ananke
// Provides simple HTTP POST wrapper for API calls
const std = @import("std");

/// HTTP client configuration
pub const HttpClient = struct {
    allocator: std.mem.Allocator,
    timeout_ms: u32 = 30000,

    pub fn init(allocator: std.mem.Allocator) HttpClient {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *HttpClient) void {
        _ = self;
    }
};

/// HTTP request configuration
pub const HttpRequest = struct {
    url: []const u8,
    method: []const u8 = "POST",
    headers: []const Header,
    body: ?[]const u8 = null,

    pub const Header = struct {
        name: []const u8,
        value: []const u8,
    };
};

/// HTTP response
pub const HttpResponse = struct {
    status_code: u16,
    headers: std.StringHashMap([]const u8),
    body: []const u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *HttpResponse) void {
        // Free header keys and values
        var iter = self.headers.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.headers.deinit();
        self.allocator.free(self.body);
    }
};

/// HTTP client errors
pub const HttpError = error{
    ConnectionFailed,
    Timeout,
    InvalidUrl,
    RequestFailed,
    InvalidResponse,
    TooManyRedirects,
};

/// Send an HTTP POST request with JSON body
pub fn post(
    allocator: std.mem.Allocator,
    url: []const u8,
    headers: []const HttpRequest.Header,
    json_body: []const u8,
) !HttpResponse {
    const uri = std.Uri.parse(url) catch {
        return HttpError.InvalidUrl;
    };

    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    // Build extra headers for the request
    var extra_headers = std.ArrayList(std.http.Header){};
    defer extra_headers.deinit(allocator);

    for (headers) |header| {
        try extra_headers.append(allocator, .{
            .name = header.name,
            .value = header.value,
        });
    }

    // Make the request
    var req = client.request(.POST, uri, .{
        .extra_headers = extra_headers.items,
    }) catch |err| {
        return switch (err) {
            error.ConnectionRefused => HttpError.ConnectionFailed,
            error.NetworkUnreachable => HttpError.ConnectionFailed,
            error.ConnectionTimedOut => HttpError.Timeout,
            error.UnknownHostName => HttpError.ConnectionFailed,
            error.HostLacksNetworkAddresses => HttpError.ConnectionFailed,
            else => err,
        };
    };
    defer req.deinit();

    // Send request with body
    req.transfer_encoding = .{ .content_length = json_body.len };
    var body_writer = try req.sendBodyUnflushed(&.{});
    try body_writer.writer.writeAll(json_body);
    try body_writer.end();
    try req.connection.?.flush();

    // Receive response head
    var redirect_buffer: [0]u8 = undefined;
    var response = try req.receiveHead(&redirect_buffer);

    const status_code: u16 = @intFromEnum(response.head.status);

    // Copy response headers BEFORE reading body
    var response_headers = std.StringHashMap([]const u8).init(allocator);
    errdefer response_headers.deinit();

    var iter = response.head.iterateHeaders();
    while (iter.next()) |header| {
        const name = try allocator.dupe(u8, header.name);
        errdefer allocator.free(name);
        const value = try allocator.dupe(u8, header.value);
        errdefer allocator.free(value);
        try response_headers.put(name, value);
    }

    // Read response body
    var body_list = std.ArrayList(u8){};
    errdefer body_list.deinit(allocator);

    const reader = response.reader(&.{});
    try reader.appendRemainingUnlimited(allocator, &body_list);

    const body = try body_list.toOwnedSlice(allocator);
    errdefer allocator.free(body);

    return HttpResponse{
        .status_code = status_code,
        .headers = response_headers,
        .allocator = allocator,
        .body = body,
    };
}

/// Parse JSON response body
pub fn parseJson(
    allocator: std.mem.Allocator,
    json_text: []const u8,
) !std.json.Parsed(std.json.Value) {
    return try std.json.parseFromSlice(std.json.Value, allocator, json_text, .{});
}

/// Build JSON request body from a struct
/// Note: This is a simplified version for Claude API messages
pub fn buildJsonBody(
    allocator: std.mem.Allocator,
    value: anytype,
) ![]const u8 {
    const T = @TypeOf(value);
    const type_info = @typeInfo(T);

    if (type_info != .@"struct") {
        @compileError("buildJsonBody only supports struct types");
    }

    var buf = std.ArrayList(u8){};
    errdefer buf.deinit(allocator);
    const writer = buf.writer(allocator);

    try writer.writeAll("{");

    inline for (type_info.@"struct".fields, 0..) |field, i| {
        if (i > 0) try writer.writeAll(",");
        try writer.print("\"{s}\":", .{field.name});

        const field_value = @field(value, field.name);
        const FieldType = @TypeOf(field_value);

        switch (@typeInfo(FieldType)) {
            .pointer => |ptr_info| {
                if (ptr_info.child == u8) {
                    try writer.print("\"{s}\"", .{field_value});
                } else if (@typeInfo(ptr_info.child) == .@"struct") {
                    try writer.writeAll("[");
                    for (field_value, 0..) |item, j| {
                        if (j > 0) try writer.writeAll(",");
                        const json = try buildJsonBody(allocator, item);
                        defer allocator.free(json);
                        try writer.writeAll(json);
                    }
                    try writer.writeAll("]");
                }
            },
            .int => try writer.print("{d}", .{field_value}),
            .float => try writer.print("{d}", .{field_value}),
            .@"struct" => {
                const json = try buildJsonBody(allocator, field_value);
                defer allocator.free(json);
                try writer.writeAll(json);
            },
            else => {},
        }
    }

    try writer.writeAll("}");
    return try buf.toOwnedSlice(allocator);
}

test "HTTP client basic functionality" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var client = HttpClient.init(allocator);
    defer client.deinit();

    // Test JSON body building
    const TestStruct = struct {
        name: []const u8,
        value: i32,
    };

    const test_data = TestStruct{
        .name = "test",
        .value = 42,
    };

    const json = try buildJsonBody(allocator, test_data);
    defer allocator.free(json);

    try testing.expect(std.mem.indexOf(u8, json, "test") != null);
    try testing.expect(std.mem.indexOf(u8, json, "42") != null);
}

test "HTTP POST with real server - httpbin.org" {
    const testing = std.testing;
    const allocator = testing.allocator;

    // Use httpbin.org for testing - it echoes back our request
    const url = "https://httpbin.org/post";
    const test_body = "{\"test\":\"data\"}";

    const headers = [_]HttpRequest.Header{
        .{ .name = "Content-Type", .value = "application/json" },
    };

    var response = try post(allocator, url, &headers, test_body);
    defer response.deinit();

    // Check we got a successful response
    try testing.expect(response.status_code == 200);

    // Check we got a non-empty body
    try testing.expect(response.body.len > 0);

    // httpbin echoes back the data we sent in JSON format
    try testing.expect(std.mem.indexOf(u8, response.body, "test") != null);
    try testing.expect(std.mem.indexOf(u8, response.body, "data") != null);
}

test "HTTP POST error handling - invalid URL" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const invalid_url = "not a valid url";
    const test_body = "{}";
    const headers = [_]HttpRequest.Header{};

    const result = post(allocator, invalid_url, &headers, test_body);
    try testing.expectError(HttpError.InvalidUrl, result);
}

test "HTTP POST error handling - connection refused" {
    const testing = std.testing;
    const allocator = testing.allocator;

    // Use a local port that's likely not listening
    const url = "http://localhost:54321/test";
    const test_body = "{}";
    const headers = [_]HttpRequest.Header{};

    const result = post(allocator, url, &headers, test_body);
    // Should get either ConnectionFailed or ConnectionRefused
    try testing.expect(std.meta.isError(result));
}

test "HTTP response body reading - large payload" {
    const testing = std.testing;
    const allocator = testing.allocator;

    // Use httpbin.org/anything which accepts POST and returns details
    const url = "https://httpbin.org/anything";
    const test_body = "{\"large\":\"payload with some data to make it bigger\"}";
    const headers = [_]HttpRequest.Header{
        .{ .name = "Content-Type", .value = "application/json" },
    };

    var response = try post(allocator, url, &headers, test_body);
    defer response.deinit();

    // httpbin.org/anything returns 200 OK
    try testing.expect(response.status_code == 200);
    try testing.expect(response.body.len > 0);
    // Should contain JSON with our data echoed back
    try testing.expect(std.mem.indexOf(u8, response.body, "large") != null);
}

test "HTTP response headers are captured" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const url = "https://httpbin.org/response-headers?X-Test-Header=test-value";
    const test_body = "{}";
    const headers = [_]HttpRequest.Header{
        .{ .name = "Content-Type", .value = "application/json" },
    };

    var response = try post(allocator, url, &headers, test_body);
    defer response.deinit();

    try testing.expect(response.status_code == 200);
    try testing.expect(response.headers.count() > 0);
}

test "JSON parsing utility" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const json_text = "{\"key\":\"value\",\"number\":42}";
    var parsed = try parseJson(allocator, json_text);
    defer parsed.deinit();

    try testing.expect(parsed.value.object.get("key") != null);
    try testing.expectEqualStrings("value", parsed.value.object.get("key").?.string);
    try testing.expect(parsed.value.object.get("number").?.integer == 42);
}
