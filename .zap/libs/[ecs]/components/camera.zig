const std = @import("std");
const zap = @import("../../../main.zig");
const rl = zap.rl;

const Transform = @import("../components.zig").Transform;

const Cache = struct {
    transform: ?*Transform = null,
    last_transform: ?Transform = null,
    offset: zap.Vector2 = zap.Vec2(0, 0),
};

fn awake(store: *zap.Store, cache_ptr: *anyopaque) !void {
    const cache = zap.CacheCast(Cache, cache_ptr);

    const transform = store.getComponent(Transform) orelse Blk: {
        try store.addComonent(Transform{});
        break :Blk store.getComponent(Transform).?;
    };

    cache.transform = transform;
    cache.last_transform = transform.*;
    cache.offset = transform.scale.divide(zap.Vec2(2, 2));
}

fn update(_: *zap.Store, cache_ptr: *anyopaque) !void {
    const cache = zap.CacheCast(Cache, cache_ptr);

    const transform = cache.transform orelse return;
    defer zap.camera.target = cache.offset.add(zap.Vec2(
        transform.position.x,
        transform.position.y,
    ));

    const last_transform = cache.last_transform orelse return;
    if (last_transform.eqlSkipPosition(transform.*)) return;

    cache.offset = transform.scale.divide(zap.Vec2(2, 2));
}

pub fn CameraTarget() !zap.Behaviour {
    var b = try zap.Behaviour.init(Cache);

    b.add(.awake, awake);
    b.add(.update, update);

    return b;
}
