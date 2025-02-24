const fyr = @import("fyr");

pub fn Box() !*fyr.Entity {
    return try fyr.entity("Box", .{
        fyr.Transform{
            .position = fyr.Vec3(128, 128, 0),
            .scale = fyr.Vec2(256, 64),
        },
        fyr.Renderer.new(
            fyr.Display{
                .img = "small.png",
            },
        ),
        fyr.ColliderBehaviour.new(.{
            .dynamic = false,
            .rect = fyr.Rect(
                0,
                0,
                256,
                64,
            ),
        }),
    });
}
