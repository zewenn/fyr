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

pub const Unit = union(UnitTag) {
    px: f32,
    percent: f32,
    vw: f32,
    vh: f32,
    fit,
    fill,
};

const Flow = enum {
    horizontal,
    vertical,
};

pub const BackgroundStyle = struct {
    color: ?rl.Color = null,
    image: ?string = null,
};

pub const FontStyle = struct {
    family: ?[]const u8 = null,
    size: f32 = 12,
    color: rl.Color = rl.Color.white,
};

pub const Position = enum {
    super,
    relative,
};

left: ?Unit = null,
top: ?Unit = null,
width: ?Unit = null,
height: ?Unit = null,
position: Position = .relative,

gap: ?Unit = null,

background: BackgroundStyle = .{},
font: FontStyle = .{},

flow: Flow = .vertical,
