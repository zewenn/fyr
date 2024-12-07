const std = @import("std");
const Allocator = @import("std").mem.Allocator;

pub const libs = @import("./.codegen/libs.zig");
pub const engine = @import("./.codegen/modules.zig");

pub const Vector2 = libs.raylib.Vector2;
pub const Vector3 = libs.raylib.Vector3;
pub const Vector4 = libs.raylib.Vector4;

pub fn changeType(comptime T: type, value: anytype) ?T {
    return switch (@typeInfo(T)) {
        .Int, .ComptimeInt => switch (@typeInfo(@TypeOf(value))) {
            .Int, .ComptimeInt => @as(T, @intCast(value)),
            .Float, .ComptimeFloat => @as(T, @intFromFloat(value)),
            .Bool => @as(T, @intFromBool(value)),
            else => null,
        },
        .Float, .ComptimeFloat => switch (@typeInfo(@TypeOf(value))) {
            .Int, .ComptimeInt => @as(T, @floatFromInt(value)),
            .Float, .ComptimeFloat => @as(T, @floatCast(value)),
            .Bool => @as(T, @floatFromInt(@intFromBool(value))),
            else => null,
        },
        .Bool => switch (@typeInfo(@TypeOf(value))) {
            .Int, .ComptimeInt => value != 0,
            .Float, .ComptimeFloat => @as(isize, @intFromFloat(@round(value))) != 0,
            .Bool => value,
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

pub fn Vec2(x: anytype, y: anytype) libs.raylib.Vector2 {
    return libs.raylib.Vector2{
        .x = changeType(f32, x) orelse 0,
        .y = changeType(f32, y) orelse 0,
    };
}

pub fn Vec3(x: anytype, y: anytype, z: anytype) libs.raylib.Vector3 {
    return libs.raylib.Vector3{
        .x = changeType(f32, x) orelse 0,
        .y = changeType(f32, y) orelse 0,
        .z = changeType(f32, z) orelse 0,
    };
}

pub fn Vec4(x: anytype, y: anytype, z: anytype, w: anytype) libs.raylib.Vector4 {
    return libs.raylib.Vector4{
        .x = changeType(f32, x) orelse 0,
        .y = changeType(f32, y) orelse 0,
        .z = changeType(f32, z) orelse 0,
        .w = changeType(f32, w) orelse 0,
    };
}
