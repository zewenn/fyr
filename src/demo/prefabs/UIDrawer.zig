const fyr = @import("fyr");

const ui = fyr.gui;

pub fn UIDrawer() !*fyr.Entity {
    return try fyr.entity("Player", .{
        try UIDrawBehaviour(),
    });
}

const UIDrawBehaviour = fyr.Behaviour.factory(struct {
    const Self = @This();

    font: ?fyr.rl.Font = null,

    pub fn awake(_: *fyr.Entity, self: *Self) !void {
        self.font = try fyr.assets.get.font("press_play.ttf");
    }

    pub fn update(_: *fyr.Entity, self: *Self) !void {
        ui.element({
            ui.elementType(.body);
            ui.id("body");

            ui.style(.{
                .width = .{ .vw = 100 },
                .height = .{ .vh = 100 },
            });
        })({
            ui.element({
                ui.id("heading1");
                ui.style(.{
                    .background = .{
                        .color = fyr.rl.Color.red,
                    },
                    .font = .{
                        .family = self.font,
                        .size = 12,
                    },
                    // .width = .{ .px = 400 },
                    // .height = .{ .px = 10 },
                });
                ui.elementType(.h1);
            })({
                try ui.text("This is the greatest ui ever!", .{});
            });
        });
    }
});
