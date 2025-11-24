// Tests for test assertion parser
const std = @import("std");
const testing = std.testing;
const root = @import("ananke");
const test_assertions = @import("clew/parsers/test_assertions.zig");
const ConstraintKind = root.types.constraint.ConstraintKind;
const ConstraintSource = root.types.constraint.ConstraintSource;

test "parse Jest toBe assertion" {
    const allocator = testing.allocator;
    const source =
        \\test('validates email', () => {
        \\    expect(validateEmail('test@example.com')).toBe(true);
        \\    expect(validateEmail('invalid')).toBe(false);
        \\});
    ;

    var parser = test_assertions.TestAssertionParser.init(allocator);
    const assertions = try parser.parse(source, .typescript);
    defer {
        for (assertions) |*assertion| {
            var mut_assertion = assertion;
            mut_assertion.deinit(allocator);
        }
        allocator.free(assertions);
    }

    try testing.expectEqual(@as(usize, 2), assertions.len);

    // First assertion
    try testing.expectEqualStrings("validateEmail", assertions[0].function_name);
    try testing.expectEqual(test_assertions.AssertionType.equality, assertions[0].assertion_type);
    try testing.expect(assertions[0].expected_value != null);
    try testing.expectEqualStrings("true", assertions[0].expected_value.?);
    try testing.expectEqual(@as(u32, 2), assertions[0].line);

    // Second assertion
    try testing.expectEqualStrings("validateEmail", assertions[1].function_name);
    try testing.expectEqual(test_assertions.AssertionType.equality, assertions[1].assertion_type);
    try testing.expectEqualStrings("false", assertions[1].expected_value.?);
    try testing.expectEqual(@as(u32, 3), assertions[1].line);
}

test "parse Jest toThrow assertion" {
    const allocator = testing.allocator;
    const source =
        \\test('handles errors', () => {
        \\    expect(() => processInvalid(null)).toThrow('Input cannot be null');
        \\    expect(() => processInvalid(undefined)).toThrow();
        \\});
    ;

    var parser = test_assertions.TestAssertionParser.init(allocator);
    const assertions = try parser.parse(source, .typescript);
    defer {
        for (assertions) |*assertion| {
            var mut_assertion = assertion;
            mut_assertion.deinit(allocator);
        }
        allocator.free(assertions);
    }

    try testing.expectEqual(@as(usize, 2), assertions.len);

    // First assertion with error message
    try testing.expectEqual(test_assertions.AssertionType.error_expected, assertions[0].assertion_type);
    try testing.expect(assertions[0].expected_value != null);
    try testing.expectEqualStrings("'Input cannot be null'", assertions[0].expected_value.?);

    // Second assertion without error message
    try testing.expectEqual(test_assertions.AssertionType.error_expected, assertions[1].assertion_type);
}

test "parse Jest toHaveProperty assertion" {
    const allocator = testing.allocator;
    const source =
        \\test('checks properties', () => {
        \\    expect(user).toHaveProperty('id');
        \\    expect(config).toHaveProperty('database.host');
        \\});
    ;

    var parser = test_assertions.TestAssertionParser.init(allocator);
    const assertions = try parser.parse(source, .typescript);
    defer {
        for (assertions) |*assertion| {
            var mut_assertion = assertion;
            mut_assertion.deinit(allocator);
        }
        allocator.free(assertions);
    }

    try testing.expectEqual(@as(usize, 2), assertions.len);

    try testing.expectEqual(test_assertions.AssertionType.property_check, assertions[0].assertion_type);
    try testing.expectEqualStrings("'id'", assertions[0].expected_value.?);

    try testing.expectEqual(test_assertions.AssertionType.property_check, assertions[1].assertion_type);
    try testing.expectEqualStrings("'database.host'", assertions[1].expected_value.?);
}

test "parse Jest toMatch assertion" {
    const allocator = testing.allocator;
    const source =
        \\test('matches patterns', () => {
        \\    expect(formatPhone('1234567890')).toMatch(/\\d{3}-\\d{3}-\\d{4}/);
        \\});
    ;

    var parser = test_assertions.TestAssertionParser.init(allocator);
    const assertions = try parser.parse(source, .typescript);
    defer {
        for (assertions) |*assertion| {
            var mut_assertion = assertion;
            mut_assertion.deinit(allocator);
        }
        allocator.free(assertions);
    }

    try testing.expectEqual(@as(usize, 1), assertions.len);
    try testing.expectEqualStrings("formatPhone", assertions[0].function_name);
    try testing.expectEqual(test_assertions.AssertionType.regex_match, assertions[0].assertion_type);
}

