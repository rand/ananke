// Scope-Graph-Informed Name Resolution
//
// Transforms Homer's path-stitching scope graphs into structured context
// that seeds the Type and Import domains for constrained decoding.
//
// Key insight: Clew extracts the AST of the *current file*. Homer's scope
// graph provides *cross-file binding context*. Together, they give TypeDomain
// everything needed for precise type checking — not just locally declared
// types, but all reachable types through the scope graph.
//
// This module defines the data types and serialization. It does NOT query
// Homer directly — that's the CLI/MCP layer's job. Data flows in, JSON
// flows out to RichContext.
//
// Scope graph → ScopeContext → JSON → RichContext.scope_bindings_json
//                                   → enriches type_bindings_json
//                                   → enriches imports_json

const std = @import("std");

/// A binding resolved through Homer's scope graph.
/// Represents a name that is in scope at a given code location,
/// resolved across file boundaries.
pub const ScopeBinding = struct {
    /// The name of the binding (e.g., "HashMap", "User", "process_request")
    name: []const u8,
    /// The fully-qualified type, if known (e.g., "std::collections::HashMap<K,V>")
    qualified_type: ?[]const u8 = null,
    /// The kind of binding (type, function, variable, module)
    kind: BindingKind,
    /// The file where this binding is defined
    definition_file: ?[]const u8 = null,
    /// Line number where this binding is defined
    definition_line: ?u32 = null,
    /// Whether this binding is re-exported (accessible through multiple paths)
    is_reexport: bool = false,
};

/// Kinds of bindings that Homer's scope graph can resolve.
pub const BindingKind = enum {
    /// class, struct, interface, enum, trait
    type_definition,
    /// function, method, constructor
    function,
    /// const, let, var, parameter
    variable,
    /// import, module, package
    module,
    /// type alias, typedef
    type_alias,
};

/// The canonical import statement that the codebase uses to access a binding.
/// Derived from the scope graph resolution path — tells the generator
/// exactly how the codebase imports a given name.
pub const CanonicalImport = struct {
    /// The module/package path (e.g., "models/user", "std::collections")
    module_path: []const u8,
    /// Specific items imported (e.g., ["User", "UserRole"])
    items: []const []const u8 = &.{},
    /// Whether this is a wildcard import (e.g., "from models import *")
    is_wildcard: bool = false,
};

/// The enclosing scope at a hole location.
pub const EnclosingScope = struct {
    /// Name of the enclosing scope (e.g., "UserService", "process_request")
    name: []const u8,
    /// Kind of scope
    kind: ScopeKind,
    /// File containing this scope
    file: []const u8,
};

/// Kinds of enclosing scopes.
pub const ScopeKind = enum {
    function,
    method,
    class,
    module,
    block,
};

/// Complete scope context at a specific code location.
/// Assembled from Homer's scope graph queries.
pub const ScopeContext = struct {
    /// All bindings in scope at the hole location (cross-file)
    bindings: []const ScopeBinding,
    /// The enclosing scope at the hole
    enclosing_scope: ?EnclosingScope = null,
    /// Import statements used by the codebase for these bindings
    canonical_imports: []const CanonicalImport = &.{},
    /// Language of the source code
    language: []const u8 = "",
};

/// Serialize scope bindings to JSON matching ConstraintSpec.type_bindings format.
/// This enriches the TypeDomain with cross-file type information.
///
/// Output format: [{"name": "...", "kind": "...", "qualified_type": "...", "definition_file": "..."}]
pub fn serializeBindingsJson(
    allocator: std.mem.Allocator,
    bindings: []const ScopeBinding,
) ![]u8 {
    var buf = std.ArrayList(u8){};
    errdefer buf.deinit(allocator);
    const writer = buf.writer(allocator);

    try writer.writeAll("[");
    for (bindings, 0..) |binding, i| {
        try writer.writeAll("{");
        try writer.print("\"name\": \"{s}\"", .{binding.name});
        try writer.print(", \"kind\": \"{s}\"", .{@tagName(binding.kind)});
        if (binding.qualified_type) |qt| {
            try writer.print(", \"qualified_type\": \"{s}\"", .{qt});
        }
        if (binding.definition_file) |df| {
            try writer.print(", \"definition_file\": \"{s}\"", .{df});
        }
        if (binding.definition_line) |dl| {
            try writer.print(", \"definition_line\": {d}", .{dl});
        }
        if (binding.is_reexport) {
            try writer.writeAll(", \"is_reexport\": true");
        }
        try writer.writeAll("}");
        if (i + 1 < bindings.len) try writer.writeAll(", ");
    }
    try writer.writeAll("]");

    return try buf.toOwnedSlice(allocator);
}

