//! C FFI Interface for Ananke
//!
//! Provides C-compatible functions for Rust integration.
//! These functions are exported and callable from Rust via FFI.

const std = @import("std");
const root = @import("ananke");
const Clew = root.clew.Clew;
const Braid = root.braid.Braid;
const Constraint = root.types.constraint.Constraint;
const ConstraintIR = root.types.constraint.ConstraintIR;
const ConstraintSet = root.types.constraint.ConstraintSet;

// Global allocator for FFI operations
var gpa_instance = std.heap.GeneralPurposeAllocator(.{}){};
const gpa = gpa_instance.allocator();

/// C-compatible error codes
pub const AnankeError = enum(c_int) {
    Success = 0,
    NullPointer = 1,
    AllocationFailure = 2,
    InvalidInput = 3,
    ExtractionFailed = 4,
    CompilationFailed = 5,
};

/// C-compatible TokenMaskRules structure matching Rust FFI definition
pub const TokenMaskRulesFFI = extern struct {
    /// Allowed tokens array
    allowed_tokens: ?[*]const u32,
    allowed_tokens_len: usize,

    /// Forbidden tokens array
    forbidden_tokens: ?[*]const u32,
    forbidden_tokens_len: usize,
};

/// C-compatible ConstraintIR structure
pub const ConstraintIRFFI = extern struct {
    /// JSON schema pointer (nullable)
    json_schema: ?[*:0]const u8,

    /// Grammar rules pointer (nullable)
    grammar: ?[*:0]const u8,

    /// Regex patterns array
    regex_patterns: ?[*]const [*:0]const u8,
    regex_patterns_len: usize,

    /// Token masks pointer to TokenMaskRulesFFI struct (nullable)
    token_masks: ?*const TokenMaskRulesFFI,

    /// Priority for conflict resolution
    priority: u32,

    /// Constraint name
    name: ?[*:0]const u8,
};

/// Initialize Ananke system
///
/// Must be called before other FFI functions.
/// Returns 0 on success, error code otherwise.
export fn ananke_init() callconv(.c) c_int {
    // Initialization is handled by module-level GPA
    return @intFromEnum(AnankeError.Success);
}

/// Cleanup Ananke system
///
/// Should be called when done using Ananke.
export fn ananke_deinit() callconv(.c) void {
    // Cleanup handled automatically by GPA deinit
    _ = gpa_instance.deinit();
}

