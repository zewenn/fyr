const std = @import("std");
const fyr = @import("../../main.zig");

const rl = @import("raylib");
const rg = @import("raygui");

pub const raygui = struct {
    var fnptr: ?(*const fn () anyerror!void) = null;

    pub fn loadStyle(filename: []const u8) !void {
        const full_path = try fyr.assets.fs.getFilePath(filename);
        defer fyr.getAllocator(.gpa).free(full_path);

        const cpath = @as([:0]const u8, try fyr.getAllocator(.gpa).dupeZ(u8, full_path));
        defer fyr.getAllocator(.gpa).free(std.mem.span(cpath));

        rg.guiLoadStyle(cpath);
    }

    pub fn setRayGuiFunction(ptr: *const fn () anyerror!void) void {
        fnptr = ptr;
    }

    pub fn callDrawFn() void {
        (fnptr orelse return)() catch {
            std.log.warn("Failed to call raygui fn", .{});
            return;
        };
    }
};
