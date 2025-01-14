const zap = @import(".zap");

const MovementBehaviour = @import("../components/MoveBehaviour.zig").MovementBehaviour;

pub fn Player() !*zap.Store {
    return zap.newStore("Player", .{
        zap.Transform{
            .position = .{
                .x = 0,
                .y = 0,
                .z = 0,
            },
        },
        try MovementBehaviour(),
        try zap.Renderer(zap.Display{
            .img = "logo_small.png",
        }),
        try zap.ColliderBehaviour(zap.Collider{
            .dynamic = true,
            .rect = zap.Rect(
                0,
                0,
                64,
                64,
            ),
        }),
        try zap.CameraTarget(),
        try zap.AnimatorBehaviour(zap.array(
            zap.Animation,
            .{
                Blk: {
                    var anim = zap.Animation.init(
                        "test",
                        2,
                        zap.interpolation.lerp,
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
