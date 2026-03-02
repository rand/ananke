//! Type Parser for Multiple Languages
//!
//! Parses type signatures from string representations into the unified Type system.
//! Supports type syntax for all 9 Ananke languages.

const std = @import("std");
const type_system = @import("type_system.zig");
const Type = type_system.Type;
const TypeArena = type_system.TypeArena;
const PrimitiveKind = type_system.PrimitiveKind;
const Language = type_system.Language;
const FunctionType = type_system.FunctionType;

pub const ParseError = error{
    UnexpectedToken,
    UnexpectedEndOfInput,
    InvalidTypeSyntax,
    UnsupportedType,
    OutOfMemory,
};

/// Type parser that converts string type signatures to Type structures
pub const TypeParser = struct {
    arena: *TypeArena,
    language: Language,
    input: []const u8,
    pos: usize,

    pub fn init(arena: *TypeArena, language: Language) TypeParser {
        return .{
            .arena = arena,
            .language = language,
            .input = "",
            .pos = 0,
        };
    }

    /// Parse a type signature string
    pub fn parse(self: *TypeParser, type_sig: []const u8) ParseError!*Type {
        self.input = type_sig;
        self.pos = 0;
        self.skipWhitespace();

        if (self.input.len == 0) {
            return ParseError.UnexpectedEndOfInput;
        }

        return self.parseType();
    }

    fn parseType(self: *TypeParser) ParseError!*Type {
        const base = try self.parseBaseType();

        // Check for type modifiers
        self.skipWhitespace();
        if (self.pos >= self.input.len) return base;

        // Check for array suffix
        if (self.matchStr("[]")) {
            return self.arena.array(base) catch return ParseError.OutOfMemory;
        }

        // Check for optional/nullable suffix
        if (self.language == .typescript or self.language == .kotlin or self.language == .csharp) {
            if (self.matchChar('?')) {
                return self.arena.optional(base) catch return ParseError.OutOfMemory;
            }
        }

        // Check for union type (TypeScript: A | B | C | ..., Python: A | B)
        if (self.language == .typescript or self.language == .python) {
            if (self.matchStr(" | ") or self.matchChar('|')) {
                self.skipWhitespace();
                // Collect all union members into a flat list
                var members_buf: [16]*const Type = undefined;
                members_buf[0] = base;
                var count: usize = 1;
                members_buf[count] = try self.parseBaseType();
                count += 1;
                // Continue collecting if more | follow
                while (count < 16) {
                    self.skipWhitespace();
                    if (self.matchStr(" | ") or self.matchChar('|')) {
                        self.skipWhitespace();
                        members_buf[count] = try self.parseBaseType();
                        count += 1;
                    } else break;
                }
                return self.arena.unionType(members_buf[0..count]) catch return ParseError.OutOfMemory;
            }
        }

        return base;
    }

    fn parseBaseType(self: *TypeParser) ParseError!*Type {
        self.skipWhitespace();

        if (self.pos >= self.input.len) {
            return ParseError.UnexpectedEndOfInput;
        }

        // Try to parse primitive types first
        if (try self.tryParsePrimitive()) |prim| {
            return prim;
        }

        // Parse language-specific compound types
        return switch (self.language) {
            .typescript, .javascript => self.parseTypeScriptType(),
            .python => self.parsePythonType(),
            .rust => self.parseRustType(),
            .go => self.parseGoType(),
            .java => self.parseJavaType(),
            .cpp => self.parseCppType(),
            .csharp => self.parseCSharpType(),
            .kotlin => self.parseKotlinType(),
            .zig_lang => self.parseZigType(),
            .c => self.parseCType(),
            .ruby => self.parseRubyType(),
            .php => self.parsePhpType(),
            .swift => self.parseSwiftType(),
        };
    }

    fn tryParsePrimitive(self: *TypeParser) ParseError!?*Type {
        return switch (self.language) {
            .typescript, .javascript => self.tryParsePrimitiveList(&.{
                .{ .name = "string", .kind = .string },
                .{ .name = "number", .kind = .number },
                .{ .name = "boolean", .kind = .boolean },
                .{ .name = "void", .kind = .void_type },
                .{ .name = "null", .kind = .null_type },
                .{ .name = "undefined", .kind = .undefined },
                .{ .name = "any", .kind = .any },
                .{ .name = "unknown", .kind = .unknown },
                .{ .name = "never", .kind = .never },
            }),
            .python => self.tryParsePrimitiveList(&.{
                .{ .name = "str", .kind = .string },
                .{ .name = "int", .kind = .i64 },
                .{ .name = "float", .kind = .f64 },
                .{ .name = "bool", .kind = .boolean },
                .{ .name = "None", .kind = .null_type },
                .{ .name = "Any", .kind = .any },
            }),
            .rust => self.tryParsePrimitiveList(&.{
                .{ .name = "String", .kind = .string },
                .{ .name = "&str", .kind = .string },
                .{ .name = "i8", .kind = .i8 },
                .{ .name = "i16", .kind = .i16 },
                .{ .name = "i32", .kind = .i32 },
                .{ .name = "i64", .kind = .i64 },
                .{ .name = "u8", .kind = .u8 },
                .{ .name = "u16", .kind = .u16 },
                .{ .name = "u32", .kind = .u32 },
                .{ .name = "u64", .kind = .u64 },
                .{ .name = "f32", .kind = .f32 },
                .{ .name = "f64", .kind = .f64 },
                .{ .name = "bool", .kind = .boolean },
                .{ .name = "()", .kind = .void_type },
            }),
            .go => self.tryParsePrimitiveList(&.{
                .{ .name = "string", .kind = .string },
                .{ .name = "int", .kind = .i64 },
                .{ .name = "int32", .kind = .i32 },
                .{ .name = "int64", .kind = .i64 },
                .{ .name = "float32", .kind = .f32 },
                .{ .name = "float64", .kind = .f64 },
                .{ .name = "bool", .kind = .boolean },
                .{ .name = "byte", .kind = .u8 },
            }),
            .java => self.tryParsePrimitiveList(&.{
                .{ .name = "String", .kind = .string },
                .{ .name = "int", .kind = .i32 },
                .{ .name = "long", .kind = .i64 },
                .{ .name = "float", .kind = .f32 },
                .{ .name = "double", .kind = .f64 },
                .{ .name = "boolean", .kind = .boolean },
                .{ .name = "char", .kind = .char },
                .{ .name = "void", .kind = .void_type },
                .{ .name = "Object", .kind = .any },
            }),
            .cpp => self.tryParsePrimitiveList(&.{
                .{ .name = "std::string", .kind = .string },
                .{ .name = "int", .kind = .i32 },
                .{ .name = "long", .kind = .i64 },
                .{ .name = "float", .kind = .f32 },
                .{ .name = "double", .kind = .f64 },
                .{ .name = "bool", .kind = .boolean },
                .{ .name = "char", .kind = .char },
                .{ .name = "void", .kind = .void_type },
            }),
            .csharp => self.tryParsePrimitiveList(&.{
                .{ .name = "string", .kind = .string },
                .{ .name = "int", .kind = .i32 },
                .{ .name = "long", .kind = .i64 },
                .{ .name = "float", .kind = .f32 },
                .{ .name = "double", .kind = .f64 },
                .{ .name = "bool", .kind = .boolean },
                .{ .name = "char", .kind = .char },
                .{ .name = "void", .kind = .void_type },
                .{ .name = "object", .kind = .any },
            }),
            .kotlin => self.tryParsePrimitiveList(&.{
                .{ .name = "String", .kind = .string },
                .{ .name = "Int", .kind = .i32 },
                .{ .name = "Long", .kind = .i64 },
                .{ .name = "Float", .kind = .f32 },
                .{ .name = "Double", .kind = .f64 },
                .{ .name = "Boolean", .kind = .boolean },
                .{ .name = "Char", .kind = .char },
                .{ .name = "Unit", .kind = .void_type },
                .{ .name = "Any", .kind = .any },
            }),
            .zig_lang => self.tryParsePrimitiveList(&.{
                .{ .name = "[]const u8", .kind = .string },
                .{ .name = "i8", .kind = .i8 },
                .{ .name = "i16", .kind = .i16 },
                .{ .name = "i32", .kind = .i32 },
                .{ .name = "i64", .kind = .i64 },
                .{ .name = "u8", .kind = .u8 },
                .{ .name = "u16", .kind = .u16 },
                .{ .name = "u32", .kind = .u32 },
                .{ .name = "u64", .kind = .u64 },
                .{ .name = "f32", .kind = .f32 },
                .{ .name = "f64", .kind = .f64 },
                .{ .name = "bool", .kind = .boolean },
                .{ .name = "void", .kind = .void_type },
                .{ .name = "anytype", .kind = .any },
            }),
            .c => self.tryParsePrimitiveList(&.{
                .{ .name = "int", .kind = .i32 },
                .{ .name = "long", .kind = .i64 },
                .{ .name = "char", .kind = .char },
                .{ .name = "float", .kind = .f32 },
                .{ .name = "double", .kind = .f64 },
                .{ .name = "void", .kind = .void_type },
                .{ .name = "_Bool", .kind = .boolean },
            }),
            .ruby => self.tryParsePrimitiveList(&.{
                .{ .name = "String", .kind = .string },
                .{ .name = "Integer", .kind = .i64 },
                .{ .name = "Float", .kind = .f64 },
                .{ .name = "Symbol", .kind = .string },
                .{ .name = "NilClass", .kind = .null_type },
                .{ .name = "TrueClass", .kind = .boolean },
                .{ .name = "FalseClass", .kind = .boolean },
            }),
            .php => self.tryParsePrimitiveList(&.{
                .{ .name = "string", .kind = .string },
                .{ .name = "int", .kind = .i64 },
                .{ .name = "float", .kind = .f64 },
                .{ .name = "bool", .kind = .boolean },
                .{ .name = "void", .kind = .void_type },
                .{ .name = "null", .kind = .null_type },
                .{ .name = "mixed", .kind = .any },
            }),
            .swift => self.tryParsePrimitiveList(&.{
                .{ .name = "String", .kind = .string },
                .{ .name = "Int", .kind = .i64 },
                .{ .name = "Int32", .kind = .i32 },
                .{ .name = "Double", .kind = .f64 },
                .{ .name = "Float", .kind = .f32 },
                .{ .name = "Bool", .kind = .boolean },
                .{ .name = "Void", .kind = .void_type },
                .{ .name = "Any", .kind = .any },
                .{ .name = "Character", .kind = .char },
            }),
        };
    }

    const PrimitiveEntry = struct { name: []const u8, kind: PrimitiveKind };

    fn tryParsePrimitiveList(self: *TypeParser, primitives: []const PrimitiveEntry) ParseError!?*Type {
        for (primitives) |prim| {
            if (self.matchStr(prim.name)) {
                return self.arena.primitive(prim.kind) catch return ParseError.OutOfMemory;
            }
        }
        return null;
    }

    fn parseTypeScriptType(self: *TypeParser) ParseError!*Type {
        // Check for Array<T> syntax
        if (self.matchStr("Array<")) {
            const elem = try self.parseType();
            if (!self.matchChar('>')) return ParseError.InvalidTypeSyntax;
            return self.arena.array(elem) catch return ParseError.OutOfMemory;
        }

        // Check for Promise<T>
        if (self.matchStr("Promise<")) {
            const inner = try self.parseType();
            if (!self.matchChar('>')) return ParseError.InvalidTypeSyntax;
            const base = self.arena.named("Promise", .typescript) catch return ParseError.OutOfMemory;
            const params = [_]*const Type{inner};
            return self.arena.generic(base, &params) catch return ParseError.OutOfMemory;
        }

        // Utility types: Record<K,V>, Partial<T>, Required<T>, Readonly<T>, Pick<T,K>, Omit<T,K>
        inline for (.{ "Record", "Pick", "Omit" }) |name| {
            if (self.matchStr(name ++ "<")) {
                const first = try self.parseType();
                self.skipWhitespace();
                if (!self.matchChar(',')) return ParseError.InvalidTypeSyntax;
                self.skipWhitespace();
                const second = try self.parseType();
                if (!self.matchChar('>')) return ParseError.InvalidTypeSyntax;
                const base = self.arena.named(name, .typescript) catch return ParseError.OutOfMemory;
                const params = [_]*const Type{ first, second };
                return self.arena.generic(base, &params) catch return ParseError.OutOfMemory;
            }
        }
        inline for (.{ "Partial", "Required", "Readonly" }) |name| {
            if (self.matchStr(name ++ "<")) {
                const inner = try self.parseType();
                if (!self.matchChar('>')) return ParseError.InvalidTypeSyntax;
                const base = self.arena.named(name, .typescript) catch return ParseError.OutOfMemory;
                const params = [_]*const Type{inner};
                return self.arena.generic(base, &params) catch return ParseError.OutOfMemory;
            }
        }

        // Check for function type: (params) => return
        if (self.matchChar('(')) {
            return self.parseTypeScriptFunction();
        }

        // Otherwise, parse as named type
        return self.parseNamedType();
    }

    fn parseTypeScriptFunction(self: *TypeParser) ParseError!*Type {
        var params_list: [16]FunctionType.Param = undefined;
        var param_count: usize = 0;

        // Parse parameters until ')'
        self.skipWhitespace();
        if (!self.peekChar(')')) {
            while (true) {
                if (param_count >= 16) return ParseError.InvalidTypeSyntax;

                // Parse parameter name (optional)
                const name = self.parseIdentifier();
                self.skipWhitespace();

                // Skip ':'
                _ = self.matchChar(':');
                self.skipWhitespace();

                // Parse parameter type
                const param_type = try self.parseType();
                params_list[param_count] = .{
                    .name = name,
                    .param_type = param_type,
                };
                param_count += 1;

                self.skipWhitespace();
                if (!self.matchChar(',')) break;
                self.skipWhitespace();
            }
        }

        if (!self.matchChar(')')) return ParseError.InvalidTypeSyntax;
        self.skipWhitespace();

        // Parse arrow
        if (!self.matchStr("=>")) return ParseError.InvalidTypeSyntax;
        self.skipWhitespace();

        // Parse return type
        const return_type = try self.parseType();

        return self.arena.function(params_list[0..param_count], return_type) catch return ParseError.OutOfMemory;
    }

    fn parsePythonType(self: *TypeParser) ParseError!*Type {
        // Check for List[T]
        if (self.matchStr("List[")) {
            const elem = try self.parseType();
            if (!self.matchChar(']')) return ParseError.InvalidTypeSyntax;
            return self.arena.array(elem) catch return ParseError.OutOfMemory;
        }

        // Check for Optional[T]
        if (self.matchStr("Optional[")) {
            const inner = try self.parseType();
            if (!self.matchChar(']')) return ParseError.InvalidTypeSyntax;
            return self.arena.optional(inner) catch return ParseError.OutOfMemory;
        }

        // Check for Dict[K, V]
        if (self.matchStr("Dict[")) {
            const key = try self.parseType();
            self.skipWhitespace();
            if (!self.matchChar(',')) return ParseError.InvalidTypeSyntax;
            self.skipWhitespace();
            const value = try self.parseType();
            if (!self.matchChar(']')) return ParseError.InvalidTypeSyntax;
            const base = self.arena.named("Dict", .python) catch return ParseError.OutOfMemory;
            const params = [_]*const Type{ key, value };
            return self.arena.generic(base, &params) catch return ParseError.OutOfMemory;
        }

        // Check for Callable[[args], ret]
        if (self.matchStr("Callable[[")) {
            // Simplified: just treat as function type
            const base = self.arena.named("Callable", .python) catch return ParseError.OutOfMemory;
            return base;
        }

        return self.parseNamedType();
    }

    fn parseRustType(self: *TypeParser) ParseError!*Type {
        // Check for Vec<T>
        if (self.matchStr("Vec<")) {
            const elem = try self.parseType();
            if (!self.matchChar('>')) return ParseError.InvalidTypeSyntax;
            return self.arena.array(elem) catch return ParseError.OutOfMemory;
        }

        // Check for Option<T>
        if (self.matchStr("Option<")) {
            const inner = try self.parseType();
            if (!self.matchChar('>')) return ParseError.InvalidTypeSyntax;
            return self.arena.optional(inner) catch return ParseError.OutOfMemory;
        }

        // Check for Result<T, E>
        if (self.matchStr("Result<")) {
            const ok = try self.parseType();
            self.skipWhitespace();
            if (!self.matchChar(',')) return ParseError.InvalidTypeSyntax;
            self.skipWhitespace();
            const err = try self.parseType();
            if (!self.matchChar('>')) return ParseError.InvalidTypeSyntax;
            const t = self.arena.arena.allocator().create(Type) catch return ParseError.OutOfMemory;
            t.* = .{ .error_union = .{ .ok_type = ok, .err_type = err } };
            return t;
        }

        // Smart pointer types: Box<T>, Rc<T>, Arc<T>
        inline for (.{ "Box<", "Rc<", "Arc<" }) |prefix| {
            if (self.matchStr(prefix)) {
                const inner = try self.parseType();
                if (!self.matchChar('>')) return ParseError.InvalidTypeSyntax;
                const name = prefix[0 .. prefix.len - 1];
                const base = self.arena.named(name, .rust) catch return ParseError.OutOfMemory;
                const params = [_]*const Type{inner};
                return self.arena.generic(base, &params) catch return ParseError.OutOfMemory;
            }
        }

        // HashMap<K, V>
        if (self.matchStr("HashMap<")) {
            const key = try self.parseType();
            self.skipWhitespace();
            if (!self.matchChar(',')) return ParseError.InvalidTypeSyntax;
            self.skipWhitespace();
            const value = try self.parseType();
            if (!self.matchChar('>')) return ParseError.InvalidTypeSyntax;
            const base = self.arena.named("HashMap", .rust) catch return ParseError.OutOfMemory;
            const params = [_]*const Type{ key, value };
            return self.arena.generic(base, &params) catch return ParseError.OutOfMemory;
        }

        // dyn Trait
        if (self.matchStr("dyn ")) {
            const trait_type = try self.parseNamedType();
            const base = self.arena.named("dyn", .rust) catch return ParseError.OutOfMemory;
            const params = [_]*const Type{trait_type};
            return self.arena.generic(base, &params) catch return ParseError.OutOfMemory;
        }

        // Check for reference types
        if (self.matchChar('&')) {
            const is_mut = self.matchStr("mut ");
            const pointee = try self.parseType();
            const t = self.arena.arena.allocator().create(Type) catch return ParseError.OutOfMemory;
            t.* = .{ .reference = .{ .pointee = pointee, .is_mutable = is_mut } };
            return t;
        }

        return self.parseNamedType();
    }

    fn parseGoType(self: *TypeParser) ParseError!*Type {
        // Check for slice []T
        if (self.matchStr("[]")) {
            const elem = try self.parseType();
            return self.arena.array(elem) catch return ParseError.OutOfMemory;
        }

        // Check for map[K]V
        if (self.matchStr("map[")) {
            const key = try self.parseType();
            if (!self.matchChar(']')) return ParseError.InvalidTypeSyntax;
            const value = try self.parseType();
            const base = self.arena.named("map", .go) catch return ParseError.OutOfMemory;
            const params = [_]*const Type{ key, value };
            return self.arena.generic(base, &params) catch return ParseError.OutOfMemory;
        }

        // Check for pointer *T
        if (self.matchChar('*')) {
            const pointee = try self.parseType();
            const t = self.arena.arena.allocator().create(Type) catch return ParseError.OutOfMemory;
            t.* = .{ .reference = .{ .pointee = pointee, .is_mutable = true } };
            return t;
        }

        // Check for interface{}
        if (self.matchStr("interface{}")) {
            return self.arena.primitive(.any) catch return ParseError.OutOfMemory;
        }

        return self.parseNamedType();
    }

    fn parseJavaType(self: *TypeParser) ParseError!*Type {
        // Check for List<T>
        if (self.matchStr("List<")) {
            const elem = try self.parseJavaTypeArg();
            if (!self.matchChar('>')) return ParseError.InvalidTypeSyntax;
            return self.arena.array(elem) catch return ParseError.OutOfMemory;
        }

        // Check for Map<K, V>
        if (self.matchStr("Map<")) {
            const key = try self.parseJavaTypeArg();
            self.skipWhitespace();
            if (!self.matchChar(',')) return ParseError.InvalidTypeSyntax;
            self.skipWhitespace();
            const value = try self.parseJavaTypeArg();
            if (!self.matchChar('>')) return ParseError.InvalidTypeSyntax;
            const base = self.arena.named("Map", .java) catch return ParseError.OutOfMemory;
            const params = [_]*const Type{ key, value };
            return self.arena.generic(base, &params) catch return ParseError.OutOfMemory;
        }

        // Check for Optional<T>
        if (self.matchStr("Optional<")) {
            const inner = try self.parseJavaTypeArg();
            if (!self.matchChar('>')) return ParseError.InvalidTypeSyntax;
            return self.arena.optional(inner) catch return ParseError.OutOfMemory;
        }

        // Stream<T>, Set<T>, Queue<T>
        inline for (.{ "Stream", "Set", "Queue" }) |name| {
            if (self.matchStr(name ++ "<")) {
                const elem = try self.parseJavaTypeArg();
                if (!self.matchChar('>')) return ParseError.InvalidTypeSyntax;
                const base = self.arena.named(name, .java) catch return ParseError.OutOfMemory;
                const params = [_]*const Type{elem};
                return self.arena.generic(base, &params) catch return ParseError.OutOfMemory;
            }
        }

        return self.parseNamedType();
    }

    /// Parse a Java type argument, handling wildcards (?, ? extends T, ? super T)
    fn parseJavaTypeArg(self: *TypeParser) ParseError!*Type {
        self.skipWhitespace();
        if (self.matchChar('?')) {
            self.skipWhitespace();
            if (self.matchStr("extends ")) {
                self.skipWhitespace();
                return self.parseType();
            }
            if (self.matchStr("super ")) {
                self.skipWhitespace();
                return self.parseType();
            }
            // Unbounded wildcard: treat as any
            return self.arena.primitive(.any) catch return ParseError.OutOfMemory;
        }
        return self.parseType();
    }

    fn parseCppType(self: *TypeParser) ParseError!*Type {
        // Check for std::vector<T>
        if (self.matchStr("std::vector<")) {
            const elem = try self.parseType();
            if (!self.matchChar('>')) return ParseError.InvalidTypeSyntax;
            return self.arena.array(elem) catch return ParseError.OutOfMemory;
        }

        // Check for std::optional<T>
        if (self.matchStr("std::optional<")) {
            const inner = try self.parseType();
            if (!self.matchChar('>')) return ParseError.InvalidTypeSyntax;
            return self.arena.optional(inner) catch return ParseError.OutOfMemory;
        }

        // Check for std::map<K, V> and std::unordered_map<K, V>
        inline for (.{ "std::map<", "std::unordered_map<" }) |prefix| {
            if (self.matchStr(prefix)) {
                const key = try self.parseType();
                self.skipWhitespace();
                if (!self.matchChar(',')) return ParseError.InvalidTypeSyntax;
                self.skipWhitespace();
                const value = try self.parseType();
                if (!self.matchChar('>')) return ParseError.InvalidTypeSyntax;
                const name = prefix[0 .. prefix.len - 1];
                const base = self.arena.named(name, .cpp) catch return ParseError.OutOfMemory;
                const params = [_]*const Type{ key, value };
                return self.arena.generic(base, &params) catch return ParseError.OutOfMemory;
            }
        }

        // Smart pointers: unique_ptr<T>, shared_ptr<T>
        inline for (.{ "std::unique_ptr<", "std::shared_ptr<" }) |prefix| {
            if (self.matchStr(prefix)) {
                const inner = try self.parseType();
                if (!self.matchChar('>')) return ParseError.InvalidTypeSyntax;
                const name = prefix[0 .. prefix.len - 1];
                const base = self.arena.named(name, .cpp) catch return ParseError.OutOfMemory;
                const params = [_]*const Type{inner};
                return self.arena.generic(base, &params) catch return ParseError.OutOfMemory;
            }
        }

        // std::pair<T, U>
        if (self.matchStr("std::pair<")) {
            const first = try self.parseType();
            self.skipWhitespace();
            if (!self.matchChar(',')) return ParseError.InvalidTypeSyntax;
            self.skipWhitespace();
            const second = try self.parseType();
            if (!self.matchChar('>')) return ParseError.InvalidTypeSyntax;
            const base = self.arena.named("std::pair", .cpp) catch return ParseError.OutOfMemory;
            const params = [_]*const Type{ first, second };
            return self.arena.generic(base, &params) catch return ParseError.OutOfMemory;
        }

        return self.parseNamedType();
    }

    fn parseCSharpType(self: *TypeParser) ParseError!*Type {
        // Check for List<T>
        if (self.matchStr("List<")) {
            const elem = try self.parseType();
            if (!self.matchChar('>')) return ParseError.InvalidTypeSyntax;
            return self.arena.array(elem) catch return ParseError.OutOfMemory;
        }

        // Check for Dictionary<K, V>
        if (self.matchStr("Dictionary<")) {
            const key = try self.parseType();
            self.skipWhitespace();
            if (!self.matchChar(',')) return ParseError.InvalidTypeSyntax;
            self.skipWhitespace();
            const value = try self.parseType();
            if (!self.matchChar('>')) return ParseError.InvalidTypeSyntax;
            const base = self.arena.named("Dictionary", .csharp) catch return ParseError.OutOfMemory;
            const params = [_]*const Type{ key, value };
            return self.arena.generic(base, &params) catch return ParseError.OutOfMemory;
        }

        return self.parseNamedType();
    }

    fn parseKotlinType(self: *TypeParser) ParseError!*Type {
        // Check for List<T>
        if (self.matchStr("List<")) {
            const elem = try self.parseType();
            if (!self.matchChar('>')) return ParseError.InvalidTypeSyntax;
            return self.arena.array(elem) catch return ParseError.OutOfMemory;
        }

        // Check for Map<K, V>
        if (self.matchStr("Map<")) {
            const key = try self.parseType();
            self.skipWhitespace();
            if (!self.matchChar(',')) return ParseError.InvalidTypeSyntax;
            self.skipWhitespace();
            const value = try self.parseType();
            if (!self.matchChar('>')) return ParseError.InvalidTypeSyntax;
            const base = self.arena.named("Map", .kotlin) catch return ParseError.OutOfMemory;
            const params = [_]*const Type{ key, value };
            return self.arena.generic(base, &params) catch return ParseError.OutOfMemory;
        }

        return self.parseNamedType();
    }

    fn parseZigType(self: *TypeParser) ParseError!*Type {
        // Check for slice []T
        if (self.matchStr("[]")) {
            const elem = try self.parseType();
            return self.arena.array(elem) catch return ParseError.OutOfMemory;
        }

        // Check for optional ?T
        if (self.matchChar('?')) {
            const inner = try self.parseType();
            return self.arena.optional(inner) catch return ParseError.OutOfMemory;
        }

        // Check for error union T!E
        if (self.pos < self.input.len) {
            // This is simplified - real Zig type parsing is more complex
        }

        return self.parseNamedType();
    }

    fn parseCType(self: *TypeParser) ParseError!*Type {
        // Check for pointer type (e.g., int*, char*)
        const base = self.parseNamedType() catch return ParseError.InvalidTypeSyntax;
        self.skipWhitespace();
        if (self.matchChar('*')) {
            const t = self.arena.arena.allocator().create(Type) catch return ParseError.OutOfMemory;
            t.* = .{ .reference = .{ .pointee = base, .is_mutable = true } };
            return t;
        }
        return base;
    }

    fn parseRubyType(self: *TypeParser) ParseError!*Type {
        // Sorbet/RBS Array[T]
        if (self.matchStr("Array[")) {
            const elem = try self.parseType();
            if (!self.matchChar(']')) return ParseError.InvalidTypeSyntax;
            return self.arena.array(elem) catch return ParseError.OutOfMemory;
        }

        // Hash[K, V]
        if (self.matchStr("Hash[")) {
            const key = try self.parseType();
            self.skipWhitespace();
            if (!self.matchChar(',')) return ParseError.InvalidTypeSyntax;
            self.skipWhitespace();
            const value = try self.parseType();
            if (!self.matchChar(']')) return ParseError.InvalidTypeSyntax;
            const base = self.arena.named("Hash", .ruby) catch return ParseError.OutOfMemory;
            const params = [_]*const Type{ key, value };
            return self.arena.generic(base, &params) catch return ParseError.OutOfMemory;
        }

        // T::Nilable (Sorbet nilable sugar)
        // Fall through to named type
        return self.parseNamedType();
    }

    fn parsePhpType(self: *TypeParser) ParseError!*Type {
        // Nullable ?Type
        if (self.matchChar('?')) {
            const inner = try self.parseType();
            return self.arena.optional(inner) catch return ParseError.OutOfMemory;
        }

        // array<T> or array<K, V>
        if (self.matchStr("array<")) {
            const first = try self.parseType();
            self.skipWhitespace();
            if (self.matchChar(',')) {
                self.skipWhitespace();
                const value = try self.parseType();
                if (!self.matchChar('>')) return ParseError.InvalidTypeSyntax;
                const base = self.arena.named("array", .php) catch return ParseError.OutOfMemory;
                const params = [_]*const Type{ first, value };
                return self.arena.generic(base, &params) catch return ParseError.OutOfMemory;
            }
            if (!self.matchChar('>')) return ParseError.InvalidTypeSyntax;
            return self.arena.array(first) catch return ParseError.OutOfMemory;
        }

        // Parse base type then check for union (int|string)
        const base = try self.parseNamedType();
        self.skipWhitespace();
        if (self.matchChar('|')) {
            self.skipWhitespace();
            const right = try self.parseType();
            const members = [_]*const Type{ base, right };
            return self.arena.unionType(&members) catch return ParseError.OutOfMemory;
        }
        return base;
    }

    fn parseSwiftType(self: *TypeParser) ParseError!*Type {
        // Array sugar [T]
        if (self.matchChar('[')) {
            const elem = try self.parseType();
            self.skipWhitespace();
            // Check for Dictionary [K: V]
            if (self.matchChar(':')) {
                self.skipWhitespace();
                const value = try self.parseType();
                if (!self.matchChar(']')) return ParseError.InvalidTypeSyntax;
                const base = self.arena.named("Dictionary", .swift) catch return ParseError.OutOfMemory;
                const params = [_]*const Type{ elem, value };
                return self.arena.generic(base, &params) catch return ParseError.OutOfMemory;
            }
            if (!self.matchChar(']')) return ParseError.InvalidTypeSyntax;
            return self.arena.array(elem) catch return ParseError.OutOfMemory;
        }

        // Optional<T>
        if (self.matchStr("Optional<")) {
            const inner = try self.parseType();
            if (!self.matchChar('>')) return ParseError.InvalidTypeSyntax;
            return self.arena.optional(inner) catch return ParseError.OutOfMemory;
        }

        // Result<T, E>
        if (self.matchStr("Result<")) {
            const ok = try self.parseType();
            self.skipWhitespace();
            if (!self.matchChar(',')) return ParseError.InvalidTypeSyntax;
            self.skipWhitespace();
            const err = try self.parseType();
            if (!self.matchChar('>')) return ParseError.InvalidTypeSyntax;
            const t = self.arena.arena.allocator().create(Type) catch return ParseError.OutOfMemory;
            t.* = .{ .error_union = .{ .ok_type = ok, .err_type = err } };
            return t;
        }

        // Parse base type, then check for optional suffix ?
        const base = try self.parseNamedType();
        self.skipWhitespace();
        if (self.pos < self.input.len and self.input[self.pos] == '?') {
            self.pos += 1;
            return self.arena.optional(base) catch return ParseError.OutOfMemory;
        }
        return base;
    }

    fn parseNamedType(self: *TypeParser) ParseError!*Type {
        const name = self.parseIdentifier();
        if (name.len == 0) return ParseError.InvalidTypeSyntax;

        self.skipWhitespace();

        // Check for generic parameters
        if (self.matchChar('<') or (self.language == .python and self.matchChar('['))) {
            const close_char: u8 = if (self.language == .python) ']' else '>';
            var params: [8]*const Type = undefined;
            var param_count: usize = 0;

            while (true) {
                if (param_count >= 8) return ParseError.InvalidTypeSyntax;
                self.skipWhitespace();
                params[param_count] = try self.parseType();
                param_count += 1;
                self.skipWhitespace();
                if (!self.matchChar(',')) break;
            }

            if (!self.matchChar(close_char)) return ParseError.InvalidTypeSyntax;

            const base = self.arena.named(name, self.language) catch return ParseError.OutOfMemory;
            return self.arena.generic(base, params[0..param_count]) catch return ParseError.OutOfMemory;
        }

        return self.arena.named(name, self.language) catch return ParseError.OutOfMemory;
    }

    fn parseIdentifier(self: *TypeParser) []const u8 {
        const start = self.pos;
        while (self.pos < self.input.len) {
            const c = self.input[self.pos];
            if (std.ascii.isAlphanumeric(c) or c == '_' or c == ':' or c == '.') {
                self.pos += 1;
            } else {
                break;
            }
        }
        return self.input[start..self.pos];
    }

    fn skipWhitespace(self: *TypeParser) void {
        while (self.pos < self.input.len and std.ascii.isWhitespace(self.input[self.pos])) {
            self.pos += 1;
        }
    }

    fn matchChar(self: *TypeParser, c: u8) bool {
        if (self.pos < self.input.len and self.input[self.pos] == c) {
            self.pos += 1;
            return true;
        }
        return false;
    }

    fn matchStr(self: *TypeParser, s: []const u8) bool {
        if (self.pos + s.len <= self.input.len and
            std.mem.eql(u8, self.input[self.pos .. self.pos + s.len], s))
        {
            self.pos += s.len;
            return true;
        }
        return false;
    }

    fn peekChar(self: *TypeParser, c: u8) bool {
        return self.pos < self.input.len and self.input[self.pos] == c;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "TypeParser - TypeScript primitives" {
    var arena = TypeArena.init(std.testing.allocator);
    defer arena.deinit();

    var parser = TypeParser.init(&arena, .typescript);

    const str_type = try parser.parse("string");
    try std.testing.expect(str_type.* == .primitive);
    try std.testing.expect(str_type.primitive == .string);

    const num_type = try parser.parse("number");
    try std.testing.expect(num_type.primitive == .number);

    const bool_type = try parser.parse("boolean");
    try std.testing.expect(bool_type.primitive == .boolean);
}

test "TypeParser - TypeScript array" {
    var arena = TypeArena.init(std.testing.allocator);
    defer arena.deinit();

    var parser = TypeParser.init(&arena, .typescript);

    const arr_type = try parser.parse("string[]");
    try std.testing.expect(arr_type.* == .array);
    try std.testing.expect(arr_type.array.primitive == .string);
}

test "TypeParser - Python List" {
    var arena = TypeArena.init(std.testing.allocator);
    defer arena.deinit();

    var parser = TypeParser.init(&arena, .python);

    const list_type = try parser.parse("List[int]");
    try std.testing.expect(list_type.* == .array);
    try std.testing.expect(list_type.array.primitive == .i64);
}

test "TypeParser - Rust Vec" {
    var arena = TypeArena.init(std.testing.allocator);
    defer arena.deinit();

    var parser = TypeParser.init(&arena, .rust);

    const vec_type = try parser.parse("Vec<String>");
    try std.testing.expect(vec_type.* == .array);
    try std.testing.expect(vec_type.array.primitive == .string);
}

test "TypeParser - Rust Option" {
    var arena = TypeArena.init(std.testing.allocator);
    defer arena.deinit();

    var parser = TypeParser.init(&arena, .rust);

    const opt_type = try parser.parse("Option<i32>");
    try std.testing.expect(opt_type.* == .optional);
    try std.testing.expect(opt_type.optional.primitive == .i32);
}

test "TypeParser - Go slice" {
    var arena = TypeArena.init(std.testing.allocator);
    defer arena.deinit();

    var parser = TypeParser.init(&arena, .go);

    const slice_type = try parser.parse("[]string");
    try std.testing.expect(slice_type.* == .array);
    try std.testing.expect(slice_type.array.primitive == .string);
}

test "TypeParser - named type with generics" {
    var arena = TypeArena.init(std.testing.allocator);
    defer arena.deinit();

    var parser = TypeParser.init(&arena, .typescript);

    const promise_type = try parser.parse("Promise<string>");
    try std.testing.expect(promise_type.* == .generic);
    try std.testing.expect(promise_type.generic.params.len == 1);
}

// ============================================================================
// Property-based tests
// ============================================================================

test "property: parser never crashes on arbitrary input" {
    // Feed random byte strings to the parser; it should return a valid type
    // or a clean ParseError, never panic or crash.
    var prng = std.Random.DefaultPrng.init(0xDEADBEEF);
    const random = prng.random();

    const languages = [_]Language{
        .typescript, .python, .rust, .go, .java,
        .cpp,        .csharp, .kotlin, .zig_lang, .c,
        .ruby,       .php,    .swift,
    };

    const charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789<>[](),?|&*:;{} \t_.-+!@#$%^";

    for (0..100) |_| {
        const lang = languages[random.uintLessThan(usize, languages.len)];

        var arena = TypeArena.init(std.testing.allocator);
        defer arena.deinit();

        var parser = TypeParser.init(&arena, lang);

        // Generate a random string of length 0-64
        const len = random.uintLessThan(usize, 65);
        var buf: [64]u8 = undefined;
        for (0..len) |j| {
            buf[j] = charset[random.uintLessThan(usize, charset.len)];
        }
        const input = buf[0..len];

        // Must either succeed or return a ParseError. Must not panic.
        const result = parser.parse(input);
        if (result) |t| {
            // Valid type returned; verify it is a real variant
            switch (t.*) {
                .primitive, .array, .tuple, .optional, .named,
                .union_type, .function, .generic, .reference, .error_union,
                => {},
            }
        } else |err| {
            // Must be one of the defined ParseError values
            switch (err) {
                error.UnexpectedToken,
                error.UnexpectedEndOfInput,
                error.InvalidTypeSyntax,
                error.UnsupportedType,
                error.OutOfMemory,
                => {},
            }
        }
    }
}

test "property: all primitives round-trip through parse" {
    // For each language, parse every primitive type name; result should
    // be a .primitive variant.
    const PrimEntry = struct { name: []const u8, kind: PrimitiveKind };

    const lang_primitives = .{
        .{ Language.typescript, &[_]PrimEntry{
            .{ .name = "string", .kind = .string },
            .{ .name = "number", .kind = .number },
            .{ .name = "boolean", .kind = .boolean },
            .{ .name = "void", .kind = .void_type },
            .{ .name = "null", .kind = .null_type },
            .{ .name = "undefined", .kind = .undefined },
            .{ .name = "any", .kind = .any },
            .{ .name = "unknown", .kind = .unknown },
            .{ .name = "never", .kind = .never },
        } },
        .{ Language.python, &[_]PrimEntry{
            .{ .name = "str", .kind = .string },
            .{ .name = "int", .kind = .i64 },
            .{ .name = "float", .kind = .f64 },
            .{ .name = "bool", .kind = .boolean },
            .{ .name = "None", .kind = .null_type },
            .{ .name = "Any", .kind = .any },
        } },
        .{ Language.rust, &[_]PrimEntry{
            .{ .name = "String", .kind = .string },
            .{ .name = "i32", .kind = .i32 },
            .{ .name = "i64", .kind = .i64 },
            .{ .name = "u8", .kind = .u8 },
            .{ .name = "u32", .kind = .u32 },
            .{ .name = "f32", .kind = .f32 },
            .{ .name = "f64", .kind = .f64 },
            .{ .name = "bool", .kind = .boolean },
        } },
        .{ Language.go, &[_]PrimEntry{
            .{ .name = "string", .kind = .string },
            .{ .name = "int", .kind = .i64 },
            .{ .name = "int32", .kind = .i32 },
            .{ .name = "float64", .kind = .f64 },
            .{ .name = "bool", .kind = .boolean },
            .{ .name = "byte", .kind = .u8 },
        } },
        .{ Language.java, &[_]PrimEntry{
            .{ .name = "String", .kind = .string },
            .{ .name = "int", .kind = .i32 },
            .{ .name = "long", .kind = .i64 },
            .{ .name = "float", .kind = .f32 },
            .{ .name = "double", .kind = .f64 },
            .{ .name = "boolean", .kind = .boolean },
            .{ .name = "void", .kind = .void_type },
        } },
        .{ Language.kotlin, &[_]PrimEntry{
            .{ .name = "String", .kind = .string },
            .{ .name = "Int", .kind = .i32 },
            .{ .name = "Long", .kind = .i64 },
            .{ .name = "Boolean", .kind = .boolean },
            .{ .name = "Unit", .kind = .void_type },
        } },
        .{ Language.swift, &[_]PrimEntry{
            .{ .name = "String", .kind = .string },
            .{ .name = "Int", .kind = .i64 },
            .{ .name = "Double", .kind = .f64 },
            .{ .name = "Bool", .kind = .boolean },
            .{ .name = "Void", .kind = .void_type },
        } },
    };

    inline for (lang_primitives) |entry| {
        const lang = entry[0];
        const prims = entry[1];

        for (prims) |prim| {
            var arena = TypeArena.init(std.testing.allocator);
            defer arena.deinit();

            var parser = TypeParser.init(&arena, lang);
            const result = try parser.parse(prim.name);
            try std.testing.expect(result.* == .primitive);
            try std.testing.expectEqual(prim.kind, result.primitive);
        }
    }
}

test "property: optional wrapping produces optional variant" {
    // For any parseable type T, wrapping it as Optional<T> (or language
    // equivalent) should produce an .optional variant.
    var prng = std.Random.DefaultPrng.init(0xDEADBEEF);
    const random = prng.random();

    const Case = struct { lang: Language, base: []const u8, wrapped: []const u8 };
    const cases = [_]Case{
        .{ .lang = .typescript, .base = "string", .wrapped = "string?" },
        .{ .lang = .typescript, .base = "number", .wrapped = "number?" },
        .{ .lang = .rust, .base = "i32", .wrapped = "Option<i32>" },
        .{ .lang = .rust, .base = "String", .wrapped = "Option<String>" },
        .{ .lang = .kotlin, .base = "Int", .wrapped = "Int?" },
        .{ .lang = .kotlin, .base = "String", .wrapped = "String?" },
        .{ .lang = .csharp, .base = "int", .wrapped = "int?" },
        .{ .lang = .csharp, .base = "string", .wrapped = "string?" },
        .{ .lang = .swift, .base = "Int", .wrapped = "Int?" },
        .{ .lang = .swift, .base = "String", .wrapped = "String?" },
    };

    // Test all defined cases
    for (cases) |case| {
        var arena = TypeArena.init(std.testing.allocator);
        defer arena.deinit();

        var parser = TypeParser.init(&arena, case.lang);

        // Parse the base type to verify it is valid
        const base_result = try parser.parse(case.base);
        try std.testing.expect(base_result.* == .primitive);

        // Parse the wrapped type and verify it is optional
        const opt_result = try parser.parse(case.wrapped);
        try std.testing.expect(opt_result.* == .optional);
    }

    // Additionally, test random selections from the case list (50 iterations)
    for (0..50) |_| {
        const idx = random.uintLessThan(usize, cases.len);
        const case = cases[idx];

        var arena = TypeArena.init(std.testing.allocator);
        defer arena.deinit();

        var parser = TypeParser.init(&arena, case.lang);
        const opt_result = try parser.parse(case.wrapped);
        try std.testing.expect(opt_result.* == .optional);
    }
}
