const std = @import("std");
const rl = @import("raylib");

const ecs = struct {
    pub const Behaviour = @import("./ecs/Behaviour.zig");
    pub const Entity = @import("./ecs/Entity.zig");
    pub const Prefab = @import("./ecs/Prefab.zig");
};

const TestBehaviour = struct {
    pub fn Awake(entity: *ecs.Entity, self: *TestBehaviour) !void {
        std.log.debug("awake: {s}@{s}", .{ entity.id, @typeName(@TypeOf(self)) });
    }
};

const player = ecs.Prefab.new("player", .{
    TestBehaviour{},
});

pub fn hello() !void {
    std.log.debug("hello world!", .{});

    const p = try player.makeInstance(std.heap.smp_allocator);
    defer p.destroy();

    p.dispatchEvent(.awake);
    p.dispatchEvent(.start);
    p.dispatchEvent(.update);
    p.dispatchEvent(.tick);
    p.dispatchEvent(.end);
}
