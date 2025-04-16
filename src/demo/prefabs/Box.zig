const fyr = @import("fyr");

pub fn Box(
    comptime id: []const u8,
    can_collide: bool,
    position: fyr.Vector3,
) !*fyr.Entity {
    return try fyr.entity("box-" ++ id, .{
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
