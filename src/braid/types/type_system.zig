//! Cross-language Type System for Type Inhabitation
//!
//! This module provides a unified type representation that can express types
//! from all 9 Ananke-supported languages: TypeScript, JavaScript, Python, Rust,
//! Go, Java, C++, C#, and Kotlin.
//!
//! The type system is used by the inhabitation graph to determine which tokens
//! can lead to expressions of a target type.

const std = @import("std");

/// Supported programming languages
pub const Language = enum {
    typescript,
    javascript,
    python,
    rust,
    go,
    java,
    cpp,
    csharp,
    kotlin,
    zig_lang,

    /// Get language-specific type syntax
    pub fn getTypeSyntax(self: Language) TypeSyntax {
        return switch (self) {
            .typescript, .javascript => .{
                .array_prefix = null,
                .array_suffix = "[]",
                .generic_open = "<",
                .generic_close = ">",
                .function_arrow = " => ",
                .nullable_suffix = " | null",
                .optional_suffix = "?",
            },
            .python => .{
                .array_prefix = "List[",
                .array_suffix = "]",
                .generic_open = "[",
                .generic_close = "]",
                .function_arrow = null, // Callable[[args], ret]
                .nullable_suffix = " | None",
                .optional_suffix = null,
            },
            .rust => .{
                .array_prefix = "Vec<",
                .array_suffix = ">",
                .generic_open = "<",
                .generic_close = ">",
                .function_arrow = " -> ",
                .nullable_suffix = null, // Option<T>
                .optional_suffix = null,
            },
            .go => .{
                .array_prefix = "[]",
                .array_suffix = null,
                .generic_open = "[",
                .generic_close = "]",
                .function_arrow = " ",
                .nullable_suffix = null, // Pointers
                .optional_suffix = null,
            },
            .java => .{
                .array_prefix = null,
                .array_suffix = "[]",
                .generic_open = "<",
                .generic_close = ">",
                .function_arrow = null, // Function<T, R>
                .nullable_suffix = null, // @Nullable
                .optional_suffix = null,
            },
            .cpp => .{
                .array_prefix = "std::vector<",
                .array_suffix = ">",
                .generic_open = "<",
                .generic_close = ">",
                .function_arrow = null, // std::function
                .nullable_suffix = null, // std::optional
                .optional_suffix = null,
            },
            .csharp => .{
                .array_prefix = null,
                .array_suffix = "[]",
                .generic_open = "<",
                .generic_close = ">",
                .function_arrow = null, // Func<T, R>
                .nullable_suffix = "?",
                .optional_suffix = "?",
            },
            .kotlin => .{
                .array_prefix = "List<",
                .array_suffix = ">",
                .generic_open = "<",
                .generic_close = ">",
                .function_arrow = " -> ",
                .nullable_suffix = "?",
                .optional_suffix = "?",
            },
            .zig_lang => .{
                .array_prefix = "[]",
                .array_suffix = null,
                .generic_open = "(",
                .generic_close = ")",
                .function_arrow = null,
                .nullable_suffix = null, // ?T
                .optional_suffix = null,
            },
        };
    }
};

/// Language-specific type syntax configuration
pub const TypeSyntax = struct {
    array_prefix: ?[]const u8,
    array_suffix: ?[]const u8,
    generic_open: []const u8,
    generic_close: []const u8,
    function_arrow: ?[]const u8,
    nullable_suffix: ?[]const u8,
    optional_suffix: ?[]const u8,
};

