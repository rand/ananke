// Test assertion parser for extracting constraints from Jest and pytest tests
const std = @import("std");
const root = @import("ananke");
const Constraint = root.types.constraint.Constraint;
const ConstraintKind = root.types.constraint.ConstraintKind;
const ConstraintSource = root.types.constraint.ConstraintSource;
const Severity = root.types.constraint.Severity;

/// Type of test assertion
pub const AssertionType = enum {
    equality,        // toBe, toEqual, ==
    type_check,      // isinstance, typeof
    error_expected,  // toThrow, raises
    property_check,  // toHaveProperty
    regex_match,     // toMatch
    membership,      // in, includes
    truthiness,      // toBeTruthy, toBeFalsy
    nullity,         // toBeNull, toBeUndefined
    comparison,      // toBeGreaterThan, toBeLessThan
};

/// Represents a single test assertion
pub const TestAssertion = struct {
    function_name: []const u8,
    assertion_type: AssertionType,
    expected_value: ?[]const u8,
    constraint_text: []const u8,
    line: u32,
    confidence: f32,

    /// Free allocated memory for this assertion
    pub fn deinit(self: *TestAssertion, allocator: std.mem.Allocator) void {
        allocator.free(self.function_name);
        if (self.expected_value) |val| {
            allocator.free(val);
        }
        allocator.free(self.constraint_text);
    }
};

