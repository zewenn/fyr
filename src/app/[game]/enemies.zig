const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const conf = @import("../../config.zig");
const e = @import("../../engine/engine.m.zig");

const weapons = @import("weapons.zig");
const prefabs = @import("items.zig").prefabs;
const usePrefab = @import("items.zig").usePrefab;
const quickspawn = @import("quickspawn.zig");

const dashing = @import("dashing.zig");
const projectiles = @import("projectiles.zig");

const HAND_DISTANCE = 24;
const HAND_ANGLE_SNAP_DEGREES = 12.5;

var Player: ?*e.entities.Entity = null;

const EnemyStruct = struct {
    entity: e.entities.Entity,
    animator: ?e.Animator = null,
    hand0: e.entities.Entity,
    hand1: e.entities.Entity,
    hands: ?weapons.Hands = null,
    current_weapon: conf.Item = prefabs.epics.weapons.piercing_sword,
    health_display: *e.GUI.GUIElement = undefined,
};

pub const manager = e.zlib.HeapManager(EnemyStruct, (struct {
    pub fn callback(alloc: Allocator, item: *EnemyStruct) !void {
        if (item.hands) |*hands| {
            hands.deinit();
        }

        e.entities.remove(item.hand0.id);
        item.hand0.deinit();
        alloc.free(item.hand0.id);

        e.entities.remove(item.hand1.id);
        item.hand1.deinit();
        alloc.free(item.hand1.id);

        const porj_items = try projectiles.manager.items();
        defer projectiles.manager.alloc.free(porj_items);

        for (porj_items) |projectile| {
            if (projectile.projectile_data.?.owner) |owner| {
                if (!e.zlib.eql(owner.*, item.entity)) continue;
                projectile.projectile_data.?.owner = null;
            }
        }

        e.entities.remove(item.entity.id);
        item.entity.deinit();
        alloc.free(item.entity.id);

        if (item.animator) |*animator| {
            animator.deinit();
        }

        if (item.health_display.is_content_heap) {
            e.zlib.arrays.freeManyItemPointerSentinel(e.ALLOCATOR, item.health_display.contents.?);
        }

        try e.GUI.remove(item.health_display);
    }
}).callback);

const TMType = e.time.TimeoutHandler(struct {
    archetype: conf.EnemyArchetypes,
    subtype: conf.EnemySubtypes,
    at: e.Vector2,
    spawn_display: *e.Entity,
});
var tm: TMType = undefined;

const MELEE_LEFT_0 = "sprites/entity/enemies/melee/left_0.png";
const MELEE_LEFT_1 = "sprites/entity/enemies/melee/left_1.png";
const MELEE_RIGHT_0 = "sprites/entity/enemies/melee/right_0.png";
const MELEE_RIGHT_1 = "sprites/entity/enemies/melee/right_1.png";

const BRUTE_LEFT_0 = "sprites/entity/enemies/brute/left_0.png";
const BRUTE_LEFT_1 = "sprites/entity/enemies/brute/left_1.png";
const BRUTE_RIGHT_0 = "sprites/entity/enemies/brute/right_0.png";
const BRUTE_RIGHT_1 = "sprites/entity/enemies/brute/right_1.png";

const MINION_LEFT_0 = "sprites/entity/enemies/minion/left_0.png";
const MINION_LEFT_1 = "sprites/entity/enemies/minion/left_1.png";
const MINION_RIGHT_0 = "sprites/entity/enemies/minion/right_0.png";
const MINION_RIGHT_1 = "sprites/entity/enemies/minion/right_1.png";

const ANGLER_LEFT_0 = "sprites/entity/enemies/angler/left.png";
const ANGLER_RIGHT_0 = "sprites/entity/enemies/angler/right.png";

const TANK_LEFT_0 = "sprites/entity/enemies/tank/left_0.png";
const TANK_LEFT_1 = "sprites/entity/enemies/tank/left_1.png";
const TANK_RIGHT_0 = "sprites/entity/enemies/tank/right_0.png";
const TANK_RIGHT_1 = "sprites/entity/enemies/tank/right_1.png";

// ===================== [Entity] =====================

// =================== [Components] ===================

// ===================== [Others] =====================

// ===================== [Events] =====================

pub fn awake() !void {
    manager.init(e.ALLOCATOR);
    tm = TMType.init(e.ALLOCATOR);
}

pub fn init() !void {
    Player = e.entities.get("Player").?;
}

