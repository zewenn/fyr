const fyr = @import("fyr");

const ui = fyr.gui;

pub fn UIDrawer() !*fyr.Entity {
    return try fyr.entity("Player", .{
        try UIDrawBehaviour(),
    });
}

const UIDrawBehaviour = fyr.Behaviour.factory(struct {
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
                    .width = .fit,
                });
            })({
                ui.element({
                    ui.id("p1");
                    ui.elementType(.p);

                    ui.style(.{
                        .background = .{
                            .color = fyr.rl.Color.lime,
                        },
                        .width = .{ .vw = 25 },
                        .font = .{
                            // .family = self.font,
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
                            .color = fyr.rl.Color.pink,
                        },
                        .width = .{ .vw = 20 },
                    });
                })({
                    ui.text("Text2", .{});
                });
            });
        });
    }
});
