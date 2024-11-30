const rlColor = @import("raylib").Color;
const std = @import("std");
const Allocator = @import("std").mem.Allocator;

pub const rl = rlColor;

pub const HEX = u32;

pub const white: HEX = 0xffecccff;
pub const black: HEX = 0x000000ff;

pub const light_gray = 0x8a5f70ff;
pub const gray = 0x5b445dff;
pub const dark_gray = 0x40334bff;
pub const yellow = 0xffcc74ff;
pub const gold = 0xffb570ff;
pub const orange = 0xea875aff;
pub const pink = 0xf16a76ff;
pub const red = 0xa9456aff;
pub const maroon = 0x6b2f5bff;
pub const green = 0xb4d9a8ff;
pub const lime = 0xe7d970ff;
pub const dark_green = 0x6a7261ff;
pub const sky_blue = 0x7273a7ff;
pub const blue = 0x51427aff;
pub const dark_blue = 0x422f5fff;
pub const purple = 0x614679ff;
pub const violet = 0x4e2a51ff;
pub const dark_purple = 0x492f62ff;
pub const beige = 0xffb592ff;
pub const brown = 0x964253ff;
pub const dark_brown = 0x57294bff;

pub const blank = 0x00000000;
pub const magenta = violet;
// pub const ray_white = Color.init(245, 245, 245, 255);

pub const RENDER_FILL_BACKGROUND: HEX = black;

var cache: std.AutoHashMap(HEX, rlColor) = undefined;
var alloc: Allocator = undefined;

pub fn init(allocator: Allocator) void {
    cache = std.AutoHashMap(u32, rlColor).init(allocator);
    alloc = allocator;
}

pub fn deinit() void {
    cache.deinit();
}

pub fn make(hex: HEX) rlColor {
    if (cache.contains(hex)) return cache.get(hex).?;

    const new = rlColor.fromInt(hex);
    cache.put(hex, new) catch {};

    return new;
}
