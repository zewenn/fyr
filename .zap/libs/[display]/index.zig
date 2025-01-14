const std = @import("std");
const Allocator = @import("std").mem.Allocator;
const zap = @import("../../main.zig");
const rl = zap.rl;

pub const Renderer = struct {
    texture: rl.Texture,
    transform: zap.Transform,
    display: zap.Display,
};

const BufferType = std.ArrayList(Renderer);
var buffer: ?BufferType = null;

fn sort(_: void, lsh: Renderer, rsh: Renderer) bool {
    if (lsh.transform.position.z < rsh.transform.position.z) return true;
    return false;
}

pub fn init() void {
    buffer = BufferType.init(zap.getAllocator(.gpa));
}

pub fn reset() void {
    const buf = &(buffer orelse return);
    buf.clearAndFree();
}

pub fn deinit() void {
    const buf = &(buffer orelse return);
    buf.deinit();
}

pub fn add(r: Renderer) !void {
    const buf = &(buffer orelse return);

    try buf.append(r);
}

pub fn render() void {
    const buf = &(buffer orelse return);
    std.sort.insertion(Renderer, buf.items, {}, sort);

    for (buf.items) |item| {
        rl.drawTexturePro(
            item.texture,
            zap.Rect(
                0,
                0,
                item.transform.scale.x,
                item.transform.scale.y,
            ),
            zap.Rect(
                item.transform.position.x,
                item.transform.position.y,
                item.transform.scale.x,
                item.transform.scale.y,
            ),
            zap.Vec2(item.transform.scale.x / 2, item.transform.scale.y / 2),
            item.transform.rotation,
            item.display.tint,
        );
    }
}