/// Extract constraints from source code
///
/// # Parameters
/// - source: Source code as null-terminated C string
/// - language: Language name as null-terminated C string
/// - out_ir: Output pointer for ConstraintIR (allocated by this function)
///
/// # Returns
/// Error code (0 = success)
///
/// # Safety
/// Caller must free the returned ConstraintIR using ananke_free_constraint_ir
export fn ananke_extract_constraints(
    source: [*:0]const u8,
    language: [*:0]const u8,
    out_ir: *?*ConstraintIRFFI,
) callconv(.c) c_int {
    if (out_ir.* != null) {
        return @intFromEnum(AnankeError.InvalidInput);
    }

    // Convert C strings to Zig slices
    const source_slice = std.mem.span(source);
    const language_slice = std.mem.span(language);

    // Initialize Clew
    var clew = Clew.init(gpa) catch {
        return @intFromEnum(AnankeError.AllocationFailure);
    };
    defer clew.deinit();

    // Extract constraints
    var constraint_set = clew.extractFromCode(source_slice, language_slice) catch {
        return @intFromEnum(AnankeError.ExtractionFailed);
    };
    defer constraint_set.deinit();

    // Initialize Braid to compile extracted constraints
    var braid = Braid.init(gpa) catch {
        return @intFromEnum(AnankeError.AllocationFailure);
    };
    defer braid.deinit();

    // Compile the extracted constraints to IR
    const ir = braid.compile(constraint_set.constraints.items) catch {
        // If compilation fails, create a minimal IR with extracted metadata
        const ir_ffi = gpa.create(ConstraintIRFFI) catch {
            return @intFromEnum(AnankeError.AllocationFailure);
        };

        // Create name based on language and constraint count
        const name_buf = gpa.allocSentinel(u8, 64, 0) catch {
            gpa.destroy(ir_ffi);
            return @intFromEnum(AnankeError.AllocationFailure);
        };

        _ = std.fmt.bufPrint(
            name_buf,
            "{s}_extracted_{d}",
            .{ language_slice, constraint_set.constraints.items.len },
        ) catch {};

        // Create minimal IR with basic info
        ir_ffi.* = .{
            .json_schema = null,
            .grammar = null,
            .regex_patterns = null,
            .regex_patterns_len = 0,
            .token_masks = null,
            .priority = 50, // Default priority for extracted constraints
            .name = name_buf.ptr,
        };

        out_ir.* = ir_ffi;
        return @intFromEnum(AnankeError.Success);
    };

    // Convert the compiled IR to FFI format
    const ir_ffi = convertIRToFFI(gpa, ir) catch |err| {
        // Clean up IR before returning error
        var mutable_ir = ir;
        mutable_ir.deinit(gpa);
        return switch (err) {
            error.OutOfMemory => @intFromEnum(AnankeError.AllocationFailure),
            else => @intFromEnum(AnankeError.CompilationFailed),
        };
    };

    // Clean up original IR (data has been copied to FFI struct)
    var mutable_ir = ir;
    mutable_ir.deinit(gpa);

    out_ir.* = ir_ffi;
    return @intFromEnum(AnankeError.Success);
}

/// Compile constraints to ConstraintIR
///
/// # Parameters
/// - constraints_json: JSON string containing array of constraints
/// - out_ir: Output pointer for ConstraintIR
///
/// # Returns
/// Error code (0 = success)
///
/// # JSON Format
/// Expected format is an array of constraint objects:
/// [
///   {
///     "id": 1,
///     "kind": "type_safety",
///     "name": "use_camelCase",
///     "description": "Functions must use camelCase naming",
///     "severity": "error",
///     "priority": "high"
///   }
/// ]
export fn ananke_compile_constraints(
    constraints_json: [*:0]const u8,
    out_ir: *?*ConstraintIRFFI,
) callconv(.c) c_int {
    if (out_ir.* != null) {
        return @intFromEnum(AnankeError.InvalidInput);
    }

    const json_slice = std.mem.span(constraints_json);

    // Parse JSON constraints
    var constraint_set = parseConstraintsJson(gpa, json_slice) catch {
        return @intFromEnum(AnankeError.InvalidInput);
    };
    defer constraint_set.deinit();

    // Initialize Braid
    var braid = Braid.init(gpa) catch {
        return @intFromEnum(AnankeError.AllocationFailure);
    };
    defer braid.deinit();

    // Use the public compile method which handles all compilation steps
    const ir = braid.compile(constraint_set.constraints.items) catch {
        return @intFromEnum(AnankeError.CompilationFailed);
    };

    // Convert ConstraintIR to FFI-compatible format
    const ir_ffi = convertIRToFFI(gpa, ir) catch |err| {
        // Clean up IR before returning error
        var mutable_ir = ir;
        mutable_ir.deinit(gpa);
        return switch (err) {
            error.OutOfMemory => @intFromEnum(AnankeError.AllocationFailure),
            else => @intFromEnum(AnankeError.CompilationFailed),
        };
    };

    // Clean up original IR (data has been copied to FFI struct)
    var mutable_ir = ir;
    mutable_ir.deinit(gpa);

    out_ir.* = ir_ffi;
    return @intFromEnum(AnankeError.Success);
}

// ============================================================================
// Helper Functions
// ============================================================================

