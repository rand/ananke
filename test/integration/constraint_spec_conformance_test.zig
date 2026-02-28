// ConstraintSpec Round-Trip Conformance Test
//
// Validates that Zig-serialized ConstraintSpec JSON conforms to the contract
// expected by Python's ConstraintSpec consumer. Tests all 5 CLaSH domains:
// Syntax (grammar), Types (function_signatures, type_bindings),
// Imports (imports), ControlFlow (control_flow), Semantics (semantic_constraints).
//
// This test ensures the serialization boundary between System A (Zig) and
// System B (Python/sglang) stays correct.

const std = @import("std");
const ananke = @import("ananke");
const constraint = ananke.types.constraint;

// ============================================================================
// Test fixtures
// ============================================================================

const zig_fixture =
    \\const std = @import("std");
    \\const fs = std.fs;
    \\
    \\pub const Config = struct {
    \\    name: []const u8,
    \\    timeout: u32 = 30,
    \\
    \\    pub fn init(allocator: std.mem.Allocator) Config {
    \\        _ = allocator;
    \\        return .{ .name = "default", .timeout = 30 };
    \\    }
    \\
    \\    pub fn loadFromFile(path: []const u8) !Config {
    \\        _ = path;
    \\        return error.FileNotFound;
    \\    }
    \\};
;

const python_fixture =
    \\import asyncio
    \\from typing import Optional, Dict, List
    \\
    \\class UserService:
    \\    def __init__(self, db_url: str):
    \\        self.db_url = db_url
    \\
    \\    async def get_user(self, user_id: int) -> Optional[Dict]:
    \\        return {"id": user_id}
    \\
    \\    async def create_user(self, name: str, email: str) -> Dict:
    \\        return {"name": name, "email": email}
    \\
    \\    def validate_email(self, email: str) -> bool:
    \\        return "@" in email
;

const typescript_fixture =
    \\import { Database } from './db';
    \\import { Logger } from './logger';
    \\
    \\interface UserConfig {
    \\    maxRetries: number;
    \\    timeout: number;
    \\}
    \\
    \\class AuthService {
    \\    private db: Database;
    \\
    \\    constructor(db: Database) {
    \\        this.db = db;
    \\    }
    \\
    \\    async authenticate(token: string): Promise<boolean> {
    \\        try {
    \\            const user = await this.db.findUser(token);
    \\            return user !== null;
    \\        } catch (err) {
    \\            throw new Error("Auth failed");
    \\        }
    \\    }
    \\}
;

// ============================================================================
// JSON validation helpers
// ============================================================================

fn parseJsonObject(allocator: std.mem.Allocator, json_str: []const u8) !std.json.Value {
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_str, .{});
    _ = parsed; // We use parseFromSlice which returns a Parsed type
    // Use the lower-level API instead
    var scanner = std.json.Scanner.initCompleteInput(allocator, json_str);
    defer scanner.deinit();
    return try std.json.Value.jsonParse(allocator, &scanner, .{ .max_value_len = json_str.len });
}

fn assertJsonArray(value: std.json.Value) !void {
    if (value != .array) return error.ExpectedArray;
}

fn assertJsonObject(value: std.json.Value) !void {
    if (value != .object) return error.ExpectedObject;
}

fn assertJsonString(obj: std.json.ObjectMap, key: []const u8) ![]const u8 {
    const val = obj.get(key) orelse return error.MissingField;
    if (val != .string) return error.ExpectedString;
    return val.string;
}

fn assertJsonBool(obj: std.json.ObjectMap, key: []const u8) !bool {
    const val = obj.get(key) orelse return error.MissingField;
    switch (val) {
        .bool => return val.bool,
        else => return error.ExpectedBool,
    }
}

// ============================================================================
// Tests
// ============================================================================

