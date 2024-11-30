const std = @import("std");
const Allocator = @import("std").mem.Allocator;

pub const z = @import("./z/z.m.zig");
pub const entities = @import("./engine.m.zig").entities;

pub const rl = @import("raylib");
const Rect = @import("engine.m.zig").Rect;

pub const box_system = struct {
    pub const Distances = struct {
        const Self = @This();

        pub const DistanceNames = enum {
            left,
            right,
            top,
            bottom,
        };

        left: f32,
        right: f32,
        top: f32,
        bottom: f32,

        pub fn getSmallest(self: *Self) ?DistanceNames {
            const smallest = z.math.f128_to(f32, z.math.min(
                self.left,
                z.math.min(
                    self.right,
                    z.math.min(
                        self.top,
                        self.bottom,
                    ).?,
                ).?,
            ).?).?;

            if (smallest == self.left) return .left;
            if (smallest == self.right) return .right;
            if (smallest == self.top) return .top;
            if (smallest == self.bottom) return .bottom;
            return null;
        }
    };

    fn moveBack(
        dists: Distances,
        e_transform: *entities.Transform,
        e_collider: *entities.Collider,
        other_transform: *entities.Transform,
        other_collider: *entities.Collider,
        mult: f32,
    ) void {
        const smallest = @constCast(&dists).getSmallest();

        switch (smallest.?) {
            .left => {
                e_transform.position.x -= (
                //
                    e_transform.position.x +
                    e_collider.rect.x +
                    e_collider.rect.width -
                    other_transform.position.x -
                    other_collider.rect.x
                //
                ) * mult;
            },
            .right => {
                e_transform.position.x += (
                //
                    other_transform.position.x +
                    other_collider.rect.x +
                    other_collider.rect.width -
                    e_transform.position.x -
                    e_collider.rect.x
                //
                ) * mult;
            },
            .top => {
                e_transform.position.y += (
                //
                    other_transform.position.y +
                    other_collider.rect.y +
                    other_collider.rect.height -
                    e_transform.position.y -
                    e_collider.rect.y
                //
                ) * mult;
            },
            .bottom => {
                e_transform.position.y -= (
                //
                    e_transform.position.y +
                    e_collider.rect.y +
                    e_collider.rect.height -
                    other_transform.position.y -
                    other_collider.rect.y
                //
                ) * mult;
            },
        }
    }

    /// If both entities have a collider it returns the `.collidionChech()`
    /// result, if not it returns false.
    pub fn collides(entity1: *entities.Entity, entity2: *entities.Entity) bool {
        if (entity1.collider) |e1_collider| {
            if (entity2.collider) |e2_collider| {
                const e1_rect = Rect(
                    entity1.transform.position.x + e1_collider.rect.x,
                    entity1.transform.position.y + e1_collider.rect.y,
                    e1_collider.rect.width,
                    e1_collider.rect.height,
                );
                const e2_rect = Rect(
                    entity2.transform.position.x + e2_collider.rect.x,
                    entity2.transform.position.y + e2_collider.rect.y,
                    e2_collider.rect.width,
                    e2_collider.rect.height,
                );

                return e1_rect.checkCollision(e2_rect);
            }
        }

        return false;
    }

    pub fn update(alloc: *Allocator) !void {
        const entities_slice = try entities.all();
        defer alloc.free(entities_slice);

        dynamic: for (entities_slice) |e| {
            if (e.collider == null) continue;
            if (e.collider.?.trigger) continue;

            const e_transform = &e.transform;

            const e_collider = &e.collider.?;

            if (!e_collider.dynamic) continue :dynamic;

            const e_rect = rl.Rectangle.init(
                e_collider.rect.x + e_transform.position.x,
                e_collider.rect.y + e_transform.position.y,
                e_collider.rect.width,
                e_collider.rect.height,
            );

            other: for (entities_slice) |other| {
                if (other.collider == null) continue;
                if (other.collider.?.trigger) continue;

                if (std.mem.eql(u8, e.id, other.id)) continue :other;

                const other_transform = &other.transform;

                const other_collider = &other.collider.?;

                const other_rect = rl.Rectangle.init(
                    other_collider.rect.x + other_transform.position.x,
                    other_collider.rect.y + other_transform.position.y,
                    other_collider.rect.width,
                    other_collider.rect.height,
                );

                if (!e_rect.checkCollision(other_rect)) continue :other;

                // Collision Happening
                const e_distances = Distances{
                    .left = (
                    //
                        e_transform.position.x +
                        e_collider.rect.x +
                        e_collider.rect.width -
                        other_transform.position.x -
                        other_collider.rect.x +
                        1
                    //
                    ),
                    .right = (
                    //
                        other_transform.position.x +
                        other_collider.rect.x +
                        other_collider.rect.width -
                        e_transform.position.x -
                        e_collider.rect.x +
                        1
                    //
                    ),
                    .top = (
                    //
                        other_transform.position.y +
                        other_collider.rect.y +
                        other_collider.rect.height -
                        e_transform.position.y -
                        e_collider.rect.y +
                        1
                    //
                    ),
                    .bottom = (
                    //
                        e_transform.position.y +
                        e_collider.rect.y +
                        e_collider.rect.height -
                        other_transform.position.y -
                        other_collider.rect.y +
                        1
                    //
                    ),
                };

                if (!other_collider.dynamic) {
                    moveBack(e_distances, e_transform, e_collider, other_transform, other_collider, 1);
                    continue :other;
                }

                const other_distances = Distances{
                    .left = (
                    //
                        other_transform.position.x +
                        other_collider.rect.x +
                        other_collider.rect.width -
                        e_transform.position.x -
                        e_collider.rect.x +
                        1

                    //
                    ),
                    .right = (
                    //
                        e_transform.position.x +
                        e_collider.rect.x +
                        e_collider.rect.width -
                        other_transform.position.x -
                        other_collider.rect.x +
                        1
                    //
                    ),
                    .top = (
                    //
                        e_transform.position.y +
                        e_collider.rect.y +
                        e_collider.rect.height -
                        other_transform.position.y -
                        other_collider.rect.y +
                        1
                    //
                    ),
                    .bottom = (
                    //
                        other_transform.position.y +
                        other_collider.rect.y +
                        other_collider.rect.height -
                        e_transform.position.y -
                        e_collider.rect.y +
                        1
                    //
                    ),
                };

                const combined_weight = z.math.to_f128(e_collider.weight + other_collider.weight).?;
                const e_mult = z.math.f128_to(f32, z.math.div(
                    e_collider.weight,
                    combined_weight,
                ).?).?;
                const other_mult = z.math.f128_to(f32, z.math.div(
                    other_collider.weight,
                    combined_weight,
                ).?).?;

                moveBack(e_distances, e_transform, e_collider, other_transform, other_collider, other_mult);
                moveBack(other_distances, other_transform, other_collider, e_transform, e_collider, e_mult);
            }
        }
    }
};

