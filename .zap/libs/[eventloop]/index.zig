const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const TICK_TARGET: comptime_float = 20;

const Instance = @import("./Instance.zig");
const zap = @import("../../main.zig");

var instances: ?std.StringHashMap(*Instance) = null;
var active_instance: ?*Instance = null;
var engine_instance: ?*Instance = null;

const executing_instances = [2]*?*Instance{ &active_instance, &engine_instance };

const tick_time: f64 = 1.0 / TICK_TARGET;
var last_tick: f64 = 0;
var last_update: f64 = 0;

pub const Events = enum(Instance.Target) {
    awake = 0,
    init = 1,
    deinit = 2,
    update = 3,
    tick = 4,
};

const EventLoopErrors = error{
    EventLoopWasntInitalised,
    OutOfMemory,
};

pub fn init() !void {
    instances = std.StringHashMap(*Instance).init(
        zap.getAllocator(.gpa),
    );

    const ptr = &(instances.?);

    const instanceptr = try zap.getAllocator(.gpa).create(Instance);
    instanceptr.* = Instance.init(zap.getAllocator(.gpa));

    ptr.put("engine", instanceptr) catch @panic("Failed to create default Instance. (eventloop)");
}

pub fn new(comptime id: []const u8) EventLoopErrors!*Instance {
    if (std.mem.eql(u8, id, "engine")) @panic("Id \"engine\" is reserved for default instance (eventloop)!");
    if (instances == null) {
        std.log.warn("Eventloop wasn't initalised!", .{});
        return EventLoopErrors.EventLoopWasntInitalised;
    }

    const ptr = &(instances.?);
    const instanceptr = try zap.getAllocator(.gpa).create(Instance);
    instanceptr.* = Instance.init(zap.getAllocator(.gpa));

    if (!ptr.contains(id)) {
        try ptr.put(id, instanceptr);
    }

    return ptr.get(id).?;
}

pub fn remove(comptime id: []const u8) void {
    if (std.mem.eql(u8, id, "engine")) @panic("Id \"engine\" is reserved for default instance, thus it cannot be removed (eventloop)!");
    if (instances == null) {
        std.log.warn("Eventloop wasn't initalised!", .{});
        return;
    }

    const ptr = &(instances.?);

    const instance_ptr = ptr.get(id);
    if (instance_ptr == active_instance) {
        active_instance = null;
    }

    ptr.remove(id);
}

pub fn get(id: []const u8) ?*Instance {
    if (instances == null) {
        std.log.warn("Eventloop wasn't initalised!", .{});
        return null;
    }

    const ptr = &(instances.?);

    return ptr.get(id);
}

pub fn execute() !void {
    const now = zap.libs.raylib.getTime();

    const do_tick = last_tick + tick_time <= now;
    // Defer used so ticking takes instance event call times into account
    defer if (do_tick) {
        last_tick = now;
    };

    for (executing_instances) |entry| {
        const instance = entry.* orelse continue;

        if (instance.stores) |s|
            for (s.items) |store| executeStoreBehaviour(store, do_tick);

        try instance.call(Events.update);
        last_update = now;

        if (!do_tick) continue;
        try instance.call(Events.tick);
    }
}

fn executeStoreBehaviour(store: *zap.Store, do_tick: bool) void {
    const behaviour = store.getComponent(zap.Behaviour) orelse return;
    behaviour.callSafe(.update, store);

    if (!do_tick) return;
    behaviour.callSafe(.tick, store);
}

pub fn setActive(id: []const u8) !void {
    if (instances == null) {
        std.log.warn("Eventloop wasn't initalised!", .{});
        return;
    }

    const ptr = &(instances.?);
    const instance = ptr.get(id) orelse return;
    defer {
        instance.call(Events.awake) catch {
            std.log.warn("OutOfMemory when calling instance event", .{});
        };
        instance.call(Events.init) catch {
            std.log.warn("OutOfMemory when calling instance event", .{});
        };
    }

    if (std.mem.eql(u8, id, "engine")) {
        engine_instance = instance;
        return;
    }

    defer active_instance = instance;
    const ai = active_instance orelse return;

    // Dispatch the deinit event
    try ai.call(Events.deinit);
    // Free all allocations with ai.allocator()
    ai.reset();

    // Currently does not do anything
    ai.executing = false;
}

pub fn deinit() void {
    const ptr = &(instances orelse return);
    defer ptr.deinit();

    var iterator = ptr.iterator();
    while (iterator.next()) |entry| {
        entry.value_ptr.*.deinit();
        zap.getAllocator(.gpa).destroy(entry.value_ptr.*);
    }
}
