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
                try Box("1", true, fyr.Vec3(0, 64, 0)),
                try Box("2", false, fyr.Vec3(128, 0, 0)),
            });

            fyr.scripts(.{
                scripts.DemoUI{},
            });
        });
        fyr.log(.debug, "default scene created", .{});
    });
}
