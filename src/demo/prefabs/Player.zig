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

        MovementBehaviour.new(400),

        try fyr.Renderer(fyr.Display{
            .img = "logo_small.png",
        }),
        try fyr.ColliderBehaviour(.{
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
                try fyr.Animation.create("test", 2, fyr.interpolation.lerp, .{
                    fyr.KeyFrame{ .rotation = 0 },
                    fyr.KeyFrame{ .rotation = 10 },
                    fyr.KeyFrame{ .rotation = 0 },
                }),
            },
        )),
    });
}
