// JSON Schema Builder for Braid
// Converts type constraints into llguidance-compatible JSON Schema
const std = @import("std");
const root = @import("ananke");
const Constraint = root.types.constraint.Constraint;

/// Property information extracted from type constraints
pub const PropertyInfo = struct {
    name: []const u8,
    type_schema: []const u8,
    optional: bool,
};

/// Build JSON Schema string from type constraints for llguidance compatibility
pub fn buildJSONSchemaString(
    allocator: std.mem.Allocator,
    constraints: []const Constraint,
) ![]const u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    var schema = std.ArrayList(u8){};
    const writer = schema.writer(arena_allocator);

    try writer.writeAll("{");

    // Parse constraints and build schema
    var properties = std.ArrayList(u8){};
    const prop_writer = properties.writer(arena_allocator);
    var required = std.ArrayList([]const u8){};
    var first_prop = true;

    for (constraints) |constraint| {
        if (constraint.kind != .type_safety) continue;

        // Parse the constraint description to extract type information
        const type_info = try parseTypeConstraint(arena_allocator, constraint.description);
        if (type_info) |info| {
            // Don't free - arena allocator will clean up everything

            if (!first_prop) {
                try prop_writer.writeAll(",");
            }
            first_prop = false;

            try prop_writer.print("\"{s}\":{s}", .{ info.name, info.type_schema });

            if (!info.optional) {
                try required.append(arena_allocator, info.name);
            }
        }
    }

    // Write type field
    try writer.writeAll("\"type\":\"object\"");

    // Write properties if any
    if (properties.items.len > 0) {
        try writer.writeAll(",\"properties\":{");
        try writer.writeAll(properties.items);
        try writer.writeAll("}");
    }

    // Write required fields if any
    if (required.items.len > 0) {
        try writer.writeAll(",\"required\":[");
        for (required.items, 0..) |req, i| {
            if (i > 0) try writer.writeAll(",");
            try writer.print("\"{s}\"", .{req});
        }
        try writer.writeAll("]");
    }

    try writer.writeAll("}");

    return try allocator.dupe(u8, schema.items);
}

/// Parse a type constraint description and extract property information
fn parseTypeConstraint(
    allocator: std.mem.Allocator,
    description: []const u8,
) !?PropertyInfo {
    // Handle different constraint description formats:
    // 1. "interface User { name: string; age: number }"
    // 2. "{ name: string }" - object literal
    // 3. "Array<string>" - array type
    // 4. "string | number" - union type
    // 5. Simple types: "string", "number", "boolean", "null"

    const trimmed = std.mem.trim(u8, description, " \t\n\r");

    // Check for "propertyName: type" pattern first (covers most cases)
    // This handles "tags: Array<string>" correctly
    if (std.mem.indexOf(u8, trimmed, ":")) |_| {
        // Check if this is a property definition (not inside an interface/object)
        if (!std.mem.startsWith(u8, trimmed, "{") and !std.mem.startsWith(u8, trimmed, "interface ")) {
            return try parseSimpleType(allocator, trimmed);
        }
    }

    // Check for interface pattern
    if (std.mem.indexOf(u8, trimmed, "interface ")) |interface_idx| {
        return try parseInterfaceType(allocator, trimmed[interface_idx..]);
    }

    // Check for object literal pattern
    if (std.mem.startsWith(u8, trimmed, "{") and std.mem.endsWith(u8, trimmed, "}")) {
        return try parseObjectType(allocator, trimmed);
    }

    // Check for array pattern (bare arrays without property name)
    if (std.mem.indexOf(u8, trimmed, "Array<")) |_| {
        return try parseArrayType(allocator, trimmed);
    }
    if (std.mem.endsWith(u8, trimmed, "[]")) {
        return try parseArrayType(allocator, trimmed);
    }

    // Check for union pattern
    if (std.mem.indexOf(u8, trimmed, " | ")) |_| {
        return try parseUnionType(allocator, trimmed);
    }

    // Bare type without property name
    return try parseSimpleType(allocator, trimmed);
}

