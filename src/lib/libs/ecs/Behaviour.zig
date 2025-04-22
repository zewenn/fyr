const std = @import("std");
const fyr = @import("../../main.zig");

const FnType = ?(*const fn (self: *anyopaque, entity: *fyr.Entity) anyerror!void);
const Events = enum { awake, start, update, tick, end };
const AllocationError = error.OutOfMemory;
const FunctionType = enum {
    generic,
    reversed,
    self_only,
    entity_only,
    empty,
};

const Self = @This();

cache: *anyopaque,
name: []const u8 = "[UNNAMED]",

awake: FnType = null,
start: FnType = null,
update: FnType = null,
tick: FnType = null,
end: FnType = null,

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
        .name = @typeName(T),
    };
}

pub fn add(self: *Self, event: Events, callback: FnType) void {
    switch (event) {
        .awake => self.awake = callback,
        .start => self.start = callback,
        .update => self.update = callback,
        .tick => self.tick = callback,
        .end => self.end = callback,
    }
}

pub fn callSafe(self: *Self, event: Events, entity: *fyr.Entity) void {
    defer FreeingCAllocations: {
        if (event != .end) break :FreeingCAllocations;

        if (fyr.lib_info.build_mode == .Debug) std.c.free(self.cache);
    }

    const func = switch (event) {
        .awake => self.awake,
        .start => self.start,
        .update => self.update,
        .tick => self.tick,
        .end => self.end,
    } orelse return;

    func(self.cache, entity) catch {
        std.log.err("failed to call behaviour event ({s}.{s})", .{
            self.name,
            switch (event) {
                .awake => "Awake",
                .start => "Start",
                .end => "End",
                .update => "Update",
                .tick => "Tick",
            },
        });
    };
}

inline fn determineFunctionType(comptime T: type, comptime info: std.builtin.Type.Fn) ?FunctionType {
    switch (info.params.len) {
        2 => {
            if (info.params[0].type == *T and info.params[1].type == *fyr.Entity) return FunctionType.generic;
            if (info.params[0].type == *fyr.Entity and info.params[1].type == *T) return FunctionType.reversed;
        },
        1 => {
            if (info.params[0].type == *T) return FunctionType.self_only;
            if (info.params[0].type == *fyr.Entity) return FunctionType.entity_only;
        },
        0 => {
            return FunctionType.empty;
        },
        else => {},
    }
    return null;
}

fn attachEvents(self: *Self, comptime T: type) void {
    // 5 Function types are excepted
    //  - fn(*Self, *Entity) - Generic
    //  - fn(*Entity, *Self) - Reversed
    //  - fn(*Self)          - SelfOnly
    //  - fn(*Entity)        - EntityOnly
    //  - fn()               - Empty

    const t = struct {
        fn call(comptime fn_name: []const u8, cache: *anyopaque, entity: *fyr.Entity) !void {
            std.debug.assert(std.meta.hasFn(T, fn_name));
            const func = comptime @field(T, fn_name);
            const typeinfo = comptime @typeInfo(@TypeOf(func)).@"fn";

            try switch (comptime determineFunctionType(T, typeinfo) orelse return) {
                .generic => @call(.auto, func, .{ @as(*T, @ptrCast(@alignCast(cache))), entity }),
                .reversed => @call(.auto, func, .{ entity, @as(*T, @ptrCast(@alignCast(cache))) }),
                .self_only => @call(.auto, func, .{@as(*T, @ptrCast(@alignCast(cache)))}),
                .entity_only => @call(.auto, func, .{entity}),
                .empty => @call(.auto, func, .{}),
            };
        }

        pub fn awake(cache: *anyopaque, entity: *fyr.Entity) !void {
            try call("Awake", cache, entity);
        }

        pub fn start(cache: *anyopaque, entity: *fyr.Entity) !void {
            try call("Start", cache, entity);
        }
        pub fn end(cache: *anyopaque, entity: *fyr.Entity) !void {
            try call("End", cache, entity);
        }

        pub fn update(cache: *anyopaque, entity: *fyr.Entity) !void {
            try call("Update", cache, entity);
        }
        pub fn tick(cache: *anyopaque, entity: *fyr.Entity) !void {
            try call("Tick", cache, entity);
        }
    };

    if (std.meta.hasFn(T, "Awake")) {
        self.add(.awake, t.awake);
    }

    if (std.meta.hasFn(T, "Start")) {
        self.add(.start, t.start);
    }
    if (std.meta.hasFn(T, "End")) {
        self.add(.end, t.end);
    }

    if (std.meta.hasFn(T, "Update")) {
        self.add(.update, t.update);
    }
    if (std.meta.hasFn(T, "Tick")) {
        self.add(.tick, t.tick);
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
