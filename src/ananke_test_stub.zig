// Minimal ananke stub for extractor inline tests.
// base.zig only needs types.constraint.{Constraint, ConstraintKind, RichContext}.
// Using the real ananke module would cause "file exists in modules" errors
// because the extractors are part of ananke's clew module tree.
pub const types = struct {
    pub const constraint = @import("types/constraint.zig");
};
