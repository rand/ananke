const std = @import("std");
const testing = std.testing;
const sanitizer = @import("../../src/braid/sanitizer.zig");

test "sanitizeName - allows alphanumeric, underscore, dash" {
    const allocator = testing.allocator;

    const valid_names = [_][]const u8{
        "valid_name",
        "ValidName123",
        "name-with-dashes",
        "MixedCase_123-test",
        "a",
        "ABC123",
    };

    for (valid_names) |name| {
        const sanitized = try sanitizer.sanitizeName(allocator, name);
        defer allocator.free(sanitized);
        try testing.expectEqualStrings(name, sanitized);
    }
}

test "sanitizeName - removes special characters" {
    const allocator = testing.allocator;

    const test_cases = [_]struct {
        input: []const u8,
        expected: []const u8,
    }{
        .{ .input = "name with spaces", .expected = "name_with_spaces" },
        .{ .input = "name\"with'quotes", .expected = "name_with_quotes" },
        .{ .input = "name\nwith\nnewlines", .expected = "name_with_newlines" },
        .{ .input = "name{with}braces", .expected = "name_with_braces" },
        .{ .input = "name.with.dots", .expected = "name_with_dots" },
        .{ .input = "name/with/slashes", .expected = "name_with_slashes" },
        .{ .input = "name\\with\\backslashes", .expected = "name_with_backslashes" },
        .{ .input = "name$with$dollars", .expected = "name_with_dollars" },
    };

    for (test_cases) |tc| {
        const sanitized = try sanitizer.sanitizeName(allocator, tc.input);
        defer allocator.free(sanitized);
        try testing.expectEqualStrings(tc.expected, sanitized);
    }
}

test "sanitizeName - handles empty string" {
    const allocator = testing.allocator;

    const sanitized = try sanitizer.sanitizeName(allocator, "");
    defer allocator.free(sanitized);
    try testing.expectEqualStrings("unnamed", sanitized);
}

test "sanitizeName - truncates to MAX_NAME_LENGTH" {
    const allocator = testing.allocator;

    // Create a name longer than MAX_NAME_LENGTH
    var long_name = try allocator.alloc(u8, 100);
    defer allocator.free(long_name);
    @memset(long_name, 'a');

    const sanitized = try sanitizer.sanitizeName(allocator, long_name);
    defer allocator.free(sanitized);

    try testing.expect(sanitized.len <= sanitizer.MAX_NAME_LENGTH);
    try testing.expect(sanitized.len == sanitizer.MAX_NAME_LENGTH);
}

test "sanitizeName - handles only invalid characters" {
    const allocator = testing.allocator;

    const sanitized = try sanitizer.sanitizeName(allocator, "!@#$%");
    defer allocator.free(sanitized);
    try testing.expectEqualStrings("_____", sanitized);
}

test "sanitizeDescription - escapes JSON special characters" {
    const allocator = testing.allocator;

    const test_cases = [_]struct {
        input: []const u8,
        expected: []const u8,
    }{
        .{ .input = "plain text", .expected = "plain text" },
        .{ .input = "text with \"quotes\"", .expected = "text with \\\"quotes\\\"" },
        .{ .input = "text with backslash \\", .expected = "text with backslash \\\\" },
        .{ .input = "line1\nline2", .expected = "line1\\nline2" },
        .{ .input = "tab\there", .expected = "tab\\there" },
        .{ .input = "carriage\rreturn", .expected = "carriage\\rreturn" },
    };

    for (test_cases) |tc| {
        const sanitized = try sanitizer.sanitizeDescription(allocator, tc.input);
        defer allocator.free(sanitized);
        try testing.expectEqualStrings(tc.expected, sanitized);
    }
}

test "sanitizeDescription - removes control characters" {
    const allocator = testing.allocator;

    // Test various control characters
    const input = "text\x00with\x01control\x1Fchars";
    const sanitized = try sanitizer.sanitizeDescription(allocator, input);
    defer allocator.free(sanitized);

    // Control characters should be replaced with spaces
    try testing.expect(std.mem.indexOf(u8, sanitized, "\x00") == null);
    try testing.expect(std.mem.indexOf(u8, sanitized, "\x01") == null);
    try testing.expect(std.mem.indexOf(u8, sanitized, "\x1F") == null);
}

test "sanitizeDescription - handles empty string" {
    const allocator = testing.allocator;

    const sanitized = try sanitizer.sanitizeDescription(allocator, "");
    defer allocator.free(sanitized);
    try testing.expectEqualStrings("", sanitized);
}

test "sanitizeDescription - truncates to MAX_DESC_LENGTH" {
    const allocator = testing.allocator;

    // Create a description longer than MAX_DESC_LENGTH
    var long_desc = try allocator.alloc(u8, 1000);
    defer allocator.free(long_desc);
    @memset(long_desc, 'a');

    const sanitized = try sanitizer.sanitizeDescription(allocator, long_desc);
    defer allocator.free(sanitized);

    try testing.expect(sanitized.len <= sanitizer.MAX_DESC_LENGTH);
}

test "sanitizeDescription - complex injection attack" {
    const allocator = testing.allocator;

    // Simulate an attack payload from malicious Claude API response
    const attack = "\"}} malicious code {\"name\":\"injected\", \"evil\":true";
    const sanitized = try sanitizer.sanitizeDescription(allocator, attack);
    defer allocator.free(sanitized);

    // Should escape quotes and braces are allowed (not control chars)
    try testing.expect(std.mem.indexOf(u8, sanitized, "\\\"") != null);
    try testing.expect(std.mem.indexOf(u8, sanitized, "}}") != null); // Braces allowed in descriptions
}

test "sanitizeName - injection attack with newlines and quotes" {
    const allocator = testing.allocator;

    // Attempt to inject newlines and quotes into a constraint name
    const attack = "legit_name\"; malicious=\"true\"\ninjection";
    const sanitized = try sanitizer.sanitizeName(allocator, attack);
    defer allocator.free(sanitized);

    // All special characters should be replaced with underscores
    try testing.expectEqualStrings("legit_name___malicious__true__injection", sanitized);
    try testing.expect(std.mem.indexOf(u8, sanitized, "\"") == null);
    try testing.expect(std.mem.indexOf(u8, sanitized, "\n") == null);
}

test "sanitizeName - SQL injection attempt" {
    const allocator = testing.allocator;

    const attack = "name'; DROP TABLE constraints;--";
    const sanitized = try sanitizer.sanitizeName(allocator, attack);
    defer allocator.free(sanitized);

    // Special SQL characters should be replaced
    try testing.expectEqualStrings("name___DROP_TABLE_constraints___", sanitized);
}

test "sanitizeName - ANSI escape code injection" {
    const allocator = testing.allocator;

    // Attempt to inject ANSI escape codes to manipulate terminal
    const attack = "name\x1b[31mRED\x1b[0m";
    const sanitized = try sanitizer.sanitizeName(allocator, attack);
    defer allocator.free(sanitized);

    // Escape codes should be removed
    try testing.expectEqualStrings("name_31mRED_0m", sanitized);
}

test "sanitizeDescription - prevents JSON injection" {
    const allocator = testing.allocator;

    // Attempt to close JSON and inject malicious fields
    const attack = "\", \"malicious\": true, \"data\": \"";
    const sanitized = try sanitizer.sanitizeDescription(allocator, attack);
    defer allocator.free(sanitized);

    // Quotes should be escaped
    try testing.expectEqualStrings("\\\", \\\"malicious\\\": true, \\\"data\\\": \\\"", sanitized);
}
