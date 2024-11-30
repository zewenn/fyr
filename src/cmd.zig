const std = @import("std");
const Allocator = @import("std").mem.Allocator;
const z = @import("./src/engine/z/z.m.zig");
const String = @import("./src/engine/strings.m.zig").String;

const BUF_128MB = 1024000000;

const cmds = enum { new_sript, quit, none };

fn keywordToEnum(kw: []const u8) cmds {
    if (std.mem.eql(u8, kw, "ns") or
        std.mem.eql(u8, kw, "new-script"))
    {
        return .new_sript;
    }
    if (std.mem.eql(u8, kw, "q") or
        std.mem.eql(u8, kw, "quit"))
    {
        return .quit;
    }
    return .none;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var allocator = gpa.allocator();

    var args = std.ArrayList([]u8).init(allocator);
    defer args.deinit();

    mainl: while (true) {
        args.clearAndFree();

        std.debug.print("\x1b[38;2;100;100;100m(zigsh)\x1b[0m ", .{});
        var cmd = try std.io.getStdIn().reader().readUntilDelimiterAlloc(allocator, '\n', BUF_128MB);
        defer allocator.free(cmd);

        const cmdp = try std.fmt.allocPrint(allocator, "{s} ", .{cmd});
        defer allocator.free(cmdp);

        var last: usize = 0;
        for (cmdp, 0..) |letter, i| {
            if (letter != ' ') continue;

            try args.append(cmd[last..i]);
            last = i + 1;
        }

        if (args.items.len == 0) continue;

        switch (keywordToEnum(args.items[0])) {
            .new_sript => {
                if (args.items.len < 3) {
                    z.dprint("[!] Not enough arguments {d}/2", .{args.items.len});
                    z.dprint("[!] Provide all arguments: ns <SceneID> <ScriptID>", .{});
                    continue;
                }
                const dest_dir_path = try std.fmt.allocPrint(
                    allocator,
                    "src/app/[{s}]",
                    .{args.items[1]},
                );
                defer allocator.free(dest_dir_path);

                const scene = try std.fmt.allocPrint(
                    allocator,
                    "src/app/[{s}]/{s}.zig",
                    .{
                        args.items[1],
                        args.items[2],
                    },
                );
                defer allocator.free(scene);

                var dest_dir = std.fs.cwd().openDir(dest_dir_path, .{}) catch {
                    z.dprint("[!] Scene does not exist!", .{});
                    continue :mainl;
                };
                dest_dir.close();

                const original = std.fs.cwd().openFile(".templates/script.zig", .{}) catch @panic("Cannot open script template");

                const o_contents = original.readToEndAlloc(allocator, BUF_128MB) catch |err| switch (err) {
                    error.FileTooBig => @panic("Maximum file size exceeded"),
                    else => @panic("Failed to read file"),
                };
                defer allocator.free(o_contents);

                original.close();

                const file = try std.fs.cwd().createFile(scene, .{
                    .truncate = false,
                    .read = true,
                });

                _ = try file.write(o_contents);
                file.close();
            },
            .quit => break :mainl,
            .none => continue :mainl,
        }
    }
}