/// Parser for test assertions in various testing frameworks
pub const TestAssertionParser = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) TestAssertionParser {
        return .{ .allocator = allocator };
    }

    /// Parse test assertions from source code
    pub fn parse(self: *TestAssertionParser, source: []const u8, language: Language) ![]TestAssertion {
        return switch (language) {
            .typescript => try self.parseJestAssertions(source),
            .python => try self.parsePytestAssertions(source),
        };
    }

    /// Parse Jest assertions from TypeScript/JavaScript test code
    fn parseJestAssertions(self: *TestAssertionParser, source: []const u8) ![]TestAssertion {
        var assertions = std.ArrayList(TestAssertion){};
        errdefer {
            for (assertions.items) |*assertion| {
                assertion.deinit(self.allocator);
            }
            assertions.deinit();
        }

        var line_num: u32 = 1;
        var lines = std.mem.splitScalar(u8, source, '\n');

        while (lines.next()) |line| : (line_num += 1) {
            const trimmed = std.mem.trim(u8, line, " \t\r");

            // Skip non-assertion lines
            if (!std.mem.containsAtLeast(u8, trimmed, 1, "expect(")) continue;

            // Parse expect() assertions
            if (try self.parseExpectAssertion(trimmed, line_num)) |assertion| {
                try assertions.append(self.allocator, assertion);
            }
        }

        return try assertions.toOwnedSlice(self.allocator);
    }

    /// Parse a single Jest expect() assertion
    fn parseExpectAssertion(self: *TestAssertionParser, line: []const u8, line_num: u32) !?TestAssertion {
        const expect_pos = std.mem.indexOf(u8, line, "expect(") orelse return null;
        const start = expect_pos + 7;

        // Find matching closing parenthesis for expect()
        var depth: i32 = 1;
        var end = start;
        while (end < line.len and depth > 0) : (end += 1) {
            if (line[end] == '(') depth += 1
            else if (line[end] == ')') depth -= 1;
        }
        if (depth != 0) return null;

        const expect_content = line[start..end - 1];

        // Extract function name if it's a function call
        const func_name = try self.extractFunctionName(expect_content);

        // Parse the assertion matcher (toBe, toEqual, etc.)
        const matcher_start = end + 1;
        if (matcher_start >= line.len or line[matcher_start - 1] != ')' or
            (matcher_start < line.len and line[matcher_start] != '.')) {
            if (func_name) |name| self.allocator.free(name);
            return null;
        }

        // Find the matcher method
        const matcher_info = try self.parseJestMatcher(line[matcher_start..], func_name);
        if (matcher_info) |info| {
            const assertion_type = info.assertion_type;
            const expected_value = info.expected_value;

            // Create constraint text
            const constraint_text = try self.createConstraintText(
                func_name orelse "expression",
                assertion_type,
                expected_value,
            );

            return TestAssertion{
                .function_name = func_name orelse try self.allocator.dupe(u8, "unknown"),
                .assertion_type = assertion_type,
                .expected_value = expected_value,
                .constraint_text = constraint_text,
                .line = line_num,
                .confidence = 0.9,
            };
        }

        if (func_name) |name| self.allocator.free(name);
        return null;
    }

    /// Extract function name from expression like "validateEmail('test@example.com')"
    fn extractFunctionName(self: *TestAssertionParser, expr: []const u8) !?[]const u8 {
        const trimmed = std.mem.trim(u8, expr, " ");

        // Look for function call pattern
        const paren_pos = std.mem.indexOf(u8, trimmed, "(");
        if (paren_pos) |pos| {
            if (pos > 0) {
                // Extract function name before parenthesis
                var name_start: usize = 0;

                // Skip any object/module prefixes (e.g., "utils.validateEmail")
                var i = pos;
                while (i > 0) : (i -= 1) {
                    const c = trimmed[i - 1];
                    if (!std.ascii.isAlphanumeric(c) and c != '_' and c != '.') {
                        name_start = i;
                        break;
                    }
                }

                const name = trimmed[name_start..pos];

                // Skip if it's a method call on the result (contains dots after first segment)
                const dot_pos = std.mem.indexOf(u8, name, ".");
                if (dot_pos != null) {
                    // Take only the last segment after the last dot
                    var last_dot: usize = 0;
                    var j: usize = 0;
                    while (j < name.len) : (j += 1) {
                        if (name[j] == '.') last_dot = j + 1;
                    }
                    return try self.allocator.dupe(u8, name[last_dot..]);
                }

                return try self.allocator.dupe(u8, name);
            }
        }

        return null;
    }

    /// Parse Jest matcher and extract assertion type and expected value
    fn parseJestMatcher(self: *TestAssertionParser, matcher_str: []const u8, func_name: ?[]const u8) !?struct {
        assertion_type: AssertionType,
        expected_value: ?[]const u8,
    } {
        _ = func_name;

        if (!std.mem.startsWith(u8, matcher_str, ".")) return null;

        const content = matcher_str[1..];

        // Parse different matcher types
        if (std.mem.startsWith(u8, content, "toBe(")) {
            const value = try self.extractMatcherArgument(content[5..]);
            return .{
                .assertion_type = .equality,
                .expected_value = value,
            };
        } else if (std.mem.startsWith(u8, content, "toEqual(")) {
            const value = try self.extractMatcherArgument(content[8..]);
            return .{
                .assertion_type = .equality,
                .expected_value = value,
            };
        } else if (std.mem.startsWith(u8, content, "toThrow(") or std.mem.startsWith(u8, content, "toThrow()")) {
            const value = if (std.mem.startsWith(u8, content, "toThrow()"))
                null
            else
                try self.extractMatcherArgument(content[8..]);
            return .{
                .assertion_type = .error_expected,
                .expected_value = value,
            };
        } else if (std.mem.startsWith(u8, content, "toHaveProperty(")) {
            const value = try self.extractMatcherArgument(content[15..]);
            return .{
                .assertion_type = .property_check,
                .expected_value = value,
            };
        } else if (std.mem.startsWith(u8, content, "toMatch(")) {
            const value = try self.extractMatcherArgument(content[8..]);
            return .{
                .assertion_type = .regex_match,
                .expected_value = value,
            };
        } else if (std.mem.startsWith(u8, content, "toBeTruthy()")) {
            return .{
                .assertion_type = .truthiness,
                .expected_value = try self.allocator.dupe(u8, "true"),
            };
        } else if (std.mem.startsWith(u8, content, "toBeFalsy()")) {
            return .{
                .assertion_type = .truthiness,
                .expected_value = try self.allocator.dupe(u8, "false"),
            };
        } else if (std.mem.startsWith(u8, content, "toBeNull()")) {
            return .{
                .assertion_type = .nullity,
                .expected_value = try self.allocator.dupe(u8, "null"),
            };
        } else if (std.mem.startsWith(u8, content, "toBeUndefined()")) {
            return .{
                .assertion_type = .nullity,
                .expected_value = try self.allocator.dupe(u8, "undefined"),
            };
        } else if (std.mem.startsWith(u8, content, "toBeGreaterThan(")) {
            const value = try self.extractMatcherArgument(content[16..]);
            return .{
                .assertion_type = .comparison,
                .expected_value = value,
            };
        } else if (std.mem.startsWith(u8, content, "toBeLessThan(")) {
            const value = try self.extractMatcherArgument(content[13..]);
            return .{
                .assertion_type = .comparison,
                .expected_value = value,
            };
        } else if (std.mem.startsWith(u8, content, "toContain(")) {
            const value = try self.extractMatcherArgument(content[10..]);
            return .{
                .assertion_type = .membership,
                .expected_value = value,
            };
        }

        return null;
    }

    /// Extract argument from matcher call like "toBe(true)"
    fn extractMatcherArgument(self: *TestAssertionParser, arg_str: []const u8) !?[]const u8 {
        // Find closing parenthesis
        const close_pos = std.mem.indexOf(u8, arg_str, ")") orelse return null;
        if (close_pos == 0) return null;

        const arg = std.mem.trim(u8, arg_str[0..close_pos], " ");
        if (arg.len == 0) return null;

        return try self.allocator.dupe(u8, arg);
    }

    /// Parse pytest assertions from Python test code
    fn parsePytestAssertions(self: *TestAssertionParser, source: []const u8) ![]TestAssertion {
        var assertions = std.ArrayList(TestAssertion){};
        errdefer {
            for (assertions.items) |*assertion| {
                assertion.deinit(self.allocator);
            }
            assertions.deinit();
        }

        var line_num: u32 = 1;
        var lines = std.mem.splitScalar(u8, source, '\n');

        while (lines.next()) |line| : (line_num += 1) {
            const trimmed = std.mem.trim(u8, line, " \t\r");

            // Parse different assertion patterns
            if (std.mem.startsWith(u8, trimmed, "assert ")) {
                if (try self.parsePytestAssert(trimmed[7..], line_num)) |assertion| {
                    try assertions.append(self.allocator, assertion);
                }
            } else if (std.mem.containsAtLeast(u8, trimmed, 1, "pytest.raises(")) {
                if (try self.parsePytestRaises(trimmed, line_num)) |assertion| {
                    try assertions.append(self.allocator, assertion);
                }
            }
        }

        return try assertions.toOwnedSlice(self.allocator);
    }

    /// Parse a pytest assert statement
    fn parsePytestAssert(self: *TestAssertionParser, assert_content: []const u8, line_num: u32) !?TestAssertion {
        const trimmed = std.mem.trim(u8, assert_content, " ");

        // Parse different assertion patterns
        if (std.mem.containsAtLeast(u8, trimmed, 1, " == ")) {
            return try self.parsePytestEquality(trimmed, line_num);
        } else if (std.mem.containsAtLeast(u8, trimmed, 1, " != ")) {
            return try self.parsePytestInequality(trimmed, line_num);
        } else if (std.mem.containsAtLeast(u8, trimmed, 1, "isinstance(")) {
            return try self.parsePytestIsInstance(trimmed, line_num);
        } else if (std.mem.containsAtLeast(u8, trimmed, 1, " in ")) {
            return try self.parsePytestMembership(trimmed, line_num);
        } else if (std.mem.containsAtLeast(u8, trimmed, 1, " > ") or
                   std.mem.containsAtLeast(u8, trimmed, 1, " < ") or
                   std.mem.containsAtLeast(u8, trimmed, 1, " >= ") or
                   std.mem.containsAtLeast(u8, trimmed, 1, " <= ")) {
            return try self.parsePytestComparison(trimmed, line_num);
        }

        // Simple assertion (just checking truthiness)
        const func_name = try self.extractPythonFunctionName(trimmed);
        if (func_name) |name| {
            const constraint_text = try std.fmt.allocPrint(
                self.allocator,
                "{s} should return truthy value",
                .{name},
            );

            return TestAssertion{
                .function_name = name,
                .assertion_type = .truthiness,
                .expected_value = try self.allocator.dupe(u8, "True"),
                .constraint_text = constraint_text,
                .line = line_num,
                .confidence = 0.8,
            };
        }

        return null;
    }

    /// Parse pytest equality assertion (assert x == y)
    fn parsePytestEquality(self: *TestAssertionParser, expr: []const u8, line_num: u32) !?TestAssertion {
        const eq_pos = std.mem.indexOf(u8, expr, " == ") orelse return null;

        const left = std.mem.trim(u8, expr[0..eq_pos], " ");
        const right = std.mem.trim(u8, expr[eq_pos + 4..], " ");

        const func_name = try self.extractPythonFunctionName(left);
        if (func_name) |name| {
            const constraint_text = try std.fmt.allocPrint(
                self.allocator,
                "{s} should return {s}",
                .{ name, right },
            );

            return TestAssertion{
                .function_name = name,
                .assertion_type = .equality,
                .expected_value = try self.allocator.dupe(u8, right),
                .constraint_text = constraint_text,
                .line = line_num,
                .confidence = 0.9,
            };
        }

        return null;
    }

    /// Parse pytest inequality assertion (assert x != y)
    fn parsePytestInequality(self: *TestAssertionParser, expr: []const u8, line_num: u32) !?TestAssertion {
        const neq_pos = std.mem.indexOf(u8, expr, " != ") orelse return null;

        const left = std.mem.trim(u8, expr[0..neq_pos], " ");
        const right = std.mem.trim(u8, expr[neq_pos + 4..], " ");

        const func_name = try self.extractPythonFunctionName(left);
        if (func_name) |name| {
            const constraint_text = try std.fmt.allocPrint(
                self.allocator,
                "{s} should not return {s}",
                .{ name, right },
            );

            return TestAssertion{
                .function_name = name,
                .assertion_type = .equality,
                .expected_value = try self.allocator.dupe(u8, right),
                .constraint_text = constraint_text,
                .line = line_num,
                .confidence = 0.9,
            };
        }

        return null;
    }

    /// Parse pytest isinstance assertion
    fn parsePytestIsInstance(self: *TestAssertionParser, expr: []const u8, line_num: u32) !?TestAssertion {
        const isinstance_pos = std.mem.indexOf(u8, expr, "isinstance(") orelse return null;
        const start = isinstance_pos + 11;

        // Find the comma separating object and type
        const comma_pos = std.mem.indexOf(u8, expr[start..], ",") orelse return null;
        const obj_expr = std.mem.trim(u8, expr[start..start + comma_pos], " ");

        // Find the closing parenthesis
        const close_pos = std.mem.indexOf(u8, expr[start + comma_pos..], ")") orelse return null;
        const type_expr = std.mem.trim(u8, expr[start + comma_pos + 1..start + comma_pos + close_pos], " ");

        const func_name = try self.extractPythonFunctionName(obj_expr);
        if (func_name) |name| {
            const constraint_text = try std.fmt.allocPrint(
                self.allocator,
                "{s} should return instance of {s}",
                .{ name, type_expr },
            );

            return TestAssertion{
                .function_name = name,
                .assertion_type = .type_check,
                .expected_value = try self.allocator.dupe(u8, type_expr),
                .constraint_text = constraint_text,
                .line = line_num,
                .confidence = 0.95,
            };
        }

        return null;
    }

    /// Parse pytest membership assertion (assert x in y)
    fn parsePytestMembership(self: *TestAssertionParser, expr: []const u8, line_num: u32) !?TestAssertion {
        const in_pos = std.mem.indexOf(u8, expr, " in ") orelse return null;

        const left = std.mem.trim(u8, expr[0..in_pos], " ");
        const right = std.mem.trim(u8, expr[in_pos + 4..], " ");

        // Check if left side is a function call result
        const func_name = try self.extractPythonFunctionName(right);
        if (func_name) |name| {
            const constraint_text = try std.fmt.allocPrint(
                self.allocator,
                "{s} should contain {s}",
                .{ name, left },
            );

            return TestAssertion{
                .function_name = name,
                .assertion_type = .membership,
                .expected_value = try self.allocator.dupe(u8, left),
                .constraint_text = constraint_text,
                .line = line_num,
                .confidence = 0.85,
            };
        }

        return null;
    }

    /// Parse pytest comparison assertion (>, <, >=, <=)
    fn parsePytestComparison(self: *TestAssertionParser, expr: []const u8, line_num: u32) !?TestAssertion {
        const operators = [_][]const u8{ " >= ", " <= ", " > ", " < " };

        for (operators) |op| {
            if (std.mem.indexOf(u8, expr, op)) |op_pos| {
                const left = std.mem.trim(u8, expr[0..op_pos], " ");
                const right = std.mem.trim(u8, expr[op_pos + op.len..], " ");

                const func_name = try self.extractPythonFunctionName(left);
                if (func_name) |name| {
                    const op_text = std.mem.trim(u8, op, " ");
                    const constraint_text = try std.fmt.allocPrint(
                        self.allocator,
                        "{s} should be {s} {s}",
                        .{ name, op_text, right },
                    );

                    return TestAssertion{
                        .function_name = name,
                        .assertion_type = .comparison,
                        .expected_value = try self.allocator.dupe(u8, right),
                        .constraint_text = constraint_text,
                        .line = line_num,
                        .confidence = 0.85,
                    };
                }
            }
        }

        return null;
    }

    /// Parse pytest.raises context manager
    fn parsePytestRaises(self: *TestAssertionParser, line: []const u8, line_num: u32) !?TestAssertion {
        const raises_pos = std.mem.indexOf(u8, line, "pytest.raises(") orelse return null;
        const start = raises_pos + 14;

        // Find the exception type
        const close_pos = std.mem.indexOf(u8, line[start..], ")") orelse return null;
        const exception_type = std.mem.trim(u8, line[start..start + close_pos], " ");

        // Try to find function name in the with block (this is approximate)
        const constraint_text = try std.fmt.allocPrint(
            self.allocator,
            "Function should raise {s}",
            .{exception_type},
        );

        return TestAssertion{
            .function_name = try self.allocator.dupe(u8, "function"),
            .assertion_type = .error_expected,
            .expected_value = try self.allocator.dupe(u8, exception_type),
            .constraint_text = constraint_text,
            .line = line_num,
            .confidence = 0.85,
        };
    }

    /// Extract Python function name from expression
    fn extractPythonFunctionName(self: *TestAssertionParser, expr: []const u8) !?[]const u8 {
        const trimmed = std.mem.trim(u8, expr, " ");

        // Look for function call pattern
        const paren_pos = std.mem.indexOf(u8, trimmed, "(");
        if (paren_pos) |pos| {
            if (pos > 0) {
                // Extract function name before parenthesis
                var name_start: usize = 0;
                var i = pos;
                while (i > 0) : (i -= 1) {
                    const c = trimmed[i - 1];
                    if (!std.ascii.isAlphanumeric(c) and c != '_' and c != '.') {
                        name_start = i;
                        break;
                    }
                }

                const name = trimmed[name_start..pos];

                // Handle module.function pattern
                const dot_pos = std.mem.lastIndexOf(u8, name, ".");
                if (dot_pos) |d_pos| {
                    return try self.allocator.dupe(u8, name[d_pos + 1..]);
                }

                return try self.allocator.dupe(u8, name);
            }
        }

        return null;
    }

    /// Create constraint text from assertion components
    fn createConstraintText(
        self: *TestAssertionParser,
        func_name: []const u8,
        assertion_type: AssertionType,
        expected_value: ?[]const u8,
    ) ![]const u8 {
        return switch (assertion_type) {
            .equality => blk: {
                if (expected_value) |val| {
                    break :blk try std.fmt.allocPrint(
                        self.allocator,
                        "Function {s} should return {s}",
                        .{ func_name, val },
                    );
                } else {
                    break :blk try std.fmt.allocPrint(
                        self.allocator,
                        "Function {s} should return expected value",
                        .{func_name},
                    );
                }
            },
            .type_check => blk: {
                if (expected_value) |val| {
                    break :blk try std.fmt.allocPrint(
                        self.allocator,
                        "Function {s} should return type {s}",
                        .{ func_name, val },
                    );
                } else {
                    break :blk try std.fmt.allocPrint(
                        self.allocator,
                        "Function {s} should return correct type",
                        .{func_name},
                    );
                }
            },
            .error_expected => blk: {
                if (expected_value) |val| {
                    break :blk try std.fmt.allocPrint(
                        self.allocator,
                        "Function {s} should throw {s}",
                        .{ func_name, val },
                    );
                } else {
                    break :blk try std.fmt.allocPrint(
                        self.allocator,
                        "Function {s} should throw an error",
                        .{func_name},
                    );
                }
            },
            .property_check => blk: {
                if (expected_value) |val| {
                    break :blk try std.fmt.allocPrint(
                        self.allocator,
                        "Result of {s} should have property {s}",
                        .{ func_name, val },
                    );
                } else {
                    break :blk try std.fmt.allocPrint(
                        self.allocator,
                        "Result of {s} should have expected properties",
                        .{func_name},
                    );
                }
            },
            .regex_match => blk: {
                if (expected_value) |val| {
                    break :blk try std.fmt.allocPrint(
                        self.allocator,
                        "Function {s} result should match pattern {s}",
                        .{ func_name, val },
                    );
                } else {
                    break :blk try std.fmt.allocPrint(
                        self.allocator,
                        "Function {s} result should match pattern",
                        .{func_name},
                    );
                }
            },
            .membership => blk: {
                if (expected_value) |val| {
                    break :blk try std.fmt.allocPrint(
                        self.allocator,
                        "Result of {s} should contain {s}",
                        .{ func_name, val },
                    );
                } else {
                    break :blk try std.fmt.allocPrint(
                        self.allocator,
                        "Result of {s} should contain expected value",
                        .{func_name},
                    );
                }
            },
            .truthiness => blk: {
                if (expected_value) |val| {
                    if (std.mem.eql(u8, val, "false") or std.mem.eql(u8, val, "False")) {
                        break :blk try std.fmt.allocPrint(
                            self.allocator,
                            "Function {s} should return falsy value",
                            .{func_name},
                        );
                    }
                }
                break :blk try std.fmt.allocPrint(
                    self.allocator,
                    "Function {s} should return truthy value",
                    .{func_name},
                );
            },
            .nullity => blk: {
                if (expected_value) |val| {
                    break :blk try std.fmt.allocPrint(
                        self.allocator,
                        "Function {s} should return {s}",
                        .{ func_name, val },
                    );
                } else {
                    break :blk try std.fmt.allocPrint(
                        self.allocator,
                        "Function {s} should return null/undefined",
                        .{func_name},
                    );
                }
            },
            .comparison => blk: {
                if (expected_value) |val| {
                    break :blk try std.fmt.allocPrint(
                        self.allocator,
                        "Function {s} result should be compared with {s}",
                        .{ func_name, val },
                    );
                } else {
                    break :blk try std.fmt.allocPrint(
                        self.allocator,
                        "Function {s} result should meet comparison criteria",
                        .{func_name},
                    );
                }
            },
        };
    }

    /// Convert test assertions to constraints
    pub fn toConstraints(self: *TestAssertionParser, assertions: []const TestAssertion) ![]Constraint {
        var constraints = std.ArrayList(Constraint){};
        errdefer constraints.deinit();

        for (assertions) |assertion| {
            const constraint = Constraint{
                .id = 0,
                .name = try std.fmt.allocPrint(
                    self.allocator,
                    "test_{s}_{s}",
                    .{ assertion.function_name, @tagName(assertion.assertion_type) },
                ),
                .description = assertion.constraint_text,
                .kind = switch (assertion.assertion_type) {
                    .type_check => .type_safety,
                    .error_expected => .semantic,
                    else => .semantic,
                },
                .source = .Test_Mining,
                .enforcement = switch (assertion.assertion_type) {
                    .type_check => .Structural,
                    else => .Semantic,
                },
                .priority = .High,
                .confidence = assertion.confidence,
                .frequency = 1,
                .severity = .warning,
                .origin_line = assertion.line,
            };

            try constraints.append(self.allocator, constraint);
        }

        return try constraints.toOwnedSlice(self.allocator);
    }
};

/// Language identifier for different test file types
pub const Language = enum {
    typescript,
    python,
};

/// Detect test file type based on file extension
pub fn detectTestFileType(path: []const u8) ?Language {
    if (std.mem.endsWith(u8, path, ".test.ts") or
        std.mem.endsWith(u8, path, ".spec.ts") or
        std.mem.endsWith(u8, path, "_test.ts") or
        std.mem.endsWith(u8, path, ".test.js") or
        std.mem.endsWith(u8, path, ".spec.js") or
        std.mem.endsWith(u8, path, "_test.js")) {
        return .typescript;
    } else if (std.mem.startsWith(u8, std.fs.path.basename(path), "test_") or
               std.mem.endsWith(u8, path, "_test.py")) {
        return .python;
    }
    return null;
}

/// Check if a file is a test file based on naming conventions
pub fn isTestFile(path: []const u8) bool {
    return detectTestFileType(path) != null;
}