test "conformance: RichContext produces valid JSON for all field types" {
    const allocator = std.testing.allocator;

    // Test with Zig source
    var engine = try ananke.Ananke.init(allocator);
    defer engine.deinit();

    var rich_ctx = try engine.extractRichContext(zig_fixture, "zig");
    defer rich_ctx.deinit(allocator);

    // Verify function_signatures is valid JSON array
    if (rich_ctx.function_signatures_json) |fs_json| {
        const parsed = try std.json.parseFromSlice(std.json.Value, allocator, fs_json, .{});
        defer parsed.deinit();
        try std.testing.expect(parsed.value == .array);
        try std.testing.expect(parsed.value.array.items.len > 0);

        // Each function signature must have required fields
        for (parsed.value.array.items) |item| {
            try std.testing.expect(item == .object);
            const obj = item.object;
            // Must have "name" field
            try std.testing.expect(obj.get("name") != null);
            // Must have "is_async" field
            try std.testing.expect(obj.get("is_async") != null);
            // Must have "is_public" field
            try std.testing.expect(obj.get("is_public") != null);
        }
    } else {
        // Zig fixture should produce function signatures
        return error.MissingFunctionSignatures;
    }

    // Verify type_bindings is valid JSON array
    if (rich_ctx.type_bindings_json) |tb_json| {
        const parsed = try std.json.parseFromSlice(std.json.Value, allocator, tb_json, .{});
        defer parsed.deinit();
        try std.testing.expect(parsed.value == .array);
        try std.testing.expect(parsed.value.array.items.len > 0);

        for (parsed.value.array.items) |item| {
            try std.testing.expect(item == .object);
            const obj = item.object;
            // Must have "name" field
            try std.testing.expect(obj.get("name") != null);
            // Must have "kind" field
            try std.testing.expect(obj.get("kind") != null);
        }
    } else {
        return error.MissingTypeBindings;
    }

    // Verify imports is valid JSON array
    if (rich_ctx.imports_json) |im_json| {
        const parsed = try std.json.parseFromSlice(std.json.Value, allocator, im_json, .{});
        defer parsed.deinit();
        try std.testing.expect(parsed.value == .array);

        for (parsed.value.array.items) |item| {
            try std.testing.expect(item == .object);
            const obj = item.object;
            // Must have "module" field
            try std.testing.expect(obj.get("module") != null);
        }
    } else {
        return error.MissingImports;
    }
}

test "conformance: control_flow JSON structure" {
    const allocator = std.testing.allocator;

    var engine = try ananke.Ananke.init(allocator);
    defer engine.deinit();

    // Zig fixture has error-returning functions
    var rich_ctx = try engine.extractRichContext(zig_fixture, "zig");
    defer rich_ctx.deinit(allocator);

    if (rich_ctx.control_flow_json) |cf_json| {
        const parsed = try std.json.parseFromSlice(std.json.Value, allocator, cf_json, .{});
        defer parsed.deinit();
        try std.testing.expect(parsed.value == .object);
        const obj = parsed.value.object;

        // Required fields
        try std.testing.expect(obj.get("async_function_count") != null);
        try std.testing.expect(obj.get("error_handling_count") != null);
        try std.testing.expect(obj.get("total_functions") != null);
        try std.testing.expect(obj.get("has_result_types") != null);
        try std.testing.expect(obj.get("has_option_types") != null);
        try std.testing.expect(obj.get("error_handling_style") != null);

        // Verify error_handling_style is a known value
        const style = obj.get("error_handling_style").?.string;
        try std.testing.expect(
            std.mem.eql(u8, style, "result_based") or
                std.mem.eql(u8, style, "exception_based") or
                std.mem.eql(u8, style, "none"),
        );
    } else {
        return error.MissingControlFlow;
    }
}

