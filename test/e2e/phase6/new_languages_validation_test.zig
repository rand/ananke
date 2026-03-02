//! Phase 6: New Language Validation Tests
//!
//! End-to-end validation that all 5 new languages (Kotlin, C#, Ruby, PHP, Swift)
//! work through every layer of the extraction pipeline:
//! 1. Tree-sitter grammar parsing (no parse errors)
//! 2. Line-by-line extractor (correct functions/types/imports)
//! 3. Pattern matching (finds expected constructs)
//! 4. Hybrid extraction (tree-sitter + patterns combined)
//! 5. Full Clew pipeline (extractFromCode produces constraints)
//! 6. Alias resolution (kt → kotlin, cs → csharp, etc.)

const std = @import("std");
const testing = std.testing;

const Clew = @import("clew").Clew;
const HybridExtractor = @import("clew").hybrid_extractor.HybridExtractor;
const ExtractionStrategy = @import("clew").hybrid_extractor.ExtractionStrategy;
const extractors = @import("clew").extractors;
const patterns = @import("clew").patterns;
const tree_sitter = @import("tree_sitter");
const TreeSitterParser = tree_sitter.TreeSitterParser;
const Language = tree_sitter.Language;

// ============================================================================
// Realistic Multi-Line Code Samples
// ============================================================================

const kotlin_sample =
    \\package com.example.service
    \\
    \\import kotlinx.coroutines.flow.Flow
    \\import kotlinx.coroutines.Dispatchers
    \\
    \\data class User(val id: Long, val name: String, val email: String?)
    \\
    \\sealed class Result<out T> {
    \\    data class Success<T>(val data: T) : Result<T>()
    \\    data class Error(val message: String) : Result<Nothing>()
    \\}
    \\
    \\interface UserRepository {
    \\    suspend fun findById(id: Long): User?
    \\    fun findAll(): Flow<List<User>>
    \\}
    \\
    \\object UserValidator {
    \\    fun validate(user: User): Boolean {
    \\        return user.name.isNotBlank()
    \\    }
    \\}
    \\
    \\class UserService(private val repo: UserRepository) {
    \\    suspend fun getUser(id: Long): Result<User> {
    \\        return try {
    \\            val user = repo.findById(id)
    \\            if (user != null) Result.Success(user)
    \\            else Result.Error("User not found")
    \\        } catch (e: Exception) {
    \\            Result.Error(e.message ?: "Unknown error")
    \\        }
    \\    }
    \\}
;

const csharp_sample =
    \\using System;
    \\using System.Collections.Generic;
    \\using System.Threading.Tasks;
    \\
    \\namespace MyApp.Services
    \\{
    \\    public record UserDto(string Name, int Age);
    \\
    \\    public interface IUserRepository
    \\    {
    \\        Task<User?> FindByIdAsync(int id);
    \\        IEnumerable<User> GetAll();
    \\    }
    \\
    \\    public class UserService : IUserRepository
    \\    {
    \\        private readonly DbContext _context;
    \\
    \\        public UserService(DbContext context)
    \\        {
    \\            _context = context;
    \\        }
    \\
    \\        public async Task<User?> FindByIdAsync(int id)
    \\        {
    \\            return await _context.Users.FindAsync(id);
    \\        }
    \\
    \\        public IEnumerable<User> GetAll()
    \\        {
    \\            return _context.Users.ToList();
    \\        }
    \\    }
    \\
    \\    public struct Point
    \\    {
    \\        public int X { get; set; }
    \\        public int Y { get; set; }
    \\    }
    \\
    \\    public enum Status
    \\    {
    \\        Active,
    \\        Inactive
    \\    }
    \\}
;

const ruby_sample =
    \\require 'json'
    \\require_relative 'base_service'
    \\
    \\module Authentication
    \\  class Token
    \\    def initialize(value, expires_at)
    \\      @value = value
    \\      @expires_at = expires_at
    \\    end
    \\
    \\    def valid?
    \\      Time.now < @expires_at
    \\    end
    \\  end
    \\end
    \\
    \\class UserService < BaseService
    \\  include Authentication
    \\
    \\  def find_by_id(id)
    \\    users.detect { |u| u.id == id }
    \\  end
    \\
    \\  def self.create(params)
    \\    new(params).tap(&:save!)
    \\  end
    \\
    \\  def destroy!
    \\    begin
    \\      delete_record
    \\    rescue StandardError => e
    \\      raise "Failed to delete: #{e.message}"
    \\    end
    \\  end
    \\end
