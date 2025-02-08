const fyr = @import("fyr");

const ui = fyr.gui;

pub fn UIDrawer() !*fyr.Entity {
    return try fyr.entity("Player", .{});
}

const UIDrawBehaviour = fyr.Behaviour.factory(struct {
    const Self = @This();

    pub fn update(_: *fyr.Entity, _: *Self) !void {
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
                ui.elementType(.h1);
            })({
                ui.text("This is the greatest ui ever!", .{});
            });
        });
    }
});
