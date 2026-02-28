// Base extractor interface and common types
const std = @import("std");

const root = @import("ananke");
const Constraint = root.types.constraint.Constraint;
const ConstraintKind = root.types.constraint.ConstraintKind;
const RichContext = root.types.constraint.RichContext;

/// Represents a function/method declaration
pub const FunctionDecl = struct {
    name: []const u8,
    line: u32,
    is_async: bool = false,
    is_public: bool = false,
    return_type: ?[]const u8 = null,
    params: []Parameter = &.{},
    has_error_handling: bool = false,

    pub const Parameter = struct {
        name: []const u8,
        type_annotation: ?[]const u8 = null,
    };
};

/// Represents a type definition (struct, class, interface, etc.)
pub const TypeDecl = struct {
    name: []const u8,
    line: u32,
    kind: TypeKind,
    fields: []Field = &.{},
    methods: []FunctionDecl = &.{},

    pub const TypeKind = enum {
        struct_type,
        class_type,
        interface_type,
        enum_type,
        union_type,
    };

    pub const Field = struct {
        name: []const u8,
        type_annotation: ?[]const u8 = null,
        is_public: bool = true,
    };
};

/// Import/module declaration
pub const ImportDecl = struct {
    module: []const u8,
    line: u32,
    is_wildcard: bool = false,
    items: [][]const u8 = &.{},
};

