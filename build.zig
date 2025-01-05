const std = @import("std");
const rlz = @import("raylib-zig");

const builtin = @import("builtin");
const fs = std.fs;

const Allocator = @import("std").mem.Allocator;
const String = @import("./.zap/libs/[string]/index.zig");

const BUF_128MB = 1024000000;

pub fn build(b: *std.Build) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.raw_c_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    // Making the src/.temp directory
    fs.cwd().makeDir("./src/.codegen/") catch {};
    fs.cwd().makeDir("./.zap/.codegen/") catch {};

    // Handling Scenes & Scripts

    Blk: {
        fs.cwd().makeDir("./src/app/[default]/") catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => @panic("Default instance dir couldn't be created!"),
        };

        var default = fs.cwd().openDir("./src/app/[default]/", .{ .iterate = true }) catch break :Blk;
        defer default.close();
        errdefer default.close();

        var it = default.iterate();
        while (it.next() catch break :Blk) |entry| {
            if (entry.kind == .file) break :Blk;
        }

        var file = default.createFile("index.zig", .{}) catch @panic("Couldn't create file in [default]");
        defer file.close();

        _ = file.write("const std = @import(\"std\");\nconst zap = @import(\".zap\");") catch {};
    }

    generateInstanceRegister(
        allocator,
        "./src/app/",
        "./src/.codegen/instances.zig",
    ) catch {
        std.log.err("failed to generate instance data from file structure!", .{});
    };

    Libs: {
        const output_file = std.fs.cwd().createFile(
            ".zap/.codegen/libs.zig",
            .{
                .truncate = true,
                .exclusive = false,
            },
        ) catch unreachable;

        var writer = output_file.writer();
        writer.writeAll("") catch unreachable;

        const scene_directories = getEntries(
            "./.zap/libs/",
            allocator,
            true,
            true,
        ) catch unreachable;
        defer {
            for (scene_directories) |item| {
                allocator.free(item);
            }
            allocator.free(scene_directories);
        }

        for (scene_directories) |shallow_entry_path| {
            const libname = shallow_entry_path[1 .. shallow_entry_path.len - 1];

            var shallow_entry_string = String.init_with_contents(
                allocator,
                shallow_entry_path,
            ) catch @panic("Couldn't create shallow string");
            defer shallow_entry_string.deinit();

            if (!shallow_entry_string.startsWith("[") or !shallow_entry_string.endsWith("]")) continue;

            writer.print("pub const {s} = @import(\"../libs/[{s}]/index.zig\");\n", .{ libname, libname }) catch unreachable;
        }
        break :Libs;
    }

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    if (optimize != .Debug) {
        try copyDir(allocator, "./src/assets/", "./zig-out/bin/assets/");
    }

    const exe = b.addExecutable(.{
        .name = "zap-engine-project",
        .root_source_file = b.path("src/main.zig"),
        .optimize = optimize,
        .target = target,
    });

    exe.addSystemFrameworkPath(
        .{ .cwd_relative = "/System/Library/Frameworks" },
    );
    // step.addSystemFrameworkPath(.{ .cwd_relative = "/System/Library/Frameworks" });

    const raylib_dep = b.dependency("raylib-zig", .{
        .target = target,
        .optimize = optimize,
    });

    const uuid_dep = b.dependency("uuid", .{
        .target = target,
        .optimize = optimize,
    });

    const raylib = raylib_dep.module("raylib");
    const raylib_artifact = raylib_dep.artifact("raylib");
    raylib.addSystemFrameworkPath(
        .{ .cwd_relative = "/System/Library/Frameworks" },
    );

    const uuid = uuid_dep.module("uuid");
    const uuid_artifact = uuid_dep.artifact("uuid-zig");

    //web exports are completely separate
    if (target.query.os_tag == .emscripten) {
        const exe_lib = try rlz.emcc.compileForEmscripten(b, "Project", "src/main.zig", target, optimize);

        exe_lib.linkLibrary(raylib_artifact);
        exe_lib.root_module.addImport("raylib", raylib);

        // Note that raylib itself is not actually added to the exe_lib output file, so it also needs to be linked with emscripten.
        const link_step = try rlz.emcc.linkWithEmscripten(b, &[_]*std.Build.Step.Compile{ exe_lib, raylib_artifact });
        //this lets your program access files like "resources/my-image.png":
        link_step.addArg("--embed-file");
        link_step.addArg("resources/");

        b.getInstallStep().dependOn(&link_step.step);
        const run_step = try rlz.emcc.emscriptenRunStep(b);
        run_step.step.dependOn(&link_step.step);
        const run_option = b.step("run", "Run Project");
        run_option.dependOn(&run_step.step);
        return;
    }

    const zap = b.addModule("zap", .{
        .root_source_file = .{ .cwd_relative = ".zap/main.zig" },
    });
    zap.linkLibrary(raylib_artifact);
    zap.addImport("raylib", raylib);
    zap.linkLibrary(uuid_artifact);
    zap.addImport("uuid", uuid);

    exe.root_module.addImport(".zap", zap);

    exe.linkLibrary(raylib_artifact);
    exe.root_module.addImport("raylib", raylib);

    exe.linkLibrary(uuid_artifact);
    exe.root_module.addImport("uuid", uuid);

    if (target.result.os.tag == .windows) {
        exe.linkLibC();
    }

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run OverLife");
    run_step.dependOn(&run_cmd.step);
}

