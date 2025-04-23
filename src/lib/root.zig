const std = @import("std");
const rl = @import("raylib");

pub fn hello() void {
    std.log.debug("hello world!", .{});
}
