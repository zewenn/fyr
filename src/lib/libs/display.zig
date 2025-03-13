const std = @import("std");
const Allocator = @import("std").mem.Allocator;
const fyr = @import("../main.zig");
const rl = @import("raylib");

pub const Renderer = struct {
    texture: rl.Texture,
    transform: fyr.Transform,
    display: fyr.Display,
};

const BufferType = std.ArrayList(Renderer);
var buffer: ?BufferType = null;

fn sort(_: void, lsh: Renderer, rsh: Renderer) bool {
    if (lsh.transform.position.z < rsh.transform.position.z) return true;
    return false;
}

pub fn init() void {
    buffer = BufferType.init(fyr.allocators.generic());
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
        if (fyr.lib_info.build_mode == .Debug and fyr.window.use_debug_lines)
            rl.drawRectanglePro(
                fyr.Rect(
                    item.transform.position.x - 2,
                    item.transform.position.y - 2,
                    item.transform.scale.x + 4,
                    item.transform.scale.y + 4,
                ),
                fyr.Vec2(item.transform.scale.x / 2, item.transform.scale.y / 2),
                item.transform.rotation,
                rl.Color.lime,
            );

        rl.drawTexturePro(
            item.texture,
            fyr.Rect(
                0,
                0,
                item.transform.scale.x,
                item.transform.scale.y,
            ),
            fyr.Rect(
                item.transform.position.x,
                item.transform.position.y,
                item.transform.scale.x,
                item.transform.scale.y,
            ),
            fyr.Vec2(item.transform.scale.x / 2, item.transform.scale.y / 2),
            item.transform.rotation,
            item.display.tint,
        );
    }
}
