const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const fyr = @import("../../main.zig");

const Self = @This();

ptr: *anyopaque,
hash: u64,
store_hash: u64,
is_behaviour: bool = false,

pub inline fn calculateHash(comptime T: type) u64 {
    const b: comptime_int = comptime switch (@typeInfo(T)) {
        .@"struct", .@"enum" => Blk: {
            var fieldsum: comptime_int = 1;

            for (std.meta.fields(T), 0..) |field, index| {
                for (field.name, 0..) |char, jndex| {
                    fieldsum += @as(comptime_int, @intCast(char)) *
                        (@as(comptime_int, @intCast(jndex)) + 1) *
                        (@as(comptime_int, @intCast(index)) + 1);
                }
            }

            for (@typeName(T)) |char| {
                fieldsum += @as(comptime_int, @intCast(char)) *
                    @as(comptime_int, @intCast(@alignOf(T)));
            }

            break :Blk fieldsum;
        },
        else => 1,
    };

    return @max(1, @sizeOf(T)) * @max(1, @alignOf(T)) +
        @max(1, @bitSizeOf(T)) * @max(1, @alignOf(T)) +
        b * @max(1, @alignOf(T)) * 13;
}

pub fn init(x: anytype) ?Self {
    const T: type = @TypeOf(x);

    const allocated = @as(?*T, @ptrCast(@alignCast(std.c.malloc(@sizeOf(T)))));

    if (allocated == null) return null;
    const ptr = allocated.?;

    ptr.* = x;

    return Self{
        .ptr = @ptrCast(@alignCast(ptr)),
        .hash = comptime calculateHash(T),
        .store_hash = comptime calculateHash(T),
        .is_behaviour = T == fyr.Behaviour,
    };
}

/// Use the original type as key for a behaviour
pub fn initBehaviour(comptime T: type, b: fyr.Behaviour) ?Self {
    const allocated = @as(?*fyr.Behaviour, @ptrCast(@alignCast(std.c.malloc(@sizeOf(fyr.Behaviour)))));

    if (allocated == null) return null;
    const ptr = allocated.?;

    ptr.* = b;

    return Self{
        .ptr = @ptrCast(@alignCast(ptr)),
        .hash = comptime calculateHash(T),
        .store_hash = comptime calculateHash(fyr.Behaviour),
        .is_behaviour = true,
    };
}

pub fn deinit(self: Self) void {
    std.c.free(self.ptr);
}

pub fn castBack(self: Self, comptime T: type) ?*T {
    if ((self.hash != comptime calculateHash(T)) and (self.store_hash != comptime calculateHash(T))) return null;
    return @ptrCast(@alignCast(self.ptr));
}

pub fn castBackBehaviour(self: Self, comptime T: type) ?*T {
    if (self.store_hash != comptime calculateHash(fyr.Behaviour)) return null;
    const behaviour: *fyr.Behaviour = @ptrCast(@alignCast(self.ptr));

    return @ptrCast(@alignCast(behaviour.cache));
}
