const std = @import("std");
const zap = @import("../../main.zig");

const FnType = ?(*const fn (*zap.Store) anyerror!void);

pub const Behaviour = struct {
    const Self = @This();

    awake: FnType = null,
    init: FnType = null,
    update: FnType = null,
    tick: FnType = null,
    deinit: FnType = null,

    pub fn callSafe(self: *Self, Fn: enum { awake, init, update, tick, deinit }, store: *zap.Store) void {
        const func = switch (Fn) {
            .awake => self.awake,
            .init => self.init,
            .update => self.update,
            .tick => self.tick,
            .deinit => self.deinit,
        } orelse return;

        func(store) catch {
            std.log.err("Error when calling Behaviour event!", .{});
        };
    }
};
