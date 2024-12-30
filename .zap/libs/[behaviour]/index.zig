const std = @import("std");
const zap = @import("../../main.zig");

const FnType = ?(*const fn (*zap.Store, *anyopaque) anyerror!void);
const Events = enum { awake, init, update, tick, deinit };

pub const Behaviour = struct {
    const Self = @This();

    cache: *anyopaque,
    awake: FnType = null,
    init: FnType = null,
    update: FnType = null,
    tick: FnType = null,
    deinit: FnType = null,

    pub fn init(comptime T: type) Self {
        const c_ptr: *anyopaque = std.c.malloc(@sizeOf(T)) orelse @panic("C allocation failed!");
        const ptr: *T = @ptrCast(@alignCast(c_ptr));
        ptr.* = T{};

        return Self{
            .cache = @ptrCast(@alignCast(ptr)),
        };
    }

    pub fn initWithDefaultValue(comptime T: type, value: T) Self {
        const c_ptr: *anyopaque = std.c.malloc(@sizeOf(T)) orelse @panic("C allocation failed!");
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

    pub fn callSafe(self: *Self, event: Events, store: *zap.Store) void {
        defer FreeingCAllocations: {
            if (event != .deinit) break :FreeingCAllocations;

            std.c.free(self.cache);
            std.log.info("BEHAVIOUR: [DEINIT] C memory Cache freed!", .{});
        }

        const func = switch (event) {
            .awake => self.awake,
            .init => self.init,
            .update => self.update,
            .tick => self.tick,
            .deinit => self.deinit,
        } orelse return;

        func(store, self.cache) catch {
            std.log.err("Error when calling Behaviour event!", .{});
        };
    }

    pub fn CacheCast(comptime T: type, ptr: *anyopaque) *T {
        return @ptrCast(@alignCast(ptr));
    }
};
