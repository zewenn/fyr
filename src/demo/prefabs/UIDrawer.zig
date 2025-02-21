const fyr = @import("fyr");

const ui = fyr.gui;

pub fn UIDrawer() !*fyr.Entity {
    return try fyr.entity("uidrawer", .{
        try UIDrawBehaviour(),
    });
}

const UIDrawBehaviour = fyr.Behaviour.impl(struct {
    const Self = @This();

    // font: ?fyr.rl.Font = null,

    // pub fn awake(_: *fyr.Entity, self: *Self) !void {
    //     self.font = try fyr.assets.get.font("press_play.ttf");
    // }

    pub fn update(_: *fyr.Entity, _: *Self) !void {
        ui.element({
            ui.elementType(.body);
            ui.id("body");

            ui.style(.{
                .width = .{ .vw = 100 },
                .height = .{ .vh = 100 },
            });
        })({
            // ui.element({
            //     ui.id("heading1");
            //     ui.style(.{
            //         .background = .{
            //             .color = fyr.rl.Color.red,
            //         },
            //         .font = .{
            //             .family = self.font,
            //             .size = 12,
            //         },
            //         // .width = .{ .px = 400 },
            //         .height = .fit,
            //     });
            //     ui.elementType(.h1);
            // })({
            //     ui.text("This is the greatest ui ever!", .{});
            // });

            ui.element({
                ui.id("testelem");
                ui.elementType(.div);

                ui.style(.{
                    .background = .{ .color = fyr.rl.Color.blue },
                    .flow = .horizontal,
                    // .height = .{ .px = 300 },
                    .height = .{ .px = 50 },
                    // .width = .fit,
                    .width = .{ .px = 600 },

                    .left = .{ .px = 50 },
                    .top = .{ .px = 40 },
                });
            })({
                ui.element({
                    ui.id("p1");
                    ui.elementType(.p);

                    ui.style(.{
                        .background = .{
                            .color = fyr.rl.Color.lime,
                        },
                        .width = .{ .px = 100 },
                        .left = .{ .px = 5 },
                        .font = .{
                            .family = "press_play.ttf",
                        },
                    });
                })({
                    ui.text("Text1", .{});
                });

                ui.element({
                    ui.id("p2");
                    ui.elementType(.p);

                    ui.style(.{
                        .background = .{
                            .color = fyr.rl.Color.red,
                        },

                        // .height = .fill,
                        // .height = .fill,

                        .width = .fill,
                        .left = .{ .vw = 15 },
                        // .top = .{ .px = 10 },
                    });
                })({
                    ui.text("Text2", .{});
                });

                ui.element({
                    ui.id("p3");
                    ui.elementType(.p);

                    ui.style(.{
                        .background = .{
                            .color = fyr.rl.Color.pink,
                        },

                        // .width = .{ .vw = 20 },
                        // .left = .{ .vw = 0 },
                        // .top = .{ .px = 5 },
                    });
                })({
                    ui.text("Text3", .{});
                });
            });

            ui.element({
                ui.style(.{
                    .top = .{ .px = 340 },
                    .left = .{ .px = 50 },
                    .height = .{ .px = 20 },
                    .width = .{ .px = 20 },
                    .background = .{ .color = fyr.rl.Color.white },
                });
            })({});
        });
    }
});
