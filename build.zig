const std = @import("std");

// Ananke Build System
// Supports multiple targets including native binaries and WASM
pub fn build(b: *std.Build) void {
    // Target options with WASM support
    const target = b.standardTargetOptions(.{
        .default_target = .{
            .cpu_arch = null,
            .os_tag = null,
            .abi = null,
        },
    });

    // Optimization options
    const optimize = b.standardOptimizeOption(.{});

    // Build option to enable WASM-specific features
    const wasm_build = b.option(bool, "wasm", "Build for WebAssembly target") orelse false;

    // Build option to enable Claude API integration
    // const enable_claude = b.option(bool, "claude", "Enable Claude API integration") orelse true;
    // It's also possible to define more custom flags to toggle optional features
    // of this build script using `b.option()`. All defined flags (including
    // target and optimize options) will be listed when running `zig build --help`
    // in this directory.

    // Tree-sitter support disabled pending Zig 0.15.x compatibility in upstream
    // TODO: Re-enable once z-tree-sitter fixes enum literal names
    // const zts = b.dependency("zts", .{
    //     .target = target,
    //     .optimize = optimize,
    //     .typescript = true,
    //     .python = true,
    //     .javascript = true,
    //     .rust = true,
    //     .go = true,
    //     .java = true,
    //     .zig = true,
    // });

    // Core Ananke modules
    // Note: We need to create modules first, then add imports after

    // API modules (http and claude)
    const http_mod = b.addModule("http", .{
        .root_source_file = b.path("src/api/http.zig"),
        .target = target,
    });

    const claude_mod = b.addModule("claude", .{
        .root_source_file = b.path("src/api/claude.zig"),
        .target = target,
    });
    claude_mod.addImport("http", http_mod);

    // Main Ananke module (declared first so we can reference it)
    const ananke_mod = b.addModule("ananke", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    // Clew: Constraint extraction engine
    const clew_mod = b.addModule("clew", .{
        .root_source_file = b.path("src/clew/clew.zig"),
        .target = target,
    });
    clew_mod.addImport("ananke", ananke_mod);
    clew_mod.addImport("http", http_mod);
    clew_mod.addImport("claude", claude_mod);
    // TODO: Re-enable when z-tree-sitter is Zig 0.15.x compatible
    // clew_mod.addImport("zts", zts.module("zts"));

    // Braid: Constraint compilation engine
    const braid_mod = b.addModule("braid", .{
        .root_source_file = b.path("src/braid/braid.zig"),
        .target = target,
    });
    braid_mod.addImport("ananke", ananke_mod);
    braid_mod.addImport("http", http_mod);
    braid_mod.addImport("claude", claude_mod);

    // Ariadne: Optional DSL compiler
    const ariadne_mod = b.addModule("ariadne", .{
        .root_source_file = b.path("src/ariadne/ariadne.zig"),
        .target = target,
    });

    // Now add imports to ananke_mod
    ananke_mod.addImport("clew", clew_mod);
    ananke_mod.addImport("braid", braid_mod);
    ananke_mod.addImport("ariadne", ariadne_mod);
    ananke_mod.addImport("http", http_mod);
    ananke_mod.addImport("claude", claude_mod);

    // Build static library for FFI integration with Rust Maze
    const lib = b.addLibrary(.{
        .name = "ananke",
        .linkage = .static,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/ffi/zig_ffi.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "ananke", .module = ananke_mod },
                .{ .name = "clew", .module = clew_mod },
                .{ .name = "braid", .module = braid_mod },
            },
        }),
    });
    b.installArtifact(lib);

    // Here we define an executable. An executable needs to have a root module
    // which needs to expose a `main` function. While we could add a main function
    // to the module defined above, it's sometimes preferable to split business
    // logic and the CLI into two separate modules.
    //
    // If your goal is to create a Zig library for others to use, consider if
    // it might benefit from also exposing a CLI tool. A parser library for a
    // data serialization format could also bundle a CLI syntax checker, for example.
    //
    // If instead your goal is to create an executable, consider if users might
    // be interested in also being able to embed the core functionality of your
    // program in their own executable in order to avoid the overhead involved in
    // subprocessing your CLI tool.
    //
    // If neither case applies to you, feel free to delete the declaration you
    // don't need and to put everything under a single module.
    const exe = b.addExecutable(.{
        .name = "ananke",
        .root_module = b.createModule(.{
            // b.createModule defines a new module just like b.addModule but,
            // unlike b.addModule, it does not expose the module to consumers of
            // this package, which is why in this case we don't have to give it a name.
            .root_source_file = b.path("src/main.zig"),
            // Target and optimization levels must be explicitly wired in when
            // defining an executable or library (in the root module), and you
            // can also hardcode a specific target for an executable or library
            // definition if desireable (e.g. firmware for embedded devices).
            .target = target,
            .optimize = optimize,
            // List of modules available for import in source files part of the
            // root module.
            .imports = &.{
                .{ .name = "ananke", .module = ananke_mod },
                .{ .name = "clew", .module = clew_mod },
                .{ .name = "braid", .module = braid_mod },
                .{ .name = "ariadne", .module = ariadne_mod },
            },
        }),
    });

    // This declares intent for the executable to be installed into the
    // install prefix when running `zig build` (i.e. when executing the default
    // step). By default the install prefix is `zig-out/` but can be overridden
    // by passing `--prefix` or `-p`.
    b.installArtifact(exe);

    // Example: Claude integration demo
    const claude_example = b.addExecutable(.{
        .name = "claude_integration",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/claude_integration.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "http", .module = http_mod },
                .{ .name = "claude", .module = claude_mod },
            },
        }),
    });
    b.installArtifact(claude_example);

    // Run step for Claude integration example
    const run_claude_example_step = b.step("run-example", "Run the Claude integration example");
    const run_claude_example_cmd = b.addRunArtifact(claude_example);
    run_claude_example_step.dependOn(&run_claude_example_cmd.step);
    run_claude_example_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_claude_example_cmd.addArgs(args);
    }

    // This creates a top level step. Top level steps have a name and can be
    // invoked by name when running `zig build` (e.g. `zig build run`).
    // This will evaluate the `run` step rather than the default step.
    // For a top level step to actually do something, it must depend on other
    // steps (e.g. a Run step, as we will see in a moment).
    const run_step = b.step("run", "Run the app");

    // This creates a RunArtifact step in the build graph. A RunArtifact step
    // invokes an executable compiled by Zig. Steps will only be executed by the
    // runner if invoked directly by the user (in the case of top level steps)
    // or if another step depends on it, so it's up to you to define when and
    // how this Run step will be executed. In our case we want to run it when
    // the user runs `zig build run`, so we create a dependency link.
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    // By making the run step depend on the default step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // WASM library build (if requested)
    // TODO: Implement WASM build when needed
    _ = wasm_build;

    // Creates an executable that will run `test` blocks from the provided module.
    const mod_tests = b.addTest(.{
        .root_module = ananke_mod,
    });

    // A run step that will run the test executable.
    const run_mod_tests = b.addRunArtifact(mod_tests);

    // Creates an executable that will run `test` blocks from the executable's
    // root module. Note that test executables only test one module at a time,
    // hence why we have to create two separate ones.
    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    // A run step that will run the second test executable.
    const run_exe_tests = b.addRunArtifact(exe_tests);

    // Creates test executable for Clew Claude integration tests
    const clew_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/clew/claude_integration_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "ananke", .module = ananke_mod },
                .{ .name = "clew", .module = clew_mod },
                .{ .name = "claude", .module = claude_mod },
            },
        }),
    });

    const run_clew_tests = b.addRunArtifact(clew_tests);

    // Pattern extraction tests
    const pattern_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/clew/pattern_extraction_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "ananke", .module = ananke_mod },
                .{ .name = "clew", .module = clew_mod },
            },
        }),
    });

    const run_pattern_tests = b.addRunArtifact(pattern_tests);

    // A top level step for running all tests. dependOn can be called multiple
    // times and since the two run steps do not depend on one another, this will
    // make the two of them run in parallel.
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
    test_step.dependOn(&run_clew_tests.step);
    test_step.dependOn(&run_pattern_tests.step);

    // Just like flags, top level steps are also listed in the `--help` menu.
    //
    // The Zig build system is entirely implemented in userland, which means
    // that it cannot hook into private compiler APIs. All compilation work
    // orchestrated by the build system will result in other Zig compiler
    // subcommands being invoked with the right flags defined. You can observe
    // these invocations when one fails (or you pass a flag to increase
    // verbosity) to validate assumptions and diagnose problems.
    //
    // Lastly, the Zig build system is relatively simple and self-contained,
    // and reading its source code will allow you to master it.

    // ============================================================================
    // Performance Benchmarks
    // ============================================================================

    // Clew extraction benchmarks
    const clew_bench = b.addExecutable(.{
        .name = "clew_bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("benches/zig/clew_bench.zig"),
            .target = target,
            .optimize = .ReleaseFast, // Always benchmark with optimizations
            .imports = &.{
                .{ .name = "ananke", .module = ananke_mod },
                .{ .name = "clew", .module = clew_mod },
            },
        }),
    });
    b.installArtifact(clew_bench);

    const run_clew_bench = b.addRunArtifact(clew_bench);
    const clew_bench_step = b.step("bench-clew", "Run Clew extraction benchmarks");
    clew_bench_step.dependOn(&run_clew_bench.step);

    // Braid compilation benchmarks
    const braid_bench = b.addExecutable(.{
        .name = "braid_bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("benches/zig/braid_bench.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .imports = &.{
                .{ .name = "ananke", .module = ananke_mod },
                .{ .name = "braid", .module = braid_mod },
            },
        }),
    });
    b.installArtifact(braid_bench);

    const run_braid_bench = b.addRunArtifact(braid_bench);
    const braid_bench_step = b.step("bench-braid", "Run Braid compilation benchmarks");
    braid_bench_step.dependOn(&run_braid_bench.step);

    // FFI bridge benchmarks
    const ffi_bench = b.addExecutable(.{
        .name = "ffi_bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("benches/zig/ffi_bench.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .imports = &.{
                .{ .name = "ananke", .module = ananke_mod },
                .{ .name = "zig_ffi", .module = b.addModule("zig_ffi", .{
                    .root_source_file = b.path("src/ffi/zig_ffi.zig"),
                    .target = target,
                }) },
            },
        }),
    });
    b.installArtifact(ffi_bench);

    const run_ffi_bench = b.addRunArtifact(ffi_bench);
    const ffi_bench_step = b.step("bench-ffi", "Run FFI bridge benchmarks");
    ffi_bench_step.dependOn(&run_ffi_bench.step);

    // Run all Zig benchmarks
    const bench_all_zig_step = b.step("bench-zig", "Run all Zig benchmarks");
    bench_all_zig_step.dependOn(clew_bench_step);
    bench_all_zig_step.dependOn(braid_bench_step);
    bench_all_zig_step.dependOn(ffi_bench_step);

    // Combined benchmark step (Zig + Rust)
    const bench_all_step = b.step("bench", "Run all benchmarks (Zig + Rust)");
    bench_all_step.dependOn(bench_all_zig_step);
    
    // Add Rust benchmarks via cargo
    const cargo_bench = b.addSystemCommand(&.{
        "cargo",
        "bench",
        "--manifest-path",
        "maze/Cargo.toml",
    });
    const rust_bench_step = b.step("bench-rust", "Run Rust Maze benchmarks");
    rust_bench_step.dependOn(&cargo_bench.step);
    bench_all_step.dependOn(rust_bench_step);
}
