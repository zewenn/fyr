const std = @import("std");
const zap = @import("../../main.zig");
const rl = zap.rl;

var count_game_time = true;
var game_time: f32 = 0;

pub fn pause() void {
    count_game_time = false;
}

pub fn proceed() void {
    count_game_time = true;
}

pub fn init() void {
    game_time = zap.tof32(rl.getTime());
}

pub fn update() void {
    if (!count_game_time) return;
    game_time += rl.getFrameTime();
}

pub inline fn deltaTime() f32 {
    return rl.getFrameTime();
}

pub inline fn appTime() f32 {
    return rl.getTime();
}

pub inline fn gameTime() f32 {
    return game_time;
}
