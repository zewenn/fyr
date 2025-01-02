const std = @import("std");
const zap = @import("../../main.zig");
const rl = zap.rl;
const assets = zap.libs.assets;

pub const Transform = struct {
    const Self = @This();

    position: zap.Vector3 = zap.Vec3(0, 0, 0),
    rotation: f32 = 0,
    scale: zap.Vector2 = zap.Vec2(64, 64),

    pub fn eql(self: Self, other: Self) bool {
        if (self.position.equals(other.position) == 0) return false;
        return eqlSkipPosition(self, other);
    }

    pub fn eqlSkipPosition(self: Self, other: Self) bool {
        if (self.rotation != other.rotation) return false;
        if (self.scale.equals(other.scale) == 0) return false;

        return true;
    }
};

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
            assets.rmref.texture(self.path, i.*);

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

pub const DisplayBehaviour = struct {
    fn awake(store: *zap.Store, cache_ptr: *anyopaque) !void {
        const cache = zap.CacheCast(DCCache, cache_ptr);

        try store.addComonent(cache.base);
        cache.display = store.getComponent(Display);

        cache.transform = store.getComponent(Transform);
        if (cache.transform == null) {
            try store.addComonent(Transform{});
            cache.transform = store.getComponent(Transform);
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
            );
        }

        try store.addComonent(display_cache);
        cache.display_cache = store.getComponent(DisplayCache);
    }

    fn update(_: *zap.Store, cache_ptr: *anyopaque) !void {
        const cache = zap.CacheCast(DCCache, cache_ptr);

        const display_cache = cache.display_cache orelse return;
        const transform = cache.transform orelse return;
        const display = cache.display orelse return;

        const has_to_be_updated = Blk: {
            if (!transform.eqlSkipPosition(display_cache.transform)) break :Blk true;
            if (!std.mem.eql(u8, display.img, display_cache.path)) break :Blk true;
            break :Blk false;
        };

        if (has_to_be_updated) {
            std.log.debug("lol", .{});
            display_cache.free();

            display_cache.* = DisplayCache{
                .path = display.img,
                .transform = transform.*,
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
                );
            }
        }

        const texture = display_cache.texture orelse return;
        rl.drawTexturePro(
            texture.*,
            zap.Rect(0, 0, transform.scale.x, transform.scale.y),
            zap.Rect(transform.position.x, transform.position.y, transform.scale.x, transform.scale.y),
            zap.Vec2(0, 0),
            transform.rotation,
            display.tint,
        );
        // rl.drawTexture(texture.*, 0, 0, rl.Color.white);
    }

    fn deinit(_: *zap.Store, cache_ptr: *anyopaque) !void {
        const cache = zap.CacheCast(DCCache, cache_ptr);
        const c_display_cache = cache.display_cache orelse return;

        c_display_cache.free();
    }

    pub fn behaviour(base: Display) !zap.Behaviour {
        var b = try zap.Behaviour.initWithDefaultValue(DCCache{
            .base = base,
        });

        b.add(.awake, awake);
        b.add(.update, update);
        b.add(.deinit, deinit);

        return b;
    }
}.behaviour;