pub fn update() !void {
    try tm.update();
    const items = try manager.items();
    defer manager.alloc.free(items);

    for (items) |item| {
        var entity_ptr = &(item.entity);

        const entity_flag: bool = Get: {
            if (entity_ptr.entity_stats == null) break :Get false;
            if (!entity_ptr.entity_stats.?.is_enemy) break :Get false;
            break :Get true;
        };

        if (!entity_flag) {
            std.log.err("Enemy without projectile data!", .{});
            std.log.err("Removing...", .{});

            manager.remove(item);
            continue;
        }

        // ==========================================
        //
        //                   REMOVE
        //
        // ==========================================

        if (entity_ptr.entity_stats.?.health <= 0) {
            manager.removeFreeId(item);
            continue;
        }

        // ==========================================
        //
        //                 INITALISE
        //
        // ==========================================

        if (!e.entities.exists(entity_ptr.id)) {
            try e.entities.append(entity_ptr);

            item.animator = e.Animator.init(
                &e.ALLOCATOR,
                entity_ptr,
            );

            item.hands = try weapons.Hands.init(
                &e.ALLOCATOR,
                &item.hand0,
                &item.hand1,
            );

            try e.entities.append(&item.hand0);
            try e.entities.append(&item.hand1);

            var animator = &(item.animator.?);
            {
                var walk_left_anim = e.Animator.Animation.init(
                    &e.ALLOCATOR,
                    "walk_left",
                    e.Animator.interpolation.ease_in_out,
                    0.25,
                );

                _ = walk_left_anim
                    .chain(
                    0,
                    .{
                        .rotation = 0,
                        .sprite = switch (item.entity.entity_stats.?.enemy_archetype) {
                            .minion => MINION_LEFT_0,
                            .brute => BRUTE_LEFT_0,
                            .angler => ANGLER_LEFT_0,
                            .tank => TANK_LEFT_0,
                            else => MELEE_LEFT_0,
                        },
                    },
                )
                    .chain(
                    50,
                    .{
                        .rotation = -5,
                        .sprite = switch (item.entity.entity_stats.?.enemy_archetype) {
                            .minion => MINION_LEFT_1,
                            .brute => BRUTE_LEFT_1,
                            .angler => ANGLER_LEFT_0,
                            .tank => TANK_LEFT_1,
                            else => MELEE_LEFT_1,
                        },
                    },
                )
                    .chain(
                    100,
                    .{
                        .rotation = 0,
                        .sprite = switch (item.entity.entity_stats.?.enemy_archetype) {
                            .minion => MINION_LEFT_0,
                            .brute => BRUTE_LEFT_0,
                            .angler => ANGLER_LEFT_0,
                            .tank => TANK_LEFT_0,
                            else => MELEE_LEFT_0,
                        },
                    },
                );

                try animator.chain(walk_left_anim);
            }
            {
                var walk_right_anim = e.Animator.Animation.init(
                    &e.ALLOCATOR,
                    "walk_right",
                    e.Animator.interpolation.ease_in_out,
                    0.25,
                );

                _ = walk_right_anim
                    .chain(
                    0,
                    .{
                        .rotation = 0,
                        .sprite = switch (item.entity.entity_stats.?.enemy_archetype) {
                            .minion => MINION_RIGHT_0,
                            .brute => BRUTE_RIGHT_0,
                            .angler => ANGLER_RIGHT_0,
                            .tank => TANK_RIGHT_0,
                            else => MELEE_RIGHT_0,
                        },
                    },
                )
                    .chain(
                    50,
                    .{
                        .rotation = 5,
                        .sprite = switch (item.entity.entity_stats.?.enemy_archetype) {
                            .minion => MINION_RIGHT_1,
                            .brute => BRUTE_RIGHT_1,
                            .angler => ANGLER_RIGHT_0,
                            .tank => TANK_RIGHT_1,
                            else => MELEE_RIGHT_1,
                        },
                    },
                )
                    .chain(
                    100,
                    .{
                        .rotation = 0,
                        .sprite = switch (item.entity.entity_stats.?.enemy_archetype) {
                            .minion => MINION_RIGHT_0,
                            .brute => BRUTE_RIGHT_0,
                            .angler => ANGLER_RIGHT_0,
                            .tank => TANK_RIGHT_0,
                            else => MELEE_RIGHT_0,
                        },
                    },
                );

                try animator.chain(walk_right_anim);
            }

            const health_display_id = try std.fmt.allocPrint(
                e.ALLOCATOR,
                "enemy-{s}-health-display",
                .{item.entity.id},
            );

            item.health_display = try e.GUI.Text(
                .{
                    .id = health_display_id,
                    .style = .{
                        .font = .{
                            .size = 16,
                            .shadow = .{
                                .color = e.Colour.dark_purple,
                                .offset = e.Vec2(2, 2),
                            },
                        },
                        .z_index = -1,
                        .color = e.Colour.red,
                        .translate = .{
                            .x = .center,
                            .y = .center,
                        },
                        .top = e.GUI.u("30x"),
                        .left = e.GUI.u("10w"),
                    },
                },
                "100",
            );
            item.health_display.heap_id = true;
        }

        // ==========================================
        //
        //                  UPDATE
        //
        // ==========================================

        item.hands.?.equip(&(item.current_weapon));
        item.hands.?.update();

        var animator = &(item.animator.?);
        animator.update();

        const action = std.crypto.random.intRangeLessThanBiased(
            u32,
            0,
            @intFromFloat(200_000 * e.time.deltaTime),
        );

        const distance_vec = Player.?.transform.position
            .subtract(entity_ptr.transform.position);

        const distance: f32 = distance_vec.length();

        const normalised_distance_vec = distance_vec
            .normalize();

        if (item.entity.dash_modifiers.?.recharge_end < e.time.gameTime) {
            item.entity.dash_modifiers.?.charges_available = item.entity.dash_modifiers.?.charges;
        }

        const angle = HAND_ANGLE_SNAP_DEGREES * @round(std.math.radiansToDegrees(
            std.math.atan2(
                normalised_distance_vec.y,
                normalised_distance_vec.x,
            ),
        ) / HAND_ANGLE_SNAP_DEGREES);

        const move_vec = normalised_distance_vec;

        if (entity_ptr.entity_stats.?.can_move and
            !entity_ptr.entity_stats.?.is_rooted and
            !entity_ptr.entity_stats.?.is_stunned and
            !entity_ptr.entity_stats.?.is_asleep and
            (distance < entity_ptr.entity_stats.?.aggro_distance or entity_ptr.entity_stats.?.is_aggroed))
        {
            entity_ptr.entity_stats.?.is_aggroed = true;
            switch (action) {
                // Apply dash
                1 => Dash: {
                    if (!item.entity.entity_stats.?.can_dash) break :Dash;
                    const direction: f32 = angle + @as(
                        f32,
                        @floatFromInt(
                            std.crypto.random.intRangeLessThanBiased(
                                i32,
                                -90,
                                90,
                            ),
                        ),
                    );
                    try dashing.applyDash(
                        entity_ptr,
                        (direction),
                        1,
                        false,
                    );
                    break :Dash;
                },
                else => {},
            }
            if (distance >= item.entity.entity_stats.?.run_away_distance) {
                entity_ptr.transform.position.x += move_vec.x * entity_ptr.entity_stats.?.movement_speed * e.time.DeltaTime();
                entity_ptr.transform.position.y += move_vec.y * entity_ptr.entity_stats.?.movement_speed * e.time.DeltaTime();
            } else {
                entity_ptr.transform.position.x -= move_vec.x * entity_ptr.entity_stats.?.movement_speed * e.time.DeltaTime();
                entity_ptr.transform.position.y -= move_vec.y * entity_ptr.entity_stats.?.movement_speed * e.time.DeltaTime();
            }

            switch (move_vec.x >= 0) {
                true => {
                    if (!animator.isPlaying("walk_right")) {
                        animator.stop("walk_left");
                        try animator.play("walk_right");
                    }
                },
                false => {
                    if (!animator.isPlaying("walk_left")) {
                        animator.stop("walk_right");
                        try animator.play("walk_left");
                    }
                },
            }
        }

        if (entity_ptr.shooting_stats.?.timeout_end < e.time.gameTime and
            distance < entity_ptr.entity_stats.?.range)
        {
            switch (item.entity.entity_stats.?.enemy_archetype) {
                .shaman => {
                    for (0..3) |_| {
                        try spawnArchetype(
                            .minion,
                            item.entity.entity_stats.?.enemy_subtype,
                            item.entity.transform.position,
                        );
                        entity_ptr.shooting_stats.?.timeout_end = e.time.gameTime + item.current_weapon.attack_speed;
                    }
                },
                else => {
                    try projectiles.summonMultiple(
                        .light,
                        &item.entity,
                        item.current_weapon,
                        0,
                        angle,
                        .enemy,
                    );

                    try item.hands.?.play(.light);

                    if (item.entity.entity_stats.?.enemy_archetype == .knight) {
                        item.entity.entity_stats.?.is_invalnureable = !item.entity.entity_stats.?.is_invalnureable;
                    }
                },
            }
        }

        if (item.hands) |*hands| {
            const Hand0 = &item.hand0;
            const Hand1 = &item.hand1;

            const This = item.entity;

            var rotator_vector0 = e.Vector2.init(HAND_DISTANCE, Hand0.transform.scale.x);
            if (hands.playing_left) {
                rotator_vector0.x += Hand0.transform.rotation.y;
                rotator_vector0.y += Hand0.transform.rotation.x;
            }

            const finished0 = rotator_vector0.rotate(std.math.degreesToRadians(-90));

            var rotator_vector1 = e.Vector2.init(HAND_DISTANCE, 0);
            if (hands.playing_right) {
                rotator_vector1.x += Hand1.transform.rotation.y;
                rotator_vector1.y += Hand1.transform.rotation.x;
            }

            const finished1 = rotator_vector1.rotate(std.math.degreesToRadians(-90));

            Hand0.transform.anchor = finished0;
            Hand1.transform.anchor = finished1;

            const rotation: f32 = angle - 90;

            Hand0.transform.position = .{
                .x = This.transform.position.x,
                .y = This.transform.position.y,
            };
            Hand0.transform.rotation.z = GetRotation: {
                if (!hands.playing_left) break :GetRotation rotation + hands.left_base_rotation;

                break :GetRotation rotation + Hand0.transform.rotation.z + hands.left_base_rotation;
            };
            Hand1.transform.position = .{
                .x = This.transform.position.x + 0,
                .y = This.transform.position.y + 0,
            };
            Hand1.transform.rotation.z = GetRotation: {
                if (!hands.playing_right) break :GetRotation rotation + hands.right_base_rotation;

                break :GetRotation rotation + Hand1.transform.rotation.z + hands.right_base_rotation;
            };
        }

        const screen_pos = e.camera.worldPositionToScreenPosition(e.Vec2(
            item.entity.transform.position.x,
            item.entity.transform.position.y - item.entity.transform.scale.y,
        ));

        item.health_display.options.style.top = e.GUI.toUnit(screen_pos.y);

        item.health_display.options.style.left = e.GUI.toUnit(screen_pos.x);

        if (item.health_display.is_content_heap) {
            e.zlib.arrays.freeManyItemPointerSentinel(e.ALLOCATOR, item.health_display.contents.?);
        }
        const content = try std.fmt.allocPrint(
            e.ALLOCATOR,
            "{d:.0}%",
            .{item.entity.entity_stats.?.health / item.entity.entity_stats.?.max_health * 100},
        );
        defer e.ALLOCATOR.free(content);

        const multipointer_content = try e.zlib.arrays.toManyItemPointerSentinel(
            e.ALLOCATOR,
            content,
        );

        item.health_display.contents = multipointer_content;
        item.health_display.is_content_heap = true;

        item.health_display.options.style.width = e.GUI.toUnit(
            e.loadf32(
                std.mem.indexOfSentinel(
                    u8,
                    0,
                    item.health_display.contents.?,
                ),
            ) *
                item.health_display.options.style.font.size,
        );
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

pub fn spawnArchetype(archetype: conf.EnemyArchetypes, subtype: conf.EnemySubtypes, at: e.Vector2) !void {
    const id = try e.UUIDV7();

    const scale_and_collider = switch (archetype) {
        .minion => e.Vec2(48, 48),
        .tank => e.Vec2(128, 128),
        .shaman => e.Vec2(80, 80),
        .knight => e.Vec2(64, 128),

        else => e.Vec2(64, 64),
    };

    const max_health: f32 = switch (archetype) {
        .minion => 20,
        .brute => 100,
        .angler => 40,
        .tank => 350,
        .shaman => 240,
        .knight => 210,
    };

    const move_speed: f32 = switch (archetype) {
        .minion => 650,
        .brute => 325,
        .angler => 250,
        .tank => 225,
        .shaman => 235,
        .knight => 350,
    };

    const New = e.entities.Entity{
        .id = id,
        .tags = "enemy",
        .transform = .{
            .position = at,
            .scale = scale_and_collider,
        },
        .display = .{
            .scaling = .pixelate,
            .sprite = switch (archetype) {
                .minion => MINION_LEFT_0,
                .brute => BRUTE_LEFT_0,
                .angler => ANGLER_LEFT_0,
                .tank => TANK_LEFT_0,
                else => MELEE_LEFT_0,
            },
        },
        .entity_stats = .{
            .is_enemy = true,
            .can_move = true,
            .can_dash = switch (archetype) {
                .minion, .brute, .knight => true,
                else => false,
            },
            .health = max_health,
            .max_health = max_health,
            .movement_speed = move_speed,
            .enemy_archetype = archetype,
            .enemy_subtype = subtype,
            .range = switch (archetype) {
                .minion => 200,
                .brute => 250,
                .angler => 750,
                .tank => 450,
                .shaman => 500,
                .knight => 350,
            },
            .run_away_distance = switch (archetype) {
                .angler => 700,
                .tank => 300,
                .shaman => 650,

                else => 200,
            },

            .damage = switch (archetype) {
                .knight => 10,
                else => 1,
            },
        },
        .dash_modifiers = .{
            .dash_time = 0.25,
            .change_invulnerable = if (archetype == .knight) false else true,
        },
        .collider = .{
            .dynamic = true,
            .rect = e.Rectangle.init(
                0,
                0,
                scale_and_collider.x,
                scale_and_collider.y,
            ),
            .weight = 0.95,
        },
        .shooting_stats = .{
            .timeout = 0.55,
        },
    };

    const hand0_id = try std.fmt.allocPrint(
        e.ALLOCATOR,
        "hand0-{s}",
        .{id},
    );
    const hand1_id = try std.fmt.allocPrint(
        e.ALLOCATOR,
        "hand1-{s}",
        .{id},
    );

    const Hand0 = e.entities.Entity{
        .id = hand0_id,
        .tags = "hand",
        .transform = e.entities.Transform{
            .scale = e.Vec2(48, 48),
        },
        .display = .{
            .scaling = .pixelate,
            .sprite = e.MISSINGNO,
        },
    };

    const Hand1 = e.entities.Entity{
        .id = hand1_id,
        .tags = "hand",
        .transform = e.entities.Transform{
            .scale = e.Vec2(96, 256),
        },
        .display = .{
            .scaling = .pixelate,
            .sprite = e.MISSINGNO,
        },
    };

    try manager.append(
        .{
            .entity = New,
            .hand0 = Hand0,
            .hand1 = Hand1,
            .current_weapon = getWeaponOfArchetype(
                archetype,
                subtype,
            ),
        },
    );
}

pub fn getWeaponOfArchetype(archetype: conf.EnemyArchetypes, subtype: conf.EnemySubtypes) conf.Item {
    var weapon = switch (archetype) {
        .minion => switch (subtype) {
            .normal => usePrefab(prefabs.epics.weapons.piercing_sword),
        },
        .brute => switch (subtype) {
            .normal => usePrefab(prefabs.legendaries.weapons.staff),
        },
        .angler => switch (subtype) {
            .normal => usePrefab(prefabs.commons.weapons.angler_spear),
        },
        .tank => switch (subtype) {
            .normal => usePrefab(prefabs.commons.weapons.tank_spreader),
        },
        .shaman => switch (subtype) {
            .normal => usePrefab(prefabs.legendaries.weapons.staff),
        },
        .knight => switch (subtype) {
            .normal => usePrefab(prefabs.commons.weapons.knights_claymore),
        },
    };

    const lifetime_scale_amount: f32 = switch (archetype) {
        .minion => 1,
        .brute => 1.25,
        .angler => 20,
        .tank => 3,
        .shaman => 7.5,
        .knight => 2,
    };
    const attack_speed_scale_amount: f32 = @as(f32, 4) + @as(f32, switch (archetype) {
        .minion => 1.5,
        .brute => 3,
        .angler => 1,
        .tank => 5,
        .shaman => 40,
        .knight => 2,
    });

    weapon.weapon_light.projectile_lifetime *= lifetime_scale_amount;
    weapon.weapon_heavy.projectile_lifetime *= lifetime_scale_amount;
    weapon.weapon_dash.projectile_lifetime *= lifetime_scale_amount;

    weapon.attack_speed *= attack_speed_scale_amount;

    weapon.weapon_light.sprite = "sprites/projectiles/enemy/generic/light.png";

    return weapon;
}

pub fn spawnWithIndicator(
    archetype: conf.EnemyArchetypes,
    subtype: conf.EnemySubtypes,
    at: e.Vector2,
    delay: f64,
) !void {
    const spawn_display = try quickspawn.spawn(e.Entity{
        .id = ".",
        .tags = ".",
        .transform = .{
            .position = at,
        },
        .display = .{
            .layer = .spawners,
            .scaling = .pixelate,
            // TODO: add sprite
            .sprite = "sprites/backgrounds/enemy_spawn.png",
        },
    });

    try tm.setTimeout(
        (struct {
            pub fn callback(args: TMType.ARGSTYPE) !void {
                quickspawn.destruct(args.spawn_display);

                try spawnArchetype(
                    args.archetype,
                    args.subtype,
                    args.at,
                );
            }
        }).callback,
        .{
            .archetype = archetype,
            .subtype = subtype,
            .at = at,
            .spawn_display = spawn_display,
        },
        delay,
    );
}
