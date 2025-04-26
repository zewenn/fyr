const std = @import("std");
const builtin = @import("builtin");
const Allocator = @import("std").mem.Allocator;

pub const rl = @import("raylib");
pub const uuid = @import("uuid");

pub const ecs = struct {
    pub const Behaviour = @import("./ecs/Behaviour.zig");
    pub const Entity = @import("./ecs/Entity.zig");
    pub const Prefab = @import("./ecs/Prefab.zig");
};

test ecs {
    const TestComponent = struct {
        pub var counter: usize = 0;

        pub fn Awake(entity: *ecs.Entity) !void {
            counter += 1;
            std.log.debug("{s} Awake", .{entity.id});
        }

        pub fn Start(entity: *ecs.Entity) !void {
            counter += 1;
            std.log.debug("{s} Start", .{entity.id});
        }

        pub fn Update(entity: *ecs.Entity) !void {
            counter += 1;
            std.log.debug("{s} Update", .{entity.id});
        }

        pub fn Tick(entity: *ecs.Entity) !void {
            counter += 1;
            std.log.debug("{s} Tick", .{entity.id});
        }

        pub fn End(entity: *ecs.Entity) !void {
            counter += 1;
            std.log.debug("{s} End", .{entity.id});
        }
    };

    const Player = ecs.Prefab.new("Player", .{
        TestComponent{},
    });

    var player = try Player.makeInstance(std.testing.allocator);
    defer player.destroy();

    player.dispatchEvent(.awake);
    player.dispatchEvent(.start);
    player.dispatchEvent(.update);
    player.dispatchEvent(.tick);
    player.dispatchEvent(.end);

    try std.testing.expect(TestComponent.counter == 5);
}

pub const eventloop = struct {
    pub const Scene = @import("./eventloop/Scene.zig");
};

pub const allocators = struct {
    fn AllocatorInstance(comptime T: type) type {
        return struct {
            interface: ?T = null,
            allocator: ?Allocator = null,
        };
    }

    pub var AI_generic: AllocatorInstance(std.heap.DebugAllocator(.{})) = .{};
    pub var AI_arena: AllocatorInstance(std.heap.ArenaAllocator) = .{};

    /// Generic allocator, warns at program exit if a memory leak happened.
    /// In the Debug and ReleaseFast modes this is a `DebugAllocator`,
    /// otherwise it is equivalent to the `std.heap.smp_allocator`
    pub inline fn generic() Allocator {
        return AI_generic.allocator orelse Blk: {
            switch (builtin.mode) {
                .Debug, .ReleaseFast => {
                    AI_generic.interface = std.heap.DebugAllocator(.{}){};
                    AI_generic.allocator = AI_generic.interface.?.allocator();
                },
                else => AI_generic.allocator = std.heap.smp_allocator,
            }
            break :Blk AI_generic.allocator.?;
        };
    }

    /// Global arena allocator, everything allocated will be freed at program exit.
    pub inline fn arena() Allocator {
        return AI_arena.allocator orelse Blk: {
            AI_arena.interface = std.heap.ArenaAllocator.init(generic());
            AI_arena.allocator = AI_arena.interface.?.allocator();

            break :Blk AI_arena.allocator.?;
        };
    }

    /// If `eventloop` has an Scene loaded, this is a shorthand for
    /// `fyr.eventloop.active_scene.allocator()`, otherwise this is the
    /// same as `arena`.
    pub inline fn scene() noreturn {
        @panic("Not Implemented");
    }
};

pub const Behaviour = ecs.Behaviour;
pub const Entity = ecs.Entity;
pub const Prefab = ecs.Prefab;
pub const Scene = eventloop.Scene;

pub const UUIDv7 = uuid.v7.new;
