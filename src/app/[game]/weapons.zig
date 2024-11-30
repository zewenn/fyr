const std = @import("std");
const conf = @import("../../config.zig");
const Allocator = @import("std").mem.Allocator;

const e = @import("../../engine/engine.m.zig");

const balancing = @import("balancing.zig");

const TMType = e.time.TimeoutHandler(OnHit);
var tm: TMType = undefined;

pub const OnHit = struct {
    entity: *e.entities.Entity,
    T: conf.Effects,
    delta: f32,
};

pub inline fn applyEffect(
    entity: *e.entities.Entity,
    effect: conf.Effects,
    strength: f32,
) void {
    if (entity.entity_stats == null) return;

    const scaled_strength: f32 = balancing.powerScaleCurve(strength);
    var use_timeout: bool = true;

    var new: f32 = 0;
    var old: f32 = 0;
    var delta: f32 = 0;

    switch (effect) {
        .none => use_timeout = false,
        .healing => {
            use_timeout = false;

            entity.entity_stats.?.health += scaled_strength;
        },
        .energised => {
            use_timeout = true;

            new = e.zlib.math.clamp(
                f32,
                entity.entity_stats.?.movement_speed + scaled_strength * 10,
                -1 * entity.entity_stats.?.max_movement_speed,
                entity.entity_stats.?.max_movement_speed,
            );
            old = entity.entity_stats.?.movement_speed;
            entity.entity_stats.?.movement_speed = new;
            entity.entity_stats.?.is_energised = true;
        },
        .stengthen => {
            use_timeout = true;

            new = entity.entity_stats.?.damage + scaled_strength;
            old = entity.entity_stats.?.damage;
            entity.entity_stats.?.damage = new;
        },
        .slowed => {
            use_timeout = true;

            new = e.zlib.math.clamp(
                f32,
                entity.entity_stats.?.movement_speed - scaled_strength * 5,
                50,
                entity.entity_stats.?.max_movement_speed,
            );
            old = entity.entity_stats.?.movement_speed;
            entity.entity_stats.?.movement_speed = new;
            entity.entity_stats.?.is_slowed = true;
        },
        .rooted => {
            use_timeout = true;

            entity.entity_stats.?.is_rooted = true;
        },
        else => {},
    }

    if (!use_timeout) return;

    delta = new - old;

    tm.setTimeout(
        (struct {
            pub fn callback(args: OnHit) !void {
                if (!e.entities.isValid(args.entity)) return;

                switch (args.T) {
                    .energised => {
                        args.entity.entity_stats.?.movement_speed -= args.delta;
                        if (args.entity.entity_stats.?.movement_speed <= args.entity.entity_stats.?.base_movement_speed)
                            args.entity.entity_stats.?.is_energised = false;
                    },
                    .slowed => {
                        args.entity.entity_stats.?.movement_speed -= args.delta;
                        // if (args.entity.entity_stats.?.movement_speed >= args.entity.entity_stats.?.base_movement_speed)
                        args.entity.entity_stats.?.is_slowed = false;
                    },
                    .stengthen => {
                        args.entity.entity_stats.?.damage -= args.delta;
                    },
                    .rooted => {
                        args.entity.entity_stats.?.is_rooted = false;
                    },
                    else => {},
                }
            }
        }).callback,
        OnHit{
            .entity = entity,
            .T = effect,
            .delta = delta,
        },
        e.zlib.math.clamp(
            f64,
            strength / 100,
            0.5,
            2,
        ),
    ) catch {};
}

