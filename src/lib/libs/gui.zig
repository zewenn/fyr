const std = @import("std");
const zap = @import("../main.zig");

const rl = @import("raylib");
const rg = @import("raygui");

var fnptr: ?(*const fn () anyerror!void) = null;

pub fn loadStyle(filename: []const u8) !void {
    const full_path = try zap.assets.getAssetFullPath(filename);
    defer zap.getAllocator(.gpa).free(full_path);

    const cpath = @as([*:0]const u8, try zap.getAllocator(.gpa).dupeZ(u8, full_path));
    defer zap.getAllocator(.gpa).free(std.mem.span(cpath));

    rg.guiLoadStyle(cpath);
}


