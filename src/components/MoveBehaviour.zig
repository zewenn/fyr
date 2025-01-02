const std = @import("std");
const zap = @import(".zap");

const Cache = struct {
    transform: ?*zap.Transform = null,
    speed: f32 = 10,
};

fn awake(store: *zap.Store, cache_ptr: *anyopaque) !void {
    const cache = zap.CacheCast(Cache, cache_ptr);

    const transform = store.getComponent(zap.Transform);
    cache.transform = transform;
}

fn update(_: *zap.Store, cache_ptr: *anyopaque) !void {
    const cache = zap.CacheCast(Cache, cache_ptr);
    const transform = cache.transform orelse return;

    var move_vec = zap.Vec3(0, 0, 0);

    if (zap.libs.raylib.isKeyDown(.key_w)) {
        move_vec.y -= 1;
    }
    if (zap.libs.raylib.isKeyDown(.key_s)) {
        move_vec.y += 1;
    }
    if (zap.libs.raylib.isKeyDown(.key_a)) {
        move_vec.x -= 1;
    }
    if (zap.libs.raylib.isKeyDown(.key_d)) {
        move_vec.x += 1;
    }

    move_vec = move_vec.normalize();

    transform.position = transform.position.add(
        move_vec.multiply(
            zap.Vec3(cache.speed, cache.speed, 0),
        ),
    );

    std.log.info("x: {d:.5} | y: {d:.5}", .{ transform.position.x, transform.position.y });
}

pub fn MovementBehaviour() !zap.Behaviour {
    var b = try zap.Behaviour.initWithDefaultValue(Cache{
        .speed = 0.2,
    });
    b.add(.awake, awake);
    b.add(.update, update);

    return b;
}
