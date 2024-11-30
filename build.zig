const std = @import("std");
const builtin = @import("builtin");
const rlz = @import("raylib-zig");
const Allocator = @import("std").mem.Allocator;
const String = @import("./src/engine/strings.m.zig").String;

const BUF_128MB = 1024000000;

pub fn build(b: *std.Build) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var allocator = gpa.allocator();

    // Making the src/.temp directory
    std.fs.cwd().makeDir("./src/.temp/") catch {};

    Filenames: {
        // const files_dir = "./src/assets/";
        const output_file = std.fs.cwd().createFile(
            "src/.temp/filenames.zig",
            .{
                .truncate = true,
                .exclusive = false,
            },
        ) catch @panic("Couldn't open outfile!");
        defer output_file.close();

        const res = getEntries(
            "./src/assets/",
            allocator,
            false,
            false,
        );
        defer {
            for (res) |item| {
                allocator.free(item);
            }
            allocator.free(res);
        }

        var writer = output_file.writer();
        writer.writeAll("") catch break :Filenames;
        _ = writer.write("pub const Filenames = [_][]const u8{\n") catch break :Filenames;

        for (res, 0..) |filepath, i| {
            if (i == 0) {
                _ = writer.write("\t\"") catch break :Filenames;
            } else {
                _ = writer.write("\",\n\t\"") catch break :Filenames;
            }

            switch (builtin.os.tag) {
                .windows => {
                    const str = try allocator.alloc(u8, filepath.len);
                    defer allocator.free(str);

                    std.mem.copyForwards(u8, str, filepath);

                    const owned = std.mem.replaceOwned(u8, allocator, filepath, "\\", "/") catch break :Filenames;
                    defer allocator.free(owned);

                    writer.print("{s}", .{owned}) catch break :Filenames;
                },
                else => {
                    writer.print("{s}", .{filepath}) catch break :Filenames;
                },
            }

            if (i == res.len - 1) {
                _ = writer.write("\"") catch unreachable;
            }
        }
        _ = writer.write("\n};") catch unreachable;

        break :Filenames;
    }

    // Handling Scenes & Scripts
    Scenes: {
        const output_file = std.fs.cwd().createFile(
            "src/.temp/script_run.zig",
            .{
                .truncate = true,
                .exclusive = false,
            },
        ) catch unreachable;

        var writer = output_file.writer();
        writer.writeAll("") catch unreachable;
        _ = writer.write("const sc = @import(\"../engine/scenes.m.zig\");\n\n") catch unreachable;
        _ = writer.write("pub fn register() !void {\n") catch unreachable;

        const scene_directories = getEntries(
            "./src/app/",
            allocator,
            true,
            true,
        );
        defer {
            for (scene_directories) |item| {
                allocator.free(item);
            }
            allocator.free(scene_directories);
        }

        for (scene_directories) |shallow_entry_path| {
            const scene_name = shallow_entry_path[1 .. shallow_entry_path.len - 1];

            var shallow_entry_string = String.init_with_contents(
                allocator,
                shallow_entry_path,
            ) catch @panic("Couldn't create shallow string");
            defer shallow_entry_string.deinit();

            if (!shallow_entry_string.startsWith("[") or !shallow_entry_string.endsWith("]")) continue;

            var sub_path_string = String.init_with_contents(allocator, "./src/app/") catch unreachable;
            defer sub_path_string.deinit();

            sub_path_string.concat(shallow_entry_path) catch @panic("Failed to concat wtf");

            const sub_path = (sub_path_string.toOwned() catch unreachable).?;
            defer allocator.free(sub_path);

            const script_paths = getEntries(
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
                var string_path_from_cwd = sub_path_string.clone() catch @panic("Failed to initalise string");
                defer string_path_from_cwd.deinit();

                string_path_from_cwd.concat("/") catch @panic("Couldn't concat!");
                string_path_from_cwd.concat(path) catch @panic("Couldn't concat!");

                const path_from_cwd = (string_path_from_cwd.toOwned() catch
                    @panic("Couldn't make into owned slice")).?;
                defer allocator.free(path_from_cwd);

                const file = std.fs.cwd().openFile(path_from_cwd, .{}) catch @panic("Failed to open file");
                defer file.close();

                const contents = file.readToEndAlloc(allocator, BUF_128MB) catch |err| switch (err) {
                    error.FileTooBig => @panic("Maximum file size exceeded"),
                    else => @panic("Failed to read file"),
                };
                defer allocator.free(contents);

                writer.print("\ttry sc.register(\"{s}\", sc.Script", .{scene_name}) catch unreachable;
                _ = writer.write("{\n") catch unreachable;

                if (std.mem.containsAtLeast(
                    u8,
                    contents,
                    1,
                    "\npub fn awake(",
                )) {
                    writer.print(
                        "\t\t.eAwake = @import(\"../app/{s}/{s}\").awake,\n",
                        .{ shallow_entry_path, path },
                    ) catch unreachable;
                }
                if (std.mem.containsAtLeast(
                    u8,
                    contents,
                    1,
                    "\npub fn init(",
                )) {
                    writer.print(
                        "\t\t.eInit = @import(\"../app/{s}/{s}\").init,\n",
                        .{ shallow_entry_path, path },
                    ) catch unreachable;
                }
                if (std.mem.containsAtLeast(
                    u8,
                    contents,
                    1,
                    "\npub fn update(",
                )) {
                    writer.print(
                        "\t\t.eUpdate = @import(\"../app/{s}/{s}\").update,\n",
                        .{ shallow_entry_path, path },
                    ) catch unreachable;
                }
                if (std.mem.containsAtLeast(
                    u8,
                    contents,
                    1,
                    "\npub fn deinit(",
                )) {
                    writer.print(
                        "\t\t.eDeinit = @import(\"../app/{s}/{s}\").deinit,\n",
                        .{ shallow_entry_path, path },
                    ) catch unreachable;
                }

                _ = writer.write("\t});") catch unreachable;
            }
        }
        _ = writer.write("\n}") catch unreachable;
        break :Scenes;
    }

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "OverLife",
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
        const exe_lib = rlz.emcc.compileForEmscripten(b, "OverLife", "src/main.zig", target, optimize);

        exe_lib.linkLibrary(raylib_artifact);
        exe_lib.root_module.addImport("raylib", raylib);

        // Note that raylib itself is not actually added to the exe_lib output file, so it also needs to be linked with emscripten.
        const link_step = try rlz.emcc.linkWithEmscripten(b, &[_]*std.Build.Step.Compile{ exe_lib, raylib_artifact });

        b.getInstallStep().dependOn(&link_step.step);
        const run_step = try rlz.emcc.emscriptenRunStep(b);
        run_step.step.dependOn(&link_step.step);
        const run_option = b.step("run", "Run OverLife");
        run_option.dependOn(&run_step.step);
        return;
    }

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
fn getEntries(files_dir: []const u8, allocator: Allocator, shallow: bool, include_dirs: bool) [][]const u8 {
    var dir = std.fs.cwd().openDir(files_dir, .{ .iterate = true }) catch unreachable;
    defer dir.close();

    var result = std.ArrayList([]const u8).init(allocator);

    if (!shallow) {
        var walker =
            dir.walk(allocator) catch
            @panic("Couldn't walk");

        defer walker.deinit();

        while (walker.next() catch @panic("Failed to iterate directory")) |*entry| {
            if (!include_dirs and entry.kind == .directory) continue;
            if (std.mem.eql(u8, entry.basename, ".DS_Store")) continue;

            const copied = allocator.alloc(u8, std.mem.replacementSize(u8, entry.path, "\\", "/")) catch
                @panic("Failed to allocate memory for slice");

            _ = std.mem.replace(u8, entry.path, "\\", "/", copied);

            result.append(copied) catch @panic("Failed to append slice to result");
        }

        return result.toOwnedSlice() catch @panic("Failed too convert to owned slice");
    } else {
        var iterator: std.fs.Dir.Iterator = dir.iterate();

        while (iterator.next() catch @panic("Failed to iterate directory")) |*entry| {
            if (!include_dirs and entry.kind == .directory) continue;

            if (std.mem.eql(u8, entry.name, ".DS_Store")) continue;

            const copied = allocator.alloc(u8, entry.name.len) catch
                @panic("Failed to allocate memory for slice");

            for (copied, entry.name) |*l, l2| {
                l.* = l2;
            }
            result.append(copied) catch @panic("Failed to append slice to result");
        }
    }

    return result.toOwnedSlice() catch @panic("Failed to convert to owned slice");
}