/// Parse JSON constraint array into ConstraintSet
fn parseConstraintsJson(
    allocator: std.mem.Allocator,
    json_str: []const u8,
) !ConstraintSet {
    const parsed = try std.json.parseFromSlice(
        std.json.Value,
        allocator,
        json_str,
        .{},
    );
    defer parsed.deinit();

    // JSON can be either an array or an object with "constraints" field
    const constraints_array = if (parsed.value == .array)
        parsed.value.array
    else if (parsed.value == .object)
        if (parsed.value.object.get("constraints")) |c|
            c.array
        else
            return error.InvalidJson
    else
        return error.InvalidJson;

    var constraint_set = ConstraintSet.init(
        allocator,
        try allocator.dupe(u8, "ffi_constraints"),
    );

    for (constraints_array.items) |constraint_value| {
        const constraint_obj = constraint_value.object;

        const kind_str = constraint_obj.get("kind").?.string;
        const severity_str = constraint_obj.get("severity").?.string;
        const constraint_name = constraint_obj.get("name").?.string;
        const description = constraint_obj.get("description").?.string;

        const id = if (constraint_obj.get("id")) |id_val|
            switch (id_val) {
                .integer => |i| @as(u64, @intCast(i)),
                else => 0,
            }
        else
            0;

        const kind = parseConstraintKind(kind_str);
        const severity = parseSeverity(severity_str);
        const priority = if (constraint_obj.get("priority")) |p|
            parsePriority(p.string)
        else
            root.types.constraint.ConstraintPriority.Medium;

        const constraint = Constraint{
            .id = id,
            .kind = kind,
            .severity = severity,
            .name = try allocator.dupe(u8, constraint_name),
            .description = try allocator.dupe(u8, description),
            .source = .User_Defined,
            .priority = priority,
            .confidence = if (constraint_obj.get("confidence")) |c| @floatCast(c.float) else 1.0,
        };

        try constraint_set.add(constraint);
    }

    return constraint_set;
}

fn parseConstraintKind(s: []const u8) root.types.constraint.ConstraintKind {
    if (std.mem.eql(u8, s, "syntactic")) return .syntactic;
    if (std.mem.eql(u8, s, "type_safety")) return .type_safety;
    if (std.mem.eql(u8, s, "semantic")) return .semantic;
    if (std.mem.eql(u8, s, "architectural")) return .architectural;
    if (std.mem.eql(u8, s, "operational")) return .operational;
    if (std.mem.eql(u8, s, "security")) return .security;
    return .semantic;
}

fn parseSeverity(s: []const u8) root.types.constraint.Severity {
    if (std.mem.eql(u8, s, "error") or std.mem.eql(u8, s, "err")) return .err;
    if (std.mem.eql(u8, s, "warning")) return .warning;
    if (std.mem.eql(u8, s, "info")) return .info;
    if (std.mem.eql(u8, s, "hint")) return .hint;
    return .err;
}

fn parsePriority(s: []const u8) root.types.constraint.ConstraintPriority {
    if (std.mem.eql(u8, s, "low")) return .Low;
    if (std.mem.eql(u8, s, "medium")) return .Medium;
    if (std.mem.eql(u8, s, "high")) return .High;
    if (std.mem.eql(u8, s, "critical")) return .Critical;
    return .Medium;
}

