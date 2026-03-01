const std = @import("std");
const testing = std.testing;
const cv = @import("comptime_validation.zig");

const TestStruct = struct {
    name: []const u8,
    age: u32,
};

test "validateStructFields - has required fields" {
    const has_fields = cv.validateStructFields(TestStruct, &.{ "name", "age" });
    try testing.expect(has_fields);
}

test "validateStructFields - missing field" {
    const has_fields = cv.validateStructFields(TestStruct, &.{ "name", "email" });
    try testing.expect(!has_fields);
}

test "validateStructFields - non-struct type" {
    const has_fields = cv.validateStructFields(u32, &.{"value"});
    try testing.expect(!has_fields);
}

const WithMethod = struct {
    pub fn process(self: @This()) void {
        _ = self;
    }
};

test "hasMethod - method exists" {
    try testing.expect(cv.hasMethod(WithMethod, "process"));
}

test "hasMethod - method missing" {
    try testing.expect(!cv.hasMethod(WithMethod, "execute"));
}

test "isValidIdentifier - valid identifiers" {
    try testing.expect(cv.isValidIdentifier("foo"));
    try testing.expect(cv.isValidIdentifier("_bar"));
    try testing.expect(cv.isValidIdentifier("foo123"));
    try testing.expect(cv.isValidIdentifier("_123"));
}

test "isValidIdentifier - invalid identifiers" {
    try testing.expect(!cv.isValidIdentifier(""));
    try testing.expect(!cv.isValidIdentifier("123foo"));
    try testing.expect(!cv.isValidIdentifier("foo-bar"));
    try testing.expect(!cv.isValidIdentifier("foo bar"));
}

test "InRange - within range" {
    const Percent = cv.InRange(u8, 0, 100);
    const p = try Percent.init(50);
    try testing.expectEqual(@as(u8, 50), p.get());
}

test "InRange - boundary values" {
    const Percent = cv.InRange(u8, 0, 100);
    _ = try Percent.init(0);
    _ = try Percent.init(100);
}

test "InRange - out of range" {
    const Percent = cv.InRange(u8, 0, 100);
    try testing.expectError(error.OutOfRange, Percent.init(101));
}

test "InRange - constants" {
    const Percent = cv.InRange(i32, -100, 100);
    try testing.expectEqual(@as(i32, -100), Percent.MIN);
    try testing.expectEqual(@as(i32, 100), Percent.MAX);
}

test "NonEmpty - valid string" {
    const Name = cv.NonEmpty(32);
    const n = try Name.init("hello");
    try testing.expectEqualStrings("hello", n.slice());
}

test "NonEmpty - empty string" {
    const Name = cv.NonEmpty(32);
    try testing.expectError(error.EmptyString, Name.init(""));
}

test "NonEmpty - too long" {
    const Name = cv.NonEmpty(5);
    try testing.expectError(error.StringTooLong, Name.init("hello world"));
}

test "isValidEmail - valid emails" {
    try testing.expect(cv.isValidEmail("test@example.com"));
    try testing.expect(cv.isValidEmail("user.name@domain.org"));
}

test "isValidEmail - invalid emails" {
    try testing.expect(!cv.isValidEmail("test"));
    try testing.expect(!cv.isValidEmail("@example.com"));
    try testing.expect(!cv.isValidEmail("test@"));
    try testing.expect(!cv.isValidEmail("test@@example.com"));
}

const Status = enum { pending, active, completed };

test "EnumValidator - fromString valid" {
    const validator = cv.EnumValidator(Status);
    const result = validator.fromString("active");
    try testing.expect(result != null);
    try testing.expectEqual(Status.active, result.?);
}

test "EnumValidator - fromString invalid" {
    const validator = cv.EnumValidator(Status);
    const result = validator.fromString("unknown");
    try testing.expect(result == null);
}

test "EnumValidator - toString" {
    const validator = cv.EnumValidator(Status);
    try testing.expectEqualStrings("completed", validator.toString(.completed));
}

