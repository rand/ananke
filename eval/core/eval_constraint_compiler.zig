// Eval Constraint Compiler (Proper Braid Integration)
// Converts eval task constraint JSON format to llguidance-compatible JSON
// using the full Braid compilation pipeline.
//
// The eval framework uses a rich constraint format:
// {
//   "task_id": "...",
//   "constraints": {
//     "grammar": "TypeScript/Python signature...",
//     "regex_pattern": "^export\\s+function...",
//     "type_constraints": { "parameters": [...], "return_type": "..." },
//     "naming_constraints": { "function_name": "...", "variable_patterns": [...] },
//     "structural_constraints": { "must_use": [...], "must_not_use": [...] },
//     "behavior_constraints": { "required_features": [...], "edge_cases": [...] },
//     "complexity_constraints": { "time_complexity": "...", "space_complexity": "..." }
//   }
// }
//
// This module:
// 1. Parses the eval constraint JSON
// 2. Converts each constraint section to Braid's Constraint type
// 3. Calls Braid.compile() to produce ConstraintIR
// 4. Uses Braid.toLLGuidanceSchema() to produce llguidance JSON

const std = @import("std");
const Allocator = std.mem.Allocator;

// Import Braid and constraint types from the main Ananke library
const root = @import("ananke");
const Braid = root.braid.Braid;
const Constraint = root.types.constraint.Constraint;
const ConstraintKind = root.types.constraint.ConstraintKind;
const ConstraintSource = root.types.constraint.ConstraintSource;
const ConstraintPriority = root.types.constraint.ConstraintPriority;
const EnforcementType = root.types.constraint.EnforcementType;
const Severity = root.types.constraint.Severity;
const ConstraintIR = root.types.constraint.ConstraintIR;

/// Compiled constraint result for sending to Modal
pub const CompiledConstraint = struct {
    /// llguidance-compatible JSON string
    llguidance_json: []const u8,
    /// Type of constraint used (for debugging/metrics)
    constraint_type: ConstraintType,
    /// Original regex pattern if used
    regex_pattern: ?[]const u8,
    /// Original grammar string if used
    grammar_signature: ?[]const u8,
    /// Number of Braid constraints compiled
    constraint_count: usize,

    pub fn deinit(self: *CompiledConstraint, allocator: Allocator) void {
        allocator.free(self.llguidance_json);
        if (self.regex_pattern) |p| allocator.free(p);
        if (self.grammar_signature) |g| allocator.free(g);
    }
};

pub const ConstraintType = enum {
    braid_full, // Full Braid compilation with all constraint types
    regex,
    json_schema,
    grammar,
    prompt_only,

    pub fn toString(self: ConstraintType) []const u8 {
        return switch (self) {
            .braid_full => "braid_full",
            .regex => "regex",
            .json_schema => "json_schema",
            .grammar => "grammar",
            .prompt_only => "prompt_only",
        };
    }
};

