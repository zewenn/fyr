const std = @import("std");
const fyr = @import("fyr");

const Player = @import("./prefabs/Player.zig").Player;
const Box = @import("./prefabs/Box.zig").Box;

const scripts = @import("scripts.zig");

pub fn main() !void {
    fyr.project({
        fyr.title("fyr-demo");
        fyr.winSize(fyr.Vec2(1280, 720));

        fyr.rl.setTargetFPS(256);
        fyr.rl.setConfigFlags(.{ .window_resizable = true });

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