/// Primitive types common across languages
pub const PrimitiveKind = enum {
    void_type,
    boolean,
    i8,
    i16,
    i32,
    i64,
    u8,
    u16,
    u32,
    u64,
    f32,
    f64,
    number, // JS/TS number (f64)
    string,
    char,
    null_type,
    undefined,
    any,
    unknown,
    never,

    /// Check if this primitive is numeric
    pub fn isNumeric(self: PrimitiveKind) bool {
        return switch (self) {
            .i8, .i16, .i32, .i64, .u8, .u16, .u32, .u64, .f32, .f64, .number => true,
            else => false,
        };
    }

    /// Check if this primitive is integral
    pub fn isIntegral(self: PrimitiveKind) bool {
        return switch (self) {
            .i8, .i16, .i32, .i64, .u8, .u16, .u32, .u64 => true,
            else => false,
        };
    }

    /// Get the canonical name for this primitive in a given language
    pub fn canonicalName(self: PrimitiveKind, lang: Language) []const u8 {
        return switch (self) {
            .void_type => switch (lang) {
                .typescript, .javascript => "void",
                .python => "None",
                .rust => "()",
                .go => "",
                .java => "void",
                .cpp => "void",
                .csharp => "void",
                .kotlin => "Unit",
                .zig_lang => "void",
            },
            .boolean => switch (lang) {
                .typescript, .javascript => "boolean",
                .python => "bool",
                .rust => "bool",
                .go => "bool",
                .java => "boolean",
                .cpp => "bool",
                .csharp => "bool",
                .kotlin => "Boolean",
                .zig_lang => "bool",
            },
            .string => switch (lang) {
                .typescript, .javascript => "string",
                .python => "str",
                .rust => "String",
                .go => "string",
                .java => "String",
                .cpp => "std::string",
                .csharp => "string",
                .kotlin => "String",
                .zig_lang => "[]const u8",
            },
            .number => switch (lang) {
                .typescript, .javascript => "number",
                .python => "float",
                .rust => "f64",
                .go => "float64",
                .java => "double",
                .cpp => "double",
                .csharp => "double",
                .kotlin => "Double",
                .zig_lang => "f64",
            },
            .i32 => switch (lang) {
                .typescript, .javascript => "number",
                .python => "int",
                .rust => "i32",
                .go => "int32",
                .java => "int",
                .cpp => "int32_t",
                .csharp => "int",
                .kotlin => "Int",
                .zig_lang => "i32",
            },
            .i64 => switch (lang) {
                .typescript, .javascript => "number",
                .python => "int",
                .rust => "i64",
                .go => "int64",
                .java => "long",
                .cpp => "int64_t",
                .csharp => "long",
                .kotlin => "Long",
                .zig_lang => "i64",
            },
            .f32 => switch (lang) {
                .typescript, .javascript => "number",
                .python => "float",
                .rust => "f32",
                .go => "float32",
                .java => "float",
                .cpp => "float",
                .csharp => "float",
                .kotlin => "Float",
                .zig_lang => "f32",
            },
            .f64 => switch (lang) {
                .typescript, .javascript => "number",
                .python => "float",
                .rust => "f64",
                .go => "float64",
                .java => "double",
                .cpp => "double",
                .csharp => "double",
                .kotlin => "Double",
                .zig_lang => "f64",
            },
            .null_type => switch (lang) {
                .typescript, .javascript => "null",
                .python => "None",
                .rust => "()",
                .go => "nil",
                .java => "null",
                .cpp => "nullptr",
                .csharp => "null",
                .kotlin => "null",
                .zig_lang => "null",
            },
            .any => switch (lang) {
                .typescript, .javascript => "any",
                .python => "Any",
                .rust => "dyn Any",
                .go => "interface{}",
                .java => "Object",
                .cpp => "std::any",
                .csharp => "object",
                .kotlin => "Any",
                .zig_lang => "anytype",
            },
            else => "unknown",
        };
    }
};

/// Object type with named fields
pub const ObjectType = struct {
    fields: []const Field,
    is_class: bool = false,
    is_interface: bool = false,

    pub const Field = struct {
        name: []const u8,
        field_type: *const Type,
        is_optional: bool = false,
        is_readonly: bool = false,
    };
};

/// Function type
pub const FunctionType = struct {
    params: []const Param,
    return_type: *const Type,
    is_async: bool = false,
    is_generator: bool = false,

    pub const Param = struct {
        name: ?[]const u8,
        param_type: *const Type,
        is_optional: bool = false,
        is_rest: bool = false,
    };
};

