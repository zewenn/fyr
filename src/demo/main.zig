const std = @import("std");
const loom = @import("loom");

pub fn main() !void {
    const TestComponent = struct {
        const Self = @This();

        speed: usize = 420,
        transform: ?*loom.Transform = null,

        pub fn Awake(entity: *loom.Entity) !void {
            std.log.debug("{s} Awake", .{entity.id});
        }

        pub fn Start(self: *Self, entity: *loom.Entity) !void {
            if (entity.getComponent(loom.Transform)) |transform| {
                self.transform = transform;
            }

            std.log.debug("{s} Start", .{entity.id});
        }

        pub fn Update(self: *Self) !void {
            const transform = self.transform orelse return error.MissingTransform;
            var move_vector = loom.vec2();

            if (loom.input.getKey(.w)) {
                move_vector.y -= 1;
            }
            if (loom.input.getKey(.s)) {
                move_vector.y += 1;
            }
            if (loom.input.getKey(.a)) {
                move_vector.x -= 1;
            }
            if (loom.input.getKey(.d)) {
                move_vector.x += 1;
            }

            transform.position = transform.position.add(
                loom.vec2ToVec3(
                    move_vector
                        .normalize()
                        .multiply(loom.Vec2(loom.time.deltaTime(), loom.time.deltaTime()))
                        .multiply(loom.Vec2(self.speed, self.speed)),
                ),
            );
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
