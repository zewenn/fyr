const std = @import("std");
const fyr = @import("../../main.zig");
const rl = fyr.rl;
const assets = fyr.libs.assets;

const display_components = @import("./components/display.zig");
const collision_components = @import("./components/collision.zig");
const camera_components = @import("./components/camera.zig");
const animator_components = @import("./components/animator/index.zig");

pub const Transform = struct {
    const Self = @This();

    position: fyr.Vector3 = fyr.Vec3(0, 0, 0),
    rotation: f32 = 0,
    scale: fyr.Vector2 = fyr.Vec2(64, 64),

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

pub const CameraTarget = camera_components.CameraTarget;

pub const Animator = animator_components.Animator;
pub const AnimatorBehaviour = animator_components.AnimatorBehaviour;
pub const Animation = animator_components.Animation;
pub const KeyFrame = animator_components.KeyFrame;
pub const interpolation = animator_components.t.interpolation;
