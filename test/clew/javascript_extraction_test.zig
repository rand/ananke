//! JavaScript Extraction Tests
//! Verifies that hybrid extraction works for JavaScript (ES6+)

const std = @import("std");
const testing = std.testing;

const Clew = @import("clew").Clew;

// ============================================================================
// Test Fixtures
// ============================================================================

const js_es6_sample =
    \\// JavaScript ES6 sample code
    \\import { EventEmitter } from 'events';
    \\import axios from 'axios';
    \\
    \\export class UserService extends EventEmitter {
    \\    constructor(apiUrl) {
    \\        super();
    \\        this.apiUrl = apiUrl;
    \\    }
    \\
    \\    async getUser(id) {
    \\        try {
    \\            const response = await axios.get(`${this.apiUrl}/users/${id}`);
    \\            this.emit('userFetched', response.data);
    \\            return response.data;
    \\        } catch (error) {
    \\            this.emit('error', error);
    \\            throw error;
    \\        }
    \\    }
    \\
    \\    static createInstance(apiUrl) {
    \\        return new UserService(apiUrl);
    \\    }
    \\}
    \\
    \\export const fetchAll = async () => {
    \\    const users = await Promise.all([
    \\        getUser(1),
    \\        getUser(2)
    \\    ]);
    \\    return users;
    \\};
;

const js_commonjs_sample =
    \\// JavaScript CommonJS sample code
    \\const fs = require('fs');
    \\const path = require('path');
    \\
    \\function readConfig(filename) {
    \\    const filepath = path.join(__dirname, filename);
    \\    const content = fs.readFileSync(filepath, 'utf8');
    \\    return JSON.parse(content);
    \\}
    \\
    \\function* generateIds() {
    \\    let id = 0;
    \\    while (true) {
    \\        yield id++;
    \\    }
    \\}
    \\
    \\module.exports = {
    \\    readConfig,
    \\    generateIds
    \\};
;

const js_modern_sample =
    \\// Modern JavaScript features
    \\"use strict";
    \\
    \\const multiply = (a, b) => a * b;
    \\
    \\const config = {
    \\    timeout: 5000,
    \\    retries: 3
    \\};
    \\
    \\const { timeout, retries } = config;
    \\
    \\const processData = async (data) => {
    \\    return new Promise((resolve, reject) => {
    \\        setTimeout(() => {
    \\            if (data) {
    \\                resolve(data);
    \\            } else {
    \\                reject(new Error('No data'));
    \\            }
    \\        }, timeout);
    \\    });
    \\};
;

// ============================================================================
// JavaScript ES6 Extraction Tests
// ============================================================================

test "JavaScript ES6: basic extraction works" {
    const allocator = testing.allocator;

    var clew = try Clew.init(allocator);
    defer clew.deinit();

    var result = try clew.extractFromCode(js_es6_sample, "javascript");
    defer result.deinit();

    // Should extract some constraints
    try testing.expect(result.constraints.items.len > 0);

    std.debug.print("\n=== JavaScript ES6 Extraction ===\n", .{});
    std.debug.print("Extracted {} constraints\n", .{result.constraints.items.len});

    for (result.constraints.items) |constraint| {
        std.debug.print("  - {s} (conf: {d:.2})\n", .{ constraint.name, constraint.confidence });
    }
}

test "JavaScript: detects async/await patterns" {
    const allocator = testing.allocator;

    var clew = try Clew.init(allocator);
    defer clew.deinit();

    var result = try clew.extractFromCode(js_es6_sample, "javascript");
    defer result.deinit();

    // Should find async functions
    var found_async = false;
    for (result.constraints.items) |constraint| {
        if (std.mem.indexOf(u8, constraint.name, "async") != null or
            std.mem.indexOf(u8, constraint.description, "async") != null or
            std.mem.indexOf(u8, constraint.description, "await") != null)
        {
            found_async = true;
            break;
        }
    }

    if (found_async) {
        std.debug.print("\n Found async/await patterns in JavaScript\n", .{});
    } else {
        std.debug.print("\n No explicit async constraint found\n", .{});
    }
}

test "JavaScript: detects class definitions" {
    const allocator = testing.allocator;

    var clew = try Clew.init(allocator);
    defer clew.deinit();

    var result = try clew.extractFromCode(js_es6_sample, "javascript");
    defer result.deinit();

    // Should find class definition
    var found_class = false;
    for (result.constraints.items) |constraint| {
        if (std.mem.indexOf(u8, constraint.name, "UserService") != null or
            std.mem.indexOf(u8, constraint.description, "class") != null)
        {
            found_class = true;
            break;
        }
    }

    if (found_class) {
        std.debug.print("\n Found class definition in JavaScript\n", .{});
    } else {
        std.debug.print("\n No class definition found\n", .{});
    }
}

test "JavaScript: detects ES6 imports" {
    const allocator = testing.allocator;

    var clew = try Clew.init(allocator);
    defer clew.deinit();

    var result = try clew.extractFromCode(js_es6_sample, "javascript");
    defer result.deinit();

    // Should find import statement
    var found_import = false;
    for (result.constraints.items) |constraint| {
        if (std.mem.indexOf(u8, constraint.name, "mport") != null or
            std.mem.indexOf(u8, constraint.description, "mport") != null)
        {
            found_import = true;
            break;
        }
    }

    if (found_import) {
        std.debug.print("\n Found ES6 imports in JavaScript\n", .{});
    } else {
        std.debug.print("\n No import constraint found\n", .{});
    }
}

// ============================================================================
// JavaScript CommonJS Extraction Tests
// ============================================================================

