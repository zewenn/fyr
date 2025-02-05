const std = @import("std");
const fyr = @import("../../../main.zig");
const rl = fyr.rl;

const Transform = @import("../components.zig").Transform;

pub const Collider = struct {
    trigger: bool = false,
    rect: rl.Rectangle,
    weight: f32 = 1,
    dynamic: bool,
};

pub const RectangleVertices = struct {
    const Self = @This();

    transform: *Transform,

    center: rl.Vector2,

    delta_top_left: rl.Vector2,
    delta_top_right: rl.Vector2,
    delta_bottom_left: rl.Vector2,
    delta_bottom_right: rl.Vector2,

    top_left: rl.Vector2 = fyr.newVec2(),
    top_right: rl.Vector2 = fyr.newVec2(),
    bottom_left: rl.Vector2 = fyr.newVec2(),
    bottom_right: rl.Vector2 = fyr.newVec2(),

    x_min: f32 = 0,
    x_max: f32 = 0,

    y_min: f32 = 0,
    y_max: f32 = 0,

    pub fn init(transform: *Transform, collider: *Collider) Self {
        const center_point = getCenterPoint(transform, collider);
        const delta_point_top_left = rl.Vector2
            .init(-collider.rect.width / 2, -collider.rect.height / 2)
            .rotate(std.math.degreesToRadians(transform.rotation));

        const delta_point_top_right = rl.Vector2
            .init(collider.rect.width / 2, -collider.rect.height / 2)
            .rotate(std.math.degreesToRadians(transform.rotation));

        const delta_point_bottom_left = rl.Vector2
            .init(-collider.rect.width / 2, collider.rect.height / 2)
            .rotate(std.math.degreesToRadians(transform.rotation));

        const delta_point_bottom_right = rl.Vector2
            .init(collider.rect.width / 2, collider.rect.height / 2)
            .rotate(std.math.degreesToRadians(transform.rotation));

        var self = Self{
            .transform = transform,
            .center = center_point,
            .delta_top_left = delta_point_top_left,
            .delta_top_right = delta_point_top_right,
            .delta_bottom_left = delta_point_bottom_left,
            .delta_bottom_right = delta_point_bottom_right,
        };

        self.recalculatePoints();
        self.recalculateXYMinMax();

        return self;
    }

    pub fn getCenterPoint(transform: *Transform, collider: *Collider) rl.Vector2 {
        return fyr.Vec2(
            transform.position.x + collider.rect.x,
            transform.position.y + collider.rect.y,
        );
    }

    pub fn recalculateXYMinMax(self: *Self) void {
        self.x_min = @min(@min(self.top_left.x, self.top_right.x), @min(self.bottom_left.x, self.bottom_right.x));
        self.x_max = @max(@max(self.top_left.x, self.top_right.x), @max(self.bottom_left.x, self.bottom_right.x));
        self.y_min = @min(@min(self.top_left.y, self.top_right.y), @min(self.bottom_left.y, self.bottom_right.y));
        self.y_max = @max(@max(self.top_left.y, self.top_right.y), @max(self.bottom_left.y, self.bottom_right.y));
    }

    pub fn recalculatePoints(self: *Self) void {
        // zig fmt: off
        self.top_left       = self.center.add(self.delta_top_left);
        self.top_right      = self.center.add(self.delta_top_right);
        self.bottom_left    = self.center.add(self.delta_bottom_left);
        self.bottom_right   = self.center.add(self.delta_bottom_right);
        // zig fmt: on
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

pub const ColliderBehaviour = struct {
    const Cache = struct {
        base: Collider,

        Entity: ?*fyr.Entity = null,
        transform: ?*Transform = null,
        collider: ?*Collider = null,
    };
    var collidable: ?std.ArrayList(*Cache) = null;

    fn awake(Entity: *fyr.Entity, cache_ptr: *anyopaque) !void {
        const cache = fyr.CacheCast(Cache, cache_ptr);

        const transform = Entity.getComponent(Transform) orelse Blk: {
            try Entity.addComonent(Transform{});
            break :Blk Entity.getComponent(Transform).?;
        };

        const collider = Entity.getComponent(Collider) orelse Blk: {
            try Entity.addComonent(cache.base);
            break :Blk Entity.getComponent(Collider).?;
        };

        cache.transform = transform;
        cache.collider = collider;
        cache.Entity = Entity;

        const c = &(collidable orelse Blk: {
            collidable = std.ArrayList(*Cache).init(fyr.getAllocator(.gpa));
            break :Blk collidable.?;
        });

        try c.append(cache);
    }

    fn update(_: *fyr.Entity, cache_ptr: *anyopaque) !void {
        const cache = fyr.CacheCast(Cache, cache_ptr);
        const c = collidable orelse return;

        const a_Entity = cache.Entity orelse return;
        const a_transform = cache.transform orelse return;

        const a_collider = cache.collider orelse return;
        if (!a_collider.dynamic) return;

        var a_vertices = RectangleVertices.init(a_transform, a_collider);

        for (c.items) |b| {
            const b_Entity = b.Entity orelse continue;
            if (a_Entity.uuid == b_Entity.uuid) continue;

            const b_transform = b.transform orelse return;
            const b_collider = b.collider orelse continue;

            var b_vertices = RectangleVertices.init(b_transform, b_collider);

            if (!a_vertices.overlaps(b_vertices)) continue;

            if (!b_collider.dynamic) {
                a_vertices.pushback(b_vertices, 1);
                continue;
            }

            const combined_weight = a_collider.weight + b_collider.weight;
            const a_mult = 1 - a_collider.weight / combined_weight;
            const b_mult = 1 - a_mult;

            a_vertices.pushback(b_vertices, a_mult);
            b_vertices.pushback(b_vertices, b_mult);
        }
    }

    fn deinit(_: *fyr.Entity, cache_ptr: *anyopaque) !void {
        const cache = fyr.CacheCast(Cache, cache_ptr);

        const c = &(collidable orelse return);
        for (c.items, 0..) |item, index| {
            if (item != cache) continue;
            _ = c.swapRemove(index);
            break;
        }

        if (c.items.len == 0) c.deinit();
    }

    pub fn behaviour(base: Collider) !fyr.Behaviour {
        var b = try fyr.Behaviour.initWithValue(Cache{
            .base = base,
        });

        b.add(.awake, awake);
        b.add(.update, update);
        b.add(.deinit, deinit);

        return b;
    }
}.behaviour;
