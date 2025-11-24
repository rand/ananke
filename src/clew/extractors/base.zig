// Base extractor interface and common types
const std = @import("std");

const root = @import("ananke");
const Constraint = root.types.constraint.Constraint;
const ConstraintKind = root.types.constraint.ConstraintKind;

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