test "EnumValidator - isValid" {
    const validator = cv.EnumValidator(Status);
    try testing.expect(validator.isValid("pending"));
    try testing.expect(!validator.isValid("invalid"));
}

test "BoundedArray - basic operations" {
    var arr = cv.BoundedArray(i32, 5){};
    try arr.append(1);
    try arr.append(2);
    try arr.append(3);

    try testing.expectEqual(@as(usize, 3), arr.len);
    try testing.expectEqual(@as(i32, 1), try arr.get(0));
    try testing.expectEqual(@as(i32, 2), try arr.get(1));
}

test "BoundedArray - overflow" {
    var arr = cv.BoundedArray(i32, 2){};
    try arr.append(1);
    try arr.append(2);
    try testing.expectError(error.ArrayFull, arr.append(3));
}

test "BoundedArray - index out of bounds" {
    var arr = cv.BoundedArray(i32, 5){};
    try arr.append(1);
    try testing.expectError(error.IndexOutOfBounds, arr.get(5));
}

test "BoundedArray - pop" {
    var arr = cv.BoundedArray(i32, 5){};
    try arr.append(10);
    try arr.append(20);
    const popped = try arr.pop();
    try testing.expectEqual(@as(i32, 20), popped);
    try testing.expectEqual(@as(usize, 1), arr.len);
}

test "BoundedArray - pop empty" {
    var arr = cv.BoundedArray(i32, 5){};
    try testing.expectError(error.ArrayEmpty, arr.pop());
}

test "BoundedArray - clear" {
    var arr = cv.BoundedArray(i32, 5){};
    try arr.append(1);
    try arr.append(2);
    arr.clear();
    try testing.expectEqual(@as(usize, 0), arr.len);
}

test "BoundedArray - slice" {
    var arr = cv.BoundedArray(i32, 5){};
    try arr.append(1);
    try arr.append(2);
    try arr.append(3);
    const slice = arr.slice();
    try testing.expectEqual(@as(usize, 3), slice.len);
    try testing.expectEqual(@as(i32, 1), slice[0]);
}

test "isNumeric - numeric types" {
    try testing.expect(cv.isNumeric(i32));
    try testing.expect(cv.isNumeric(u64));
    try testing.expect(cv.isNumeric(f32));
    try testing.expect(cv.isNumeric(f64));
}

test "isNumeric - non-numeric types" {
    try testing.expect(!cv.isNumeric(bool));
    try testing.expect(!cv.isNumeric([]const u8));
}

test "isSignedInt" {
    try testing.expect(cv.isSignedInt(i32));
    try testing.expect(cv.isSignedInt(i64));
    try testing.expect(!cv.isSignedInt(u32));
    try testing.expect(!cv.isSignedInt(f32));
}

test "isUnsignedInt" {
    try testing.expect(cv.isUnsignedInt(u32));
    try testing.expect(cv.isUnsignedInt(usize));
    try testing.expect(!cv.isUnsignedInt(i32));
    try testing.expect(!cv.isUnsignedInt(f32));
}

test "unwrapOrDefault - some value" {
    const value: ?i32 = 42;
    const result = cv.unwrapOrDefault(i32, value, 0);
    try testing.expectEqual(@as(i32, 42), result);
}

test "unwrapOrDefault - null" {
    const value: ?i32 = null;
    const result = cv.unwrapOrDefault(i32, value, 99);
    try testing.expectEqual(@as(i32, 99), result);
}

fn isPositive(x: i32) bool {
    return x > 0;
}

test "Validated - valid value" {
    const PositiveInt = cv.Validated(i32, isPositive);
    const v = try PositiveInt.init(42);
    try testing.expectEqual(@as(i32, 42), v.get());
}

test "Validated - invalid value" {
    const PositiveInt = cv.Validated(i32, isPositive);
    try testing.expectError(error.ValidationFailed, PositiveInt.init(-5));
}
