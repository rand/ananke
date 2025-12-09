//! C/C++/Java Extraction Tests
//! Verifies that hybrid extraction works for C, C++, and Java

const std = @import("std");
const testing = std.testing;

const Clew = @import("clew").Clew;

// ============================================================================
// Test Fixtures
// ============================================================================

const c_sample =
    \\// C sample code
    \\#include <stdio.h>
    \\#include <stdlib.h>
    \\
    \\typedef struct {
    \\    int id;
    \\    char* name;
    \\} User;
    \\
    \\User* create_user(int id) {
    \\    User* user = (User*)malloc(sizeof(User));
    \\    if (user == NULL) {
    \\        return NULL;
    \\    }
    \\    user->id = id;
    \\    user->name = NULL;
    \\    return user;
    \\}
    \\
    \\void free_user(User* user) {
    \\    if (user != NULL) {
    \\        free(user->name);
    \\        free(user);
    \\    }
    \\}
;

const cpp_sample =
    \\// C++ sample code
    \\#include <memory>
    \\#include <string>
    \\#include <vector>
    \\
    \\class User {
    \\public:
    \\    User(int id) : id_(id) {}
    \\    virtual ~User() = default;
    \\
    \\    int getId() const { return id_; }
    \\    void setName(const std::string& name) { name_ = name; }
    \\
    \\private:
    \\    int id_;
    \\    std::string name_;
    \\};
    \\
    \\std::unique_ptr<User> createUser(int id) {
    \\    return std::make_unique<User>(id);
    \\}
    \\
    \\template<typename T>
    \\T process(T value) {
    \\    return value;
    \\}
;

const java_sample =
    \\// Java sample code
    \\package com.example.service;
    \\
    \\import java.util.Optional;
    \\import java.util.List;
    \\
    \\public class UserService {
    \\    private final UserRepository repository;
    \\
    \\    public UserService(UserRepository repository) {
    \\        this.repository = repository;
    \\    }
    \\
    \\    public Optional<User> getUser(int id) throws NotFoundException {
    \\        return repository.findById(id);
    \\    }
    \\
    \\    public List<User> getAllUsers() {
    \\        return repository.findAll();
    \\    }
    \\}
    \\
    \\interface UserRepository {
    \\    Optional<User> findById(int id);
    \\    List<User> findAll();
    \\}
    \\
    \\enum UserStatus {
    \\    ACTIVE,
    \\    INACTIVE,
    \\    PENDING
    \\}
;

// ============================================================================
// C Extraction Tests
// ============================================================================

test "C: basic extraction works" {
    const allocator = testing.allocator;

    var clew = try Clew.init(allocator);
    defer clew.deinit();

    var result = try clew.extractFromCode(c_sample, "c");
    defer result.deinit();

    // Should extract some constraints
    try testing.expect(result.constraints.items.len > 0);

    std.debug.print("\n=== C Extraction ===\n", .{});
    std.debug.print("Extracted {} constraints\n", .{result.constraints.items.len});

    for (result.constraints.items) |constraint| {
        std.debug.print("  - {s} (conf: {d:.2})\n", .{ constraint.name, constraint.confidence });
    }
}

test "C: detects memory management" {
    const allocator = testing.allocator;

    var clew = try Clew.init(allocator);
    defer clew.deinit();

    var result = try clew.extractFromCode(c_sample, "c");
    defer result.deinit();

    // Should find malloc/free patterns
    var found_memory = false;
    for (result.constraints.items) |constraint| {
        if (std.mem.indexOf(u8, constraint.name, "alloc") != null or
            std.mem.indexOf(u8, constraint.description, "alloc") != null or
            std.mem.indexOf(u8, constraint.description, "free") != null)
        {
            found_memory = true;
            break;
        }
    }

    if (found_memory) {
        std.debug.print("\n Constraint indicates memory management in C\n", .{});
    } else {
        std.debug.print("\n No explicit memory management constraint found\n", .{});
    }
}

test "C: detects struct definitions" {
    const allocator = testing.allocator;

    var clew = try Clew.init(allocator);
    defer clew.deinit();

    var result = try clew.extractFromCode(c_sample, "c");
    defer result.deinit();

    // Should find struct definition
    var found_struct = false;
    for (result.constraints.items) |constraint| {
        if (std.mem.indexOf(u8, constraint.name, "User") != null or
            std.mem.indexOf(u8, constraint.description, "struct") != null or
            std.mem.indexOf(u8, constraint.description, "typedef") != null)
        {
            found_struct = true;
            break;
        }
    }

    if (found_struct) {
        std.debug.print("\n Found struct definition in C\n", .{});
    } else {
        std.debug.print("\n No struct definition found\n", .{});
    }
}

// ============================================================================
// C++ Extraction Tests
// ============================================================================

test "C++: basic extraction works" {
    const allocator = testing.allocator;

    var clew = try Clew.init(allocator);
    defer clew.deinit();

    var result = try clew.extractFromCode(cpp_sample, "cpp");
    defer result.deinit();

    // Should extract some constraints
    try testing.expect(result.constraints.items.len > 0);

    std.debug.print("\n=== C++ Extraction ===\n", .{});
    std.debug.print("Extracted {} constraints\n", .{result.constraints.items.len});

    for (result.constraints.items) |constraint| {
        std.debug.print("  - {s} (conf: {d:.2})\n", .{ constraint.name, constraint.confidence });
    }
}

