// Output formatting utilities for Ananke CLI
const std = @import("std");
const ananke = @import("ananke");
const constraint = ananke.types.constraint;

pub const OutputFormat = enum {
    json,
    yaml,
    pretty,
    ariadne,

    pub fn fromString(s: []const u8) ?OutputFormat {
        if (std.mem.eql(u8, s, "json")) return .json;
        if (std.mem.eql(u8, s, "yaml")) return .yaml;
        if (std.mem.eql(u8, s, "pretty")) return .pretty;
        if (std.mem.eql(u8, s, "ariadne")) return .ariadne;
        return null;
    }
};

pub const Color = enum {
    reset,
    red,
    green,
    yellow,
    blue,
    magenta,
    cyan,
    gray,
    bold,

    pub fn code(self: Color) []const u8 {
        return switch (self) {
            .reset => "\x1b[0m",
            .red => "\x1b[31m",
            .green => "\x1b[32m",
            .yellow => "\x1b[33m",
            .blue => "\x1b[34m",
            .magenta => "\x1b[35m",
            .cyan => "\x1b[36m",
            .gray => "\x1b[90m",
            .bold => "\x1b[1m",
        };
    }
};

pub var use_colors: bool = true;

pub fn setColorEnabled(enabled: bool) void {
    use_colors = enabled;
}

pub fn colorize(comptime color: Color, text: []const u8, allocator: std.mem.Allocator) ![]u8 {
    if (!use_colors) return try allocator.dupe(u8, text);
    return std.fmt.allocPrint(allocator, "{s}{s}{s}", .{ color.code(), text, Color.reset.code() });
}

/// Format constraints as JSON
pub fn formatJson(
    allocator: std.mem.Allocator,
    constraint_set: constraint.ConstraintSet,
) ![]u8 {
    var list = std.ArrayList(u8){};
    errdefer list.deinit(allocator);
    const writer = list.writer(allocator);

    try writer.writeAll("{\n");
    try writer.print("  \"name\": \"{s}\",\n", .{constraint_set.name});
    try writer.writeAll("  \"constraints\": [\n");

    for (constraint_set.constraints.items, 0..) |c, i| {
        try writer.writeAll("    {\n");
        try writer.print("      \"id\": {d},\n", .{c.id});
        try writer.print("      \"kind\": \"{s}\",\n", .{@tagName(c.kind)});
        try writer.print("      \"severity\": \"{s}\",\n", .{@tagName(c.severity)});
        try writer.print("      \"name\": \"{s}\",\n", .{escapeJson(c.name)});
        try writer.print("      \"description\": \"{s}\",\n", .{escapeJson(c.description)});
        try writer.print("      \"source\": \"{s}\",\n", .{@tagName(c.source)});
        try writer.print("      \"priority\": \"{s}\",\n", .{@tagName(c.priority)});
        try writer.print("      \"confidence\": {d:.2},\n", .{c.confidence});
        try writer.print("      \"frequency\": {d}\n", .{c.frequency});
        try writer.writeAll("    }");
        // Safe check: use addition instead of subtraction to avoid underflow
        if (i + 1 < constraint_set.constraints.items.len) {
            try writer.writeAll(",");
        }
        try writer.writeAll("\n");
    }

    try writer.writeAll("  ]\n");
    try writer.writeAll("}\n");

    return list.toOwnedSlice(allocator);
}

