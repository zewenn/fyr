const std = @import("std");
const rl = @import("../../main.zig").libs.raylib;

pub fn displayThisString(string: []const u8) void {
    std.log.debug("{s}", .{string});
}
