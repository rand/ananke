// Ananke: Constraint-driven code generation system
// Root module that exports all submodules

const std = @import("std");
const testing = std.testing;

// Re-export core modules
pub const clew = @import("clew");
pub const braid = @import("braid");
pub const ariadne = @import("ariadne");

// Re-export API modules
pub const api = struct {
    pub const http = @import("http");
    pub const claude = @import("claude");
};

// Re-export types
pub const types = struct {
    pub const constraint = @import("types/constraint.zig");
    pub const intent = @import("types/intent.zig");
};

// Re-export utility modules
pub const utils = struct {
    pub const ring_queue = @import("utils/ring_queue.zig");
    pub const RingQueue = ring_queue.RingQueue;
    pub const StringInterner = @import("utils/string_interner.zig").StringInterner;
};

// Re-export commonly used types at top level for convenience
pub const Constraint = types.constraint.Constraint;
pub const ConstraintID = types.constraint.ConstraintID;
pub const ConstraintIR = types.constraint.ConstraintIR;
pub const ConstraintSet = types.constraint.ConstraintSet;
pub const ConstraintKind = types.constraint.ConstraintKind;
pub const ConstraintSource = types.constraint.ConstraintSource;
pub const EnforcementType = types.constraint.EnforcementType;
pub const ConstraintPriority = types.constraint.ConstraintPriority;

// Main Ananke API
pub const Ananke = struct {
    allocator: std.mem.Allocator,
    clew_engine: clew.Clew,
    braid_engine: braid.Braid,
    ariadne_compiler: ?ariadne.AriadneCompiler = null,

    pub fn init(allocator: std.mem.Allocator) !Ananke {
        return .{
            .allocator = allocator,
            .clew_engine = try clew.Clew.init(allocator),
            .braid_engine = try braid.Braid.init(allocator),
            .ariadne_compiler = try ariadne.AriadneCompiler.init(allocator),
        };
    }

    pub fn deinit(self: *Ananke) void {
        self.clew_engine.deinit();
        self.braid_engine.deinit();
        if (self.ariadne_compiler) |*compiler| {
            compiler.deinit();
        }
    }

    /// Extract constraints from source code
    pub fn extract(
        self: *Ananke,
        source: []const u8,
        language: []const u8,
    ) !types.constraint.ConstraintSet {
        return try self.clew_engine.extractFromCode(source, language);
    }

    /// Compile constraints to IR
    pub fn compile(
        self: *Ananke,
        constraints: []const types.constraint.Constraint,
    ) !types.constraint.ConstraintIR {
        return try self.braid_engine.compile(constraints);
    }

    /// Compile Ariadne DSL to constraints
    pub fn compileAriadne(
        self: *Ananke,
        source: []const u8,
    ) !types.constraint.ConstraintIR {
        if (self.ariadne_compiler) |*compiler| {
            return try compiler.compile(source);
        }
        return error.AriadneNotAvailable;
    }
};

test "basic Ananke initialization" {
    var ananke = try Ananke.init(testing.allocator);
    defer ananke.deinit();

    // Just verify that the engines are initialized
    // Note: Allocators cannot be directly compared in Zig 0.15.x
    _ = ananke.clew_engine.allocator;
    _ = ananke.braid_engine.allocator;
}
