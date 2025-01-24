const std = @import("std");
const fyr = @import("../../main.zig");

const FnType = ?(*const fn (*fyr.Entity, *anyopaque) anyerror!void);
const Events = enum { awake, init, update, tick, deinit };
const AllocationError = error.OutOfMemory;

const Self = @This();

cache: *anyopaque,
awake: FnType = null,
init: FnType = null,
update: FnType = null,
tick: FnType = null,
deinit: FnType = null,

pub fn init(comptime T: type) !Self {
    return initWithDefaultValue(T{});
}

pub fn initWithDefaultValue(value: anytype) !Self {
    const T: type = comptime @TypeOf(value);

    const c_ptr = std.c.malloc(@sizeOf(T)) orelse return AllocationError;
    const ptr: *T = @ptrCast(@alignCast(c_ptr));
    ptr.* = value;

    return Self{
        .cache = @ptrCast(@alignCast(ptr)),
    };
}

pub fn add(self: *Self, event: Events, callback: FnType) void {
    switch (event) {
        .awake => self.awake = callback,
        .init => self.init = callback,
        .update => self.update = callback,
        .tick => self.tick = callback,
        .deinit => self.deinit = callback,
    }
}

pub fn callSafe(self: *Self, event: Events, entity: *fyr.Entity) void {
    defer FreeingCAllocations: {
        if (event != .deinit) break :FreeingCAllocations;

        if (fyr.BUILD_MODE == .Debug) {
            const addr = @intFromPtr(self.cache);

            std.c.free(self.cache);
            std.log.info("behaviour cache \x1b[32m\x1b[1mfree\x1b[0m at 0x{x}", .{addr});
        }
    }

    const func = switch (event) {
        // zig fmt: off
        .awake  => self.awake,
        .init   => self.init,
        .update => self.update,
        .tick   => self.tick,
        .deinit => self.deinit,
        // zig fmt: on
    } orelse return;

    func(entity, self.cache) catch {
        std.log.err("failed to call behaviour event ({s})", .{switch (event) {
            // zig fmt: off
            .awake  => "awake",
            .init   => "init",
            .deinit => "deinit",
            .update => "update",
            .tick   => "tick",
            // zig fmt: on
        }});
    };
}

pub inline fn CacheCast(comptime T: type, ptr: *anyopaque) *T {
    return @ptrCast(@alignCast(ptr));
}