test "parse Jest truthiness assertions" {
    const allocator = testing.allocator;
    const source =
        \\test('checks truthiness', () => {
        \\    expect(isActive()).toBeTruthy();
        \\    expect(isDisabled()).toBeFalsy();
        \\});
    ;

    var parser = test_assertions.TestAssertionParser.init(allocator);
    const assertions = try parser.parse(source, .typescript);
    defer {
        for (assertions) |*assertion| {
            var mut_assertion = assertion;
            mut_assertion.deinit(allocator);
        }
        allocator.free(assertions);
    }

    try testing.expectEqual(@as(usize, 2), assertions.len);

    try testing.expectEqualStrings("isActive", assertions[0].function_name);
    try testing.expectEqual(test_assertions.AssertionType.truthiness, assertions[0].assertion_type);
    try testing.expectEqualStrings("true", assertions[0].expected_value.?);

    try testing.expectEqualStrings("isDisabled", assertions[1].function_name);
    try testing.expectEqual(test_assertions.AssertionType.truthiness, assertions[1].assertion_type);
    try testing.expectEqualStrings("false", assertions[1].expected_value.?);
}

test "parse Jest comparison assertions" {
    const allocator = testing.allocator;
    const source =
        \\test('compares values', () => {
        \\    expect(getScore()).toBeGreaterThan(0);
        \\    expect(getAge()).toBeLessThan(150);
        \\});
    ;

    var parser = test_assertions.TestAssertionParser.init(allocator);
    const assertions = try parser.parse(source, .typescript);
    defer {
        for (assertions) |*assertion| {
            var mut_assertion = assertion;
            mut_assertion.deinit(allocator);
        }
        allocator.free(assertions);
    }

    try testing.expectEqual(@as(usize, 2), assertions.len);

    try testing.expectEqualStrings("getScore", assertions[0].function_name);
    try testing.expectEqual(test_assertions.AssertionType.comparison, assertions[0].assertion_type);
    try testing.expectEqualStrings("0", assertions[0].expected_value.?);

    try testing.expectEqualStrings("getAge", assertions[1].function_name);
    try testing.expectEqual(test_assertions.AssertionType.comparison, assertions[1].assertion_type);
    try testing.expectEqualStrings("150", assertions[1].expected_value.?);
}

test "parse pytest equality assertion" {
    const allocator = testing.allocator;
    const source =
        \\def test_basic_math():
        \\    assert add(2, 3) == 5
        \\    assert multiply(4, 7) == 28
    ;

    var parser = test_assertions.TestAssertionParser.init(allocator);
    const assertions = try parser.parse(source, .python);
    defer {
        for (assertions) |*assertion| {
            var mut_assertion = assertion;
            mut_assertion.deinit(allocator);
        }
        allocator.free(assertions);
    }

    try testing.expectEqual(@as(usize, 2), assertions.len);

    try testing.expectEqualStrings("add", assertions[0].function_name);
    try testing.expectEqual(test_assertions.AssertionType.equality, assertions[0].assertion_type);
    try testing.expectEqualStrings("5", assertions[0].expected_value.?);

    try testing.expectEqualStrings("multiply", assertions[1].function_name);
    try testing.expectEqual(test_assertions.AssertionType.equality, assertions[1].assertion_type);
    try testing.expectEqualStrings("28", assertions[1].expected_value.?);
}

test "parse pytest isinstance assertion" {
    const allocator = testing.allocator;
    const source =
        \\def test_types():
        \\    assert isinstance(parse_int('123'), int)
        \\    assert isinstance(parse_float('3.14'), float)
    ;

    var parser = test_assertions.TestAssertionParser.init(allocator);
    const assertions = try parser.parse(source, .python);
    defer {
        for (assertions) |*assertion| {
            var mut_assertion = assertion;
            mut_assertion.deinit(allocator);
        }
        allocator.free(assertions);
    }

    try testing.expectEqual(@as(usize, 2), assertions.len);

    try testing.expectEqualStrings("parse_int", assertions[0].function_name);
    try testing.expectEqual(test_assertions.AssertionType.type_check, assertions[0].assertion_type);
    try testing.expectEqualStrings("int", assertions[0].expected_value.?);

    try testing.expectEqualStrings("parse_float", assertions[1].function_name);
    try testing.expectEqual(test_assertions.AssertionType.type_check, assertions[1].assertion_type);
    try testing.expectEqualStrings("float", assertions[1].expected_value.?);
}