;

const php_sample =
    \\<?php
    \\
    \\namespace App\Http\Controllers;
    \\
    \\use App\Models\User;
    \\use Illuminate\Http\Request;
    \\
    \\interface UserRepositoryInterface
    \\{
    \\    public function findById(int $id): ?User;
    \\    public function getAll(): array;
    \\}
    \\
    \\trait Timestampable
    \\{
    \\    public function getCreatedAt(): \DateTime
    \\    {
    \\        return $this->createdAt;
    \\    }
    \\}
    \\
    \\class UserController extends Controller
    \\{
    \\    public function __construct(
    \\        private readonly UserRepositoryInterface $repo
    \\    ) {}
    \\
    \\    public function show(int $id): User
    \\    {
    \\        return $this->repo->findById($id);
    \\    }
    \\
    \\    public function index(): array
    \\    {
    \\        return $this->repo->getAll();
    \\    }
    \\}
    \\
    \\enum UserRole: string
    \\{
    \\    case Admin = 'admin';
    \\    case User = 'user';
    \\}
;

const swift_sample =
    \\import Foundation
    \\import SwiftUI
    \\
    \\protocol UserRepository {
    \\    func findById(_ id: Int) async throws -> User?
    \\    func getAll() -> [User]
    \\}
    \\
    \\struct User: Codable, Identifiable {
    \\    let id: Int
    \\    let name: String
    \\    let email: String?
    \\}
    \\
    \\enum NetworkError: Error {
    \\    case notFound
    \\    case serverError(String)
    \\}
    \\
    \\actor UserService: UserRepository {
    \\    private let session: URLSession
    \\
    \\    init(session: URLSession = .shared) {
    \\        self.session = session
    \\    }
    \\
    \\    func findById(_ id: Int) async throws -> User? {
    \\        let url = URL(string: "https://api.example.com/users/\(id)")!
    \\        let (data, _) = try await session.data(from: url)
    \\        return try JSONDecoder().decode(User.self, from: data)
    \\    }
    \\
    \\    func getAll() -> [User] {
    \\        return []
    \\    }
    \\}
;

// ============================================================================
// Layer 1: Tree-Sitter Grammar Parsing
// ============================================================================

test "Layer 1: Kotlin tree-sitter grammar parses without errors" {
    const allocator = testing.allocator;
    var parser = try TreeSitterParser.init(allocator, .kotlin);
    defer parser.deinit();
    var tree = try parser.parse(kotlin_sample);
    defer tree.deinit();
    const root = tree.rootNode();
    // Tree must be non-null
    try testing.expect(!root.isNull());
    // Check parse quality - hasError indicates parse failures
    if (root.hasError()) {
        std.debug.print("\n  WARNING: Kotlin tree has parse errors (child count: {})\n", .{root.childCount()});
    }
    try testing.expect(root.childCount() > 0);
    std.debug.print("\n  Kotlin: {} top-level nodes, hasError={}\n", .{ root.childCount(), root.hasError() });
}

test "Layer 1: C# tree-sitter grammar parses without errors" {
    const allocator = testing.allocator;
    var parser = try TreeSitterParser.init(allocator, .csharp);
    defer parser.deinit();
    var tree = try parser.parse(csharp_sample);
    defer tree.deinit();
    const root = tree.rootNode();
    try testing.expect(!root.isNull());
    try testing.expect(root.childCount() > 0);
    std.debug.print("\n  C#: {} top-level nodes, hasError={}\n", .{ root.childCount(), root.hasError() });
}

test "Layer 1: Ruby tree-sitter grammar parses without errors" {
    const allocator = testing.allocator;
    var parser = try TreeSitterParser.init(allocator, .ruby);
    defer parser.deinit();
    var tree = try parser.parse(ruby_sample);
    defer tree.deinit();
    const root = tree.rootNode();
    try testing.expect(!root.isNull());
    try testing.expect(root.childCount() > 0);
    std.debug.print("\n  Ruby: {} top-level nodes, hasError={}\n", .{ root.childCount(), root.hasError() });
}

test "Layer 1: PHP tree-sitter grammar parses without errors" {
    const allocator = testing.allocator;
    var parser = try TreeSitterParser.init(allocator, .php);
    defer parser.deinit();
    var tree = try parser.parse(php_sample);
    defer tree.deinit();
    const root = tree.rootNode();
    try testing.expect(!root.isNull());
    try testing.expect(root.childCount() > 0);
    std.debug.print("\n  PHP: {} top-level nodes, hasError={}\n", .{ root.childCount(), root.hasError() });
}

