const std = @import("std");
const zap = @import(".zap");

const registerScripts = @import("../.temp/script_run.zig").register;

var x: f32 = 10;

const xy = struct {
    x: u8 = 88,
    y: bool = true,
};

pub fn main() !void {
    // const myvec2 = zap.Vec2(false, 120);
    // std.log.debug("{any}", .{myvec2});

    // _ = zap.changeType([]isize, null);

    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer _ = gpa.deinit();

    // const allocator = gpa.allocator();

    // try zap.engine.eventloop.init(allocator);
    // defer zap.engine.eventloop.deinit();

    // try zap.engine.eventloop.SceneAwake(struct {
    //     pub fn callback() !void {
    //         std.log.debug("asdasdasd", .{});

    //         x = 20;
    //     }
    // }.callback);

    // try zap.engine.eventloop.call(zap.engine.eventloop.SceneEvents.awake);

    var myarr = zap.array(xy, .{ xy{}, xy{ .x = 99 } });
    defer myarr.deinit();

    var reversed = try myarr.reverse();
    defer reversed.deinit();

    for (reversed.items) |item| {
        std.debug.print("{any}\n", .{item});
    }
}
