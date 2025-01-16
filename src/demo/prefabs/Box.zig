const zap = @import("zap");

pub fn Box() !*zap.Store {
    return zap.newStore("Box", .{
        zap.Transform{
            .position = zap.Vec3(128, 128, 0),
            .scale = zap.Vec2(256, 64),
        },
        try zap.Renderer(zap.Display{
            .img = "small.png",
        }),
        try zap.ColliderBehaviour(zap.Collider{
            .dynamic = false,
            .rect = zap.Rect(
                0,
                0,
                256,
                64,
            ),
        }),
    });
}
