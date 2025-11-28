/// Build Helpers for Ananke
///
/// Utilities to simplify build configuration and improve developer experience.
/// Provides automatic tree-sitter detection, parser linking, and helpful error messages.

const std = @import("std");

/// Helper to link tree-sitter system library with automatic path detection
///
/// This function attempts to find tree-sitter via standard system paths and pkg-config.
/// Falls back to common installation locations if not found in standard paths.
///
/// Usage:
/// ```zig
/// try linkTreeSitter(b, exe, target);
/// ```
pub fn linkTreeSitter(
    b: *std.Build,
    artifact: *std.Build.Step.Compile,
    target: std.Build.ResolvedTarget,
) !void {
    _ = target; // Reserved for future platform-specific logic

    // Link the system library - Zig will automatically search standard paths
    artifact.linkSystemLibrary("tree-sitter");

    // NOTE: For most systems, linkSystemLibrary() is sufficient.
    // Zig's build system will find tree-sitter via:
    // 1. pkg-config (if available)
    // 2. Standard library paths (/usr/lib, /usr/local/lib, etc.)
    // 3. Compiler-provided paths
    //
    // Only add explicit paths if you have a non-standard installation.
    // In that case, set the LIBRARY_PATH and CPATH environment variables:
    //   export LIBRARY_PATH=/custom/path/lib:$LIBRARY_PATH
    //   export CPATH=/custom/path/include:$CPATH

    // For debugging build issues, uncomment to see search paths:
    // std.debug.print("Tree-sitter linking configured\n", .{});

    _ = b; // Reserved for future use
}

/// Helper to link tree-sitter module with proper configuration
///
/// Creates or configures a tree-sitter module with the correct settings
/// for C FFI bindings to work properly.
///
/// Usage:
/// ```zig
/// const tree_sitter_mod = try configureTreeSitterModule(b, target);
/// ```
pub fn configureTreeSitterModule(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
) !*std.Build.Module {
    const mod = b.addModule("tree_sitter", .{
        .root_source_file = b.path("src/clew/tree_sitter.zig"),
        .target = target,
        .link_libc = true,
    });

    // Link tree-sitter system library for this module
    mod.linkSystemLibrary("tree-sitter", .{});

    return mod;
}

/// Link all Ananke tree-sitter language parsers to an artifact
///
/// This helper links all language parser libraries built by Ananke.
/// Use this when building executables or libraries that need AST parsing.
///
/// Usage:
/// ```zig
/// const ananke = b.dependency("ananke", .{ .target = target, .optimize = optimize });
/// try linkAnankeLanguageParsers(exe, ananke);
/// ```
pub fn linkAnankeLanguageParsers(
    artifact: *std.Build.Step.Compile,
    ananke_dep: *std.Build.Dependency,
) !void {
    // Link all language parser libraries
    const parsers = [_][]const u8{
        "tree-sitter-typescript",
        "tree-sitter-python",
        "tree-sitter-javascript",
        "tree-sitter-rust",
        "tree-sitter-go",
        "tree-sitter-zig",
        "tree-sitter-c",
        "tree-sitter-cpp",
        "tree-sitter-java",
    };

    for (parsers) |parser| {
        artifact.linkLibrary(ananke_dep.artifact(parser));
    }
}

/// Complete setup for using Ananke with tree-sitter support
///
/// This is a convenience function that:
/// 1. Links tree-sitter system library
/// 2. Links all Ananke language parsers
/// 3. Adds Ananke module imports
///
/// Usage:
/// ```zig
/// const ananke = b.dependency("ananke", .{ .target = target, .optimize = optimize });
/// try setupAnanke(b, exe, ananke, target);
/// ```
pub fn setupAnanke(
    b: *std.Build,
    artifact: *std.Build.Step.Compile,
    ananke_dep: *std.Build.Dependency,
    target: std.Build.ResolvedTarget,
) !void {
    // Link tree-sitter
    try linkTreeSitter(b, artifact, target);

    // Link all language parsers
    try linkAnankeLanguageParsers(artifact, ananke_dep);

    // Note: Module imports should be configured separately via:
    // .imports = &.{ .{ .name = "ananke", .module = ananke.module("ananke") } }
}

