const std = @import("std");
const rlz = @import("raylib_zig");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const loom_mod = b.createModule(.{
        .root_source_file = b.path("src/lib/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
        .linux_display_backend = rlz.LinuxDisplayBackend.X11,
    });

    const raylib = raylib_dep.module("raylib"); // main raylib module
    const raygui = raylib_dep.module("raygui"); // raygui module
    const raylib_artifact = raylib_dep.artifact("raylib"); // raylib C library

    const zclay_dep = b.dependency("zclay", .{ .target = target, .optimize = optimize });
    const zclay = zclay_dep.module("zclay");

    const uuid_dep = b.dependency("uuid", .{ .target = target, .optimize = optimize });
    const uuid = uuid_dep.module("uuid");

    loom_mod.addImport("raylib", raylib);
    loom_mod.addImport("raygui", raygui);
    loom_mod.addImport("zclay", zclay);
    loom_mod.linkLibrary(raylib_artifact);

    loom_mod.addImport("uuid", uuid);

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/demo/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_mod.addImport("loom", loom_mod);

    try b.modules.put("loom", loom_mod);

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "loom",
        .root_module = loom_mod,
    });
    b.installArtifact(lib);

    const exe = b.addExecutable(.{
        .name = "loom-demo",
        .root_module = exe_mod,
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const lib_unit_tests = b.addTest(.{ .root_module = loom_mod });
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const exe_unit_tests = b.addTest(.{ .root_module = exe_mod });
    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);
}