/// Abstract syntax structure
pub const SyntaxStructure = struct {
    allocator: std.mem.Allocator,
    functions: std.ArrayList(FunctionDecl),
    types: std.ArrayList(TypeDecl),
    imports: std.ArrayList(ImportDecl),

    pub fn init(allocator: std.mem.Allocator) SyntaxStructure {
        return .{
            .allocator = allocator,
            .functions = std.ArrayList(FunctionDecl){},
            .types = std.ArrayList(TypeDecl){},
            .imports = std.ArrayList(ImportDecl){},
        };
    }

    pub fn deinit(self: *SyntaxStructure) void {
        // Free function declarations
        for (self.functions.items) |func| {
            self.allocator.free(func.name);
            if (func.return_type) |ret_type| {
                self.allocator.free(ret_type);
            }
            for (func.params) |param| {
                self.allocator.free(param.name);
                if (param.type_annotation) |type_ann| {
                    self.allocator.free(type_ann);
                }
            }
            self.allocator.free(func.params);
        }

        // Free type declarations
        for (self.types.items) |type_decl| {
            self.allocator.free(type_decl.name);
            for (type_decl.fields) |field| {
                self.allocator.free(field.name);
                if (field.type_annotation) |type_ann| {
                    self.allocator.free(type_ann);
                }
            }
            self.allocator.free(type_decl.fields);
            for (type_decl.methods) |method| {
                self.allocator.free(method.name);
                if (method.return_type) |ret_type| {
                    self.allocator.free(ret_type);
                }
                for (method.params) |param| {
                    self.allocator.free(param.name);
                    if (param.type_annotation) |type_ann| {
                        self.allocator.free(type_ann);
                    }
                }
                self.allocator.free(method.params);
            }
            self.allocator.free(type_decl.methods);
        }

        // Free import declarations
        for (self.imports.items) |import_decl| {
            self.allocator.free(import_decl.module);
            for (import_decl.items) |item| {
                self.allocator.free(item);
            }
            self.allocator.free(import_decl.items);
        }

        self.functions.deinit(self.allocator);
        self.types.deinit(self.allocator);
        self.imports.deinit(self.allocator);
    }

    /// Serialize syntax structure to RichContext JSON for sglang ConstraintSpec.
    /// Field names match ConstraintSpec.from_dict() exactly.
    pub fn toRichContext(self: *const SyntaxStructure, allocator: std.mem.Allocator) !RichContext {
        var ctx = RichContext{};
        errdefer ctx.deinit(allocator);

        // Serialize function signatures
        if (self.functions.items.len > 0) {
            ctx.function_signatures_json = try serializeFunctions(allocator, self.functions.items);
        }

        // Serialize type bindings (non-class types: structs, enums, unions, interfaces)
        // and class definitions separately
        var type_bindings_count: usize = 0;
        var class_count: usize = 0;
        for (self.types.items) |td| {
            if (td.kind == .class_type) {
                class_count += 1;
            } else {
                type_bindings_count += 1;
            }
        }

        if (type_bindings_count > 0) {
            ctx.type_bindings_json = try serializeTypeBindings(allocator, self.types.items);
        }
        if (class_count > 0) {
            ctx.class_definitions_json = try serializeClassDefinitions(allocator, self.types.items);
        }

        // Serialize imports
        if (self.imports.items.len > 0) {
            ctx.imports_json = try serializeImports(allocator, self.imports.items);
        }

        // Derive control flow context from function declarations
        if (self.functions.items.len > 0) {
            ctx.control_flow_json = try serializeControlFlow(allocator, self.functions.items, self.types.items);
        }

        // Derive semantic constraints from type signatures (morphism: Types → Semantics)
        ctx.semantic_constraints_json = try deriveSemanticConstraints(allocator, self.functions.items, self.types.items);

        return ctx;
    }

    /// Convert syntax structure to constraints
    pub fn toConstraints(self: *const SyntaxStructure, constraint_allocator: std.mem.Allocator) ![]Constraint {
        var constraints = std.ArrayList(Constraint){};
        errdefer constraints.deinit(constraint_allocator);

        // Function-related constraints
        if (self.functions.items.len > 0) {
            var async_count: u32 = 0;
            var typed_count: u32 = 0;
            var error_handling_count: u32 = 0;

            for (self.functions.items) |func| {
                if (func.is_async) async_count += 1;
                if (func.return_type != null) typed_count += 1;
                if (func.has_error_handling) error_handling_count += 1;
            }

            // Summary constraint for functions
            const func_desc = try std.fmt.allocPrint(
                constraint_allocator,
                "Code contains {d} function definitions ({d} async, {d} typed)",
                .{ self.functions.items.len, async_count, typed_count },
            );
            try constraints.append(constraint_allocator, Constraint{
                .kind = .syntactic,
                .severity = .info,
                .name = "function_structure",
                .description = func_desc,
                .source = .AST_Pattern,
                .frequency = @intCast(self.functions.items.len),
            });

            // Type safety constraint
            if (typed_count > 0) {
                const typed_ratio = @as(f32, @floatFromInt(typed_count)) / @as(f32, @floatFromInt(self.functions.items.len));
                if (typed_ratio > 0.5) {
                    const type_desc = try std.fmt.allocPrint(
                        constraint_allocator,
                        "Strong type safety: {d}% of functions have return type annotations",
                        .{@as(u32, @intFromFloat(typed_ratio * 100))},
                    );
                    try constraints.append(constraint_allocator, Constraint{
                        .kind = .type_safety,
                        .severity = .info,
                        .name = "typed_functions",
                        .description = type_desc,
                        .source = .Type_System,
                        .confidence = typed_ratio,
                        .frequency = typed_count,
                    });
                }
            }

            // Error handling constraint
            if (error_handling_count > 0) {
                const error_desc = try std.fmt.allocPrint(
                    constraint_allocator,
                    "Explicit error handling in {d} functions",
                    .{error_handling_count},
                );
                try constraints.append(constraint_allocator, Constraint{
                    .kind = .semantic,
                    .severity = .info,
                    .name = "error_handling",
                    .description = error_desc,
                    .source = .Control_Flow,
                    .frequency = error_handling_count,
                });
            }

            // Async pattern constraint
            if (async_count > 0) {
                const async_desc = try std.fmt.allocPrint(
                    constraint_allocator,
                    "Asynchronous execution in {d} functions",
                    .{async_count},
                );
                try constraints.append(constraint_allocator, Constraint{
                    .kind = .semantic,
                    .severity = .info,
                    .name = "async_functions",
                    .description = async_desc,
                    .source = .Control_Flow,
                    .frequency = async_count,
                });
            }
        }

        // Type definition constraints
        if (self.types.items.len > 0) {
            const type_desc = try std.fmt.allocPrint(
                constraint_allocator,
                "Code defines {d} custom types",
                .{self.types.items.len},
            );
            try constraints.append(constraint_allocator, Constraint{
                .kind = .type_safety,
                .severity = .info,
                .name = "type_definitions",
                .description = type_desc,
                .source = .Type_System,
                .frequency = @intCast(self.types.items.len),
            });
        }

        // Import/module constraints
        if (self.imports.items.len > 0) {
            const import_desc = try std.fmt.allocPrint(
                constraint_allocator,
                "Modular design with {d} imports",
                .{self.imports.items.len},
            );
            try constraints.append(constraint_allocator, Constraint{
                .kind = .architectural,
                .severity = .info,
                .name = "modularity",
                .description = import_desc,
                .source = .AST_Pattern,
                .frequency = @intCast(self.imports.items.len),
            });
        }

        return try constraints.toOwnedSlice(constraint_allocator);
    }
};

/// Base extractor interface
pub const Extractor = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Extractor {
        return .{ .allocator = allocator };
    }

    /// Parse source code into syntax structure
    pub fn parse(self: *Extractor, source: []const u8, language: []const u8) !SyntaxStructure {
        _ = self;
        _ = source;
        _ = language;
        @panic("parse() must be implemented by language-specific extractor");
    }
};

