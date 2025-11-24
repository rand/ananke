const std = @import("std");
const testing = std.testing;
const braid = @import("braid");
const ananke = @import("ananke");
const Constraint = ananke.types.constraint.Constraint;
const ConstraintKind = ananke.types.constraint.ConstraintKind;
const Severity = ananke.types.constraint.Severity;
const TokenMaskRule = ananke.types.constraint.TokenMaskRule;

test "buildTokenMasks: security constraint with no credentials blocks password/api_key/token/secret" {
    const allocator = testing.allocator;

    const constraints = [_]Constraint{
        .{
            .id = 1,
            .name = "no_credentials",
            .description = "Do not expose credentials or secrets in output",
            .kind = .security,
            .severity = .err,
            .enforcement = .Security,
        },
    };

    const rules = try braid.buildTokenMasks(allocator, &constraints);
    defer {
        for (rules) |rule| {
            allocator.free(rule.pattern);
            allocator.free(rule.description);
        }
        allocator.free(rules);
    }

    // Should generate 4 rules: password, api_key, token, secret
    try testing.expectEqual(@as(usize, 4), rules.len);

    // Check that all patterns are deny_tokens
    for (rules) |rule| {
        try testing.expectEqual(TokenMaskRule.MaskType.deny_tokens, rule.mask_type);
    }

    // Check that expected patterns are present
    const expected_patterns = [_][]const u8{ "password", "api_key", "token", "secret" };
    var found_count: usize = 0;
    for (expected_patterns) |expected| {
        for (rules) |rule| {
            if (std.mem.eql(u8, rule.pattern, expected)) {
                found_count += 1;
                break;
            }
        }
    }
    try testing.expectEqual(@as(usize, 4), found_count);
}

test "buildTokenMasks: security constraint with no URLs blocks http/https" {
    const allocator = testing.allocator;

    const constraints = [_]Constraint{
        .{
            .id = 2,
            .name = "no_external_urls",
            .description = "Prevent generation of external URLs",
            .kind = .security,
            .severity = .err,
            .enforcement = .Security,
        },
    };

    const rules = try braid.buildTokenMasks(allocator, &constraints);
    defer {
        for (rules) |rule| {
            allocator.free(rule.pattern);
            allocator.free(rule.description);
        }
        allocator.free(rules);
    }

    // Should generate 2 rules: http://, https://
    try testing.expectEqual(@as(usize, 2), rules.len);

    // Check patterns
    var found_http = false;
    var found_https = false;
    for (rules) |rule| {
        try testing.expectEqual(TokenMaskRule.MaskType.deny_tokens, rule.mask_type);
        if (std.mem.eql(u8, rule.pattern, "http://")) found_http = true;
        if (std.mem.eql(u8, rule.pattern, "https://")) found_https = true;
    }
    try testing.expect(found_http);
    try testing.expect(found_https);
}

test "buildTokenMasks: security constraint with no SQL blocks SQL keywords" {
    const allocator = testing.allocator;

    const constraints = [_]Constraint{
        .{
            .id = 3,
            .name = "no_sql_injection",
            .description = "Prevent SQL injection attacks",
            .kind = .security,
            .severity = .err,
            .enforcement = .Security,
        },
    };

    const rules = try braid.buildTokenMasks(allocator, &constraints);
    defer {
        for (rules) |rule| {
            allocator.free(rule.pattern);
            allocator.free(rule.description);
        }
        allocator.free(rules);
    }

    // Should generate 4 rules: DROP, DELETE, INSERT, UPDATE
    try testing.expectEqual(@as(usize, 4), rules.len);

    const expected_patterns = [_][]const u8{ "DROP", "DELETE", "INSERT", "UPDATE" };
    var found_count: usize = 0;
    for (expected_patterns) |expected| {
        for (rules) |rule| {
            try testing.expectEqual(TokenMaskRule.MaskType.deny_tokens, rule.mask_type);
            if (std.mem.eql(u8, rule.pattern, expected)) {
                found_count += 1;
                break;
            }
        }
    }
    try testing.expectEqual(@as(usize, 4), found_count);
}

test "buildTokenMasks: security constraint with no code execution blocks eval/exec/system" {
    const allocator = testing.allocator;

    const constraints = [_]Constraint{
        .{
            .id = 4,
            .name = "no_code_execution",
            .description = "Prevent arbitrary code execution",
            .kind = .security,
            .severity = .err,
            .enforcement = .Security,
        },
    };

    const rules = try braid.buildTokenMasks(allocator, &constraints);
    defer {
        for (rules) |rule| {
            allocator.free(rule.pattern);
            allocator.free(rule.description);
        }
        allocator.free(rules);
    }

    // Should generate 3 rules: eval, exec, system()
    try testing.expectEqual(@as(usize, 3), rules.len);

    const expected_patterns = [_][]const u8{ "eval", "exec", "system(" };
    var found_count: usize = 0;
    for (expected_patterns) |expected| {
        for (rules) |rule| {
            try testing.expectEqual(TokenMaskRule.MaskType.deny_tokens, rule.mask_type);
            if (std.mem.eql(u8, rule.pattern, expected)) {
                found_count += 1;
                break;
            }
        }
    }
    try testing.expectEqual(@as(usize, 3), found_count);
}

