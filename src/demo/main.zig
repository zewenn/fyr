const std = @import("std");
const loom = @import("loom");

pub fn main() !void {
    const TestComponent = struct {
        const Self = @This();

        myvar: usize = 42,

        pub fn Awake(entity: *loom.Entity) !void {
            std.log.debug("{s} Awake", .{entity.id});
        }

        pub fn Start(entity: *loom.Entity) !void {
            std.log.debug("{s} Start", .{entity.id});
        }

        pub fn Update() !void {
            if (loom.rl.isKeyPressed(.a))
                try loom.eventloop.setActive("other");
        }

        pub fn End(entity: *loom.Entity) !void {
            std.log.debug("{s} End", .{entity.id});
        }
    };

    const player = loom.Prefab.new("Player", .{
        TestComponent{},
        loom.Renderer{
            .img_path = "logo_large.png",
        },
        loom.Transform{
            .position = loom.Vec3(720, 360, 0),
            .scale = loom.Vec2(128, 64),
        },
    });

    try loom.project({
        loom.window.resizing.enable();
        loom.window.size.set(loom.Vec2(1440, 720));

        loom.useAssetPaths(.{
            .debug = "./src/demo/assets/",
        });
    })({
        loom.scene("default")({
            loom.prefabs(.{
                player,
            });
        });

        loom.scene("other")({
            loom.prefabs(.{
                player,
            });
        });
    });
}