test "parse pytest raises assertion" {
    const allocator = testing.allocator;
    const source =
        \\def test_errors():
        \\    with pytest.raises(ValueError):
        \\        validate_age(-1)
        \\    with pytest.raises(TypeError, match="Invalid type"):
        \\        process_data("wrong_type")
    ;

    var parser = test_assertions.TestAssertionParser.init(allocator);
    const assertions = try parser.parse(source, .python);
    defer {
        for (assertions) |*assertion| {
            var mut_assertion = assertion;
            mut_assertion.deinit(allocator);
        }
        allocator.free(assertions);
    }

    try testing.expectEqual(@as(usize, 2), assertions.len);

    try testing.expectEqual(test_assertions.AssertionType.error_expected, assertions[0].assertion_type);
    try testing.expectEqualStrings("ValueError", assertions[0].expected_value.?);

    try testing.expectEqual(test_assertions.AssertionType.error_expected, assertions[1].assertion_type);
    // Note: We're not parsing the match parameter yet, just the exception type
    try testing.expectEqualStrings("TypeError", assertions[1].expected_value.?);
}

test "parse pytest membership assertion" {
    const allocator = testing.allocator;
    const source =
        \\def test_membership():
        \\    assert 'hello' in split_words('hello world')
        \\    assert 'b' in parse_csv('a,b,c')
    ;

    var parser = test_assertions.TestAssertionParser.init(allocator);
    const assertions = try parser.parse(source, .python);
    defer {
        for (assertions) |*assertion| {
            var mut_assertion = assertion;
            mut_assertion.deinit(allocator);
        }
        allocator.free(assertions);
    }

    try testing.expectEqual(@as(usize, 2), assertions.len);

    try testing.expectEqualStrings("split_words", assertions[0].function_name);
    try testing.expectEqual(test_assertions.AssertionType.membership, assertions[0].assertion_type);
    try testing.expectEqualStrings("'hello'", assertions[0].expected_value.?);

    try testing.expectEqualStrings("parse_csv", assertions[1].function_name);
    try testing.expectEqual(test_assertions.AssertionType.membership, assertions[1].assertion_type);
    try testing.expectEqualStrings("'b'", assertions[1].expected_value.?);
}

test "parse pytest comparison assertions" {
    const allocator = testing.allocator;
    const source =
        \\def test_comparisons():
        \\    assert get_score() > 0
        \\    assert get_age() < 150
        \\    assert get_percentage() >= 0
        \\    assert get_discount() <= 100
    ;

    var parser = test_assertions.TestAssertionParser.init(allocator);
    const assertions = try parser.parse(source, .python);
    defer {
        for (assertions) |*assertion| {
            var mut_assertion = assertion;
            mut_assertion.deinit(allocator);
        }
        allocator.free(assertions);
    }

    try testing.expectEqual(@as(usize, 4), assertions.len);

    try testing.expectEqualStrings("get_score", assertions[0].function_name);
    try testing.expectEqual(test_assertions.AssertionType.comparison, assertions[0].assertion_type);
    try testing.expectEqualStrings("0", assertions[0].expected_value.?);

    try testing.expectEqualStrings("get_age", assertions[1].function_name);
    try testing.expectEqual(test_assertions.AssertionType.comparison, assertions[1].assertion_type);
    try testing.expectEqualStrings("150", assertions[1].expected_value.?);

    try testing.expectEqualStrings("get_percentage", assertions[2].function_name);
    try testing.expectEqual(test_assertions.AssertionType.comparison, assertions[2].assertion_type);
    try testing.expectEqualStrings("0", assertions[2].expected_value.?);

    try testing.expectEqualStrings("get_discount", assertions[3].function_name);
    try testing.expectEqual(test_assertions.AssertionType.comparison, assertions[3].assertion_type);
    try testing.expectEqualStrings("100", assertions[3].expected_value.?);
}

test "detect test file type" {
    try testing.expectEqual(test_assertions.Language.typescript, test_assertions.detectTestFileType("user.test.ts").?);
    try testing.expectEqual(test_assertions.Language.typescript, test_assertions.detectTestFileType("user.spec.ts").?);
    try testing.expectEqual(test_assertions.Language.typescript, test_assertions.detectTestFileType("user_test.ts").?);
    try testing.expectEqual(test_assertions.Language.typescript, test_assertions.detectTestFileType("app.test.js").?);

    try testing.expectEqual(test_assertions.Language.python, test_assertions.detectTestFileType("test_user.py").?);
    try testing.expectEqual(test_assertions.Language.python, test_assertions.detectTestFileType("user_test.py").?);

    try testing.expectEqual(@as(?test_assertions.Language, null), test_assertions.detectTestFileType("user.ts"));
    try testing.expectEqual(@as(?test_assertions.Language, null), test_assertions.detectTestFileType("app.py"));
}

