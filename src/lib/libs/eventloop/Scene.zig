const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const fyr = @import("../../main.zig");
const Entity = fyr.Entity;

const EventActions = std.ArrayList(Action);
const EventMapType = std.AutoHashMap(Target, EventActions);
const Action = @import("Action.zig");
pub const Target = isize;

const Self = @This();

id: []const u8,
arena: std.heap.ArenaAllocator,
arena_alloc: ?Allocator = null,

entities: ?std.ArrayList(*Entity) = null,

original_alloc: Allocator,
event_map: ?EventMapType,
executing: bool = false,

// Creation -- Destruction

pub fn init(alloc: Allocator, id: []const u8) Self {
    return Self{
        .arena = std.heap.ArenaAllocator.init(alloc),
        .original_alloc = alloc,
        .event_map = EventMapType.init(alloc),
        .id = id,
    };
}

pub fn deinit(self: *Self) void {
    const emap = &(self.event_map orelse return);

    var entries = emap.iterator();
    while (entries.next()) |entry| {
        entry.value_ptr.deinit();
    }

    emap.deinit();
    self.reset();
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
    defer _ = self.arena.reset(.free_all);

    const entities = self.entities orelse return;
    for (entities.items) |entity| {
        self.removeEntity(entity);
    }
}

// Event Handling

fn makeGetEventList(self: *Self, event: anytype) !*EventActions {
    const emap: *EventMapType = &(self.event_map orelse @panic("event_map wasn't initalised! Call eventloop.init()!"));

    const key = fyr.changeNumberType(Target, event) orelse -1;

    if (!emap.contains(key)) {
        try emap.put(key, EventActions.init(self.original_alloc));
    }

    return emap.getPtr(key).?;
}

pub fn on(self: *Self, event: anytype, action: Action) !void {
    const ptr = try self.makeGetEventList(event);

    try ptr.append(action);
}

pub fn call(self: *Self, event: anytype) !void {
    const ptr = try self.makeGetEventList(event);

    const items = try fyr.cloneToOwnedSlice(Action, ptr.*);
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

// Entitys

fn makeGetEntities(self: *Self) *std.ArrayList(*Entity) {
    if (self.entities == null) self.entities = std.ArrayList(*Entity).init(self.allocator());
    return &(self.entities.?);
}

pub fn newEntity(self: *Self, id: []const u8, components: anytype) !*Entity {
    const ptr = try self.allocator().create(Entity);
    ptr.* = Entity.init(self.allocator(), id);

    inline for (components) |component| {
        try ptr.addComonent(component);
    }

    return ptr;
}

pub fn addEntity(self: *Self, entity: *Entity) !void {
    const behaviours = try entity.getBehaviours();
    for (behaviours) |b| {
        b.callSafe(.awake, entity);
        b.callSafe(.init, entity);
    }

    const entities = self.makeGetEntities();
    try entities.append(entity);
}

pub fn removeEntity(self: *Self, entity: *Entity) void {
    const entities = self.makeGetEntities();
    for (entities.items, 0..) |it, index| {
        if (@intFromPtr(entity) != @intFromPtr(it)) continue;

        const behaviours = entity.getBehaviours() catch &[_]*fyr.Behaviour{};
        for (behaviours) |b| {
            b.callSafe(.deinit, entity);
        }
        _ = entities.swapRemove(index);
        break;
    }
}

pub fn removeEntityByUuid(self: *Self, uuid: u128) void {
    const entities = self.makeGetEntities();
    for (entities.items, 0..) |it, index| {
        if (it.uuid != uuid) continue;

        const behaviours = it.getBehaviours() catch &[_]*fyr.Behaviour{};
        for (behaviours) |b| {
            b.callSafe(.deinit, it);
        }
        _ = entities.swapRemove(index);
        break;
    }
}

pub fn removeEntityById(self: *Self, id: []const u8) void {
    const entities = self.makeGetEntities();
    for (entities.items, 0..) |it, index| {
        if (std.mem.eql(u8, id, it.id)) continue;

        const behaviours = it.getBehaviours() catch &[_]*fyr.Behaviour{};
        for (behaviours) |b| {
            b.callSafe(.deinit, it);
        }
        _ = entities.swapRemove(index);
        break;
    }
}

pub fn getEntityById(self: *Self, id: []const u8) ?*Entity {
    const Entitys = self.entities orelse return null;
    for (Entitys.items) |entity| {
        if (!std.mem.eql(u8, entity.id, id)) continue;
        return Entity;
    }

    return null;
}

pub fn getEntityByUuid(self: *Self, uuid: u128) ?*Entity {
    const Entitys = self.entities orelse return null;
    for (Entitys.items) |entity| {
        if (entity.uuid == uuid) continue;
        return Entity;
    }

    return null;
}

pub fn isEntityAliveId(self: *Self, id: []const u8) bool {
    const Entitys = self.entities orelse return false;
    for (Entitys.items) |entity| {
        if (!std.mem.eql(u8, entity.id, id)) continue;
        return true;
    }

    return false;
}

pub fn isEntityAliveUuid(self: *Self, uuid: u128) bool {
    const Entitys = self.entities orelse return false;
    for (Entitys.items) |entity| {
        if (entity.uuid == uuid) continue;
        return Entity;
    }

    return false;
}
