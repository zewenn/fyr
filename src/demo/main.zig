const std = @import("std");
const loom = @import("loom");

pub fn main() !void {
    const TestComponent = struct {
        pub fn Awake(entity: *loom.Entity) !void {
            std.log.debug("{s} Awake", .{entity.id});
        }

        pub fn Start(entity: *loom.Entity) !void {
            std.log.debug("{s} Start", .{entity.id});
        }

        pub fn Update(entity: *loom.Entity) !void {
            std.log.debug("{s} Update", .{entity.id});
        }

        pub fn Tick(entity: *loom.Entity) !void {
            std.log.debug("{s} Tick", .{entity.id});
        }

        pub fn End(entity: *loom.Entity) !void {
            std.log.debug("{s} End", .{entity.id});
        }
    };

    const player = loom.Prefab.new("Player", .{
        TestComponent{},
    });

    try loom.project({})({
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
