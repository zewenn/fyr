const std = @import("std");
const fyr = @import("../../main.zig");

const FnType = ?(*const fn (self: *anyopaque, entity: *fyr.Entity) anyerror!void);
const Events = enum { awake, init, update, tick, deinit };
const AllocationError = error.OutOfMemory;

const Self = @This();

cache: *anyopaque,
_name: []const u8 = "[UNNAMED]",
awake: FnType = null,
init: FnType = null,
update: FnType = null,
tick: FnType = null,
deinit: FnType = null,

pub fn init(comptime T: type) !Self {
    return initWithValue(T{});
}

pub fn initWithValue(value: anytype) !Self {
    const T: type = comptime @TypeOf(value);

    const c_ptr = std.c.malloc(@sizeOf(T)) orelse return AllocationError;
    const ptr: *T = @ptrCast(@alignCast(c_ptr));
    ptr.* = value;

    return Self{
        .cache = @ptrCast(@alignCast(ptr)),
        ._name = @typeName(T),
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

        if (fyr.lib_info.build_mode == .Debug) {
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

    func(self.cache, entity) catch {
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

fn attachEvents(b: *Self, comptime T: type) void {
    const t = struct {
        pub fn awake(cache: *anyopaque, entity: *fyr.Entity) !void {
            try @field(T, "awake")(@ptrCast(@alignCast(cache)), entity);
        }

        pub fn init(cache: *anyopaque, entity: *fyr.Entity) !void {
            try @field(T, "init")(@ptrCast(@alignCast(cache)), entity);
        }
        pub fn deinit(cache: *anyopaque, entity: *fyr.Entity) !void {
            try @field(T, "deinit")(@ptrCast(@alignCast(cache)), entity);
        }

        pub fn update(cache: *anyopaque, entity: *fyr.Entity) !void {
            try @field(T, "update")(@ptrCast(@alignCast(cache)), entity);
        }
        pub fn tick(cache: *anyopaque, entity: *fyr.Entity) !void {
            try @field(T, "tick")(@ptrCast(@alignCast(cache)), entity);
        }
    };

    if (std.meta.hasFn(T, "awake")) {
        b.add(.awake, t.awake);
    }

    if (std.meta.hasFn(T, "init")) {
        b.add(.init, t.init);
    }
    if (std.meta.hasFn(T, "deinit")) {
        b.add(.deinit, t.deinit);
    }

    if (std.meta.hasFn(T, "update")) {
        b.add(.update, t.update);
    }
    if (std.meta.hasFn(T, "tick")) {
        b.add(.tick, t.tick);
    }
}

pub fn from(obj: anytype) !Self {
    const T: type = @TypeOf(obj);

    var self = try Self.initWithValue(obj);
    self.attachEvents(T);

    return self;
}

pub inline fn isBehaviourBase(value: anytype) bool {
    return comptime @hasDecl(@TypeOf(value), "FYR_BEHAVIOUR");
}

pub inline fn isBehvaiourBaseType(T: type) bool {
    return comptime @hasDecl(T, "FYR_BEHAVIOUR");
}
