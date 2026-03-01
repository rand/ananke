// Call-Graph Context Retrieval for Constrained Decoding
//
// Following InlineCoder (January 2026, 49% improvement on RepoExec):
//   - Upstream callers: how the function at the hole is used
//   - Downstream callees: what the function at the hole depends on
//
// This module defines the data types and serialization. It does NOT query
// Homer directly — that's the CLI/MCP layer's job. Data flows in, JSON
// flows out to RichContext.
//
// Homer call graph → CallGraphContext → JSON → RichContext.call_graph_json

const std = @import("std");

/// A caller of the function containing the generation hole.
/// Captures how the function is invoked — usage patterns, argument types,
/// and result handling.
pub const Caller = struct {
    /// Name of the calling function
    name: []const u8,
    /// File where the caller is defined
    file: ?[]const u8 = null,
    /// Line number of the call site
    call_line: ?u32 = null,
    /// Arguments passed at the call site (e.g., "user.id, options")
    arguments: ?[]const u8 = null,
    /// How the return value is used (e.g., "const result = ", "if (")
    result_usage: ?[]const u8 = null,
};

/// A callee invoked by the function containing the generation hole.
/// Captures what the function depends on — signature, module, return type.
pub const Callee = struct {
    /// Name of the called function
    name: []const u8,
    /// File where the callee is defined
    file: ?[]const u8 = null,
    /// Parameters of the callee (for type context)
    params: ?[]const u8 = null,
    /// Return type of the callee
    return_type: ?[]const u8 = null,
    /// Whether the callee is async
    is_async: bool = false,
};

/// Complete call graph context around a generation hole.
pub const CallGraphContext = struct {
    /// Functions that call the function containing the hole
    callers: []const Caller = &.{},
    /// Functions called by the function containing the hole
    callees: []const Callee = &.{},
    /// Name of the function containing the hole
    target_function: ?[]const u8 = null,
    /// File containing the hole
    target_file: ?[]const u8 = null,
    /// Call graph depth retrieved (1 = direct callers/callees only)
    depth: u32 = 1,

    /// Serialize callers to JSON array for RichContext.
    pub fn serializeCallersJson(self: *const CallGraphContext, allocator: std.mem.Allocator) ![]u8 {
        var buf = std.ArrayList(u8){};
        errdefer buf.deinit(allocator);
        const writer = buf.writer(allocator);

        try writer.writeAll("[");
        for (self.callers, 0..) |caller, i| {
            if (i > 0) try writer.writeAll(",");
            try writer.writeAll("{");
            try writer.print("\"name\":\"{s}\"", .{caller.name});
            if (caller.file) |f| {
                try writer.print(",\"file\":\"{s}\"", .{f});
            }
            if (caller.call_line) |line| {
                try writer.print(",\"call_line\":{d}", .{line});
            }
            if (caller.arguments) |args| {
                try writer.print(",\"arguments\":\"{s}\"", .{args});
            }
            if (caller.result_usage) |usage| {
                try writer.print(",\"result_usage\":\"{s}\"", .{usage});
            }
            try writer.writeAll("}");
        }
        try writer.writeAll("]");

        return try buf.toOwnedSlice(allocator);
    }

    /// Serialize callees to JSON array for RichContext.
    pub fn serializeCalleesJson(self: *const CallGraphContext, allocator: std.mem.Allocator) ![]u8 {
        var buf = std.ArrayList(u8){};
        errdefer buf.deinit(allocator);
        const writer = buf.writer(allocator);

        try writer.writeAll("[");
        for (self.callees, 0..) |callee, i| {
            if (i > 0) try writer.writeAll(",");
            try writer.writeAll("{");
            try writer.print("\"name\":\"{s}\"", .{callee.name});
            if (callee.file) |f| {
                try writer.print(",\"file\":\"{s}\"", .{f});
            }
            if (callee.params) |p| {
                try writer.print(",\"params\":\"{s}\"", .{p});
            }
            if (callee.return_type) |rt| {
                try writer.print(",\"return_type\":\"{s}\"", .{rt});
            }
            if (callee.is_async) {
                try writer.writeAll(",\"is_async\":true");
            }
            try writer.writeAll("}");
        }
        try writer.writeAll("]");

        return try buf.toOwnedSlice(allocator);
    }

    /// Serialize full call graph context to JSON for RichContext.call_graph_json.
    pub fn serializeContextJson(self: *const CallGraphContext, allocator: std.mem.Allocator) ![]u8 {
        var buf = std.ArrayList(u8){};
        errdefer buf.deinit(allocator);
        const writer = buf.writer(allocator);

        try writer.writeAll("{");

        if (self.target_function) |tf| {
            try writer.print("\"target_function\":\"{s}\"", .{tf});
        }
        if (self.target_file) |f| {
            const needs_comma = self.target_function != null;
            if (needs_comma) try writer.writeAll(",");
            try writer.print("\"target_file\":\"{s}\"", .{f});
        }

        const has_prior_fields = self.target_function != null or self.target_file != null;
        if (has_prior_fields) try writer.writeAll(",");
        try writer.print("\"depth\":{d}", .{self.depth});

        // Callers
        try writer.writeAll(",\"callers\":[");
        for (self.callers, 0..) |caller, i| {
            if (i > 0) try writer.writeAll(",");
            try writer.writeAll("{");
            try writer.print("\"name\":\"{s}\"", .{caller.name});
            if (caller.file) |f| {
                try writer.print(",\"file\":\"{s}\"", .{f});
            }
            if (caller.call_line) |line| {
                try writer.print(",\"call_line\":{d}", .{line});
            }
            if (caller.arguments) |args| {
                try writer.print(",\"arguments\":\"{s}\"", .{args});
            }
            if (caller.result_usage) |usage| {
                try writer.print(",\"result_usage\":\"{s}\"", .{usage});
            }
            try writer.writeAll("}");
        }
        try writer.writeAll("]");

        // Callees
        try writer.writeAll(",\"callees\":[");
        for (self.callees, 0..) |callee, i| {
            if (i > 0) try writer.writeAll(",");
            try writer.writeAll("{");
            try writer.print("\"name\":\"{s}\"", .{callee.name});
            if (callee.file) |f| {
                try writer.print(",\"file\":\"{s}\"", .{f});
            }
            if (callee.params) |p| {
                try writer.print(",\"params\":\"{s}\"", .{p});
            }
            if (callee.return_type) |rt| {
                try writer.print(",\"return_type\":\"{s}\"", .{rt});
            }
            if (callee.is_async) {
                try writer.writeAll(",\"is_async\":true");
            }
            try writer.writeAll("}");
        }
        try writer.writeAll("]");

        try writer.writeAll("}");

        return try buf.toOwnedSlice(allocator);
    }

    /// Count total edges (callers + callees) in the context.
    pub fn edgeCount(self: *const CallGraphContext) usize {
        return self.callers.len + self.callees.len;
    }

    /// Check if there's enough call graph data to meaningfully influence generation.
    /// InlineCoder showed upstream callers have the highest impact (49% improvement).
    pub fn hasUpstreamContext(self: *const CallGraphContext) bool {
        return self.callers.len > 0;
    }

    /// Check if downstream dependencies provide type context.
    pub fn hasDownstreamTypeContext(self: *const CallGraphContext) bool {
        for (self.callees) |callee| {
            if (callee.return_type != null or callee.params != null) return true;
        }
        return false;
    }
};

