const std = @import("std");
const zap = @import(".zap");

pub fn main() !void {
    const myvec2 = zap.Vec2(false, 120);
    std.log.debug("{any}", .{myvec2});

    _ = zap.changeType([]isize, null);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    try zap.engine.eventloop.init(allocator);
    defer zap.engine.eventloop.deinit();

    try zap.engine.eventloop.Awake(struct {
        pub fn callback() !void {
            std.log.debug("asdasdasd", .{});
        }
    }.callback);

    try zap.engine.eventloop.call(zap.engine.eventloop.SceneEvents.awake);
}
