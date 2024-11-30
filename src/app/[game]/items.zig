const std = @import("std");
const conf = @import("../../config.zig");

const e = @import("../../engine/engine.m.zig");

const LightStats = conf.WeaponAttackLightStats;
const HeavyStats = conf.WeaponAttackHeavyStats;
const DashStats = conf.WeaponAttackDashStats;

const Item = conf.newItem;

pub fn awake() !void {}

pub fn init() !void {}

pub fn update() !void {}

pub fn deinit() !void {}

/// If the id of an item is 0, it's a prefab.
pub const prefabs = struct {
    pub const hands = Item(.{
        .id = 0,
        .T = .weapon,
        .weapon_type = .daggers,

        .damage = 10,
        .weapon_projectile_scale_light = e.Vec2(64, 64),

        .weapon_heavy = .{
            .sprite = "sprites/projectiles/player/generic/heavy.png",
        },

        .name = "Hands",
        .equipped = true,
        .unequippable = false,

        .attack_speed = 0.25,

        .icon = "sprites/weapons/gloves/left.png",
        .weapon_sprite_left = "sprites/weapons/gloves/left.png",
        .weapon_sprite_right = "sprites/weapons/gloves/right.png",
    });

    pub const commons = struct {
        pub const weapons = struct {
            pub const angler_spear = Item(.{
                .T = .weapon,
                .rarity = .common,
                .weapon_type = .polearm,
                .damage = 5,
                .attack_speed = 1,

                .name = "Angler Spear",

                .weapon_light = .{
                    .projectile_speed = 720,
                    .projectile_array = conf.createProjectileArray(
                        4,
                        [_]?f32{ -180, -90, 0, 90 },
                    ),
                },

                .icon = "sprites/weapons/normal_polearm.png",
                .weapon_sprite_right = "sprites/weapons/normal_polearm.png",
            });
            pub const tank_spreader = Item(.{
                .T = .weapon,
                .rarity = .common,
                .weapon_type = .sword,
                .damage = 5,
                .attack_speed = 1,
                .level = 10,

                .name = "Tank Spreader",

                .weapon_light = .{
                    .projectile_lifetime = 0.25,
                    .projectile_speed = 720,
                    .projectile_array = conf.createProjectileArray(
                        9,
                        [_]?f32{
                            -20,
                            -15,
                            -10,
                            -5,
                            0,
                            5,
                            10,
                            15,
                            20,
                        },
                    ),
                    .projectile_on_hit_effect = .healing,
                },

                .icon = "sprites/weapons/steel_sword.png",
                .weapon_sprite_right = "sprites/weapons/steel_sword.png",
            });

            pub const knights_claymore = Item(.{
                .T = .weapon,
                .weapon_type = .claymore,
                .rarity = .common,
                .damage = 20,
                .weapon_projectile_scale_light = e.Vec2(64, 128),

                .name = "Claymore",
                .attack_speed = 1,

                .weapon_light = .{
                    .projectile_array = [4]?f32{ -180, -90, 0, 90 } ++ ([_]?f32{null} ** 12),
                    .projectile_health = 2000,
                    .projectile_scale = e.Vec2(128, 64),
                    // .projectile_on_hit_effect = .stengthen,
                },
                .weapon_heavy = .{
                    .projectile_array = conf.createProjectileArray(
                        8,
                        [_]?f32{ -180, -135, -90, -45, 0, 45, 90, 135 },
                    ),
                    .projectile_health = 5000,
                    .projectile_scale = e.Vec2(256, 128),
                    .attack_speed_modifier = 2.5,
                    .sprite = "sprites/projectiles/player/generic/heavy.png",
                    // .projectile_on_hit_effect = .stengthen,
                },
                .weapon_dash = .{
                    .projectile_array = [1]?f32{0} ++ ([_]?f32{null} ** 15),
                    .projectile_health = 3500,
                    .projectile_scale = e.Vec2(385, 128),
                    .attack_speed_modifier = 2,
                    .projectile_speed = 720,
                    .sprite = "sprites/projectiles/player/generic/dash.png",
                },

                .icon = "sprites/weapons/normal_claymore.png",
                .weapon_sprite_left = e.MISSINGNO,
                .weapon_sprite_right = "sprites/weapons/normal_claymore.png",
            });
        };
    };

    pub const epics = struct {
        pub const weapons = struct {
            pub const piercing_sword = Item(.{
                .T = .weapon,
                .rarity = .epic,
                .damage = 10,

                .name = "Piercing Sword",

                .weapon_light = .{
                    .projectile_health = 500,
                },
                .weapon_heavy = .{
                    .projectile_health = 1000,
                    .sprite = "sprites/projectiles/player/generic/heavy.png",
                },

                .icon = "sprites/weapons/normal_sword.png",
                .weapon_sprite_left = e.MISSINGNO,
                .weapon_sprite_right = "sprites/weapons/normal_sword.png",
            });
        };
        pub const amethysts = struct {
            pub const normal_amethyst: conf.Item = .{
                .T = .amethyst,
                .rarity = .epic,
                .damage = 10,
                .weapon_projectile_scale_light = e.Vec2(64, 64),

                .name = "Amethyst",
                .icon = "sprites/items/common/amethyst/normal.png",
            };
        };
    };

    pub const legendaries = struct {
        pub const weapons = struct {
            pub const legendary_sword = Item(.{
                .equipped = true,
                .id = 0,
                .T = .weapon,
                .rarity = .legendary,
                .damage = 10,
                .weapon_projectile_scale_light = e.Vec2(64, 64),

                .level = 10,

                .attack_speed = 0.25,

                .name = "Legendary Sword",
                .weapon_light = .{
                    .projectile_array = conf.createProjectileArray(
                        5,
                        [_]?f32{ -75, -37.5, 0, 37.5, 75 },
                    ),
                    .projectile_on_hit_effect = .healing,
                },
                .weapon_heavy = .{
                    .projectile_array = [5]?f32{ -25, -12.5, 0, 12.5, 25 } ++ ([_]?f32{null} ** 11),
                    .sprite = "sprites/projectiles/player/generic/heavy.png",
                },
                .weapon_dash = .{
                    .projectile_array = conf.createProjectileArray(
                        3,
                        [_]?f32{ -30, 0, 30 },
                    ),
                    .sprite = "sprites/projectiles/player/generic/dash.png",
                },

                .icon = "sprites/weapons/normal_sword.png",
                .weapon_sprite_left = e.MISSINGNO,
                .weapon_sprite_right = "sprites/weapons/normal_sword.png",
            });

            pub const staff = Item(.{
                .T = .weapon,
                .level = 100,
                .weapon_type = .polearm,
                .rarity = .legendary,
                .damage = 10,
                .weapon_projectile_scale_light = e.Vec2(64, 64),

                .name = "Staff",

                .attack_speed = 0.215,
                .dash_charges = 2,

                .weapon_light = .{
                    .projectile_array = [3]?f32{ -60, 0, 60 } ++ ([_]?f32{null} ** 13),
                    .projectile_health = 500,
                    .projectile_on_hit_effect = .slowed,
                },
                .weapon_heavy = .{
                    .projectile_health = 1000,
                    .sprite = "sprites/projectiles/player/generic/heavy.png",
                },
                .weapon_dash = .{
                    .projectile_array = [5]?f32{ -100, -60, 0, 60, 100 } ++ ([_]?f32{null} ** 11),
                    .projectile_health = 750,
                    .projectile_speed = 720,
                },

                .icon = "sprites/weapons/normal_polearm.png",
                .weapon_sprite_left = e.MISSINGNO,
                .weapon_sprite_right = "sprites/weapons/normal_polearm.png",
            });

            pub const daggers = Item(.{
                .T = .weapon,
                .level = 100,
                .weapon_type = .daggers,
                .rarity = .legendary,
                .damage = 10,
                .weapon_projectile_scale_light = e.Vec2(64, 64),

                .name = "Daggers of the Gods",

                .weapon_light = .{
                    .projectile_array = [2]?f32{ -20, 20 } ++ ([_]?f32{null} ** 14),

                    .projectile_on_hit_effect = .slowed,
                    .projectile_on_hit_strength_multiplier = 1.5,
                    .projectile_target = .enemy,
                },
                .weapon_heavy = .{
                    .projectile_array = [3]?f32{ -20, 0, 20 } ++ ([_]?f32{null} ** 13),
                    .projectile_health = 1000,
                    .sprite = "sprites/projectiles/player/generic/heavy.png",
                },

                .icon = "sprites/weapons/normal_dagger.png",
                .weapon_sprite_left = "sprites/weapons/normal_dagger.png",
                .weapon_sprite_right = "sprites/weapons/normal_dagger.png",
            });

            pub const claymore = Item(.{
                .T = .weapon,
                .weapon_type = .claymore,
                .rarity = .legendary,
                .damage = 120,
                .weapon_projectile_scale_light = e.Vec2(64, 128),

                .name = "Claymore",
                .attack_speed = 1,

                .weapon_light = .{
                    .projectile_array = [4]?f32{ -180, -90, 0, 90 } ++ ([_]?f32{null} ** 12),
                    .projectile_health = 2000,
                    .projectile_scale = e.Vec2(128, 64),
                    // .projectile_on_hit_effect = .stengthen,
                },
                .weapon_heavy = .{
                    .projectile_array = conf.createProjectileArray(
                        8,
                        [_]?f32{ -180, -135, -90, -45, 0, 45, 90, 135 },
                    ),
                    .projectile_health = 5000,
                    .projectile_scale = e.Vec2(256, 128),
                    .attack_speed_modifier = 2.5,
                    .sprite = "sprites/projectiles/player/generic/heavy.png",
                    // .projectile_on_hit_effect = .stengthen,
                },
                .weapon_dash = .{
                    .projectile_array = [1]?f32{0} ++ ([_]?f32{null} ** 15),
                    .projectile_health = 3500,
                    .projectile_scale = e.Vec2(385, 128),
                    .attack_speed_modifier = 2,
                    .projectile_speed = 720,
                    .sprite = "sprites/projectiles/player/generic/dash.png",
                },

                .icon = "sprites/weapons/normal_claymore.png",
                .weapon_sprite_left = e.MISSINGNO,
                .weapon_sprite_right = "sprites/weapons/normal_claymore.png",
            });
        };
    };
};

pub fn usePrefab(prefab: conf.Item) conf.Item {
    var it: conf.Item = prefab;

    it.id = e.uuid.v7.new();

    return it;
}