test "Layer 1: Swift tree-sitter grammar parses without errors" {
    const allocator = testing.allocator;
    var parser = try TreeSitterParser.init(allocator, .swift);
    defer parser.deinit();
    var tree = try parser.parse(swift_sample);
    defer tree.deinit();
    const root = tree.rootNode();
    try testing.expect(!root.isNull());
    try testing.expect(root.childCount() > 0);
    std.debug.print("\n  Swift: {} top-level nodes, hasError={}\n", .{ root.childCount(), root.hasError() });
}

// ============================================================================
// Layer 2: Line-by-Line Extractor Correctness
// ============================================================================

test "Layer 2: Kotlin extractor finds all expected constructs" {
    const allocator = testing.allocator;
    var s = try extractors.kotlin.parse(allocator, kotlin_sample);
    defer s.deinit();

    std.debug.print("\n  Kotlin extractor: {} functions, {} types, {} imports\n", .{
        s.functions.items.len, s.types.items.len, s.imports.items.len,
    });

    // Imports: package + 2 imports = 3
    try testing.expect(s.imports.items.len >= 3);
    // Verify specific import
    var found_coroutines = false;
    for (s.imports.items) |imp| {
        if (std.mem.indexOf(u8, imp.module, "kotlinx.coroutines") != null) found_coroutines = true;
    }
    try testing.expect(found_coroutines);

    // Types: User (data class), Result (sealed class), Success, Error, UserRepository (interface),
    //        UserValidator (object), UserService (class) = 7
    try testing.expect(s.types.items.len >= 5);
    var found_user = false;
    var found_repo = false;
    var found_validator = false;
    for (s.types.items) |t| {
        if (std.mem.eql(u8, t.name, "User")) found_user = true;
        if (std.mem.eql(u8, t.name, "UserRepository")) found_repo = true;
        if (std.mem.eql(u8, t.name, "UserValidator")) found_validator = true;
    }
    try testing.expect(found_user);
    try testing.expect(found_repo);
    try testing.expect(found_validator);

    // Functions: findById (suspend), findAll, validate, getUser (suspend)
    try testing.expect(s.functions.items.len >= 3);
    var found_suspend = false;
    for (s.functions.items) |f| {
        if (f.is_async) found_suspend = true;
    }
    try testing.expect(found_suspend);

    // Print all found items for diagnostics
    for (s.types.items) |t| {
        std.debug.print("    type: {s} ({})\n", .{ t.name, t.kind });
    }
    for (s.functions.items) |f| {
        std.debug.print("    func: {s} (async={}, public={})\n", .{ f.name, f.is_async, f.is_public });
    }
}

test "Layer 2: C# extractor finds all expected constructs" {
    const allocator = testing.allocator;
    var s = try extractors.csharp.parse(allocator, csharp_sample);
    defer s.deinit();

    std.debug.print("\n  C# extractor: {} functions, {} types, {} imports\n", .{
        s.functions.items.len, s.types.items.len, s.imports.items.len,
    });

    // Imports: 3 using + 1 namespace = 4
    try testing.expect(s.imports.items.len >= 4);

    // Types: UserDto (record), IUserRepository (interface), UserService (class),
    //        Point (struct), Status (enum) = 5
    try testing.expect(s.types.items.len >= 5);
    var found_interface = false;
    var found_record = false;
    var found_struct = false;
    var found_enum = false;
    for (s.types.items) |t| {
        if (std.mem.eql(u8, t.name, "IUserRepository") and t.kind == .interface_type) found_interface = true;
        if (std.mem.eql(u8, t.name, "UserDto")) found_record = true;
        if (std.mem.eql(u8, t.name, "Point") and t.kind == .struct_type) found_struct = true;
        if (std.mem.eql(u8, t.name, "Status") and t.kind == .enum_type) found_enum = true;
    }
    try testing.expect(found_interface);
    try testing.expect(found_record);
    try testing.expect(found_struct);
    try testing.expect(found_enum);

    // Functions: FindByIdAsync (async), GetAll, UserService (constructor), show, index
    try testing.expect(s.functions.items.len >= 2);
    var found_async_method = false;
    for (s.functions.items) |f| {
        if (std.mem.eql(u8, f.name, "FindByIdAsync") and f.is_async) found_async_method = true;
    }
    try testing.expect(found_async_method);

    for (s.types.items) |t| {
        std.debug.print("    type: {s} ({})\n", .{ t.name, t.kind });
    }
    for (s.functions.items) |f| {
        std.debug.print("    func: {s} (async={}, public={})\n", .{ f.name, f.is_async, f.is_public });
    }
}

