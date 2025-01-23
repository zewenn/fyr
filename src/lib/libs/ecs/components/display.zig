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
    img: ?*rl.Image = null,
    texture: ?*rl.Texture = null,

    pub fn free(self: *Self) void {
        const i = self.img orelse return;

        if (self.texture != null)
            assets.rmref.texture(self.path, i.*, self.transform.rotation);

        assets.rmref.image(
            self.path,
            self.transform.scale,
            self.transform.rotation,
        );
    }
};

const DCCache = struct {
    const Self = @This();

    base: Display,
    display: ?*Display = null,
    transform: ?*Transform = null,
    display_cache: ?*DisplayCache = null,
};

pub const Renderer = struct {
    fn awake(Entity: *fyr.Entity, cache_ptr: *anyopaque) !void {
        const cache = fyr.CacheCast(DCCache, cache_ptr);

        try Entity.addComonent(cache.base);
        cache.display = Entity.getComponent(Display);

        cache.transform = Entity.getComponent(Transform);
        if (cache.transform == null) {
            try Entity.addComonent(Transform{});
            cache.transform = Entity.getComponent(Transform);
        }

        const c_transform = cache.transform.?;
        const c_display = cache.display.?;

        var display_cache = DisplayCache{
            .path = c_display.img,
            .transform = c_transform.*,
        };

        display_cache.img = try assets.get.image(
            display_cache.path,
            display_cache.transform.scale,
            display_cache.transform.rotation,
        );
        if (display_cache.img) |i| {
            display_cache.texture = try assets.get.texture(
                display_cache.path,
                i.*,
                c_transform.rotation,
            );
        }

        try Entity.addComonent(display_cache);
        cache.display_cache = Entity.getComponent(DisplayCache);
    }

    fn update(_: *fyr.Entity, cache_ptr: *anyopaque) !void {
        const cache = fyr.CacheCast(DCCache, cache_ptr);

        const display_cache = cache.display_cache orelse return;
        const transform = cache.transform orelse return;
        const display = cache.display orelse return;

        const has_to_be_updated = Blk: {
            if (!transform.eqlSkipPosition(display_cache.transform)) break :Blk true;
            if (!std.mem.eql(u8, display.img, display_cache.path)) break :Blk true;
            break :Blk false;
        };

        if (has_to_be_updated) {
            display_cache.free();

            display_cache.* = DisplayCache{
                .path = display.img,
                .transform = transform.*,
            };
            display_cache.img = assets.get.image(
                display_cache.path,
                display_cache.transform.scale,
                display_cache.transform.rotation,
            ) catch {
                std.log.err("Image error!", .{});
                return;
            };

            if (display_cache.img) |i| {
                display_cache.texture = assets.get.texture(
                    display_cache.path,
                    i.*,
                    transform.rotation,
                ) catch {
                    std.log.err("Texture error!", .{});
                    return;
                };
            }
        }

        const texture = display_cache.texture orelse return;
        try fyr.display.add(.{
            .texture = texture.*,
            .transform = transform.*,
            .display = display.*,
        });
        // rl.drawTexture(texture.*, 0, 0, rl.Color.white);
    }

    fn deinit(_: *fyr.Entity, cache_ptr: *anyopaque) !void {
        const cache = fyr.CacheCast(DCCache, cache_ptr);
        const c_display_cache = cache.display_cache orelse return;

        c_display_cache.free();
    }

    pub fn behaviour(base: Display) !fyr.Behaviour {
        var b = try fyr.Behaviour.initWithDefaultValue(DCCache{
            .base = base,
        });

        b.add(.awake, awake);
        b.add(.update, update);
        b.add(.deinit, deinit);

        return b;
    }
}.behaviour;
