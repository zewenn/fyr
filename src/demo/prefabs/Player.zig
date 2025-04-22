const std = @import("std");
const fyr = @import("fyr");

const MovementBehaviour = @import("../behaviours.zig").MovementBehaviour;
const Box = @import("./Box.zig").Box;

pub fn Player() !*fyr.Entity {
    return try fyr.entity("Player", .{
        fyr.Transform{
            .position = .{
                .x = -64,
                .y = -64,
                .z = 0,
            },
            .scale = .{
                .x = 64,
                .y = 32,
            }
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

        fyr.RectCollider.init(.{
            .dynamic = true,
            .weight = 1,
            .rect = fyr.Rect(
                0,
                0,
                64,
                64,
            ),
        }),

        fyr.RectCollider.init(.{
            .trigger = true,
            .rect = fyr.Rect(
                // -64,
                // -64,
                0,
                0,
                64 * 3,
                64 * 3,
            ),
        }),

        fyr.Children.init(
            .create(.{
                try Box("player", false, fyr.Vec3(0, 100, 20)),
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