const Segment = struct {
    alloc: std.mem.Allocator,
    list: std.ArrayListAligned([]const u8, null),
};

/// Caller owns the returned memory.
/// Returns the path of the entires.
fn getEntries(files_dir: []const u8, allocator: Allocator, shallow: bool, include_dirs: bool) ![][]const u8 {
    var dir = try std.fs.cwd().openDir(files_dir, .{ .iterate = true });
    defer dir.close();

    var result = std.ArrayList([]const u8).init(allocator);

    if (!shallow) {
        var walker = try dir.walk(allocator);

        defer walker.deinit();

        while (try walker.next()) |*entry| {
            if (!include_dirs and entry.kind == .directory) continue;
            if (std.mem.eql(u8, entry.basename, ".DS_Store")) continue;

            const copied = try allocator.alloc(u8, std.mem.replacementSize(u8, entry.path, "\\", "/"));

            _ = std.mem.replace(u8, entry.path, "\\", "/", copied);

            try result.append(copied);
        }

        return try result.toOwnedSlice();
    }

    var iterator: std.fs.Dir.Iterator = dir.iterate();

    while (try iterator.next()) |*entry| {
        if (!include_dirs and entry.kind == .directory) continue;

        if (std.mem.eql(u8, entry.name, ".DS_Store")) continue;

        const copied = try allocator.alloc(u8, entry.name.len);

        for (copied, entry.name) |*l, l2| {
            l.* = l2;
        }
        try result.append(copied);
    }

    return try result.toOwnedSlice();
}

