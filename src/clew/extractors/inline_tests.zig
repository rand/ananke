// Test discovery harness for language extractor inline tests.
// This file lives alongside the extractors so that relative @import
// paths trigger Zig's inline test discovery mechanism.
//
// Zig's test runner only discovers test blocks in files imported via
// @import("relative/path.zig"), not through named module re-exports.
// The "ananke" named module provided to this test step is a minimal
// stub that avoids module conflicts with the full ananke module tree.

comptime {
    _ = @import("rust.zig");
    _ = @import("java.zig");
    _ = @import("python.zig");
    _ = @import("kotlin.zig");
}
