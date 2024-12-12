const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const Instance = @import("./Instance.zig");
const zap = @import("../../main.zig");

var instances: ?std.AutoHashMap(Instance.EventEnumTarget, Instance) = null;

pub const SceneEvents = enum(Instance.EventEnumTarget) {
    awake = 0,
    init = 1,
    deinit = 2,
    update = 3,
    tick = 4,
};

pub const EngineEvents = enum(Instance.EventEnumTarget) {
    awake = -50,
    init = -51,
    deinit = -52,
    update = -53,
    tick = -54,
};

pub fn init() !void {
    instances = std.AutoHashMap(Instance.EventEnumTarget, Instance).init(
        zap.getAllocator(.gpa),
    );
}

pub fn deinit() void {
    const instptr = &(instances orelse return);
    instptr.deinit();
}
