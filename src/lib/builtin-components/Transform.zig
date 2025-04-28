const loom = @import("../root.zig");

const Self = @This();

position: loom.Vector3 = loom.Vec3(0, 0, 0),
rotation: f32 = 0,
scale: loom.Vector2 = loom.Vec2(64, 64),

pub fn eql(self: Self, other: Self) bool {
    if (self.position.equals(other.position) == 0) return false;
    return eqlSkipPosition(self, other);
}

pub fn eqlSkipPosition(self: Self, other: Self) bool {
    if (self.rotation != other.rotation) return false;
    if (self.scale.equals(other.scale) == 0) return false;

    return true;
}
