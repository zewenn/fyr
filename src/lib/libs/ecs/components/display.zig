const std = @import("std");
const fyr = @import("../../../main.zig");
const rl = fyr.rl;
const assets = fyr.assets;

const Transform = @import("../components.zig").Transform;
const Child = @import("children.zig").Child;
const EntityRef = @import("children.zig").EntityRef;

pub const Display = struct {
    img: []const u8,
    tint: rl.Color = rl.Color.white,
};

pub const DisplayCache = struct {
    const Self = @This();

    transform: Transform,
    path: []const u8,
    texture: ?*rl.Texture = null,

    pub fn free(self: *Self) void {
        if (self.texture != null)
            assets.texture.release(
                self.path,
                .{ self.transform.scale.x, self.transform.scale.y },
            );
    }
};

pub const Renderer = struct {
    pub const FYR_BEHAVIOUR = {};
    const Self = @This();

    base: Display,
    display: ?*Display = null,
    transform: ?*Transform = null,
    display_cache: ?*DisplayCache = null,
    is_child: bool = false,
    parent: ?*Transform = null,

    pub fn init(args: Display) Self {
        return Self{
            .base = args,
        };
    }

    pub fn Awake(self: *Self, entity: *fyr.Entity) !void {
        try entity.addComonent(self.base);
        self.display = entity.getComponent(Display);

        const display = self.display.?;

        const display_cache = DisplayCache{
            .path = display.img,
            .transform = Transform{},
            .texture = assets.texture.get(
                display.img,
                .{ 0, 0 },
            ),
        };

        try entity.addComonent(display_cache);
        self.display_cache = entity.getComponent(DisplayCache);
    }

    pub fn Start(self: *Self, entity: *fyr.Entity) !void {
        if (entity.getComponent(Child)) |child_component| {
            self.parent = child_component.parent.ptr.?.getComponent(Transform);
        }

        if (entity.getComponent(Transform)) |transform| {
            self.transform = transform;
        }
    }

    pub fn Update(self: *Self, _: *fyr.Entity) !void {
        const display_cache = self.display_cache orelse return;
        const transform = self.transform orelse return;
        const display = self.display orelse return;

        if (transform.scale.x == 0 or transform.scale.y == 0) return;

        const has_to_be_updated = Blk: {
            if (transform.scale.equals(display_cache.transform.scale) == 0) break :Blk true;
            if (!std.mem.eql(u8, display.img, display_cache.path)) break :Blk true;
            break :Blk false;
        };

        if (has_to_be_updated) {
            display_cache.free();

            display_cache.* = DisplayCache{
                .path = display.img,
                .transform = transform.*,
                .texture = assets.texture.get(
                    display.img,
                    .{ transform.scale.x, transform.scale.y },
                ),
            };
        }

        const texture = display_cache.texture orelse return;
        try fyr.display.add(.{
            .texture = texture.*,
            .transform = Transform{
                .position = transform.*.position.add(
                    if (self.parent) |parent|
                        parent.position
                    else
                        fyr.vec3(),
                ),
                .rotation = transform.*.rotation,
                .scale = transform.*.scale,
            },
            .display = display.*,
        });
    }

    pub fn End(self: *Self, _: *fyr.Entity) !void {
        const display_cache = self.display_cache orelse return;
        display_cache.free();
    }
};