/// Convert ConstraintIR to C-compatible ConstraintIRFFI
fn convertIRToFFI(
    allocator: std.mem.Allocator,
    ir: ConstraintIR,
) !*ConstraintIRFFI {
    const ir_ffi = try allocator.create(ConstraintIRFFI);
    errdefer allocator.destroy(ir_ffi);

    // Allocate and copy JSON schema if present
    const json_schema_ptr = if (ir.json_schema) |schema| blk: {
        const schema_str = try serializeJsonSchema(allocator, schema);
        errdefer allocator.free(schema_str);
        break :blk try allocator.dupeZ(u8, schema_str);
    } else null;

    // Allocate and copy grammar if present
    const grammar_ptr = if (ir.grammar) |grammar| blk: {
        const grammar_str = try serializeGrammar(allocator, grammar);
        errdefer allocator.free(grammar_str);
        break :blk try allocator.dupeZ(u8, grammar_str);
    } else null;

    // Allocate and copy regex patterns with flags
    var regex_ptrs: ?[*][*:0]const u8 = null;
    var regex_len: usize = 0;
    if (ir.regex_patterns.len > 0) {
        const patterns = try allocator.alloc([*:0]const u8, ir.regex_patterns.len);
        errdefer allocator.free(patterns);

        for (ir.regex_patterns, 0..) |regex, i| {
            // Include flags in pattern if present
            const pattern_with_flags = if (regex.flags.len > 0) blk: {
                const formatted = try std.fmt.allocPrint(allocator, "{s}|FLAGS:{s}", .{ regex.pattern, regex.flags });
                defer allocator.free(formatted);
                break :blk try allocator.dupeZ(u8, formatted);
            } else try allocator.dupeZ(u8, regex.pattern);
            patterns[i] = pattern_with_flags.ptr;
        }
        regex_ptrs = patterns.ptr;
        regex_len = patterns.len;
    }

    // Allocate and copy token masks if present
    var token_masks_ptr: ?*TokenMaskRulesFFI = null;
    if (ir.token_masks) |masks| {
        const masks_ffi = try allocator.create(TokenMaskRulesFFI);
        errdefer allocator.destroy(masks_ffi);

        // Copy allowed tokens
        var allowed_ptr: ?[*]u32 = null;
        var allowed_len: usize = 0;
        if (masks.allowed_tokens) |tokens| {
            const allowed_copy = try allocator.alloc(u32, tokens.len);
            @memcpy(allowed_copy, tokens);
            allowed_ptr = allowed_copy.ptr;
            allowed_len = tokens.len;
        }

        // Copy forbidden tokens
        var forbidden_ptr: ?[*]u32 = null;
        var forbidden_len: usize = 0;
        if (masks.forbidden_tokens) |tokens| {
            const forbidden_copy = try allocator.alloc(u32, tokens.len);
            @memcpy(forbidden_copy, tokens);
            forbidden_ptr = forbidden_copy.ptr;
            forbidden_len = tokens.len;
        }

        masks_ffi.* = .{
            .allowed_tokens = allowed_ptr,
            .allowed_tokens_len = allowed_len,
            .forbidden_tokens = forbidden_ptr,
            .forbidden_tokens_len = forbidden_len,
        };

        token_masks_ptr = masks_ffi;
    }

    // Generate a name for this IR
    const name_buf = try allocator.allocSentinel(u8, 64, 0);
    errdefer allocator.free(name_buf);
    _ = try std.fmt.bufPrint(name_buf, "compiled_ir_p{d}", .{ir.priority});

    ir_ffi.* = .{
        .json_schema = if (json_schema_ptr) |ptr| ptr.ptr else null,
        .grammar = if (grammar_ptr) |ptr| ptr.ptr else null,
        .regex_patterns = regex_ptrs,
        .regex_patterns_len = regex_len,
        .token_masks = token_masks_ptr,
        .priority = ir.priority,
        .name = name_buf.ptr,
    };

    return ir_ffi;
}

/// Serialize JsonSchema to JSON string
fn serializeJsonSchema(
    allocator: std.mem.Allocator,
    schema: root.types.constraint.JsonSchema,
) ![]const u8 {
    var buf = std.ArrayList(u8){};
    defer buf.deinit(allocator);

    const writer = buf.writer(allocator);
    try writer.writeAll("{\"schema_type\":\"");
    try writer.writeAll(schema.type);
    try writer.writeAll("\"");

    // Add properties if present
    if (schema.properties) |_| {
        try writer.writeAll(",\"properties\":");
        // For now, serialize as empty object - full JSON map serialization would be complex
        try writer.writeAll("{}");
    }

    // Add required array if present
    if (schema.required.len > 0) {
        try writer.writeAll(",\"required\":[");
        for (schema.required, 0..) |req, i| {
            if (i > 0) try writer.writeAll(",");
            try writer.writeAll("\"");
            try writer.writeAll(req);
            try writer.writeAll("\"");
        }
        try writer.writeAll("]");
    }

    // Add additional_properties flag
    try writer.writeAll(",\"additional_properties\":");
    try writer.writeAll(if (schema.additional_properties) "true" else "false");

    try writer.writeAll("}");

    return try buf.toOwnedSlice(allocator);
}

