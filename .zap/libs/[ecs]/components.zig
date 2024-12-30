const std = @import("std");
const zap = @import("../../main.zig");

pub const Transform = struct {
    position: zap.Vector2 = zap.Vec2(0, 0),
    rotation: f32 = 0,
    scale: zap.Vector2 = zap.Vec2(1, 1),
};
