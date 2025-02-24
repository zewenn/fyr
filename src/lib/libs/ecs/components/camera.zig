const std = @import("std");
const fyr = @import("../../../main.zig");
const rl = fyr.rl;

const Transform = @import("../components.zig").Transform;

pub const CameraTarget = struct {
    pub const FYR_BEHAVIOUR = {};
    const Self = @This();

    transform: ?*Transform = null,

    pub fn awake(cache: *Self, entity: *fyr.Entity) !void {
        const transform = entity.getComponent(Transform) orelse Blk: {
            try entity.addComonent(Transform{});
            break :Blk entity.getComponent(Transform).?;
        };

        cache.transform = transform;
    }

    pub fn update(cache: *Self, _: *fyr.Entity) !void {
        const transform = cache.transform orelse return;
        defer fyr.camera.target = fyr.Vec2(
            transform.position.x,
            transform.position.y,
        );
    }
};
