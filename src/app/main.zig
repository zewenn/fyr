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

    var arr = zap.array(u8, .{ 8, 9, 10 });
    defer arr.deinit();

    var res = try arr.map(f64, struct {
        pub fn callback(v: u8) !f64 {
            std.log.debug("n: {d}", .{v});
            return zap.changeType(f64, v).?;
        }
    }.callback);
    defer res.deinit();

    try zap.init();
    defer zap.deinit();

    var test_instance = (try zap.libs.eventloop.new(1)).?;
    {
        try test_instance.on(zap.libs.eventloop.Events.awake, .{
            .fn_ptr = struct {
                pub fn callback() !void {
                    std.log.debug("Awoken", .{});
                }
            }.callback,
            .on_fail = .ignore,
        });
        try test_instance.on(zap.libs.eventloop.Events.init, .{
            .fn_ptr = struct {
                pub fn callback() !void {
                    std.log.debug("Inited", .{});
                }
            }.callback,
            .on_fail = .ignore,
        });
    }

    try zap.libs.eventloop.setActive(1);
    try zap.libs.eventloop.execute();

    try zap.loop();
}
