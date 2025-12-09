// Hole compilation to constraint IR
const std = @import("std");
const root = @import("ananke");
const Hole = root.types.hole.Hole;
const HoleSet = root.types.hole.HoleSet;
const HoleScale = root.types.hole.HoleScale;
const HoleSpec = root.types.constraint.HoleSpec;
const ConstraintIR = root.types.constraint.ConstraintIR;
const JsonSchema = root.types.constraint.JsonSchema;
const Grammar = root.types.constraint.Grammar;
const GrammarRule = root.types.constraint.GrammarRule;
const FillConstraint = root.types.constraint.FillConstraint;

pub const HoleCompiler = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) HoleCompiler {
        return .{ .allocator = allocator };
    }

    /// Compile holes to ConstraintIR with HoleSpecs
    pub fn compile(self: *HoleCompiler, holes: *const HoleSet) !ConstraintIR {
        var ir = ConstraintIR{};

        var hole_specs = std.ArrayList(HoleSpec){};
        defer hole_specs.deinit(self.allocator);

        for (holes.holes.items) |hole| {
            const spec = try self.compileHole(&hole);
            try hole_specs.append(self.allocator, spec);
        }

        ir.hole_specs = try hole_specs.toOwnedSlice(self.allocator);
        ir.supports_refinement = true;

        return ir;
    }

    fn compileHole(self: *HoleCompiler, hole: *const Hole) !HoleSpec {
        var spec = HoleSpec{
            .hole_id = hole.id,
        };

        // Generate JSON Schema from expected type
        if (hole.expected_type) |expected| {
            spec.fill_schema = try self.typeToJsonSchema(expected);
        }

        // Generate grammar for syntactic constraints
        spec.fill_grammar = try self.generateGrammar(hole);

        // Generate grammar reference for llguidance cross-hole constraints
        spec.grammar_ref = try self.generateGrammarRef(hole);

        return spec;
    }

    fn typeToJsonSchema(self: *HoleCompiler, type_str: []const u8) !JsonSchema {
        // Map type strings to JSON Schema
        _ = self;

        if (std.mem.eql(u8, type_str, "string") or std.mem.eql(u8, type_str, "str")) {
            return .{
                .type = "string",
            };
        } else if (std.mem.eql(u8, type_str, "int") or std.mem.eql(u8, type_str, "number")) {
            return .{
                .type = "integer",
            };
        } else if (std.mem.eql(u8, type_str, "bool") or std.mem.eql(u8, type_str, "boolean")) {
            return .{
                .type = "boolean",
            };
        } else if (std.mem.startsWith(u8, type_str, "list") or std.mem.startsWith(u8, type_str, "array")) {
            return .{
                .type = "array",
            };
        }

        // Default: object for complex types
        return .{
            .type = "object",
        };
    }

    fn generateGrammar(self: *HoleCompiler, hole: *const Hole) !?Grammar {
        // Generate CFG grammar based on hole scale and context
        _ = self;
        _ = hole;

        // For now, return null - grammar generation will be enhanced later
        return null;
    }

    fn generateGrammarRef(self: *HoleCompiler, hole: *const Hole) !?[]const u8 {
        // Generate llguidance grammar reference for cross-hole constraints
        _ = self;

        if (hole.name) |name| {
            return name;
        }

        // Generate reference based on scale
        return switch (hole.scale) {
            .expression => "@expr",
            .statement => "@stmt",
            .block => "@block",
            .function => "@function_body",
            else => null,
        };
    }
};
