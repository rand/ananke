// Claude API client for Ananke
// Provides semantic analysis and conflict resolution using Claude
const std = @import("std");
const http = @import("http");

/// Claude API configuration
pub const ClaudeConfig = struct {
    api_key: []const u8,
    endpoint: []const u8 = "https://api.anthropic.com/v1/messages",
    model: []const u8 = "claude-sonnet-4-5-20250929",
    max_tokens: u32 = 4096,
    temperature: f32 = 0.7,
    timeout_ms: u32 = 30000,
};

/// Claude API client
pub const ClaudeClient = struct {
    allocator: std.mem.Allocator,
    config: ClaudeConfig,
    http_client: http.HttpClient,

    // Rate limiting
    last_request_time: i64 = 0,
    min_request_interval_ms: i64 = 100,

    // Retry configuration
    max_retries: u32 = 3,
    retry_delay_ms: u32 = 1000,

    pub fn init(allocator: std.mem.Allocator, config: ClaudeConfig) !ClaudeClient {
        return .{
            .allocator = allocator,
            .config = config,
            .http_client = http.HttpClient.init(allocator),
        };
    }

    pub fn deinit(self: *ClaudeClient) void {
        self.http_client.deinit();
    }

    /// Analyze code for semantic constraints
    pub fn analyzeCode(
        self: *ClaudeClient,
        source: []const u8,
        language: []const u8,
    ) ![]const Constraint {
        const prompt = try std.fmt.allocPrint(
            self.allocator,
            \\Analyze the following {s} code and extract semantic constraints.
            \\
            \\For each constraint, provide:
            \\1. Type (semantic, type_safety, security, etc.)
            \\2. Severity (error, warning, info, hint)
            \\3. Name (short identifier)
            \\4. Description (clear explanation)
            \\5. Confidence (0.0 to 1.0)
            \\
            \\Code:
            \\```{s}
            \\{s}
            \\```
            \\
            \\Return the constraints as a JSON array with this format:
            \\[
            \\  {{
            \\    "kind": "semantic",
            \\    "severity": "error",
            \\    "name": "constraint_name",
            \\    "description": "Clear description",
            \\    "confidence": 0.9
            \\  }}
            \\]
        ,
            .{ language, language, source },
        );
        defer self.allocator.free(prompt);

        const response = try self.sendMessage(prompt);
        defer self.allocator.free(response);

        return try self.parseConstraintsResponse(response);
    }

    /// Suggest resolution for constraint conflicts
    pub fn suggestResolution(
        self: *ClaudeClient,
        conflicts: []const ConflictDescription,
    ) !ResolutionSuggestion {
        // Build conflict description
        var conflict_desc = std.ArrayList(u8){};
        defer conflict_desc.deinit(self.allocator);

        const writer = conflict_desc.writer(self.allocator);
        try writer.writeAll("The following constraint conflicts need resolution:\n\n");

        for (conflicts, 0..) |conflict, i| {
            try writer.print("Conflict {d}:\n", .{i + 1});
            try writer.print("  Constraint A: {s} ({s})\n", .{ conflict.constraint_a_name, conflict.constraint_a_desc });
            try writer.print("  Constraint B: {s} ({s})\n", .{ conflict.constraint_b_name, conflict.constraint_b_desc });
            try writer.print("  Issue: {s}\n\n", .{conflict.issue});
        }

        try writer.writeAll(
            \\Suggest a resolution strategy. For each conflict, provide one of:
            \\1. "disable_a" or "disable_b" - disable one constraint
            \\2. "merge" - merge constraints into a single unified constraint
            \\3. "modify_a" or "modify_b" - modify a constraint to resolve conflict
            \\
            \\Return JSON in this format:
            \\{
            \\  "resolutions": [
            \\    {
            \\      "conflict_index": 0,
            \\      "action": "disable_a",
            \\      "reasoning": "Explanation of why this is the best resolution"
            \\    }
            \\  ]
            \\}
        );

        const prompt = try conflict_desc.toOwnedSlice(self.allocator);
        defer self.allocator.free(prompt);

        const response = try self.sendMessage(prompt);
        defer self.allocator.free(response);

        return try self.parseResolutionResponse(response);
    }

    /// Analyze test intent to extract constraints
    pub fn analyzeTestIntent(
        self: *ClaudeClient,
        test_source: []const u8,
    ) !TestIntentAnalysis {
        const prompt = try std.fmt.allocPrint(
            self.allocator,
            \\Analyze these test cases to understand what constraints they imply about the code under test.
            \\
            \\Test code:
            \\```
            \\{s}
            \\```
            \\
            \\Extract constraints that the tested code must satisfy. Return JSON:
            \\{{
            \\  "constraints": [
            \\    {{
            \\      "kind": "semantic",
            \\      "severity": "error",
            \\      "name": "constraint_name",
            \\      "description": "What the test verifies",
            \\      "confidence": 0.85
            \\    }}
            \\  ],
            \\  "test_intent": "High-level description of what these tests validate"
            \\}}
        ,
            .{test_source},
        );
        defer self.allocator.free(prompt);

        const response = try self.sendMessage(prompt);
        defer self.allocator.free(response);

        return try self.parseTestIntentResponse(response);
    }

    // Private methods

    /// Send a message to Claude API with retries and rate limiting
    fn sendMessage(self: *ClaudeClient, user_message: []const u8) ![]const u8 {
        // Apply rate limiting
        try self.applyRateLimit();

        var retries: u32 = 0;
        while (retries < self.max_retries) : (retries += 1) {
            const result = self.sendMessageOnce(user_message) catch |err| {
                if (retries == self.max_retries - 1) {
                    return err;
                }
                // Exponential backoff
                const delay = self.retry_delay_ms * (@as(u32, 1) << @as(u5, @intCast(retries)));
                std.Thread.sleep(@as(u64, @intCast(delay)) * std.time.ns_per_ms);
                continue;
            };
            return result;
        }
        return error.MaxRetriesExceeded;
    }

    /// Send a single message to Claude API
    fn sendMessageOnce(self: *ClaudeClient, user_message: []const u8) ![]const u8 {
        // Build request body
        const RequestBody = struct {
            model: []const u8,
            max_tokens: u32,
            temperature: f32,
            messages: []const Message,

            const Message = struct {
                role: []const u8,
                content: []const u8,
            };
        };

        const messages = [_]RequestBody.Message{
            .{
                .role = "user",
                .content = user_message,
            },
        };

        const request_body = RequestBody{
            .model = self.config.model,
            .max_tokens = self.config.max_tokens,
            .temperature = self.config.temperature,
            .messages = &messages,
        };

        const json_body = try http.buildJsonBody(self.allocator, request_body);
        defer self.allocator.free(json_body);

        // Prepare headers
        const api_version = "2023-06-01";
        const headers = [_]http.HttpRequest.Header{
            .{ .name = "x-api-key", .value = self.config.api_key },
            .{ .name = "anthropic-version", .value = api_version },
            .{ .name = "content-type", .value = "application/json" },
        };

        // Send request
        var response = try http.post(
            self.allocator,
            self.config.endpoint,
            &headers,
            json_body,
        );
        defer response.deinit();

        // Check status code
        if (response.status_code != 200) {
            std.log.err("Claude API error: status {d}, body: {s}", .{ response.status_code, response.body });
            return error.ApiError;
        }

        // Parse response
        const parsed = try http.parseJson(self.allocator, response.body);
        defer parsed.deinit();

        const content = parsed.value.object.get("content") orelse return error.InvalidResponse;
        const content_array = content.array;
        if (content_array.items.len == 0) return error.EmptyResponse;

        const first_content = content_array.items[0].object;
        const text = first_content.get("text") orelse return error.InvalidResponse;

        return try self.allocator.dupe(u8, text.string);
    }

    /// Apply rate limiting
    fn applyRateLimit(self: *ClaudeClient) !void {
        const now = std.time.milliTimestamp();
        const elapsed = now - self.last_request_time;

        if (elapsed < self.min_request_interval_ms) {
            const sleep_time = self.min_request_interval_ms - elapsed;
            std.Thread.sleep(@as(u64, @intCast(sleep_time)) * std.time.ns_per_ms);
        }

        self.last_request_time = std.time.milliTimestamp();
    }

    /// Parse constraints from Claude response
    fn parseConstraintsResponse(self: *ClaudeClient, response: []const u8) ![]const Constraint {
        // Extract JSON from response (may have markdown code blocks)
        const json_start = std.mem.indexOf(u8, response, "[") orelse return error.InvalidResponse;
        const json_end = std.mem.lastIndexOf(u8, response, "]") orelse return error.InvalidResponse;
        const json_text = response[json_start..json_end + 1];

        const parsed = try http.parseJson(self.allocator, json_text);
        defer parsed.deinit();

        const array = parsed.value.array;
        var constraints = try std.ArrayList(Constraint).initCapacity(self.allocator, array.items.len);
        errdefer constraints.deinit(self.allocator);

        for (array.items) |item| {
            const obj = item.object;

            const kind_str = obj.get("kind").?.string;
            const kind = parseConstraintKind(kind_str);

            const severity_str = obj.get("severity").?.string;
            const severity = parseSeverity(severity_str);

            const name = try self.allocator.dupe(u8, obj.get("name").?.string);
            const description = try self.allocator.dupe(u8, obj.get("description").?.string);
            const confidence = if (obj.get("confidence")) |c| @as(f32, @floatCast(c.float)) else 0.8;

            try constraints.append(self.allocator, Constraint{
                .kind = kind,
                .severity = severity,
                .name = name,
                .description = description,
                .confidence = confidence,
            });
        }

        return try constraints.toOwnedSlice(self.allocator);
    }

    /// Parse resolution suggestions from Claude response
    fn parseResolutionResponse(self: *ClaudeClient, response: []const u8) !ResolutionSuggestion {
        // Extract JSON from response
        const json_start = std.mem.indexOf(u8, response, "{") orelse return error.InvalidResponse;
        const json_end = std.mem.lastIndexOf(u8, response, "}") orelse return error.InvalidResponse;
        const json_text = response[json_start..json_end + 1];

        const parsed = try http.parseJson(self.allocator, json_text);
        defer parsed.deinit();

        const resolutions_array = parsed.value.object.get("resolutions").?.array;
        var resolutions = try std.ArrayList(ResolutionAction).initCapacity(
            self.allocator,
            resolutions_array.items.len,
        );
        errdefer resolutions.deinit(self.allocator);

        for (resolutions_array.items) |item| {
            const obj = item.object;
            const conflict_index = @as(usize, @intCast(obj.get("conflict_index").?.integer));
            const action_str = obj.get("action").?.string;
            const reasoning = try self.allocator.dupe(u8, obj.get("reasoning").?.string);

            const action = parseResolutionAction(action_str, conflict_index, reasoning);
            try resolutions.append(self.allocator, action);
        }

        return ResolutionSuggestion{
            .actions = try resolutions.toOwnedSlice(self.allocator),
        };
    }

    /// Parse test intent from Claude response
    fn parseTestIntentResponse(self: *ClaudeClient, response: []const u8) !TestIntentAnalysis {
        const json_start = std.mem.indexOf(u8, response, "{") orelse return error.InvalidResponse;
        const json_end = std.mem.lastIndexOf(u8, response, "}") orelse return error.InvalidResponse;
        const json_text = response[json_start..json_end + 1];

        const parsed = try http.parseJson(self.allocator, json_text);
        defer parsed.deinit();

        const constraints = try self.parseConstraintsResponse(response);
        const intent = try self.allocator.dupe(u8, parsed.value.object.get("test_intent").?.string);

        return TestIntentAnalysis{
            .constraints = constraints,
            .intent_description = intent,
        };
    }
};

