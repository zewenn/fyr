const std = @import("std");
const conf = @import("../../config.zig");

const e = @import("../../engine/engine.m.zig");

const projectiles = @import("projectiles.zig");
const enemies = @import("enemies.zig");
const dashing = @import("dashing.zig");
const inventory = @import("inventory.zig");
const weapons = @import("weapons.zig");
const spells = @import("spells.zig");
const usePrefab = @import("items.zig").usePrefab;

const levels = @import("levels.zig");

const HAND_DISTANCE: comptime_float = 24;
const HIT_GLOVE_DISTANCE: f32 = 45;
const HIT_PLATES_ROTATION: f32 = 42.5;
const PROJECTILE_LIFETIME: comptime_float = 2;

const WALK_LEFT_0 = "sprites/entity/player" ++ (if (METAL_MODE) "/metal" else "") ++ "/left_0.png";
const WALK_LEFT_1 = "sprites/entity/player" ++ (if (METAL_MODE) "/metal" else "") ++ "/left_1.png";
const WALK_RIGHT_0 = "sprites/entity/player" ++ (if (METAL_MODE) "/metal" else "") ++ "/right_0.png";
const WALK_RIGHT_1 = "sprites/entity/player" ++ (if (METAL_MODE) "/metal" else "") ++ "/right_1.png";

const METAL_MODE = false;

pub var Player = e.entities.Entity{
    .id = "Player",
    .tags = "player",
    .transform = e.entities.Transform.new(),
    .display = .{
        .scaling = .pixelate,
        .sprite = WALK_LEFT_0,
    },
    .shooting_stats = .{
        .timeout = 0.2,
    },
    .collider = .{
        .dynamic = true,
        .rect = e.Rectangle.init(0, 0, 64, 64),
        .weight = 1,
    },

    .entity_stats = .{
        .can_move = true,
        .damage = 10,
    },
    .dash_modifiers = .{
        .dash_time = 0.35,
        .movement_speed_multiplier = 3.5,
    },
};

pub var Hand0 = e.entities.Entity{
    .id = "Hand0",
    .tags = "hand",
    .transform = e.entities.Transform{
        .scale = e.Vec2(48, 48),
    },
    .display = .{
        .scaling = .pixelate,
        .sprite = "sprites/icons/empty.png",
    },
};

pub var Hand1 = e.entities.Entity{
    .id = "Hand1",
    .tags = "hand",
    .transform = e.entities.Transform{
        .position = e.Vec2(0, 64),
        .scale = e.Vec2(96, 256),
    },
    .display = .{
        .scaling = .pixelate,
        .sprite = "sprites/icons/empty.png",
    },
};

var player_animator: e.Animator = undefined;
var hands: weapons.Hands = undefined;

var health_display: *e.GUI.GUIElement = undefined;
var dash_charges_display: *e.GUI.GUIElement = undefined;

// ===================== [Entity] =====================

// =================== [Components] ===================

// ===================== [Others] =====================

var mouse_rotation: f32 = 0;

// ===================== [Events] =====================

pub fn awake() !void {
    try e.entities.append(&Player);

    player_animator = e.Animator.init(&e.ALLOCATOR, &Player);
    {
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
                    .sprite = WALK_LEFT_0,
                },
            )
                .chain(
                50,
                .{
                    .rotation = -5,
                    .sprite = WALK_LEFT_1,
                },
            )
                .chain(
                100,
                .{
                    .rotation = 0,
                    .sprite = WALK_LEFT_0,
                },
            );

            try player_animator.chain(walk_left_anim);
        }
        {
            var walk_right_anim = e.Animator.Animation.init(
                &e.ALLOCATOR,
                "walk_right",
                e.Animator.interpolation.ease_in_out,
                0.25,
                // 5,
            );

            _ = walk_right_anim
                .chain(
                0,
                .{
                    .rotation = 0,
                    .sprite = WALK_RIGHT_0,
                },
            )
                .chain(
                50,
                .{
                    .rotation = 5,
                    .sprite = WALK_RIGHT_1,
                },
            )
                .chain(
                100,
                .{
                    .rotation = 0,
                    .sprite = WALK_RIGHT_0,
                },
            );

            try player_animator.chain(walk_right_anim);
        }
    }

    try e.entities.append(&Hand0);
    try e.entities.append(&Hand1);

    hands = try weapons.Hands.init(
        &e.ALLOCATOR,
        &Hand0,
        &Hand1,
    );

    e.camera.follow(&Player.transform.position);
}

