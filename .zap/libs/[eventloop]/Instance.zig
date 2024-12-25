const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const zap = @import("../../main.zig");
const Store = zap.Store;

const EventActions = std.ArrayList(Action);
const EventMapType = std.AutoHashMap(Target, EventActions);
const Action = @import("Action.zig");
pub const Target = isize;

const Self = @This();

arena: std.heap.ArenaAllocator,
arena_alloc: ?Allocator = null,

stores: ?std.ArrayList(*Store) = null,

original_alloc: Allocator,
event_map: ?EventMapType,
executing: bool = false,

// Creation -- Deletion

pub fn init(alloc: Allocator) Self {
    return Self{
        .arena = std.heap.ArenaAllocator.init(alloc),
        .original_alloc = alloc,
        .event_map = EventMapType.init(alloc),
    };
}

pub fn deinit(self: *Self) void {
    const emap = &(self.event_map orelse return);

    var entries = emap.iterator();
    while (entries.next()) |entry| {
        entry.value_ptr.deinit();
    }

    emap.deinit();
    self.arena.deinit();
}

// Arena

pub inline fn allocator(self: *Self) Allocator {
    if (self.arena_alloc == null) {
        self.arena_alloc = self.arena.allocator();
    }
    return self.arena_alloc.?;
}

pub inline fn reset(self: *Self) void {
    _ = self.arena.reset(.free_all);
}

// Event Handling

fn makeGetEvent(self: *Self, event: anytype) !*EventActions {
    const emap: *EventMapType = &(self.event_map orelse @panic("event_map wasn't initalised! Call eventloop.init()!"));

    const key = zap.changeType(Target, event) orelse -1;

    if (!emap.contains(key)) {
        try emap.put(key, EventActions.init(self.original_alloc));
    }

    return emap.getPtr(key).?;
}

pub fn on(self: *Self, event: anytype, action: Action) !void {
    const ptr = try self.makeGetEvent(event);

    try ptr.append(action);
}

pub fn call(self: *Self, event: anytype) !void {
    const ptr = try self.makeGetEvent(event);

    const items = try zap.cloneToOwnedSlice(Action, ptr.*);
    defer ptr.allocator.free(items);

    for (items) |action| {
        action.fn_ptr() catch switch (action.on_fail) {
            .ignore => {
                std.log.warn("Ignored function failiure!", .{});
            },
            .remove => {
                std.log.warn("Removed function failiure!", .{});
                for (ptr.items, 0..) |item, index| {
                    if (!std.meta.eql(item, action)) continue;

                    _ = ptr.swapRemove(index);
                    break;
                }
            },
            .panic => @panic("Critical eventloop action failiure!"),
        };
    }
}

// Stores

fn makeGetStores(self: *Self) *std.ArrayList(*Store) {
    if (self.stores == null) self.stores = std.ArrayList(*Store).init(self.allocator());
    return &(self.stores.?);
}

pub fn newStore(self: *Self) !*Store {
    const ptr = try self.allocator().create(Store);
    ptr.* = Store.init(self.allocator());

    const stores = self.makeGetStores();
    try stores.append(ptr);

    return ptr;
}

pub fn removeStore(self: *Self, store: *Store) void {
    const stores = self.makeGetStores();
    for (stores.items, 0..) |it, index| {
        if (@intFromPtr(store) != @intFromPtr(it)) continue;
        _ = stores.swapRemove(index);
    }
}
