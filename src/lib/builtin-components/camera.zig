const std = @import("std");
const loom = @import("../root.zig");
const rl = loom.rl;

const Transform = @import("./Transform.zig");

pub const CameraTarget = struct {
    pub const FYR_BEHAVIOUR = {};
    const Self = @This();

    transform: ?*Transform = null,
    max_distance: f32 = 0,
    min_distance: f32 = 0,
    follow_speed: f32 = 1,

    pub fn Awake(self: *Self, entity: *loom.Entity) !void {
        const transform = entity.getComponent(Transform) orelse Blk: {
            try entity.addComponent(Transform{});
            break :Blk entity.getComponent(Transform).?;
        };

        self.transform = transform;
    }

    pub fn Update(self: *Self, _: *loom.Entity) !void {
        const transform = self.transform orelse return;

        const delta = loom.vec3ToVec2(transform.position).subtract(loom.camera.target);
        if (delta.length() < self.min_distance) return;

        const max_distance_position = loom.vec3ToVec2(transform.position).add(
            delta
                .negate()
                .normalize()
                .multiply(loom.Vec2(self.max_distance, self.max_distance)),
        );

        const movement = delta
            .normalize()
            .multiply(loom.Vec2(self.follow_speed, self.follow_speed))
            .multiply(loom.time.deltaTimeVector2());

        if (movement.length() > delta.length()) {
            loom.camera.target = loom.camera.target.add(delta);
            return;
        }

        if (delta.length() > self.max_distance) {
            loom.camera.target = max_distance_position;
            return;
        }

        loom.camera.target = loom.camera.target.add(movement);
    }
};
