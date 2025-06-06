const std = @import("std");
const Allocator = @import("std").mem.Allocator;
const loom = @import("root.zig");
const builtin = @import("builtin");
const rl = @import("raylib");

pub const Renderer = struct {
    texture: rl.Texture,
    transform: loom.Transform,
    display: struct {
        img_path: []const u8,
        tint: rl.Color,
    },
    entity: ?*loom.Entity = null,
};

const BufferType = std.ArrayList(Renderer);
var buffer: ?BufferType = null;

fn sort(_: void, lsh: Renderer, rsh: Renderer) bool {
    if (lsh.transform.position.z < rsh.transform.position.z) return true;
    return false;
}

pub fn init() void {
    buffer = BufferType.init(loom.allocators.generic());
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
    if (r.transform.scale.equals(loom.vec2()) == 1) return;
    const buf = &(buffer orelse return);

    try buf.append(r);
}

pub fn render() void {
    const buf = &(buffer orelse return);
    std.sort.insertion(Renderer, buf.items, {}, sort);

    for (buf.items) |item| {
        if (builtin.mode == .Debug and loom.window.use_debug_mode) {
            rl.drawRectanglePro(
                loom.Rect(
                    item.transform.position.x - 2,
                    item.transform.position.y - 2,
                    item.transform.scale.x + 4,
                    item.transform.scale.y + 4,
                ),
                loom.Vec2(item.transform.scale.x / 2, item.transform.scale.y / 2),
                item.transform.rotation,
                rl.Color.lime,
            );
            rl.drawRectanglePro(
                loom.Rect(
                    item.transform.position.x,
                    item.transform.position.y,
                    item.transform.scale.x,
                    item.transform.scale.y,
                ),
                loom.Vec2(item.transform.scale.x / 2, item.transform.scale.y / 2),
                item.transform.rotation,
                loom.window.clear_color,
            );

            if (item.entity) |entity| blk: {
                const collider = entity.getComponent(loom.RectangleCollider) orelse break :blk;

                const points = collider.points orelse break :blk;

                rl.drawCircle(loom.toi32(points.A.x), loom.toi32(points.A.y), 2, rl.Color.pink);
                rl.drawCircle(loom.toi32(points.B.x), loom.toi32(points.B.y), 2, rl.Color.pink);
                rl.drawCircle(loom.toi32(points.C.x), loom.toi32(points.C.y), 2, rl.Color.pink);
                rl.drawCircle(loom.toi32(points.D.x), loom.toi32(points.D.y), 2, rl.Color.pink);
            }
        }

        rl.drawTexturePro(
            item.texture,
            loom.Rect(
                0,
                0,
                item.transform.scale.x,
                item.transform.scale.y,
            ),
            loom.Rect(
                item.transform.position.x,
                item.transform.position.y,
                item.transform.scale.x,
                item.transform.scale.y,
            ),
            loom.Vec2(item.transform.scale.x / 2, item.transform.scale.y / 2),
            item.transform.rotation,
            item.display.tint,
        );
    }
}