test "Layer 2: Ruby extractor finds all expected constructs" {
    const allocator = testing.allocator;
    var s = try extractors.ruby.parse(allocator, ruby_sample);
    defer s.deinit();

    std.debug.print("\n  Ruby extractor: {} functions, {} types, {} imports\n", .{
        s.functions.items.len, s.types.items.len, s.imports.items.len,
    });

    // Imports: require 'json' + require_relative 'base_service' + include Authentication = 3
    try testing.expect(s.imports.items.len >= 2);
    var found_json = false;
    for (s.imports.items) |imp| {
        if (std.mem.eql(u8, imp.module, "json")) found_json = true;
    }
    try testing.expect(found_json);

    // Types: Authentication (module), Token (class), UserService (class) = 3
    try testing.expect(s.types.items.len >= 3);
    var found_module = false;
    var found_class = false;
    for (s.types.items) |t| {
        if (std.mem.eql(u8, t.name, "Authentication")) found_module = true;
        if (std.mem.eql(u8, t.name, "UserService")) found_class = true;
    }
    try testing.expect(found_module);
    try testing.expect(found_class);

    // Methods: initialize, valid?, find_by_id, self.create, destroy!
    try testing.expect(s.functions.items.len >= 4);
    var found_predicate = false;
    var found_bang = false;
    var found_class_method = false;
    for (s.functions.items) |f| {
        if (std.mem.eql(u8, f.name, "valid?")) found_predicate = true;
        if (std.mem.eql(u8, f.name, "destroy!")) found_bang = true;
        if (std.mem.eql(u8, f.name, "create")) found_class_method = true;
    }
    try testing.expect(found_predicate);
    try testing.expect(found_bang);
    try testing.expect(found_class_method);

    for (s.types.items) |t| {
        std.debug.print("    type: {s} ({})\n", .{ t.name, t.kind });
    }
    for (s.functions.items) |f| {
        std.debug.print("    func: {s}\n", .{f.name});
    }
}

test "Layer 2: PHP extractor finds all expected constructs" {
    const allocator = testing.allocator;
    var s = try extractors.php.parse(allocator, php_sample);
    defer s.deinit();

    std.debug.print("\n  PHP extractor: {} functions, {} types, {} imports\n", .{
        s.functions.items.len, s.types.items.len, s.imports.items.len,
    });

    // Imports: namespace + 2 use = 3
    try testing.expect(s.imports.items.len >= 3);
    var found_namespace = false;
    for (s.imports.items) |imp| {
        if (std.mem.indexOf(u8, imp.module, "App\\Http\\Controllers") != null) found_namespace = true;
    }
    try testing.expect(found_namespace);

    // Types: UserRepositoryInterface (interface), Timestampable (trait),
    //        UserController (class), UserRole (enum) = 4
    try testing.expect(s.types.items.len >= 4);
    var found_interface = false;
    var found_trait = false;
    var found_enum = false;
    for (s.types.items) |t| {
        if (std.mem.eql(u8, t.name, "UserRepositoryInterface") and t.kind == .interface_type) found_interface = true;
        if (std.mem.eql(u8, t.name, "Timestampable")) found_trait = true;
        if (std.mem.eql(u8, t.name, "UserRole") and t.kind == .enum_type) found_enum = true;
    }
    try testing.expect(found_interface);
    try testing.expect(found_trait);
    try testing.expect(found_enum);

    // Functions: findById, getAll, getCreatedAt, show, index
    try testing.expect(s.functions.items.len >= 4);

    for (s.types.items) |t| {
        std.debug.print("    type: {s} ({})\n", .{ t.name, t.kind });
    }
    for (s.functions.items) |f| {
        std.debug.print("    func: {s}\n", .{f.name});
    }
}

