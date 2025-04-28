const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const Entity = @import("./Entity.zig");

pub const PrefabFn = *const fn (Allocator) anyerror!*Entity;
const Self = @This();

func: PrefabFn,

pub fn new(comptime id: []const u8, comptime components: anytype) Self {
    return Self{
        .func = struct {
            pub fn callback(alloc: Allocator) !*Entity {
                const ptr = try Entity.create(alloc, id);
                try ptr.addComponents(components);

                return ptr;
            }
        }.callback,
    };
}

pub fn makeInstance(self: Self, alloc: Allocator) !*Entity {
    return try self.func(alloc);
}
