const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const rl = @import("raylib");
const window = @import("./window.zig");

const zlib = @import("../z/z.m.zig");
const time = @import("../time.m.zig");

const loadf32 = @import("../engine.m.zig").loadf32;

pub var position = rl.Vector2.init(0, 0);
pub var zoom: f32 = 0.75;
pub var last_zoom: f32 = 0.1;

pub var following: ?*rl.Vector2 = null;

pub var apply_shake = true;
pub var shake_freq: f32 = 15;
pub var default_shake_freq: f32 = 15;
pub var shake_strength: f32 = 8;
pub var default_shake_strength: f32 = 8;

pub var trauma: f32 = 0;
pub var recoverySpeed: f32 = 50;

const TMType = time.TimeoutHandler(struct {});
pub var tm: TMType = undefined;

pub var follow_stopped = false;

pub fn follow(vec: *rl.Vector2) void {
    following = vec;
}

pub fn init(allocator: Allocator) void {
    tm = TMType.init(allocator);
}

pub fn deinit() void {
    tm.deinit();
}

pub inline fn resetShakeAfter(after: f64, scale_by_percent: f32) !void {
    shake_freq = default_shake_freq * (1 + scale_by_percent / 100);
    shake_strength = default_shake_strength * (1 + scale_by_percent / 100);
    try tm.setTimeout(
        (struct {
            pub fn callback(_: TMType.ARGSTYPE) !void {
                shake_freq = default_shake_freq;
                shake_strength = default_shake_strength;
            }
        }).callback,
        .{},
        after,
    );
}

pub fn update() void {
    const shake_vec = if (apply_shake) Shake: {
        if (trauma == 0) break :Shake rl.Vector2.init(0, 0);
        const perlin_noise = (zlib.perlin.noise(f32, .{
            .x = loadf32(time.gameTime) * loadf32(shake_freq),
            .y = loadf32(time.gameTime) * loadf32(shake_freq),
        }) * shake_strength - 1) * trauma / recoverySpeed;

        break :Shake rl.Vector2.init(perlin_noise, perlin_noise);
    } else rl.Vector2.init(0, 0);

    if (following) |v| Blk: {
        if (follow_stopped) break :Blk;
        position = v.*.add(shake_vec);
    }

    trauma = @max(0, trauma - recoverySpeed * 2 * time.DeltaTime());
}

pub fn worldPositionToScreenPosition(world_position: rl.Vector2) rl.Vector2 {
    const x = GetX: {
        var _x: f32 = window.size.x / 2;
        _x += world_position.x * zoom;
        _x -= position.x * zoom;
        break :GetX _x;
    };

    const y = GetX: {
        var _y: f32 = window.size.y / 2;
        _y += world_position.y * zoom;
        _y -= position.y * zoom;
        break :GetX _y;
    };

    return rl.Vector2.init(x, y);
}

pub fn screenPositionToWorldPosition(screen_position: rl.Vector2) rl.Vector2 {
    const x = GetX: {
        var _x: f32 = 0;
        _x += screen_position.x / zoom;
        _x += position.x;
        break :GetX _x;
    };

    const y = GetX: {
        var _y: f32 = 0;
        _y += screen_position.y / zoom;
        _y += position.y;
        break :GetX _y;
    };

    return rl.Vector2.init(x, y);
}