pub fn init() !void {
    health_display = try e.GUI.Text(
        .{
            .id = "player-health-display",
            .style = .{
                .font = .{
                    .size = 22,
                    .shadow = .{
                        .color = e.Colour.dark_green,
                        .offset = e.Vec2(2, 2),
                    },
                },
                .z_index = -1,
                .color = e.Colour.green,
                .translate = .{
                    .x = .center,
                    .y = .center,
                },
                .top = e.GUI.u("30x"),
                .left = e.GUI.u("10w"),
            },
        },
        "Health: 100",
    );
    dash_charges_display = try e.GUI.Text(
        .{
            .id = "player-dash-charges-display",
            .style = .{
                .font = .{
                    .size = 22,
                    .shadow = .{
                        .color = e.Colour.dark_purple,
                        .offset = e.Vec2(2, 2),
                    },
                },
                .z_index = -1,
                .color = e.Colour.gray,
                .translate = .{
                    .x = .center,
                    .y = .center,
                },
                .top = e.GUI.u("60x"),
                .left = e.GUI.u("10w"),
            },
        },
        "Dashes: 0",
    );
}

pub fn update() !void {
    if (e.isKeyDown(.key_seven)) e.display.camera.zoom *= 0.99;
    if (e.isKeyDown(.key_eight)) e.display.camera.zoom *= 1.01;

    if (e.isKeyDown(.key_e)) {
        if (e.isKeyDown(.key_one)) {
            Player.entity_stats.?.health += 0.1;
            Player.entity_stats.?.is_healing = true;
        } else Player.entity_stats.?.is_healing = false;
        if (e.isKeyDown(.key_two)) {
            Player.entity_stats.?.health -= 0.1;
        }
    }

    if (e.isKeyDown(.key_r)) {
        Player.entity_stats.?.is_slowed = e.isKeyDown(.key_one);

        Player.entity_stats.?.is_rooted = e.isKeyDown(.key_two);

        Player.entity_stats.?.is_stunned = e.isKeyDown(.key_three);

        Player.entity_stats.?.is_asleep = e.isKeyDown(.key_four);
    }

    Player.entity_stats.?.health = e.zlib.math.clamp(
        f32,
        Player.entity_stats.?.health,
        0,
        Player.entity_stats.?.max_health,
    );

    if (health_display.is_content_heap) {
        e.zlib.arrays.freeManyItemPointerSentinel(e.ALLOCATOR, health_display.contents.?);
    }

    try inventory.preview.toNamedHeapString(
        health_display,
        "HP",
        Player.entity_stats.?.health / Player.entity_stats.?.max_health * 100,
        true,
    );

    if (dash_charges_display.is_content_heap) {
        e.zlib.arrays.freeManyItemPointerSentinel(
            e.ALLOCATOR,
            dash_charges_display.contents.?,
        );
    }

    try inventory.preview.toNamedHeapString(
        dash_charges_display,
        "Dashes",
        @floatFromInt(Player.dash_modifiers.?.charges_available),
        false,
    );

    if (e.input.ui_mode) return;

    Player.dash_modifiers.?.charges = Player.dash_modifiers.?.base_charges +
        e.loadusize(inventory.equippedbar.get(.dash_charges));

    if (Player.dash_modifiers.?.recharge_end < e.time.gameTime) {
        Player.dash_modifiers.?.charges_available = Player.dash_modifiers.?.charges;
    }

    hands.equip(inventory.equippedbar.current_weapon);

    const mouse_pos = e.input.mouse_position;
    const mouse_relative_pos = e.Vec2(
        mouse_pos.x - e.window.size.x / 2,
        mouse_pos.y - e.window.size.y / 2,
    );

    if (e.input.input_mode == .KeyboardAndMouse) {
        mouse_rotation = std.math.radiansToDegrees(
            std.math.atan2(
                mouse_relative_pos.y,
                mouse_relative_pos.x,
            ),
        );
    }

    var move_vector = e.Vec2(0, 0);
    Input: {
        // @test
        if (e.isKeyPressed(.key_u)) {
            std.log.debug("asd", .{});
            // try levels.loadFromMatrix(
            //     ([_][200]u8{
            //         ([_]u8{1} ** 10) ++ ([_]u8{0} ** 190),
            //     } ++
            //         ([_][200]u8{
            //         ([_]u8{1} ** 1) ++ ([_]u8{0} ** 8) ++ ([_]u8{1} ** 1) ++ ([_]u8{0} ** 190),
            //     } ** 8) ++
            //         [_][200]u8{
            //         ([_]u8{1} ** 10) ++ ([_]u8{0} ** 190),
            //     }) ++
            //         ([_][200]u8{
            //         ([_]u8{0} ** 200),
            //     } ** 190),
            // );
            // try levels.loadFromMatrix(
            //     try e.assets.getJson(
            //         [200][200]u16,
            //         e.ARENA,
            //         "levels/test.json",
            //     ),
            // );
        }

        if (e.isKeyDown(.key_w)) {
            move_vector.y -= 1;
        }
        if (e.isKeyDown(.key_s)) {
            move_vector.y += 1;
        }
        if (e.isKeyDown(.key_a)) {
            move_vector.x -= 1;
        }
        if (e.isKeyDown(.key_d)) {
            move_vector.x += 1;
        }
        if (e.isKeyPressed(.key_f)) KeyF: {
            if (e.isKeyDown(.key_one)) {
                levels.unload();
                break :KeyF;
            }

            if (e.isKeyDown(.key_two)) {
                try levels.startRound();
                break :KeyF;
            }

            try levels.leveldat.load("demo");
            break :KeyF;
            // if (e.isKeyDown(.key_zero)) {
            //     for (0..10) |_| {
            //         try enemies.spawnArchetype(
            //             .brute,
            //             .normal,
            //             e.Vec2(0, 0),
            //         );
            //     }
            // }
            // if (e.isKeyDown(.key_one)) {
            //     try enemies.spawnArchetype(
            //         .minion,
            //         .normal,
            //         e.Vec2(0, 0),
            //     );
            // }
            // if (e.isKeyDown(.key_two)) {
            //     try enemies.spawnArchetype(
            //         .brute,
            //         .normal,
            //         e.Vec2(0, 0),
            //     );
            // }
            // if (e.isKeyDown(.key_three)) {
            //     try enemies.spawnArchetype(
            //         .angler,
            //         .normal,
            //         e.Vec2(0, 0),
            //     );
            // }
            // if (e.isKeyDown(.key_four)) {
            //     try enemies.spawnArchetype(
            //         .tank,
            //         .normal,
            //         e.Vec2(0, 0),
            //     );
            // }
            // if (e.isKeyDown(.key_five)) {
            //     try enemies.spawnArchetype(
            //         .shaman,
            //         .normal,
            //         e.Vec2(0, 0),
            //     );
            // }
            // if (e.isKeyDown(.key_six)) {
            //     try enemies.spawnArchetype(
            //         .knight,
            //         .normal,
            //         e.Vec2(0, 0),
            //     );
            // }
        }
        if (e.isKeyPressed(.key_q) and inventory.equippedbar.spells.q != null) {
            try spells.summon(
                inventory.equippedbar.spells.q.?.*,
                &Player,
                .player,
                Player.entity_stats.?.damage,
            );
        }
        if (e.isKeyPressed(.key_e) and inventory.equippedbar.spells.e != null) {
            try spells.summon(
                inventory.equippedbar.spells.e.?.*,
                &Player,
                .player,
                Player.entity_stats.?.damage,
            );
        }
        if (e.isKeyPressed(.key_r) and inventory.equippedbar.spells.r != null) {
            try spells.summon(
                inventory.equippedbar.spells.r.?.*,
                &Player,
                .player,
                Player.entity_stats.?.damage,
            );
        }
        if (e.isKeyPressed(.key_x) and inventory.equippedbar.spells.x != null) {
            try spells.summon(
                inventory.equippedbar.spells.x.?.*,
                &Player,
                .player,
                Player.entity_stats.?.damage,
            );
        }

        const norm_vector = move_vector.normalize();

        if (Player.entity_stats.?.can_move and
            !Player.entity_stats.?.is_rooted and
            !Player.entity_stats.?.is_stunned and
            !Player.entity_stats.?.is_asleep)
        {
            Player.transform.position.x += norm_vector.x * Player.entity_stats.?.movement_speed * @as(f32, @floatCast(e.time.deltaTime));
            Player.transform.position.y += norm_vector.y * Player.entity_stats.?.movement_speed * @as(f32, @floatCast(e.time.deltaTime));
        }

        if (Player.entity_stats.?.is_stunned or Player.entity_stats.?.is_asleep) break :Input;

        if (e.isKeyPressed(.key_space)) {
            try dashing.applyDash(
                &Player,
                std.math.radiansToDegrees(
                    std.math.atan2(
                        move_vector.y,
                        move_vector.x,
                    ),
                ),
                1,
                true,
            );
        }

        const shoot_angle = switch (e.input.input_mode) {
            .KeyboardAndMouse => mouse_rotation,
            .Keyboard => GetRot: {
                var rot_vector = e.Vec2(0, 0);

                if (e.isKeyDown(.key_up)) {
                    rot_vector.y -= 1;
                }
                if (e.isKeyDown(.key_down)) {
                    rot_vector.y += 1;
                }
                if (e.isKeyDown(.key_left)) {
                    rot_vector.x -= 1;
                }
                if (e.isKeyDown(.key_right)) {
                    rot_vector.x += 1;
                }

                const norm_rot = rot_vector.normalize();
                break :GetRot std.math.radiansToDegrees(
                    std.math.atan2(norm_rot.y, norm_rot.x),
                );
            },
        };

        const shoot = (
        //
            (e.isKeyPressed(.key_up) or
            e.isKeyPressed(.key_down) or
            e.isKeyPressed(.key_left) or
            e.isKeyPressed(.key_right)) and
            e.input.input_mode == .Keyboard
        //
        ) or (
        //
            e.isMouseButtonPressed(.mouse_button_left)
        //
        );

        if (shoot and e.input.input_mode == .Keyboard) {
            mouse_rotation = shoot_angle;
        }

        const shoot_heavy = ((shoot and e.isKeyDown(.key_left_shift)) or
            e.isMouseButtonPressed(.mouse_button_right));

        if (Player.shooting_stats.?.timeout_end >= e.time.gameTime) break :Input;

        if (shoot_heavy) {
            try projectiles.summonMultiple(
                .heavy,
                &Player,
                inventory.equippedbar.current_weapon.*,
                Player.entity_stats.?.damage,
                shoot_angle,
                .player,
            );
            try hands.play(.heavy);

            e.camera.trauma = 40;
            try e.camera.resetShakeAfter(0.25, 10);

            break :Input;
        }

        if (Player.dash_modifiers.?.dash_end + 0.1 >= e.time.gameTime and shoot) {
            try projectiles.summonMultiple(
                .dash,
                &Player,
                inventory.equippedbar.current_weapon.*,
                Player.entity_stats.?.damage,
                shoot_angle,
                .player,
            );
            try hands.play(.dash);

            e.camera.trauma = 45;
            try e.camera.resetShakeAfter(0.25, 15);

            break :Input;
        }

        if (shoot) {
            try projectiles.summonMultiple(
                .light,
                &Player,
                inventory.equippedbar.current_weapon.*,
                Player.entity_stats.?.damage,
                shoot_angle,
                .player,
            );
            try hands.play(.light);

            e.camera.trauma = 30;
            try e.camera.resetShakeAfter(0.25, 5);
        }

        break :Input;
    }

    Animator: {
        player_animator.update();
        hands.update();

        if (move_vector.x < 0 and !player_animator.isPlaying("walk_left")) {
            player_animator.stop("walk_right");
            try player_animator.play("walk_left");

            Player.facing = .left;
        }
        if (move_vector.x > 0 and !player_animator.isPlaying("walk_right")) {
            player_animator.stop("walk_left");
            try player_animator.play("walk_right");

            Player.facing = .right;
        }

        if (move_vector.y == 0) break :Animator;

        if (player_animator.isPlaying("walk_left") or player_animator.isPlaying("walk_right")) break :Animator;

        try player_animator.play(
            switch (Player.facing) {
                .left => "walk_left",
                .right => "walk_right",
            },
        );
    }

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

    const rotation: f32 = mouse_rotation - 90;

    Hand0.transform.position = .{
        .x = Player.transform.position.x,
        .y = Player.transform.position.y,
    };
    Hand0.transform.rotation.z = GetRotation: {
        if (!hands.playing_left) break :GetRotation rotation + hands.left_base_rotation;

        break :GetRotation rotation + Hand0.transform.rotation.z + hands.left_base_rotation;
    };
    Hand1.transform.position = .{
        .x = Player.transform.position.x + 0,
        .y = Player.transform.position.y + 0,
    };
    Hand1.transform.rotation.z = GetRotation: {
        if (!hands.playing_right) break :GetRotation rotation + hands.right_base_rotation;

        break :GetRotation rotation + Hand1.transform.rotation.z + hands.right_base_rotation;
    };
}

pub fn deinit() !void {
    player_animator.deinit();
    hands.deinit();

    e.entities.remove(Player.id);
    Player.deinit();

    if (health_display.is_content_heap) {
        e.zlib.arrays.freeManyItemPointerSentinel(
            e.ALLOCATOR,
            health_display.contents.?,
        );
    }

    if (dash_charges_display.is_content_heap) {
        e.zlib.arrays.freeManyItemPointerSentinel(
            e.ALLOCATOR,
            dash_charges_display.contents.?,
        );
    }
}
