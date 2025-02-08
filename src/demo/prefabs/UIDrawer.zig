const fyr = @import("fyr");

const ui = fyr.gui;

pub fn UIDrawer() !*fyr.Entity {
    return try fyr.entity("Player", .{
        try UIDrawBehaviour(),
    });
}

const UIDrawBehaviour = fyr.Behaviour.factory(struct {
    const Self = @This();

    pub fn update(_: *fyr.Entity, _: *Self) !void {
        ui.element({
            ui.elementType(.body);
            ui.id("body");

            ui.style(.{
                .width = .{ .vw = 10 },
                .height = .{ .vh = 10 },
            });
        })({
            ui.element({
                ui.id("heading1");
                ui.elementType(.h1);

                ui.style(.{
                    .font = .{
                        .size = 0.1,
                    },
                    .width = .{ .px = 400 },
                    .height = .{ .px = 10 },
                });
            })({
                try ui.text("This is the greatest ui ever!", .{});
            });
        });
    }
});
