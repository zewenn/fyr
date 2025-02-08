const std = @import("std");
const fyr = @import("../../main.zig");
const rl = @import("raylib");

const string = []const u8;

const UnitTag = enum {
    px,
    percent,
    vw,
    vh,
    fit,
    fill,
};

const Unit = union(UnitTag) {
    px: f32,
    percent: f32,
    vw: f32,
    vh: f32,
    fit,
    fill,
};

pub const BackgroundStyle = struct {
    color: ?rl.Color = null,
    image: ?string = null,
};

pub const FontStyle = struct {
    family: []const u8 = "press_play.ttf",
    size: usize = 12,
    color: rl.Color = rl.Color.white,
};

left: ?f32 = null,
top: ?f32 = null,
width: ?Unit = null,
height: ?Unit = null,

background: BackgroundStyle = .{},
font: FontStyle = .{},