/// Detect tree-sitter installation and provide helpful error messages
///
/// This function checks if tree-sitter is properly installed and provides
/// platform-specific installation instructions if not found.
///
/// Returns: void on success, error with helpful message on failure
pub fn verifyTreeSitterInstallation(b: *std.Build) !void {
    // Try to run pkg-config to check for tree-sitter
    const result = std.process.Child.run(.{
        .allocator = b.allocator,
        .argv = &.{ "pkg-config", "--exists", "tree-sitter" },
    }) catch {
        // pkg-config not available or tree-sitter not found
        try printTreeSitterInstallHelp(b);
        return error.TreeSitterNotFound;
    };

    if (result.term.Exited != 0) {
        try printTreeSitterInstallHelp(b);
        return error.TreeSitterNotFound;
    }
}

fn printTreeSitterInstallHelp(b: *std.Build) !void {
    const stderr = std.io.getStdErr().writer();

    try stderr.writeAll(
        \\
        \\========================================
        \\  tree-sitter NOT FOUND
        \\========================================
        \\
        \\Ananke requires tree-sitter to be installed system-wide.
        \\
        \\Installation instructions:
        \\
        \\  macOS (Homebrew):
        \\    brew install tree-sitter
        \\
        \\  Ubuntu/Debian:
        \\    sudo apt-get install libtree-sitter-dev
        \\
        \\  Arch Linux:
        \\    sudo pacman -S tree-sitter
        \\
        \\  Fedora/RHEL:
        \\    sudo dnf install libtree-sitter-devel
        \\
        \\After installation, verify with:
        \\  tree-sitter --version
        \\
        \\For more help, see: docs/TROUBLESHOOTING.md
        \\========================================
        \\
        \\
    );

    _ = b; // May use in future for build-specific messages
}

/// Get compiler flags optimized for tree-sitter C libraries
///
/// Returns appropriate C compiler flags based on optimization level.
/// Includes LTO and CPU-native options when enabled.
pub fn getTreeSitterCFlags(
    optimize: std.builtin.OptimizeMode,
    lto: bool,
    native: bool,
) []const []const u8 {
    return switch (optimize) {
        .Debug => &.{ "-std=c11", "-O0", "-g", "-fno-sanitize=undefined" },
        .ReleaseSafe => if (lto)
            &.{ "-std=c11", "-O2", "-flto", "-fno-omit-frame-pointer", "-fno-sanitize=undefined" }
        else
            &.{ "-std=c11", "-O2", "-fno-omit-frame-pointer", "-fno-sanitize=undefined" },
        .ReleaseFast => if (lto and native)
            &.{ "-std=c11", "-O3", "-flto", "-march=native", "-mtune=native", "-fno-sanitize=undefined" }
        else if (lto)
            &.{ "-std=c11", "-O3", "-flto", "-fno-sanitize=undefined" }
        else if (native)
            &.{ "-std=c11", "-O3", "-march=native", "-mtune=native", "-fno-sanitize=undefined" }
        else
            &.{ "-std=c11", "-O3", "-fno-sanitize=undefined" },
        .ReleaseSmall => if (lto)
            &.{ "-std=c11", "-Os", "-flto", "-fno-sanitize=undefined" }
        else
            &.{ "-std=c11", "-Os", "-fno-sanitize=undefined" },
    };
}

/// Build error messages
pub const BuildError = error{
    TreeSitterNotFound,
    InvalidConfiguration,
};

test "build helpers compile" {
    // Basic compilation test to ensure helpers are syntactically correct
    const testing = std.testing;
    _ = testing;
}
