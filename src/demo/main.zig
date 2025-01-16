const std = @import("std");
const zap = @import("zap");

pub fn main() !void {
    try zap.init();
    defer zap.deinit();

    zap.loop();
}
