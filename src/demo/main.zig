const std = @import("std");
const fyr = @import("fyr");

const behaviours = @import("behaviours.zig");

const MovementBehaviour = behaviours.MovementBehaviour;
const Player = @import("./prefabs/Player.zig").Player;
const Box = @import("./prefabs/Box.zig").Box;

const gui = fyr.gui;
const Element = gui.Element;
const ID = gui.ID;

pub fn main() !void {
    fyr.useAssetDebugPath("./src/demo/assets/");

    try fyr.init();
    defer fyr.deinit();

    fyr.scene("default")({
        fyr.entities(.{
            try Player(),
            try Box(),
        });
    });

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

    fyr.loop();
}