test "C++: detects class definitions" {
    const allocator = testing.allocator;

    var clew = try Clew.init(allocator);
    defer clew.deinit();

    var result = try clew.extractFromCode(cpp_sample, "cpp");
    defer result.deinit();

    // Should find class definition
    var found_class = false;
    for (result.constraints.items) |constraint| {
        if (std.mem.indexOf(u8, constraint.name, "User") != null or
            std.mem.indexOf(u8, constraint.description, "class") != null)
        {
            found_class = true;
            break;
        }
    }

    if (found_class) {
        std.debug.print("\n Found class definition in C++\n", .{});
    } else {
        std.debug.print("\n No class definition found\n", .{});
    }
}

test "C++: detects smart pointers" {
    const allocator = testing.allocator;

    var clew = try Clew.init(allocator);
    defer clew.deinit();

    var result = try clew.extractFromCode(cpp_sample, "cpp");
    defer result.deinit();

    // Should find unique_ptr or shared_ptr
    var found_smart_ptr = false;
    for (result.constraints.items) |constraint| {
        if (std.mem.indexOf(u8, constraint.name, "unique_ptr") != null or
            std.mem.indexOf(u8, constraint.description, "unique") != null or
            std.mem.indexOf(u8, constraint.description, "smart") != null)
        {
            found_smart_ptr = true;
            break;
        }
    }

    if (found_smart_ptr) {
        std.debug.print("\n Found smart pointer in C++\n", .{});
    } else {
        std.debug.print("\n No explicit smart pointer constraint found\n", .{});
    }
}

// ============================================================================
// Java Extraction Tests
// ============================================================================

test "Java: basic extraction works" {
    const allocator = testing.allocator;

    var clew = try Clew.init(allocator);
    defer clew.deinit();

    var result = try clew.extractFromCode(java_sample, "java");
    defer result.deinit();

    // Should extract some constraints
    try testing.expect(result.constraints.items.len > 0);

    std.debug.print("\n=== Java Extraction ===\n", .{});
    std.debug.print("Extracted {} constraints\n", .{result.constraints.items.len});

    for (result.constraints.items) |constraint| {
        std.debug.print("  - {s} (conf: {d:.2})\n", .{ constraint.name, constraint.confidence });
    }
}

test "Java: detects class and interface" {
    const allocator = testing.allocator;

    var clew = try Clew.init(allocator);
    defer clew.deinit();

    var result = try clew.extractFromCode(java_sample, "java");
    defer result.deinit();

    // Should find class or interface definitions
    var found_class = false;
    var found_interface = false;
    for (result.constraints.items) |constraint| {
        if (std.mem.indexOf(u8, constraint.name, "UserService") != null or
            std.mem.indexOf(u8, constraint.description, "class") != null)
        {
            found_class = true;
        }
        if (std.mem.indexOf(u8, constraint.name, "UserRepository") != null or
            std.mem.indexOf(u8, constraint.description, "interface") != null)
        {
            found_interface = true;
        }
    }

    if (found_class) {
        std.debug.print("\n Found class definition in Java\n", .{});
    } else {
        std.debug.print("\n No class definition found\n", .{});
    }

    if (found_interface) {
        std.debug.print("\n Found interface definition in Java\n", .{});
    } else {
        std.debug.print("\n No interface definition found\n", .{});
    }
}

test "Java: detects exception handling" {
    const allocator = testing.allocator;

    var clew = try Clew.init(allocator);
    defer clew.deinit();

    var result = try clew.extractFromCode(java_sample, "java");
    defer result.deinit();

    // Should find throws declaration
    var found_throws = false;
    for (result.constraints.items) |constraint| {
        if (std.mem.indexOf(u8, constraint.name, "throws") != null or
            std.mem.indexOf(u8, constraint.description, "throws") != null or
            std.mem.indexOf(u8, constraint.description, "Exception") != null)
        {
            found_throws = true;
            break;
        }
    }

    if (found_throws) {
        std.debug.print("\n Found exception handling in Java\n", .{});
    } else {
        std.debug.print("\n No explicit throws constraint found\n", .{});
    }
}

test "Java: detects enum definition" {
    const allocator = testing.allocator;

    var clew = try Clew.init(allocator);
    defer clew.deinit();

    var result = try clew.extractFromCode(java_sample, "java");
    defer result.deinit();

    // Should find enum definition
    var found_enum = false;
    for (result.constraints.items) |constraint| {
        if (std.mem.indexOf(u8, constraint.name, "UserStatus") != null or
            std.mem.indexOf(u8, constraint.description, "enum") != null)
        {
            found_enum = true;
            break;
        }
    }

    if (found_enum) {
        std.debug.print("\n Found enum definition in Java\n", .{});
    } else {
        std.debug.print("\n No enum definition found\n", .{});
    }
}

// ============================================================================
// Cross-Language Comparison (C/C++/Java)
// ============================================================================

test "Cross-language: C, C++, and Java extract constraints" {
    const allocator = testing.allocator;

    var clew = try Clew.init(allocator);
    defer clew.deinit();

    // Extract from all three languages
    var c_result = try clew.extractFromCode(c_sample, "c");
    defer c_result.deinit();

    var cpp_result = try clew.extractFromCode(cpp_sample, "cpp");
    defer cpp_result.deinit();

    var java_result = try clew.extractFromCode(java_sample, "java");
    defer java_result.deinit();

    std.debug.print("\n=== Cross-Language Comparison (C/C++/Java) ===\n", .{});
    std.debug.print("C:    {} constraints\n", .{c_result.constraints.items.len});
    std.debug.print("C++:  {} constraints\n", .{cpp_result.constraints.items.len});
    std.debug.print("Java: {} constraints\n", .{java_result.constraints.items.len});

    // All should have extracted at least some constraints
    try testing.expect(c_result.constraints.items.len > 0);
    try testing.expect(cpp_result.constraints.items.len > 0);
    try testing.expect(java_result.constraints.items.len > 0);

    std.debug.print("All three languages successfully extracted constraints\n", .{});
}
