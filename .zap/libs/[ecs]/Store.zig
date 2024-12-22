const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const Entry = @import("./Entry.zig");
const zap = @import("../../main.zig");

const ComponentErrors = error{ ItemCreationError, AlreadyHasComponent };
const Self = @This();

list: std.ArrayList(Entry),
original_alloc: Allocator,
arena_alloc: ?Allocator = null,
arena: std.heap.ArenaAllocator,

pub fn init(alloc: Allocator) Self {
    return Self{
        .arena = std.heap.ArenaAllocator.init(alloc),
        .original_alloc = alloc,
        .list = std.ArrayList(Entry).init(alloc),
    };
}

pub fn new() Self {
    return Self.init(zap.getAllocator(.gpa));
}

pub fn deinit(self: *Self) void {
    for (self.list.items) |item| {
        item.deinit();
    }
    self.list.deinit();
    self.arena.deinit();
}

pub inline fn allocator(self: *Self) Allocator {
    if (self.arena_alloc == null) self.arena_alloc = self.arena.allocator();
    return self.arena_alloc.?;
}

pub fn store(self: *Self, value: anytype) !void {
    if (self.getComponent(@TypeOf(value)) != null) return ComponentErrors.AlreadyHasComponent;
    try self.list.append(Entry.init(value) orelse return ComponentErrors.ItemCreationError);
}

pub fn addComonent(self: *Self, comptime T: type, value: T) !void {
    try self.store(value);
}

pub fn getComponent(self: *Self, comptime T: type) ?*T {
    const hash = Entry.calculateHash(T);

    for (self.list.items) |item| {
        if (item.hash != hash) continue;

        return item.castBack(T);
    }

    return null;
}