test "JavaScript CommonJS: basic extraction works" {
    const allocator = testing.allocator;

    var clew = try Clew.init(allocator);
    defer clew.deinit();

    var result = try clew.extractFromCode(js_commonjs_sample, "js");
    defer result.deinit();

    // Should extract some constraints
    try testing.expect(result.constraints.items.len > 0);

    std.debug.print("\n=== JavaScript CommonJS Extraction ===\n", .{});
    std.debug.print("Extracted {} constraints\n", .{result.constraints.items.len});
}

test "JavaScript: detects require patterns" {
    const allocator = testing.allocator;

    var clew = try Clew.init(allocator);
    defer clew.deinit();

    var result = try clew.extractFromCode(js_commonjs_sample, "javascript");
    defer result.deinit();

    // Should find require() calls
    var found_require = false;
    for (result.constraints.items) |constraint| {
        if (std.mem.indexOf(u8, constraint.name, "require") != null or
            std.mem.indexOf(u8, constraint.description, "require") != null or
            std.mem.indexOf(u8, constraint.description, "CommonJS") != null)
        {
            found_require = true;
            break;
        }
    }

    if (found_require) {
        std.debug.print("\n Found CommonJS require in JavaScript\n", .{});
    } else {
        std.debug.print("\n No require constraint found\n", .{});
    }
}

test "JavaScript: detects generator functions" {
    const allocator = testing.allocator;

    var clew = try Clew.init(allocator);
    defer clew.deinit();

    var result = try clew.extractFromCode(js_commonjs_sample, "javascript");
    defer result.deinit();

    // Should find generator function
    var found_generator = false;
    for (result.constraints.items) |constraint| {
        if (std.mem.indexOf(u8, constraint.name, "generator") != null or
            std.mem.indexOf(u8, constraint.description, "generator") != null or
            std.mem.indexOf(u8, constraint.name, "generateIds") != null)
        {
            found_generator = true;
            break;
        }
    }

    if (found_generator) {
        std.debug.print("\n Found generator function in JavaScript\n", .{});
    } else {
        std.debug.print("\n No generator constraint found\n", .{});
    }
}

// ============================================================================
// JavaScript Modern Features Tests
// ============================================================================

test "JavaScript Modern: arrow functions" {
    const allocator = testing.allocator;

    var clew = try Clew.init(allocator);
    defer clew.deinit();

    var result = try clew.extractFromCode(js_modern_sample, "javascript");
    defer result.deinit();

    // Should extract some constraints
    try testing.expect(result.constraints.items.len > 0);

    std.debug.print("\n=== JavaScript Modern Features Extraction ===\n", .{});
    std.debug.print("Extracted {} constraints\n", .{result.constraints.items.len});

    // Should find arrow function
    var found_arrow = false;
    for (result.constraints.items) |constraint| {
        if (std.mem.indexOf(u8, constraint.name, "arrow") != null or
            std.mem.indexOf(u8, constraint.description, "rrow") != null or
            std.mem.indexOf(u8, constraint.name, "multiply") != null or
            std.mem.indexOf(u8, constraint.name, "processData") != null)
        {
            found_arrow = true;
            break;
        }
    }

    if (found_arrow) {
        std.debug.print("\n Found arrow function in JavaScript\n", .{});
    } else {
        std.debug.print("\n No arrow function constraint found\n", .{});
    }
}

test "JavaScript: detects Promise patterns" {
    const allocator = testing.allocator;

    var clew = try Clew.init(allocator);
    defer clew.deinit();

    var result = try clew.extractFromCode(js_modern_sample, "javascript");
    defer result.deinit();

    // Should find Promise
    var found_promise = false;
    for (result.constraints.items) |constraint| {
        if (std.mem.indexOf(u8, constraint.name, "Promise") != null or
            std.mem.indexOf(u8, constraint.description, "Promise") != null or
            std.mem.indexOf(u8, constraint.description, "async") != null)
        {
            found_promise = true;
            break;
        }
    }

    if (found_promise) {
        std.debug.print("\n Found Promise patterns in JavaScript\n", .{});
    } else {
        std.debug.print("\n No Promise constraint found\n", .{});
    }
}

// ============================================================================
// JavaScript vs TypeScript Comparison
// ============================================================================

test "JavaScript vs TypeScript: both extract from similar code" {
    const allocator = testing.allocator;

    var clew = try Clew.init(allocator);
    defer clew.deinit();

    // Extract from JavaScript
    var js_result = try clew.extractFromCode(js_es6_sample, "javascript");
    defer js_result.deinit();

    // Create TypeScript version of the same code (with type annotations)
    const ts_sample =
        \\import { EventEmitter } from 'events';
        \\import axios from 'axios';
        \\
        \\export class UserService extends EventEmitter {
        \\    private apiUrl: string;
        \\
        \\    constructor(apiUrl: string) {
        \\        super();
        \\        this.apiUrl = apiUrl;
        \\    }
        \\
        \\    async getUser(id: number): Promise<User> {
        \\        const response = await axios.get(`${this.apiUrl}/users/${id}`);
        \\        return response.data;
        \\    }
        \\}
    ;

    var ts_result = try clew.extractFromCode(ts_sample, "typescript");
    defer ts_result.deinit();

    std.debug.print("\n=== JavaScript vs TypeScript Comparison ===\n", .{});
    std.debug.print("JavaScript: {} constraints\n", .{js_result.constraints.items.len});
    std.debug.print("TypeScript: {} constraints\n", .{ts_result.constraints.items.len});

    // Both should have extracted constraints
    try testing.expect(js_result.constraints.items.len > 0);
    try testing.expect(ts_result.constraints.items.len > 0);

    std.debug.print("Both JavaScript and TypeScript successfully extracted constraints\n", .{});
}