const RectangleVertices = entities.RectangleVertices;

/// If both entities have a collider, returns the value of
/// `collder.overlaps()` else returns null
pub fn collides(entity1: *entities.Entity, entity2: *entities.Entity) bool {
    if (entity1.collider == null) return false;
    if (entity2.collider == null) return false;

    var a = getCachedOrNew(entity1);
    entity1.cached_collider = a;
    const b = getCachedOrNew(entity2);
    entity2.cached_collider = b;

    return a.overlaps(b);
}

pub fn getCachedOrNew(e: *entities.Entity) RectangleVertices {
    if (e.cached_collider == null or e.cached_display == null)
        return RectangleVertices.init(
            &e.transform,
            &e.collider.?,
        );

    var cc = e.cached_collider.?;
    const cd = e.cached_display.?;

    if (cd.transform.scale.equals(e.transform.scale) == 0 or
        cd.transform.rotation.z != e.transform.rotation.z)
    {
        return RectangleVertices.init(
            &e.transform,
            &e.collider.?,
        );
    }

    cc.center = RectangleVertices.getCenterPoint(
        &(e.transform),
        &(e.collider.?),
    );

    cc.recalculatePoints();
    cc.recalculateXYMinMax();

    return cc;
}

pub fn update(alloc: *Allocator) !void {
    const entities_slice = try entities.all();
    defer alloc.free(entities_slice);

    dynamic_colliders: for (entities_slice) |dynamic| {
        if (dynamic.collider == null) continue;
        if (dynamic.collider.?.trigger) continue;

        const dynamic_collider = &dynamic.collider.?;

        if (!dynamic_collider.dynamic) continue :dynamic_colliders;

        var dynamic_vertices = getCachedOrNew(dynamic);
        dynamic.cached_collider = dynamic_vertices;

        other: for (entities_slice) |other| {
            if (other.collider == null) continue;
            if (other.collider.?.trigger) continue;

            if (std.mem.eql(u8, dynamic.id, other.id)) continue :other;

            const other_collider = &other.collider.?;

            var other_vertices = getCachedOrNew(other);

            if (!dynamic_vertices.overlaps(other_vertices)) continue :other;

            // Single dynamic
            if (!other_collider.dynamic) {
                dynamic_vertices.pushback(other_vertices, 1);
                continue :other;
            }

            // Multiple dynamic

            const combined_weight = z.math.to_f128(dynamic_collider.weight + other_collider.weight).?;
            const e_mult = z.math.f128_to(f32, z.math.div(
                dynamic_collider.weight,
                combined_weight,
            ).?).?;
            const other_mult = z.math.f128_to(f32, z.math.div(
                other_collider.weight,
                combined_weight,
            ).?).?;

            dynamic_vertices.pushback(other_vertices, other_mult);
            other_vertices.pushback(dynamic_vertices, e_mult);
        }
    }
}
