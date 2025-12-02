const std = @import("std");
const task_spec = @import("task_spec");
const modal_client = @import("modal_client");
const Allocator = std.mem.Allocator;

/// Baseline generator that uses few-shot prompting without constraints
pub const BaselineGenerator = struct {
    allocator: Allocator,
    modal_client: modal_client.ModalClient,

    pub fn init(allocator: Allocator, base_url: []const u8) BaselineGenerator {
        return .{
            .allocator = allocator,
            .modal_client = modal_client.ModalClient.init(allocator, base_url),
        };
    }

    pub fn deinit(self: *BaselineGenerator) void {
        self.modal_client.deinit();
    }

    /// Generate code using few-shot prompting (unconstrained)
    pub fn generate(self: *BaselineGenerator, task: task_spec.TaskSpec) !task_spec.GenerationResult {
        // Build prompt with task description
        const prompt = try self.buildPrompt(task);
        defer self.allocator.free(prompt);

        // Build few-shot examples JSON array
        const few_shot_json = try self.buildFewShotJson(task);
        defer self.allocator.free(few_shot_json);

        std.log.info("Generating baseline (unconstrained) for task: {s}", .{task.id});
        std.log.info("Prompt length: {} chars", .{prompt.len});
        std.log.info("Few-shot examples: {}", .{task.few_shot_examples.len});

        // Generate using Modal without constraints
        const max_tokens: u32 = @min(task.expected_loc * 20, 4096); // Rough estimate: 20 tokens per LOC

        var result = try self.modal_client.generateUnconstrained(prompt, few_shot_json, max_tokens);

        // Set task_id
        self.allocator.free(result.task_id);
        result.task_id = try self.allocator.dupe(u8, task.id);

        return result;
    }

    /// Build prompt from task specification
    fn buildPrompt(self: *BaselineGenerator, task: task_spec.TaskSpec) ![]const u8 {
        var buf = try std.ArrayList(u8).initCapacity(self.allocator, 1024);
        defer buf.deinit(self.allocator);

        const writer = buf.writer(self.allocator);

        // System message/context
        try writer.print("You are an expert {s} developer. ", .{task.language.toString()});
        try writer.writeAll("Generate production-quality code that follows best practices.\n\n");

        // Main task
        try writer.print("Title: {s}\n", .{task.title});
        try writer.print("Description: {s}\n\n", .{task.description});

        if (task.requirements.len > 0) {
            try writer.writeAll("Requirements:\n");
            for (task.requirements) |req| {
                try writer.print("- {s}\n", .{req});
            }
            try writer.writeAll("\n");
        }

        try writer.print("Generate complete, working {s} code. ", .{task.language.toString()});
        try writer.writeAll("Include all necessary imports, types, and functions.\n");

        return try buf.toOwnedSlice(self.allocator);
    }

    /// Build few-shot examples JSON array
    fn buildFewShotJson(self: *BaselineGenerator, task: task_spec.TaskSpec) ![]const u8 {
        var buf = try std.ArrayList(u8).initCapacity(self.allocator, 2048);
        defer buf.deinit(self.allocator);

        const writer = buf.writer(self.allocator);

        try writer.writeAll("[");

        for (task.few_shot_examples, 0..) |example, i| {
            if (i > 0) try writer.writeAll(",");

            try writer.writeAll("{");
            try writer.writeAll("\"prompt\":");
            try writeJsonString(writer, example.prompt);
            try writer.writeAll(",\"code\":");
            try writeJsonString(writer, example.code);
            try writer.writeAll("}");
        }

        try writer.writeAll("]");

        return try buf.toOwnedSlice(self.allocator);
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