fn generateInstanceRegister(
    allocator: Allocator,
    instances_dir_path: []const u8,
    out_file_path: []const u8,
) !void {
    const output_file = try std.fs.cwd().createFile(
        out_file_path,
        .{
            .truncate = true,
            .exclusive = false,
        },
    );
    defer output_file.close();

    var writer = output_file.writer();
    try writer.writeAll("");

    _ = try writer.write("const zap = @import(\".zap\");\n");
    _ = try writer.write("const el = zap.libs.eventloop;\n\n");

    _ = try writer.write("pub fn register() !void {");
    defer _ = writer.write("\n}") catch {
        std.log.err("Write failiure", .{});
        unreachable;
    };

    const inner_directories = try getEntries(
        instances_dir_path,
        allocator,
        true,
        true,
    );
    defer {
        for (inner_directories) |item| {
            allocator.free(item);
        }
        allocator.free(inner_directories);
    }

    for (inner_directories) |shallow_entry_path| {
        const instance_name = shallow_entry_path[1 .. shallow_entry_path.len - 1];

        var shallow_entry_string = try String.init_with_contents(
            allocator,
            shallow_entry_path,
        );
        defer shallow_entry_string.deinit();

        if (!shallow_entry_string.startsWith("[") or !shallow_entry_string.endsWith("]")) continue;

        var sub_path_string = try String.init_with_contents(allocator, "./src/app/");
        defer sub_path_string.deinit();

        try sub_path_string.concat(shallow_entry_path);

        const sub_path = (try sub_path_string.toOwned()) orelse return error.InvalidString;
        defer allocator.free(sub_path);

        const script_paths = try getEntries(
            sub_path,
            allocator,
            false,
            false,
        );
        defer {
            for (script_paths) |item| {
                allocator.free(item);
            }
            allocator.free(script_paths);
        }

        for (script_paths) |path| {
            var string_path_from_cwd = try sub_path_string.clone();
            defer string_path_from_cwd.deinit();

            try string_path_from_cwd.concat("/");
            try string_path_from_cwd.concat(path);

            const path_from_cwd = (try string_path_from_cwd.toOwned()) orelse return error.InvalidString;
            defer allocator.free(path_from_cwd);

            const file = try std.fs.cwd().openFile(path_from_cwd, .{});
            defer file.close();

            const contents = try file.readToEndAlloc(allocator, BUF_128MB);
            defer allocator.free(contents);

            try writer.print("\n\n\t// ----- [{s}] -----\n", .{instance_name});
            try writer.print(
                "\n\tconst {s}_instance = try el.new(\"{s}\");\n",
                .{ instance_name, instance_name },
            );
            _ = try writer.write("\t{\n");
            defer _ = writer.write("\n\t}") catch {
                std.log.err("Filer write error", .{});
                unreachable;
            };

            var added = false;

            if (std.mem.containsAtLeast(
                u8,
                contents,
                1,
                "\npub fn awake(",
            )) {
                added = true;
                try printEventImport(
                    writer,
                    "awake",
                    instance_name,
                    path,
                );
            }
            if (std.mem.containsAtLeast(
                u8,
                contents,
                1,
                "\npub fn init(",
            )) {
                added = true;
                try printEventImport(
                    writer,
                    "init",
                    instance_name,
                    path,
                );
            }
            if (std.mem.containsAtLeast(
                u8,
                contents,
                1,
                "\npub fn update(",
            )) {
                added = true;
                try printEventImport(
                    writer,
                    "update",
                    instance_name,
                    path,
                );
            }
            if (std.mem.containsAtLeast(
                u8,
                contents,
                1,
                "\npub fn tick(",
            )) {
                added = true;
                try printEventImport(
                    writer,
                    "tick",
                    instance_name,
                    path,
                );
            }
            if (std.mem.containsAtLeast(
                u8,
                contents,
                1,
                "\npub fn deinit(",
            )) {
                added = true;
                try printEventImport(
                    writer,
                    "deinit",
                    instance_name,
                    path,
                );
            }

            if (!added)
                try writer.print("\t\t_ = {s}_instance;", .{instance_name});
        }
    }
}

fn printEventImport(
    writer: std.fs.File.Writer,
    event: []const u8,
    scene_name: []const u8,
    filename: []const u8,
) !void {
    try writer.print("\t\ttry {s}_instance.on(\n", .{scene_name});
    defer _ = writer.write("\t\t);") catch {
        std.log.err("Filer write error", .{});
        unreachable;
    };

    try writer.print("\t\t\tel.Events.{s},\n", .{event});
    _ = try writer.write("\t\t\t.{");
    try writer.print(
        " .fn_ptr = @import(\"../app/[{s}]/{s}\").{s}, .on_fail = .remove ",
        .{ scene_name, filename, event },
    );
    _ = try writer.write("},\n");
}

fn copyDir(allocator: Allocator, src_path: []const u8, dist_path: []const u8) !void {
    var src_dir = try std.fs.cwd().openDir(
        src_path,
        .{ .iterate = true },
    );
    defer src_dir.close();

    var dest_dir = try std.fs.cwd().makeOpenPath(dist_path, .{});
    defer dest_dir.close();

    var walker = try src_dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        switch (entry.kind) {
            .file => {
                try entry.dir.copyFile(entry.basename, dest_dir, entry.path, .{});
            },
            .directory => {
                try dest_dir.makeDir(entry.path);
            },
            else => return error.UnexpectedEntryKind,
        }
    }
}