// JSON serialization helpers for RichContext.
// Output format matches sglang ConstraintSpec.from_dict() field schemas.

fn serializeFunctions(allocator: std.mem.Allocator, functions: []const FunctionDecl) ![]const u8 {
    var buf: std.io.Writer.Allocating = .init(allocator);
    defer buf.deinit();
    var s: std.json.Stringify = .{ .writer = &buf.writer };

    try s.beginArray();
    for (functions) |func| {
        try s.beginObject();
        try s.objectField("name");
        try s.write(func.name);
        try s.objectField("is_async");
        try s.write(func.is_async);
        try s.objectField("is_public");
        try s.write(func.is_public);
        if (func.return_type) |rt| {
            try s.objectField("return_type");
            try s.write(rt);
        }
        if (func.params.len > 0) {
            try s.objectField("params");
            try s.beginArray();
            for (func.params) |param| {
                try s.beginObject();
                try s.objectField("name");
                try s.write(param.name);
                if (param.type_annotation) |ta| {
                    try s.objectField("type");
                    try s.write(ta);
                }
                try s.endObject();
            }
            try s.endArray();
        }
        try s.objectField("has_error_handling");
        try s.write(func.has_error_handling);
        try s.endObject();
    }
    try s.endArray();
    return try buf.toOwnedSlice();
}

fn serializeTypeBindings(allocator: std.mem.Allocator, types: []const TypeDecl) ![]const u8 {
    var buf: std.io.Writer.Allocating = .init(allocator);
    defer buf.deinit();
    var s: std.json.Stringify = .{ .writer = &buf.writer };

    try s.beginArray();
    for (types) |td| {
        if (td.kind == .class_type) continue; // classes go to class_definitions
        try s.beginObject();
        try s.objectField("name");
        try s.write(td.name);
        try s.objectField("kind");
        try s.write(@tagName(td.kind));
        if (td.fields.len > 0) {
            try s.objectField("fields");
            try s.beginArray();
            for (td.fields) |field| {
                try s.beginObject();
                try s.objectField("name");
                try s.write(field.name);
                if (field.type_annotation) |ta| {
                    try s.objectField("type");
                    try s.write(ta);
                }
                try s.objectField("is_public");
                try s.write(field.is_public);
                try s.endObject();
            }
            try s.endArray();
        }
        try s.endObject();
    }
    try s.endArray();
    return try buf.toOwnedSlice();
}

fn serializeClassDefinitions(allocator: std.mem.Allocator, types: []const TypeDecl) ![]const u8 {
    var buf: std.io.Writer.Allocating = .init(allocator);
    defer buf.deinit();
    var s: std.json.Stringify = .{ .writer = &buf.writer };

    try s.beginArray();
    for (types) |td| {
        if (td.kind != .class_type) continue;
        try s.beginObject();
        try s.objectField("name");
        try s.write(td.name);
        if (td.fields.len > 0) {
            try s.objectField("fields");
            try s.beginArray();
            for (td.fields) |field| {
                try s.beginObject();
                try s.objectField("name");
                try s.write(field.name);
                if (field.type_annotation) |ta| {
                    try s.objectField("type");
                    try s.write(ta);
                }
                try s.objectField("is_public");
                try s.write(field.is_public);
                try s.endObject();
            }
            try s.endArray();
        }
        if (td.methods.len > 0) {
            try s.objectField("methods");
            try s.beginArray();
            for (td.methods) |method| {
                try s.beginObject();
                try s.objectField("name");
                try s.write(method.name);
                if (method.return_type) |rt| {
                    try s.objectField("return_type");
                    try s.write(rt);
                }
                if (method.params.len > 0) {
                    try s.objectField("params");
                    try s.beginArray();
                    for (method.params) |param| {
                        try s.beginObject();
                        try s.objectField("name");
                        try s.write(param.name);
                        if (param.type_annotation) |ta| {
                            try s.objectField("type");
                            try s.write(ta);
                        }
                        try s.endObject();
                    }
                    try s.endArray();
                }
                try s.endObject();
            }
            try s.endArray();
        }
        try s.endObject();
    }
    try s.endArray();
    return try buf.toOwnedSlice();
}

