const std = @import("std");
const fyr = @import("../../../main.zig");

pub const EntityRef = struct {
    const Self = @This();

    uuid: u128,
    ptr: ?*fyr.Entity = null,

    pub fn new(uuid: u128) Self {
        return .{ .uuid = uuid, .ptr = Blk: {
            const scene = fyr.activeScene() catch break :Blk null;
            break :Blk scene.getEntityByUuid(uuid);
        } };
    }

    pub fn init(uuid: u128, ptr: *fyr.Entity) Self {
        return .{
            .uuid = uuid,
            .ptr = ptr,
        };
    }
};

pub const Child = struct {
    pub const FYR_BEHAVIOUR = {};
    const Self = @This();

    parent: EntityRef,

    pub fn init(ptr: *fyr.Entity) Self {
        return .{
            .parent = .init(ptr.uuid, ptr),
        };
    }
};

pub const Children = struct {
    pub const FYR_BEHAVIOUR = {};
    const Self = @This();

    list: ?std.ArrayList(EntityRef) = null,

    fn getMakeList(self: *Self) *std.ArrayList(EntityRef) {
        return &(self.list orelse Blk: {
            self.list = .init(fyr.allocators.generic());
            break :Blk self.list.?;
        });
    }

    pub fn init(base: fyr.Array(*fyr.Entity)) Self {
        defer base.deinit();

        var this = Self{};
        var child_list = this.getMakeList();

        for (base.items) |ptr| {
            child_list.append(EntityRef.init(ptr.uuid, ptr)) catch continue;
        }

        return this;
    }

    pub fn Start(self: *Self, entity: *fyr.Entity) !void {
        const list = self.getMakeList();

        for (list.items) |*item| {
            const ptr = item.ptr orelse continue;
            try ptr.addComonent(Child.init(entity));
            std.log.debug("asd: {any}", .{ptr.getComponent(Child) != null});
            fyr.entities(.{ptr});
        }
    }

    pub fn End(self: *Self, _: *fyr.Entity) !void {
        const list = self.getMakeList();
        defer {
            list.deinit();
            self.list = null;
        }

        const scene = fyr.activeScene() catch return;
        for (list.items) |item| {
            scene.removeEntityByUuid(item.uuid);
        }
    }
};
