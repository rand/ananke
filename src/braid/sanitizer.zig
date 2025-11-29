// Constraint Sanitizer - Prevent injection attacks from untrusted constraint data
const std = @import("std");

/// Maximum allowed length for constraint names (prevent DoS)
pub const MAX_NAME_LENGTH: usize = 64;

/// Maximum allowed length for constraint descriptions (prevent DoS)
pub const MAX_DESC_LENGTH: usize = 512;

/// Sanitize a constraint name to prevent injection attacks.
/// Only allows: [a-zA-Z0-9_-]
/// Truncates to MAX_NAME_LENGTH
/// Returns a newly allocated sanitized string that caller must free.
pub fn sanitizeName(allocator: std.mem.Allocator, name: []const u8) ![]const u8 {
    if (name.len == 0) {
        return try allocator.dupe(u8, "unnamed");
    }

    // Allocate buffer for sanitized name (max length)
    const max_len = @min(name.len, MAX_NAME_LENGTH);
    var sanitized = try std.ArrayList(u8).initCapacity(allocator, max_len);
    errdefer sanitized.deinit(allocator);

    // Copy only allowed characters
    var count: usize = 0;
    for (name) |char| {
        if (count >= MAX_NAME_LENGTH) break;

        if (isAllowedNameChar(char)) {
            try sanitized.append(allocator, char);
            count += 1;
        } else {
            // Replace disallowed characters with underscore
            try sanitized.append(allocator, '_');
            count += 1;
        }
    }

    // Ensure we have at least one character
    if (sanitized.items.len == 0) {
        try sanitized.append(allocator, '_');
    }

    return try sanitized.toOwnedSlice(allocator);
}

/// Check if a character is allowed in a constraint name
fn isAllowedNameChar(char: u8) bool {
    return (char >= 'a' and char <= 'z') or
        (char >= 'A' and char <= 'Z') or
        (char >= '0' and char <= '9') or
        char == '_' or
        char == '-';
}

/// Sanitize a constraint description for safe use in JSON/logs.
/// Escapes: quotes, backslashes, control characters
/// Truncates to MAX_DESC_LENGTH
/// Returns a newly allocated sanitized string that caller must free.
pub fn sanitizeDescription(allocator: std.mem.Allocator, description: []const u8) ![]const u8 {
    if (description.len == 0) {
        return try allocator.dupe(u8, "");
    }

    // Allocate buffer (may grow up to 2x due to escape sequences)
    var sanitized = std.ArrayList(u8){};
    errdefer sanitized.deinit(allocator);

    var count: usize = 0;
    for (description) |char| {
        // Stop at max length (account for escape sequences)
        if (count >= MAX_DESC_LENGTH) break;

        switch (char) {
            '"' => {
                try sanitized.appendSlice(allocator, "\\\"");
                count += 2;
            },
            '\\' => {
                try sanitized.appendSlice(allocator, "\\\\");
                count += 2;
            },
            '\n' => {
                try sanitized.appendSlice(allocator, "\\n");
                count += 2;
            },
            '\r' => {
                try sanitized.appendSlice(allocator, "\\r");
                count += 2;
            },
            '\t' => {
                try sanitized.appendSlice(allocator, "\\t");
                count += 2;
            },
            // Other control characters (excluding \t=0x09, \n=0x0A, \r=0x0D)
            0x00...0x08, 0x0B, 0x0C, 0x0E...0x1F, 0x7F => {
                // Control characters - replace with space
                try sanitized.append(allocator, ' ');
                count += 1;
            },
            else => {
                // Safe character - copy as-is
                try sanitized.append(allocator, char);
                count += 1;
            },
        }
    }

    return try sanitized.toOwnedSlice(allocator);
}

/// Sanitize a constraint name in-place within a Constraint struct.
/// Frees the old name and replaces it with sanitized version.
pub fn sanitizeConstraintName(allocator: std.mem.Allocator, constraint: *@import("ananke").Constraint) !void {
    const sanitized = try sanitizeName(allocator, constraint.name);
    allocator.free(constraint.name);
    constraint.name = sanitized;
}

/// Sanitize a constraint description in-place within a Constraint struct.
/// Frees the old description and replaces it with sanitized version.
pub fn sanitizeConstraintDescription(allocator: std.mem.Allocator, constraint: *@import("ananke").Constraint) !void {
    const sanitized = try sanitizeDescription(allocator, constraint.description);
    allocator.free(constraint.description);
    constraint.description = sanitized;
}

/// Sanitize both name and description of a constraint in-place.
pub fn sanitizeConstraint(allocator: std.mem.Allocator, constraint: *@import("ananke").Constraint) !void {
    try sanitizeConstraintName(allocator, constraint);
    try sanitizeConstraintDescription(allocator, constraint);
}