/// Serialize Grammar to JSON string
fn serializeGrammar(
    allocator: std.mem.Allocator,
    grammar: root.types.constraint.Grammar,
) ![]const u8 {
    var buf = std.ArrayList(u8){};
    defer buf.deinit(allocator);

    const writer = buf.writer(allocator);
    try writer.writeAll("{\"start_symbol\":\"");
    try writer.writeAll(grammar.start_symbol);
    try writer.writeAll("\",\"rules\":[");

    for (grammar.rules, 0..) |rule, i| {
        if (i > 0) try writer.writeAll(",");
        try writer.writeAll("{\"lhs\":\"");
        try writer.writeAll(rule.lhs);
        try writer.writeAll("\",\"rhs\":[");
        for (rule.rhs, 0..) |rhs_item, j| {
            if (j > 0) try writer.writeAll(",");
            try writer.writeAll("\"");
            try writer.writeAll(rhs_item);
            try writer.writeAll("\"");
        }
        try writer.writeAll("]}");
    }

    try writer.writeAll("]}");
    return try buf.toOwnedSlice(allocator);
}

// ============================================================================
// Exported Functions
// ============================================================================

/// Free a ConstraintIR structure
///
/// # Safety
/// Must be called exactly once on each ConstraintIR returned by other functions
export fn ananke_free_constraint_ir(ir: ?*ConstraintIRFFI) callconv(.c) void {
    if (ir) |ptr| {
        // Free name string
        if (ptr.name) |name| {
            const name_slice = std.mem.span(name);
            gpa.free(name_slice);
        }

        // Free regex patterns if present
        if (ptr.regex_patterns) |patterns| {
            const patterns_slice = patterns[0..ptr.regex_patterns_len];
            for (patterns_slice) |pattern| {
                const pattern_slice = std.mem.span(pattern);
                gpa.free(pattern_slice);
            }
            gpa.free(patterns_slice);
        }

        // Free JSON schema if present
        if (ptr.json_schema) |schema| {
            const schema_slice = std.mem.span(schema);
            gpa.free(schema_slice);
        }

        // Free grammar if present
        if (ptr.grammar) |grammar| {
            const grammar_slice = std.mem.span(grammar);
            gpa.free(grammar_slice);
        }

        // Free token masks if present
        if (ptr.token_masks) |masks| {
            // Free allowed tokens array
            if (masks.allowed_tokens) |tokens| {
                const allowed_slice = tokens[0..masks.allowed_tokens_len];
                gpa.free(allowed_slice);
            }

            // Free forbidden tokens array
            if (masks.forbidden_tokens) |tokens| {
                const forbidden_slice = tokens[0..masks.forbidden_tokens_len];
                gpa.free(forbidden_slice);
            }

            // Free the TokenMaskRulesFFI struct itself
            gpa.destroy(masks);
        }

        gpa.destroy(ptr);
    }
}

/// Get version information
///
/// Returns a null-terminated string with version info.
/// Caller does NOT need to free this string.
export fn ananke_version() callconv(.c) [*:0]const u8 {
    return "Ananke v0.1.0 (Zig 0.15.1)";
}

