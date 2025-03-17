const std = @import("std");
const fyr = @import("fyr");

const Player = @import("./prefabs/Player.zig").Player;
const Box = @import("./prefabs/Box.zig").Box;

const scripts = @import("scripts.zig");
const window = fyr.window;

pub fn main() !void {
    fyr.project({
        window.title("fyr-demo");
        window.size.set(fyr.Vec2(1280, 720));
        window.fps.setTarget(256);
        window.resizing.enable();

        fyr.useAssetPaths(.{
            .debug = "./src/demo/assets/",
        });
    })({
        fyr.scene("default")({
            fyr.entities(.{
                try Player(),
                try Box(),
            });

            fyr.scripts(.{
                scripts.DemoUI{},
            });
        });
    });
}
