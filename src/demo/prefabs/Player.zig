const fyr = @import("fyr");

const MovementBehaviour = @import("../behaviours.zig").MovementBehaviour;
const Box = @import("./Box.zig").Box;

pub fn Player() !*fyr.Entity {
    return try fyr.entity("Player", .{
        fyr.Transform{
            .position = .{
                .x = 0,
                .y = 0,
                .z = 0,
            },
        },

        MovementBehaviour.init(400),

        fyr.CameraTarget{
            .max_distance = 400,
            .min_distance = 50,
            .follow_speed = 360,
        },

        fyr.Renderer.init(.{
            .img = "logo_small.png",
        }),

        fyr.ColliderBehaviour.init(.{
            .dynamic = true,
            .rect = fyr.Rect(
                0,
                0,
                64,
                64,
            ),
        }),

        fyr.Children.init(
            .create(.{
                try Box(),
            }),
        ),

        fyr.AnimatorBehaviour.init(.create(
            .{
                try fyr.Animation.create(
                    "test",
                    1,
                    fyr.interpolation.lerp,
                    .{
                        fyr.KeyFrame{ .rotation = 0 },
                        fyr.KeyFrame{ .rotation = 10 },
                        fyr.KeyFrame{ .rotation = 0 },
                    },
                ),
            },
        )),
    });
}
