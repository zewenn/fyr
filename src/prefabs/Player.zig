const zap = @import(".zap");

const MovementBehaviour = @import("../components/MoveBehaviour.zig").MovementBehaviour;

pub fn Player() !*zap.Store {
    return zap.newStore("Player", .{
        zap.Transform{},
        try MovementBehaviour(),
    });
}