// Tests
test "FFI basic operations" {
    const testing = std.testing;

    // Test initialization
    const init_result = ananke_init();
    try testing.expectEqual(@intFromEnum(AnankeError.Success), init_result);

    // Test version
    const version = ananke_version();
    try testing.expect(std.mem.len(version) > 0);

    // Cleanup
    ananke_deinit();
}

test "FFI constraint compilation" {
    const testing = std.testing;

    // Test JSON with constraints
    const json_constraints =
        \\[
        \\  {
        \\    "id": 1,
        \\    "kind": "syntactic",
        \\    "name": "use_camelCase",
        \\    "description": "Functions must use camelCase naming",
        \\    "severity": "error",
        \\    "priority": "high"
        \\  },
        \\  {
        \\    "id": 2,
        \\    "kind": "type_safety",
        \\    "name": "explicit_types",
        \\    "description": "All function parameters must have explicit types",
        \\    "severity": "error",
        \\    "priority": "medium"
        \\  }
        \\]
    ;

    // Initialize
    _ = ananke_init();
    defer ananke_deinit();

    // Compile constraints
    var ir_ptr: ?*ConstraintIRFFI = null;
    const result = ananke_compile_constraints(json_constraints.ptr, &ir_ptr);

    // Check compilation succeeded
    try testing.expectEqual(@intFromEnum(AnankeError.Success), result);
    try testing.expect(ir_ptr != null);

    // Verify IR fields
    if (ir_ptr) |ir| {
        try testing.expect(ir.name != null);
        try testing.expect(ir.priority > 0);

        // Clean up
        ananke_free_constraint_ir(ir);
    }
}

test "FFI constraint compilation with invalid JSON" {
    const testing = std.testing;

    const invalid_json = "{ invalid json }";

    // Initialize
    _ = ananke_init();
    defer ananke_deinit();

    // Try to compile invalid JSON
    var ir_ptr: ?*ConstraintIRFFI = null;
    const result = ananke_compile_constraints(invalid_json.ptr, &ir_ptr);

    // Should fail with InvalidInput error
    try testing.expectEqual(@intFromEnum(AnankeError.InvalidInput), result);
    try testing.expect(ir_ptr == null);
}

test "FFI constraint compilation produces valid IR components" {
    const testing = std.testing;

    // Test with constraints that should produce grammar and patterns
    const json_constraints =
        \\[
        \\  {
        \\    "id": 1,
        \\    "kind": "syntactic",
        \\    "name": "function_style",
        \\    "description": "Functions should use arrow function syntax",
        \\    "severity": "warning",
        \\    "priority": "low"
        \\  },
        \\  {
        \\    "id": 2,
        \\    "kind": "syntactic",
        \\    "name": "naming",
        \\    "description": "Variables must match regex: ^[a-z][a-zA-Z0-9]*$",
        \\    "severity": "error",
        \\    "priority": "high"
        \\  }
        \\]
    ;

    // Initialize
    _ = ananke_init();
    defer ananke_deinit();

    // Compile constraints
    var ir_ptr: ?*ConstraintIRFFI = null;
    const result = ananke_compile_constraints(json_constraints.ptr, &ir_ptr);

    try testing.expectEqual(@intFromEnum(AnankeError.Success), result);

    if (ir_ptr) |ir| {
        defer ananke_free_constraint_ir(ir);

        // Verify we got a name
        try testing.expect(ir.name != null);
        if (ir.name) |name| {
            const name_str = std.mem.span(name);
            try testing.expect(name_str.len > 0);
        }

        // Check priority was computed
        try testing.expect(ir.priority > 0);

        // Grammar should be generated for syntactic constraints
        if (ir.grammar) |grammar| {
            const grammar_str = std.mem.span(grammar);
            try testing.expect(grammar_str.len > 0);
            try testing.expect(std.mem.indexOf(u8, grammar_str, "start_symbol") != null);
        }

        // Regex patterns should be extracted
        if (ir.regex_patterns_len > 0) {
            try testing.expect(ir.regex_patterns != null);
        }
    }
}
