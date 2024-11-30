const std = @import("std");
const Allocator = @import("std").mem.Allocator;
const rl = @import("raylib");
const Colour = @import("../display/Colour.zig");

const entities = @import("../engine.m.zig").entities;
const z = @import("../z/z.m.zig");

const Unit = @import("Unit.zig");

const Self = @This();
const Translate = enum { min, center, max };

pub const Alignment = struct {
    x: Translate = .min,
    y: Translate = .min,
};

display: bool = true,

top: Unit = Unit.init(0, .px),
left: Unit = Unit.init(0, .px),

translate: Alignment = .{},
text_align: Alignment = .{
    .x = .min,
    .y = .min,
},

rotation: f32 = 0,

width: Unit = Unit.init(64, .px),
height: Unit = Unit.init(64, .px),

color: Colour.HEX = Colour.black,

background: struct {
    color: ?Colour.HEX = null,
    image: ?[]const u8 = null,
    fill: enum {
        scale,
        contain,
    } = .scale,
} = .{},

font: struct {
    family: []const u8 = "fonts/press_play.ttf",
    size: f32 = 16,
    spacing: f32 = 0,
    shadow: ?struct {
        offset: rl.Vector2 = .{
            .x = 0,
            .y = 0,
        },
        color: u32,
    } = null,
} = .{},

z_index: i32 = 0,

pub fn equals(self: *Self, other: Self) bool {
    if (!self.top.equals(other.top)) return false;
    if (!self.left.equals(other.left)) return false;

    if (self.rotation != other.rotation) return false;

    if (!self.width.equals(other.width)) return false;
    if (!self.height.equals(other.height)) return false;

    if (!self.color.normalize().equals(other.color.normalize()))
        return false;

    if (!self.background_color.normalize().equals(other.background_color.normalize()))
        return false;

    if (self.background_image) |sBgImg| {
        if (other.background_image) |oBgImg| {
            if (!std.mem.eql(u8, sBgImg, oBgImg)) return false;
        } else return false;
    } else if (other.background_image != null) return false;

    return true;
}

pub fn merge(self: *Self, other: Self) Self {
    const base = Self{};

    var result = self.*;

    if (!z.eql(base.font.family, other.font.family))
        result.font.family = other.font.family;

    if (!z.eql(base.font.size, other.font.size))
        result.font.size = other.font.size;

    if (!z.eql(base.font.spacing, other.font.spacing))
        result.font.spacing = other.font.spacing;

    if (base.font.shadow != null and other.font.shadow != null) {
        if (!z.eql(base.font.shadow.?.color, other.font.shadow.?.color))
            base.font.shadow.?.color = other.font.shadow.?.color;

        if (!z.eql(base.font.shadow.?.offset.x, other.font.shadow.?.offset.x))
            base.font.shadow.?.offset.x = other.font.shadow.?.offset.x;

        if (!z.eql(base.font.shadow.?.offset.y, other.font.shadow.?.offset.y))
            base.font.shadow.?.offset.y = other.font.shadow.?.offset.y;
    }

    // Transform

    if (!z.eql(base.top, other.top))
        result.top = other.top;

    if (!z.eql(base.left, other.left))
        result.left = other.left;

    if (!z.eql(base.rotation, other.rotation))
        result.rotation = other.rotation;

    if (!z.eql(base.width, other.width))
        result.width = other.width;

    if (!z.eql(base.height, other.height))
        result.height = other.height;

    // Translate

    if (!z.eql(base.translate.x, other.translate.x))
        result.translate.x = other.translate.x;

    if (!z.eql(base.translate.y, other.translate.y))
        result.translate.y = other.translate.y;

    // Color

    if (!z.eql(base.color, other.color))
        result.color = other.color;

    if (!z.eql(base.background, other.background))
        result.background = other.background;

    return result;
}

pub fn _merge(self: *Self, other: Self) Self {
    var result = self.*;

    if (!z.eql(result.font.family, other.font.family))
        result.font.family = other.font.family;

    if (!z.eql(result.font.size, other.font.size))
        result.font.size = other.font.size;

    if (!z.eql(result.font.spacing, other.font.spacing))
        result.font.spacing = other.font.spacing;

    // Transform

    if (!z.eql(result.top, other.top))
        result.top = other.top;

    if (!z.eql(result.left, other.left))
        result.left = other.left;

    if (!z.eql(result.rotation, other.rotation))
        result.rotation = other.rotation;

    if (!z.eql(result.width, other.width))
        result.width = other.width;

    if (!z.eql(result.height, other.height))
        result.height = other.height;

    // Translate

    if (!z.eql(result.translate.x, other.translate.x))
        result.translate.x = other.translate.x;

    if (!z.eql(result.translate.y, other.translate.y))
        result.translate.y = other.translate.y;

    // Color

    if (!z.eql(result.color, other.color))
        result.color = other.color;

    // Z-Index

    if (!z.eql(result.z_index, other.z_index))
        result.z_index = other.z_index;

    return result;
}
