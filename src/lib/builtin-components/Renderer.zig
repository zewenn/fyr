const std = @import("std");
const loom = @import("../root.zig");
const rl = loom.rl;
const assets = loom.assets;

const Transform = @import("Transform.zig");

pub const DisplayCache = struct {
    const This = @This();

    transform: Transform,
    img_path: []const u8,
    texture: ?*rl.Texture = null,

    pub fn free(self: *This) void {
        if (self.texture == null) return;

        self.texture = null;
        assets.texture.release(
            self.img_path,
            .{ self.transform.scale.x, self.transform.scale.y },
        );
    }
};

const Self = @This();

img_path: []const u8,
tile_size: ?loom.Vector2 = null,
tint: rl.Color = rl.Color.white,

transform: ?*Transform = null,
display_cache: ?*DisplayCache = null,
is_child: bool = false,
parent: ?*Transform = null,

pub fn init(path: []const u8) Self {
    return Self{
        .img_path = path,
    };
}

pub fn tile(path: []const u8, tile_size: loom.Vector2) Self {
    return Self{
        .img_path = path,
        .tile_size = tile_size,
    };
}

pub fn Awake(self: *Self, entity: *loom.Entity) !void {
    const display_cache = DisplayCache{
        .img_path = self.img_path,
        .transform = Transform{
            .scale = .init(-1, -1),
        },
        .texture = assets.texture.get(
            self.img_path,
            .{ 0, 0 },
        ),
    };

    try entity.addComponent(display_cache);
    self.display_cache = try entity.getComponentUnsafe(DisplayCache).unwrap();
}

pub fn Start(self: *Self, entity: *loom.Entity) !void {
    if (entity.getComponent(Transform)) |transform| {
        self.transform = transform;
    }
}

pub fn Update(self: *Self, entity: *loom.Entity) !void {
    const display_cache: *DisplayCache = try loom.ensureComponent(self.display_cache);
    const transform: *Transform = try loom.ensureComponent(self.transform);

    if (transform.scale.x == 0 or transform.scale.y == 0) return;

    const tile_size = self.tile_size orelse transform.scale;

    const has_to_be_updated =
        transform.scale.equals(display_cache.transform.scale) == 0 or
        !std.mem.eql(u8, self.img_path, display_cache.img_path) or
        display_cache.texture == null;

    if (has_to_be_updated) {
        display_cache.free();

        display_cache.* = DisplayCache{
            .img_path = self.img_path,
            .transform = transform.*,
            .texture = assets.texture.get(
                self.img_path,
                .{ tile_size.x, tile_size.y },
            ),
        };
    }

    const texture = display_cache.texture orelse return;
    try loom.display.add(.{
        .texture = texture.*,
        .transform = Transform{
            .position = transform.*.position.add(
                if (self.parent) |parent|
                    parent.position
                else
                    loom.vec3(),
            ),
            .rotation = transform.*.rotation,
            .scale = transform.*.scale,
        },
        .display = .{
            .img_path = self.img_path,
            .tint = self.tint,
        },
        .entity = entity,
    });
}

pub fn End(self: *Self) !void {
    const display_cache = self.display_cache orelse return;
    display_cache.free();
}
