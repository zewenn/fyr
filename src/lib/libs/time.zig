const std = @import("std");
const rl = @import("raylib");
const tof32 = @import("../main.zig").tof32;

var count_game_time = true;
var game_time: f32 = 0;

pub fn pause() void {
    count_game_time = false;
}

pub fn proceed() void {
    count_game_time = true;
}

pub fn init() void {
    game_time = tof32(rl.getTime());
}

pub fn update() void {
    if (!count_game_time) return;
    game_time += rl.getFrameTime();
}

pub inline fn deltaTime() f32 {
    return rl.getFrameTime();
}

pub inline fn deltaTimeVector2() rl.Vector2 {
    return rl.Vector2.init(deltaTime(), deltaTime());
}

pub inline fn deltaTimeVector3() rl.Vector3 {
    return rl.Vector3.init(deltaTime(), deltaTime(), deltaTime());
}

pub inline fn appTime() f32 {
    return rl.getTime();
}

pub inline fn gameTime() f32 {
    return game_time;
}
