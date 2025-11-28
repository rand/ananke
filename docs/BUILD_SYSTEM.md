# Build System Guide

Complete guide to Ananke's Zig build system, including dependencies, optimization options, and troubleshooting.

## Overview

Ananke uses Zig's native build system (`build.zig`) for compilation and dependency management. The build system handles:

- Cross-platform compilation (macOS, Linux, Windows WSL)
- Tree-sitter C library integration
- Multiple language parser libraries (TypeScript, Python, Rust, Go, Zig, etc.)
- Optimization levels and mechanical sympathy features
- Example projects and test suites

## Quick Start

### Basic Build

```bash
# Build Ananke (debug mode)
zig build

# Build with optimization
zig build -Doptimize=ReleaseFast

# Build with LTO and native CPU features
zig build -Doptimize=ReleaseFast -Dlto=true -Dcpu-native=true

# Clean build
rm -rf zig-out .zig-cache && zig build
```

### Build Options

```bash
# List all build options
zig build --help

# Common options:
zig build -Dtarget=x86_64-linux      # Cross-compile for Linux
zig build -Doptimize=ReleaseSmall    # Optimize for size
zig build -Dlto=true                 # Enable Link-Time Optimization
zig build -Dcpu-native=true          # Optimize for your CPU
```

## Build Helpers

Ananke provides `build_helpers.zig` with utilities to simplify build configuration:

### Using Build Helpers in Your Project

```zig
const std = @import("std");
const helpers = @import("build_helpers.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "my-app",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Get Ananke dependency
    const ananke = b.dependency("ananke", .{
        .target = target,
        .optimize = optimize,
    });

    // Use helper to setup everything automatically
    helpers.setupAnanke(b, exe, ananke, target) catch |err| {
        std.debug.print("Failed to setup Ananke: {}\n", .{err});
        std.process.exit(1);
    };

    b.installArtifact(exe);
}
```

### Available Helpers

#### `linkTreeSitter()`

Links tree-sitter system library with automatic path detection.

```zig
try helpers.linkTreeSitter(b, exe, target);
```

#### `linkAnankeLanguageParsers()`

Links all Ananke language parser libraries in one call.

```zig
const ananke = b.dependency("ananke", .{});
try helpers.linkAnankeLanguageParsers(exe, ananke);
```

#### `setupAnanke()`

Complete one-line setup for Ananke with tree-sitter.

```zig
try helpers.setupAnanke(b, exe, ananke, target);
```

#### `verifyTreeSitterInstallation()`

Checks if tree-sitter is installed and provides helpful error messages.

```zig
helpers.verifyTreeSitterInstallation(b) catch |err| {
    // Error message with installation instructions already printed
    std.process.exit(1);
};
```

#### `getTreeSitterCFlags()`

Returns optimized C compiler flags for tree-sitter libraries.

```zig
const cflags = helpers.getTreeSitterCFlags(optimize, lto, cpu_native);
lib.addCSourceFiles(.{
    .files = &.{"parser.c"},
    .flags = cflags,
});
```

## Dependencies

### System Dependencies

**tree-sitter** (Required)

The core tree-sitter C library for AST parsing.

```bash
# macOS
brew install tree-sitter

# Ubuntu/Debian
sudo apt-get install libtree-sitter-dev

# Arch Linux
sudo pacman -S tree-sitter

# Fedora/RHEL
sudo dnf install libtree-sitter-devel

# Verify installation
tree-sitter --version  # Should show 0.20.0 or later
```

**Zig** (Required)

Zig compiler version 0.15.0 or later.

```bash
# Download from https://ziglang.org/download/
# Or use zigup version manager:
zigup 0.15.2

# Verify
zig version
```

### Vendored Dependencies

Ananke vendors language parser grammars in `vendor/`:

- `tree-sitter-typescript/` - TypeScript & JavaScript parsers
- `tree-sitter-python/` - Python parser
- `tree-sitter-rust/` - Rust parser
- `tree-sitter-go/` - Go parser
- `tree-sitter-zig/` - Zig parser
- `tree-sitter-c/` - C parser
- `tree-sitter-cpp/` - C++ parser
- `tree-sitter-java/` - Java parser

These are compiled as static libraries during the build.

## Build Targets

### Main Targets

**ananke** (CLI binary)

