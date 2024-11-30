const std = @import("std");
const rl = @import("raylib");
const z = @import("../z/z.m.zig");

pub const Transform = struct {
    const Self = @This();

    position: rl.Vector2 = rl.Vector2.init(0, 0),
    rotation: rl.Vector3 = rl.Vector3.init(0, 0, 0),
    scale: rl.Vector2 = rl.Vector2.init(64, 64),
    anchor: ?rl.Vector2 = null,

    /// Creates a new transform with 64x64 `scale` and everything else set to 0.
    pub fn new() Self {
        return Self{
            .position = rl.Vector2.init(0, 0),
            .rotation = rl.Vector3.init(0, 0, 0),
            .scale = rl.Vector2.init(64, 64),
            .anchor = null,
        };
    }

    pub fn equals(self: *Self, other: Self) bool {
        if (self.position.equals(other.position) > 0) return false;
        if (self.rotation.equals(other.rotation) > 0) return false;
        if (self.scale.equals(other.scale) > 0) return false;

        return true;
    }

    pub fn rotate(self: *Self, by: f32) void {
        const scale = 359 + 360;
        var new_rot: f32 = self.rotation.z + by;

        if (new_rot > 360) {
            const rem: f32 = @rem(new_rot - 360, scale);
            new_rot = @as(f32, -359) + rem;
        }
        if (new_rot < -359) {
            const rem: f32 = @rem(new_rot + 359, scale);
            new_rot = @as(f32, 360) - rem;
        }

        self.rotation.z = new_rot;
    }

    pub fn getRect(self: *Self) rl.Rectangle {
        return rl.Rectangle.init(
            if (self.anchor) |anchor| self.position.x - anchor.x else self.position.x,
            if (self.anchor) |anchor| self.position.y - anchor.y else self.position.y,
            self.scale.x,
            self.scale.y,
        );
    }
};

pub const Display = struct {
    pub const scalings = enum {
        pixelate,
        normal,
    };
    pub const layers = enum(u8) {
        background,
        spawners,
        trail_effects,
        foreground,
        showers,
        walls,
        editor_spawners,
        top,
    };

    sprite: []const u8 = "sprites/missingno.png",
    scaling: scalings = .normal,
    tint: u32 = 0xffffffff,
    ignore_world_pos: bool = false,
    layer: layers = .foreground,

    background_tile_size: ?rl.Vector2 = null,
};

pub const Collider = struct {
    trigger: bool = false,
    rect: rl.Rectangle,
    weight: f32,
    dynamic: bool,
};

pub const CachedDisplay = struct {
    const Self = @This();

    display: Display,
    transform: Transform,
    img: ?rl.Image,
    texture: ?rl.Texture,

    pub fn init(display: Display, transform: Transform, img: rl.Image, texture: rl.Texture) Self {
        return Self{
            .display = display,
            .transform = transform,
            .img = img,
            .texture = texture,
        };
    }
};

