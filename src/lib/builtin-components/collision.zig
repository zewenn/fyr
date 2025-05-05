const std = @import("std");
const loom = @import("../root.zig");
const rl = loom.rl;

const Transform = @import("./Transform.zig");

pub const RectangleVertices = struct {
    const Self = @This();

    transform: *Transform,

    center: rl.Vector2,

    delta_top_left: rl.Vector2,
    delta_top_right: rl.Vector2,
    delta_bottom_left: rl.Vector2,
    delta_bottom_right: rl.Vector2,

    top_left: rl.Vector2 = loom.vec2(),
    top_right: rl.Vector2 = loom.vec2(),
    bottom_left: rl.Vector2 = loom.vec2(),
    bottom_right: rl.Vector2 = loom.vec2(),

    x_min: f32 = 0,
    x_max: f32 = 0,

    y_min: f32 = 0,
    y_max: f32 = 0,

    pub fn init(transform: *Transform, collider_rect: loom.Rectangle) Self {
        const center_point = getCenterPoint(transform, collider_rect);
        const delta_point_top_left = rl.Vector2
            .init(-collider_rect.width / 2, -collider_rect.height / 2)
            .rotate(std.math.degreesToRadians(transform.rotation));

        const delta_point_top_right = rl.Vector2
            .init(collider_rect.width / 2, -collider_rect.height / 2)
            .rotate(std.math.degreesToRadians(transform.rotation));

        const delta_point_bottom_left = rl.Vector2
            .init(-collider_rect.width / 2, collider_rect.height / 2)
            .rotate(std.math.degreesToRadians(transform.rotation));

        const delta_point_bottom_right = rl.Vector2
            .init(collider_rect.width / 2, collider_rect.height / 2)
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

    pub fn getCenterPoint(transform: *Transform, collider_rect: loom.Rectangle) rl.Vector2 {
        return loom.Vec2(
            transform.position.x + collider_rect.x,
            transform.position.y + collider_rect.y,
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

pub const RectCollider = struct {
    const Self = @This();
    var collidables_or_null: ?std.ArrayList(*RectCollider) = null;

    pub const Config = struct {
        trigger: bool = false,
        rect: rl.Rectangle,
        verticies: ?RectangleVertices = null,
        weight: f32 = 1,
        dynamic: bool = true,
        onCollisionEnter: ?*const fn (self: *loom.Entity, other: *loom.Entity) anyerror!void = null,
    };

    entity: ?*loom.Entity = null,
    transform: ?*Transform = null,
    config: Config,

    pub fn init(config: Config) Self {
        return .{ .config = config };
    }

    pub fn Awake(self: *Self, entity: *loom.Entity) !void {
        self.entity = entity;

        const collidables = &(collidables_or_null orelse Blk: {
            collidables_or_null = std.ArrayList(*Self).init(loom.allocators.generic());
            break :Blk collidables_or_null.?;
        });

        try collidables.append(self);
    }

    pub fn Start(self: *Self, entity: *loom.Entity) !void {
        if (entity.getComponent(Transform)) |transform| {
            self.transform = transform;
        }
    }

    pub fn Update(self: *Self) !void {
        const collidables = collidables_or_null orelse return;

        const self_entity = self.entity orelse return;
        const self_transform = self.transform orelse return;

        const self_collider = &self.config;
        if (!self_collider.dynamic) return;

        var self_vertices = self_collider.verticies orelse Blk: {
            self_collider.verticies = RectangleVertices.init(self_transform, self_collider.rect);
            break :Blk self_collider.verticies.?;
        };

        for (collidables.items) |other| {
            const other_entity = other.entity orelse continue;
            if (self_entity.uuid == other_entity.uuid) continue;

            const other_transform = other.transform orelse return;
            const other_collider = &other.config;

            var other_vertices = other_collider.verticies orelse Blk: {
                other_collider.verticies = RectangleVertices.init(other_transform, other_collider.rect);
                break :Blk other_collider.verticies.?;
            };

            if (other.config.trigger) continue;
            if (!self_vertices.overlaps(other_vertices)) continue;

            if (self.config.onCollisionEnter) |func|
                func(self_entity, other_entity) catch {
                    std.log.err("CollisionEnter function failed ({s}/{x})", .{ self_entity.id, self_entity.uuid });
                };

            if (self.config.trigger) continue;

            if (!other_collider.dynamic) {
                self_vertices.pushback(other_vertices, 1);
                continue;
            }

            const combined_weight = self_collider.weight + other_collider.weight;
            const self_mult = 1 - self_collider.weight / combined_weight;
            const other_mult = 1 - self_mult;

            self_vertices.pushback(other_vertices, self_mult);
            other_vertices.pushback(self_vertices, other_mult);
        }

        for (collidables.items) |item| {
            item.config.verticies = null;
        }
    }

    pub fn End(self: *Self) !void {
        const collidables = &(collidables_or_null orelse return);
        for (collidables.items, 0..) |item, index| {
            if (item != self) continue;
            _ = collidables.swapRemove(index);
            break;
        }

        if (collidables.items.len == 0) collidables.deinit();
    }
};