/// Eval constraint compiler using proper Braid integration
pub const EvalConstraintCompiler = struct {
    allocator: Allocator,
    braid: Braid,
    next_constraint_id: u64,

    pub fn init(allocator: Allocator) !EvalConstraintCompiler {
        return .{
            .allocator = allocator,
            .braid = try Braid.init(allocator),
            .next_constraint_id = 1,
        };
    }

    pub fn deinit(self: *EvalConstraintCompiler) void {
        self.braid.deinit();
    }

    /// Compile eval constraint JSON to llguidance-compatible format
    /// using the full Braid pipeline
    pub fn compile(self: *EvalConstraintCompiler, constraint_json: []const u8) !CompiledConstraint {
        // Parse the JSON
        const parsed = try std.json.parseFromSlice(
            std.json.Value,
            self.allocator,
            constraint_json,
            .{},
        );
        defer parsed.deinit();

        const root_obj = parsed.value.object;

        // Get the constraints object (handle both nested and flat formats)
        const constraints_obj = if (root_obj.get("constraints")) |c|
            switch (c) {
                .object => |o| o,
                else => root_obj,
            }
        else
            root_obj;

        // Extract fields
        const regex_pattern = self.getStringField(constraints_obj, "regex_pattern");
        const grammar_str = self.getStringField(constraints_obj, "grammar");

        // Convert eval constraints to Braid Constraint array
        var braid_constraints = std.ArrayList(Constraint){};
        defer braid_constraints.deinit(self.allocator);

        // 1. Extract type_constraints → type_safety Constraints
        if (constraints_obj.get("type_constraints")) |tc| {
            if (tc == .object) {
                try self.extractTypeConstraints(&braid_constraints, tc.object);
            }
        }

        // 2. Extract naming_constraints → syntactic Constraints
        if (constraints_obj.get("naming_constraints")) |nc| {
            if (nc == .object) {
                try self.extractNamingConstraints(&braid_constraints, nc.object);
            }
        }

        // 3. Extract structural_constraints → syntactic/security Constraints
        if (constraints_obj.get("structural_constraints")) |sc| {
            if (sc == .object) {
                try self.extractStructuralConstraints(&braid_constraints, sc.object);
            }
        }

        // 4. Extract behavior_constraints → semantic Constraints
        if (constraints_obj.get("behavior_constraints")) |bc| {
            if (bc == .object) {
                try self.extractBehaviorConstraints(&braid_constraints, bc.object);
            }
        }

        // 5. Extract complexity_constraints → operational Constraints
        if (constraints_obj.get("complexity_constraints")) |cc| {
            if (cc == .object) {
                try self.extractComplexityConstraints(&braid_constraints, cc.object);
            }
        }

        // Count total rich constraints extracted
        const constraint_count = braid_constraints.items.len;

        // If we have regex_pattern, add it as a constraint for Braid to include
        if (regex_pattern) |pattern| {
            try braid_constraints.append(self.allocator, Constraint{
                .id = self.nextId(),
                .name = "regex_prefix",
                .description = try std.fmt.allocPrint(
                    self.allocator,
                    "Code must match regex: {s}",
                    .{pattern},
                ),
                .kind = .syntactic,
                .source = .User_Defined,
                .enforcement = .Syntactic,
                .priority = .Critical,
                .severity = .err,
            });
        }

        // If we have rich constraints, use full Braid pipeline
        if (braid_constraints.items.len > 0) {
            return self.compileWithBraid(braid_constraints.items, regex_pattern, grammar_str);
        }

        // Fallback: check if grammar is a valid JSON schema
        if (grammar_str) |grammar| {
            if (self.isValidJsonSchema(grammar)) {
                return self.compileJsonSchemaWithCount(grammar, constraint_count);
            }
            // Grammar is a TypeScript/Python signature - use for prompt only
            return self.compilePromptOnlyWithCount(grammar, constraint_count);
        }

        // No usable constraints
        return self.compilePromptOnlyWithCount(null, constraint_count);
    }

    /// Compile using Braid's full pipeline
    fn compileWithBraid(
        self: *EvalConstraintCompiler,
        constraints: []const Constraint,
        regex_pattern: ?[]const u8,
        grammar_sig: ?[]const u8,
    ) !CompiledConstraint {
        // Use Braid to compile constraints to ConstraintIR
        var ir = try self.braid.compile(constraints);
        defer ir.deinit(self.allocator);

        // Convert ConstraintIR to llguidance JSON
        const llguidance_json = try self.braid.toLLGuidanceSchema(ir);

        return CompiledConstraint{
            .llguidance_json = llguidance_json,
            .constraint_type = .braid_full,
            .regex_pattern = if (regex_pattern) |p| try self.allocator.dupe(u8, p) else null,
            .grammar_signature = if (grammar_sig) |g| try self.allocator.dupe(u8, g) else null,
            .constraint_count = constraints.len,
        };
    }

    /// Extract type_constraints to Braid Constraints
    fn extractTypeConstraints(
        self: *EvalConstraintCompiler,
        constraints: *std.ArrayList(Constraint),
        type_obj: std.json.ObjectMap,
    ) !void {
        // Parameters
        if (type_obj.get("parameters")) |params| {
            if (params == .array) {
                for (params.array.items) |param| {
                    if (param == .object) {
                        const name = self.getStringField(param.object, "name") orelse "unknown";
                        const param_type = self.getStringField(param.object, "type") orelse "any";
                        const required = if (param.object.get("required")) |r|
                            (r == .bool and r.bool)
                        else
                            false;

                        const desc = try std.fmt.allocPrint(
                            self.allocator,
                            "Parameter '{s}' must be of type {s}{s}",
                            .{ name, param_type, if (required) " (required)" else "" },
                        );

                        try constraints.append(self.allocator, Constraint{
                            .id = self.nextId(),
                            .name = try std.fmt.allocPrint(self.allocator, "param_{s}_type", .{name}),
                            .description = desc,
                            .kind = .type_safety,
                            .source = .User_Defined,
                            .enforcement = .Structural,
                            .priority = if (required) .High else .Medium,
                            .severity = if (required) .err else .warning,
                        });
                    }
                }
            }
        }

        // Return type
        if (self.getStringField(type_obj, "return_type")) |ret_type| {
            try constraints.append(self.allocator, Constraint{
                .id = self.nextId(),
                .name = "return_type",
                .description = try std.fmt.allocPrint(
                    self.allocator,
                    "Function must return type: {s}",
                    .{ret_type},
                ),
                .kind = .type_safety,
                .source = .User_Defined,
                .enforcement = .Structural,
                .priority = .High,
                .severity = .err,
            });
        }
    }

    /// Extract naming_constraints to Braid Constraints
    fn extractNamingConstraints(
        self: *EvalConstraintCompiler,
        constraints: *std.ArrayList(Constraint),
        naming_obj: std.json.ObjectMap,
    ) !void {
        // Function name
        if (self.getStringField(naming_obj, "function_name")) |func_name| {
            try constraints.append(self.allocator, Constraint{
                .id = self.nextId(),
                .name = "function_name",
                .description = try std.fmt.allocPrint(
                    self.allocator,
                    "Function must be named '{s}'",
                    .{func_name},
                ),
                .kind = .syntactic,
                .source = .User_Defined,
                .enforcement = .Syntactic,
                .priority = .Critical,
                .severity = .err,
            });
        }

        // Variable patterns
        if (naming_obj.get("variable_patterns")) |patterns| {
            if (patterns == .array) {
                for (patterns.array.items) |pattern| {
                    if (pattern == .string) {
                        try constraints.append(self.allocator, Constraint{
                            .id = self.nextId(),
                            .name = try std.fmt.allocPrint(self.allocator, "var_pattern_{s}", .{pattern.string}),
                            .description = try std.fmt.allocPrint(
                                self.allocator,
                                "Code should use variable naming pattern: {s}",
                                .{pattern.string},
                            ),
                            .kind = .syntactic,
                            .source = .User_Defined,
                            .enforcement = .Syntactic,
                            .priority = .Low,
                            .severity = .hint,
                        });
                    }
                }
            }
        }
    }

    /// Extract structural_constraints to Braid Constraints
    fn extractStructuralConstraints(
        self: *EvalConstraintCompiler,
        constraints: *std.ArrayList(Constraint),
        struct_obj: std.json.ObjectMap,
    ) !void {
        // must_use patterns
        if (struct_obj.get("must_use")) |must_use| {
            if (must_use == .array) {
                for (must_use.array.items) |pattern| {
                    if (pattern == .string) {
                        try constraints.append(self.allocator, Constraint{
                            .id = self.nextId(),
                            .name = "must_use_pattern",
                            .description = try std.fmt.allocPrint(
                                self.allocator,
                                "Code must use: {s}",
                                .{pattern.string},
                            ),
                            .kind = .syntactic,
                            .source = .User_Defined,
                            .enforcement = .Syntactic,
                            .priority = .High,
                            .severity = .err,
                        });
                    }
                }
            }
        }

        // must_not_use patterns (security constraints)
        if (struct_obj.get("must_not_use")) |must_not_use| {
            if (must_not_use == .array) {
                for (must_not_use.array.items) |pattern| {
                    if (pattern == .string) {
                        try constraints.append(self.allocator, Constraint{
                            .id = self.nextId(),
                            .name = "must_not_use_pattern",
                            .description = try std.fmt.allocPrint(
                                self.allocator,
                                "Code must NOT use: {s}",
                                .{pattern.string},
                            ),
                            .kind = .security,
                            .source = .User_Defined,
                            .enforcement = .Security,
                            .priority = .Critical,
                            .severity = .err,
                        });
                    }
                }
            }
        }

        // recommended_patterns
        if (struct_obj.get("recommended_patterns")) |recommended| {
            if (recommended == .array) {
                for (recommended.array.items) |pattern| {
                    if (pattern == .string) {
                        try constraints.append(self.allocator, Constraint{
                            .id = self.nextId(),
                            .name = "recommended_pattern",
                            .description = try std.fmt.allocPrint(
                                self.allocator,
                                "Recommended pattern: {s}",
                                .{pattern.string},
                            ),
                            .kind = .syntactic,
                            .source = .User_Defined,
                            .enforcement = .Syntactic,
                            .priority = .Low,
                            .severity = .hint,
                        });
                    }
                }
            }
        }
    }

    /// Extract behavior_constraints to Braid Constraints
    fn extractBehaviorConstraints(
        self: *EvalConstraintCompiler,
        constraints: *std.ArrayList(Constraint),
        behavior_obj: std.json.ObjectMap,
    ) !void {
        // required_features
        if (behavior_obj.get("required_features")) |features| {
            if (features == .array) {
                for (features.array.items) |feature| {
                    if (feature == .string) {
                        try constraints.append(self.allocator, Constraint{
                            .id = self.nextId(),
                            .name = "required_feature",
                            .description = try std.fmt.allocPrint(
                                self.allocator,
                                "Must implement: {s}",
                                .{feature.string},
                            ),
                            .kind = .semantic,
                            .source = .User_Defined,
                            .enforcement = .Semantic,
                            .priority = .High,
                            .severity = .err,
                        });
                    }
                }
            }
        }

        // edge_cases
        if (behavior_obj.get("edge_cases")) |edge_cases| {
            if (edge_cases == .array) {
                for (edge_cases.array.items) |edge_case| {
                    if (edge_case == .string) {
                        try constraints.append(self.allocator, Constraint{
                            .id = self.nextId(),
                            .name = "edge_case_handling",
                            .description = try std.fmt.allocPrint(
                                self.allocator,
                                "Must handle edge case: {s}",
                                .{edge_case.string},
                            ),
                            .kind = .semantic,
                            .source = .User_Defined,
                            .enforcement = .Semantic,
                            .priority = .Medium,
                            .severity = .warning,
                        });
                    }
                }
            }
        }
    }

    /// Extract complexity_constraints to Braid Constraints
    fn extractComplexityConstraints(
        self: *EvalConstraintCompiler,
        constraints: *std.ArrayList(Constraint),
        complexity_obj: std.json.ObjectMap,
    ) !void {
        // time_complexity
        if (self.getStringField(complexity_obj, "time_complexity")) |time_comp| {
            try constraints.append(self.allocator, Constraint{
                .id = self.nextId(),
                .name = "time_complexity",
                .description = try std.fmt.allocPrint(
                    self.allocator,
                    "Time complexity must be: {s}",
                    .{time_comp},
                ),
                .kind = .operational,
                .source = .User_Defined,
                .enforcement = .Performance,
                .priority = .Medium,
                .severity = .warning,
            });
        }

        // space_complexity
        if (self.getStringField(complexity_obj, "space_complexity")) |space_comp| {
            try constraints.append(self.allocator, Constraint{
                .id = self.nextId(),
                .name = "space_complexity",
                .description = try std.fmt.allocPrint(
                    self.allocator,
                    "Space complexity must be: {s}",
                    .{space_comp},
                ),
                .kind = .operational,
                .source = .User_Defined,
                .enforcement = .Performance,
                .priority = .Low,
                .severity = .info,
            });
        }
    }

    fn nextId(self: *EvalConstraintCompiler) u64 {
        const id = self.next_constraint_id;
        self.next_constraint_id += 1;
        return id;
    }

    fn getStringField(self: *EvalConstraintCompiler, obj: std.json.ObjectMap, key: []const u8) ?[]const u8 {
        _ = self;
        if (obj.get(key)) |v| {
            if (v == .string) {
                return v.string;
            }
        }
        return null;
    }

    fn compileRegex(self: *EvalConstraintCompiler, pattern: []const u8, grammar_sig: ?[]const u8) !CompiledConstraint {
        // Build llguidance JSON with regex constraint
        // Append [\s\S]* to allow any content after the prefix (dotall-like behavior)
        var json_buf = std.ArrayList(u8){};
        errdefer json_buf.deinit(self.allocator);

        const writer = json_buf.writer(self.allocator);
        try writer.writeAll("{");
        try writer.writeAll("\"type\":\"guidance\",");
        try writer.writeAll("\"version\":\"1.0\",");
        try writer.writeAll("\"regex\":");

        // Write the prefix pattern + suffix to allow continuation
        try writer.writeByte('"');
        for (pattern) |c| {
            switch (c) {
                '"' => try writer.writeAll("\\\""),
                '\\' => try writer.writeAll("\\\\"),
                '\n' => try writer.writeAll("\\n"),
                '\r' => try writer.writeAll("\\r"),
                '\t' => try writer.writeAll("\\t"),
                else => try writer.writeByte(c),
            }
        }
        // Append suffix to allow any continuation after the prefix
        try writer.writeAll("[\\\\s\\\\S]*");
        try writer.writeByte('"');
        try writer.writeAll("}");

        return CompiledConstraint{
            .llguidance_json = try json_buf.toOwnedSlice(self.allocator),
            .constraint_type = .regex,
            .regex_pattern = try self.allocator.dupe(u8, pattern),
            .grammar_signature = if (grammar_sig) |g| try self.allocator.dupe(u8, g) else null,
            .constraint_count = 1,
        };
    }

    fn compileJsonSchema(self: *EvalConstraintCompiler, schema_str: []const u8) !CompiledConstraint {
        // Build llguidance JSON with json_schema constraint
        var json_buf = std.ArrayList(u8){};
        errdefer json_buf.deinit(self.allocator);

        const writer = json_buf.writer(self.allocator);
        try writer.writeAll("{");
        try writer.writeAll("\"type\":\"guidance\",");
        try writer.writeAll("\"version\":\"1.0\",");
        try writer.writeAll("\"json_schema\":");
        try writer.writeAll(schema_str); // Already valid JSON
        try writer.writeAll("}");

        return CompiledConstraint{
            .llguidance_json = try json_buf.toOwnedSlice(self.allocator),
            .constraint_type = .json_schema,
            .regex_pattern = null,
            .grammar_signature = null,
            .constraint_count = 1,
        };
    }

    fn compilePromptOnly(self: *EvalConstraintCompiler, grammar_sig: ?[]const u8) !CompiledConstraint {
        return self.compilePromptOnlyWithCount(grammar_sig, 0);
    }

    // WithCount variants that include extracted constraint count

    fn compileRegexWithCount(self: *EvalConstraintCompiler, pattern: []const u8, grammar_sig: ?[]const u8, constraint_count: usize) !CompiledConstraint {
        // Build llguidance JSON with regex constraint
        // Append [\s\S]* to allow any content after the prefix (dotall-like behavior)
        var json_buf = std.ArrayList(u8){};
        errdefer json_buf.deinit(self.allocator);

        const writer = json_buf.writer(self.allocator);
        try writer.writeAll("{");
        try writer.writeAll("\"type\":\"guidance\",");
        try writer.writeAll("\"version\":\"1.0\",");
        try writer.writeAll("\"regex\":");

        // Write the prefix pattern + suffix to allow continuation
        try writer.writeByte('"');
        for (pattern) |c| {
            switch (c) {
                '"' => try writer.writeAll("\\\""),
                '\\' => try writer.writeAll("\\\\"),
                '\n' => try writer.writeAll("\\n"),
                '\r' => try writer.writeAll("\\r"),
                '\t' => try writer.writeAll("\\t"),
                else => try writer.writeByte(c),
            }
        }
        // Append suffix to allow any continuation after the prefix
        try writer.writeAll("[\\\\s\\\\S]*");
        try writer.writeByte('"');
        try writer.writeAll("}");

        // Use the greater of: extracted constraint count or 1 (for the regex itself)
        const final_count = if (constraint_count > 0) constraint_count else 1;

        return CompiledConstraint{
            .llguidance_json = try json_buf.toOwnedSlice(self.allocator),
            .constraint_type = .regex,
            .regex_pattern = try self.allocator.dupe(u8, pattern),
            .grammar_signature = if (grammar_sig) |g| try self.allocator.dupe(u8, g) else null,
            .constraint_count = final_count,
        };
    }

    fn compileJsonSchemaWithCount(self: *EvalConstraintCompiler, schema_str: []const u8, constraint_count: usize) !CompiledConstraint {
        // Build llguidance JSON with json_schema constraint
        var json_buf = std.ArrayList(u8){};
        errdefer json_buf.deinit(self.allocator);

        const writer = json_buf.writer(self.allocator);
        try writer.writeAll("{");
        try writer.writeAll("\"type\":\"guidance\",");
        try writer.writeAll("\"version\":\"1.0\",");
        try writer.writeAll("\"json_schema\":");
        try writer.writeAll(schema_str); // Already valid JSON
        try writer.writeAll("}");

        const final_count = if (constraint_count > 0) constraint_count else 1;

        return CompiledConstraint{
            .llguidance_json = try json_buf.toOwnedSlice(self.allocator),
            .constraint_type = .json_schema,
            .regex_pattern = null,
            .grammar_signature = null,
            .constraint_count = final_count,
        };
    }

    fn compilePromptOnlyWithCount(self: *EvalConstraintCompiler, grammar_sig: ?[]const u8, constraint_count: usize) !CompiledConstraint {
        // No machine-enforceable constraint, just pass through for prompt engineering
        var json_buf = std.ArrayList(u8){};
        errdefer json_buf.deinit(self.allocator);

        const writer = json_buf.writer(self.allocator);
        try writer.writeAll("{");
        try writer.writeAll("\"type\":\"guidance\",");
        try writer.writeAll("\"version\":\"1.0\",");
        try writer.writeAll("\"constraint_mode\":\"prompt_only\"");
        if (grammar_sig) |g| {
            try writer.writeAll(",\"signature\":");
            try self.writeJsonString(writer, g);
        }
        try writer.writeAll("}");

        return CompiledConstraint{
            .llguidance_json = try json_buf.toOwnedSlice(self.allocator),
            .constraint_type = .prompt_only,
            .regex_pattern = null,
            .grammar_signature = if (grammar_sig) |g| try self.allocator.dupe(u8, g) else null,
            .constraint_count = constraint_count, // Use actual extracted count
        };
    }

    fn isValidJsonSchema(self: *EvalConstraintCompiler, str: []const u8) bool {
        _ = self;
        // Quick check: valid JSON schemas start with { and contain "type"
        const trimmed = std.mem.trim(u8, str, " \t\n\r");
        if (trimmed.len == 0) return false;
        if (trimmed[0] != '{') return false;

        // Try to parse as JSON
        const parsed = std.json.parseFromSlice(
            std.json.Value,
            std.heap.page_allocator, // Temp allocator for validation
            str,
            .{},
        ) catch return false;
        defer parsed.deinit();

        // Check if it looks like a JSON schema
        const obj = switch (parsed.value) {
            .object => |o| o,
            else => return false,
        };

        // JSON schemas typically have "type" or "$schema" or "properties"
        return obj.contains("type") or obj.contains("$schema") or obj.contains("properties");
    }

    fn writeJsonString(self: *EvalConstraintCompiler, writer: anytype, s: []const u8) !void {
        _ = self;
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

/// Build constraints JSON for sending to Modal
/// Converts raw eval constraint file to a format the inference service can use directly
pub fn compileForModal(allocator: Allocator, raw_constraint_json: []const u8) ![]const u8 {
    var compiler = try EvalConstraintCompiler.init(allocator);
    defer compiler.deinit();

    var compiled = try compiler.compile(raw_constraint_json);
    defer {
        if (compiled.regex_pattern) |p| allocator.free(p);
        if (compiled.grammar_signature) |g| allocator.free(g);
    }

    // Build the final constraints object for Modal
    // Format: {"grammar": "...", "regex_pattern": "...", "llguidance": {...}, "constraint_type": "...", "constraint_count": N}
    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    const writer = result.writer(allocator);
    try writer.writeAll("{");

    // Include the compiled llguidance JSON
    try writer.writeAll("\"llguidance\":");
    try writer.writeAll(compiled.llguidance_json);

    // Include constraint type for debugging
    try writer.print(",\"constraint_type\":\"{s}\"", .{compiled.constraint_type.toString()});

    // Include constraint count
    try writer.print(",\"constraint_count\":{d}", .{compiled.constraint_count});

    // Include original values for prompt construction
    if (compiled.grammar_signature) |g| {
        try writer.writeAll(",\"grammar\":");
        var temp_compiler = try EvalConstraintCompiler.init(allocator);
        defer temp_compiler.deinit();
        try temp_compiler.writeJsonString(writer, g);
    }

    if (compiled.regex_pattern) |p| {
        try writer.writeAll(",\"regex_pattern\":");
        var temp_compiler = try EvalConstraintCompiler.init(allocator);
        defer temp_compiler.deinit();
        try temp_compiler.writeJsonString(writer, p);
    }

    try writer.writeAll("}");

    // Free the llguidance_json from compiled (we've copied it to result)
    allocator.free(compiled.llguidance_json);

    return try result.toOwnedSlice(allocator);
}

test "compile regex constraint" {
    const allocator = std.testing.allocator;
    const input =
        \\{
        \\  "task_id": "test_001",
        \\  "constraints": {
        \\    "grammar": "function add(a: number, b: number): number",
        \\    "regex_pattern": "^function\\s+add"
        \\  }
        \\}
    ;

    var compiler = try EvalConstraintCompiler.init(allocator);
    defer compiler.deinit();
    var result = try compiler.compile(input);
    defer result.deinit(allocator);

    // With proper Braid integration, regex constraints go through Braid.compile()
    try std.testing.expectEqual(ConstraintType.braid_full, result.constraint_type);
    try std.testing.expect(result.regex_pattern != null);
}

test "compile json schema constraint" {
    const allocator = std.testing.allocator;
    const input =
        \\{
        \\  "task_id": "test_002",
        \\  "constraints": {
        \\    "grammar": "{\"type\": \"object\", \"properties\": {\"name\": {\"type\": \"string\"}}}"
        \\  }
        \\}
    ;

    var compiler = try EvalConstraintCompiler.init(allocator);
    defer compiler.deinit();
    var result = try compiler.compile(input);
    defer result.deinit(allocator);

    try std.testing.expectEqual(ConstraintType.json_schema, result.constraint_type);
}

test "compile prompt only constraint" {
    const allocator = std.testing.allocator;
    const input =
        \\{
        \\  "task_id": "test_003",
        \\  "constraints": {
        \\    "grammar": "function parseConfig(content: string): Record<string, any>"
        \\  }
        \\}
    ;

    var compiler = try EvalConstraintCompiler.init(allocator);
    defer compiler.deinit();
    var result = try compiler.compile(input);
    defer result.deinit(allocator);

    try std.testing.expectEqual(ConstraintType.prompt_only, result.constraint_type);
    try std.testing.expect(result.grammar_signature != null);
}

test "compile full constraint set with Braid" {
    const allocator = std.testing.allocator;
    const input =
        \\{
        \\  "task_id": "test_full",
        \\  "constraints": {
        \\    "grammar": "function add(a: number, b: number): number",
        \\    "type_constraints": {
        \\      "parameters": [
        \\        {"name": "a", "type": "number", "required": true},
        \\        {"name": "b", "type": "number", "required": true}
        \\      ],
        \\      "return_type": "number"
        \\    },
        \\    "naming_constraints": {
        \\      "function_name": "add"
        \\    },
        \\    "structural_constraints": {
        \\      "must_use": ["return a + b"],
        \\      "must_not_use": ["eval", "new Function"]
        \\    },
        \\    "behavior_constraints": {
        \\      "required_features": ["Addition of two numbers"],
        \\      "edge_cases": ["Negative numbers", "Zero"]
        \\    }
        \\  }
        \\}
    ;

    var compiler = try EvalConstraintCompiler.init(allocator);
    defer compiler.deinit();
    var result = try compiler.compile(input);
    defer result.deinit(allocator);

    // Should use full Braid compilation
    try std.testing.expectEqual(ConstraintType.braid_full, result.constraint_type);
    // Should have multiple constraints compiled
    try std.testing.expect(result.constraint_count > 5);
}
