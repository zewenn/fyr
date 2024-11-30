const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const conf = @import("../../config.zig");

const e = @import("../../engine/engine.m.zig");

pub const EffectShower = struct {
    entity: e.Entity,
    animator: e.Animator = undefined,
};

const manager = e.zlib.HeapManager(EffectShower, (struct {
    pub fn callback(alloc: Allocator, item: *EffectShower) !void {
        e.entities.remove(item.entity.id);

        alloc.free(item.entity.id);
        alloc.free(item.entity.effect_shower_stats.?.bound_entity_id);
        item.entity.deinit();

        item.animator.deinit();
    }
}).callback);

const ANIMS = struct {
    pub const INVULNERABLE = "invulnerable_anim";
    pub const HEALING = "healing_anim";
    pub const ENERGISED = "energised_anim";
    pub const SLOWED = "slowed_anim";
    pub const ROOTED = "rooted_anim";
    pub const STUNNED = "stunned_anim";
    pub const ASLEEP = "asleep_anim";
};

pub fn awake() !void {
    manager.init(e.ALLOCATOR);
}

pub fn init() !void {}

pub fn update() !void {
    const entities = try e.entities.all();
    defer e.entities.alloc.free(entities);

    try setKeepAlive(false);

    EntityLoop: for (entities) |entity| {
        const estats: *conf.EntityStats = if (entity.entity_stats) |*t| t else continue;

        if (!(
        //
            estats.is_invalnureable or
            estats.is_healing or
            estats.is_energised or
            //
            estats.is_slowed or
            estats.is_rooted or
            estats.is_stunned or
            estats.is_asleep
        //
        ))
            continue;

        const items = try manager.items();
        defer manager.alloc.free(items);

        for (items) |item| {
            defer item.animator.update();
            if (!std.mem.eql(u8, entity.id, item.entity.effect_shower_stats.?.bound_entity_id)) continue;

            try setShowerTo(&(item.entity), entity, &(item.animator));

            continue :EntityLoop;
        }

        // No matches found so far

        const new_item = try new(entity.id);

        try setShowerTo(&(new_item.entity), entity, &(new_item.animator));
    }

    try removeDead();
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

pub fn new(entity_id: []const u8) !*EffectShower {
    const id = try e.UUIDV7();

    const New = e.entities.Entity{
        .id = id,
        .tags = "projectile",
        .transform = .{},
        .display = .{
            .scaling = .pixelate,
            .sprite = e.MISSINGNO,
            .layer = .showers,
        },
        .effect_shower_stats = .{
            .bound_entity_id = try e.ALLOCATOR.dupe(u8, entity_id),
        },
    };

    const NewPtr = try manager.appendReturn(EffectShower{
        .entity = New,
    });

    var Animator = e.Animator.init(&e.ALLOCATOR, &(NewPtr.entity));
    {
        var invlunerable_anim = e.Animator.Animation.init(
            &e.ALLOCATOR,
            ANIMS.INVULNERABLE,
            e.Animator.interpolation.lerp,
            0.42,
        );
        {
            _ = invlunerable_anim
                .append(.{ .d1f32 = 0, .sprite = "sprites/effects/invulnerable/anim_0.png" })
                .append(.{ .d1f32 = -8, .sprite = "sprites/effects/invulnerable/anim_1.png" })
                .append(.{ .d1f32 = -16, .sprite = "sprites/effects/invulnerable/anim_2.png" })
                .append(.{ .d1f32 = 0, .sprite = "sprites/effects/invulnerable/anim_3.png" })
                .append(.{ .d1f32 = 8, .sprite = "sprites/effects/invulnerable/anim_4.png" })
                .append(.{ .d1f32 = 0, .sprite = "sprites/effects/invulnerable/anim_5.png" })
                .close();
        }
        try Animator.chain(invlunerable_anim);

        var healing_anim = e.Animator.Animation.init(
            &e.ALLOCATOR,
            ANIMS.HEALING,
            e.Animator.interpolation.lerp,
            0.21,
        );
        {
            _ = healing_anim
                .append(.{ .d1f32 = 0, .sprite = "sprites/effects/healing/anim_0.png" })
                .append(.{ .d1f32 = -8, .sprite = "sprites/effects/healing/anim_1.png" })
                .append(.{ .d1f32 = 0, .sprite = "sprites/effects/healing/anim_0.png" })
                .close();
        }
        try Animator.chain(healing_anim);

        var energised_anim = e.Animator.Animation.init(
            &e.ALLOCATOR,
            ANIMS.ENERGISED,
            e.Animator.interpolation.lerp,
            0.21,
        );
        {
            _ = energised_anim
                .append(.{ .d1f32 = 0, .sprite = "sprites/effects/energised/anim_0.png" })
                .append(.{ .d1f32 = -8, .sprite = "sprites/effects/energised/anim_1.png" })
                .append(.{ .d1f32 = 0, .sprite = "sprites/effects/energised/anim_0.png" })
                .close();
        }
        try Animator.chain(energised_anim);

        var slowed_anim = e.Animator.Animation.init(
            &e.ALLOCATOR,
            ANIMS.SLOWED,
            e.Animator.interpolation.lerp,
            0.21,
        );
        {
            _ = slowed_anim
                .append(.{ .d1f32 = 0, .sprite = "sprites/effects/slowed/anim_0.png" })
                .append(.{ .d1f32 = -8, .sprite = "sprites/effects/slowed/anim_1.png" })
                .append(.{ .d1f32 = 0, .sprite = "sprites/effects/slowed/anim_0.png" })
                .close();
        }
        try Animator.chain(slowed_anim);

        var rooted_anim = e.Animator.Animation.init(
            &e.ALLOCATOR,
            ANIMS.ROOTED,
            e.Animator.interpolation.lerp,
            0.21,
        );
        {
            _ = rooted_anim
                .append(.{ .d1f32 = 0, .sprite = "sprites/effects/rooted/anim_0.png" })
                .append(.{ .d1f32 = -8, .sprite = "sprites/effects/rooted/anim_1.png" })
                .append(.{ .d1f32 = 0, .sprite = "sprites/effects/rooted/anim_0.png" })
                .close();
        }
        try Animator.chain(rooted_anim);

        var stunned_anim = e.Animator.Animation.init(
            &e.ALLOCATOR,
            ANIMS.STUNNED,
            e.Animator.interpolation.lerp,
            0.35,
        );
        {
            _ = stunned_anim
                .append(.{ .d1f32 = 0, .sprite = "sprites/effects/stunned/anim_0.png" })
                .append(.{ .d1f32 = -8, .sprite = "sprites/effects/stunned/anim_1.png" })
                .append(.{ .d1f32 = -16, .sprite = "sprites/effects/stunned/anim_2.png" })
                .append(.{ .d1f32 = 0, .sprite = "sprites/effects/stunned/anim_3.png" })
                .append(.{ .d1f32 = 8, .sprite = "sprites/effects/stunned/anim_0.png" })
                .close();
        }
        try Animator.chain(stunned_anim);

        var asleep_anim = e.Animator.Animation.init(
            &e.ALLOCATOR,
            ANIMS.ASLEEP,
            e.Animator.interpolation.lerp,
            0.21,
        );
        {
            _ = asleep_anim
                .append(.{ .d1f32 = 0, .sprite = "sprites/effects/asleep/anim_0.png" })
                .append(.{ .d1f32 = -8, .sprite = "sprites/effects/asleep/anim_1.png" })
                .append(.{ .d1f32 = 0, .sprite = "sprites/effects/asleep/anim_0.png" })
                .close();
        }
        try Animator.chain(asleep_anim);
    }

    NewPtr.animator = Animator;

    try e.entities.append(&(NewPtr.entity));

    return NewPtr;
}

pub fn setKeepAlive(to: bool) !void {
    const items = try manager.items();
    defer manager.alloc.free(items);

    for (items) |item| {
        // Removing junk if it somehow ended up in the manager

        if (item.entity.effect_shower_stats == null) {
            manager.remove(item);
            continue;
        }

        item.entity.effect_shower_stats.?.keep_alive = to;
    }
}

pub fn removeDead() !void {
    const items = try manager.items();
    defer manager.alloc.free(items);

    for (items) |item| {
        // Removing junk if it somehow ended up in the manager

        if (item.entity.effect_shower_stats == null) {
            manager.remove(item);
            continue;
        }

        if (item.entity.effect_shower_stats.?.keep_alive) continue;

        manager.removeFreeId(item);
    }
}

fn setShowerTo(item: *e.Entity, entity: *e.Entity, animator: *e.Animator) !void {
    item.transform.position = entity.transform.position;
    item.effect_shower_stats.?.keep_alive = true;

    const istats: *conf.EntityStats = if (entity.entity_stats) |*i| i else return;

    if (istats.is_invalnureable) {
        try playAnim(ANIMS.INVULNERABLE, animator);
        return;
    }

    if (istats.is_healing) {
        try playAnim(ANIMS.HEALING, animator);
        return;
    }

    if (istats.is_energised) {
        try playAnim(ANIMS.ENERGISED, animator);
        return;
    }
    if (istats.is_asleep) {
        try playAnim(ANIMS.ASLEEP, animator);
        return;
    }

    if (istats.is_stunned) {
        try playAnim(ANIMS.STUNNED, animator);
        return;
    }

    if (istats.is_rooted) {
        try playAnim(ANIMS.ROOTED, animator);
        return;
    }

    if (istats.is_slowed) {
        try playAnim(ANIMS.SLOWED, animator);
        return;
    }
}

fn playAnim(anim: []const u8, animator: *e.Animator) !void {
    if (animator.isPlaying(anim)) return;
    stopAllAnims(animator);

    try animator.play(anim);
}

fn stopAllAnims(animator: *e.Animator) void {
    animator.stop(ANIMS.INVULNERABLE);
    animator.stop(ANIMS.HEALING);
    animator.stop(ANIMS.ENERGISED);
    animator.stop(ANIMS.SLOWED);
    animator.stop(ANIMS.ROOTED);
    animator.stop(ANIMS.STUNNED);
    animator.stop(ANIMS.ASLEEP);
}
