const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Get the ananke dependency
    const ananke = b.dependency("ananke", .{
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "full-pipeline",
        .root_module = b.createModule(.{
            .root_source_file = b.path("main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "ananke", .module = ananke.module("ananke") },
            },
        }),
    });

    // Link tree-sitter and language parsers from the ananke dependency
    exe.linkSystemLibrary("tree-sitter");
    exe.addSystemIncludePath(.{ .cwd_relative = "/opt/homebrew/Cellar/tree-sitter/0.25.10/include" });
    exe.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/Cellar/tree-sitter/0.25.10/lib" });
    exe.linkLibrary(ananke.artifact("tree-sitter-typescript"));
    exe.linkLibrary(ananke.artifact("tree-sitter-python"));
    exe.linkLibrary(ananke.artifact("tree-sitter-javascript"));
    exe.linkLibrary(ananke.artifact("tree-sitter-rust"));
    exe.linkLibrary(ananke.artifact("tree-sitter-go"));
    exe.linkLibrary(ananke.artifact("tree-sitter-zig"));
    exe.linkLibrary(ananke.artifact("tree-sitter-c"));
    exe.linkLibrary(ananke.artifact("tree-sitter-cpp"));
    exe.linkLibrary(ananke.artifact("tree-sitter-java"));

    // Note: Maze library linking will be added once FFI functions are implemented
    // const build_mode = if (optimize == .Debug) "debug" else "release";
    // const maze_lib_path = b.fmt("../../maze/target/{s}", .{build_mode});
    // exe.addLibraryPath(.{ .cwd_relative = maze_lib_path });
    // exe.linkSystemLibrary("maze");
    // exe.linkLibC();

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the full pipeline example");
    run_step.dependOn(&run_cmd.step);
}