The command-line tool for constraint extraction and compilation.

```bash
zig build
./zig-out/bin/ananke --help
```

**lib** (Static library)

Ananke as a linkable library for integration with other projects.

```bash
zig build
# Library: ./zig-out/lib/libananke.a
```

**test** (Test suite)

Run all tests (unit, integration, E2E).

```bash
zig build test          # All tests
zig build test-unit     # Unit tests only
zig build test-e2e      # E2E tests only
```

**examples**

Build and run example projects.

```bash
cd examples/01-simple-extraction
zig build run
```

### Platform Targets

**Native** (Default)

Builds for your current platform.

```bash
zig build  # Detects your platform automatically
```

**Cross-compilation**

Build for different platforms.

```bash
# Linux (from macOS)
zig build -Dtarget=x86_64-linux-gnu

# macOS (from Linux)
zig build -Dtarget=aarch64-macos

# Windows (WSL only)
zig build -Dtarget=x86_64-windows-gnu
```

**WebAssembly** (Experimental)

```bash
zig build -Dwasm=true -Dtarget=wasm32-freestanding
```

## Optimization Levels

### Standard Levels

```bash
# Debug (default) - No optimization, debug symbols
zig build

# ReleaseSafe - Optimized with safety checks
zig build -Doptimize=ReleaseSafe

# ReleaseFast - Maximum performance
zig build -Doptimize=ReleaseFast

# ReleaseSmall - Optimize for binary size
zig build -Doptimize=ReleaseSmall
```

### Advanced Optimizations

**Link-Time Optimization (LTO)**

Enables whole-program optimization at link time.

```bash
zig build -Doptimize=ReleaseFast -Dlto=true
```

Benefits:
- ~15-20% performance improvement
- Better inlining across translation units
- Dead code elimination

Trade-offs:
- Longer compile times (~2-3x)
- Higher memory usage during linking

**CPU-Native Features**

Enables CPU-specific instructions for your processor.

```bash
zig build -Doptimize=ReleaseFast -Dcpu-native=true
```

Benefits:
- ~5-10% performance improvement
- Uses SIMD, AVX, etc.

Trade-offs:
- Binary only works on your CPU architecture
- Not portable to other machines

**Combined (Maximum Performance)**

```bash
zig build -Doptimize=ReleaseFast -Dlto=true -Dcpu-native=true
```

Expected performance: ~25-30% faster than Debug build.

## Troubleshooting

### Build Errors

#### Error: tree-sitter not found

```
error: unable to find system library 'tree-sitter'
```

**Solution**: Install tree-sitter (see Dependencies section above)

#### Error: Wrong Zig version

```
error: Zig version 0.15.0 or later required
```

**Solution**: Update Zig
```bash
# Download from https://ziglang.org/download/
# Or use zigup:
zigup 0.15.2
```

#### Error: Permission denied

```
error: unable to write to zig-cache
```

**Solution**: Clean and rebuild
```bash
rm -rf zig-out .zig-cache
zig build
```

### Linking Errors

#### Error: Undefined reference to `tree_sitter_xxx`

```
error: undefined reference to `tree_sitter_typescript`
```

**Solution**: Ensure language parsers are linked
```zig
exe.linkLibrary(ananke.artifact("tree-sitter-typescript"));
exe.linkLibrary(ananke.artifact("tree-sitter-python"));
// ... other parsers
```

Or use the helper:
```zig
try helpers.linkAnankeLanguageParsers(exe, ananke);
```

#### Error: Multiple definition of `tree_sitter_xxx`

```
error: multiple definition of `tree_sitter_typescript'
```

**Solution**: You're linking the same parser multiple times. Check your build.zig for duplicate linkLibrary calls.

### Runtime Errors

#### Error: Language parser not found

```
error: UnsupportedLanguage
```

**Solution**: The language parser wasn't linked. Add it to your build.zig:
```zig
exe.linkLibrary(ananke.artifact("tree-sitter-<language>"));
```

#### Error: Shared library not found (Linux)

```
error while loading shared libraries: libtree-sitter.so.0
```

**Solution**: Update library cache
```bash
sudo ldconfig
```

Or set LD_LIBRARY_PATH:
```bash
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
```

### Performance Issues

#### Slow Build Times

**Problem**: Build takes >5 minutes

**Solutions**:
- Use Debug mode during development (no LTO)
- Disable cpu-native flag
- Use `zig build-exe` for single-file builds
- Upgrade to latest Zig (build performance improves regularly)

```bash
# Fast development builds
zig build  # Debug, no LTO, ~30s

