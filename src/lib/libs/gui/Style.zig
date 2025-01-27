const std = @import("std");
const fyr = @import("../../main.zig");
const rl = @import("raylib");

const string = []const u8;

const dim_tag = enum { grow, fill, number };

const dim = union(dim_tag) { grow: bool, fill: bool, number: f32 };

pub const StyleSheet = struct {
    pub const BackgroundStyle = struct {
        color: ?rl.Color = null,
        image: ?string = null,
    };

    pub const FontStyle = struct {
        family: []const u8 = "press_play.ttf",
        size: usize = 12,
        color: rl.Color = rl.Color.white,
    };

    left: ?f32,
    top: ?f32,
    width: ?dim,
    height: ?dim,

    background: BackgroundStyle = .{},
    font: FontStyle = .{},
};