/// Serialize canonical imports to JSON matching ConstraintSpec.imports format.
/// Seeds the ImportDomain with exact import statements used by the codebase.
///
/// Output format: [{"module": "...", "items": ["..."], "is_wildcard": false}]
pub fn serializeImportsJson(
    allocator: std.mem.Allocator,
    imports: []const CanonicalImport,
) ![]u8 {
    var buf = std.ArrayList(u8){};
    errdefer buf.deinit(allocator);
    const writer = buf.writer(allocator);

    try writer.writeAll("[");
    for (imports, 0..) |imp, i| {
        try writer.writeAll("{");
        try writer.print("\"module\": \"{s}\"", .{imp.module_path});
        try writer.writeAll(", \"items\": [");
        for (imp.items, 0..) |item, j| {
            try writer.print("\"{s}\"", .{item});
            if (j + 1 < imp.items.len) try writer.writeAll(", ");
        }
        try writer.writeAll("]");
        try writer.print(", \"is_wildcard\": {}", .{imp.is_wildcard});
        try writer.writeAll("}");
        if (i + 1 < imports.len) try writer.writeAll(", ");
    }
    try writer.writeAll("]");

    return try buf.toOwnedSlice(allocator);
}

/// Serialize the full scope context to JSON for RichContext.scope_bindings_json.
///
/// Output format: {"bindings": [...], "enclosing_scope": {...}, "canonical_imports": [...]}
pub fn serializeContextJson(
    allocator: std.mem.Allocator,
    context: ScopeContext,
) ![]u8 {
    var buf = std.ArrayList(u8){};
    errdefer buf.deinit(allocator);
    const writer = buf.writer(allocator);

    try writer.writeAll("{");

    // Bindings
    const bindings_json = try serializeBindingsJson(allocator, context.bindings);
    defer allocator.free(bindings_json);
    try writer.print("\"bindings\": {s}", .{bindings_json});

    // Enclosing scope
    if (context.enclosing_scope) |scope| {
        try writer.print(", \"enclosing_scope\": {{\"name\": \"{s}\", \"kind\": \"{s}\", \"file\": \"{s}\"}}", .{
            scope.name,
            @tagName(scope.kind),
            scope.file,
        });
    }

    // Canonical imports
    if (context.canonical_imports.len > 0) {
        const imports_json = try serializeImportsJson(allocator, context.canonical_imports);
        defer allocator.free(imports_json);
        try writer.print(", \"canonical_imports\": {s}", .{imports_json});
    }

    // Language
    if (context.language.len > 0) {
        try writer.print(", \"language\": \"{s}\"", .{context.language});
    }

    try writer.writeAll("}");

    return try buf.toOwnedSlice(allocator);
}

/// Extract type-definition bindings from a scope context.
/// Useful for selectively enriching the TypeDomain.
pub fn filterTypeBindings(bindings: []const ScopeBinding) FilterResult {
    var count: usize = 0;
    for (bindings) |b| {
        if (b.kind == .type_definition or b.kind == .type_alias) {
            count += 1;
        }
    }
    return .{ .bindings = bindings, .type_count = count };
}

pub const FilterResult = struct {
    bindings: []const ScopeBinding,
    type_count: usize,

    /// Check if type bindings are available for TypeDomain enrichment
    pub fn hasTypes(self: FilterResult) bool {
        return self.type_count > 0;
    }
};

/// Extract function bindings from a scope context.
/// Used for enriching function_signatures in RichContext.
pub fn countFunctionBindings(bindings: []const ScopeBinding) usize {
    var count: usize = 0;
    for (bindings) |b| {
        if (b.kind == .function) count += 1;
    }
    return count;
}

/// Determine if scope context provides enough data to activate
/// cross-file type checking (PLDI 2025 prefix automata approach).
/// Requires at least one type binding with a qualified type.
pub fn canActivateCrossFileTypeChecking(bindings: []const ScopeBinding) bool {
    for (bindings) |b| {
        if ((b.kind == .type_definition or b.kind == .type_alias) and
            b.qualified_type != null)
        {
            return true;
        }
    }
    return false;
}

// ---------- Tests ----------

test "serialize empty bindings" {
    const json = try serializeBindingsJson(std.testing.allocator, &.{});
    defer std.testing.allocator.free(json);
    try std.testing.expectEqualStrings("[]", json);
}

test "serialize single binding" {
    const bindings = [_]ScopeBinding{
        .{
            .name = "User",
            .kind = .type_definition,
            .qualified_type = "models.user.User",
            .definition_file = "src/models/user.py",
            .definition_line = 15,
        },
    };

    const json = try serializeBindingsJson(std.testing.allocator, &bindings);
    defer std.testing.allocator.free(json);

    // Verify key fields are present
    try std.testing.expect(std.mem.indexOf(u8, json, "\"name\": \"User\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"kind\": \"type_definition\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"qualified_type\": \"models.user.User\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"definition_file\": \"src/models/user.py\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"definition_line\": 15") != null);
}

