const std = @import("std");
const testing = std.testing;
const eu = @import("error_union.zig");

test "Result - ok value" {
    const result = eu.Result(i32){ .ok = 42 };
    try testing.expect(result.isOk());
    try testing.expect(!result.isErr());
    try testing.expectEqual(@as(i32, 42), result.unwrap());
}

test "Result - error value" {
    const result = eu.Result(i32){ .err = error.FileNotFound };
    try testing.expect(!result.isOk());
    try testing.expect(result.isErr());
}

test "Result - unwrapOr" {
    const ok_result = eu.Result(i32){ .ok = 42 };
    try testing.expectEqual(@as(i32, 42), ok_result.unwrapOr(0));

    const err_result = eu.Result(i32){ .err = error.FileNotFound };
    try testing.expectEqual(@as(i32, 0), err_result.unwrapOr(0));
}

test "Result - map" {
    const result = eu.Result(i32){ .ok = 21 };
    const mapped = result.map(struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f);
    try testing.expectEqual(@as(i32, 42), mapped.unwrap());
}

test "Context - wrap error" {
    const ctx = eu.Context(eu.FileError).wrap(error.FileNotFound, "config.json");
    try testing.expectEqual(error.FileNotFound, ctx.getError().?);
    try testing.expectEqualStrings("config.json", ctx.getContext());
}

test "ErrorAccumulator - add errors" {
    var acc = eu.ErrorAccumulator(eu.ParseError, 10){};

    try acc.add(error.InvalidFormat);
    try acc.add(error.UnexpectedToken);

    try testing.expect(acc.hasErrors());
    try testing.expectEqual(@as(usize, 2), acc.getErrors().len);
}

test "ErrorAccumulator - clear" {
    var acc = eu.ErrorAccumulator(eu.ParseError, 10){};
    try acc.add(error.InvalidFormat);
    acc.clear();
    try testing.expect(!acc.hasErrors());
}

test "ErrorAccumulator - overflow" {
    var acc = eu.ErrorAccumulator(eu.ParseError, 2){};
    try acc.add(error.InvalidFormat);
    try acc.add(error.UnexpectedToken);
    try testing.expectError(error.TooManyErrors, acc.add(error.EndOfInput));
}

test "parseInt - positive number" {
    const result = try eu.parseInt("123");
    try testing.expectEqual(@as(i64, 123), result);
}

test "parseInt - negative number" {
    const result = try eu.parseInt("-456");
    try testing.expectEqual(@as(i64, -456), result);
}

test "parseInt - with plus sign" {
    const result = try eu.parseInt("+789");
    try testing.expectEqual(@as(i64, 789), result);
}

test "parseInt - empty string" {
    try testing.expectError(error.EndOfInput, eu.parseInt(""));
}

test "parseInt - invalid character" {
    try testing.expectError(error.InvalidCharacter, eu.parseInt("12a34"));
}

test "parseInt - only sign" {
    try testing.expectError(error.InvalidFormat, eu.parseInt("-"));
}

test "parseFloat - simple float" {
    const result = try eu.parseFloat("3.14");
    try testing.expectApproxEqAbs(@as(f64, 3.14), result, 0.001);
}

test "parseFloat - negative float" {
    const result = try eu.parseFloat("-2.5");
    try testing.expectApproxEqAbs(@as(f64, -2.5), result, 0.001);
}

test "parseFloat - integer" {
    const result = try eu.parseFloat("42");
    try testing.expectApproxEqAbs(@as(f64, 42.0), result, 0.001);
}

test "parseFloat - leading decimal" {
    const result = try eu.parseFloat("0.5");
    try testing.expectApproxEqAbs(@as(f64, 0.5), result, 0.001);
}

test "parseFloat - empty string" {
    try testing.expectError(error.EndOfInput, eu.parseFloat(""));
}

test "parseFloat - invalid character" {
    try testing.expectError(error.InvalidCharacter, eu.parseFloat("1.2a"));
}

test "parseFloat - double decimal" {
    try testing.expectError(error.InvalidFormat, eu.parseFloat("1..2"));
}

test "validatePath - valid path" {
    try eu.validatePath("/home/user/file.txt");
}

test "validatePath - empty path" {
    try testing.expectError(error.InvalidPath, eu.validatePath(""));
}

test "validatePath - path traversal" {
    try testing.expectError(error.InvalidPath, eu.validatePath("/etc/../passwd"));
}

test "errorName" {
    const name = eu.errorName(error.FileNotFound);
    try testing.expectEqualStrings("FileNotFound", name);
}

test "isError - matching error" {
    try testing.expect(eu.isError(eu.FileError, error.FileNotFound));
    try testing.expect(eu.isError(eu.FileError, error.PermissionDenied));
}

test "isError - non-matching error" {
    try testing.expect(!eu.isError(eu.FileError, error.InvalidFormat));
}

fn mayFail(succeed: bool) !i32 {
    if (succeed) return 42;
    return error.TestError;
}

test "chain - success" {
    const result = eu.chain(i32, i32, mayFail(true), struct {
        fn f(x: i32) !i32 {
            return x * 2;
        }
    }.f);
    try testing.expectEqual(@as(i32, 84), try result);
}

test "chain - first fails" {
    const result = eu.chain(i32, i32, mayFail(false), struct {
        fn f(x: i32) !i32 {
            return x * 2;
        }
    }.f);
    try testing.expectError(error.TestError, result);
}

fn translateError(_: eu.FileError) eu.ParseError {
    return error.InvalidFormat;
}

test "mapError - translates error" {
    const failing: eu.FileError!i32 = error.FileNotFound;
    const result = eu.mapError(i32, eu.FileError, eu.ParseError, failing, translateError);
    try testing.expectError(error.InvalidFormat, result);
}

var cleanup_called = false;

fn testCleanup() void {
    cleanup_called = true;
}

test "ensure - runs cleanup on error" {
    cleanup_called = false;
    const failing: anyerror!i32 = error.TestError;
    const result = eu.ensure(i32, failing, testCleanup);
    try testing.expectError(error.TestError, result);
    try testing.expect(cleanup_called);
}

test "ensure - no cleanup on success" {
    cleanup_called = false;
    const succeeding: anyerror!i32 = 42;
    const result = try eu.ensure(i32, succeeding, testCleanup);
    try testing.expectEqual(@as(i32, 42), result);
    try testing.expect(!cleanup_called);
}