fn parseInterfaceType(
    allocator: std.mem.Allocator,
    description: []const u8,
) !?PropertyInfo {
    // Extract interface name and body
    // Format: "interface User { name: string; age: number }"
    const brace_start = std.mem.indexOf(u8, description, "{") orelse return null;
    const brace_end = std.mem.lastIndexOf(u8, description, "}") orelse return null;

    if (brace_end <= brace_start) return null;

    const body = description[brace_start + 1 .. brace_end];
    const name_part = std.mem.trim(u8, description[0..brace_start], " \t\n\r");

    // Extract interface name
    var name: []const u8 = "root";
    if (std.mem.indexOf(u8, name_part, "interface ")) |idx| {
        const after_interface = std.mem.trim(u8, name_part[idx + 10 ..], " \t\n\r");
        if (after_interface.len > 0) {
            name = after_interface;
        }
    }

    // Parse properties from body
    var props = std.ArrayList(u8){};
    const writer = props.writer(allocator);
    var required = std.ArrayList([]const u8){};

    try writer.writeAll("{\"type\":\"object\",\"properties\":{");

    var first = true;
    var iter = std.mem.splitScalar(u8, body, ';');
    while (iter.next()) |prop_def| {
        const trimmed_prop = std.mem.trim(u8, prop_def, " \t\n\r");
        if (trimmed_prop.len == 0) continue;

        // Parse "name: type" or "name?: type"
        const colon_idx = std.mem.indexOf(u8, trimmed_prop, ":") orelse continue;
        var prop_name = std.mem.trim(u8, trimmed_prop[0..colon_idx], " \t\n\r");
        const prop_type = std.mem.trim(u8, trimmed_prop[colon_idx + 1 ..], " \t\n\r");

        const optional = std.mem.endsWith(u8, prop_name, "?");
        if (optional) {
            prop_name = prop_name[0 .. prop_name.len - 1];
        }

        if (!first) try writer.writeAll(",");
        first = false;

        try writer.print("\"{s}\":", .{prop_name});
        try writeTypeSchema(writer, prop_type);

        if (!optional) {
            try required.append(allocator, try allocator.dupe(u8, prop_name));
        }
    }

    try writer.writeAll("}");

    // Add required fields
    if (required.items.len > 0) {
        try writer.writeAll(",\"required\":[");
        for (required.items, 0..) |req, i| {
            if (i > 0) try writer.writeAll(",");
            try writer.print("\"{s}\"", .{req});
        }
        try writer.writeAll("]");
    }

    try writer.writeAll("}");

    return PropertyInfo{
        .name = try allocator.dupe(u8, name),
        .type_schema = try allocator.dupe(u8, props.items),
        .optional = false,
    };
}

fn parseObjectType(
    allocator: std.mem.Allocator,
    description: []const u8,
) !?PropertyInfo {
    // Format: "{ name: string; age: number }"
    const brace_start = std.mem.indexOf(u8, description, "{") orelse return null;
    const brace_end = std.mem.lastIndexOf(u8, description, "}") orelse return null;

    if (brace_end <= brace_start) return null;

    const body = description[brace_start + 1 .. brace_end];

    var props = std.ArrayList(u8){};
    const writer = props.writer(allocator);
    var required = std.ArrayList([]const u8){};

    try writer.writeAll("{\"type\":\"object\",\"properties\":{");

    var first = true;
    var iter = std.mem.splitScalar(u8, body, ';');
    while (iter.next()) |prop_def| {
        const trimmed_prop = std.mem.trim(u8, prop_def, " \t\n\r");
        if (trimmed_prop.len == 0) continue;

        const colon_idx = std.mem.indexOf(u8, trimmed_prop, ":") orelse continue;
        var prop_name = std.mem.trim(u8, trimmed_prop[0..colon_idx], " \t\n\r");
        const prop_type = std.mem.trim(u8, trimmed_prop[colon_idx + 1 ..], " \t\n\r");

        const optional = std.mem.endsWith(u8, prop_name, "?");
        if (optional) {
            prop_name = prop_name[0 .. prop_name.len - 1];
        }

        if (!first) try writer.writeAll(",");
        first = false;

        try writer.print("\"{s}\":", .{prop_name});
        try writeTypeSchema(writer, prop_type);

        if (!optional) {
            try required.append(allocator, try allocator.dupe(u8, prop_name));
        }
    }

    try writer.writeAll("}");

    if (required.items.len > 0) {
        try writer.writeAll(",\"required\":[");
        for (required.items, 0..) |req, i| {
            if (i > 0) try writer.writeAll(",");
            try writer.print("\"{s}\"", .{req});
        }
        try writer.writeAll("]");
    }

    try writer.writeAll("}");

    return PropertyInfo{
        .name = try allocator.dupe(u8, "root"),
        .type_schema = try allocator.dupe(u8, props.items),
        .optional = false,
    };
}