test "serialize multiple bindings" {
    const bindings = [_]ScopeBinding{
        .{ .name = "HashMap", .kind = .type_definition, .qualified_type = "std::collections::HashMap" },
        .{ .name = "process", .kind = .function },
        .{ .name = "CONFIG", .kind = .variable },
    };

    const json = try serializeBindingsJson(std.testing.allocator, &bindings);
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"HashMap\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"process\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"CONFIG\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"function\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"variable\"") != null);
}

test "serialize reexported binding" {
    const bindings = [_]ScopeBinding{
        .{
            .name = "User",
            .kind = .type_definition,
            .is_reexport = true,
            .definition_file = "models/user.py",
        },
    };

    const json = try serializeBindingsJson(std.testing.allocator, &bindings);
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"is_reexport\": true") != null);
}

test "serialize canonical imports" {
    const items = [_][]const u8{ "User", "UserRole" };
    const imports = [_]CanonicalImport{
        .{ .module_path = "models.user", .items = &items },
        .{ .module_path = "utils", .is_wildcard = true },
    };

    const json = try serializeImportsJson(std.testing.allocator, &imports);
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"module\": \"models.user\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"User\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"UserRole\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"is_wildcard\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"is_wildcard\": true") != null);
}

test "serialize full context" {
    const bindings = [_]ScopeBinding{
        .{ .name = "User", .kind = .type_definition, .qualified_type = "models.User" },
        .{ .name = "get_user", .kind = .function },
    };
    const items = [_][]const u8{"User"};
    const imports = [_]CanonicalImport{
        .{ .module_path = "models", .items = &items },
    };
    const context = ScopeContext{
        .bindings = &bindings,
        .enclosing_scope = .{
            .name = "UserService",
            .kind = .class,
            .file = "src/services/user_service.py",
        },
        .canonical_imports = &imports,
        .language = "python",
    };

    const json = try serializeContextJson(std.testing.allocator, context);
    defer std.testing.allocator.free(json);

    // Verify structure
    try std.testing.expect(std.mem.indexOf(u8, json, "\"bindings\": [") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"enclosing_scope\": {") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"UserService\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"class\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"canonical_imports\": [") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"language\": \"python\"") != null);
}

test "context without enclosing scope or imports" {
    const bindings = [_]ScopeBinding{
        .{ .name = "fmt", .kind = .module },
    };
    const context = ScopeContext{
        .bindings = &bindings,
    };

    const json = try serializeContextJson(std.testing.allocator, context);
    defer std.testing.allocator.free(json);

    // Should have bindings but no enclosing_scope or canonical_imports
    try std.testing.expect(std.mem.indexOf(u8, json, "\"bindings\": [") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"enclosing_scope\"") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"canonical_imports\"") == null);
}

test "filter type bindings" {
    const bindings = [_]ScopeBinding{
        .{ .name = "User", .kind = .type_definition },
        .{ .name = "process", .kind = .function },
        .{ .name = "UserId", .kind = .type_alias },
        .{ .name = "config", .kind = .variable },
    };

    const result = filterTypeBindings(&bindings);
    try std.testing.expectEqual(@as(usize, 2), result.type_count);
    try std.testing.expect(result.hasTypes());
}

test "filter type bindings: none found" {
    const bindings = [_]ScopeBinding{
        .{ .name = "process", .kind = .function },
        .{ .name = "config", .kind = .variable },
    };

    const result = filterTypeBindings(&bindings);
    try std.testing.expectEqual(@as(usize, 0), result.type_count);
    try std.testing.expect(!result.hasTypes());
}

test "count function bindings" {
    const bindings = [_]ScopeBinding{
        .{ .name = "User", .kind = .type_definition },
        .{ .name = "get_user", .kind = .function },
        .{ .name = "create_user", .kind = .function },
    };

    try std.testing.expectEqual(@as(usize, 2), countFunctionBindings(&bindings));
}

test "cross-file type checking activation" {
    // With qualified type → can activate
    const with_types = [_]ScopeBinding{
        .{ .name = "User", .kind = .type_definition, .qualified_type = "models.User" },
    };
    try std.testing.expect(canActivateCrossFileTypeChecking(&with_types));

    // Without qualified type → cannot activate
    const without_types = [_]ScopeBinding{
        .{ .name = "User", .kind = .type_definition },
    };
    try std.testing.expect(!canActivateCrossFileTypeChecking(&without_types));

    // Function binding (not a type) → cannot activate
    const funcs_only = [_]ScopeBinding{
        .{ .name = "process", .kind = .function, .qualified_type = "utils.process" },
    };
    try std.testing.expect(!canActivateCrossFileTypeChecking(&funcs_only));

    // Empty → cannot activate
    try std.testing.expect(!canActivateCrossFileTypeChecking(&.{}));
}