/// Format constraints as YAML
pub fn formatYaml(
    allocator: std.mem.Allocator,
    constraint_set: constraint.ConstraintSet,
) ![]u8 {
    var list = std.ArrayList(u8){};
    errdefer list.deinit(allocator);
    const writer = list.writer(allocator);

    try writer.print("name: {s}\n", .{constraint_set.name});
    try writer.writeAll("constraints:\n");

    for (constraint_set.constraints.items) |c| {
        try writer.print("  - id: {d}\n", .{c.id});
        try writer.print("    kind: {s}\n", .{@tagName(c.kind)});
        try writer.print("    severity: {s}\n", .{@tagName(c.severity)});
        try writer.print("    name: {s}\n", .{c.name});
        try writer.print("    description: {s}\n", .{c.description});
        try writer.print("    source: {s}\n", .{@tagName(c.source)});
        try writer.print("    priority: {s}\n", .{@tagName(c.priority)});
        try writer.print("    confidence: {d:.2}\n", .{c.confidence});
        try writer.print("    frequency: {d}\n", .{c.frequency});
    }

    return list.toOwnedSlice(allocator);
}

/// Format constraints in human-readable pretty format
pub fn formatPretty(
    allocator: std.mem.Allocator,
    constraint_set: constraint.ConstraintSet,
) ![]u8 {
    var list = std.ArrayList(u8){};
    errdefer list.deinit(allocator);
    const writer = list.writer(allocator);

    try writer.print("Constraint Set: {s}\n", .{constraint_set.name});
    try writer.print("Total Constraints: {d}\n\n", .{constraint_set.constraints.items.len});

    for (constraint_set.constraints.items, 0..) |c, i| {
        const severity_symbol = switch (c.severity) {
            .err => "✗",
            .warning => "⚠",
            .info => "ℹ",
            .hint => "💡",
        };

        const severity_color = switch (c.severity) {
            .err => Color.red,
            .warning => Color.yellow,
            .info => Color.blue,
            .hint => Color.cyan,
        };

        if (use_colors) {
            try writer.print("{s}{s} [{s}]{s} {s}\n", .{
                severity_color.code(),
                severity_symbol,
                @tagName(c.kind),
                Color.reset.code(),
                c.name,
            });
        } else {
            try writer.print("{s} [{s}] {s}\n", .{ severity_symbol, @tagName(c.kind), c.name });
        }

        try writer.print("  {s}\n", .{c.description});
        try writer.print("  Source: {s} | Priority: {s} | Confidence: {d:.0}%\n", .{
            @tagName(c.source),
            @tagName(c.priority),
            c.confidence * 100,
        });

        // Safe check: use addition instead of subtraction to avoid underflow
        if (i + 1 < constraint_set.constraints.items.len) {
            try writer.writeAll("\n");
        }
    }

    return list.toOwnedSlice(allocator);
}

/// Format constraints in Ariadne DSL format
pub fn formatAriadne(
    allocator: std.mem.Allocator,
    constraint_set: constraint.ConstraintSet,
) ![]u8 {
    var list = std.ArrayList(u8){};
    errdefer list.deinit(allocator);
    const writer = list.writer(allocator);

    try writer.print("constraint_set \"{s}\" {{\n", .{constraint_set.name});

    for (constraint_set.constraints.items) |c| {
        const severity_str = switch (c.severity) {
            .err => "error",
            .warning => "warning",
            .info => "info",
            .hint => "hint",
        };

        try writer.print("  {s} {s} \"{s}\" {{\n", .{
            @tagName(c.kind),
            severity_str,
            c.name,
        });
        try writer.print("    description: \"{s}\"\n", .{c.description});
        try writer.print("    confidence: {d:.2}\n", .{c.confidence});
        try writer.print("    priority: {s}\n", .{@tagName(c.priority)});
        try writer.writeAll("  }\n\n");
    }

    try writer.writeAll("}\n");

    return list.toOwnedSlice(allocator);
}

