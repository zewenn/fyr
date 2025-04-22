const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const fyr = @import("../../main.zig");
const Entity = fyr.Entity;

const EventActions = std.ArrayList(Action);
const EventMapType = std.AutoHashMap(Target, EventActions);
const Action = @import("Action.zig");
const Script = @import("Script.zig");
pub const Target = isize;

const Self = @This();

id: []const u8,
arena: std.heap.ArenaAllocator,
arena_alloc: ?Allocator = null,

entities: ?std.ArrayList(*Entity) = null,
scripts: ?std.ArrayList(*Script) = null,

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

    if (self.scripts) |scripts| {
        for (scripts.items) |script| {
            self.allocator().destroy(script);
        }

        scripts.deinit();
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
        self.removeEntityByPtr(entity);
    }
}

// Event Handling

fn makeGetEventList(self: *Self, event: anytype) !*EventActions {
    const emap: *EventMapType = &(self.event_map orelse @panic("event_map wasn't initalised! Call eventloop.init()!"));

    const key = fyr.coerceTo(Target, event) orelse -1;

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
                fyr.logWarn("Ignored function failiure!", .{});
            },
            .remove => {
                fyr.logWarn("Removed function failiure!", .{});
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

// Entities - Generics

pub fn addEntity(self: *Self, entity: *Entity) !void {
    const behaviours = try entity.getBehaviours();
    const entities = self.makeGetEntities();
    try entities.append(entity);

    for (behaviours) |b| {
        b.callSafe(.awake, entity);
    }
    for (behaviours) |b| {
        b.callSafe(.start, entity);
    }
}

pub fn removeEntity(self: *Self, value: anytype, eqls: *const fn (@TypeOf(value), *Entity) bool) void {
    const entities = self.makeGetEntities();
    for (entities.items, 0..) |entity, index| {
        if (!eqls(value, entity)) continue;

        const behaviours = entity.getBehaviours() catch &[_]*fyr.Behaviour{};
        for (behaviours) |b| {
            b.callSafe(.end, entity);
        }
        _ = entities.swapRemove(index);
        break;
    }
}

pub fn getEntity(self: *Self, value: anytype, eqls: *const fn (@TypeOf(value), *Entity) bool) ?*Entity {
    const entities = self.entities orelse return null;
    for (entities.items) |entity| {
        if (!eqls(value, entity)) continue;
        return Entity;
    }

    return null;
}

pub fn isEntityAlive(self: *Self, value: anytype, eqls: *const fn (@TypeOf(value), *Entity) bool) bool {
    const entities = self.entities orelse return false;
    for (entities.items) |entity| {
        if (!eqls(value, entity)) continue;
        return true;
    }

    return false;
}

// Entities - Specified

fn ptrEqls(ptr: *Entity, entity: *Entity) bool {
    return @intFromPtr(ptr) == @intFromPtr(entity);
}

fn idEqls(string: []const u8, entity: *Entity) bool {
    return std.mem.eql(u8, string, entity.id);
}

fn uuidEqls(uuid: u128, entity: *Entity) bool {
    return uuid == entity.uuid;
}

pub fn removeEntityByPtr(self: *Self, entity: *Entity) void {
    removeEntity(self, entity, ptrEqls);
}

pub fn removeEntityById(self: *Self, id: []const u8) void {
    removeEntity(self, id, idEqls);
}

pub fn removeEntityByUuid(self: *Self, uuid: u128) void {
    removeEntity(self, uuid, uuidEqls);
}

pub fn getEntityById(self: *Self, id: []const u8) ?*Entity {
    return getEntity(self, id, idEqls);
}

pub fn getEntityByUuid(self: *Self, uuid: u128) ?*Entity {
    return getEntity(self, uuid, uuidEqls);
}

pub fn isEntityAliveId(self: *Self, id: []const u8) bool {
    return isEntityAlive(self, id, idEqls);
}

pub fn isEntityAliveUuid(self: *Self, uuid: u128) bool {
    return isEntityAlive(self, uuid, uuidEqls);
}

// Scripts

fn makeGetScripts(self: *Self) *std.ArrayList(*Script) {
    return &(self.scripts orelse Blk: {
        self.scripts = .init(fyr.allocators.generic());
        break :Blk self.scripts.?;
    });
}

pub fn newScript(self: *Self, value: anytype) !void {
    if (!Script.isScript(value)) return;

    const script = try Script.from(value);
    const ptr = try self.allocator().create(Script);
    ptr.* = script;

    const scripts = self.makeGetScripts();
    try scripts.append(ptr);
}
