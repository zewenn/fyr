const std = @import("std");
const fyr = @import("fyr");

pub const MovementBehaviour = fyr.Behaviour.make(struct {
    const Self = @This();

    transform: ?*fyr.Transform = null,
    speed: f32 = 350,

    pub fn awake(Entity: *fyr.Entity, cache: *Self) !void {
        const transform = Entity.getComponent(fyr.Transform);
        cache.transform = transform;
    }

    pub fn update(Entity: *fyr.Entity, cache: *Self) !void {
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
        const animator = Entity.getComponent(fyr.Animator) orelse return;

        try animator.play("test");
    }
});