fn parseArrayType(
    allocator: std.mem.Allocator,
    description: []const u8,
) !?PropertyInfo {
    var item_type: []const u8 = "string";

    // Handle "Array<Type>" format
    if (std.mem.indexOf(u8, description, "Array<")) |start_idx| {
        const type_start = start_idx + 6;
        const type_end = std.mem.lastIndexOf(u8, description, ">") orelse description.len;
        if (type_end > type_start) {
            item_type = std.mem.trim(u8, description[type_start..type_end], " \t\n\r");
        }
    }
    // Handle "Type[]" format
    else if (std.mem.endsWith(u8, description, "[]")) {
        item_type = std.mem.trim(u8, description[0 .. description.len - 2], " \t\n\r");
    }

    var schema = std.ArrayList(u8){};
    const writer = schema.writer(allocator);

    try writer.writeAll("{\"type\":\"array\",\"items\":");
    try writeTypeSchema(writer, item_type);
    try writer.writeAll("}");

    return PropertyInfo{
        .name = try allocator.dupe(u8, "root"),
        .type_schema = try allocator.dupe(u8, schema.items),
        .optional = false,
    };
}

fn parseUnionType(
    allocator: std.mem.Allocator,
    description: []const u8,
) !?PropertyInfo {
    var schema = std.ArrayList(u8){};
    const writer = schema.writer(allocator);

    try writer.writeAll("{\"anyOf\":[");

    var first = true;
    var iter = std.mem.splitSequence(u8, description, " | ");
    while (iter.next()) |type_part| {
        const trimmed = std.mem.trim(u8, type_part, " \t\n\r");
        if (trimmed.len == 0) continue;

        if (!first) try writer.writeAll(",");
        first = false;

        try writeTypeSchema(writer, trimmed);
    }

    try writer.writeAll("]}");

    return PropertyInfo{
        .name = try allocator.dupe(u8, "root"),
        .type_schema = try allocator.dupe(u8, schema.items),
        .optional = false,
    };
}

fn parseSimpleType(
    allocator: std.mem.Allocator,
    description: []const u8,
) !?PropertyInfo {
    // Check for "propertyName: type" pattern
    if (std.mem.indexOf(u8, description, ":")) |colon_idx| {
        var prop_name = std.mem.trim(u8, description[0..colon_idx], " \t\n\r");
        const prop_type = std.mem.trim(u8, description[colon_idx + 1 ..], " \t\n\r");

        const optional = std.mem.endsWith(u8, prop_name, "?");
        if (optional) {
            prop_name = prop_name[0 .. prop_name.len - 1];
        }

        var schema = std.ArrayList(u8){};
        const writer = schema.writer(allocator);
        try writeTypeSchema(writer, prop_type);

        return PropertyInfo{
            .name = try allocator.dupe(u8, prop_name),
            .type_schema = try allocator.dupe(u8, schema.items),
            .optional = optional,
        };
    }

    // Just a type name
    var schema = std.ArrayList(u8){};
    const writer = schema.writer(allocator);
    try writeTypeSchema(writer, description);

    return PropertyInfo{
        .name = try allocator.dupe(u8, "value"),
        .type_schema = try allocator.dupe(u8, schema.items),
        .optional = false,
    };
}

