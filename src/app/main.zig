const std = @import("std");
const zap = @import(".zap");

const registerScripts = @import("../.temp/script_run.zig").register;

var x: f32 = 10;

const xy = struct {
    x: u8 = 88,
    y: bool = true,
};

fn operate(arr: zap.WrappedArray(isize)) void {
    for (arr.items) |item| {
        std.log.debug("item: {d}", .{item});
    }
    arr.deinit();
}

pub fn main() !void {
    operate(zap.array(isize, .{
        88,
        99,
        9.9,
        10,
    }));

    try zap.init();
    defer zap.deinit();
}

pub const Behaviour = zap.engine.behaviour{
    .awake = struct {
        pub fn callback() !void {}
    }.callback,

    .tick = struct {
        pub fn callback() !void {}
    }.callback,
};