// Helper types and functions

/// Constraint extracted from Claude analysis
pub const Constraint = struct {
    kind: ConstraintKind,
    severity: Severity,
    name: []const u8,
    description: []const u8,
    confidence: f32 = 0.8,
};

pub const ConstraintKind = enum {
    syntactic,
    type_safety,
    semantic,
    architectural,
    operational,
    security,
};

pub const Severity = enum {
    err,
    warning,
    info,
    hint,
};

/// Conflict description for resolution
pub const ConflictDescription = struct {
    constraint_a_name: []const u8,
    constraint_a_desc: []const u8,
    constraint_b_name: []const u8,
    constraint_b_desc: []const u8,
    issue: []const u8,
};

/// Resolution suggestion from Claude
pub const ResolutionSuggestion = struct {
    actions: []const ResolutionAction,
};

pub const ResolutionAction = union(enum) {
    disable_a: struct {
        conflict_index: usize,
        reasoning: []const u8,
    },
    disable_b: struct {
        conflict_index: usize,
        reasoning: []const u8,
    },
    merge: struct {
        conflict_index: usize,
        reasoning: []const u8,
    },
    modify_a: struct {
        conflict_index: usize,
        reasoning: []const u8,
    },
    modify_b: struct {
        conflict_index: usize,
        reasoning: []const u8,
    },
};