/// Derive control flow context from function declarations.
/// This is a soft-tier constraint (ControlFlow domain in CLaSH).
fn serializeControlFlow(
    allocator: std.mem.Allocator,
    functions: []const FunctionDecl,
    types: []const TypeDecl,
) ![]const u8 {
    var buf: std.io.Writer.Allocating = .init(allocator);
    defer buf.deinit();
    var s: std.json.Stringify = .{ .writer = &buf.writer };

    var async_count: u32 = 0;
    var error_handling_count: u32 = 0;

    for (functions) |func| {
        if (func.is_async) async_count += 1;
        if (func.has_error_handling) error_handling_count += 1;
    }

    try s.beginObject();
    try s.objectField("async_function_count");
    try s.write(async_count);
    try s.objectField("error_handling_count");
    try s.write(error_handling_count);
    try s.objectField("total_functions");
    try s.write(@as(u32, @intCast(functions.len)));

    // Detect error handling style from type signatures
    // Morphism: Types → ControlFlow
    var has_result_types = false;
    var has_option_types = false;
    for (functions) |func| {
        if (func.return_type) |rt| {
            if (std.mem.indexOf(u8, rt, "Result") != null or
                std.mem.indexOf(u8, rt, "!") != null)
                has_result_types = true;
            if (std.mem.indexOf(u8, rt, "Option") != null or
                std.mem.indexOf(u8, rt, "?") != null)
                has_option_types = true;
        }
    }
    for (types) |td| {
        if (std.mem.indexOf(u8, td.name, "Error") != null or
            std.mem.indexOf(u8, td.name, "Result") != null)
            has_result_types = true;
    }

    try s.objectField("has_result_types");
    try s.write(has_result_types);
    try s.objectField("has_option_types");
    try s.write(has_option_types);

    // Infer error handling style
    try s.objectField("error_handling_style");
    if (has_result_types and error_handling_count > 0) {
        try s.write("result_based");
    } else if (error_handling_count > 0) {
        try s.write("exception_based");
    } else {
        try s.write("none");
    }

    try s.endObject();
    return try buf.toOwnedSlice();
}

/// Derive semantic constraints from type signatures and declarations.
/// This implements cross-domain morphisms:
///   Types → Semantics: Result<T,E> ⟹ expect error handling
///   Types → Semantics: fn sort(v: &mut Vec<T>) where T: Ord ⟹ expect ordering
fn deriveSemanticConstraints(
    allocator: std.mem.Allocator,
    functions: []const FunctionDecl,
    types: []const TypeDecl,
) !?[]const u8 {
    var buf: std.io.Writer.Allocating = .init(allocator);
    defer buf.deinit();
    var s: std.json.Stringify = .{ .writer = &buf.writer };

    var has_constraints = false;
    try s.beginArray();

    // Derive from function signatures (morphism: Types → Semantics)
    for (functions) |func| {
        if (func.return_type) |rt| {
            // Result types imply error handling obligation
            if (std.mem.indexOf(u8, rt, "Result") != null or
                std.mem.indexOf(u8, rt, "!") != null)
            {
                try s.beginObject();
                try s.objectField("kind");
                try s.write("error_handling_required");
                try s.objectField("function");
                try s.write(func.name);
                try s.objectField("return_type");
                try s.write(rt);
                try s.objectField("tier");
                try s.write("soft");
                try s.endObject();
                has_constraints = true;
            }
            // Mutable reference params imply side effects
        }

        // Async functions imply await usage
        if (func.is_async) {
            try s.beginObject();
            try s.objectField("kind");
            try s.write("async_pattern");
            try s.objectField("function");
            try s.write(func.name);
            try s.objectField("tier");
            try s.write("soft");
            try s.endObject();
            has_constraints = true;
        }
    }

    // Derive from type definitions
    for (types) |td| {
        // Error types imply they should be used in error handling
        if (std.mem.indexOf(u8, td.name, "Error") != null) {
            try s.beginObject();
            try s.objectField("kind");
            try s.write("error_type_defined");
            try s.objectField("type_name");
            try s.write(td.name);
            try s.objectField("tier");
            try s.write("soft");
            try s.endObject();
            has_constraints = true;
        }
    }

    try s.endArray();

    if (!has_constraints) return null;
    return try buf.toOwnedSlice();
}

fn serializeImports(allocator: std.mem.Allocator, imports: []const ImportDecl) ![]const u8 {
    var buf: std.io.Writer.Allocating = .init(allocator);
    defer buf.deinit();
    var s: std.json.Stringify = .{ .writer = &buf.writer };

    try s.beginArray();
    for (imports) |imp| {
        try s.beginObject();
        try s.objectField("module");
        try s.write(imp.module);
        try s.objectField("is_wildcard");
        try s.write(imp.is_wildcard);
        if (imp.items.len > 0) {
            try s.objectField("items");
            try s.beginArray();
            for (imp.items) |item| {
                try s.write(item);
            }
            try s.endArray();
        }
        try s.endObject();
    }
    try s.endArray();
    return try buf.toOwnedSlice();
}
