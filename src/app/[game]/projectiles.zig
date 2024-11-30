const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const conf = @import("../../config.zig");
const e = @import("../../engine/engine.m.zig");

// ===================== [Entity] =====================

// =================== [Components] ===================

// ===================== [Others] =====================

// ===================== [Events] =====================

const weapons = @import("weapons.zig");

pub const manager = e.zlib.HeapManager(e.entities.Entity, (struct {
    pub fn callback(alloc: Allocator, item: *e.entities.Entity) !void {
        e.entities.remove(item.id);
        item.deinit();
        alloc.free(item.id);
    }
}).callback);

const PLAYER_PROJECTILE_LIGHT_SPRITE = "sprites/projectiles/projectile_player_light.png";
const PLAYER_PROJECTILE_HEAVY_SPRITE = "sprites/projectiles/projectile_player_heavy.png";
const ENEMY_PROJECTILE_LIGHT_SPRITE = "sprites/projectiles/projectile_enemy_light.png";
const ENEMY_PROJECTILE_HEAVY_SPRITE = "sprites/projectiles/projectile_enemy_heavy.png";

const ENEMY_ATTACK_TIMEOUT_MULTIPLIER: comptime_float = 5;
const ENEMY_PROJECTILE_SPEED_DECREASE_MULTIPLIER: comptime_float = 1.05;

pub fn awake() !void {
    manager.init(e.ALLOCATOR);
    // std.log.info("Maximum projectile count: {d}", .{ProjectileManager.ArraySize});
}

pub fn init() !void {}

pub fn update() !void {
    const others = try e.entities.searchExclude("projectile");
    defer e.ALLOCATOR.free(others);

    const items = try manager.items();
    defer manager.alloc.free(items);

    projectile_loop: for (items) |entity_ptr| {
        if (entity_ptr.projectile_data == null) {
            std.log.err("Projectile without projectile data!", .{});
            std.log.err("Removing...", .{});

            manager.remove(entity_ptr);
            continue;
        }

        const projectile_data = &(entity_ptr.projectile_data.?);

        if (projectile_data.lifetime_end < e.time.gameTime) {
            manager.removeFreeId(entity_ptr);
            continue;
        }

        if (!e.entities.exists(entity_ptr.id)) {
            try e.entities.append(entity_ptr);
        }

        const direction_vector = e.Vec2(1, 0)
            .rotate(std.math.degreesToRadians(projectile_data.direction))
            .normalize();

        entity_ptr.transform.rotation.z = projectile_data.direction - 90;

        entity_ptr.transform.position.x += direction_vector.x * projectile_data.speed * @as(f32, @floatCast(e.time.deltaTime));
        entity_ptr.transform.position.y += direction_vector.y * projectile_data.speed * @as(f32, @floatCast(e.time.deltaTime));

        // std.log.debug("index: {d} - {s}", .{ index, item.id });

        for (others) |other| {
            if (other.entity_stats == null) continue;

            if (projectile_data.side == .player and std.mem.eql(u8, other.id, "Player"))
                continue;

            if (projectile_data.side == .enemy and std.mem.containsAtLeast(
                u8,
                other.tags,
                1,
                "enemy",
            ))
                continue;

            if (!e.collision.collides(entity_ptr, other)) {
                continue;
            }

            // if (std.mem.containsAtLeast(u8, other.tags, 1, "wall")) {
            //     manager.removeFreeId(entity_ptr);
            //     continue;
            // }

            projectile_data.health -= projectile_data.bleed_per_second * e.time.DeltaTime();

            if (!other.entity_stats.?.is_invalnureable) {
                if (projectile_data.health > 1) {
                    other.entity_stats.?.health -= projectile_data.damage * 5 * e.time.DeltaTime();
                } else {
                    other.entity_stats.?.health -= projectile_data.damage;
                }
            }

            if (std.mem.eql(u8, other.id, "Player")) {
                e.camera.trauma = 50;
                try e.camera.resetShakeAfter(0.25, 25);
            }

            if (projectile_data.health <= 0 or other.entity_stats.?.health <= 0) OnHit: {
                switch (projectile_data.on_hit_target) {
                    .enemy => {
                        if (other.entity_stats.?.health > 0) {
                            weapons.applyEffect(
                                other,
                                projectile_data.on_hit_effect,
                                projectile_data.on_hit_effect_strength,
                            );
                            break :OnHit;
                        }
                    },
                    .self => {
                        if (projectile_data.owner) |owner| {
                            weapons.applyEffect(
                                owner,
                                projectile_data.on_hit_effect,
                                projectile_data.on_hit_effect_strength,
                            );
                        }
                    },
                }
            }

            if (projectile_data.health <= 0) {
                manager.removeFreeId(entity_ptr);
                continue :projectile_loop;
            }
        }
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
}

pub fn new(at: e.Vector2, data: conf.ProjectileData) !void {
    const id_o = e.uuid.urn.serialize(e.uuid.v7.new());
    // std.log.debug("id: {s}", .{id});

    const id = try e.ALLOCATOR.alloc(u8, 36);
    std.mem.copyForwards(u8, id, &id_o);

    const New = e.entities.Entity{
        .id = id,
        .tags = "projectile",
        .transform = .{
            .position = at,
            .rotation = e.Vector3.init(0, 0, 0),
            .scale = data.scale,
        },
        .display = .{
            .scaling = .pixelate,
            .sprite = data.sprite,
        },
        .projectile_data = data,
        .collider = .{
            .trigger = true,
            .dynamic = false,
            .weight = 0,
            .rect = e.Rect(
                0,
                0,
                data.scale.x,
                data.scale.y,
            ),
        },
    };

    try manager.append(New);
}

pub fn summonMultiple(
    T: conf.AttackTypes,
    entity: *e.entities.Entity,
    weapon: conf.Item,
    bonus_damage: f32,
    shoot_angle: f32,
    side: conf.ProjectileSide,
) !void {
    if (entity.shooting_stats.?.timeout_end >= e.time.gameTime) return;
    const strct = switch (T) {
        .dash => weapon.weapon_dash,
        .heavy => weapon.weapon_heavy,

        else => weapon.weapon_light,
    };

    const is_crit = e.loadf32(std.crypto.random.intRangeAtMostBiased(i32, 0, 100)) < weapon.crit_rate;

    for (strct.projectile_array) |pa| {
        const plus_angle: f32 = if (pa) |p| p else continue;

        try new(entity.transform.position, .{
            .direction = shoot_angle + plus_angle,
            .lifetime_end = e.time.gameTime +
                strct.projectile_lifetime,
            .scale = strct.projectile_scale,
            .side = side,
            .weight = .heavy,
            .speed = strct.projectile_speed,
            .damage = entity.entity_stats.?.damage +
                entity.entity_stats.?.damage +
                bonus_damage +
                weapon.damage *
                strct.multiplier * if (is_crit) weapon.crit_damage_multiplier else 1,
            .health = strct.projectile_health,
            .bleed_per_second = strct.projectile_bps,
            .sprite = strct.sprite,

            .owner = entity,
            .on_hit_effect = strct.projectile_on_hit_effect,
            // .on_hit_effect = if (side == .player) strct.projectile_on_hit_effect else .none,
            .on_hit_effect_strength = @as(
                f32,
                @floatFromInt(weapon.level),
            ) *
                strct.projectile_on_hit_strength_multiplier,
            .on_hit_target = strct.projectile_target,
        });
    }

    entity.shooting_stats.?.timeout_end = e.time.gameTime +
        weapon.attack_speed *
        strct.attack_speed_modifier;
}
