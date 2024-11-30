const std = @import("std");
const conf = @import("../../config.zig");

const e = @import("../../engine/engine.m.zig");

const BASE: comptime_float = 1005 / 1000;
const POWER_STEP: comptime_float = 5;
const PRICE_STEP: comptime_float = 5.5;
const STEP_DIVIDER: comptime_int = 10;

pub fn powerScaleCurve(x: anytype) f32 {
    const rx = e.loadf32(x);

    return std.math.pow(f32, BASE, rx) + POWER_STEP * @round(rx / STEP_DIVIDER);
}

pub fn priceScaleCurve(x: anytype) f32 {
    const rx = e.loadf32(x);

    return std.math.pow(f32, BASE, rx) + PRICE_STEP * @round(rx / STEP_DIVIDER);
}

pub fn awake() !void {}

pub fn init() !void {}

pub fn update() !void {}

pub fn deinit() !void {}
