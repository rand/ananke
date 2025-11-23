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

/// C-compatible ConstraintIR structure
pub const ConstraintIRFFI = extern struct {
    /// JSON schema pointer (nullable)
    json_schema: ?[*:0]const u8,

    /// Grammar rules pointer (nullable)
    grammar: ?[*:0]const u8,

    /// Regex patterns array
    regex_patterns: ?[*]const [*:0]const u8,
    regex_patterns_len: usize,

    /// Token masks (reserved for future use)
    token_masks: ?*anyopaque,

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

    // For now, create a simple IR with basic information
    // TODO: Full IR conversion once Braid compilation is complete
    const ir_ffi = gpa.create(ConstraintIRFFI) catch {
        return @intFromEnum(AnankeError.AllocationFailure);
    };

    // Allocate and copy constraint name
    const name_buf = gpa.allocSentinel(u8, 64, 0) catch {
        gpa.destroy(ir_ffi);
        return @intFromEnum(AnankeError.AllocationFailure);
    };

    const name_fmt = std.fmt.bufPrint(
        name_buf,
        "{s}_constraints_{d}",
        .{ language_slice, constraint_set.constraints.items.len },
    ) catch "constraints";
    _ = name_fmt;

    ir_ffi.* = .{
        .json_schema = null,
        .grammar = null,
        .regex_patterns = null,
        .regex_patterns_len = 0,
        .token_masks = null,
        .priority = 100,
        .name = name_buf.ptr,
    };

    out_ir.* = ir_ffi;
    return @intFromEnum(AnankeError.Success);
}

/// Compile constraints to ConstraintIR
///
/// # Parameters
/// - constraints: Array of constraint descriptions (JSON format)
/// - constraints_len: Number of constraints
/// - out_ir: Output pointer for ConstraintIR
///
/// # Returns
/// Error code (0 = success)
export fn ananke_compile_constraints(
    constraints: [*:0]const u8,
    out_ir: *?*ConstraintIRFFI,
) callconv(.c) c_int {
    if (out_ir.* != null) {
        return @intFromEnum(AnankeError.InvalidInput);
    }

    const constraints_slice = std.mem.span(constraints);
    _ = constraints_slice;

    // Initialize Braid
    var braid = Braid.init(gpa) catch {
        return @intFromEnum(AnankeError.AllocationFailure);
    };
    defer braid.deinit();

    // TODO: Parse JSON constraints and compile
    // For now, return a placeholder IR

    const ir_ffi = gpa.create(ConstraintIRFFI) catch {
        return @intFromEnum(AnankeError.AllocationFailure);
    };

    const name_buf = gpa.allocSentinel(u8, 32, 0) catch {
        gpa.destroy(ir_ffi);
        return @intFromEnum(AnankeError.AllocationFailure);
    };

    _ = std.fmt.bufPrint(name_buf, "compiled_ir", .{}) catch "compiled";

    ir_ffi.* = .{
        .json_schema = null,
        .grammar = null,
        .regex_patterns = null,
        .regex_patterns_len = 0,
        .token_masks = null,
        .priority = 100,
        .name = name_buf.ptr,
    };

    out_ir.* = ir_ffi;
    return @intFromEnum(AnankeError.Success);
}

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
