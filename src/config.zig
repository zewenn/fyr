const std = @import("std");
const Allocator = @import("std").mem.Allocator;
const HeapManager = @import("engine/z/heapmanager.zig").HeapManager;

const entities_module = @import("./engine/entities/entities.m.zig");
const rl = @import("raylib");
const uuid = @import("uuid");
const z = @import("./engine/z/z.m.zig");
const UUIDV7 = @import("./engine/engine.m.zig").UUIDV7;

pub const Entity = struct {
    const Self = @This();

    id: []const u8,
    tags: []const u8,
    transform: entities_module.Transform,
    display: entities_module.Display,
    collider: ?entities_module.Collider = null,
    cached_display: ?entities_module.CachedDisplay = null,
    cached_collider: ?entities_module.RectangleVertices = null,
    dummy_data: entities_module.DummyData = .{},

    shooting_stats: ?ShootingStats = null,

    facing: enum { left, right } = .left,
    projectile_data: ?ProjectileData = null,

    entity_stats: ?EntityStats = null,

    dash_modifiers: ?DashModifiers = null,
    effect_shower_stats: ?BoundEntityStats = null,

    /// This will resolve all allocations that can
    /// happen within an entity
    /// From raylib stuff to the on hit effects.
    pub fn deinit(self: *Self) void {
        if (self.cached_display) |cached| {
            if (cached.img) |image| {
                rl.unloadImage(image);
                self.cached_display.?.img = null;
            }
            if (cached.texture) |texture| {
                rl.unloadTexture(texture);
                self.cached_display.?.texture = null;
            }
        }
    }

    pub fn dummy() Self {
        return Self{
            .id = "dummy",
            .tags = "",
            .transform = .{ .scale = .{
                .x = 0,
                .y = 0,
            } },
            .display = .{
                .sprite = "sprites/missingno.png",
            },
        };
    }
};

pub const entities = entities_module.make(Entity);

pub const ProjectileSide = enum {
    player,
    enemy,
};

pub const BoundEntityStats = struct {
    bound_entity_id: []const u8,
    keep_alive: bool = false,
};

pub const ProjectileData = struct {
    lifetime_end: f64,
    side: ProjectileSide,
    weight: enum {
        light,
        heavy,
    },
    sprite: []const u8,
    speed: f32,
    direction: f32,
    scale: rl.Vector2,
    damage: f32 = 10,
    health: f32 = 0.01,
    bleed_per_second: f32 = 100,

    owner: ?*Entity = null,
    on_hit_effect: Effects = .none,
    on_hit_effect_strength: f32 = 0,
    on_hit_target: OnHitTargets = .self,
};

pub const ShootingStats = struct {
    timeout: f64 = 0.1,
    timeout_end: f64 = 0,
    projectile_lifetime: f64 = 2,
};

pub const EntityStats = struct {
    const Self = @This();

    base_movement_speed: f32 = 335,
    movement_speed: f32 = 335,
    max_movement_speed: f32 = 1280,

    health: f32 = 100,
    max_health: f32 = 100,
    damage: f32 = 1,

    crit_rate: f32 = 0,
    crit_damage_multiplier: f32 = 2,

    aggro_distance: f32 = 600,
    is_aggroed: bool = false,
    run_away_distance: f32 = 0,

    is_enemy: bool = false,
    range: f32 = 500,

    can_move: bool = false,
    can_dash: bool = true,
    is_dashing: bool = false,
    is_invalnureable: bool = false,

    is_slowed: bool = false,
    is_rooted: bool = false,
    is_stunned: bool = false,
    is_asleep: bool = false,

    is_healing: bool = false,
    is_energised: bool = false,

    enemy_archetype: EnemyArchetypes = .minion,
    enemy_subtype: EnemySubtypes = .normal,
};

pub const Effects = enum {
    none,
    slowed,
    rooted,
    stunned,
    asleep,
    invulnerable,
    healing,
    energised,
    stengthen,
};

