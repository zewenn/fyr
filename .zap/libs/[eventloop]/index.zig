const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const TICK_TARGET: comptime_float = 20;

pub const Instance = @import("./Instance.zig");
const zap = @import("../../main.zig");

var instances: ?std.StringHashMap(*Instance) = null;
pub var active_instance: ?*Instance = null;
var next_instance: ?*Instance = null;
var engine_instance: ?*Instance = null;

var _unload = false;

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

/// Executes the main event loop, handling instance updates and ticks.
///
/// This function performs the following tasks:
/// - Retrieves the current time using `zap.libs.raylib.getTime()`.
/// - Determines if a tick should occur based on the elapsed time since the last tick.
/// - Iterates over all executing instances and performs the following:
///   - Executes store behaviour if the instance has stores.
///   - Calls the `update` event on the instance.
///   - Calls the `tick` event on the instance if a tick is due.
/// - Handles unloading of instances if `_unload` is set to true:
///   - Dispatches the `deinit` event to the active instance.
///   - Frees all allocations associated with the active instance.
///   - Resets the active instance.
pub fn execute() !void {
    // Note:
    // - The `defer` statement is used to ensure that `last_tick` is updated after ticking.
    // - The function uses `orelse continue` to skip over `null` entries in the `executing_instances` array.
    // - The `active_instance` is set to `next_instance` after unloading.

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

    if (!_unload) return;
    _unload = false;
    defer active_instance = next_instance;
    const ai = active_instance orelse return;

    // Dispatch the deinit event
    try ai.call(Events.deinit);
    // Free all allocations with ai.allocator()
    ai.reset();

    // Currently does not do anything
    ai.executing = false;
}

fn executeStoreBehaviour(store: *zap.Store, do_tick: bool) void {
    const behaviours = store.getComponents(zap.Behaviour) catch &[_]*zap.Behaviour{};
    for (behaviours) |b| {
        b.callSafe(.update, store);

        if (!do_tick) continue;
        b.callSafe(.tick, store);
    }
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

    if (!zap.isLoopRunning()) {
        active_instance = instance;
        return;
    }

    next_instance = instance;
    unload();
}

pub fn deinit() void {
    const ptr = &(instances orelse return);
    defer ptr.deinit();

    unload();
    execute() catch {};
    engine_instance.?.call(Events.deinit) catch {};

    var iterator = ptr.iterator();
    while (iterator.next()) |entry| {
        entry.value_ptr.*.deinit();
        zap.getAllocator(.gpa).destroy(entry.value_ptr.*);
    }
}

pub fn unload() void {
    _unload = true;
}