test "buildTokenMasks: security constraint with no file paths blocks path patterns" {
    const allocator = testing.allocator;

    const constraints = [_]Constraint{
        .{
            .id = 5,
            .name = "no_file_paths",
            .description = "Prevent exposure of file paths",
            .kind = .security,
            .severity = .err,
            .enforcement = .Security,
        },
    };

    const rules = try braid.buildTokenMasks(allocator, &constraints);
    defer {
        for (rules) |rule| {
            allocator.free(rule.pattern);
            allocator.free(rule.description);
        }
        allocator.free(rules);
    }

    // Should generate 2 rules: /path/, C:\
    try testing.expectEqual(@as(usize, 2), rules.len);

    var found_unix = false;
    var found_windows = false;
    for (rules) |rule| {
        try testing.expectEqual(TokenMaskRule.MaskType.deny_tokens, rule.mask_type);
        if (std.mem.eql(u8, rule.pattern, "/path/")) found_unix = true;
        if (std.mem.eql(u8, rule.pattern, "C:\\")) found_windows = true;
    }
    try testing.expect(found_unix);
    try testing.expect(found_windows);
}

test "buildTokenMasks: operational constraint handling" {
    const allocator = testing.allocator;

    const constraints = [_]Constraint{
        .{
            .id = 6,
            .name = "no_secrets_in_logs",
            .description = "Operational requirement: no secrets in logs",
            .kind = .operational,
            .severity = .warning,
            .enforcement = .Performance,
        },
    };

    const rules = try braid.buildTokenMasks(allocator, &constraints);
    defer {
        for (rules) |rule| {
            allocator.free(rule.pattern);
            allocator.free(rule.description);
        }
        allocator.free(rules);
    }

    // Should generate credential blocking rules since description mentions "secrets"
    try testing.expect(rules.len > 0);

    // Check that at least one credential pattern is blocked
    var found_credential_block = false;
    for (rules) |rule| {
        if (std.mem.eql(u8, rule.pattern, "password") or
            std.mem.eql(u8, rule.pattern, "secret") or
            std.mem.eql(u8, rule.pattern, "api_key") or
            std.mem.eql(u8, rule.pattern, "token"))
        {
            found_credential_block = true;
            break;
        }
    }
    try testing.expect(found_credential_block);
}

test "buildTokenMasks: multiple security constraints generate multiple rules" {
    const allocator = testing.allocator;

    const constraints = [_]Constraint{
        .{
            .id = 7,
            .name = "no_credentials",
            .description = "No credentials allowed",
            .kind = .security,
            .severity = .err,
            .enforcement = .Security,
        },
        .{
            .id = 8,
            .name = "no_urls",
            .description = "No external URLs allowed",
            .kind = .security,
            .severity = .err,
            .enforcement = .Security,
        },
    };

    const rules = try braid.buildTokenMasks(allocator, &constraints);
    defer {
        for (rules) |rule| {
            allocator.free(rule.pattern);
            allocator.free(rule.description);
        }
        allocator.free(rules);
    }

    // Should generate 4 credential rules + 2 URL rules = 6 total
    try testing.expectEqual(@as(usize, 6), rules.len);
}

test "buildTokenMasks: no security constraints returns empty array" {
    const allocator = testing.allocator;

    const constraints = [_]Constraint{
        .{
            .id = 9,
            .name = "syntactic_rule",
            .description = "Some syntactic constraint",
            .kind = .syntactic,
            .severity = .warning,
            .enforcement = .Syntactic,
        },
        .{
            .id = 10,
            .name = "type_rule",
            .description = "Some type safety constraint",
            .kind = .type_safety,
            .severity = .err,
            .enforcement = .Structural,
        },
    };

    const rules = try braid.buildTokenMasks(allocator, &constraints);
    defer allocator.free(rules);

    // Should generate no rules since no security/operational constraints
    try testing.expectEqual(@as(usize, 0), rules.len);
}

test "buildTokenMasks: case-insensitive pattern matching" {
    const allocator = testing.allocator;

    const constraints = [_]Constraint{
        .{
            .id = 11,
            .name = "no_creds_upper",
            .description = "NO CREDENTIALS ALLOWED IN OUTPUT",
            .kind = .security,
            .severity = .err,
            .enforcement = .Security,
        },
    };

    const rules = try braid.buildTokenMasks(allocator, &constraints);
    defer {
        for (rules) |rule| {
            allocator.free(rule.pattern);
            allocator.free(rule.description);
        }
        allocator.free(rules);
    }

    // Should still match "NO CREDENTIALS" and generate 4 rules
    try testing.expectEqual(@as(usize, 4), rules.len);
}

test "buildTokenMasks: combined patterns in single constraint" {
    const allocator = testing.allocator;

    const constraints = [_]Constraint{
        .{
            .id = 12,
            .name = "comprehensive_security",
            .description = "No credentials, no URLs, no SQL injection allowed",
            .kind = .security,
            .severity = .err,
            .enforcement = .Security,
        },
    };

    const rules = try braid.buildTokenMasks(allocator, &constraints);
    defer {
        for (rules) |rule| {
            allocator.free(rule.pattern);
            allocator.free(rule.description);
        }
        allocator.free(rules);
    }

    // Should generate:
    // - 4 credential rules
    // - 2 URL rules
    // - 4 SQL rules
    // Total: 10 rules
    try testing.expectEqual(@as(usize, 10), rules.len);
}
