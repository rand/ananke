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
const TypeInhabitationData = root.types.constraint.TypeInhabitationData;
const TypeBinding = root.types.constraint.TypeBinding;
const TypeLanguage = root.types.constraint.TypeLanguage;

pub const HoleCompiler = struct {
    allocator: std.mem.Allocator,

    /// Default language for type parsing
    default_language: TypeLanguage = .typescript,

    pub fn init(allocator: std.mem.Allocator) HoleCompiler {
        return .{ .allocator = allocator };
    }

    /// Set the default language for type parsing
    pub fn setLanguage(self: *HoleCompiler, language: TypeLanguage) void {
        self.default_language = language;
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

        // If any hole has type information, build type inhabitation
        for (holes.holes.items) |hole| {
            if (hole.expected_type != null) {
                ir.type_inhabitation = try self.buildTypeInhabitationForHole(&hole);
                break;
            }
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

        // Add type-based fill constraints
        if (hole.expected_type) |expected| {
            var fill_constraints = std.ArrayList(FillConstraint){};
            defer fill_constraints.deinit(self.allocator);

            try fill_constraints.append(self.allocator, .{
                .kind = .must_have_type,
                .value = expected,
                .error_message = "Expression must have the expected type",
            });

            spec.fill_constraints = try fill_constraints.toOwnedSlice(self.allocator);
        }

        // Generate grammar for syntactic constraints
        spec.fill_grammar = try self.generateGrammar(hole);

        // Generate grammar reference for llguidance cross-hole constraints
        spec.grammar_ref = try self.generateGrammarRef(hole);

        return spec;
    }

    fn buildTypeInhabitationForHole(self: *HoleCompiler, hole: *const Hole) !?TypeInhabitationData {
        const expected = hole.expected_type orelse return null;

        var bindings = std.ArrayList(TypeBinding){};
        defer bindings.deinit(self.allocator);

        // Extract bindings from hole's available_bindings
        for (hole.available_bindings) |binding| {
            try bindings.append(self.allocator, .{
                .name = binding.name,
                .type_sig = binding.type_annotation orelse "unknown",
            });
        }

        return TypeInhabitationData{
            .goal_type = expected,
            .bindings = try bindings.toOwnedSlice(self.allocator),
            .language = self.default_language,
        };
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