test "conformance: semantic_constraints JSON structure" {
    const allocator = std.testing.allocator;

    var engine = try ananke.Ananke.init(allocator);
    defer engine.deinit();

    var rich_ctx = try engine.extractRichContext(zig_fixture, "zig");
    defer rich_ctx.deinit(allocator);

    if (rich_ctx.semantic_constraints_json) |sc_json| {
        const parsed = try std.json.parseFromSlice(std.json.Value, allocator, sc_json, .{});
        defer parsed.deinit();
        try std.testing.expect(parsed.value == .array);

        for (parsed.value.array.items) |item| {
            try std.testing.expect(item == .object);
            const obj = item.object;

            // Must have "kind" field with known value
            const kind = obj.get("kind").?.string;
            try std.testing.expect(
                std.mem.eql(u8, kind, "error_handling_required") or
                    std.mem.eql(u8, kind, "async_pattern") or
                    std.mem.eql(u8, kind, "error_type_defined"),
            );

            // Must have "tier" field = "soft"
            const tier = obj.get("tier").?.string;
            try std.testing.expect(std.mem.eql(u8, tier, "soft"));
        }
    } else {
        return error.MissingSemanticConstraints;
    }
}

test "conformance: Zig error-returning functions produce correct morphisms" {
    const allocator = std.testing.allocator;

    var engine = try ananke.Ananke.init(allocator);
    defer engine.deinit();

    var rich_ctx = try engine.extractRichContext(zig_fixture, "zig");
    defer rich_ctx.deinit(allocator);

    // loadFromFile returns !Config → should have error_handling_required
    const sc_parsed = try std.json.parseFromSlice(std.json.Value, allocator, rich_ctx.semantic_constraints_json.?, .{});
    defer sc_parsed.deinit();

    var found_load = false;
    for (sc_parsed.value.array.items) |item| {
        const obj = item.object;
        const kind = obj.get("kind").?.string;
        if (std.mem.eql(u8, kind, "error_handling_required")) {
            if (obj.get("function")) |func| {
                if (std.mem.eql(u8, func.string, "loadFromFile")) {
                    found_load = true;
                    // Verify return_type field exists
                    const ret = obj.get("return_type").?.string;
                    try std.testing.expect(std.mem.eql(u8, ret, "!Config"));
                }
            }
        }
    }
    try std.testing.expect(found_load);

    // control_flow should show result_based error handling
    const cf_parsed = try std.json.parseFromSlice(std.json.Value, allocator, rich_ctx.control_flow_json.?, .{});
    defer cf_parsed.deinit();
    const style = cf_parsed.value.object.get("error_handling_style").?.string;
    try std.testing.expect(std.mem.eql(u8, style, "result_based"));
    try std.testing.expect(cf_parsed.value.object.get("has_result_types").?.bool == true);
}

test "conformance: Python async functions produce async_pattern constraints" {
    const allocator = std.testing.allocator;

    var engine = try ananke.Ananke.init(allocator);
    defer engine.deinit();

    var rich_ctx = try engine.extractRichContext(python_fixture, "python");
    defer rich_ctx.deinit(allocator);

    // Should have function signatures including async ones
    if (rich_ctx.function_signatures_json) |fs_json| {
        const parsed = try std.json.parseFromSlice(std.json.Value, allocator, fs_json, .{});
        defer parsed.deinit();

        var async_count: usize = 0;
        for (parsed.value.array.items) |item| {
            const obj = item.object;
            if (obj.get("is_async")) |is_async| {
                if (is_async.bool) async_count += 1;
            }
        }
        try std.testing.expect(async_count >= 2); // get_user, create_user
    }

    // Should have async_pattern semantic constraints
    if (rich_ctx.semantic_constraints_json) |sc_json| {
        const parsed = try std.json.parseFromSlice(std.json.Value, allocator, sc_json, .{});
        defer parsed.deinit();

        var async_constraints: usize = 0;
        for (parsed.value.array.items) |item| {
            const obj = item.object;
            const kind = obj.get("kind").?.string;
            if (std.mem.eql(u8, kind, "async_pattern")) {
                async_constraints += 1;
                // All must be soft tier
                const tier = obj.get("tier").?.string;
                try std.testing.expect(std.mem.eql(u8, tier, "soft"));
            }
        }
        try std.testing.expect(async_constraints >= 2);
    }

    // control_flow should show async functions
    if (rich_ctx.control_flow_json) |cf_json| {
        const parsed = try std.json.parseFromSlice(std.json.Value, allocator, cf_json, .{});
        defer parsed.deinit();
        const async_fn_count = parsed.value.object.get("async_function_count").?.integer;
        try std.testing.expect(async_fn_count >= 2);
    }
}

