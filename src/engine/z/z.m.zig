const std = @import("std");

pub fn assert(statement: bool, comptime msg: []const u8) void {
    if (!statement) {
        @panic(msg);
    }
}

pub fn panic(msg: anytype) noreturn {
    std.debug.print("{any}", .{msg});
    unreachable;
}

pub fn panicWithArgs(comptime fmt: []const u8, msg: anytype) noreturn {
    std.log.err(fmt, msg);
    unreachable;
}

pub fn eql(a: anytype, b: anytype) bool {
    if (@TypeOf(a) != @TypeOf(b)) return false;

    return std.meta.eql(a, b);
}

const NullAssertError = error{
    CouldntAssertNullValue,
};
pub fn nullAssertOptionalPointer(comptime T: type, ptr: *?T) !*T {
    if (ptr.* != null) return &(ptr.*.?);
    return NullAssertError.CouldntAssertNullValue;
}

pub const math = @import("math.zig");
pub const arrays = @import("arrays.zig");

pub const perlin = @import("perlin.zig");
pub const reshape = @import("magic.zig").reshape;

pub const debug = @import("./debug.zig");
pub const print = debug.print;
pub const println = debug.println;
pub const dprint = debug.dprint;
pub const addrprint = debug.addrprint;

pub const HeapManager = @import("heapmanager.zig").HeapManager;