test "is test file" {
    try testing.expect(test_assertions.isTestFile("user.test.ts"));
    try testing.expect(test_assertions.isTestFile("user.spec.ts"));
    try testing.expect(test_assertions.isTestFile("test_user.py"));
    try testing.expect(test_assertions.isTestFile("user_test.py"));

    try testing.expect(!test_assertions.isTestFile("user.ts"));
    try testing.expect(!test_assertions.isTestFile("app.py"));
    try testing.expect(!test_assertions.isTestFile("main.zig"));
}

test "convert assertions to constraints" {
    const allocator = testing.allocator;

    var parser = test_assertions.TestAssertionParser.init(allocator);

    // Create sample assertions
    var assertions = [_]test_assertions.TestAssertion{
        .{
            .function_name = try allocator.dupe(u8, "validateEmail"),
            .assertion_type = .equality,
            .expected_value = try allocator.dupe(u8, "true"),
            .constraint_text = try allocator.dupe(u8, "Function validateEmail should return true"),
            .line = 10,
            .confidence = 0.9,
        },
        .{
            .function_name = try allocator.dupe(u8, "parseUser"),
            .assertion_type = .type_check,
            .expected_value = try allocator.dupe(u8, "User"),
            .constraint_text = try allocator.dupe(u8, "Function parseUser should return type User"),
            .line = 20,
            .confidence = 0.95,
        },
    };

    defer {
        for (&assertions) |*assertion| {
            assertion.deinit(allocator);
        }
    }

    const constraints = try parser.toConstraints(&assertions);
    defer allocator.free(constraints);

    try testing.expectEqual(@as(usize, 2), constraints.len);

    // Check first constraint (equality)
    try testing.expect(std.mem.containsAtLeast(u8, constraints[0].name, 1, "validateEmail"));
    try testing.expectEqual(ConstraintKind.semantic, constraints[0].kind);
    try testing.expectEqual(ConstraintSource.Test_Mining, constraints[0].source);
    try testing.expectEqual(@as(f32, 0.9), constraints[0].confidence);

    // Check second constraint (type check)
    try testing.expect(std.mem.containsAtLeast(u8, constraints[1].name, 1, "parseUser"));
    try testing.expectEqual(ConstraintKind.type_safety, constraints[1].kind);
    try testing.expectEqual(ConstraintSource.Test_Mining, constraints[1].source);
    try testing.expectEqual(@as(f32, 0.95), constraints[1].confidence);
}

test "parse real Jest test fixture" {
    const allocator = testing.allocator;

    // Read actual test fixture
    const file = try std.fs.cwd().openFile("test/fixtures/typescript/sample.test.ts", .{});
    defer file.close();

    const source = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(source);

    var parser = test_assertions.TestAssertionParser.init(allocator);
    const assertions = try parser.parse(source, .typescript);
    defer {
        for (assertions) |*assertion| {
            var mut_assertion = assertion;
            mut_assertion.deinit(allocator);
        }
        allocator.free(assertions);
    }

    // Verify we extracted a good number of assertions
    try testing.expect(assertions.len > 20);

    // Verify we have a variety of assertion types
    var has_equality = false;
    var has_error = false;
    var has_property = false;
    var has_comparison = false;
    var has_truthiness = false;

    for (assertions) |assertion| {
        switch (assertion.assertion_type) {
            .equality => has_equality = true,
            .error_expected => has_error = true,
            .property_check => has_property = true,
            .comparison => has_comparison = true,
            .truthiness => has_truthiness = true,
            else => {},
        }
    }

    try testing.expect(has_equality);
    try testing.expect(has_error);
    try testing.expect(has_property);
    try testing.expect(has_comparison);
    try testing.expect(has_truthiness);
}

test "parse real pytest test fixture" {
    const allocator = testing.allocator;

    // Read actual test fixture
    const file = try std.fs.cwd().openFile("test/fixtures/python/test_sample.py", .{});
    defer file.close();

    const source = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(source);

    var parser = test_assertions.TestAssertionParser.init(allocator);
    const assertions = try parser.parse(source, .python);
    defer {
        for (assertions) |*assertion| {
            var mut_assertion = assertion;
            mut_assertion.deinit(allocator);
        }
        allocator.free(assertions);
    }

    // Verify we extracted a good number of assertions
    try testing.expect(assertions.len > 15);

    // Verify we have a variety of assertion types
    var has_equality = false;
    var has_error = false;
    var has_type_check = false;
    var has_comparison = false;
    var has_membership = false;

    for (assertions) |assertion| {
        switch (assertion.assertion_type) {
            .equality => has_equality = true,
            .error_expected => has_error = true,
            .type_check => has_type_check = true,
            .comparison => has_comparison = true,
            .membership => has_membership = true,
            else => {},
        }
    }

    try testing.expect(has_equality);
    try testing.expect(has_error);
    try testing.expect(has_type_check);
    try testing.expect(has_comparison);
    try testing.expect(has_membership);
}