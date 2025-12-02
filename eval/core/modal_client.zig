const std = @import("std");
const http = @import("http");
const task_spec = @import("task_spec");
const Allocator = std.mem.Allocator;

/// Modal inference service client for evaluation framework
pub const ModalClient = struct {
    allocator: Allocator,
    base_url: []const u8,
    constrained_path: []const u8,
    unconstrained_path: []const u8,
    timeout_ms: u32,

    /// Initialize with base URL (e.g., "https://user--app-name-inferenceservice-fastapi-app.modal.run")
    /// Paths default to "/generate/constrained" and "/generate/unconstrained"
    pub fn init(allocator: Allocator, base_url: []const u8) ModalClient {
        return .{
            .allocator = allocator,
            .base_url = base_url,
            .constrained_path = "/generate/constrained",
            .unconstrained_path = "/generate/unconstrained",
            .timeout_ms = 300000, // 5 minutes for code generation
        };
    }

    /// Legacy init with separate URLs (for backwards compatibility)
    pub fn initWithSeparateUrls(allocator: Allocator, constrained_url: []const u8, unconstrained_url: []const u8) ModalClient {
        _ = unconstrained_url; // Base URL is derived from constrained URL
        return .{
            .allocator = allocator,
            .base_url = constrained_url, // Assume this is the full URL
            .constrained_path = "", // Empty path since URL is complete
            .unconstrained_path = "", // Will be handled specially
            .timeout_ms = 300000,
        };
    }

    fn buildUrl(self: *ModalClient, path: []const u8) ![]const u8 {
        if (path.len == 0) {
            return try self.allocator.dupe(u8, self.base_url);
        }
        const url = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ self.base_url, path });
        return url;
    }

    pub fn deinit(self: *ModalClient) void {
        _ = self;
    }

    /// Generate code with constraints (Ananke mode)
    /// Calls Modal's generate_constrained_endpoint
    /// Request format: {prompt, constraints, model?}
    /// Response format: {code, metadata: {tokens_used, generation_time_ms, model}}
    pub fn generateConstrained(
        self: *ModalClient,
        prompt: []const u8,
        constraints: ?[]const u8,
        max_tokens: u32,
    ) !task_spec.GenerationResult {
        _ = max_tokens; // Not used by Modal API
        var timer = try std.time.Timer.start();

        // Build request body to match Modal API
        var body_buf = try std.ArrayList(u8).initCapacity(self.allocator, 2048);
        defer body_buf.deinit(self.allocator);

        const writer = body_buf.writer(self.allocator);
        try writer.writeAll("{");

        // Add prompt (escaped)
        try writer.writeAll("\"prompt\":");
        try writeJsonString(writer, prompt);
        try writer.writeAll(",");

        // Add constraints object
        try writer.writeAll("\"constraints\":");
        if (constraints) |c| {
            try writer.writeAll(c); // Already JSON
        } else {
            try writer.writeAll("{}");
        }

        try writer.writeAll("}");

        const json_body = try body_buf.toOwnedSlice(self.allocator);
        defer self.allocator.free(json_body);

        // Send request to constrained endpoint
        const headers = [_]http.HttpRequest.Header{
            .{ .name = "Content-Type", .value = "application/json" },
        };

        const url = try self.buildUrl(self.constrained_path);
        defer self.allocator.free(url);

        var response = try http.post(self.allocator, url, &headers, json_body);
        defer response.deinit();

        if (response.status_code != 200) {
            return error.GenerationFailed;
        }

        // Parse response: {code, metadata}
        const parsed = try std.json.parseFromSlice(
            std.json.Value,
            self.allocator,
            response.body,
            .{},
        );
        defer parsed.deinit();

        const result_obj = parsed.value.object;

        // Extract code from response
        const generated_code = result_obj.get("code").?.string;
        const code = try self.allocator.dupe(u8, generated_code);
        errdefer self.allocator.free(code);

        const duration_ms = timer.read() / std.time.ns_per_ms;

        return task_spec.GenerationResult{
            .task_id = try self.allocator.dupe(u8, ""),
            .mode = .constrained,
            .code = code,
            .duration_ms = @intCast(duration_ms),
            .success = true,
            .error_msg = null,
        };
    }

    /// Generate code without constraints (baseline mode)
    /// Calls Modal's generate_unconstrained_endpoint
    /// Request format: {prompt, few_shot_examples, model?}
    /// Response format: {code, metadata: {tokens_used, generation_time_ms, model}}
    pub fn generateUnconstrained(
        self: *ModalClient,
        prompt: []const u8,
        few_shot_examples: []const u8, // JSON array of {prompt, code} objects
        max_tokens: u32,
    ) !task_spec.GenerationResult {
        _ = max_tokens; // Not used by Modal API
        var timer = try std.time.Timer.start();

        // Build request body to match Modal API
        var body_buf = try std.ArrayList(u8).initCapacity(self.allocator, 2048);
        defer body_buf.deinit(self.allocator);

        const writer = body_buf.writer(self.allocator);
        try writer.writeAll("{");

        // Add prompt (escaped)
        try writer.writeAll("\"prompt\":");
        try writeJsonString(writer, prompt);
        try writer.writeAll(",");

        // Add few_shot_examples array
        try writer.writeAll("\"few_shot_examples\":");
        try writer.writeAll(few_shot_examples); // Already JSON

        try writer.writeAll("}");

        const json_body = try body_buf.toOwnedSlice(self.allocator);
        defer self.allocator.free(json_body);

        // Send request to unconstrained endpoint
        const headers = [_]http.HttpRequest.Header{
            .{ .name = "Content-Type", .value = "application/json" },
        };

        const url = try self.buildUrl(self.unconstrained_path);
        defer self.allocator.free(url);

        var response = try http.post(self.allocator, url, &headers, json_body);
        defer response.deinit();

        if (response.status_code != 200) {
            return error.GenerationFailed;
        }

        // Parse response: {code, metadata}
        const parsed = try std.json.parseFromSlice(
            std.json.Value,
            self.allocator,
            response.body,
            .{},
        );
        defer parsed.deinit();

        const result_obj = parsed.value.object;

        // Extract code from response
        const generated_code = result_obj.get("code").?.string;
        const code = try self.allocator.dupe(u8, generated_code);
        errdefer self.allocator.free(code);

        const duration_ms = timer.read() / std.time.ns_per_ms;

        return task_spec.GenerationResult{
            .task_id = try self.allocator.dupe(u8, ""),
            .mode = .unconstrained,
            .code = code,
            .duration_ms = @intCast(duration_ms),
            .success = true,
            .error_msg = null,
        };
    }

    /// Health check (currently not implemented for Modal endpoints)
    pub fn healthCheck(self: *ModalClient) !bool {
        _ = self;
        // Modal web endpoints don't have a standard health check endpoint
        // Return true for now - actual health is checked when making requests
        return true;
    }

    /// Write a JSON-escaped string
    fn writeJsonString(writer: anytype, s: []const u8) !void {
        try writer.writeByte('"');
        for (s) |c| {
            switch (c) {
                '"' => try writer.writeAll("\\\""),
                '\\' => try writer.writeAll("\\\\"),
                '\n' => try writer.writeAll("\\n"),
                '\r' => try writer.writeAll("\\r"),
                '\t' => try writer.writeAll("\\t"),
                else => try writer.writeByte(c),
            }
        }
        try writer.writeByte('"');
    }
};
