const std = @import("std");
const zap = @import("../../../main.zig");
const rl = zap.rl;

const Transform = @import("../components.zig").Transform;

const Cache = struct {
    transform: ?*Transform = null,
};

fn awake(store: *zap.Store, cache_ptr: *anyopaque) !void {
    const cache = zap.CacheCast(Cache, cache_ptr);

    const transform = store.getComponent(Transform) orelse Blk: {
        try store.addComonent(Transform{});
        break :Blk store.getComponent(Transform).?;
    };

    cache.transform = transform;
}

fn update(_: *zap.Store, cache_ptr: *anyopaque) !void {
    const cache = zap.CacheCast(Cache, cache_ptr);

    const transform = cache.transform orelse return;
    defer zap.camera.target = zap.Vec2(
        transform.position.x,
        transform.position.y,
    );
}

pub fn CameraTarget() !zap.Behaviour {
    var b = try zap.Behaviour.init(Cache);

    b.add(.awake, awake);
    b.add(.update, update);

    return b;
}
