const std = @import("std");
const Allocator = @import("std").mem.Allocator;
const rl = @import("raylib");

const entities = @import("../engine.m.zig").entities;

const Self = @This();

// === Transform ===

// Position
x: ?f32 = null,
y: ?f32 = null,

// Rotation
rx: ?f32 = null,
ry: ?f32 = null,
rotation: ?f32 = null,

// Scale
width: ?f32 = null,
height: ?f32 = null,

// === Display ===

sprite: ?[]const u8 = null,
scaling: ?entities.Display.scalings = null,
tint: ?rl.Color = null,

// DUMMY

d1f32: ?f32 = null,
d2f32: ?f32 = null,
d3f32: ?f32 = null,
d4f32: ?f32 = null,
d5f32: ?f32 = null,
d6f32: ?f32 = null,
d7f32: ?f32 = null,
d8f32: ?f32 = null,

d1u8: ?u8 = null,
d2u8: ?u8 = null,
d3u8: ?u8 = null,
d4u8: ?u8 = null,
d5u8: ?u8 = null,
d6u8: ?u8 = null,
d7u8: ?u8 = null,
d8u8: ?u8 = null,

d1Color: ?rl.Color = null,
d2Color: ?rl.Color = null,
d3Color: ?rl.Color = null,
d4Color: ?rl.Color = null,
