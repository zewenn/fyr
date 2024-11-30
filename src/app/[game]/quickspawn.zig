const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const conf = @import("../../config.zig");

const e = @import("../../engine/engine.m.zig");

pub const manager = e.zlib.HeapManager(e.Entity, (struct {
    pub fn callback(alloc: Allocator, item: *e.Entity) !void {
        if (!e.entities.tagged(item, "quickspawn")) return;
        e.entities.remove(item.id);
        alloc.free(item.id);
    }
}).callback);

pub fn awake() !void {
    manager.init(e.ALLOCATOR);
}

pub fn init() !void {}

pub fn update() !void {}

pub fn deinit() !void {
    const items = manager.items() catch {
        std.log.err("Failed to get items from the manager", .{});
        return;
    };
    defer manager.alloc.free(items);

    for (items) |item| {
        manager.removeFreeId(item);
    }

    manager.deinit();
}

pub fn destruct(entity: *e.Entity) void {
    manager.removeFreeId(entity);
}

pub fn spawn(entity: e.Entity) !*e.Entity {
    var new = entity;

    new.id = try e.UUIDV7();
    new.tags = "quickspawn, entity";

    const it = try manager.appendReturn(new);

    try e.entities.append(it);

    return it;
}
