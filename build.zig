const std = @import("std");
const rlz = @import("raylib_zig");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // dependencies
    // ----------------------------------------------------------------------
    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
    });

    const raylib = raylib_dep.module("raylib");
    const raygui = raylib_dep.module("raygui");
    const raylib_artifact = raylib_dep.artifact("raylib");

    const uuid_dep = b.dependency("uuid", .{ .target = target, .optimize = optimize });
    const uuid = uuid_dep.module("uuid");

    const zclay_dep = b.dependency("zclay", .{
        .target = target,
        .optimize = optimize,
    });
    const zclay = zclay_dep.module("zclay");

    if (target.result.os.tag == .macos)
        raylib.addSystemFrameworkPath(
            .{ .cwd_relative = "/System/Library/Frameworks" },
        );

    // module
    // ----------------------------------------------------------------------
    const fyr_module = b.addModule("fyr", .{
        .root_source_file = b.path("./src/lib/main.zig"),
        .link_libc = true,
    });

    fyr_module.addImport("raylib", raylib);
    fyr_module.addImport("raygui", raygui);
    fyr_module.linkLibrary(raylib_artifact);

    fyr_module.addImport("uuid", uuid);

    fyr_module.addImport("zclay", zclay);

    try b.modules.put(b.dupe("fyr"), fyr_module);

    // library
    // ----------------------------------------------------------------------
    const lib = b.addStaticLibrary(.{
        .name = "fyr",
        .root_source_file = b.path("src/lib/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    lib.linkLibC();

    lib.root_module.addImport("raylib", raylib);
    lib.root_module.addImport("raygui", raygui);
    lib.root_module.linkLibrary(raylib_artifact);

    lib.root_module.addImport("uuid", uuid);

    lib.root_module.addImport("zclay", zclay);

    b.installArtifact(lib);

    // demo.exe
    // ----------------------------------------------------------------------
    const demo_exe = b.addExecutable(.{
        .name = "fyr-demo",
        .root_source_file = b.path("src/demo/main.zig"),
        .optimize = optimize,
        .target = target,
    });
    demo_exe.linkLibC();
    demo_exe.root_module.addImport("fyr", fyr_module);
    if (target.result.os.tag == .windows and optimize != .Debug)
        demo_exe.subsystem = .Windows;

    b.installArtifact(demo_exe);

    // Run Step
    // ----------------------------------------------------------------------
    const run_cmd = b.addRunArtifact(demo_exe);
    const run_step = b.step("run", "run demo");
    run_step.dependOn(&run_cmd.step);

    // Unit tests
    // ----------------------------------------------------------------------
    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/libtest/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_unit_tests.linkLibC();
    exe_unit_tests.root_module.addImport("fyr", lib.root_module);

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
