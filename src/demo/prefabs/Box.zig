const fyr = @import("fyr");

pub fn Box(can_collide: bool, position: fyr.Vector3) !*fyr.Entity {
    return try fyr.entity("Box", .{
        fyr.Transform{
            .position = position,
            .scale = fyr.Vec2(256, 64),
        },
        fyr.Renderer.init(
            fyr.Display{
                .img = "small.png",
            },
        ),
        fyr.RectCollider.init(.{
            .dynamic = can_collide,
            .rect = fyr.Rect(
                0,
                0,
                256,
                64,
            ),
            .weight = 2,
        }),
    });
}
