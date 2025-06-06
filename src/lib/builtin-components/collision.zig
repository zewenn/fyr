const std = @import("std");
const loom = @import("../root.zig");
const rl = loom.rl;

const Transform = @import("./Transform.zig");
const Vector2 = loom.Vector2;

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
            collidables_or_null = std.ArrayList(*Self).init(loom.allocators.scene());
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

        if (collidables.items.len == 0) {
            collidables.deinit();
            collidables_or_null = null;
        }
    }
};

pub const RectangleCollider = struct {
    const MinMax = struct {
        x_min: f32 = 0,
        x_max: f32 = 0,

        y_min: f32 = 0,
        y_max: f32 = 0,
    };

    /// ```
    /// A +---------+ B
    ///   |    * O  |
    /// D +---------+ C
    /// ```
    /// ABCD Rectangle, with O center. O is the position A;B;C;D are relative to.
    const Vertices = struct {
        A: Vector2, // top-left
        B: Vector2, // top-right
        C: Vector2, // bottom-right
        D: Vector2, // bottom-left

        pub fn init(scale: Vector2, sin_theta: f32, cos_theta: f32) Vertices {
            const half_width = scale.x / 2;
            const half_height = scale.y / 2;

            var A: Vector2 = .init(-1 * half_width, -1 * half_height);
            {
                A.x = A.x * cos_theta - A.y * sin_theta;
                A.y = A.x * sin_theta + A.y * cos_theta;
            }

            var B: Vector2 = .init(half_width, -1 * half_height);
            {
                B.x = B.x * cos_theta - B.y * sin_theta;
                B.y = B.x * sin_theta + B.y * cos_theta;
            }

            var C: Vector2 = .init(half_width, half_height);
            {
                C.x = C.x * cos_theta - C.y * sin_theta;
                C.y = C.x * sin_theta + C.y * cos_theta;
            }

            var D: Vector2 = .init(-1 * half_width, half_height);
            {
                D.x = D.x * cos_theta - D.y * sin_theta;
                D.y = D.x * sin_theta + D.y * cos_theta;
            }

            return Vertices{
                .A = A,
                .B = B,
                .C = C,
                .D = D,
            };
        }

        pub fn zero() Vertices {
            return Vertices{
                .A = .init(0, 0),
                .B = .init(0, 0),
                .C = .init(0, 0),
                .D = .init(0, 0),
            };
        }

        pub fn getMinMax(self: Vertices) MinMax {
            return MinMax{
                .x_min = @min(@min(self.A.x, self.B.x), @min(self.C.x, self.D.x)),
                .x_max = @max(@max(self.A.x, self.B.x), @max(self.C.x, self.D.x)),
                .y_min = @min(@min(self.A.y, self.B.y), @min(self.C.y, self.D.y)),
                .y_max = @max(@max(self.A.y, self.B.y), @max(self.C.y, self.D.y)),
            };
        }
    };

    const Self = @This();
    var collidables: ?std.ArrayList(*Self) = null;

    collider_transform: Transform,
    type: enum {
        static,
        dynamic,
        trigger,
        passtrough,
    } = .static,
    weight: f32 = 1,
    onCollision: ?*const fn (self: *loom.Entity, other: *loom.Entity) anyerror!void = null,

    entity: *loom.Entity = undefined,

    last_collider_transform: Transform = .{},
    transform: ?*Transform = null,
    last_transform: ?Transform = null,

    deltas: Vertices = .zero(),
    points: ?Vertices = null,
    minmax: ?MinMax = null,

    sin_theta: f32 = 0,
    cos_theta: f32 = 0,

    pub fn R(self: *Self) f32 {
        return std.math.hypot(self.collider_transform.scale.x / 2, self.collider_transform.scale.y / 2);
    }

    pub fn center(self: *Self) !Vector2 {
        const transform: *Transform = try loom.ensureComponent(self.transform);

        return loom.vec3ToVec2(transform.position.add(self.collider_transform.position));
    }

    pub fn init(collider_transform: Transform) Self {
        return Self{
            .collider_transform = collider_transform,
            .last_collider_transform = collider_transform,
        };
    }

    pub fn recalculateRotation(self: *Self) !void {
        const transform: *Transform = try loom.ensureComponent(self.transform);
        const theta = transform.rotation + self.collider_transform.rotation;

        self.sin_theta = @sin(std.math.degreesToRadians(theta));
        self.cos_theta = @cos(std.math.degreesToRadians(theta));
    }

    pub fn recalculateDeltas(self: *Self) void {
        self.deltas = .init(self.collider_transform.scale, self.sin_theta, self.cos_theta);
    }

    pub fn recalculatePoints(self: *Self) !void {
        const transform: *Transform = try loom.ensureComponent(self.transform);

        self.points = Vertices{
            .A = self.deltas.A.add(loom.vec3ToVec2(transform.position)).add(loom.vec3ToVec2(self.collider_transform.position)),
            .B = self.deltas.B.add(loom.vec3ToVec2(transform.position)).add(loom.vec3ToVec2(self.collider_transform.position)),
            .C = self.deltas.C.add(loom.vec3ToVec2(transform.position)).add(loom.vec3ToVec2(self.collider_transform.position)),
            .D = self.deltas.D.add(loom.vec3ToVec2(transform.position)).add(loom.vec3ToVec2(self.collider_transform.position)),
        };
    }

    pub fn overlaps(self: *Self, other: *Self) bool {
        const self_minmax = self.minmax orelse return false;
        const other_minmax = other.minmax orelse return false;

        if ((self_minmax.x_max > other_minmax.x_min and self_minmax.x_min < other_minmax.x_max) and
            (self_minmax.y_max > other_minmax.y_min and self_minmax.y_min < other_minmax.y_max))
            return true;
        return false;
    }

    pub fn pushback(a: *Self, b: *Self, weight: f32) !void {
        const a_transform: *Transform = try loom.ensureComponent(a.transform);

        const a_minmax = a.minmax orelse return;
        const b_minmax = b.minmax orelse return;

        const overlap_x = @min(a_minmax.x_max - b_minmax.x_min, b_minmax.x_max - a_minmax.x_min);
        const overlap_y = @min(a_minmax.y_max - b_minmax.y_min, b_minmax.y_max - a_minmax.y_min);

        switch (overlap_x < overlap_y) {
            true => PushBack_X: {
                if (a_minmax.x_max > b_minmax.x_min and a_minmax.x_max < b_minmax.x_max) {
                    a_transform.position.x -= overlap_x * weight;
                    break :PushBack_X;
                }

                a_transform.position.x += overlap_x * weight;
                break :PushBack_X;
            },
            false => PushBack_Y: {
                if (a_minmax.y_max > b_minmax.y_min and a_minmax.y_max < b_minmax.y_max) {
                    a_transform.position.y -= overlap_y * weight;
                    break :PushBack_Y;
                }

                a_transform.position.y += overlap_y * weight;
                break :PushBack_Y;
            },
        }
    }

    pub fn Awake(self: *Self, entity: *loom.Entity) !void {
        self.entity = entity;
        self.last_collider_transform = self.collider_transform;

        if (collidables == null) {
            collidables = .init(loom.allocators.scene());
        }
        try collidables.?.append(self);
    }

    pub fn Start(self: *Self, entity: *loom.Entity) !void {
        self.transform = try entity.pullComponent(Transform);
        self.last_transform = self.transform.?.*;

        try self.recalculateRotation();
        self.recalculateDeltas();
        try self.recalculatePoints();
    }

    pub fn Update(self: *Self, entity: *loom.Entity) !void {
        const colliders = collidables orelse return error.CollidablesWasNotInitalised;

        if (self.type != .dynamic and self.type != .trigger) return;

        const self_transform: *Transform = try loom.ensureComponent(self.transform);
        const self_last_transform = self.last_transform orelse blk: {
            self.last_transform = self_transform.*;
            break :blk self.last_transform.?;
        };
        const self_center = try self.center();

        defer {
            self.last_transform = self_transform.*;
            self.last_collider_transform = self.collider_transform;
        }

        if (self_last_transform.rotation != self_transform.rotation or self.collider_transform.rotation != self.last_collider_transform.rotation)
            try self.recalculateRotation();

        if (self.collider_transform.scale.equals(self.last_collider_transform.scale) == 0)
            self.recalculateDeltas();

        if (self_last_transform.position.equals(self_transform.position) == 0 or self.last_collider_transform.position.equals(self.collider_transform.position) == 0)
            try self.recalculatePoints();

        const self_points = self.points orelse return;
        self.minmax = self_points.getMinMax();

        for (colliders.items) |other| {
            if (other.entity.uuid == self.entity.uuid) continue;
            if (other.type == .trigger) continue;
            if (other.type == .passtrough and self.type != .trigger) continue;

            const other_transform: *Transform = try loom.ensureComponent(other.transform);
            const other_last_transform = other.last_transform orelse blk: {
                other.last_transform = other_transform.*;
                break :blk other.last_transform.?;
            };

            const other_center = try other.center();

            if (self.R() + other.R() < std.math.hypot(self_center.x - other_center.x, self_center.y - other_center.y)) continue;

            if (other_last_transform.rotation != other_transform.rotation or other.collider_transform.rotation != other.last_collider_transform.rotation)
                try other.recalculateRotation();

            if (other.collider_transform.scale.equals(other.last_collider_transform.scale) == 0)
                other.recalculateDeltas();

            if (other_last_transform.position.equals(other_transform.position) == 0 or other.last_collider_transform.position.equals(other.collider_transform.position) == 0)
                try other.recalculatePoints();

            const other_points = other.points orelse continue;
            other.minmax = other_points.getMinMax();

            if (!self.overlaps(other)) continue;

            if (self.onCollision) |onCollision|
                onCollision(entity, other.entity) catch |err| {
                    std.log.err("onCollidion returned an error on entity: {s}@{x} when colliding with {s}@{x}", .{ entity.id, entity.uuid, other.entity.id, other.entity.uuid });
                    std.log.err("{any}", .{err});
                };

            if (self.type == .trigger) continue;
            if (other.type != .dynamic) {
                try self.pushback(other, 1);
                continue;
            }

            const combined_weight = self.weight + other.weight;
            const self_mult = 1 - self.weight / combined_weight;
            const other_mult = 1 - self_mult;

            try self.pushback(other, self_mult);
            try other.pushback(self, other_mult);
        }
    }

    pub fn End(self: *Self) !void {
        const colliders = &(collidables orelse return);
        for (colliders.items, 0..) |item, index| {
            if (item != self) continue;
            _ = colliders.swapRemove(index);
            break;
        }

        if (colliders.items.len == 0) {
            colliders.deinit();
            collidables = null;
        }
    }
};
