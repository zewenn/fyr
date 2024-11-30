const std = @import("std");

pub fn print(comptime msg: []const u8, args: anytype) void {
    std.debug.print(msg, args);
}

pub fn println(comptime msg: []const u8, args: anytype) void {
    print(msg ++ "\n", args);
}

pub fn dprint(comptime msg: []const u8, args: anytype) void {
    print(
        (
        //
            "\n=========================================\n\n" ++
            msg ++
            "\n\n=========================================\n\n"
        //
        ),
        args,
    );
}

pub fn addrprint(name: []const u8, ptr: anytype) void {
    switch (@typeInfo(@TypeOf(ptr))) {
        .Pointer => dprint("ADDR[{s}]: 0x{x}", .{ name, @intFromPtr(ptr) }),
        else => print("{any}", .{ptr}),
    }
}

pub fn enable() void {
    debugDisplay = true;
}

pub fn disable() void {
    debugDisplay = false;
}

pub var debugDisplay = false;
