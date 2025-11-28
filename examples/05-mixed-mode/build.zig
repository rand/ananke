const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const ananke = b.dependency("ananke", .{
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "mixed-mode",
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
    // Note: tree-sitter must be installed system-wide (brew install tree-sitter on macOS,
    // apt-get install libtree-sitter-dev on Ubuntu, pacman -S tree-sitter on Arch)
    exe.linkSystemLibrary("tree-sitter");
    exe.linkLibrary(ananke.artifact("tree-sitter-typescript"));
    exe.linkLibrary(ananke.artifact("tree-sitter-python"));
    exe.linkLibrary(ananke.artifact("tree-sitter-javascript"));
    exe.linkLibrary(ananke.artifact("tree-sitter-rust"));
    exe.linkLibrary(ananke.artifact("tree-sitter-go"));
    exe.linkLibrary(ananke.artifact("tree-sitter-zig"));
    exe.linkLibrary(ananke.artifact("tree-sitter-c"));
    exe.linkLibrary(ananke.artifact("tree-sitter-cpp"));
    exe.linkLibrary(ananke.artifact("tree-sitter-java"));

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the mixed-mode example");
    run_step.dependOn(&run_cmd.step);
}
