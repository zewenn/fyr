const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const fyr = @import("../../../../main.zig");

pub const t = @import("./types.zig");

pub const Animation = t.Animation;
pub const KeyFrame = t.KeyFrame;

pub const Animator = struct {
    const Self = @This();

    alloc: Allocator,
    alive: bool = false,

    animations: std.StringHashMap(*Animation),
    playing: std.ArrayList(*Animation),

    pub fn init() Self {
        return Self{
            .alloc = fyr.getAllocator(.scene),
            .animations = std.StringHashMap(*Animation).init(fyr.getAllocator(.scene)),
            .playing = std.ArrayList(*Animation).init(fyr.getAllocator(.scene)),
            .alive = true,
        };
    }

    pub fn deinit(self: *Self) void {
        if (!self.alive) return;
        var iterator = self.animations.iterator();
        while (iterator.next()) |item| {
            item.value_ptr.*.deinit();
        }

        self.alive = false;

        self.playing.deinit();
        self.animations.deinit();
    }

    pub fn chain(self: *Self, anim: Animation) !void {
        if (!self.alive) return;

        const ptr = try self.alloc.create(Animation);
        ptr.* = anim;

        try self.animations.put(anim.name, ptr);
    }

    pub fn isPlaying(self: *Self, name: []const u8) bool {
        if (!self.alive) return false;

        const anim = self.animations.get(name) orelse return false;
        return anim.playing;
    }

    pub fn play(self: *Self, name: []const u8) !void {
        if (!self.alive) return;

        const anim = self.animations.get(name) orelse return;
        if (anim.playing) return;

        try self.playing.append(anim);

        anim.playing = true;
        anim.current_percent = 0;
        anim.start_time = fyr.time.gameTime();
    }

    pub fn stop(self: *Self, name: []const u8) void {
        if (!self.alive) return;

        const anim = self.animations.get(name) orelse return;
        if (!anim.playing) return;

        for (self.playing.items, 0..) |item, index| {
            if (item.uuid != anim.uuid) continue;

            _ = self.playing.swapRemove(index);
            break;
        }

        anim.playing = false;
    }
};

pub const AnimatorBehaviour = struct {
    pub const FYR_BEHAVIOUR = {};
    const Self = @This();

    animations: fyr.WrappedArray(Animation),
    animator: ?*Animator = null,
    transform: ?*fyr.Transform = null,
    display: ?*fyr.Display = null,

    pub fn new(arg: fyr.WrappedArray(Animation)) Self {
        return Self{
            .animations = arg,
        };
    }

    pub fn Awake(self: *Self, entity: *fyr.Entity) !void {
        var animator = Animator.init();
        for (self.animations.items) |item| {
            try animator.chain(item);
        }

        self.animations.deinit();

        try entity.addComonent(animator);

        self.animator = entity.getComponent(fyr.Animator) orelse return;
        self.transform = entity.getComponent(fyr.Transform) orelse return;
        self.display = entity.getComponent(fyr.Display) orelse return;
    }

    pub fn Update(self: *Self, _: *fyr.Entity) !void {
        const transform = self.transform orelse return;
        const display = self.display orelse return;
        const animator = self.animator orelse return;

        for (animator.playing.items) |animation| {
            const current = animation.current();
            const next = animation.next();

            const current_keyframe = current orelse continue;

            if (next == null) {
                current_keyframe.apply(transform, display);
                continue;
            }

            const next_keyframe = next orelse continue;

            const interpolation_factor =
                @min(1, @max(0, (fyr.time.gameTime() - fyr.tof32(animation.start_time)) / fyr.tof32(animation.length)));

            const anim_progress_percent = animation.timing_function(0, 1, interpolation_factor);
            const next_index_percent = animation.timing_function(0, 1, fyr.tof32(animation.next_index) / 100);

            const percent = @min(1, @max(0, anim_progress_percent / next_index_percent));

            current_keyframe
                .interpolate(next_keyframe, t.interpolation.lerp, percent)
                .apply(transform, display);

            if (percent != 1) continue;

            animation.incrementCurrentPercent(fyr.toi32(interpolation_factor * 100));
            if (!animation.playing) {
                animator.stop(animation.name);
                break;
            }
        }
    }

    pub fn Deinit(self: *Self, _: *fyr.Entity) !void {
        if (self.animator) |animator| {
            animator.deinit();
        }
    }
};
