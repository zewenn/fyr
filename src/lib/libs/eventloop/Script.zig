const std = @import("std");
const fyr = @import("../../main.zig");

const FnType = ?(*const fn (self: *anyopaque) anyerror!void);
const Events = enum { awake, start, update, ui, tick, end };
const AllocationError = error.OutOfMemory;

const Self = @This();

cache: *anyopaque,
name: []const u8 = "[UNNAMED]",

awake: FnType = null,
start: FnType = null,
update: FnType = null,
ui: FnType = null,
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
        .ui => self.ui = callback,
        .end => self.end = callback,
    }
}

pub fn callSafe(self: *Self, event: Events) void {
    defer FreeingCAllocations: {
        if (event != .end) break :FreeingCAllocations;

        if (fyr.lib_info.build_mode == .Debug) std.c.free(self.cache);
    }

    const func = switch (event) {
        .awake => self.awake,
        .start => self.start,
        .update => self.update,
        .tick => self.tick,
        .ui => self.ui,
        .end => self.end,
    } orelse return;

    func(self.cache) catch {
        std.log.err("failed to call behaviour event ({s}.{s})", .{
            self.name,
            switch (event) {
                .awake => "Awake",
                .start => "Start",
                .end => "End",
                .update => "Update",
                .ui => "UI",
                .tick => "Tick",
            },
        });
    };
}

fn attachEvents(b: *Self, comptime T: type) void {
    const t = struct {
        pub fn awake(cache: *anyopaque) !void {
            try @field(T, "Awake")(@ptrCast(@alignCast(cache)));
        }

        pub fn start(cache: *anyopaque) !void {
            try @field(T, "Start")(@ptrCast(@alignCast(cache)));
        }
        pub fn end(cache: *anyopaque) !void {
            try @field(T, "End")(@ptrCast(@alignCast(cache)));
        }

        pub fn update(cache: *anyopaque) !void {
            try @field(T, "Update")(@ptrCast(@alignCast(cache)));
        }
        pub fn ui(cache: *anyopaque) !void {
            try @field(T, "UI")(@ptrCast(@alignCast(cache)));
        }
        pub fn tick(cache: *anyopaque) !void {
            try @field(T, "Tick")(@ptrCast(@alignCast(cache)));
        }
    };

    if (std.meta.hasFn(T, "Awake")) {
        b.add(.awake, t.awake);
    }

    if (std.meta.hasFn(T, "Start")) {
        b.add(.start, t.start);
    }
    if (std.meta.hasFn(T, "End")) {
        b.add(.end, t.end);
    }

    if (std.meta.hasFn(T, "Update")) {
        b.add(.update, t.update);
    }
    if (std.meta.hasFn(T, "UI")) {
        b.add(.ui, t.ui);
    }
    if (std.meta.hasFn(T, "Tick")) {
        b.add(.tick, t.tick);
    }
}

pub fn from(obj: anytype) !Self {
    const T: type = @TypeOf(obj);

    var self = try Self.initWithValue(obj);
    self.attachEvents(T);

    return self;
}

pub inline fn isScript(value: anytype) bool {
    return comptime @hasDecl(@TypeOf(value), "FYR_SCRIPT");
}

pub inline fn isScriptType(T: type) bool {
    return comptime @hasDecl(T, "FYR_SCRIPT");
}
