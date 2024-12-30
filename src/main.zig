const std = @import("std");
const zap = @import(".zap");

const MovementBehaviour = @import("./components/MoveBehaviour.zig").MovementBehaviour;
const Player = @import("./prefabs/Player.zig").Player;

// const registerScripts = @import("../.temp/script_run.zig").register;
// const filenames = @import("../.temp/filenames.zig").Filenames;

// var x: f32 = 10;

// const xy = struct {
//     x: u8 = 88,
//     y: bool = true,
// };

fn operate(arr: zap.WrappedArray(isize)) void {
    for (arr.items) |item| {
        std.log.debug("item: {d}", .{item});
    }
    arr.deinit();
}

pub fn main() !void {
    // operate(zap.array(isize, .{
    //     88,
    //     99,
    //     9.9,
    //     10,
    // }));

    // var arr = zap.array(u8, .{ 8, 9, 10 });
    // defer arr.deinit();

    // var res = try arr.map(f64, struct {
    //     pub fn callback(v: u8) !f64 {
    //         std.log.debug("n: {d}", .{v});
    //         return zap.changeType(f64, v).?;
    //     }
    // }.callback);
    // defer res.deinit();

    try zap.init();
    defer zap.deinit();

    // std.log.debug("{any}", .{filenames});

    var test_instance = try zap.libs.eventloop.new("test");
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
        try test_instance.on(zap.libs.eventloop.Events.tick, .{
            .fn_ptr = struct {
                pub fn callback() !void {
                    std.log.debug("tick", .{});
                }
            }.callback,
            .on_fail = .ignore,
        });
    }

    var test_2_instance = try zap.libs.eventloop.new("test2");
    {
        try test_2_instance.on(zap.libs.eventloop.Events.tick, .{
            .fn_ptr = struct {
                pub fn callback() !void {
                    std.log.debug("tick2", .{});
                }
            }.callback,
            .on_fail = .ignore,
        });
    }

    try zap.libs.eventloop.setActive("test");
    try zap.libs.eventloop.execute();

    try zap.instance().addStore(try Player());

    const Pref: ?*zap.Store = zap.instance().getStoreById("Player");
    zap.assert("Pref is not null", Pref != null);

    zap.loop();
}
