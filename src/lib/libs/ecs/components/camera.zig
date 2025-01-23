const std = @import("std");
const fyr = @import("../../../main.zig");
const rl = fyr.rl;

const Transform = @import("../components.zig").Transform;

const Cache = struct {
    transform: ?*Transform = null,
};

fn awake(store: *fyr.Store, cache_ptr: *anyopaque) !void {
    const cache = fyr.CacheCast(Cache, cache_ptr);

    const transform = store.getComponent(Transform) orelse Blk: {
        try store.addComonent(Transform{});
        break :Blk store.getComponent(Transform).?;
    };

    cache.transform = transform;
}

fn update(_: *fyr.Store, cache_ptr: *anyopaque) !void {
    const cache = fyr.CacheCast(Cache, cache_ptr);

    const transform = cache.transform orelse return;
    defer fyr.camera.target = fyr.Vec2(
        transform.position.x,
        transform.position.y,
    );
}

pub fn CameraTarget() !fyr.Behaviour {
    var b = try fyr.Behaviour.init(Cache);

    b.add(.awake, awake);
    b.add(.update, update);

    return b;
}
