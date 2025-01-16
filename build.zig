const std = @import("std");
const rlz = @import("raylib-zig");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // dependencies

    const raylib_dep = b.dependency("raylib-zig", .{
        .target = target,
        .optimize = optimize,
    });

    const raylib = raylib_dep.module("raylib");
    const raylib_artifact = raylib_dep.artifact("raylib");

    const uuid_dep = b.dependency("uuid", .{
        .target = target,
        .optimize = optimize,
    });

    const uuid = uuid_dep.module("uuid");
    const uuid_artifact = uuid_dep.artifact("uuid-zig");

    if (target.result.os.tag == .macos)
        raylib.addSystemFrameworkPath(
            .{ .cwd_relative = "/System/Library/Frameworks" },
        );

    // zap library

    const zap_module = b.addModule("zap", .{
        .root_source_file = b.path("./src/lib/main.zig"),
    });

    try b.modules.put(b.dupe("zap"), zap_module); 

    const lib = b.addStaticLibrary(.{
        .name = "zap",
        .root_source_file = b.path("src/lib/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    lib.root_module.addImport("raylib", raylib);
    lib.root_module.linkLibrary(raylib_artifact);

    lib.root_module.addImport("uuid", uuid);
    lib.root_module.linkLibrary(uuid_artifact);

    b.installArtifact(lib);

    // demo-exe

    const demo_exe = b.addExecutable(.{
        .name = "zap-demo",
        .root_source_file = b.path("src/demo/main.zig"),
        .optimize = optimize,
        .target = target,
    });

    demo_exe.root_module.addImport("zap", &lib.root_module);

    b.installArtifact(demo_exe);

    const run_cmd = b.addRunArtifact(demo_exe);
    const run_step = b.step("run", "run demo");
    run_step.dependOn(&run_cmd.step);
}