fn writeTypeSchema(
    writer: anytype,
    type_name: []const u8,
) !void {
    const trimmed = std.mem.trim(u8, type_name, " \t\n\r");

    // Check for array types first
    if (std.mem.indexOf(u8, trimmed, "Array<")) |start_idx| {
        const type_start = start_idx + 6;
        const type_end = std.mem.lastIndexOf(u8, trimmed, ">") orelse trimmed.len;
        if (type_end > type_start) {
            const item_type = std.mem.trim(u8, trimmed[type_start..type_end], " \t\n\r");
            try writer.writeAll("{\"type\":\"array\",\"items\":");
            try writeTypeSchema(writer, item_type); // Recursive call for nested types
            try writer.writeAll("}");
            return;
        }
    }
    if (std.mem.endsWith(u8, trimmed, "[]")) {
        const item_type = std.mem.trim(u8, trimmed[0 .. trimmed.len - 2], " \t\n\r");
        try writer.writeAll("{\"type\":\"array\",\"items\":");
        try writeTypeSchema(writer, item_type); // Recursive call for nested types
        try writer.writeAll("}");
        return;
    }

    // Map TypeScript/common types to JSON Schema types
    if (std.mem.eql(u8, trimmed, "string")) {
        try writer.writeAll("{\"type\":\"string\"}");
    } else if (std.mem.eql(u8, trimmed, "number") or
        std.mem.eql(u8, trimmed, "integer") or
        std.mem.eql(u8, trimmed, "int"))
    {
        try writer.writeAll("{\"type\":\"integer\"}");
    } else if (std.mem.eql(u8, trimmed, "float") or
        std.mem.eql(u8, trimmed, "double"))
    {
        try writer.writeAll("{\"type\":\"number\"}");
    } else if (std.mem.eql(u8, trimmed, "boolean") or
        std.mem.eql(u8, trimmed, "bool"))
    {
        try writer.writeAll("{\"type\":\"boolean\"}");
    } else if (std.mem.eql(u8, trimmed, "null")) {
        try writer.writeAll("{\"type\":\"null\"}");
    } else if (std.mem.indexOf(u8, trimmed, "email")) |_| {
        try writer.writeAll("{\"type\":\"string\",\"format\":\"email\"}");
    } else if (std.mem.indexOf(u8, trimmed, "uri") orelse std.mem.indexOf(u8, trimmed, "url")) |_| {
        try writer.writeAll("{\"type\":\"string\",\"format\":\"uri\"}");
    } else if (std.mem.indexOf(u8, trimmed, "date")) |_| {
        try writer.writeAll("{\"type\":\"string\",\"format\":\"date-time\"}");
    } else if (std.mem.startsWith(u8, trimmed, "pattern:")) {
        const pattern = std.mem.trim(u8, trimmed[8..], " \t\n\r");
        try writer.print("{{\"type\":\"string\",\"pattern\":\"{s}\"}}", .{pattern});
    } else if (std.mem.startsWith(u8, trimmed, "range:")) {
        // Format: "range:min-max" e.g., "range:0-100"
        const range_part = std.mem.trim(u8, trimmed[6..], " \t\n\r");
        if (std.mem.indexOf(u8, range_part, "-")) |dash_idx| {
            const min = std.mem.trim(u8, range_part[0..dash_idx], " \t\n\r");
            const max = std.mem.trim(u8, range_part[dash_idx + 1 ..], " \t\n\r");
            try writer.print("{{\"type\":\"integer\",\"minimum\":{s},\"maximum\":{s}}}", .{ min, max });
        } else {
            try writer.writeAll("{\"type\":\"integer\"}");
        }
    } else {
        // Unknown type - treat as object or string
        try writer.writeAll("{\"type\":\"string\"}");
    }
}
