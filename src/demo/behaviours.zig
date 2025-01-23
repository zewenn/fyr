const std = @import("std");
const fyr = @import("fyr");

pub const MovementBehaviour = struct {
    const Cache = struct {
        transform: ?*fyr.Transform = null,
        speed: f32 = 10,
    };

    fn awake(store: *fyr.Store, cache_ptr: *anyopaque) !void {
        const cache = fyr.CacheCast(Cache, cache_ptr);

        const transform = store.getComponent(fyr.Transform);
        cache.transform = transform;
    }

    fn update(store: *fyr.Store, cache_ptr: *anyopaque) !void {
        const cache = fyr.CacheCast(Cache, cache_ptr);
        const transform = cache.transform orelse return;

        var move_vec = fyr.Vec3(0, 0, 0);

        if (fyr.rl.isKeyDown(.w)) {
            move_vec.y -= 1;
        }
        if (fyr.rl.isKeyDown(.s)) {
            move_vec.y += 1;
        }
        if (fyr.rl.isKeyDown(.a)) {
            move_vec.x -= 1;
        }
        if (fyr.rl.isKeyDown(.d)) {
            move_vec.x += 1;
        }

        move_vec = move_vec.normalize();

        transform.position = transform.position.add(
            move_vec.multiply(
                fyr.Vec3(cache.speed, cache.speed, 0),
            ).multiply(
                fyr.Vec3(
                    fyr.time.deltaTime(),
                    fyr.time.deltaTime(),
                    0,
                ),
            ),
        );

        if (move_vec.length() < 0.5) return;
        const animator = store.getComponent(fyr.Animator) orelse return;

        try animator.play("test");
    }

    pub fn behaviour() !fyr.Behaviour {
        var b = try fyr.Behaviour.initWithDefaultValue(Cache{
            .speed = 300,
        });
        b.add(.awake, awake);
        b.add(.update, update);

        return b;
    }
}.behaviour;
