const std = @import("std");

const entities = @import("../engine.m.zig").entities;
const window = @import("../display/display.m.zig").window;
const z = @import("../z/z.m.zig");

const loadf32 = @import("../engine.m.zig").loadf32;

const Self = @This();

const UnitEnum = enum {
    px,
    unit,
    percent,
    vw,
    vh,
};

value: f32,
unit: UnitEnum,

pub fn init(value: f32, unit: UnitEnum) Self {
    return Self{
        .value = value,
        .unit = unit,
    };
}

pub fn equals(self: *Self, other: Self) bool {
    if (self.unit != other.unit) return false;
    if (self.value != other.value) return false;
    return true;
}

fn getUnitSize() f32 {
    const sw: f32 = 1920;
    const sh: f32 = 1080;

    const w: f32 = switch (window.size.x > window.size.y) {
        true => window.size.y * 16 / 9,
        false => window.size.x,
    };
    const h: f32 = switch (window.size.x < window.size.y) {
        true => window.size.x * 9 / 16,
        false => window.size.y,
    };

    return floorToNearestScalable((w / sw + h / sh) / 2);
}

fn floorToNearestScalable(to_be_rounded: f32) f32 {
    var n: f32 = 1;
    var upper: f32 = 1;
    var lower: f32 = 1;

    if (to_be_rounded == 1) return 1;

    while (!(upper >= to_be_rounded and lower <= to_be_rounded)) {
        n += 1;
        if (1 > to_be_rounded) {
            lower = 1 / n;
            upper = 1 / (n - 1);
        } else {
            lower = n - 1;
            upper = n;
        }
    }

    return lower;
}

pub fn calculate(self: *Self, parent: f32, percent_parent: f32) f32 {
    return switch (self.unit) {
        .px => parent + self.value,
        .unit => parent + self.value * getUnitSize(),
        // .unit => parent + window.size.x * (self.value / 100),
        .percent => parent + percent_parent * (self.value / 100),
        .vw => parent + window.size.x * (self.value / 100),
        .vh => parent + window.size.y * (self.value / 100),
    };
}

/// Parses the given input, if the input is incorrect
/// *(syntax is not `<number><'x' | 'u' | '%' | 'h' | 'w'>`)* returns 0x/0 pixels,
pub fn u(from: []const u8) Self {
    const str_value = from[0 .. from.len - 1];
    const str_unit = from[from.len - 1 ..];

    const unit: UnitEnum = switch (str_unit[0]) {
        'x' => .px,
        'u' => .unit,
        '%' => .percent,
        'h' => .vh,
        'w' => .vw,
        else => .px,
    };

    const float_value = std.fmt.parseFloat(f32, str_value) catch 0;

    return Self{
        .value = float_value,
        .unit = unit,
    };
}

pub fn toUnit(from: anytype) Self {
    const float = if (z.math.f128_to(f32, z.math.to_f128(from).?)) |v| v else 0;

    return Self{
        .value = float,
        .unit = .px,
    };
}