pub const EffectsShown = struct {
    slowed: bool = false,
    rooted: bool = false,
    stunned: bool = false,
    asleep: bool = false,
    healing: bool = false,
    invulnerable: bool = false,
    energised: bool = false,
};

pub const EnemyArchetypes = enum {
    minion,
    brute,
    angler,
    tank,
    shaman,
    knight,
};

pub const EnemySubtypes = enum {
    normal,
};

pub const DashModifiers = struct {
    movement_speed_multiplier: f32 = 3,
    dash_time: f64 = 1,
    towards: rl.Vector2 = rl.Vector2.init(1, 0),
    base_charges: usize = 2,
    charges: usize = 2,
    charges_available: usize = 2,

    recharge_time: f64 = 1.5,
    recharge_end: f64 = 0,
    change_invulnerable: bool = true,

    dash_end: f64 = 0,
};

pub const ItemTypes = enum {
    spell,
    weapon,
    ring,
    amethyst,
    wayfinder,
};

pub const ItemStats = enum {
    damage,
    health,
    crit_rate,
    crit_damage,
    movement_speed,
    tenacity,
    dash_charges,
};

pub const OnHitApplied = struct {
    type: Effects,
    delta: f32,
    end_time: f64,
};

pub const OnHitTargets = enum {
    self,
    enemy,
};

pub const WeaponAttackTypeStats = struct {
    projectile_scale: rl.Vector2 = .{
        .x = 64,
        .y = 64,
    },
    projectile_speed: f32 = 650,
    projectile_array: [16]?f32 = [1]?f32{0} ++ ([_]?f32{null} ** 15),
    projectile_lifetime: f32 = 0.5,

    /// Any projectile_health above 1 will make the
    /// projectile into a piercing projectile
    projectile_health: f32 = 0.01,
    projectile_bps: f32 = 100,

    projectile_on_hit_effect: Effects = .none,
    projectile_on_hit_strength_multiplier: f32 = 1,
    projectile_target: OnHitTargets = .self,

    multiplier: f32 = 1,
    sprite: []const u8 = "sprites/projectiles/player/generic/light.png",
    attack_speed_modifier: f32 = 1,
};

pub fn mergeWeaponAttackStats(base: WeaponAttackTypeStats, new: WeaponAttackTypeStats) WeaponAttackTypeStats {
    const default = WeaponAttackTypeStats{};
    var res = base;

    const fields: []const std.builtin.Type.StructField = std.meta.fields(WeaponAttackTypeStats);

    inline for (fields) |field| {
        if (!z.eql(@field(base, field.name), @field(new, field.name)) and
            !z.eql(@field(default, field.name), @field(new, field.name)))
        {
            const fieldptr = &(@field(res, field.name));
            fieldptr.* = @field(new, field.name);
        }
    }

    return res;
}

pub fn WeaponAttackLightStats(stats: WeaponAttackTypeStats) WeaponAttackTypeStats {
    return mergeWeaponAttackStats(
        .{
            .projectile_lifetime = 0.65,
        },
        stats,
    );
}
pub fn WeaponAttackHeavyStats(stats: WeaponAttackTypeStats) WeaponAttackTypeStats {
    return mergeWeaponAttackStats(
        .{
            .projectile_lifetime = 0.85,
            .multiplier = 2,
            .attack_speed_modifier = 2,
        },
        stats,
    );
}
pub fn WeaponAttackDashStats(stats: WeaponAttackTypeStats) WeaponAttackTypeStats {
    return mergeWeaponAttackStats(
        .{
            .projectile_lifetime = 1.05,
            .multiplier = 1.25,
            .attack_speed_modifier = 1.5,
            .projectile_scale = .{
                .x = 128,
                .y = 64,
            },
            .projectile_speed = 860,
        },
        stats,
    );
}

pub fn createProjectileArray(comptime size: usize, comptime degree_list: [size]?f32) [16]?f32 {
    return degree_list ++ ([_]?f32{null} ** (16 - size));
}

pub fn createTypeArray(comptime T: type, comptime size: usize, comptime list: [size]?T) [16]?T {
    return @as([size]?T, list) ++ ([_]?T{null} ** (16 - size));
}

