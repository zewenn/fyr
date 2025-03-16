const std = @import("std");
const fyr = @import("fyr");

pub const MovementBehaviour = struct {
    pub const FYR_BEHAVIOUR = {};

    const Self = @This();

    transform: ?*fyr.Transform = null,
    speed: f32 = 350,

    pub fn init(speed: f32) Self {
        return Self{
            .speed = speed,
        };
    }

    pub fn Awake(cache: *Self, entity: *fyr.Entity) !void {
        const transform = entity.getComponent(fyr.Transform);
        cache.transform = transform;
    }

    pub fn Update(cache: *Self, entity: *fyr.Entity) !void {
        const transform = cache.transform orelse return;

        var move_vec = fyr.Vec3(0, 0, 0);

        if (fyr.input.getKey(.w)) {
            move_vec.y -= 1;
        }
        if (fyr.input.getKey(.s)) {
            move_vec.y += 1;
        }
        if (fyr.input.getKey(.a)) {
            move_vec.x -= 1;
        }
        if (fyr.input.getKey(.d)) {
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
        const animator = entity.getComponent(fyr.Animator) orelse return;

        try animator.play("test");
    }
};
