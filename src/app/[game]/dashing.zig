const std = @import("std");

const Allocator = @import("std").mem.Allocator;

const e = @import("../../engine/engine.m.zig");

// ===================== [Entity] =====================

// =================== [Components] ===================

// ===================== [Others] =====================

// ===================== [Events] =====================

const BoundShadow = struct {
    entity: e.Entity,
    target: *e.Entity,
    lifetime: f32 = 0.15,
};

const manager = e.zlib.HeapManager(BoundShadow, (struct {
    pub fn callback(_: Allocator, item: *BoundShadow) !void {
        e.entities.remove(item.entity.id);
        e.ALLOCATOR.free(item.entity.id);
        item.entity.deinit();
    }
}).callback);

const TMTYPE = e.time.TimeoutHandler(*BoundShadow);
var tm: TMTYPE = undefined;

fn isPointerInBounds(ptr: *u8, begin: *u8, end: *u8) bool {
    const ptrInt = @intFromPtr(ptr);
    const startInt = @intFromPtr(begin);
    const endInt = @intFromPtr(end);
    return ptrInt >= startInt and ptrInt < endInt;
}

pub fn awake() !void {
    manager.init(e.ALLOCATOR);
    tm = TMTYPE.init(e.ALLOCATOR);
}

pub fn init() !void {}

pub fn update() !void {
    try tm.update();
    const entities = try e.entities.all();
    defer e.entities.alloc.free(entities);

    for (entities) |entity| {
        if (entity.entity_stats == null) continue;
        if (entity.dash_modifiers == null) continue;

        if (!entity.entity_stats.?.is_dashing) continue;

        if (entity.dash_modifiers.?.dash_end <= e.time.gameTime) {
            entity.entity_stats.?.is_dashing = false;
            entity.entity_stats.?.can_move = true;
            if (entity.entity_stats.?.is_invalnureable and entity.dash_modifiers.?.change_invulnerable)
                entity.entity_stats.?.is_invalnureable = false;
            continue;
        }

        try spawnShadow(
            entity,
            @floatCast(entity.dash_modifiers.?.dash_time / 3),
        );

        entity.transform.position.x +=
            entity.dash_modifiers.?.towards.x *
            entity.entity_stats.?.movement_speed *
            entity.dash_modifiers.?.movement_speed_multiplier *
            @as(f32, @floatCast(e.time.deltaTime));

        entity.transform.position.y +=
            entity.dash_modifiers.?.towards.y *
            entity.entity_stats.?.movement_speed *
            entity.dash_modifiers.?.movement_speed_multiplier *
            @as(f32, @floatCast(e.time.deltaTime));
    }
}

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

    tm.deinit();
}

pub fn applyDash(entity: *e.entities.Entity, towards: f32, strength: f32, use_charges: bool) !void {
    if (entity.entity_stats == null) return;
    if (entity.dash_modifiers == null) return;

    if (entity.dash_modifiers.?.charges_available == 0) return;

    if (use_charges) {
        entity.dash_modifiers.?.charges_available -= 1;
        if (entity.dash_modifiers.?.recharge_end < e.time.gameTime) {
            entity.dash_modifiers.?.recharge_end = e.time.gameTime + entity.dash_modifiers.?.recharge_time;
        }
    }

    entity.entity_stats.?.is_dashing = true;
    entity.entity_stats.?.can_move = false;
    if (!entity.entity_stats.?.is_invalnureable and entity.dash_modifiers.?.change_invulnerable)
        entity.entity_stats.?.is_invalnureable = true;

    entity.dash_modifiers.?.towards = e.Vec2(1, 0)
        .rotate(std.math.degreesToRadians(towards));

    entity.dash_modifiers.?.dash_end = e.time.gameTime + entity.dash_modifiers.?.dash_time * strength;
}

pub fn spawnShadow(target: *e.Entity, lifetime: f32) !void {
    const bound = e.Entity{
        .id = try e.UUIDV7(),
        .tags = "bound, dash-shadow",
        .transform = target.*.transform,
        .display = .{
            .sprite = target.*.display.sprite,
            .scaling = target.*.display.scaling,
            .tint = e.Colour.dark_purple,
            .layer = .trail_effects,
        },
    };

    const appended = try manager.appendReturn(.{
        .entity = bound,
        .target = target,
        .lifetime = lifetime,
    });

    try e.entities.append(&(appended.entity));

    try tm.setTimeout(
        (struct {
            pub fn callback(args: *BoundShadow) !void {
                manager.removeFreeId(args);
            }
        }).callback,
        appended,
        appended.lifetime,
    );
}