pub fn createTypeArrayUnknownLength(comptime T: type, comptime list: []?T) [16]?T {
    var ls: [16]?T = [_]?T{null} ** 16;

    for (list, 0..) |item, index| {
        ls[index] = item;
    }

    return ls;
}

pub fn newItem(item: Item) Item {
    var res = item;
    res.weapon_light = WeaponAttackLightStats(res.weapon_light);
    res.weapon_heavy = WeaponAttackHeavyStats(res.weapon_heavy);
    res.weapon_dash = WeaponAttackDashStats(res.weapon_dash);

    return res;
}

pub const AttackTypes = enum {
    light,
    heavy,
    dash,
};

pub const Rarity = enum {
    common,
    epic,
    legendary,
};

pub const SpellSlots = enum { q, e, r, x };

pub const Item = struct {
    /// If id is 0 the Item is a prefab and should not be modified without cloning
    id: u128 = 0,

    T: ItemTypes = .weapon,
    rarity: Rarity = .common,

    // This is obviously not applicable to any non-weapons
    weapon_type: enum {
        sword,
        polearm,
        daggers,
        claymore,
        special,
    } = .sword,

    equipped: bool = false,
    equipped_spell_slot: ?SpellSlots = null,
    unequippable: bool = true,

    level: usize = 0,
    cost_per_level: usize = 16,
    base_upgrade_cost: usize = 16,

    health: f32 = 0,
    tenacity: f32 = 0,

    damage: f32 = 0,
    crit_rate: f32 = 0,
    crit_damage_multiplier: f32 = 0,

    movement_speed: f32 = 0,
    dash_charges: f32 = 0,

    /// Smaller better
    attack_speed: f32 = 0.25,

    weapon_light: WeaponAttackTypeStats = WeaponAttackLightStats(.{}),
    weapon_heavy: WeaponAttackTypeStats = WeaponAttackHeavyStats(.{}),
    weapon_dash: WeaponAttackTypeStats = WeaponAttackDashStats(.{}),

    spell_archetype: SpellTypes = .spawn,
    spell_blessings: [16]?Blessings = createTypeArray(Blessings, 0, [_]?Blessings{}),

    weapon_projectile_scale_light: rl.Vector2 = .{
        .x = 64,
        .y = 64,
    },

    name: []const u8,

    icon: []const u8 = "sprites/missingno.png",
    weapon_sprite_left: []const u8 = "sprites/missingno.png",
    weapon_sprite_right: []const u8 = "sprites/missingno.png",

    // useless_field: ?u8 = null,
};

// ========================================================================
//
//                                SPELLS
//
// ========================================================================

// @spells

pub const SpellTypes = enum {
    spawn,
    lingering,
    targeted,
};

pub const Blessings = enum {
    /// Pure damage increase @done
    fire,
    /// Multiple Projectiles, +1/fracture blessing @done
    fracture,
    /// Summon speed @done
    zephyr,
    /// Projectile Rounds @done
    curse,
    /// Healing @done
    blood,
    /// Energised on hit @done
    kin,
    /// Upscale the projectiles @done
    steel,
    /// Increased crit rate
    death,
};

// ========================================================================
//
//                                LEVELS
//
// ========================================================================

pub const Level = struct {
    rounds: [][]EnemySpawner,
    reward_tier: Rarity,
    backgrounds: []Entity,
    walls: []Entity,
    player_pos: rl.Vector2 = .{
        .x = 0,
        .y = 0,
    },
};

pub const LoadedLevel = struct {
    rounds: [][]*EnemySpawner,
    reward_tier: Rarity,
    backgrounds: []*Entity,
    walls: []*Entity,
    player_pos: rl.Vector2 = .{
        .x = 0,
        .y = 0,
    },
};

pub const EnemySpawner = struct {
    enemy_archetype: EnemyArchetypes,
    enemy_subtype: EnemySubtypes,
    spawn_at: rl.Vector2,
};
