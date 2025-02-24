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
    return initWithValue(T{});
}

pub fn initWithValue(value: anytype) !Self {
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

fn attachEvents(b: *Self, comptime T: type) void {
    const t = struct {
        pub fn awake(entity: *fyr.Entity, cache: *anyopaque) !void {
            try @field(T, "awake")(entity, @ptrCast(@alignCast(cache)));
        }

        pub fn init(entity: *fyr.Entity, cache: *anyopaque) !void {
            try @field(T, "init")(entity, @ptrCast(@alignCast(cache)));
        }
        pub fn deinit(entity: *fyr.Entity, cache: *anyopaque) !void {
            try @field(T, "deinit")(entity, @ptrCast(@alignCast(cache)));
        }

        pub fn update(entity: *fyr.Entity, cache: *anyopaque) !void {
            try @field(T, "update")(entity, @ptrCast(@alignCast(cache)));
        }
        pub fn tick(entity: *fyr.Entity, cache: *anyopaque) !void {
            try @field(T, "tick")(entity, @ptrCast(@alignCast(cache)));
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

pub fn impl(comptime T: type) *const fn () anyerror!Self {
    return (struct {
        pub fn this() !Self {
            var b = try Self.init(T);

            b.attachEvents(T);

            return b;
        }
    }).this;
}

pub fn factoryAutoInferArgument(comptime T: type) *const fn (if (@typeInfo(@TypeOf(@field(T, "create"))).Fn.params[0].type) |t| t else @TypeOf(null)) anyerror!Self {
    return (struct {
        const can_create = Blk: {
            if (!std.meta.hasFn(T, "create")) break :Blk false;
            const typeinfo = @typeInfo(@TypeOf(@field(T, "create")));
            if (typeinfo != .Fn)
                break :Blk false;

            if (typeinfo.Fn.return_type != T)
                break :Blk false;

            break :Blk true;
        };

        const argstype = @typeInfo(@TypeOf(@field(T, "create"))).Fn.params[0].type orelse @TypeOf(null);

        pub fn this(argument: argstype) !Self {
            var b: Self = undefined;

            if (can_create) {
                const Tinstance = @call(
                    .auto,
                    @field(T, "create"),
                    .{argument},
                );
                b = try Self.initWithValue(Tinstance);
            } else {
                b = try Self.init(T);
            }

            b.attachEvents(T);

            return b;
        }
    }).this;
}

pub fn factoryWithArgument(comptime A: type, comptime T: type) *const fn (A) anyerror!Self {
    return (struct {
        const can_create = Blk: {
            if (!std.meta.hasFn(T, "create")) break :Blk false;
            const typeinfo = @typeInfo(@TypeOf(@field(T, "create")));
            if (typeinfo != .Fn)
                break :Blk false;

            if (typeinfo.Fn.return_type != T)
                break :Blk false;

            break :Blk true;
        };

        pub fn this(argument: A) !Self {
            var b: Self = undefined;

            if (can_create) {
                const Tinstance = @call(
                    .auto,
                    @field(T, "create"),
                    .{argument},
                );
                b = try Self.initWithValue(Tinstance);
            } else {
                b = try Self.init(T);
            }

            b.attachEvents(T);

            return b;
        }
    }).this;
}

pub inline fn CacheCast(comptime T: type, ptr: *anyopaque) *T {
    return @ptrCast(@alignCast(ptr));
}
