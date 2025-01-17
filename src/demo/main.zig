const std = @import("std");
const zap = @import("zap");

const behaviours = @import("behaviours.zig");

const MovementBehaviour = behaviours.MovementBehaviour;
const Player = @import("./prefabs/Player.zig").Player;
const Box = @import("./prefabs/Box.zig").Box;

pub fn main() !void {
    zap.useAssetDebugPath("./src/demo/assets/");

    try zap.init();
    defer zap.deinit();

    try zap.gui.loadStyle("style_cherry.rgs");

    const default = try zap.eventloop.new("default");
    try zap.useInstance("default");

    try default.addStore(try Player());
    try default.addStore(try Box());

    zap.loop();
}
