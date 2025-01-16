const std = @import("std");
const zap = @import(".zap");

const Player = @import("../../prefabs/Player.zig").Player;
const Box = @import("../../prefabs/Box.zig").Box;
var audio: ?*zap.rl.Sound = null;

pub fn awake() !void {
    const activeInstance = zap.activeInstance();
    try activeInstance.addStore(try Player());
    try activeInstance.addStore(try Box());

    audio = try zap.libs.assets.get.audio("main_menu.mp3");

    if (audio) |a| {
        std.log.debug("asd", .{});
        zap.rl.setSoundVolume(a.*, 0.1);
        zap.rl.playSound(a.*);
    }
}
