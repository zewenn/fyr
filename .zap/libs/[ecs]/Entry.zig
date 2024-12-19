const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const Self = @This();

ptr: *anyopaque,
hash: usize,

pub inline fn calculateHash(comptime T: type) usize {
    return @max(1, @sizeOf(T)) * @max(1, @alignOf(T)) + @max(1, @bitSizeOf(T)) * @max(1, @alignOf(T));
}

pub fn init(x: anytype) ?Self {
    const T: type = @TypeOf(x);

    const allocated = @as(?*T, @ptrCast(@alignCast(std.c.malloc(@sizeOf(T)))));

    if (allocated == null) return null;
    const ptr = allocated.?;

    ptr.* = x;

    return Self{
        .ptr = @ptrCast(@alignCast(ptr)),
        .hash = calculateHash(T),
    };
}

pub fn deinit(self: Self) void {
    std.c.free(self.ptr);
}

pub fn castBack(self: Self, comptime T: type) ?*T {
    if (self.hash != calculateHash(T)) return null;
    return @ptrCast(@alignCast(self.ptr));
}