test "conformance: TypeScript class extraction with imports" {
    const allocator = std.testing.allocator;

    var engine = try ananke.Ananke.init(allocator);
    defer engine.deinit();

    var rich_ctx = try engine.extractRichContext(typescript_fixture, "typescript");
    defer rich_ctx.deinit(allocator);

    // Should have class_definitions for AuthService
    if (rich_ctx.class_definitions_json) |cd_json| {
        const parsed = try std.json.parseFromSlice(std.json.Value, allocator, cd_json, .{});
        defer parsed.deinit();
        try std.testing.expect(parsed.value == .array);

        var found_auth = false;
        for (parsed.value.array.items) |item| {
            const obj = item.object;
            const name = obj.get("name").?.string;
            if (std.mem.eql(u8, name, "AuthService")) {
                found_auth = true;
            }
        }
        try std.testing.expect(found_auth);
    }

    // Should have imports
    if (rich_ctx.imports_json) |im_json| {
        const parsed = try std.json.parseFromSlice(std.json.Value, allocator, im_json, .{});
        defer parsed.deinit();
        try std.testing.expect(parsed.value == .array);
        try std.testing.expect(parsed.value.array.items.len > 0);
    }
}

test "conformance: RichContext clone preserves all fields" {
    const allocator = std.testing.allocator;

    var engine = try ananke.Ananke.init(allocator);
    defer engine.deinit();

    var original = try engine.extractRichContext(zig_fixture, "zig");
    defer original.deinit(allocator);

    var cloned = try original.clone(allocator);
    defer cloned.deinit(allocator);

    // All populated fields should be present in clone
    try std.testing.expect(original.hasData() == cloned.hasData());

    // Compare JSON content
    if (original.function_signatures_json) |orig_fs| {
        try std.testing.expect(cloned.function_signatures_json != null);
        try std.testing.expectEqualStrings(orig_fs, cloned.function_signatures_json.?);
        // Must be different allocations (not aliased)
        try std.testing.expect(orig_fs.ptr != cloned.function_signatures_json.?.ptr);
    }

    if (original.control_flow_json) |orig_cf| {
        try std.testing.expect(cloned.control_flow_json != null);
        try std.testing.expectEqualStrings(orig_cf, cloned.control_flow_json.?);
    }

    if (original.semantic_constraints_json) |orig_sc| {
        try std.testing.expect(cloned.semantic_constraints_json != null);
        try std.testing.expectEqualStrings(orig_sc, cloned.semantic_constraints_json.?);
    }
}

test "conformance: empty source produces empty but valid RichContext" {
    const allocator = std.testing.allocator;

    var engine = try ananke.Ananke.init(allocator);
    defer engine.deinit();

    var rich_ctx = try engine.extractRichContext("", "zig");
    defer rich_ctx.deinit(allocator);

    // Empty source should not produce data but should not crash
    // hasData() may be true or false depending on whether empty arrays are produced
    // The key invariant: deinit works without double-free
}

