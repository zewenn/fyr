const std = @import("std");
const builtin = @import("builtin");

const Allocator = @import("std").mem.Allocator;

const rl = @import("raylib");

const components = @import("components.zig");

pub const Transform = components.Transform;
pub const Display = components.Display;
pub const Collider = components.Collider;
pub const CachedDisplay = components.CachedDisplay;
pub const RectangleVertices = components.RectangleVertices;
pub const DummyData = components.DummyData;

const EntityTypeError = error{
    TypeMustBeStruct,
    NoIdField,
    NoTagsField,
    NoTransformField,
    NoDisplayField,
    NoColliderField,
    NoCachedDisplayField,
};

inline fn containsFieldName(fields: []const std.builtin.Type.StructField, name: []const u8) bool {
    for (fields) |field| {
        if (std.mem.eql(u8, field.name, name)) return true;
    }
    return false;
}

/// `T` is the type all entities must match.
/// This type must have all internal fields since
/// otherwise some engine modules won't work
/// *(if the type does not have these fields and error
/// will be returned)*.
pub fn make(comptime T: type) type {
    comptime {
        if (@typeInfo(T) != .Struct) @compileError("Type must be struct");

        const must_have_fields = [_][]const u8{
            "id",
            "tags",
            "transform",
            "display",
            "collider",
            "cached_display",
            "cached_collider",
        };

        const fields = std.meta.fields(T);

        for (must_have_fields) |field| {
            if (!containsFieldName(fields, field)) {
                @compileError("Missing field \"" ++ field ++ "\" on entity type!");
            }
        }
    }

    return struct {
        pub const Entity = T;

        pub const Transform = components.Transform;
        pub const Display = components.Display;
        pub const Collider = components.Collider;
        pub const CachedDisplay = components.CachedDisplay;
        pub const RectangleVertices = components.RectangleVertices;
        pub const DummyData = components.DummyData;

        const EntityArrayType = std.ArrayList(*Entity);

        var entities: EntityArrayType = undefined;
        pub var alloc: Allocator = undefined;

        pub fn init(allocator: Allocator) void {
            alloc = allocator;

            entities = EntityArrayType.init(alloc);
        }

        pub fn deinit() void {
            entities.deinit();
        }

        pub fn get(id: []const u8) ?*Entity {
            for (entities.items) |item| {
                if (std.mem.eql(u8, item.id, id)) return item;
            }
            return null;
        }

        pub fn tagged(entity: *Entity, tag: []const u8) bool {
            return std.mem.containsAtLeast(u8, entity.tags, 1, tag);
        }

        /// Caller owns the returned memory.
        /// Returns all entities with the given tag.
        pub fn search(tag: []const u8) ![]*Entity {
            var list = EntityArrayType.init(alloc);
            defer list.deinit();

            for (entities.items) |item| {
                if (std.mem.containsAtLeast(
                    u8,
                    item.id,
                    1,
                    tag,
                )) try list.append(item);
            }
            return try list.toOwnedSlice();
        }

        /// Caller owns the returned memory.
        /// Returns all entities without the given tag.
        pub fn searchExclude(tag: []const u8) ![]*Entity {
            var list = EntityArrayType.init(alloc);
            defer list.deinit();

            for (entities.items) |item| {
                if (!std.mem.containsAtLeast(
                    u8,
                    item.tags,
                    1,
                    tag,
                )) try list.append(item);
            }
            return try list.toOwnedSlice();
        }

        pub fn isValid(ptr: *Entity) bool {
            const as_int: usize = @intFromPtr(ptr);
            for (entities.items) |eptr| {
                const eptr_as_int: usize = @intFromPtr(eptr);

                if (eptr_as_int != as_int) continue;
                return true;
            }
            return false;
        }

        /// Caller owns the returned memory
        pub fn all() ![]*Entity {
            var list = try entities.clone();
            defer list.deinit();

            return try list.toOwnedSlice();
        }

        pub fn exists(id: []const u8) bool {
            if (get(id) != null) return true;
            return false;
        }

        pub fn append(entity: *Entity) !void {
            try entities.append(entity);
        }

        pub fn remove(id: []const u8) void {
            for (entities.items, 0..) |item, i| {
                if (!std.mem.eql(u8, item.id, id)) continue;
                item.deinit();
                _ = entities.orderedRemove(i);
                return;
            }
        }

        pub fn clear() void {
            entities.clearAndFree();
        }
    };
}