/// Format ConstraintIR as JSON
pub fn formatIRJson(
    allocator: std.mem.Allocator,
    ir: constraint.ConstraintIR,
) ![]u8 {
    var list = std.ArrayList(u8){};
    errdefer list.deinit(allocator);
    const writer = list.writer(allocator);

    try writer.writeAll("{\n");
    try writer.print("  \"priority\": {d},\n", .{ir.priority});

    // JSON Schema
    if (ir.json_schema) |schema| {
        try writer.writeAll("  \"json_schema\": {\n");
        try writer.print("    \"type\": \"{s}\"\n", .{schema.type});
        try writer.writeAll("  },\n");
    } else {
        try writer.writeAll("  \"json_schema\": null,\n");
    }

    // Grammar
    if (ir.grammar) |grammar| {
        try writer.writeAll("  \"grammar\": {\n");
        try writer.print("    \"start_symbol\": \"{s}\",\n", .{grammar.start_symbol});
        try writer.writeAll("    \"rules\": [\n");
        for (grammar.rules, 0..) |rule, i| {
            try writer.print("      {{\"lhs\": \"{s}\", \"rhs\": [", .{rule.lhs});
            for (rule.rhs, 0..) |rhs_item, j| {
                try writer.print("\"{s}\"", .{rhs_item});
                if (j < rule.rhs.len - 1) try writer.writeAll(", ");
            }
            try writer.writeAll("]}");
            if (i < grammar.rules.len - 1) try writer.writeAll(",");
            try writer.writeAll("\n");
        }
        try writer.writeAll("    ]\n");
        try writer.writeAll("  },\n");
    } else {
        try writer.writeAll("  \"grammar\": null,\n");
    }

    // Regex patterns
    try writer.writeAll("  \"regex_patterns\": [\n");
    for (ir.regex_patterns, 0..) |regex, i| {
        try writer.print("    {{\"pattern\": \"{s}\"}}", .{regex.pattern});
        if (i < ir.regex_patterns.len - 1) {
            try writer.writeAll(",");
        }
        try writer.writeAll("\n");
    }
    try writer.writeAll("  ],\n");

    // Token masks
    if (ir.token_masks) |_| {
        try writer.writeAll("  \"token_masks\": {}\n");
    } else {
        try writer.writeAll("  \"token_masks\": null\n");
    }

    try writer.writeAll("}\n");

    return list.toOwnedSlice(allocator);
}

/// Simple progress spinner for long operations
pub const Spinner = struct {
    frames: []const []const u8 = &.{ "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },
    current: usize = 0,
    message: []const u8,

    pub fn init(message: []const u8) Spinner {
        return .{ .message = message };
    }

    pub fn tick(self: *Spinner) void {
        if (!use_colors) return;
        std.debug.print("\r{s} {s}", .{ self.frames[self.current], self.message });
        self.current = (self.current + 1) % self.frames.len;
    }

    pub fn finish(self: *Spinner, success_message: []const u8) void {
        if (use_colors) {
            std.debug.print("\r{s}{s} {s}{s}\n", .{
                Color.green.code(),
                "✓",
                success_message,
                Color.reset.code(),
            });
        } else {
            std.debug.print("{s}\n", .{success_message});
        }
        _ = self;
    }
};

/// Escape JSON special characters
fn escapeJson(s: []const u8) []const u8 {
    // TODO: Implement proper JSON escaping for quotes, backslashes, etc.
    // For now, return as-is
    return s;
}

/// Print a table of constraints
pub fn printTable(
    constraint_set: constraint.ConstraintSet,
) !void {

    const stdout = std.io.getStdOut().writer();

    // Header
    try stdout.writeAll("┌────────────────┬──────────┬────────────────────────────────────────┐\n");
    try stdout.writeAll("│ Kind           │ Severity │ Name                                   │\n");
    try stdout.writeAll("├────────────────┼──────────┼────────────────────────────────────────┤\n");

    // Rows
    for (constraint_set.constraints.items) |c| {
        try stdout.print("│ {s: <14} │ {s: <8} │ {s: <38} │\n", .{
            @tagName(c.kind),
            @tagName(c.severity),
            if (c.name.len > 38) c.name[0..38] else c.name,
        });
    }

    // Footer
    try stdout.writeAll("└────────────────┴──────────┴────────────────────────────────────────┘\n");
}
