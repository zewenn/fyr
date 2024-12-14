const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const Instance = @import("./Instance.zig");
const zap = @import("../../main.zig");

var instances: ?std.AutoHashMap(Instance.EventEnumTarget, Instance) = null;
var executing: ?Instance = null;

const tick_time: f64 = 1 / 20;
var last_tick: f64 = 0;
var last_update: f64 = 0;

pub const Events = enum(Instance.EventEnumTarget) {
    awake = 0,
    init = 1,
    deinit = 2,
    update = 3,
    tick = 4,
};

pub fn init() !void {
    instances = std.AutoHashMap(Instance.EventEnumTarget, Instance).init(
        zap.getAllocator(.gpa),
    );

    const ptr = &(instances.?);

    const default_instance = Instance.init(zap.getAllocator(.gpa));
    ptr.put(0, default_instance) catch @panic("Failed to create default Instance. (eventloop)");
}

pub fn new(comptime id: Instance.EventEnumTarget) !Instance {
    if (id == 0) @compileError("Id \"0\" is reserved for default instance (eventloop)!");
    if (instances == null) {
        std.log.warn("Eventloop wasn't initalised!", .{});
        return;
    }

    const ptr = &(instances.?);

    if (!ptr.contains(id)) {
        try ptr.put(id, Instance.init(zap.getAllocator(.gpa)));
    }

    return ptr.get(id).?;
}

pub fn remove(comptime id: Instance.EventEnumTarget) void {
    if (id == 0) @compileError("Id \"0\" is reserved for default instance, thus it cannot be removed (eventloop)!");
    if (instances == null) {
        std.log.warn("Eventloop wasn't initalised!", .{});
        return;
    }

    const ptr = &(instances.?);

    ptr.remove(id);
}

pub fn get(id: Instance.EventEnumTarget) ?Instance {
    if (instances == null) {
        std.log.warn("Eventloop wasn't initalised!", .{});
        return;
    }

    const ptr = &(instances.?);

    return ptr.get(id);
}

pub fn execute() !void {
    const exec = executing orelse return;

    exec.call(Events.update);
    last_update = zap.libs.raylib.getTime();

    if (last_tick <= tick_time + zap.libs.raylib.getTime()) {
        exec.call(Events.tick);
        last_tick = zap.libs.raylib.getTime();
    }
}

pub fn setActive(id: Instance.EventEnumTarget) !void {
    if (instances == null) {
        std.log.warn("Eventloop wasn't initalised!", .{});
        return;
    }

    const ptr = &(instances.?);
    const instance = ptr.get(id) orelse return;

    if (executing) |exec| {
        exec.call(Events.deinit);
    }

    executing = instance;
    const exec = executing orelse return;

    exec.call(Events.awake);
    exec.call(Events.init);
}

pub fn deinit() void {
    const instptr = &(instances orelse return);
    defer instptr.deinit();

    var iterator = instptr.iterator();
    while (iterator.next()) |entry| {
        entry.value_ptr.deinit();
    }
}
