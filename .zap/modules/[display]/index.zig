const std = @import("std");
const rl = @import("../../main.zig").libs.raylib;

pub fn displayThisString(string: []const u8) void {
    std.log.debug("{s}", .{string});
}

pub fn awake() !void {
    std.log.debug("Hello from display!", .{});
}

pub fn update() !void {
    rl.beginDrawing();
    defer rl.endDrawing();

    rl.clearBackground(rl.Color.white);
}

pub fn tick() !void {
    // std.log.debug("Ticking display!", .{});
}
