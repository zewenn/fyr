const std = @import("std");
const zap = @import(".zap");

const MovementBehaviour = @import("./components/MoveBehaviour.zig").MovementBehaviour;
const Player = @import("./prefabs/Player.zig").Player;
const Box = @import("./prefabs/Box.zig").Box;

pub fn main() !void {
    try zap.init();
    defer zap.deinit();

    try @import(".codegen/instances.zig").register();

    zap.loop();
}
