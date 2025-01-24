const fyr = @import("fyr");

pub fn Box() !*fyr.Entity {
    return try fyr.entity("Box", .{
        fyr.Transform{
            .position = fyr.Vec3(128, 128, 0),
            .scale = fyr.Vec2(256, 64),
        },
        try fyr.Renderer(fyr.Display{
            .img = "small.png",
        }),
        try fyr.ColliderBehaviour(fyr.Collider{
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
