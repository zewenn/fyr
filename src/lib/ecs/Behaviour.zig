const std = @import("std");
const builtin = @import("builtin");

const Entity = @import("Entity.zig");

const FnType = ?(*const fn (self: *anyopaque, entity: *Entity) anyerror!void);
pub const Events = enum { awake, start, update, tick, end };
const Error = error{OutOfMemory};
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
hash: u64,
is_alive: bool = false,
initalised: bool = false,

awake: FnType = null,
start: FnType = null,
update: FnType = null,
tick: FnType = null,
end: FnType = null,

pub fn init(value: anytype) !Self {
    const T: type = comptime @TypeOf(value);

    const c_ptr = std.c.malloc(@sizeOf(T)) orelse return Error.OutOfMemory;
    const ptr: *T = @ptrCast(@alignCast(c_ptr));
    ptr.* = value;

    var self = Self{
        .cache = @ptrCast(@alignCast(ptr)),
        .name = @typeName(T),
        .hash = comptime calculateHash(T),
        .is_alive = true,
    };
    self.attachEvents(T);

    return self;
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

pub fn callSafe(self: *Self, event: Events, entity: *Entity) void {
    if (!self.is_alive) return;

    defer if (event == .end and self.is_alive) {
        self.is_alive = false;
        std.c.free(self.cache);
    };

    defer if (event == .awake) {
        self.initalised = true;
    };

    const func = switch (event) {
        .awake => self.awake,
        .start => self.start,
        .update => self.update,
        .tick => self.tick,
        .end => self.end,
    } orelse return;

    func(self.cache, entity) catch {
        std.log.err("behaviour event failed ({s}({x})->{s}.{s})", .{
            entity.id,
            entity.uuid,
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
            if (info.params[0].type == *T and info.params[1].type == *Entity) return FunctionType.generic;
            if (info.params[0].type == *Entity and info.params[1].type == *T) return FunctionType.reversed;
        },
        1 => {
            if (info.params[0].type == *T) return FunctionType.self_only;
            if (info.params[0].type == *Entity) return FunctionType.entity_only;
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

    const wrapper = struct {
        fn call(comptime fn_name: []const u8, cache: *anyopaque, entity: *Entity) !void {
            std.debug.assert(std.meta.hasFn(T, fn_name));

            const func = comptime @field(T, fn_name);
            const typeinfo = comptime @typeInfo(@TypeOf(func)).@"fn";

            if (comptime (typeinfo.return_type.? == void))
                switch (comptime determineFunctionType(T, typeinfo) orelse return) {
                    .generic => @call(.auto, func, .{ @as(*T, @ptrCast(@alignCast(cache))), entity }),
                    .reversed => @call(.auto, func, .{ entity, @as(*T, @ptrCast(@alignCast(cache))) }),
                    .self_only => @call(.auto, func, .{@as(*T, @ptrCast(@alignCast(cache)))}),
                    .entity_only => @call(.auto, func, .{entity}),
                    .empty => @call(.auto, func, .{}),
                }
            else
                try switch (comptime determineFunctionType(T, typeinfo) orelse return) {
                    .generic => @call(.auto, func, .{ @as(*T, @ptrCast(@alignCast(cache))), entity }),
                    .reversed => @call(.auto, func, .{ entity, @as(*T, @ptrCast(@alignCast(cache))) }),
                    .self_only => @call(.auto, func, .{@as(*T, @ptrCast(@alignCast(cache)))}),
                    .entity_only => @call(.auto, func, .{entity}),
                    .empty => @call(.auto, func, .{}),
                };
        }

        pub fn awake(cache: *anyopaque, entity: *Entity) !void {
            try call("Awake", cache, entity);
        }

        pub fn start(cache: *anyopaque, entity: *Entity) !void {
            try call("Start", cache, entity);
        }
        pub fn end(cache: *anyopaque, entity: *Entity) !void {
            try call("End", cache, entity);
        }

        pub fn update(cache: *anyopaque, entity: *Entity) !void {
            try call("Update", cache, entity);
        }
        pub fn tick(cache: *anyopaque, entity: *Entity) !void {
            try call("Tick", cache, entity);
        }
    };

    if (std.meta.hasFn(T, "Awake")) self.add(.awake, wrapper.awake);

    if (std.meta.hasFn(T, "Start")) self.add(.start, wrapper.start);
    if (std.meta.hasFn(T, "End")) self.add(.end, wrapper.end);

    if (std.meta.hasFn(T, "Update")) self.add(.update, wrapper.update);
    if (std.meta.hasFn(T, "Tick")) self.add(.tick, wrapper.tick);
}

pub fn castBack(self: *Self, comptime T: type) ?*T {
    return if (self.isType(T)) @ptrCast(@alignCast(self.cache)) else null;
}

pub inline fn isType(self: *Self, comptime T: type) bool {
    return self.hash == comptime calculateHash(T);
}

pub inline fn calculateHash(comptime T: type) u64 {
    const name_hash: comptime_int = comptime switch (@typeInfo(T)) {
        .@"struct", .@"enum" => blk: {
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

            break :blk fieldsum;
        },
        else => 1,
    };

    return (@max(1, @sizeOf(T)) * @max(1, @alignOf(T)) +
        @max(1, @bitSizeOf(T)) * @max(1, @alignOf(T)) +
        name_hash * @max(1, @alignOf(T)) * 13) % std.math.maxInt(u63);
}
