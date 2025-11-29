// Constraint Validator - Ensure constraint data integrity and prevent null/empty issues
const std = @import("std");
const Constraint = @import("constraint.zig").Constraint;
const ConstraintSet = @import("constraint.zig").ConstraintSet;

pub const ValidationError = error{
    EmptyName,
    EmptyDescription,
    InvalidConfidence,
    EmptyConstraintSet,
};

/// Validate a single constraint for data integrity
/// Returns error if constraint has invalid fields
pub fn validateConstraint(constraint: Constraint) ValidationError!void {
    // Check for empty name
    if (constraint.name.len == 0) {
        return ValidationError.EmptyName;
    }

    // Check for empty description
    if (constraint.description.len == 0) {
        return ValidationError.EmptyDescription;
    }

    // Validate confidence is in valid range [0.0, 1.0]
    if (constraint.confidence < 0.0 or constraint.confidence > 1.0) {
        return ValidationError.InvalidConfidence;
    }
}

/// Validate a constraint set for data integrity
/// Returns error if constraint set is invalid
pub fn validateConstraintSet(set: ConstraintSet) ValidationError!void {
    // Check for empty constraint set
    if (set.constraints.items.len == 0) {
        return ValidationError.EmptyConstraintSet;
    }

    // Validate each constraint
    for (set.constraints.items) |constraint| {
        try validateConstraint(constraint);
    }
}

/// Check if a constraint is valid without returning an error
pub fn isValidConstraint(constraint: Constraint) bool {
    validateConstraint(constraint) catch return false;
    return true;
}

/// Check if a constraint set is valid without returning an error
pub fn isValidConstraintSet(set: ConstraintSet) bool {
    validateConstraintSet(set) catch return false;
    return true;
}

/// Safely get a constraint from a set by index
/// Returns null if index is out of bounds
pub fn safeGet(set: *const ConstraintSet, index: usize) ?Constraint {
    if (index >= set.constraints.items.len) {
        return null;
    }
    return set.constraints.items[index];
}

/// Check if a constraint set is empty
pub fn isEmpty(set: *const ConstraintSet) bool {
    return set.constraints.items.len == 0;
}

/// Get the number of constraints in a set safely
pub fn count(set: *const ConstraintSet) usize {
    return set.constraints.items.len;
}

/// Filter out invalid constraints from a set in-place
/// Returns the number of constraints removed
pub fn removeInvalid(allocator: std.mem.Allocator, set: *ConstraintSet) !usize {
    var removed: usize = 0;
    var i: usize = 0;

    while (i < set.constraints.items.len) {
        if (!isValidConstraint(set.constraints.items[i])) {
            // Free the invalid constraint's memory
            const invalid = set.constraints.orderedRemove(i);
            allocator.free(invalid.name);
            allocator.free(invalid.description);
            removed += 1;
        } else {
            i += 1;
        }
    }

    return removed;
}

/// Create a default/fallback constraint for error recovery
pub fn createDefaultConstraint(allocator: std.mem.Allocator) !Constraint {
    return Constraint{
        .name = try allocator.dupe(u8, "default_constraint"),
        .description = try allocator.dupe(u8, "Default constraint created for error recovery"),
        .kind = .semantic,
        .severity = .info,
        .confidence = 0.5,
    };
}
