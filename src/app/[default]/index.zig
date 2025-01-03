const zap = @import(".zap");

const Player = @import("../../prefabs/Player.zig").Player;
const Box = @import("../../prefabs/Box.zig").Box;

pub fn awake() !void {
    const activeInstance = zap.activeInstance();
    try activeInstance.addStore(try Player());
    try activeInstance.addStore(try Box());
}
