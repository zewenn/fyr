const std = @import("std");
const rl = @import("../../main.zig").libs.raylib;

const assets = @import("../../main.zig").libs.assets;
const zap = @import("../../main.zig");

var img_ptr: ?*rl.Image = null;
var texture: ?*rl.Texture = null;

pub fn awake() !void {
    std.log.debug("Hello from display!", .{});
}

// pub fn update() !void {
//     rl.beginDrawing();
//     defer rl.endDrawing();

//     rl.clearBackground(rl.Color.white);

//     if (img_ptr == null and rl.isKeyPressed(.key_a)) img_ptr = try assets.get.image(
//         "small.png",
//         zap.Vec2(512, 512),
//         45,
//     );

//     if (img_ptr) |iptr| Blk: {
//         if (texture != null) break :Blk;

//         texture = try assets.get.texture("small.png", iptr.*);
//     }

//     if (texture) |t|
//         rl.drawTexture(t.*, 0, 0, rl.Color.white);
// }

pub fn tick() !void {}

pub fn deinit() !void {
    if (texture != null)
        assets.rmref.texture("small.png", img_ptr.?.*);
    if (img_ptr != null)
        assets.rmref.image("small.png", zap.Vec2(512, 512), 45);
}
