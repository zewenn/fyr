const fyr = @import("fyr");

const MovementBehaviour = @import("../behaviours.zig").MovementBehaviour;

pub fn Player() !*fyr.Entity {
    return try fyr.entity("Player", .{
        fyr.Transform{
            .position = .{
                .x = 0,
                .y = 0,
                .z = 0,
            },
        },
        try MovementBehaviour(),
        try fyr.Renderer(fyr.Display{
            .img = "logo_small.png",
        }),
        try fyr.ColliderBehaviour(fyr.Collider{
            .dynamic = true,
            .rect = fyr.Rect(
                0,
                0,
                64,
                64,
            ),
        }),
        try fyr.CameraTarget(),
        try fyr.AnimatorBehaviour(fyr.array(
            fyr.Animation,
            .{
                Blk: {
                    var anim = fyr.Animation.init(
                        "test",
                        2,
                        fyr.interpolation.lerp,
                    );
                    anim
                        .append(.{ .rotation = 0 })
                        .append(.{ .rotation = 2 })
                        .append(.{ .rotation = 0 })
                        .close();
                    break :Blk anim;
                },
            },
        )),
    });
}
