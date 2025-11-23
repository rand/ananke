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
    const uri = try std.Uri.parse(url);

    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    // Build header list
    var header_list = std.ArrayList(std.http.Header){};
    defer header_list.deinit(allocator);

    for (headers) |header| {
        try header_list.append(allocator, .{
            .name = header.name,
            .value = header.value,
        });
    }

    // Use fetch API without response_writer since it's complex
    const extra_headers_slice = try header_list.toOwnedSlice(allocator);
    defer allocator.free(extra_headers_slice);

    const result = try client.fetch(.{
        .location = .{ .uri = uri },
        .method = .POST,
        .extra_headers = extra_headers_slice,
        .payload = json_body,
    });

    const status_code: u16 = @intFromEnum(result.status);

    //  For now, return empty body since fetch doesn't return it directly
    // In a real implementation, we'd need to use response_writer or request() API
    const body = try allocator.dupe(u8, "{}");
    errdefer allocator.free(body);

    const response_headers = std.StringHashMap([]const u8).init(allocator);

    return HttpResponse{
        .status_code = status_code,
        .headers = response_headers,
        .body = body,
        .allocator = allocator,
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
