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

    // Build options for mechanical sympathy optimizations
    const enable_lto = b.option(bool, "lto", "Enable Link-Time Optimization for release builds") orelse (optimize != .Debug);
    const cpu_native = b.option(bool, "cpu-native", "Enable native CPU features (-march=native)") orelse false;
    // TODO: Apply strip_symbols to executables (requires updating exe configuration)
    // const strip_symbols = b.option(bool, "strip", "Strip debug symbols from release builds") orelse (optimize == .ReleaseSmall);

    // Build option to enable WASM-specific features
    const wasm_build = b.option(bool, "wasm", "Build for WebAssembly target") orelse false;

    // Build option to enable Claude API integration
    // const enable_claude = b.option(bool, "claude", "Enable Claude API integration") orelse true;
    // It's also possible to define more custom flags to toggle optional features
    // of this build script using `b.option()`. All defined flags (including
    // target and optimize options) will be listed when running `zig build --help`
    // in this directory.

    // Helper function to generate C compiler flags based on optimization level
    // Enables aggressive optimizations for release builds with LTO and CPU-specific features
    const getCFlags = struct {
        fn get(opt: std.builtin.OptimizeMode, lto: bool, native: bool) []const []const u8 {
            return switch (opt) {
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
    }.get;

    // Tree-sitter support via direct C FFI
    // Note: Requires tree-sitter libraries to be installed via:
    // macOS: brew install tree-sitter
    // Linux: apt-get install libtree-sitter-dev or similar

    // Tree-sitter module for direct C FFI bindings
    const tree_sitter_mod = b.addModule("tree_sitter", .{
        .root_source_file = b.path("src/clew/tree_sitter.zig"),
        .target = target,
        .link_libc = true,
    });

    // Tree-sitter language parsers as static libraries
    // TypeScript parser
    const ts_parser_lib = b.addLibrary(.{
        .name = "tree-sitter-typescript",
        .linkage = .static,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    ts_parser_lib.addIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/tree-sitter/include" });
    ts_parser_lib.addIncludePath(.{ .cwd_relative = "vendor/tree-sitter-typescript/typescript/src" });
    ts_parser_lib.addCSourceFiles(.{
        .root = b.path("vendor/tree-sitter-typescript/typescript/src"),
        .files = &.{ "parser.c", "scanner.c" },
        .flags = getCFlags(optimize, enable_lto, cpu_native),
    });

    // Python parser
    const py_parser_lib = b.addLibrary(.{
        .name = "tree-sitter-python",
        .linkage = .static,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    py_parser_lib.addIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/tree-sitter/include" });
    py_parser_lib.addCSourceFiles(.{
        .root = b.path("vendor/tree-sitter-python/src"),
        .files = &.{ "parser.c", "scanner.c" },
        .flags = getCFlags(optimize, enable_lto, cpu_native),
    });

    // JavaScript parser
    const js_parser_lib = b.addLibrary(.{
        .name = "tree-sitter-javascript",
        .linkage = .static,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    js_parser_lib.addIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/tree-sitter/include" });
    js_parser_lib.addCSourceFiles(.{
        .root = b.path("vendor/tree-sitter-javascript/src"),
        .files = &.{ "parser.c", "scanner.c" },
        .flags = getCFlags(optimize, enable_lto, cpu_native),
    });

    // Rust parser
    const rust_parser_lib = b.addLibrary(.{
        .name = "tree-sitter-rust",
        .linkage = .static,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    rust_parser_lib.addIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/tree-sitter/include" });
    rust_parser_lib.addCSourceFiles(.{
        .root = b.path("vendor/tree-sitter-rust/src"),
        .files = &.{ "parser.c", "scanner.c" },
        .flags = getCFlags(optimize, enable_lto, cpu_native),
    });

    // Go parser
    const go_parser_lib = b.addLibrary(.{
        .name = "tree-sitter-go",
        .linkage = .static,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    go_parser_lib.addIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/tree-sitter/include" });
    go_parser_lib.addCSourceFiles(.{
        .root = b.path("vendor/tree-sitter-go/src"),
        .files = &.{"parser.c"},
        .flags = getCFlags(optimize, enable_lto, cpu_native),
    });

    // Zig parser
    const zig_parser_lib = b.addLibrary(.{
        .name = "tree-sitter-zig",
        .linkage = .static,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    zig_parser_lib.addIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/tree-sitter/include" });
    zig_parser_lib.addCSourceFiles(.{
        .root = b.path("vendor/tree-sitter-zig/src"),
        .files = &.{"parser.c"},
        .flags = getCFlags(optimize, enable_lto, cpu_native),
    });

    // C parser
    const c_parser_lib = b.addLibrary(.{
        .name = "tree-sitter-c",
        .linkage = .static,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    c_parser_lib.addIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/tree-sitter/include" });
    c_parser_lib.addCSourceFiles(.{
        .root = b.path("vendor/tree-sitter-c/src"),
        .files = &.{"parser.c"},
        .flags = getCFlags(optimize, enable_lto, cpu_native),
    });

    // C++ parser
    const cpp_parser_lib = b.addLibrary(.{
        .name = "tree-sitter-cpp",
        .linkage = .static,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    cpp_parser_lib.addIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/tree-sitter/include" });
    cpp_parser_lib.addCSourceFiles(.{
        .root = b.path("vendor/tree-sitter-cpp/src"),
        .files = &.{ "parser.c", "scanner.c" },
        .flags = getCFlags(optimize, enable_lto, cpu_native),
    });

    // Java parser
    const java_parser_lib = b.addLibrary(.{
        .name = "tree-sitter-java",
        .linkage = .static,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    java_parser_lib.addIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/tree-sitter/include" });
    java_parser_lib.addCSourceFiles(.{
        .root = b.path("vendor/tree-sitter-java/src"),
        .files = &.{"parser.c"},
        .flags = getCFlags(optimize, enable_lto, cpu_native),
    });

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
        .link_libc = true,
    });
    clew_mod.addImport("ananke", ananke_mod);
    clew_mod.addImport("http", http_mod);
    clew_mod.addImport("claude", claude_mod);
    clew_mod.addImport("tree_sitter", tree_sitter_mod);

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

    // CLI modules (dependent on ananke)
    const cli_args_mod = b.addModule("cli_args", .{
        .root_source_file = b.path("src/cli/args.zig"),
        .target = target,
    });

    const cli_output_mod = b.addModule("cli_output", .{
        .root_source_file = b.path("src/cli/output.zig"),
        .target = target,
    });
    cli_output_mod.addImport("ananke", ananke_mod);

    const cli_config_mod = b.addModule("cli_config", .{
        .root_source_file = b.path("src/cli/config.zig"),
        .target = target,
    });

    const cli_error_mod = b.addModule("cli_error", .{
        .root_source_file = b.path("src/cli/error.zig"),
        .target = target,
    });
    cli_error_mod.addImport("cli_output", cli_output_mod);

    // CLI command modules
    const cli_extract_mod = b.addModule("cli_extract", .{
        .root_source_file = b.path("src/cli/commands/extract.zig"),
        .target = target,
    });
    cli_extract_mod.addImport("ananke", ananke_mod);
    cli_extract_mod.addImport("cli_args", cli_args_mod);
    cli_extract_mod.addImport("cli_output", cli_output_mod);
    cli_extract_mod.addImport("cli_config", cli_config_mod);
    cli_extract_mod.addImport("cli_error", cli_error_mod);

    const cli_compile_mod = b.addModule("cli_compile", .{
        .root_source_file = b.path("src/cli/commands/compile.zig"),
        .target = target,
    });
    cli_compile_mod.addImport("ananke", ananke_mod);
    cli_compile_mod.addImport("cli_args", cli_args_mod);
    cli_compile_mod.addImport("cli_output", cli_output_mod);
    cli_compile_mod.addImport("cli_config", cli_config_mod);
    cli_compile_mod.addImport("cli_error", cli_error_mod);

    const cli_generate_mod = b.addModule("cli_generate", .{
        .root_source_file = b.path("src/cli/commands/generate.zig"),
        .target = target,
    });
    cli_generate_mod.addImport("cli_args", cli_args_mod);
    cli_generate_mod.addImport("cli_config", cli_config_mod);
    cli_generate_mod.addImport("cli_error", cli_error_mod);

    const cli_validate_mod = b.addModule("cli_validate", .{
        .root_source_file = b.path("src/cli/commands/validate.zig"),
        .target = target,
    });
    cli_validate_mod.addImport("ananke", ananke_mod);
    cli_validate_mod.addImport("cli_args", cli_args_mod);
    cli_validate_mod.addImport("cli_output", cli_output_mod);
    cli_validate_mod.addImport("cli_config", cli_config_mod);
    cli_validate_mod.addImport("cli_error", cli_error_mod);

    const cli_init_mod = b.addModule("cli_init", .{
        .root_source_file = b.path("src/cli/commands/init.zig"),
        .target = target,
    });
    cli_init_mod.addImport("cli_args", cli_args_mod);
    cli_init_mod.addImport("cli_config", cli_config_mod);
    cli_init_mod.addImport("cli_error", cli_error_mod);

    const cli_version_mod = b.addModule("cli_version", .{
        .root_source_file = b.path("src/cli/commands/version.zig"),
        .target = target,
    });
    cli_version_mod.addImport("cli_args", cli_args_mod);
    cli_version_mod.addImport("cli_config", cli_config_mod);
    cli_version_mod.addImport("cli_output", cli_output_mod);

    const cli_help_mod = b.addModule("cli_help", .{
        .root_source_file = b.path("src/cli/commands/help.zig"),
        .target = target,
    });
    cli_help_mod.addImport("cli_args", cli_args_mod);
    cli_help_mod.addImport("cli_config", cli_config_mod);
    cli_help_mod.addImport("cli_output", cli_output_mod);

    // Build static library for FFI integration with Rust Maze
    const lib = b.addLibrary(.{
        .name = "ananke",
        .linkage = .static,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/ffi/zig_ffi.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "ananke", .module = ananke_mod },
                .{ .name = "clew", .module = clew_mod },
                .{ .name = "braid", .module = braid_mod },
            },
        }),
    });
    lib.linkSystemLibrary("tree-sitter");
    lib.addIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/tree-sitter/include" });
    lib.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/opt/tree-sitter/lib" });
    lib.linkLibrary(ts_parser_lib);
    lib.linkLibrary(py_parser_lib);
    lib.linkLibrary(js_parser_lib);
    lib.linkLibrary(rust_parser_lib);
    lib.linkLibrary(go_parser_lib);
    lib.linkLibrary(zig_parser_lib);
    lib.linkLibrary(c_parser_lib);
    lib.linkLibrary(cpp_parser_lib);
    lib.linkLibrary(java_parser_lib);
    lib.linkLibrary(js_parser_lib);
    lib.linkLibrary(rust_parser_lib);
    lib.linkLibrary(go_parser_lib);
    lib.linkLibrary(zig_parser_lib);
    lib.linkLibrary(c_parser_lib);
    lib.linkLibrary(cpp_parser_lib);
    lib.linkLibrary(java_parser_lib);
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
            .link_libc = true,
            // List of modules available for import in source files part of the
            // root module.
            .imports = &.{
                .{ .name = "ananke", .module = ananke_mod },
                .{ .name = "clew", .module = clew_mod },
                .{ .name = "braid", .module = braid_mod },
                .{ .name = "ariadne", .module = ariadne_mod },
                .{ .name = "cli/args", .module = cli_args_mod },
                .{ .name = "cli/output", .module = cli_output_mod },
                .{ .name = "cli/config", .module = cli_config_mod },
                .{ .name = "cli/error", .module = cli_error_mod },
                .{ .name = "cli/commands/extract", .module = cli_extract_mod },
                .{ .name = "cli/commands/compile", .module = cli_compile_mod },
                .{ .name = "cli/commands/generate", .module = cli_generate_mod },
                .{ .name = "cli/commands/validate", .module = cli_validate_mod },
                .{ .name = "cli/commands/init", .module = cli_init_mod },
                .{ .name = "cli/commands/version", .module = cli_version_mod },
                .{ .name = "cli/commands/help", .module = cli_help_mod },
            },
        }),
    });

    // Link tree-sitter libraries
    exe.linkSystemLibrary("tree-sitter");
    exe.addIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/tree-sitter/include" });
    exe.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/opt/tree-sitter/lib" });
    exe.linkLibrary(ts_parser_lib);
    exe.linkLibrary(py_parser_lib);
    exe.linkLibrary(js_parser_lib);
    exe.linkLibrary(rust_parser_lib);
    exe.linkLibrary(go_parser_lib);
    exe.linkLibrary(zig_parser_lib);
    exe.linkLibrary(c_parser_lib);
    exe.linkLibrary(cpp_parser_lib);
    exe.linkLibrary(java_parser_lib);

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
    clew_tests.linkSystemLibrary("tree-sitter");
    clew_tests.addIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/tree-sitter/include" });
    clew_tests.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/opt/tree-sitter/lib" });
    clew_tests.linkLibrary(ts_parser_lib);
    clew_tests.linkLibrary(py_parser_lib);
    clew_tests.linkLibrary(js_parser_lib);
    clew_tests.linkLibrary(rust_parser_lib);
    clew_tests.linkLibrary(go_parser_lib);
    clew_tests.linkLibrary(zig_parser_lib);
    clew_tests.linkLibrary(c_parser_lib);
    clew_tests.linkLibrary(cpp_parser_lib);
    clew_tests.linkLibrary(java_parser_lib);

    const run_clew_tests = b.addRunArtifact(clew_tests);

    // Cache tests
    const cache_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/clew/cache_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "ananke", .module = ananke_mod },
                .{ .name = "clew", .module = clew_mod },
            },
        }),
    });
    cache_tests.linkSystemLibrary("tree-sitter");
    cache_tests.addIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/tree-sitter/include" });
    cache_tests.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/opt/tree-sitter/lib" });
    cache_tests.linkLibrary(ts_parser_lib);
    cache_tests.linkLibrary(py_parser_lib);
    cache_tests.linkLibrary(js_parser_lib);
    cache_tests.linkLibrary(rust_parser_lib);
    cache_tests.linkLibrary(go_parser_lib);
    cache_tests.linkLibrary(zig_parser_lib);
    cache_tests.linkLibrary(c_parser_lib);
    cache_tests.linkLibrary(cpp_parser_lib);
    cache_tests.linkLibrary(java_parser_lib);

    const run_cache_tests = b.addRunArtifact(cache_tests);

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
    pattern_tests.linkSystemLibrary("tree-sitter");
    pattern_tests.addIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/tree-sitter/include" });
    pattern_tests.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/opt/tree-sitter/lib" });
    pattern_tests.linkLibrary(ts_parser_lib);
    pattern_tests.linkLibrary(py_parser_lib);
    pattern_tests.linkLibrary(js_parser_lib);
    pattern_tests.linkLibrary(rust_parser_lib);
    pattern_tests.linkLibrary(go_parser_lib);
    pattern_tests.linkLibrary(zig_parser_lib);
    pattern_tests.linkLibrary(c_parser_lib);
    pattern_tests.linkLibrary(cpp_parser_lib);
    pattern_tests.linkLibrary(java_parser_lib);

    const run_pattern_tests = b.addRunArtifact(pattern_tests);

    // Tree-sitter FFI tests
    const tree_sitter_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/clew/tree_sitter_test.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "tree_sitter", .module = tree_sitter_mod },
            },
        }),
    });
    tree_sitter_tests.linkSystemLibrary("tree-sitter");
    tree_sitter_tests.addIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/tree-sitter/include" });
    tree_sitter_tests.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/opt/tree-sitter/lib" });
    tree_sitter_tests.linkLibrary(ts_parser_lib);
    tree_sitter_tests.linkLibrary(py_parser_lib);
    tree_sitter_tests.linkLibrary(js_parser_lib);
    tree_sitter_tests.linkLibrary(rust_parser_lib);
    tree_sitter_tests.linkLibrary(go_parser_lib);
    tree_sitter_tests.linkLibrary(zig_parser_lib);
    tree_sitter_tests.linkLibrary(c_parser_lib);
    tree_sitter_tests.linkLibrary(cpp_parser_lib);
    tree_sitter_tests.linkLibrary(java_parser_lib);

    const run_tree_sitter_tests = b.addRunArtifact(tree_sitter_tests);

    // Hybrid extractor integration tests
    const hybrid_extractor_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/clew/hybrid_extractor_test.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "ananke", .module = ananke_mod },
                .{ .name = "clew", .module = clew_mod },
                .{ .name = "tree_sitter", .module = tree_sitter_mod },
            },
        }),
    });
    hybrid_extractor_tests.linkSystemLibrary("tree-sitter");
    hybrid_extractor_tests.addIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/tree-sitter/include" });
    hybrid_extractor_tests.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/opt/tree-sitter/lib" });
    hybrid_extractor_tests.linkLibrary(ts_parser_lib);
    hybrid_extractor_tests.linkLibrary(py_parser_lib);
    hybrid_extractor_tests.linkLibrary(js_parser_lib);
    hybrid_extractor_tests.linkLibrary(rust_parser_lib);
    hybrid_extractor_tests.linkLibrary(go_parser_lib);
    hybrid_extractor_tests.linkLibrary(zig_parser_lib);
    hybrid_extractor_tests.linkLibrary(c_parser_lib);
    hybrid_extractor_tests.linkLibrary(cpp_parser_lib);
    hybrid_extractor_tests.linkLibrary(java_parser_lib);

    const run_hybrid_extractor_tests = b.addRunArtifact(hybrid_extractor_tests);

    // Tree-sitter traversal integration tests
    const traversal_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/clew/tree_sitter_traversal_test.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "tree_sitter", .module = tree_sitter_mod },
            },
        }),
    });
    traversal_tests.linkSystemLibrary("tree-sitter");
    traversal_tests.addIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/tree-sitter/include" });
    traversal_tests.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/opt/tree-sitter/lib" });
    traversal_tests.linkLibrary(ts_parser_lib);
    traversal_tests.linkLibrary(py_parser_lib);
    traversal_tests.linkLibrary(js_parser_lib);
    traversal_tests.linkLibrary(rust_parser_lib);
    traversal_tests.linkLibrary(go_parser_lib);
    traversal_tests.linkLibrary(zig_parser_lib);
    traversal_tests.linkLibrary(c_parser_lib);
    traversal_tests.linkLibrary(cpp_parser_lib);
    traversal_tests.linkLibrary(java_parser_lib);

    const run_traversal_tests = b.addRunArtifact(traversal_tests);

    // Phase 3: Rust/Go/Zig extraction tests
    const rust_go_zig_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/clew/rust_go_zig_extraction_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "ananke", .module = ananke_mod },
                .{ .name = "clew", .module = clew_mod },
            },
        }),
    });
    rust_go_zig_tests.linkSystemLibrary("tree-sitter");
    rust_go_zig_tests.addIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/tree-sitter/include" });
    rust_go_zig_tests.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/opt/tree-sitter/lib" });
    rust_go_zig_tests.linkLibrary(ts_parser_lib);
    rust_go_zig_tests.linkLibrary(py_parser_lib);
    rust_go_zig_tests.linkLibrary(js_parser_lib);
    rust_go_zig_tests.linkLibrary(rust_parser_lib);
    rust_go_zig_tests.linkLibrary(go_parser_lib);
    rust_go_zig_tests.linkLibrary(zig_parser_lib);
    rust_go_zig_tests.linkLibrary(c_parser_lib);
    rust_go_zig_tests.linkLibrary(cpp_parser_lib);
    rust_go_zig_tests.linkLibrary(java_parser_lib);

    const run_rust_go_zig_tests = b.addRunArtifact(rust_go_zig_tests);

    // Graph algorithm tests for Braid constraint compilation
    const graph_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/braid/graph_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "ananke", .module = ananke_mod },
                .{ .name = "braid", .module = braid_mod },
            },
        }),
    });

    const run_graph_tests = b.addRunArtifact(graph_tests);

    // JSON Schema generation tests for Braid
    const json_schema_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/braid/json_schema_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "ananke", .module = ananke_mod },
                .{ .name = "braid", .module = braid_mod },
            },
        }),
    });

    const run_json_schema_tests = b.addRunArtifact(json_schema_tests);

    // Grammar generation tests for Braid
    const grammar_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/braid/grammar_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "ananke", .module = ananke_mod },
                .{ .name = "braid", .module = braid_mod },
            },
        }),
    });

    const run_grammar_tests = b.addRunArtifact(grammar_tests);

    // Regex pattern extraction tests for Braid
    const regex_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/braid/regex_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "ananke", .module = ananke_mod },
                .{ .name = "braid", .module = braid_mod },
            },
        }),
    });

    const run_regex_tests = b.addRunArtifact(regex_tests);

    // Constraint operations tests for Braid
    const constraint_ops_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/braid/constraint_ops_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "ananke", .module = ananke_mod },
                .{ .name = "braid", .module = braid_mod },
            },
        }),
    });

    const run_constraint_ops_tests = b.addRunArtifact(constraint_ops_tests);

    // Token mask generation tests for Braid
    const token_mask_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/braid/token_mask_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "ananke", .module = ananke_mod },
                .{ .name = "braid", .module = braid_mod },
            },
        }),
    });

    const run_token_mask_tests = b.addRunArtifact(token_mask_tests);

    // Integration tests for Extract -> Compile pipeline
    const integration_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/integration/pipeline_tests.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "ananke", .module = ananke_mod },
                .{ .name = "clew", .module = clew_mod },
                .{ .name = "braid", .module = braid_mod },
            },
        }),
    });
    integration_tests.linkSystemLibrary("tree-sitter");
    integration_tests.addIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/tree-sitter/include" });
    integration_tests.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/opt/tree-sitter/lib" });
    integration_tests.linkLibrary(ts_parser_lib);
    integration_tests.linkLibrary(py_parser_lib);
    integration_tests.linkLibrary(js_parser_lib);
    integration_tests.linkLibrary(rust_parser_lib);
    integration_tests.linkLibrary(go_parser_lib);
    integration_tests.linkLibrary(zig_parser_lib);
    integration_tests.linkLibrary(c_parser_lib);
    integration_tests.linkLibrary(cpp_parser_lib);
    integration_tests.linkLibrary(java_parser_lib);

    const run_integration_tests = b.addRunArtifact(integration_tests);

    // E2E integration tests for full Zig -> Rust -> Modal pipeline
    const e2e_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/integration/e2e_pipeline_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "ananke", .module = ananke_mod },
                .{ .name = "clew", .module = clew_mod },
                .{ .name = "braid", .module = braid_mod },
            },
        }),
    });
    e2e_tests.linkSystemLibrary("tree-sitter");
    e2e_tests.addIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/tree-sitter/include" });
    e2e_tests.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/opt/tree-sitter/lib" });
    e2e_tests.linkLibrary(ts_parser_lib);
    e2e_tests.linkLibrary(py_parser_lib);
    e2e_tests.linkLibrary(js_parser_lib);
    e2e_tests.linkLibrary(rust_parser_lib);
    e2e_tests.linkLibrary(go_parser_lib);
    e2e_tests.linkLibrary(zig_parser_lib);
    e2e_tests.linkLibrary(c_parser_lib);
    e2e_tests.linkLibrary(cpp_parser_lib);
    e2e_tests.linkLibrary(java_parser_lib);

    const run_e2e_tests = b.addRunArtifact(e2e_tests);

    // New comprehensive E2E test suite with fixtures
    const new_e2e_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/e2e/e2e_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "ananke", .module = ananke_mod },
                .{ .name = "clew", .module = clew_mod },
                .{ .name = "braid", .module = braid_mod },
            },
        }),
    });
    new_e2e_tests.linkSystemLibrary("tree-sitter");
    new_e2e_tests.addIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/tree-sitter/include" });
    new_e2e_tests.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/opt/tree-sitter/lib" });
    new_e2e_tests.linkLibrary(ts_parser_lib);
    new_e2e_tests.linkLibrary(py_parser_lib);
    new_e2e_tests.linkLibrary(js_parser_lib);
    new_e2e_tests.linkLibrary(rust_parser_lib);
    new_e2e_tests.linkLibrary(go_parser_lib);
    new_e2e_tests.linkLibrary(zig_parser_lib);
    new_e2e_tests.linkLibrary(c_parser_lib);
    new_e2e_tests.linkLibrary(cpp_parser_lib);
    new_e2e_tests.linkLibrary(java_parser_lib);

    const run_new_e2e_tests = b.addRunArtifact(new_e2e_tests);

    // Phase 2 E2E tests: Full pipeline integration
    const phase2_full_pipeline_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/e2e/phase2/full_pipeline_test.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "ananke", .module = ananke_mod },
                .{ .name = "clew", .module = clew_mod },
                .{ .name = "tree_sitter", .module = tree_sitter_mod },
            },
        }),
    });
    phase2_full_pipeline_tests.linkSystemLibrary("tree-sitter");
    phase2_full_pipeline_tests.addIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/tree-sitter/include" });
    phase2_full_pipeline_tests.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/opt/tree-sitter/lib" });
    phase2_full_pipeline_tests.linkLibrary(ts_parser_lib);
    phase2_full_pipeline_tests.linkLibrary(py_parser_lib);
    phase2_full_pipeline_tests.linkLibrary(js_parser_lib);
    phase2_full_pipeline_tests.linkLibrary(rust_parser_lib);
    phase2_full_pipeline_tests.linkLibrary(go_parser_lib);
    phase2_full_pipeline_tests.linkLibrary(zig_parser_lib);
    phase2_full_pipeline_tests.linkLibrary(c_parser_lib);
    phase2_full_pipeline_tests.linkLibrary(cpp_parser_lib);
    phase2_full_pipeline_tests.linkLibrary(java_parser_lib);

    const run_phase2_full_pipeline_tests = b.addRunArtifact(phase2_full_pipeline_tests);

    // Phase 2 E2E tests: Multi-language integration
    const phase2_multi_language_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/e2e/phase2/multi_language_test.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "ananke", .module = ananke_mod },
                .{ .name = "clew", .module = clew_mod },
                .{ .name = "tree_sitter", .module = tree_sitter_mod },
            },
        }),
    });
    phase2_multi_language_tests.linkSystemLibrary("tree-sitter");
    phase2_multi_language_tests.addIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/tree-sitter/include" });
    phase2_multi_language_tests.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/opt/tree-sitter/lib" });
    phase2_multi_language_tests.linkLibrary(ts_parser_lib);
    phase2_multi_language_tests.linkLibrary(py_parser_lib);
    phase2_multi_language_tests.linkLibrary(js_parser_lib);
    phase2_multi_language_tests.linkLibrary(rust_parser_lib);
    phase2_multi_language_tests.linkLibrary(go_parser_lib);
    phase2_multi_language_tests.linkLibrary(zig_parser_lib);
    phase2_multi_language_tests.linkLibrary(c_parser_lib);
    phase2_multi_language_tests.linkLibrary(cpp_parser_lib);
    phase2_multi_language_tests.linkLibrary(java_parser_lib);

    const run_phase2_multi_language_tests = b.addRunArtifact(phase2_multi_language_tests);

    // Phase 2 E2E tests: Strategy comparison
    const phase2_strategy_comparison_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/e2e/phase2/strategy_comparison_test.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "ananke", .module = ananke_mod },
                .{ .name = "clew", .module = clew_mod },
                .{ .name = "tree_sitter", .module = tree_sitter_mod },
            },
        }),
    });
    phase2_strategy_comparison_tests.linkSystemLibrary("tree-sitter");
    phase2_strategy_comparison_tests.addIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/tree-sitter/include" });
    phase2_strategy_comparison_tests.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/opt/tree-sitter/lib" });
    phase2_strategy_comparison_tests.linkLibrary(ts_parser_lib);
    phase2_strategy_comparison_tests.linkLibrary(py_parser_lib);
    phase2_strategy_comparison_tests.linkLibrary(js_parser_lib);
    phase2_strategy_comparison_tests.linkLibrary(rust_parser_lib);
    phase2_strategy_comparison_tests.linkLibrary(go_parser_lib);
    phase2_strategy_comparison_tests.linkLibrary(zig_parser_lib);
    phase2_strategy_comparison_tests.linkLibrary(c_parser_lib);
    phase2_strategy_comparison_tests.linkLibrary(cpp_parser_lib);
    phase2_strategy_comparison_tests.linkLibrary(java_parser_lib);

    const run_phase2_strategy_comparison_tests = b.addRunArtifact(phase2_strategy_comparison_tests);

    // Phase 2 E2E tests: Constraint quality validation
    const phase2_constraint_quality_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/e2e/phase2/constraint_quality_test.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "ananke", .module = ananke_mod },
                .{ .name = "clew", .module = clew_mod },
                .{ .name = "tree_sitter", .module = tree_sitter_mod },
            },
        }),
    });
    phase2_constraint_quality_tests.linkSystemLibrary("tree-sitter");
    phase2_constraint_quality_tests.addIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/tree-sitter/include" });
    phase2_constraint_quality_tests.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/opt/tree-sitter/lib" });
    phase2_constraint_quality_tests.linkLibrary(ts_parser_lib);
    phase2_constraint_quality_tests.linkLibrary(py_parser_lib);
    phase2_constraint_quality_tests.linkLibrary(js_parser_lib);
    phase2_constraint_quality_tests.linkLibrary(rust_parser_lib);
    phase2_constraint_quality_tests.linkLibrary(go_parser_lib);
    phase2_constraint_quality_tests.linkLibrary(zig_parser_lib);
    phase2_constraint_quality_tests.linkLibrary(c_parser_lib);
    phase2_constraint_quality_tests.linkLibrary(cpp_parser_lib);
    phase2_constraint_quality_tests.linkLibrary(java_parser_lib);

    const run_phase2_constraint_quality_tests = b.addRunArtifact(phase2_constraint_quality_tests);

    // CLI tests
    const cli_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/cli/cli_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{},
        }),
    });

    // Add CLI module imports to CLI tests
    cli_tests.root_module.addImport("args", b.addModule("cli_args", .{
        .root_source_file = b.path("src/cli/args.zig"),
        .target = target,
    }));
    cli_tests.root_module.addImport("output", b.addModule("cli_output", .{
        .root_source_file = b.path("src/cli/output.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "types/constraint", .module = b.addModule("constraint_types", .{
                .root_source_file = b.path("src/types/constraint.zig"),
                .target = target,
            }) },
        },
    }));
    cli_tests.root_module.addImport("config", b.addModule("cli_config", .{
        .root_source_file = b.path("src/cli/config.zig"),
        .target = target,
    }));

    const run_cli_tests = b.addRunArtifact(cli_tests);

    // CLI integration tests
    const cli_integration_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/cli/cli_integration_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{},
        }),
    });

    // Add only the supporting module imports (not command modules)
    cli_integration_tests.root_module.addImport("cli_args", b.addModule("cli_args_test", .{
        .root_source_file = b.path("src/cli/args.zig"),
        .target = target,
    }));
    cli_integration_tests.root_module.addImport("cli_config", b.addModule("cli_config_test", .{
        .root_source_file = b.path("src/cli/config.zig"),
        .target = target,
    }));

    const run_cli_integration_tests = b.addRunArtifact(cli_integration_tests);

    // A top level step for running all tests. dependOn can be called multiple
    // times and since the two run steps do not depend on one another, this will
    // make the two of them run in parallel.
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
    test_step.dependOn(&run_clew_tests.step);
    test_step.dependOn(&run_cache_tests.step);
    test_step.dependOn(&run_pattern_tests.step);
    test_step.dependOn(&run_tree_sitter_tests.step);
    test_step.dependOn(&run_hybrid_extractor_tests.step);
    test_step.dependOn(&run_traversal_tests.step);
    test_step.dependOn(&run_rust_go_zig_tests.step);
    test_step.dependOn(&run_graph_tests.step);
    test_step.dependOn(&run_json_schema_tests.step);
    test_step.dependOn(&run_grammar_tests.step);
    test_step.dependOn(&run_regex_tests.step);
    test_step.dependOn(&run_constraint_ops_tests.step);
    test_step.dependOn(&run_token_mask_tests.step);
    test_step.dependOn(&run_integration_tests.step);
    test_step.dependOn(&run_e2e_tests.step);
    test_step.dependOn(&run_new_e2e_tests.step);
    test_step.dependOn(&run_phase2_full_pipeline_tests.step);
    test_step.dependOn(&run_phase2_multi_language_tests.step);
    test_step.dependOn(&run_phase2_strategy_comparison_tests.step);
    test_step.dependOn(&run_phase2_constraint_quality_tests.step);
    test_step.dependOn(&run_cli_tests.step);
    test_step.dependOn(&run_cli_integration_tests.step);

    // E2E test step (can be run separately)
    const e2e_test_step = b.step("test-e2e", "Run end-to-end integration tests");
    e2e_test_step.dependOn(&run_e2e_tests.step);
    e2e_test_step.dependOn(&run_new_e2e_tests.step);
    e2e_test_step.dependOn(&run_phase2_full_pipeline_tests.step);
    e2e_test_step.dependOn(&run_phase2_multi_language_tests.step);
    e2e_test_step.dependOn(&run_phase2_strategy_comparison_tests.step);
    e2e_test_step.dependOn(&run_phase2_constraint_quality_tests.step);

    // Phase 2 E2E test step (can be run separately)
    const phase2_test_step = b.step("test-phase2", "Run Phase 2 E2E integration tests");
    phase2_test_step.dependOn(&run_phase2_full_pipeline_tests.step);
    phase2_test_step.dependOn(&run_phase2_multi_language_tests.step);
    phase2_test_step.dependOn(&run_phase2_strategy_comparison_tests.step);
    phase2_test_step.dependOn(&run_phase2_constraint_quality_tests.step);

    // CLI test step (can be run separately)
    const cli_test_step = b.step("test-cli", "Run CLI tests");
    cli_test_step.dependOn(&run_cli_tests.step);
    cli_test_step.dependOn(&run_cli_integration_tests.step);

    // CLI integration test step (can be run separately)
    const cli_integration_test_step = b.step("test-cli-integration", "Run CLI integration tests");
    cli_integration_test_step.dependOn(&run_cli_integration_tests.step);

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
    clew_bench.linkSystemLibrary("tree-sitter");
    clew_bench.addIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/tree-sitter/include" });
    clew_bench.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/opt/tree-sitter/lib" });
    clew_bench.linkLibrary(ts_parser_lib);
    clew_bench.linkLibrary(py_parser_lib);
    clew_bench.linkLibrary(js_parser_lib);
    clew_bench.linkLibrary(rust_parser_lib);
    clew_bench.linkLibrary(go_parser_lib);
    clew_bench.linkLibrary(zig_parser_lib);
    clew_bench.linkLibrary(c_parser_lib);
    clew_bench.linkLibrary(cpp_parser_lib);
    clew_bench.linkLibrary(java_parser_lib);

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
    // ============================================================================
    // Additional Performance Benchmarks
    // ============================================================================

    // Multi-language extraction benchmarks
    const multi_lang_bench = b.addExecutable(.{
        .name = "multi_language_bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("benches/zig/multi_language_bench.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .imports = &.{
                .{ .name = "ananke", .module = ananke_mod },
                .{ .name = "clew", .module = clew_mod },
            },
        }),
    });
    b.installArtifact(multi_lang_bench);
    multi_lang_bench.linkSystemLibrary("tree-sitter");
    multi_lang_bench.addIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/tree-sitter/include" });
    multi_lang_bench.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/opt/tree-sitter/lib" });
    multi_lang_bench.linkLibrary(ts_parser_lib);
    multi_lang_bench.linkLibrary(py_parser_lib);
    multi_lang_bench.linkLibrary(js_parser_lib);
    multi_lang_bench.linkLibrary(rust_parser_lib);
    multi_lang_bench.linkLibrary(go_parser_lib);
    multi_lang_bench.linkLibrary(zig_parser_lib);
    multi_lang_bench.linkLibrary(c_parser_lib);
    multi_lang_bench.linkLibrary(cpp_parser_lib);
    multi_lang_bench.linkLibrary(java_parser_lib);

    const run_multi_lang_bench = b.addRunArtifact(multi_lang_bench);
    const multi_lang_bench_step = b.step("bench-multi-lang", "Run multi-language extraction benchmarks");
    multi_lang_bench_step.dependOn(&run_multi_lang_bench.step);

    // Constraint density benchmarks
    const density_bench = b.addExecutable(.{
        .name = "constraint_density_bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("benches/zig/constraint_density_bench.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .imports = &.{
                .{ .name = "ananke", .module = ananke_mod },
                .{ .name = "braid", .module = braid_mod },
            },
        }),
    });
    b.installArtifact(density_bench);

    const run_density_bench = b.addRunArtifact(density_bench);
    const density_bench_step = b.step("bench-density", "Run constraint density benchmarks");
    density_bench_step.dependOn(&run_density_bench.step);

    // Memory usage benchmarks
    const memory_bench = b.addExecutable(.{
        .name = "memory_bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("benches/zig/memory_bench.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .imports = &.{
                .{ .name = "ananke", .module = ananke_mod },
                .{ .name = "clew", .module = clew_mod },
                .{ .name = "braid", .module = braid_mod },
            },
        }),
    });
    b.installArtifact(memory_bench);
    memory_bench.linkSystemLibrary("tree-sitter");
    memory_bench.addIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/tree-sitter/include" });
    memory_bench.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/opt/tree-sitter/lib" });
    memory_bench.linkLibrary(ts_parser_lib);
    memory_bench.linkLibrary(py_parser_lib);
    memory_bench.linkLibrary(js_parser_lib);
    memory_bench.linkLibrary(rust_parser_lib);
    memory_bench.linkLibrary(go_parser_lib);
    memory_bench.linkLibrary(zig_parser_lib);
    memory_bench.linkLibrary(c_parser_lib);
    memory_bench.linkLibrary(cpp_parser_lib);
    memory_bench.linkLibrary(java_parser_lib);

    const run_memory_bench = b.addRunArtifact(memory_bench);
    const memory_bench_step = b.step("bench-memory", "Run memory usage benchmarks");
    memory_bench_step.dependOn(&run_memory_bench.step);

    // FFI roundtrip benchmarks
    const ffi_roundtrip_bench = b.addExecutable(.{
        .name = "ffi_roundtrip_bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("benches/zig/ffi_roundtrip_bench.zig"),
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
    b.installArtifact(ffi_roundtrip_bench);

    const run_ffi_roundtrip_bench = b.addRunArtifact(ffi_roundtrip_bench);
    const ffi_roundtrip_bench_step = b.step("bench-ffi-roundtrip", "Run FFI roundtrip benchmarks");
    ffi_roundtrip_bench_step.dependOn(&run_ffi_roundtrip_bench.step);

    // End-to-end pipeline benchmarks
    const pipeline_bench = b.addExecutable(.{
        .name = "pipeline_bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("benches/zig/pipeline_bench.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .imports = &.{
                .{ .name = "ananke", .module = ananke_mod },
                .{ .name = "clew", .module = clew_mod },
                .{ .name = "braid", .module = braid_mod },
            },
        }),
    });
    b.installArtifact(pipeline_bench);
    pipeline_bench.linkSystemLibrary("tree-sitter");
    pipeline_bench.addIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/tree-sitter/include" });
    pipeline_bench.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/opt/tree-sitter/lib" });
    pipeline_bench.linkLibrary(ts_parser_lib);
    pipeline_bench.linkLibrary(py_parser_lib);
    pipeline_bench.linkLibrary(js_parser_lib);
    pipeline_bench.linkLibrary(rust_parser_lib);
    pipeline_bench.linkLibrary(go_parser_lib);
    pipeline_bench.linkLibrary(zig_parser_lib);
    pipeline_bench.linkLibrary(c_parser_lib);
    pipeline_bench.linkLibrary(cpp_parser_lib);
    pipeline_bench.linkLibrary(java_parser_lib);

    const run_pipeline_bench = b.addRunArtifact(pipeline_bench);
    const pipeline_bench_step = b.step("bench-pipeline", "Run end-to-end pipeline benchmarks");
    pipeline_bench_step.dependOn(&run_pipeline_bench.step);

    // Regression test suite
    const regression_test = b.addExecutable(.{
        .name = "regression_test",
        .root_module = b.createModule(.{
            .root_source_file = b.path("benches/zig/regression_test.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .imports = &.{
                .{ .name = "ananke", .module = ananke_mod },
                .{ .name = "clew", .module = clew_mod },
                .{ .name = "braid", .module = braid_mod },
            },
        }),
    });
    b.installArtifact(regression_test);
    regression_test.linkSystemLibrary("tree-sitter");
    regression_test.addIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/tree-sitter/include" });
    regression_test.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/opt/tree-sitter/lib" });
    regression_test.linkLibrary(ts_parser_lib);
    regression_test.linkLibrary(py_parser_lib);
    regression_test.linkLibrary(js_parser_lib);
    regression_test.linkLibrary(rust_parser_lib);
    regression_test.linkLibrary(go_parser_lib);
    regression_test.linkLibrary(zig_parser_lib);
    regression_test.linkLibrary(c_parser_lib);
    regression_test.linkLibrary(cpp_parser_lib);
    regression_test.linkLibrary(java_parser_lib);

    const run_regression_test = b.addRunArtifact(regression_test);
    const regression_test_step = b.step("bench-regression", "Run performance regression tests");
    regression_test_step.dependOn(&run_regression_test.step);

    // Update comprehensive Zig benchmarks step
    bench_all_zig_step.dependOn(multi_lang_bench_step);
    bench_all_zig_step.dependOn(density_bench_step);
    bench_all_zig_step.dependOn(memory_bench_step);
    bench_all_zig_step.dependOn(ffi_roundtrip_bench_step);
    bench_all_zig_step.dependOn(pipeline_bench_step);
}
