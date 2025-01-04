const zap = @import(".zap");

const MovementBehaviour = @import("../components/MoveBehaviour.zig").MovementBehaviour;

pub fn Player() !*zap.Store {
    return zap.newStore("Player", .{
        zap.Transform{},
        try MovementBehaviour(),
        try zap.Renderer(zap.Display{
            .img = "small.png",
        }),
        try zap.ColliderBehaviour(zap.Collider{
            .dynamic = true,
            .rect = zap.Rect(0, 0, 64, 64),
        }),
        try zap.CameraTarget(),
    });
}
