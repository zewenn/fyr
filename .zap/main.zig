const std = @import("std");
const Allocator = @import("std").mem.Allocator;

pub const libs = @import("./.codegen/libs.zig");
pub const engine = @import("./.codegen/modules.zig");

pub const Vector2 = libs.raylib.Vector2;
pub const Vector3 = libs.raylib.Vector3;
pub const Vector4 = libs.raylib.Vector4;
pub const Rectangle = libs.raylib.Rectangle;

pub fn changeType(comptime T: type, value: anytype) ?T {
    return switch (@typeInfo(T)) {
        .Int, .ComptimeInt => switch (@typeInfo(@TypeOf(value))) {
            .Int, .ComptimeInt => @as(T, @intCast(value)),
            .Float, .ComptimeFloat => @as(T, @intFromFloat(value)),
            .Bool => @as(T, @intFromBool(value)),
            .Enum => @as(T, @intFromEnum(value)),
            else => null,
        },
        .Float, .ComptimeFloat => switch (@typeInfo(@TypeOf(value))) {
            .Int, .ComptimeInt => @as(T, @floatFromInt(value)),
            .Float, .ComptimeFloat => @as(T, @floatCast(value)),
            .Bool => @as(T, @floatFromInt(@intFromBool(value))),
            .Enum => @as(T, @floatFromInt(@intFromEnum(value))),
            else => null,
        },
        .Bool => switch (@typeInfo(@TypeOf(value))) {
            .Int, .ComptimeInt => value != 0,
            .Float, .ComptimeFloat => @as(isize, @intFromFloat(@round(value))) != 0,
            .Bool => value,
            .Enum => @as(isize, @intFromEnum(value)) != 0,
            else => null,
        },
        .Enum => switch (@typeInfo(@TypeOf(value))) {
            .Int, .ComptimeInt => @enumFromInt(value),
            .Float, .ComptimeFloat => @enumFromInt(@as(isize, @intFromFloat(@round(value)))),
            .Bool => @enumFromInt(@intFromBool(value)),
            .Enum => @enumFromInt(@as(isize, @intFromEnum(value))),
            else => null,
        },
        else => Catch: {
            std.log.warn(
                "cannot change type of \"{any}\" to type \"{any}\"! (zap.changeType())",
                .{ value, T },
            );
            break :Catch null;
        },
    };
}

pub fn tof32(value: anytype) f32 {
    return changeType(f32, value) orelse 0;
}

pub fn Vec2(x: anytype, y: anytype) Vector2 {
    return Vector2{
        .x = tof32(x),
        .y = tof32(y),
    };
}

pub fn Vec3(x: anytype, y: anytype, z: anytype) Vector3 {
    return Vector3{
        .x = tof32(x),
        .y = tof32(y),
        .z = tof32(z),
    };
}

pub fn Vec4(x: anytype, y: anytype, z: anytype, w: anytype) Vector4 {
    return Vector4{
        .x = tof32(x),
        .y = tof32(y),
        .z = tof32(z),
        .w = tof32(w),
    };
}

pub fn Rect(x: anytype, y: anytype, width: anytype, height: anytype) Rectangle {
    return Rectangle{
        .x = tof32(x),
        .y = tof32(y),
        .width = tof32(width),
        .height = tof32(height),
    };
}

pub fn cloneToOwnedSlice(comptime T: type, list: std.ArrayList(T)) ![]T {
    return try @constCast(&(try list.clone())).toOwnedSlice();
}

pub const WrappedArrayOptions = struct {
    try_type_change: bool = true,
};

pub fn WrappedArray(comptime T: type) type {
    return WrappedArrayAdvanced(T, .{});
}

pub fn WrappedArrayAdvanced(comptime T: type, comptime options: WrappedArrayOptions) type {
    return struct {
        const Self = @This();

        alloc: Allocator = std.heap.page_allocator,
        items: []T,

        pub fn init(tuple: anytype, alloc: ?Allocator) !Self {
            const allocator = alloc orelse std.heap.page_allocator;

            var arrlist = std.ArrayList(T).init(allocator);
            defer arrlist.deinit();

            inline for (tuple) |item| {
                const item_value = @as(
                    ?T,
                    if (T != @TypeOf(item))
                        switch (options.try_type_change) {
                            true => changeType(T, item),
                            false => null,
                        }
                    else
                        item,
                );
                if (item_value) |c| {
                    try arrlist.append(c);
                }
            }

            const slice = try arrlist.toOwnedSlice();

            return Self{
                .alloc = allocator,
                .items = slice,
            };
        }

        pub fn fromArray(arr: []T, alloc: ?Allocator) !Self {
            const allocator = alloc orelse std.heap.page_allocator;

            const new = try allocator.alloc(T, arr.len);
            std.mem.copyForwards(T, new, arr);

            return Self{
                .items = new,
                .alloc = allocator,
            };
        }

        pub fn fromArrayList(arr: std.ArrayList(T)) !Self {
            const allocator = arr.allocator;

            return Self{
                .items = try cloneToOwnedSlice(T, arr),
                .alloc = allocator,
            };
        }

        pub fn clone(self: Self) !Self {
            const new = try self.alloc.alloc(T, self.items.len);
            std.mem.copyForwards(T, new, self.items);

            return Self{
                .items = new,
                .alloc = self.alloc,
            };
        }

        pub fn reverse(self: Self) Self {
            const new = self.alloc.alloc(T, self.items.len) catch @panic("Allocation failiure!");

            for (0..self.items.len) |jndex| {
                const index = self.items.len - 1 - jndex;

                new[jndex] = self.items[index];
            }

            return Self{
                .items = new,
                .alloc = self.alloc,
            };
        }

        pub fn map(self: Self, comptime R: type, map_fn: fn (T) anyerror!R) !WrappedArray(R) {
            var arrlist = std.ArrayList(R).init(self.alloc);
            defer arrlist.deinit();

            for (self.items) |item| {
                try arrlist.append(try map_fn(item));
            }

            return WrappedArrayAdvanced(R, options){
                .items = try cloneToOwnedSlice(R, arrlist),
                .alloc = self.alloc,
            };
        }

        pub fn deinit(self: *Self) void {
            self.alloc.free(self.items);
        }
    };
}

pub fn array(comptime T: type, tuple: anytype) WrappedArray(T) {
    return WrappedArray(T).init(tuple, null) catch unreachable;
}

pub fn arrayAdvanced(comptime T: type, comptime options: WrappedArrayOptions, alloc: Allocator, tuple: anytype) WrappedArrayAdvanced(T, options) {
    return WrappedArrayAdvanced(T, options).init(tuple, alloc) catch unreachable;
}
