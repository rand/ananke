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

        // Check for union type (TypeScript: T | U)
        if (self.language == .typescript or self.language == .python) {
            if (self.matchStr(" | ") or self.matchChar('|')) {
                self.skipWhitespace();
                const right = try self.parseType();
                const members = [_]*const Type{ base, right };
                return self.arena.unionType(&members) catch return ParseError.OutOfMemory;
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
            const base = self.arena.named("Map", .java) catch return ParseError.OutOfMemory;
            const params = [_]*const Type{ key, value };
            return self.arena.generic(base, &params) catch return ParseError.OutOfMemory;
        }

        // Check for Optional<T>
        if (self.matchStr("Optional<")) {
            const inner = try self.parseType();
            if (!self.matchChar('>')) return ParseError.InvalidTypeSyntax;
            return self.arena.optional(inner) catch return ParseError.OutOfMemory;
        }

        return self.parseNamedType();
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

        // Check for std::map<K, V>
        if (self.matchStr("std::map<")) {
            const key = try self.parseType();
            self.skipWhitespace();
            if (!self.matchChar(',')) return ParseError.InvalidTypeSyntax;
            self.skipWhitespace();
            const value = try self.parseType();
            if (!self.matchChar('>')) return ParseError.InvalidTypeSyntax;
            const base = self.arena.named("std::map", .cpp) catch return ParseError.OutOfMemory;
            const params = [_]*const Type{ key, value };
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
