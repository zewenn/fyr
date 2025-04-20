const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const Entry = @import("./Entry.zig");
const fyr = @import("../../main.zig");

const ComponentErrors = error{ ItemCreationError, AlreadyHasComponent };
const Self = @This();

id: []const u8,
uuid: u128,
list: std.ArrayList(Entry),
original_alloc: Allocator,

arena_alloc: ?Allocator = null,
arena: std.heap.ArenaAllocator,

pub fn init(alloc: Allocator, id: []const u8) Self {
    return Self{
        .id = id,
        .uuid = fyr.UUIDV7(),
        .arena = std.heap.ArenaAllocator.init(alloc),
        .original_alloc = alloc,
        .list = std.ArrayList(Entry).init(alloc),
    };
}

pub fn new(id: []const u8) Self {
    return Self.init(fyr.allocators.generic(), id);
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

pub fn addComonent(self: *Self, value: anytype) !void {
    const isBehaviour = fyr.Behaviour.isBehaviourBase(value);

    fyr.logInfo("c({s}): {s}", .{
        if (isBehaviour) "behaviour" else "normal",
        @typeName(@TypeOf(value)),
    });

    try self.list.append(
        if (isBehaviour)
            Entry.initBehaviour(
                @TypeOf(value),
                try fyr.asBehaviour(value),
            ) orelse
                return ComponentErrors.ItemCreationError
        else
            Entry.init(
                value,
            ) orelse
                return ComponentErrors.ItemCreationError,
    );
}

pub fn getComponent(self: *Self, T: type) ?*T {
    const hash = comptime Entry.calculateHash(T);

    for (self.list.items) |item| {
        if (item.hash != hash) continue;
        if (item.is_behaviour and fyr.Behaviour.isBehvaiourBaseType(T)) {
            return item.castBackBehaviour(T);
        }

        return item.castBack(T);
    }

    return null;
}

pub fn getComponents(self: *Self, T: type) ![]*T {
    const hash = comptime Entry.calculateHash(T);

    var arr = std.ArrayList(*T).init(self.allocator());
    defer arr.deinit();

    for (self.list.items) |item| {
        if (item.hash != hash) continue;

        const ptr = item.castBack(T) orelse continue;

        try arr.append(ptr);
    }

    return arr.toOwnedSlice();
}

pub fn getBehaviours(self: *Self) ![]*fyr.Behaviour {
    var arr = std.ArrayList(*fyr.Behaviour).init(self.allocator());
    defer arr.deinit();

    for (self.list.items) |item| {
        if (!item.is_behaviour) continue;

        const ptr = item.castBack(fyr.Behaviour) orelse continue;
        try arr.append(ptr);
    }

    return arr.toOwnedSlice();
}