/// Unified type representation across all languages
pub const Type = union(enum) {
    // Primitives
    primitive: PrimitiveKind,

    // Compound types
    array: *const Type,
    tuple: []const *const Type,
    object: ObjectType,
    function: FunctionType,

    // Type combinators
    union_type: []const *const Type,
    intersection: []const *const Type,
    optional: *const Type, // T? or Option<T>

    // Named types (for language-specific types)
    named: struct {
        name: []const u8,
        language: ?Language,
    },

    // Generic types
    generic: struct {
        base: *const Type,
        params: []const *const Type,
    },

    // Reference/pointer types
    reference: struct {
        pointee: *const Type,
        is_mutable: bool,
    },

    // Error types (Rust Result, Zig error union)
    error_union: struct {
        ok_type: *const Type,
        err_type: ?*const Type,
    },

    /// Check if this type is assignable to target type in the given language
    pub fn isAssignableTo(self: *const Type, target: *const Type, lang: Language) bool {
        // Same type
        if (self.eql(target)) return true;

        // Any accepts everything
        if (target.* == .primitive and target.primitive == .any) return true;

        // Check specific type coercions
        return switch (self.*) {
            .primitive => |p| self.checkPrimitiveAssignable(p, target, lang),
            .array => |elem| self.checkArrayAssignable(elem, target, lang),
            .optional => |inner| self.checkOptionalAssignable(inner, target, lang),
            .union_type => |members| {
                // All union members must be assignable
                for (members) |member| {
                    if (!member.isAssignableTo(target, lang)) return false;
                }
                return true;
            },
            else => false,
        };
    }

    fn checkPrimitiveAssignable(self: *const Type, p: PrimitiveKind, target: *const Type, lang: Language) bool {
        _ = self;
        return switch (target.*) {
            .primitive => |tp| {
                // Same primitive
                if (p == tp) return true;

                // Numeric coercions
                if (p.isNumeric() and tp.isNumeric()) {
                    return switch (lang) {
                        // JavaScript/TypeScript: all numbers coerce
                        .typescript, .javascript => true,
                        // Python: int -> float
                        .python => p.isIntegral() and tp == .f64,
                        // Most languages: no implicit coercion
                        else => false,
                    };
                }

                // null -> undefined in JS/TS
                if (lang == .typescript or lang == .javascript) {
                    if ((p == .null_type and tp == .undefined) or
                        (p == .undefined and tp == .null_type))
                    {
                        return true;
                    }
                }

                return false;
            },
            .optional => true, // Primitives can be wrapped in optional
            else => false,
        };
    }

    fn checkArrayAssignable(self: *const Type, elem: *const Type, target: *const Type, lang: Language) bool {
        _ = self;
        return switch (target.*) {
            .array => |target_elem| elem.isAssignableTo(target_elem, lang),
            else => false,
        };
    }

    fn checkOptionalAssignable(self: *const Type, inner: *const Type, target: *const Type, lang: Language) bool {
        _ = self;
        return switch (target.*) {
            .optional => |target_inner| inner.isAssignableTo(target_inner, lang),
            else => inner.isAssignableTo(target, lang),
        };
    }

    /// Compute a hash for this type
    pub fn hash(self: *const Type) u64 {
        var hasher = std.hash.Wyhash.init(0);
        self.hashInto(&hasher);
        return hasher.final();
    }

    fn hashInto(self: *const Type, hasher: *std.hash.Wyhash) void {
        const tag = @intFromEnum(self.*);
        hasher.update(std.mem.asBytes(&tag));

        switch (self.*) {
            .primitive => |p| {
                const p_tag = @intFromEnum(p);
                hasher.update(std.mem.asBytes(&p_tag));
            },
            .array => |elem| elem.hashInto(hasher),
            .tuple => |elems| {
                for (elems) |elem| elem.hashInto(hasher);
            },
            .named => |n| hasher.update(n.name),
            .optional => |inner| inner.hashInto(hasher),
            .union_type => |members| {
                for (members) |m| m.hashInto(hasher);
            },
            .generic => |g| {
                g.base.hashInto(hasher);
                for (g.params) |p| p.hashInto(hasher);
            },
            else => {},
        }
    }

    /// Check equality with another type
    pub fn eql(self: *const Type, other: *const Type) bool {
        if (@intFromEnum(self.*) != @intFromEnum(other.*)) return false;

        return switch (self.*) {
            .primitive => |p| other.primitive == p,
            .array => |elem| elem.eql(other.array),
            .tuple => |elems| {
                if (elems.len != other.tuple.len) return false;
                for (elems, other.tuple) |a, b| {
                    if (!a.eql(b)) return false;
                }
                return true;
            },
            .named => |n| std.mem.eql(u8, n.name, other.named.name),
            .optional => |inner| inner.eql(other.optional),
            .union_type => |members| {
                if (members.len != other.union_type.len) return false;
                for (members, other.union_type) |a, b| {
                    if (!a.eql(b)) return false;
                }
                return true;
            },
            else => false,
        };
    }

    /// Check if this type contains a specific named type
    pub fn containsNamed(self: *const Type, name: []const u8) bool {
        return switch (self.*) {
            .named => |n| std.mem.eql(u8, n.name, name),
            .array => |elem| elem.containsNamed(name),
            .tuple => |elems| {
                for (elems) |elem| {
                    if (elem.containsNamed(name)) return true;
                }
                return false;
            },
            .optional => |inner| inner.containsNamed(name),
            .union_type => |members| {
                for (members) |m| {
                    if (m.containsNamed(name)) return true;
                }
                return false;
            },
            .generic => |g| {
                if (g.base.containsNamed(name)) return true;
                for (g.params) |p| {
                    if (p.containsNamed(name)) return true;
                }
                return false;
            },
            else => false,
        };
    }
};

