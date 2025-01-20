const std = @import("std");
const zap = @import("../../main.zig");
const rl = @import("raylib");

const string = []const u8;

pub const StyleSheet = struct {
    pub const BackgroundStyle = struct {
        color: ?rl.Color = null,
        image: ?string = null,
    };

    pub const FontStyle = struct {
        family: ?rl.Font = null,
        size: usize = 12,
        color: rl.Color = rl.Color.white,
    };

    rectangle: ?zap.Rectangle = null,
    background: BackgroundStyle = .{},
};
