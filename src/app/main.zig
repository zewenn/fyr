const std = @import("std");
const zap = @import(".zap");

pub fn main() !void {
    const myvec2 = zap.Vec2(false, 120);
    std.log.debug("{any}", .{myvec2});

    _ = zap.changeType([]isize, null);
}