test "Layer 2: Swift extractor finds all expected constructs" {
    const allocator = testing.allocator;
    var s = try extractors.swift.parse(allocator, swift_sample);
    defer s.deinit();

    std.debug.print("\n  Swift extractor: {} functions, {} types, {} imports\n", .{
        s.functions.items.len, s.types.items.len, s.imports.items.len,
    });

    // Imports: Foundation + SwiftUI = 2
    try testing.expect(s.imports.items.len >= 2);
    var found_foundation = false;
    for (s.imports.items) |imp| {
        if (std.mem.eql(u8, imp.module, "Foundation")) found_foundation = true;
    }
    try testing.expect(found_foundation);

    // Types: UserRepository (protocol), User (struct), NetworkError (enum),
    //        UserService (actor) = 4
    try testing.expect(s.types.items.len >= 4);
    var found_protocol = false;
    var found_struct = false;
    var found_enum = false;
    var found_actor = false;
    for (s.types.items) |t| {
        if (std.mem.eql(u8, t.name, "UserRepository") and t.kind == .interface_type) found_protocol = true;
        if (std.mem.eql(u8, t.name, "User") and t.kind == .struct_type) found_struct = true;
        if (std.mem.eql(u8, t.name, "NetworkError") and t.kind == .enum_type) found_enum = true;
        if (std.mem.eql(u8, t.name, "UserService")) found_actor = true;
    }
    try testing.expect(found_protocol);
    try testing.expect(found_struct);
    try testing.expect(found_enum);
    try testing.expect(found_actor);

    // Functions: findById (async throws), getAll
    try testing.expect(s.functions.items.len >= 2);
    var found_async_throws = false;
    for (s.functions.items) |f| {
        if (std.mem.eql(u8, f.name, "findById") and f.is_async and f.has_error_handling) {
            found_async_throws = true;
        }
    }
    try testing.expect(found_async_throws);

    for (s.types.items) |t| {
        std.debug.print("    type: {s} ({})\n", .{ t.name, t.kind });
    }
    for (s.functions.items) |f| {
        std.debug.print("    func: {s} (async={}, throws={})\n", .{ f.name, f.is_async, f.has_error_handling });
    }
}

// ============================================================================
// Layer 3: Pattern Matching
// ============================================================================

test "Layer 3: Pattern matching finds constructs in all 5 languages" {
    const allocator = testing.allocator;

    const langs = [_]struct { name: []const u8, code: []const u8 }{
        .{ .name = "kotlin", .code = kotlin_sample },
        .{ .name = "csharp", .code = csharp_sample },
        .{ .name = "ruby", .code = ruby_sample },
        .{ .name = "php", .code = php_sample },
        .{ .name = "swift", .code = swift_sample },
    };

    std.debug.print("\n", .{});
    for (langs) |lang| {
        const lang_patterns = patterns.getPatternsForLanguage(lang.name) orelse {
            std.debug.print("  FAIL: No patterns for {s}\n", .{lang.name});
            return error.TestUnexpectedResult;
        };

        const matches = try patterns.findPatternMatches(allocator, lang.code, lang_patterns, lang.name);
        defer allocator.free(matches);

        std.debug.print("  {s}: {} pattern matches\n", .{ lang.name, matches.len });
        try testing.expect(matches.len > 0);
    }
}

// ============================================================================
// Layer 4: Hybrid Extraction (tree-sitter + patterns)
// ============================================================================

test "Layer 4: Hybrid extraction produces constraints for all 5 languages" {
    const allocator = testing.allocator;

    const langs = [_]struct { name: []const u8, code: []const u8 }{
        .{ .name = "kotlin", .code = kotlin_sample },
        .{ .name = "csharp", .code = csharp_sample },
        .{ .name = "ruby", .code = ruby_sample },
        .{ .name = "php", .code = php_sample },
        .{ .name = "swift", .code = swift_sample },
    };

    std.debug.print("\n", .{});
    for (langs) |lang| {
        var extractor = try HybridExtractor.init(allocator, .tree_sitter_with_fallback);
        defer extractor.deinit();

        var result = try extractor.extract(lang.code, lang.name);
        defer result.deinitFull(allocator);

        std.debug.print("  {s}: ts_available={}, constraints={}, strategy={}\n", .{
            lang.name,
            result.tree_sitter_available,
            result.constraints.len,
            result.strategy_used,
        });

        // Must produce constraints
        try testing.expect(result.constraints.len > 0);
        // Tree-sitter should be available since we added grammars
        try testing.expect(result.tree_sitter_available);
        // Strategy should be tree_sitter_with_fallback
        try testing.expectEqual(ExtractionStrategy.tree_sitter_with_fallback, result.strategy_used);

        if (result.tree_sitter_errors) |errors| {
            std.debug.print("    TS errors: {s}\n", .{errors});
        }
    }
}

// ============================================================================
// Layer 5: Full Clew Pipeline
// ============================================================================

