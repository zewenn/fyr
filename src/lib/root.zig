const std = @import("std");
const builtin = @import("builtin");
const Allocator = @import("std").mem.Allocator;

const rl = @import("raylib");

pub const ecs = struct {
    pub const Behaviour = @import("./ecs/Behaviour.zig");
    pub const Entity = @import("./ecs/Entity.zig");
    pub const Prefab = @import("./ecs/Prefab.zig");
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
