const std = @import("std");
const rl = @import("../../main.zig").libs.raylib;

const assets = @import("../../main.zig").libs.assets;
const zap = @import("../../main.zig");

pub fn displayThisString(string: []const u8) void {
    std.log.debug("{s}", .{string});
}

var img_ptr: ?*zap.SharedPointer(rl.Image) = null;
var texture: ?rl.Texture = null;

pub fn awake() !void {
    std.log.debug("Hello from display!", .{});
}

pub fn update() !void {
    rl.beginDrawing();
    defer Blk: {
        rl.endDrawing();
        rl.unloadTexture(texture orelse break :Blk);
        texture = null;
    }

    rl.clearBackground(rl.Color.white);

    if (img_ptr == null) img_ptr = try assets.get.image(
        "./src/assets/small.png",
        zap.Vec2(0, 0),
    );

    const i = img_ptr orelse return;
    texture = rl.loadTextureFromImage(i.ptr.?.*);

    rl.drawTexture(texture.?, 0, 0, rl.Color.white);
}

pub fn tick() !void {
    // std.log.debug("Ticking display!", .{});
}

pub fn deinit() !void {
    (img_ptr orelse return).rmref();
}