# Production builds (slower but optimized)
zig build -Doptimize=ReleaseFast -Dlto=true  # ~3-5 minutes
```

#### Large Binary Size

**Problem**: Binary is >50MB

**Solutions**:
```bash
# Optimize for size
zig build -Doptimize=ReleaseSmall

# Strip debug symbols (coming soon)
# zig build -Dstrip=true

# Use dynamic linking for tree-sitter (reduces size)
# Already enabled by default via linkSystemLibrary
```

## Advanced Topics

### Custom Build Configuration

Create a custom build configuration for your project:

```zig
// build.zig
const std = @import("std");
const helpers = @import("build_helpers.zig");

pub fn build(b: *std.Build) void {
    // Custom build options
    const enable_logging = b.option(bool, "logging", "Enable verbose logging") orelse false;
    const max_parsers = b.option(usize, "max-parsers", "Maximum concurrent parsers") orelse 4;

    const exe = b.addExecutable(.{
        .name = "custom-analyzer",
        .root_source_file = b.path("src/main.zig"),
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
    });

    // Pass build options to your code
    const options = b.addOptions();
    options.addOption(bool, "enable_logging", enable_logging);
    options.addOption(usize, "max_parsers", max_parsers);
    exe.root_module.addOptions("build_options", options);

    // Setup Ananke
    const ananke = b.dependency("ananke", .{
        .target = exe.root_module.resolved_target.?,
        .optimize = exe.root_module.optimize.?,
    });
    helpers.setupAnanke(b, exe, ananke, exe.root_module.resolved_target.?) catch unreachable;

    b.installArtifact(exe);
}
```

Then in your code:
```zig
const build_options = @import("build_options");

pub fn main() !void {
    if (build_options.enable_logging) {
        std.debug.print("Logging enabled\n", .{});
    }
}
```

Build with options:
```bash
zig build -Dlogging=true -Dmax-parsers=8
```

### Multi-Module Projects

Structure large projects with multiple modules:

```zig
pub fn build(b: *std.Build) void {
    // Shared modules
    const utils = b.addModule("utils", .{
        .root_source_file = b.path("src/utils.zig"),
    });

    const core = b.addModule("core", .{
        .root_source_file = b.path("src/core.zig"),
        .imports = &.{
            .{ .name = "utils", .module = utils },
        },
    });

    // Main executable
    const exe = b.addExecutable(.{
        .name = "app",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .imports = &.{
                .{ .name = "core", .module = core },
                .{ .name = "utils", .module = utils },
            },
        }),
    });
}
```

### Testing Infrastructure

```zig
// Add unit tests
const unit_tests = b.addTest(.{
    .root_source_file = b.path("src/main.zig"),
    .target = target,
    .optimize = optimize,
});

const test_step = b.step("test", "Run unit tests");
test_step.dependOn(&b.addRunArtifact(unit_tests).step);

// Add integration tests
const integration_tests = b.addTest(.{
    .root_source_file = b.path("test/integration.zig"),
});

const integration_step = b.step("test-integration", "Run integration tests");
integration_step.dependOn(&b.addRunArtifact(integration_tests).step);
```

## Best Practices

1. **Use build helpers** - Simplifies configuration and prevents errors
2. **Test locally first** - Run `zig build test` before committing
3. **Clean builds periodically** - `rm -rf zig-out .zig-cache` prevents stale artifacts
4. **Debug mode for development** - Fast builds, helpful errors
5. **ReleaseFast for production** - Maximum performance
6. **Document custom options** - Use `--help` to show available flags
7. **Version lock Zig** - Specify exact version in CI/CD

## Further Reading

- [Zig Build System Documentation](https://ziglang.org/documentation/master/#Build-System)
- [LIBRARY_INTEGRATION.md](LIBRARY_INTEGRATION.md) - Using Ananke as a library
- [QUICKSTART.md](../QUICKSTART.md) - Getting started guide
- [ARCHITECTURE.md](ARCHITECTURE.md) - System design overview