/// Arena-based type allocator for efficient type construction
pub const TypeArena = struct {
    arena: std.heap.ArenaAllocator,

    pub fn init(backing_allocator: std.mem.Allocator) TypeArena {
        return .{
            .arena = std.heap.ArenaAllocator.init(backing_allocator),
        };
    }

    pub fn deinit(self: *TypeArena) void {
        self.arena.deinit();
    }

    pub fn allocator(self: *TypeArena) std.mem.Allocator {
        return self.arena.allocator();
    }

    /// Create a primitive type
    pub fn primitive(self: *TypeArena, kind: PrimitiveKind) !*Type {
        const t = try self.arena.allocator().create(Type);
        t.* = .{ .primitive = kind };
        return t;
    }

    /// Create an array type
    pub fn array(self: *TypeArena, elem: *const Type) !*Type {
        const t = try self.arena.allocator().create(Type);
        t.* = .{ .array = elem };
        return t;
    }

    /// Create an optional type
    pub fn optional(self: *TypeArena, inner: *const Type) !*Type {
        const t = try self.arena.allocator().create(Type);
        t.* = .{ .optional = inner };
        return t;
    }

    /// Create a named type
    pub fn named(self: *TypeArena, name: []const u8, lang: ?Language) !*Type {
        const t = try self.arena.allocator().create(Type);
        const name_copy = try self.arena.allocator().dupe(u8, name);
        t.* = .{ .named = .{ .name = name_copy, .language = lang } };
        return t;
    }

    /// Create a union type
    pub fn unionType(self: *TypeArena, members: []const *const Type) !*Type {
        const t = try self.arena.allocator().create(Type);
        const members_copy = try self.arena.allocator().dupe(*const Type, members);
        t.* = .{ .union_type = members_copy };
        return t;
    }

    /// Create a function type
    pub fn function(
        self: *TypeArena,
        params: []const FunctionType.Param,
        return_type: *const Type,
    ) !*Type {
        const t = try self.arena.allocator().create(Type);
        const params_copy = try self.arena.allocator().dupe(FunctionType.Param, params);
        t.* = .{ .function = .{
            .params = params_copy,
            .return_type = return_type,
        } };
        return t;
    }

    /// Create a generic type
    pub fn generic(self: *TypeArena, base: *const Type, params: []const *const Type) !*Type {
        const t = try self.arena.allocator().create(Type);
        const params_copy = try self.arena.allocator().dupe(*const Type, params);
        t.* = .{ .generic = .{
            .base = base,
            .params = params_copy,
        } };
        return t;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "PrimitiveKind.isNumeric" {
    try std.testing.expect(PrimitiveKind.i32.isNumeric());
    try std.testing.expect(PrimitiveKind.f64.isNumeric());
    try std.testing.expect(PrimitiveKind.number.isNumeric());
    try std.testing.expect(!PrimitiveKind.string.isNumeric());
    try std.testing.expect(!PrimitiveKind.boolean.isNumeric());
}

test "PrimitiveKind.canonicalName" {
    try std.testing.expectEqualStrings("string", PrimitiveKind.string.canonicalName(.typescript));
    try std.testing.expectEqualStrings("str", PrimitiveKind.string.canonicalName(.python));
    try std.testing.expectEqualStrings("String", PrimitiveKind.string.canonicalName(.rust));
}

test "Type.hash and eql" {
    var arena = TypeArena.init(std.testing.allocator);
    defer arena.deinit();

    const int_type = try arena.primitive(.i32);
    const int_type2 = try arena.primitive(.i32);
    const str_type = try arena.primitive(.string);

    // Same type should have same hash
    try std.testing.expectEqual(int_type.hash(), int_type2.hash());

    // Different types should have different hash (usually)
    try std.testing.expect(int_type.hash() != str_type.hash());

    // Equality
    try std.testing.expect(int_type.eql(int_type2));
    try std.testing.expect(!int_type.eql(str_type));
}

test "Type.isAssignableTo - primitives" {
    var arena = TypeArena.init(std.testing.allocator);
    defer arena.deinit();

    const int_type = try arena.primitive(.i32);
    const num_type = try arena.primitive(.number);
    const any_type = try arena.primitive(.any);

    // Same type
    try std.testing.expect(int_type.isAssignableTo(int_type, .typescript));

    // Any accepts everything
    try std.testing.expect(int_type.isAssignableTo(any_type, .typescript));

    // JS/TS numeric coercion
    try std.testing.expect(int_type.isAssignableTo(num_type, .typescript));
}

test "TypeArena allocation" {
    var arena = TypeArena.init(std.testing.allocator);
    defer arena.deinit();

    const str_type = try arena.primitive(.string);
    const arr_type = try arena.array(str_type);
    const opt_type = try arena.optional(str_type);

    try std.testing.expect(arr_type.array == str_type);
    try std.testing.expect(opt_type.optional == str_type);
}
