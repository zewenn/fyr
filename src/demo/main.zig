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

    const default = try fyr.eventloop.new("default");
    try fyr.useInstance("default");

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

    fyr.loop();
}
