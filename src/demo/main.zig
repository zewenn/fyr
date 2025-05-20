const std = @import("std");
const loom = @import("loom");

const ui = loom.ui;

pub fn main() !void {
    const TestComponent = struct {
        const Self = @This();

        speed: usize = 430,
        transform: ?*loom.Transform = null,
        animator: ?*loom.Animator = null,

        borderless: bool = false,

        pub fn Awake(entity: *loom.Entity) !void {
            std.log.debug("{s} Awake", .{entity.id});
        }

        pub fn Start(self: *Self, entity: *loom.Entity) !void {
            if (entity.getComponent(loom.Transform)) |transform| {
                self.transform = transform;
            }

            if (entity.getComponent(loom.Animator)) |animator| {
                self.animator = animator;
            }

            std.log.debug("{s} Start", .{entity.id});
        }

        pub fn Update(self: *Self) !void {
            const transform = self.transform orelse return error.MissingTransform;
            const animator = self.animator orelse return error.MissingTransform;
            var move_vector = loom.vec2();

            if (loom.input.getKeyDown(.f))
                try animator.play("walk-left");

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

            if (loom.input.getKeyDown(.e)) {
                try animator.play("test");
            }

            if (loom.input.getKey(.left_alt)) {
                if (loom.input.getKeyDown(.h)) {
                    loom.window.borderless.toggle();
                }
                if (loom.input.getKeyDown(.j)) {
                    loom.window.fullscreen.toggle();
                }
                if (loom.input.getKeyDown(.k)) {
                    loom.window.resizing.toggle();
                }
            }

            transform.position = transform.position.add(
                loom.vec2ToVec3(
                    move_vector
                        .normalize()
                        .multiply(loom.Vec2(loom.time.deltaTime(), loom.time.deltaTime()))
                        .multiply(loom.Vec2(self.speed, self.speed)),
                ),
            );

            ui.new(.{
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
                ui.new(.{
                    .id = .ID("test"),
                    .layout = .{
                        .sizing = .{
                            .w = .grow,
                            .h = .fixed(300),
                        },
                    },
                    .background_color = loom.ui.color(20, 120, 220, 255),
                })({
                    ui.text("Clay - UI Library", .{
                        .font_size = 12,
                        .letter_spacing = 1,
                        .color = .{ 0, 0, 0, 255 },
                        .font_id = loom.ui.fontID("press_play.ttf"),
                    });
                });
                ui.new(.{
                    .id = .ID("test"),
                    .layout = .{
                        .sizing = .{
                            .w = .grow,
                            .h = .fixed(100),
                        },
                    },
                })({
                    ui.text("Clay - UI Library", .{
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

        loom.Animator.init(&.{
            .init("walk-left", 3, loom.interpolation.lerp, &.{
                loom.Keyframe{
                    .rotation = 0,
                    .sprite = "img2.png",
                },
                loom.Keyframe{
                    .rotation = -15,
                    .sprite = "img3.png",
                },
                loom.Keyframe{
                    .rotation = 0,
                    .sprite = "img2.png",
                },
            }),
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
        loom.window.fpsTarget.set(180);

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
