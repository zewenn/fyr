const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const fyr = @import("../../main.zig");
const Error = error{
    OutOfMemory,
};

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
                    fieldsum += (@as(comptime_int, @intCast(char)) *
                        (@as(comptime_int, @intCast(jndex)) + 1) *
                        (@as(comptime_int, @intCast(index)) + 1)) % std.math.maxInt(u63);
                }
            }

            for (@typeName(T)) |char| {
                fieldsum += @as(comptime_int, @intCast(char)) *
                    (@as(comptime_int, @intCast(@alignOf(T))) + 1);
            }

            break :Blk fieldsum;
        },
        else => 1,
    };

    return (@max(1, @sizeOf(T)) * @max(1, @alignOf(T)) +
        @max(1, @bitSizeOf(T)) * @max(1, @alignOf(T)) +
        b * @max(1, @alignOf(T)) * 13) % std.math.maxInt(u63);
}

pub fn init(x: anytype) !Self {
    const isBehaviour = fyr.Behaviour.isBehaviourBase(x);
    const T: type = @TypeOf(x);

    const valure_ptr: *anyopaque = switch (isBehaviour) {
        true => behaviour: {
            const ptr = @as(?*fyr.Behaviour, @ptrCast(@alignCast(std.c.malloc(@sizeOf(fyr.Behaviour))))) orelse return Error.OutOfMemory;
            ptr.* = try fyr.asBehaviour(x);

            break :behaviour ptr;
        },
        false => normal: {
            const ptr = @as(?*T, @ptrCast(@alignCast(std.c.malloc(@sizeOf(T))))) orelse return Error.OutOfMemory;
            ptr.* = x;

            break :normal ptr;
        },
    };

    return Self{
        .ptr = valure_ptr,
        .hash = comptime calculateHash(T),
        .store_hash = switch (isBehaviour) {
            true => comptime calculateHash(fyr.Behaviour),
            false => comptime calculateHash(T),
        },
        .is_behaviour = isBehaviour,
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