// ---------- Tests ----------

test "empty call graph context serialization" {
    const ctx = CallGraphContext{};
    const json = try ctx.serializeContextJson(std.testing.allocator);
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"depth\":1") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"callers\":[]") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"callees\":[]") != null);
}

test "caller serialization" {
    const callers = [_]Caller{
        .{
            .name = "handle_request",
            .file = "src/api/handler.py",
            .call_line = 42,
            .arguments = "user_id, options",
            .result_usage = "const result = ",
        },
        .{
            .name = "test_validate",
            .file = "tests/test_auth.py",
        },
    };

    const ctx = CallGraphContext{
        .callers = &callers,
        .target_function = "validate_user",
    };

    const json = try ctx.serializeCallersJson(std.testing.allocator);
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"name\":\"handle_request\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"call_line\":42") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"name\":\"test_validate\"") != null);
}

test "callee serialization" {
    const callees = [_]Callee{
        .{
            .name = "db_query",
            .file = "src/db/queries.py",
            .params = "query: str, params: list",
            .return_type = "Optional[Row]",
            .is_async = true,
        },
    };

    const ctx = CallGraphContext{
        .callees = &callees,
    };

    const json = try ctx.serializeCalleesJson(std.testing.allocator);
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"name\":\"db_query\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"return_type\":\"Optional[Row]\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"is_async\":true") != null);
}

test "full context serialization" {
    const callers = [_]Caller{
        .{ .name = "main", .file = "src/main.zig", .call_line = 10 },
    };
    const callees = [_]Callee{
        .{ .name = "log", .return_type = "void" },
        .{ .name = "allocate", .params = "size: usize", .return_type = "?[*]u8" },
    };

    const ctx = CallGraphContext{
        .callers = &callers,
        .callees = &callees,
        .target_function = "process",
        .target_file = "src/engine.zig",
        .depth = 1,
    };

    const json = try ctx.serializeContextJson(std.testing.allocator);
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"target_function\":\"process\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"target_file\":\"src/engine.zig\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"name\":\"main\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"name\":\"log\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"name\":\"allocate\"") != null);
}

test "edge count" {
    const callers = [_]Caller{
        .{ .name = "a" },
        .{ .name = "b" },
    };
    const callees = [_]Callee{
        .{ .name = "c" },
    };

    const ctx = CallGraphContext{
        .callers = &callers,
        .callees = &callees,
    };

    try std.testing.expectEqual(@as(usize, 3), ctx.edgeCount());
}

test "upstream context detection" {
    const empty = CallGraphContext{};
    try std.testing.expect(!empty.hasUpstreamContext());

    const callers = [_]Caller{.{ .name = "caller" }};
    const with_callers = CallGraphContext{ .callers = &callers };
    try std.testing.expect(with_callers.hasUpstreamContext());
}

test "downstream type context detection" {
    const no_types = [_]Callee{.{ .name = "log" }};
    const ctx1 = CallGraphContext{ .callees = &no_types };
    try std.testing.expect(!ctx1.hasDownstreamTypeContext());

    const with_types = [_]Callee{.{ .name = "query", .return_type = "Row" }};
    const ctx2 = CallGraphContext{ .callees = &with_types };
    try std.testing.expect(ctx2.hasDownstreamTypeContext());
}
