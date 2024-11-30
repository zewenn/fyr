const std = @import("std");
const Allocator = @import("std").mem.Allocator;

pub const interpolation = @import("interpolation.zig");
const entities = @import("../engine.m.zig").entities;

pub const Keyframe = @import("Keyframe.zig");
pub const Animation = @import("Animation.zig");
pub const Number = interpolation.Number;

const time = @import("../time.m.zig");
const z = @import("../z/z.m.zig");

const loadf32 = @import("../engine.m.zig").loadf32;

const Self = @This();

entity: *entities.Entity,
transform: *entities.Transform,
display: *entities.Display,
dummy: *entities.DummyData,

animations: std.StringHashMap(Animation),
playing: std.ArrayList(*Animation),

alloc: *Allocator,

pub fn init(allocator: *Allocator, entity: *entities.Entity) Self {
    return Self{
        .alloc = allocator,
        .entity = entity,
        .transform = &entity.transform,
        .display = &entity.display,
        .dummy = &entity.dummy_data,
        .animations = std.StringHashMap(Animation).init(allocator.*),
        .playing = std.ArrayList(*Animation).init(allocator.*),
    };
}

pub fn deinit(self: *Self) void {
    var it = self.animations.iterator();
    while (it.next()) |entry| {
        entry.value_ptr.*.deinit();
    }
    self.playing.deinit();
    self.animations.deinit();
}

/// Animations chained to the animator **will be** freed when `.deinit()` is called.
pub fn chain(self: *Self, anim: Animation) !void {
    try self.animations.put(anim.id, anim);
}

pub fn play(self: *Self, id: []const u8) !void {
    const anim = self.animations.getPtr(id);

    const animation = anim orelse return;

    try self.playing.append(animation);

    animation.playing = true;
    animation.current_frame = 0;
    animation.start_time = loadf32(time.gameTime);
    animation.last_frame_at = time.gameTime;
    animation.next_frame_at = time.gameTime + animation.transition_time_ms_per_frame;
}

pub fn isPlaying(self: *Self, id: []const u8) bool {
    const anim = self.animations.getPtr(id);
    if (anim) |a| {
        return a.playing;
    }
    return false;
}

pub fn stop(self: *Self, id: []const u8) void {
    const anim = self.animations.getPtr(id);
    if (anim) |animation| {
        for (self.playing.items, 0..) |item, i| {
            if (!std.mem.eql(u8, item.id, id)) continue;

            _ = self.playing.orderedRemove(i);
            break;
        }
        animation.playing = false;
    }
}

pub fn applyKeyframe(self: *Self, kf: Keyframe) void {
    // === Transform ===

    // Position
    if (kf.x) |v| {
        self.transform.position.x = v;
    }

    if (kf.y) |v| {
        self.transform.position.y = v;
    }

    // Rotation
    if (kf.rx) |v| {
        self.transform.rotation.x = v;
    }

    if (kf.ry) |v| {
        self.transform.rotation.y = v;
    }

    if (kf.rotation) |v| {
        self.transform.rotation.z = v;
    }

    // Scale
    if (kf.width) |v| {
        self.transform.scale.x = v;
    }

    if (kf.height) |v| {
        self.transform.scale.y = v;
    }

    // === Display ===
    if (kf.sprite) |v| {
        self.display.sprite = v;
    }

    if (kf.scaling) |v| {
        self.display.scaling = v;
    }

    if (kf.tint) |v| {
        self.display.tint = @intCast(v.toInt());
    }

    // Dummy
    {
        if (kf.d1f32) |v| {
            self.dummy.d1f32 = v;
        }

        if (kf.d2f32) |v| {
            self.dummy.d2f32 = v;
        }

        if (kf.d3f32) |v| {
            self.dummy.d3f32 = v;
        }

        if (kf.d4f32) |v| {
            self.dummy.d4f32 = v;
        }

        if (kf.d5f32) |v| {
            self.dummy.d5f32 = v;
        }

        if (kf.d6f32) |v| {
            self.dummy.d6f32 = v;
        }

        if (kf.d7f32) |v| {
            self.dummy.d7f32 = v;
        }

        if (kf.d8f32) |v| {
            self.dummy.d8f32 = v;
        }

        if (kf.d1u8) |v| {
            self.dummy.d1u8 = v;
        }

        if (kf.d2u8) |v| {
            self.dummy.d2u8 = v;
        }

        if (kf.d3u8) |v| {
            self.dummy.d3u8 = v;
        }

        if (kf.d4u8) |v| {
            self.dummy.d4u8 = v;
        }

        if (kf.d5u8) |v| {
            self.dummy.d5u8 = v;
        }

        if (kf.d6u8) |v| {
            self.dummy.d6u8 = v;
        }

        if (kf.d7u8) |v| {
            self.dummy.d7u8 = v;
        }

        if (kf.d8u8) |v| {
            self.dummy.d8u8 = v;
        }

        if (kf.d1Color) |v| {
            self.dummy.d1Color = v;
        }

        if (kf.d2Color) |v| {
            self.dummy.d2Color = v;
        }

        if (kf.d3Color) |v| {
            self.dummy.d3Color = v;
        }

        if (kf.d4Color) |v| {
            self.dummy.d4Color = v;
        }
    }
}

pub fn update(self: *Self) void {
    for (self.playing.items) |anim| {
        if (anim.cached_transition_time != anim.transition_time) {
            anim.cached_transition_time = anim.transition_time;
            anim.transition_time_ms_per_frame = anim.transition_time / loadf32(anim.max_frames);
        }

        const current_kf = anim.getCurrent();
        const next_kf = anim.getNext();

        if (next_kf == null and current_kf != null) {
            self.applyKeyframe(current_kf.?);
            continue;
        }

        if (current_kf == null or next_kf == null) continue;

        const curr = current_kf.?;
        const nxt = next_kf.?;

        // (gameTime - startTime) / (
        //         anim.length
        //         * (next_kf_percent + 0.001)
        //     )
        var interpolation_factor = ((loadf32(time.gameTime) - anim.start_time) / (anim.transition_time));
        // var interpolation_factor = (loadf32(time.gameTime) - anim.start_time) / (anim.transition_time);
        // var interpolation_factor = loadf32(loadf32(anim.current_frame) * anim.transition_time_ms_per_frame) / (anim.transition_time);
        interpolation_factor = @max(0, @min(interpolation_factor, 1));

        var percent = (anim.timing_fn(0, 1, interpolation_factor) - (anim.timing_fn(0, 1, (loadf32(anim.current_index) / 100)))) / (anim.timing_fn(0, 1, loadf32(anim.next_index) / 100) - (anim.timing_fn(0, 1, (loadf32(anim.current_index) / 100))));
        percent = @max(0, @min(1, percent));

        self.applyKeyframe(
            anim.interpolateKeyframes(
                curr,
                nxt,
                percent,
            ),
        );

        if (percent == 1) {
            anim.next(interpolation_factor * 100);
            if (!anim.playing) {
                self.stop(anim.id);
                break;
            }

            anim.last_frame_at = time.gameTime;
            anim.next_frame_at = time.gameTime + anim.transition_time_ms_per_frame;
        }
    }
}