/// Test intent analysis result
pub const TestIntentAnalysis = struct {
    constraints: []const Constraint,
    intent_description: []const u8,
};

/// Parse constraint kind from string
fn parseConstraintKind(s: []const u8) ConstraintKind {
    if (std.mem.eql(u8, s, "syntactic")) return .syntactic;
    if (std.mem.eql(u8, s, "type_safety")) return .type_safety;
    if (std.mem.eql(u8, s, "semantic")) return .semantic;
    if (std.mem.eql(u8, s, "architectural")) return .architectural;
    if (std.mem.eql(u8, s, "operational")) return .operational;
    if (std.mem.eql(u8, s, "security")) return .security;
    return .semantic; // default
}

/// Parse severity from string
fn parseSeverity(s: []const u8) Severity {
    if (std.mem.eql(u8, s, "error")) return .err;
    if (std.mem.eql(u8, s, "warning")) return .warning;
    if (std.mem.eql(u8, s, "info")) return .info;
    if (std.mem.eql(u8, s, "hint")) return .hint;
    return .warning; // default
}

/// Parse resolution action from string
fn parseResolutionAction(s: []const u8, conflict_index: usize, reasoning: []const u8) ResolutionAction {
    if (std.mem.eql(u8, s, "disable_a")) {
        return .{ .disable_a = .{ .conflict_index = conflict_index, .reasoning = reasoning } };
    }
    if (std.mem.eql(u8, s, "disable_b")) {
        return .{ .disable_b = .{ .conflict_index = conflict_index, .reasoning = reasoning } };
    }
    if (std.mem.eql(u8, s, "merge")) {
        return .{ .merge = .{ .conflict_index = conflict_index, .reasoning = reasoning } };
    }
    if (std.mem.eql(u8, s, "modify_a")) {
        return .{ .modify_a = .{ .conflict_index = conflict_index, .reasoning = reasoning } };
    }
    if (std.mem.eql(u8, s, "modify_b")) {
        return .{ .modify_b = .{ .conflict_index = conflict_index, .reasoning = reasoning } };
    }
    // default to disable_a
    return .{ .disable_a = .{ .conflict_index = conflict_index, .reasoning = reasoning } };
}

test "Claude client initialization" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const config = ClaudeConfig{
        .api_key = "test-key",
    };

    var client = try ClaudeClient.init(allocator, config);
    defer client.deinit();

    try testing.expectEqualStrings("test-key", client.config.api_key);
    try testing.expectEqual(@as(u32, 4096), client.config.max_tokens);
}

test "Constraint kind parsing" {
    try std.testing.expectEqual(ConstraintKind.semantic, parseConstraintKind("semantic"));
    try std.testing.expectEqual(ConstraintKind.type_safety, parseConstraintKind("type_safety"));
    try std.testing.expectEqual(ConstraintKind.security, parseConstraintKind("security"));
}

test "Severity parsing" {
    try std.testing.expectEqual(Severity.err, parseSeverity("error"));
    try std.testing.expectEqual(Severity.warning, parseSeverity("warning"));
    try std.testing.expectEqual(Severity.info, parseSeverity("info"));
}
