const std = @import("std");
const zap = @import("../../main.zig");
const rl = zap.rl;
const assets = zap.libs.assets;

const display_components = @import("./components/display.zig");
const collision_components = @import("./components/collision.zig");

pub const Transform = struct {
    const Self = @This();

    position: zap.Vector3 = zap.Vec3(0, 0, 0),
    rotation: f32 = 0,
    scale: zap.Vector2 = zap.Vec2(64, 64),

    pub fn eql(self: Self, other: Self) bool {
        if (self.position.equals(other.position) == 0) return false;
        return eqlSkipPosition(self, other);
    }

    pub fn eqlSkipPosition(self: Self, other: Self) bool {
        if (self.rotation != other.rotation) return false;
        if (self.scale.equals(other.scale) == 0) return false;

        return true;
    }
};

pub const Display = display_components.Display;
pub const DisplayCache = display_components.DisplayCache;
pub const Renderer = display_components.Renderer;

pub const ColliderBehaviour = collision_components.ColliderBehaviour;
pub const Collider = collision_components.Collider;