const std = @import("std");
const zap = @import("zap");

const behaviours = @import("behaviours.zig");

const MovementBehaviour = behaviours.MovementBehaviour;
const Player = @import("./prefabs/Player.zig").Player;
const Box = @import("./prefabs/Box.zig").Box;

const gui = zap.gui;
const Element = gui.Element;
const ID = gui.ID;

pub fn main() !void {
    zap.useAssetDebugPath("./src/demo/assets/");

    try zap.init();
    defer zap.deinit();

    const default = try zap.eventloop.new("default");
    try zap.useInstance("default");

    gui.clear();
    defer gui.clear();

    Element({
        ID("test_1");
    })({
        Element({
            ID("test_1_1");
        })({
            Element({
                ID("test_1_1");
            })({});
        });

        Element({
            ID("test_1_2");
        })({});
    });

    try default.addStore(try Player());
    try default.addStore(try Box());

    zap.loop();
}
