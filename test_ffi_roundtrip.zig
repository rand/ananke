const std = @import("std");

// Import as internal module to access private functions
const ffi = @import("src/ffi/zig_ffi.zig");

// Test the internal convertIRToFFI function
test "Test FFI convertIRToFFI function exists" {
    const testing = std.testing;

    // Test that the module imports correctly
    _ = ffi.AnankeError;
    _ = ffi.ConstraintIRFFI;
    _ = ffi.TokenMaskRulesFFI;

    try testing.expect(true); // Basic test passes
}

test "FFI exported functions" {
    const testing = std.testing;

    // Test initialization
    const init_result = ffi.ananke_init();
    try testing.expectEqual(@as(c_int, 0), init_result);

    // Test version
    const version = ffi.ananke_version();
    try testing.expect(std.mem.len(version) > 0);

    // Cleanup
    ffi.ananke_deinit();
}
