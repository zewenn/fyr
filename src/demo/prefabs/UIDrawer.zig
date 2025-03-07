const fyr = @import("fyr");

const ui = fyr.gui;

pub fn UIDrawer() !*fyr.Entity {
    return try fyr.entity("uidrawer", .{
        UIDrawBehaviour{},
    });
}

const UIDrawBehaviour = struct {
    pub const FYR_BEHAVIOUR = {};
    const Self = @This();

    pub fn Update(_: *Self, _: *fyr.Entity) !void {}
};
