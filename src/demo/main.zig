const std = @import("std");
const loom = @import("loom");

pub fn main() !void {
    const TestComponent = struct {
        const Self = @This();

        speed: usize = 430,
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

            const clay = loom.clay;

            clay.UI()(.{
                .id = .ID("test"),

                .layout = .{
                    .sizing = .{
                        .w = .fixed(300),
                        .h = .percent(100),
                    },
                    .padding = .all(10),
                    .child_gap = 10,
                    .direction = .top_to_bottom,
                },
                .background_color = .{ 250, 250, 255, 255 },
            })({
                clay.UI()(.{
                    .id = .ID("test"),
                    .layout = .{
                        .sizing = .{
                            .w = .grow,
                            .h = .fixed(300),
                        },
                    },
                    .background_color = loom.ui.color(20, 120, 220, 255),
                })({
                    clay.text("Clay - UI Library", .{
                        .font_size = 12,
                        .letter_spacing = 1,
                        .color = .{ 0, 0, 0, 255 },
                        .font_id = loom.ui.fontID("press_play.ttf"),
                    });
                });
                clay.UI()(.{
                    .id = .ID("test"),
                    .layout = .{
                        .sizing = .{
                            .w = .grow,
                            .h = .fixed(100),
                        },
                    },
                })({
                    clay.text("Clay - UI Library", .{
                        .font_size = 12,
                        .letter_spacing = 1,
                        .color = .{ 0, 0, 0, 255 },
                        .font_id = loom.ui.fontID("press_play.ttf"),
                    });
                });
            });
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
            .position = loom.Vec3(0, 0, 0),
            .scale = loom.Vec2(88, 32),
        },
        loom.RectCollider.init(.{
            .rect = loom.Rect(0, 0, 88, 32),
            .dynamic = true,
            .weight = 1,
        }),
        // loom.CameraTarget{},
    });

    const box = loom.Prefab.new("Box", .{
        loom.Renderer{
            .img_path = "logo_large.png",
        },
        loom.Transform{
            .position = loom.Vec3(100, 0, 0),
            .scale = loom.Vec2(88, 32),
        },
        loom.RectCollider.init(.{
            .rect = loom.Rect(0, 0, 88, 32),
            .dynamic = true,
            .weight = 2,
        }),
    });

    loom.project({
        loom.window.resizing.enable();
        loom.window.size.set(loom.Vec2(1440, 720));
        loom.window.fps.setTarget(180);

        loom.useAssetPaths(.{
            .debug = "./src/demo/assets/",
        });
    })({
        loom.scene("default")({
            loom.prefabs(.{
                player,
                box,
            });
        });

        loom.scene("other")({
            loom.prefabs(.{
                player,
            });
        });
    });
}