pub const RectangleVertices = struct {
    const Self = @This();

    transform: *Transform,

    center: rl.Vector2,
    top_left: rl.Vector2,
    top_right: rl.Vector2,
    bottom_left: rl.Vector2,
    bottom_right: rl.Vector2,
    delta_top_left: rl.Vector2,
    delta_top_right: rl.Vector2,
    delta_bottom_left: rl.Vector2,
    delta_bottom_right: rl.Vector2,

    x_min: f32 = 0,
    x_max: f32 = 0,

    y_min: f32 = 0,
    y_max: f32 = 0,

    pub fn init(transform: *Transform, collider: *Collider) Self {
        const center_point = getCenterPoint(transform, collider);
        const delta_point_top_left = rl.Vector2
            .init(-collider.rect.width / 2, -collider.rect.height / 2)
            .rotate(std.math.degreesToRadians(transform.rotation.z));

        const delta_point_top_right = rl.Vector2
            .init(collider.rect.width / 2, -collider.rect.height / 2)
            .rotate(std.math.degreesToRadians(transform.rotation.z));

        const delta_point_bottom_left = rl.Vector2
            .init(-collider.rect.width / 2, collider.rect.height / 2)
            .rotate(std.math.degreesToRadians(transform.rotation.z));

        const delta_point_bottom_right = rl.Vector2
            .init(collider.rect.width / 2, collider.rect.height / 2)
            .rotate(std.math.degreesToRadians(transform.rotation.z));

        const point_top_left = center_point.add(delta_point_top_left);
        const point_top_right = center_point.add(delta_point_top_right);
        const point_bottom_left = center_point.add(delta_point_bottom_left);
        const point_bottom_right = center_point.add(delta_point_bottom_right);

        const x_min: f32 = @min(
            @min(
                point_top_left.x,
                point_top_right.x,
            ),
            @min(
                point_bottom_left.x,
                point_bottom_right.x,
            ),
        );
        const x_max: f32 = @max(
            @max(
                point_top_left.x,
                point_top_right.x,
            ),
            @max(
                point_bottom_left.x,
                point_bottom_right.x,
            ),
        );

        const y_min: f32 = @min(
            @min(
                point_top_left.y,
                point_top_right.y,
            ),
            @min(
                point_bottom_left.y,
                point_bottom_right.y,
            ),
        );
        const y_max: f32 = @max(
            @max(
                point_top_left.y,
                point_top_right.y,
            ),
            @max(
                point_bottom_left.y,
                point_bottom_right.y,
            ),
        );

        return Self{
            .transform = transform,
            .center = center_point,
            .top_left = point_top_left,
            .top_right = point_top_right,
            .bottom_left = point_bottom_left,
            .bottom_right = point_bottom_right,
            .delta_top_left = delta_point_top_left,
            .delta_top_right = delta_point_top_right,
            .delta_bottom_left = delta_point_bottom_left,
            .delta_bottom_right = delta_point_bottom_right,
            .x_min = x_min,
            .x_max = x_max,
            .y_min = y_min,
            .y_max = y_max,
        };
    }

    pub fn getCenterPoint(transform: *Transform, collider: *Collider) rl.Vector2 {
        return rl.Vector2.init(
            transform.position.x + collider.rect.x + transform.scale.x / 2 - collider.rect.width / 2,
            transform.position.y + collider.rect.y + transform.scale.y / 2 - collider.rect.height / 2,
        );
    }

    pub fn recalculateXYMinMax(self: *Self) void {
        self.x_min = @min(@min(self.top_left.x, self.top_right.x), @min(self.bottom_left.x, self.bottom_right.x));
        self.x_max = @max(@max(self.top_left.x, self.top_right.x), @max(self.bottom_left.x, self.bottom_right.x));
        self.y_min = @min(@min(self.top_left.y, self.top_right.y), @min(self.bottom_left.y, self.bottom_right.y));
        self.y_max = @max(@max(self.top_left.y, self.top_right.y), @max(self.bottom_left.y, self.bottom_right.y));
    }

    pub fn recalculatePoints(self: *Self) void {
        self.top_left = self.center.add(self.delta_top_left);
        self.top_right = self.center.add(self.delta_top_right);
        self.bottom_left = self.center.add(self.delta_bottom_left);
        self.bottom_right = self.center.add(self.delta_bottom_right);
    }

    pub fn overlaps(self: *Self, other: Self) bool {
        if ((self.x_max > other.x_min and self.x_min < other.x_max) and
            (self.y_max > other.y_min and self.y_min < other.y_max))
            return true;
        return false;
    }

    pub fn pushback(a: *Self, b: Self, weight: f32) void {
        const overlap_x = @min(a.x_max - b.x_min, b.x_max - a.x_min);
        const overlap_y = @min(a.y_max - b.y_min, b.y_max - a.y_min);

        switch (overlap_x < overlap_y) {
            true => PushBack_X: {
                if (a.x_max > b.x_min and a.x_max < b.x_max) {
                    a.transform.position.x -= overlap_x * weight;
                    break :PushBack_X;
                }

                a.transform.position.x += overlap_x * weight;
                break :PushBack_X;
            },
            false => PushBack_Y: {
                if (a.y_max > b.y_min and a.y_max < b.y_max) {
                    a.transform.position.y -= overlap_y * weight;
                    break :PushBack_Y;
                }

                a.transform.position.y += overlap_y * weight;
                break :PushBack_Y;
            },
        }
    }
};

pub const DummyData = struct {
    d1f32: f32 = 0,
    d2f32: f32 = 0,
    d3f32: f32 = 0,
    d4f32: f32 = 0,
    d5f32: f32 = 0,
    d6f32: f32 = 0,
    d7f32: f32 = 0,
    d8f32: f32 = 0,

    d1u8: u8 = 0,
    d2u8: u8 = 0,
    d3u8: u8 = 0,
    d4u8: u8 = 0,
    d5u8: u8 = 0,
    d6u8: u8 = 0,
    d7u8: u8 = 0,
    d8u8: u8 = 0,

    d1Color: rl.Color = rl.Color.init(0, 0, 0, 255),
    d2Color: rl.Color = rl.Color.init(0, 0, 0, 255),
    d3Color: rl.Color = rl.Color.init(0, 0, 0, 255),
    d4Color: rl.Color = rl.Color.init(0, 0, 0, 255),
};
