const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const loom = @import("../root.zig");
const Entity = loom.Entity;

const Self = @This();
var active: ?*Self = null;

id: []const u8,
uuid: u128,
alloc: Allocator,

prefabs: std.ArrayList(loom.Prefab),
entities: std.ArrayList(*loom.Entity),
new_entities: std.ArrayList(*loom.Entity),

is_active: bool = false,
is_alive: bool = false,

last_tick_at: f64 = 0,
ticks_per_second: u8 = 20,

pub fn init(allocator: Allocator, id: []const u8) Self {
    return Self{
        .id = id,
        .uuid = loom.UUIDv7(),
        .alloc = allocator,
        .is_alive = true,
        .prefabs = .init(allocator),
        .entities = .init(allocator),
        .new_entities = .init(allocator),
    };
}

pub fn create(allocator: Allocator, id: []const u8) !*Self {
    const ptr = try allocator.create(Self);
    ptr.* = .init(allocator, id);

    return ptr;
}

pub fn deinit(self: *Self) void {
    self.unload();
    self.prefabs.deinit();
}

pub fn destroy(self: *Self) void {
    self.deinit();
    self.alloc.destroy(self);
}

pub fn load(self: *Self) !void {
    if (!self.is_alive) return;

    for (self.prefabs.items) |prefabs| {
        const entity = try prefabs.makeInstance(self.alloc);
        try self.entities.append(entity);

        try entity.addPreparedComponents(false);

        entity.dispatchEvent(.awake);
    }

    for (self.entities.items) |entity| {
        entity.dispatchEvent(.start);
    }

    self.is_active = true;
}

pub fn unload(self: *Self) void {
    for (self.entities.items) |entity| {
        entity.remove_next_frame = true;
    }

    for (self.entities.items) |item| {
        item.dispatchEvent(.end);
    }

    const clone = loom.Array(*loom.Entity).fromArrayList(self.entities) catch return;
    defer clone.deinit();

    for (clone.items) |entity| {
        for (self.entities.items, 0..) |original, index| {
            if (original.uuid != entity.uuid) continue;

            original.destroy();
            _ = self.entities.swapRemove(index);
            break;
        }
    }

    self.entities.clearAndFree();
    self.is_active = false;
}

pub fn execute(self: *Self) void {
    const is_tick = self.last_tick_at + 1.0 / loom.tof64(self.ticks_per_second) <= loom.time.appTime();

    var new_entities_clone = loom.Array(*Entity).fromArrayList(self.new_entities) catch loom.Array(*Entity){ .items = &.{} };
    defer new_entities_clone.deinit();

    self.new_entities.clearAndFree();

    for (new_entities_clone.items) |entity| {
        if (entity.remove_next_frame) continue;
        self.entities.append(entity) catch continue;

        entity.addPreparedComponents(true) catch continue;
    }

    const clone = loom.cloneToOwnedSlice(*loom.Entity, self.entities) catch return;
    defer loom.allocators.generic().free(clone);

    for (clone) |entity| {
        if (!entity.remove_next_frame) continue;
        entity.dispatchEvent(.end);

        for (self.entities.items, 0..) |original, index| {
            if (original.uuid != entity.uuid) continue;

            original.destroy();
            _ = self.entities.swapRemove(index);
            break;
        }
    }

    for (self.entities.items) |entity| {
        entity.addPreparedComponents(true) catch {};
        entity.dispatchEvent(.update);

        if (is_tick) {
            entity.dispatchEvent(.tick);
            self.last_tick_at = loom.time.gameTime();
        }
    }
}

pub fn addPrefab(self: *Self, prefab: loom.Prefab) !void {
    if (!self.is_alive) return;

    try self.prefabs.append(prefab);
}

pub fn addPrefabs(self: *Self, prefab_tuple: anytype) !void {
    if (!self.is_alive) return;

    inline for (prefab_tuple) |prefab| {
        const T = @TypeOf(prefab);

        if (T == loom.Prefab) try self.addPrefab(prefab);
    }
}

pub fn newEntity(self: *Self, id: []const u8, component_tuple: anytype) !void {
    const entity = try loom.Entity.create(self.alloc, id);
    entity.addComponents(component_tuple);

    self.addEntity(entity);
}

pub fn addEntity(self: *Self, entity: *loom.Entity) !void {
    if (!self.is_alive) return;

    try self.new_entities.append(entity);
}

pub fn getEntity(self: *Self, value: anytype, eqls: *const fn (@TypeOf(value), *Entity) bool) ?*Entity {
    for (self.entities.items) |entity| {
        if (eqls(value, entity)) return entity;
    }
    return null;
}

pub fn removeEntity(self: *Self, value: anytype, eqls: *const fn (@TypeOf(value), *Entity) bool) void {
    for (self.entities.items) |entity| {
        if (!eqls(value, entity)) continue;

        entity.remove_next_frame = true;
    }
}

pub fn isEntityAlive(self: *Self, value: anytype, eqls: *const fn (@TypeOf(value), *Entity) bool) bool {
    const entities = self.entities;
    for (entities.items) |entity| {
        if (!eqls(value, entity)) continue;
        return true;
    }

    return false;
}

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