test "conformance: full ConstraintSpec JSON round-trip" {
    const allocator = std.testing.allocator;

    var engine = try ananke.Ananke.init(allocator);
    defer engine.deinit();

    // 1. Extract constraints
    var constraint_set = try engine.extract(zig_fixture, "zig");
    defer constraint_set.deinit();

    // 2. Compile to IR
    var ir = try engine.compile(constraint_set.constraints.items);
    defer ir.deinit(allocator);

    // 3. Extract rich context
    var rich_ctx = try engine.extractRichContext(zig_fixture, "zig");
    defer rich_ctx.deinit(allocator);

    // 4. Build combined ConstraintSpec JSON (mimics export-spec)
    var json_buf = std.ArrayList(u8){};
    defer json_buf.deinit(allocator);
    const writer = json_buf.writer(allocator);

    try writer.writeAll("{");
    try writer.print("\"language\":\"zig\"", .{});
    try writer.print(",\"priority\":{d}", .{ir.priority});

    if (rich_ctx.function_signatures_json) |fs| {
        try writer.writeAll(",\"function_signatures\":");
        try writer.writeAll(fs);
    }
    if (rich_ctx.type_bindings_json) |tb| {
        try writer.writeAll(",\"type_bindings\":");
        try writer.writeAll(tb);
    }
    if (rich_ctx.class_definitions_json) |cd| {
        try writer.writeAll(",\"class_definitions\":");
        try writer.writeAll(cd);
    }
    if (rich_ctx.imports_json) |im| {
        try writer.writeAll(",\"imports\":");
        try writer.writeAll(im);
    }
    if (rich_ctx.control_flow_json) |cf| {
        try writer.writeAll(",\"control_flow\":");
        try writer.writeAll(cf);
    }
    if (rich_ctx.semantic_constraints_json) |sc| {
        try writer.writeAll(",\"semantic_constraints\":");
        try writer.writeAll(sc);
    }

    try writer.writeAll("}");

    const spec_json = try json_buf.toOwnedSlice(allocator);
    defer allocator.free(spec_json);

    // 5. Parse the combined JSON — it must be valid
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, spec_json, .{});
    defer parsed.deinit();

    try std.testing.expect(parsed.value == .object);
    const obj = parsed.value.object;

    // Required top-level fields
    try std.testing.expectEqualStrings("zig", obj.get("language").?.string);
    try std.testing.expect(obj.get("priority") != null);

    // Rich context fields should be present for Zig code
    try std.testing.expect(obj.get("function_signatures") != null);
    try std.testing.expect(obj.get("type_bindings") != null);
    try std.testing.expect(obj.get("imports") != null);
    try std.testing.expect(obj.get("control_flow") != null);
    try std.testing.expect(obj.get("semantic_constraints") != null);

    // Validate types
    try std.testing.expect(obj.get("function_signatures").? == .array);
    try std.testing.expect(obj.get("type_bindings").? == .array);
    try std.testing.expect(obj.get("imports").? == .array);
    try std.testing.expect(obj.get("control_flow").? == .object);
    try std.testing.expect(obj.get("semantic_constraints").? == .array);
}

test "conformance: multi-language field consistency" {
    const allocator = std.testing.allocator;

    var engine = try ananke.Ananke.init(allocator);
    defer engine.deinit();

    // All languages should produce the same field names
    const fixtures = [_]struct { source: []const u8, lang: []const u8 }{
        .{ .source = zig_fixture, .lang = "zig" },
        .{ .source = python_fixture, .lang = "python" },
        .{ .source = typescript_fixture, .lang = "typescript" },
    };

    for (fixtures) |fixture| {
        var rich_ctx = try engine.extractRichContext(fixture.source, fixture.lang);
        defer rich_ctx.deinit(allocator);

        // Every language should produce function_signatures
        try std.testing.expect(rich_ctx.function_signatures_json != null);

        // Validate function_signatures field names are consistent
        const fs_parsed = try std.json.parseFromSlice(std.json.Value, allocator, rich_ctx.function_signatures_json.?, .{});
        defer fs_parsed.deinit();

        for (fs_parsed.value.array.items) |item| {
            const obj = item.object;
            // All languages must use these exact field names
            try std.testing.expect(obj.get("name") != null);
            try std.testing.expect(obj.get("is_async") != null);
            try std.testing.expect(obj.get("is_public") != null);
        }
    }
}