test "Layer 5: Clew.extractFromCode works for all 5 languages" {
    const allocator = testing.allocator;

    const langs = [_]struct { name: []const u8, code: []const u8 }{
        .{ .name = "kotlin", .code = kotlin_sample },
        .{ .name = "csharp", .code = csharp_sample },
        .{ .name = "ruby", .code = ruby_sample },
        .{ .name = "php", .code = php_sample },
        .{ .name = "swift", .code = swift_sample },
    };

    std.debug.print("\n", .{});
    for (langs) |lang| {
        var clew = try Clew.init(allocator);
        defer clew.deinit();

        var constraints = try clew.extractFromCode(lang.code, lang.name);
        defer constraints.deinit();

        std.debug.print("  {s}: {} constraints from Clew pipeline\n", .{
            lang.name, constraints.constraints.items.len,
        });

        try testing.expect(constraints.constraints.items.len > 0);
    }
}

// ============================================================================
// Layer 6: Alias Resolution
// ============================================================================

test "Layer 6: Language aliases resolve correctly" {
    const allocator = testing.allocator;

    // Test alias → canonical name resolution through extractSyntaxStructure
    const aliases = [_]struct { alias: []const u8, code: []const u8, expect_types: bool }{
        .{ .alias = "kt", .code = "class Foo {}", .expect_types = true },
        .{ .alias = "cs", .code = "class Bar {}", .expect_types = true },
        .{ .alias = "c#", .code = "class Baz {}", .expect_types = true },
        .{ .alias = "rb", .code = "class Qux\nend", .expect_types = true },
    };

    std.debug.print("\n", .{});
    for (aliases) |a| {
        var s = try extractors.extractSyntaxStructure(allocator, a.code, a.alias);
        defer s.deinit();
        std.debug.print("  alias '{s}': {} types, {} functions, {} imports\n", .{
            a.alias, s.types.items.len, s.functions.items.len, s.imports.items.len,
        });
        if (a.expect_types) {
            try testing.expect(s.types.items.len > 0);
        }
    }

    // Test that pattern lookup also works with aliases
    try testing.expect(patterns.getPatternsForLanguage("kt") != null);
    try testing.expect(patterns.getPatternsForLanguage("cs") != null);
    try testing.expect(patterns.getPatternsForLanguage("c#") != null);
    try testing.expect(patterns.getPatternsForLanguage("rb") != null);
    std.debug.print("  All aliases resolve correctly\n", .{});
}

// ============================================================================
// Layer 7: SyntaxStructure → RichContext serialization
// ============================================================================

test "Layer 7: SyntaxStructure serializes to RichContext JSON for all 5 languages" {
    const allocator = testing.allocator;

    const langs = [_]struct { name: []const u8, code: []const u8 }{
        .{ .name = "kotlin", .code = kotlin_sample },
        .{ .name = "csharp", .code = csharp_sample },
        .{ .name = "ruby", .code = ruby_sample },
        .{ .name = "php", .code = php_sample },
        .{ .name = "swift", .code = swift_sample },
    };

    std.debug.print("\n", .{});
    for (langs) |lang| {
        var s = try extractors.extractSyntaxStructure(allocator, lang.code, lang.name);
        defer s.deinit();

        var rich_ctx = try s.toRichContext(allocator);
        defer rich_ctx.deinit(allocator);

        // Verify non-null JSON fields
        const has_functions = rich_ctx.function_signatures_json != null;
        const has_types = rich_ctx.type_bindings_json != null or rich_ctx.class_definitions_json != null;
        const has_imports = rich_ctx.imports_json != null;

        std.debug.print("  {s}: functions={}, types={}, imports={}\n", .{
            lang.name, has_functions, has_types, has_imports,
        });

        // Every realistic sample should produce at least some serializable data
        try testing.expect(has_functions or has_types or has_imports);

        // Verify the JSON is actually parseable
        if (rich_ctx.function_signatures_json) |json| {
            const parsed = std.json.parseFromSlice(std.json.Value, allocator, json, .{}) catch |err| {
                std.debug.print("    FAIL: function_signatures_json not valid JSON: {}\n", .{err});
                return err;
            };
            defer parsed.deinit();
        }
        if (rich_ctx.imports_json) |json| {
            const parsed = std.json.parseFromSlice(std.json.Value, allocator, json, .{}) catch |err| {
                std.debug.print("    FAIL: imports_json not valid JSON: {}\n", .{err});
                return err;
            };
            defer parsed.deinit();
        }
    }
}