pub const Hands = struct {
    const hit_types = enum {
        light,
        heavy,
        dash,
    };

    const ANIM_TIME_MODIFIER = 1.5;

    const Self = @This();

    left: *e.entities.Entity,
    right: *e.entities.Entity,
    left_animator: e.Animator,
    right_animator: e.Animator,
    playing_left: bool = false,
    playing_right: bool = false,
    left_base_rotation: f32 = 0,
    right_base_rotation: f32 = 0,
    animation_attack_speed_ration: f32 = 0.8,

    light_hit_anim: []const u8 = "sword_hit_light",
    heavy_hit_anim: []const u8 = "sword_hit_heavy",
    dash_hit_anim: []const u8 = "sword_hit_dash",

    current_weapon: ?*conf.Item = null,

    pub fn init(
        allocator: *Allocator,
        left_hand: *e.entities.Entity,
        right_hand: *e.entities.Entity,
    ) !Self {
        var this = Self{
            .left = left_hand,
            .right = right_hand,
            .left_animator = e.Animator.init(allocator, left_hand),
            .right_animator = e.Animator.init(allocator, right_hand),
        };

        // Sword animation
        SwordAnimation: {
            Right: {
                var light = e.Animator.Animation.init(
                    allocator,
                    "sword_hit_light",
                    e.Animator.interpolation.ease_in_out,
                    0.05,
                );

                _ = light
                    .append(.{ .rotation = 0 })
                    .append(.{ .rotation = -105 })
                    .append(.{ .rotation = 0 })
                    .close();

                try this.right_animator.chain(light);

                var heavy = e.Animator.Animation.init(
                    allocator,
                    "sword_hit_heavy",
                    e.Animator.interpolation.ease_in_out,
                    0.25,
                );

                _ = heavy
                    .append(.{ .rotation = 0 })
                    .append(.{ .rotation = -180 })
                    .append(.{ .rotation = 0 })
                    .close();

                try this.right_animator.chain(heavy);

                var dash = e.Animator.Animation.init(
                    allocator,
                    "sword_hit_dash",
                    e.Animator.interpolation.ease_in_out,
                    0.25,
                );

                _ = dash
                    .append(.{ .rotation = 0, .ry = 0 })
                    .append(.{ .ry = 24, .rotation = -60 })
                    .append(.{ .ry = 128, .rx = -1 * right_hand.transform.scale.x / 2, .rotation = -60 })
                    .append(.{ .ry = 0, .rotation = 0 })
                    .close();

                try this.right_animator.chain(dash);
                break :Right;
            }

            break :SwordAnimation;
        }
        // Polearm animation
        PolearmAnimation: {
            Right: {
                var light = e.Animator.Animation.init(
                    allocator,
                    "polearm_hit_light",
                    e.Animator.interpolation.ease_in_out,
                    0.15,
                );

                _ = light
                    .append(.{ .rotation = 0, .ry = 0, .rx = 0 })
                    .append(.{ .rotation = -10, .ry = 48, .rx = 24 })
                    .append(.{ .rotation = 0, .ry = 0, .rx = 0 })
                    .close();

                try this.right_animator.chain(light);

                var heavy = e.Animator.Animation.init(
                    allocator,
                    "polearm_hit_heavy",
                    e.Animator.interpolation.ease_in_out,
                    0.35,
                    // 5,
                );

                _ = heavy
                    .append(.{ .rotation = 0, .ry = 0, .rx = 0 })
                    .append(.{ .rotation = -10, .ry = -24, .rx = -12 })
                    .append(.{ .rotation = -10, .ry = 64, .rx = 24 })
                    .append(.{ .rotation = -10, .ry = 64, .rx = 24 })
                    .append(.{ .rotation = 0, .ry = 0, .rx = 0 })
                    .close();

                try this.right_animator.chain(heavy);

                var dash = e.Animator.Animation.init(
                    allocator,
                    "polearm_hit_dash",
                    e.Animator.interpolation.ease_in_out,
                    0.35,
                    // 5,
                );
                {
                    _ = dash
                        .append(.{ .rotation = 0, .ry = 0, .rx = 0 })
                        .append(.{ .rotation = -10, .ry = -24, .rx = -12 })
                        .append(.{ .rotation = -10, .ry = 64, .rx = 24 })
                        .append(.{ .rotation = -10, .ry = 64, .rx = 24 })
                        .append(.{ .rotation = 0, .ry = 0, .rx = 0 })
                        .close();
                }

                try this.right_animator.chain(dash);
                break :Right;
            }

            break :PolearmAnimation;
        }
        // Daggers animation
        DaggersAnimation: {
            Right: {
                var light = e.Animator.Animation.init(
                    allocator,
                    "daggers_hit_light",
                    e.Animator.interpolation.ease_in_out,
                    0.15,
                    // 2.5,
                );
                {
                    _ = light
                        .append(.{ .rotation = 0, .ry = 0, .rx = 0 })
                        .append(.{ .rotation = 0, .ry = 1, .rx = 0 })
                        .append(.{ .rotation = 10, .ry = 48 })
                        .append(.{ .rotation = 0, .ry = 0, .rx = 0 })
                        .close();
                }

                try this.right_animator.chain(light);

                var heavy = e.Animator.Animation.init(
                    allocator,
                    "daggers_hit_heavy",
                    e.Animator.interpolation.ease_in_out,
                    0.35,
                    // 5,
                );
                {
                    _ = heavy
                        .append(.{ .rotation = 0, .ry = 0, .rx = 0 })
                        .append(.{ .rotation = 0, .ry = 80 })
                        .append(.{ .rotation = 0, .ry = 0, .rx = 0 })
                        .close();
                }

                try this.right_animator.chain(heavy);

                var dash = e.Animator.Animation.init(
                    allocator,
                    "daggers_hit_dash",
                    e.Animator.interpolation.ease_in_out,
                    0.35,
                    // 5,
                );
                {
                    _ = dash
                        .append(.{ .rotation = 0, .ry = 0, .rx = 0 })
                        .append(.{ .ry = -24, .rx = 12, .rotation = -360 })
                        .append(.{ .rotation = 0, .ry = 0, .rx = 0 })
                        .close();
                }

                try this.right_animator.chain(dash);
                break :Right;
            }
            Left: {
                var light = e.Animator.Animation.init(
                    allocator,
                    "daggers_hit_light",
                    e.Animator.interpolation.ease_in_out,
                    0.2,
                );
                {
                    _ = light
                        .append(.{ .rotation = 0, .ry = 0, .rx = 0 })
                        .append(.{ .rotation = -10, .ry = 48, .rx = 0 })
                        .append(.{ .rotation = 0, .ry = 0, .rx = 0 })
                        .close();
                }

                try this.left_animator.chain(light);

                var heavy = e.Animator.Animation.init(
                    allocator,
                    "daggers_hit_heavy",
                    e.Animator.interpolation.ease_in_out,
                    0.35,
                    // 5,
                );
                {
                    _ = heavy
                        .append(.{ .rotation = 0, .ry = 0, .rx = 0 })
                        .append(.{ .rotation = 0, .ry = 80 })
                        .append(.{ .rotation = 0, .ry = 0, .rx = 0 })
                        .close();
                }
                try this.left_animator.chain(heavy);

                var dash = e.Animator.Animation.init(
                    allocator,
                    "daggers_hit_dash",
                    e.Animator.interpolation.ease_in_out,
                    0.35,
                    // 5,
                );

                _ = dash
                    .append(.{ .rotation = 0, .ry = 0, .rx = 0 })
                    .append(.{ .ry = -24, .rx = 12, .rotation = -360 })
                    .append(.{ .rotation = 0, .ry = 0, .rx = 0 })
                    .close();

                try this.left_animator.chain(dash);
                break :Left;
            }

            break :DaggersAnimation;
        }
        // Claymore animation
        Claymore: {
            Right: {
                var light = e.Animator.Animation.init(
                    allocator,
                    "claymore_hit_light",
                    e.Animator.interpolation.ease_in_out,
                    0.5,
                );

                _ = light
                    .append(.{ .rotation = 0, .ry = 0 })
                    .append(.{ .rotation = -360, .ry = 64 })
                    .append(.{ .rotation = -360, .ry = 0 })
                    .close();

                try this.right_animator.chain(light);

                var heavy = e.Animator.Animation.init(
                    allocator,
                    "claymore_hit_heavy",
                    e.Animator.interpolation.ease_out,
                    0.25,
                );

                _ = heavy
                    .append(.{ .rotation = 0, .ry = 0 })
                    .append(.{ .rotation = -360, .ry = 128 })
                    .append(.{ .rotation = -360, .ry = 64 })
                    .append(.{ .rotation = -360, .ry = 0 })
                    .close();

                try this.right_animator.chain(heavy);

                var dash = e.Animator.Animation.init(
                    allocator,
                    "claymore_hit_dash",
                    e.Animator.interpolation.ease_in_out,
                    0.25,
                );

                _ = dash
                    .append(.{ .rotation = 0, .ry = 0 })
                    .append(.{ .ry = 0, .rotation = 180 })
                    .append(.{ .ry = 24, .rotation = -90 })
                    .append(.{ .ry = 24, .rotation = -90 })
                    .append(.{ .ry = 24, .rotation = -90 })
                    .append(.{ .ry = 0, .rotation = 0 })
                    .close();

                try this.right_animator.chain(dash);
                break :Right;
            }

            break :Claymore;
        }
        return this;
    }

    pub fn deinit(self: *Self) void {
        self.left_animator.deinit();
        self.right_animator.deinit();
    }

    pub fn update(self: *Self) void {
        self.left_animator.update();
        self.right_animator.update();

        self.playing_left = self.left_animator.playing.items.len != 0;
        self.playing_right = self.right_animator.playing.items.len != 0;
    }

    pub fn play(
        self: *Self,
        T: hit_types,
    ) !void {
        const id = switch (T) {
            .light => self.light_hit_anim,
            .heavy => self.heavy_hit_anim,
            .dash => self.dash_hit_anim,
        };

        // if (!self.left_animator.isPlaying(id))
        self.left_animator.stop(id);
        try self.left_animator.play(id);

        // if (!self.right_animator.isPlaying(id))
        self.right_animator.stop(id);
        try self.right_animator.play(id);
    }

    pub fn equip(self: *Self, item: *conf.Item) void {
        const reset = Get: {
            if (self.current_weapon == null) break :Get false;
            if (self.current_weapon.?.id != item.id) break :Get false;

            break :Get true;
        };

        if (reset) return;

        self.current_weapon = item;

        self.left.display.sprite = item.weapon_sprite_left;
        self.right.display.sprite = item.weapon_sprite_right;

        switch (item.weapon_type) {
            .sword => {
                self.right.transform.scale = e.Vec2(48, 96);
                self.left.transform.scale = e.Vec2(0, 0);

                self.right_base_rotation = 60;

                self.light_hit_anim = "sword_hit_light";
                self.heavy_hit_anim = switch (item.rarity) {
                    .common => "sword_hit_light",
                    else => "sword_hit_heavy",
                };
                self.dash_hit_anim = switch (item.rarity) {
                    .legendary => "sword_hit_dash",
                    else => "sword_hit_light",
                };
            },
            .polearm => {
                self.right.transform.scale = e.Vec2(48, 128);
                self.left.transform.scale = e.Vec2(0, 0);

                self.right_base_rotation = 10;

                self.light_hit_anim = "polearm_hit_light";
                self.heavy_hit_anim = switch (item.rarity) {
                    .common => "polearm_hit_light",
                    else => "polearm_hit_heavy",
                };
                self.dash_hit_anim = switch (item.rarity) {
                    .legendary => "polearm_hit_dash",
                    else => "polearm_hit_light",
                };
            },
            .daggers => {
                self.right.transform.scale = e.Vec2(48, 48);
                self.left.transform.scale = e.Vec2(48, 48);

                self.right_base_rotation = -10;
                self.left_base_rotation = 10;

                self.light_hit_anim = "daggers_hit_light";
                self.heavy_hit_anim = switch (item.rarity) {
                    .common => "daggers_hit_light",
                    else => "daggers_hit_heavy",
                };
                self.dash_hit_anim = switch (item.rarity) {
                    .legendary => "daggers_hit_dash",
                    else => "daggers_hit_light",
                };
            },
            .claymore => {
                self.right.transform.scale = e.Vec2(48, 192);
                self.left.transform.scale = e.Vec2(0, 0);

                self.right_base_rotation = 85;

                self.light_hit_anim = "claymore_hit_light";
                self.heavy_hit_anim = switch (item.rarity) {
                    .common => "claymore_hit_light",
                    else => "claymore_hit_heavy",
                };
                self.dash_hit_anim = switch (item.rarity) {
                    .legendary => "claymore_hit_dash",
                    else => "claymore_hit_light",
                };
            },
            .special => {},
        }

        if (self.left_animator.animations.getPtr(self.light_hit_anim)) |anim| {
            anim.transition_time = @max(0.2, item.attack_speed * item.weapon_light.attack_speed_modifier * self.animation_attack_speed_ration * ANIM_TIME_MODIFIER);
            // std.log.info("tt: {d}", .{anim.transition_time});
        }
        if (self.right_animator.animations.getPtr(self.light_hit_anim)) |anim| {
            anim.transition_time = @max(0.2, item.attack_speed * item.weapon_light.attack_speed_modifier * self.animation_attack_speed_ration * ANIM_TIME_MODIFIER);
        }

        if (!std.mem.eql(u8, self.heavy_hit_anim, self.light_hit_anim)) {
            if (self.left_animator.animations.getPtr(self.heavy_hit_anim)) |anim| {
                anim.transition_time = item.attack_speed * item.weapon_heavy.attack_speed_modifier * self.animation_attack_speed_ration * ANIM_TIME_MODIFIER;
            }
            if (self.right_animator.animations.getPtr(self.heavy_hit_anim)) |anim| {
                anim.transition_time = item.attack_speed * item.weapon_heavy.attack_speed_modifier * self.animation_attack_speed_ration * ANIM_TIME_MODIFIER;
            }
        }

        if (!std.mem.eql(u8, self.dash_hit_anim, self.light_hit_anim)) {
            if (self.left_animator.animations.getPtr(self.dash_hit_anim)) |anim| {
                anim.transition_time = item.attack_speed * item.weapon_dash.attack_speed_modifier * self.animation_attack_speed_ration * ANIM_TIME_MODIFIER;
            }
            if (self.right_animator.animations.getPtr(self.dash_hit_anim)) |anim| {
                anim.transition_time = item.attack_speed * item.weapon_dash.attack_speed_modifier * self.animation_attack_speed_ration * ANIM_TIME_MODIFIER;
                // anim.transition_time = item.attack_speed * item.weapon_dash.attack_speed_modifier * self.animation_attack_speed_ration * 10;
            }
        }
    }
};

pub fn awake() !void {
    tm = TMType.init(e.ALLOCATOR);
}

pub fn init() !void {}

pub fn update() !void {
    try tm.update();
}

pub fn deinit() !void {
    tm.deinit();
}
