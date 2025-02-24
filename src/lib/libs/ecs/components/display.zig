const std = @import("std");
const fyr = @import("../../../main.zig");
const rl = fyr.rl;
const assets = fyr.assets;

const Transform = @import("../components.zig").Transform;

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

    pub fn new(args: Display) Self {
        return Self{
            .base = args,
        };
    }

    pub fn Awake(self: *Self, entity: *fyr.Entity) !void {
        try entity.addComonent(self.base);
        self.display = entity.getComponent(Display);

        self.transform = entity.getComponent(Transform);
        if (self.transform == null) {
            try entity.addComonent(Transform{});
            self.transform = entity.getComponent(Transform);
        }

        const c_transform = self.transform.?;
        const c_display = self.display.?;

        var display_cache = DisplayCache{
            .path = c_display.img,
            .transform = c_transform.*,
        };

        display_cache.texture = assets.texture.get(
            display_cache.path,
            .{
                c_transform.scale.x,
                c_transform.scale.y,
            },
        );

        try entity.addComonent(display_cache);
        self.display_cache = entity.getComponent(DisplayCache);
    }

    pub fn Update(self: *Self, _: *fyr.Entity) !void {
        const display_cache = self.display_cache orelse return;
        const transform = self.transform orelse return;
        const display = self.display orelse return;

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
            };

            display_cache.texture = assets.texture.get(
                display_cache.path,
                .{
                    transform.scale.x,
                    transform.scale.y,
                },
            );
        }

        const texture = display_cache.texture orelse return;
        try fyr.display.add(.{
            .texture = texture.*,
            .transform = transform.*,
            .display = display.*,
        });
    }

    pub fn Deinit(self: *Self, _: *fyr.Entity) !void {
        const c_display_cache = self.display_cache orelse return;

        c_display_cache.free();
    }
};
