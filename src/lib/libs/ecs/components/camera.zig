const std = @import("std");
const fyr = @import("../../../main.zig");
const rl = fyr.rl;

const Transform = @import("../components.zig").Transform;

pub const CameraTarget = struct {
    pub const FYR_BEHAVIOUR = {};
    const Self = @This();

    transform: ?*Transform = null,
    max_distance: f32 = 0,
    min_distance: f32 = 0,
    follow_speed: f32 = 1,

    pub fn Awake(self: *Self, entity: *fyr.Entity) !void {
        const transform = entity.getComponent(Transform) orelse Blk: {
            try entity.addComonent(Transform{});
            break :Blk entity.getComponent(Transform).?;
        };

        self.transform = transform;
    }

    pub fn Update(self: *Self, _: *fyr.Entity) !void {
        const transform = self.transform orelse return;

        const delta = fyr.vec3ToVec2(transform.position).subtract(fyr.camera.target);
        if (delta.length() < self.min_distance) return;

        const max_distance_position = fyr.vec3ToVec2(transform.position).add(
            delta
                .negate()
                .normalize()
                .multiply(fyr.Vec2(self.max_distance, self.max_distance)),
        );

        const movement = delta
            .normalize()
            .multiply(fyr.Vec2(self.follow_speed, self.follow_speed))
            .multiply(fyr.time.deltaTimeVector2());

        if (movement.length() > delta.length()) {
            fyr.camera.target = fyr.camera.target.add(delta);
            return;
        }

        if (delta.length() > self.max_distance) {
            fyr.camera.target = max_distance_position;
            return;
        }

        fyr.camera.target = fyr.camera.target.add(movement);
    }
};
