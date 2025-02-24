const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const TICK_TARGET: comptime_float = 20;

pub const Scene = @import("./Scene.zig");
const fyr = @import("../../main.zig");

var Scenes: ?std.StringHashMap(*Scene) = null;
pub var active_scene: ?*Scene = null;
var next_Scene: ?*Scene = null;
var engine_scene: ?*Scene = null;

var _unload = false;

pub var open_scene: ?*Scene = null;

const executing_scenes = [2]*?*Scene{ &active_scene, &engine_scene };

const tick_time: f64 = 1.0 / TICK_TARGET;
var last_tick: f64 = 0;
var last_update: f64 = 0;

pub const Events = enum(Scene.Target) {
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
    Scenes = std.StringHashMap(*Scene).init(
        fyr.getAllocator(.gpa),
    );

    const ptr = &(Scenes.?);

    const Sceneptr = try fyr.getAllocator(.gpa).create(Scene);
    Sceneptr.* = Scene.init(fyr.getAllocator(.gpa), "engine");

    ptr.put("engine", Sceneptr) catch @panic("Failed to create default Scene. (eventloop)");
}

pub fn new(comptime id: []const u8) EventLoopErrors!*Scene {
    if (std.mem.eql(u8, id, "engine")) @panic("Id \"engine\" is reserved for default Scene (eventloop)!");
    if (Scenes == null) {
        std.log.warn("Eventloop wasn't initalised!", .{});
        return EventLoopErrors.EventLoopWasntInitalised;
    }

    const ptr = &(Scenes.?);
    const Sceneptr = try fyr.getAllocator(.gpa).create(Scene);
    Sceneptr.* = Scene.init(fyr.getAllocator(.gpa), id);

    if (!ptr.contains(id)) {
        try ptr.put(id, Sceneptr);
    }

    const scene_ptr = ptr.get(id).?;

    return scene_ptr;
}

pub fn remove(comptime id: []const u8) void {
    if (std.mem.eql(u8, id, "engine")) @panic("Id \"engine\" is reserved for default Scene, thus it cannot be removed (eventloop)!");
    if (Scenes == null) {
        std.log.warn("Eventloop wasn't initalised!", .{});
        return;
    }

    const ptr = &(Scenes.?);

    const Scene_ptr = ptr.get(id);
    if (Scene_ptr == active_scene) {
        active_scene = null;
    }

    ptr.remove(id);
}

pub fn get(id: []const u8) ?*Scene {
    if (Scenes == null) {
        std.log.warn("Eventloop wasn't initalised!", .{});
        return null;
    }

    const ptr = &(Scenes.?);

    return ptr.get(id);
}

/// Executes the main event loop, handling Scene updates and ticks.
///
/// This function performs the following tasks:
/// - Retrieves the current time using `fyr.rl.getTime()`.
/// - Determines if a tick should occur based on the elapsed time since the last tick.
/// - Iterates over all executing Scenes and performs the following:
///   - Executes Entity behaviour if the Scene has Entitys.
///   - Calls the `update` event on the Scene.
///   - Calls the `tick` event on the Scene if a tick is due.
/// - Handles unloading of Scenes if `_unload` is set to true:
///   - Dispatches the `deinit` event to the active Scene.
///   - Frees all allocations associated with the active Scene.
///   - Resets the active Scene.
pub fn execute() !void {
    // Note:
    // - The `defer` statement is used to ensure that `last_tick` is updated after ticking.
    // - The function uses `orelse continue` to skip over `null` entries in the `executing_Scenes` array.
    // - The `active_Scene` is set to `next_Scene` after unloading.

    const now = fyr.rl.getTime();

    const do_tick = last_tick + tick_time <= now;
    // Defer used so ticking takes Scene event call times into account
    defer if (do_tick) {
        last_tick = now;
    };

    for (executing_scenes) |entry| {
        const _scene = entry.* orelse continue;

        if (_scene.entities) |s|
            for (s.items) |Entity| executeEntityBehaviour(Entity, do_tick);

        try _scene.call(Events.update);
        last_update = now;

        if (!do_tick) continue;
        try _scene.call(Events.tick);
    }

    if (!_unload) return;
    _unload = false;
    fyr.gui.sceneUnload();

    defer active_scene = next_Scene;
    const ai = active_scene orelse return;

    // Dispatch the deinit event
    try ai.call(Events.deinit);
    // Free all allocations with ai.allocator()
    ai.reset();

    // Currently does not do anything
    ai.executing = false;
}

fn executeEntityBehaviour(Entity: *fyr.Entity, do_tick: bool) void {
    const behaviours = Entity.getBehaviours() catch &[_]*fyr.Behaviour{};
    for (behaviours) |b| {
        b.callSafe(.update, Entity);

        if (!do_tick) continue;
        b.callSafe(.tick, Entity);
    }
}

pub fn setActive(id: []const u8) !void {
    if (Scenes == null) {
        std.log.warn("Eventloop wasn't initalised!", .{});
        return;
    }

    const ptr = &(Scenes.?);
    const _scene = ptr.get(id) orelse return;
    defer {
        _scene.call(Events.awake) catch {
            std.log.warn("OutOfMemory when calling Scene event", .{});
        };
        _scene.call(Events.init) catch {
            std.log.warn("OutOfMemory when calling Scene event", .{});
        };
    }

    if (std.mem.eql(u8, id, "engine")) {
        engine_scene = _scene;
        return;
    }

    if (!fyr.isLoopRunning()) {
        active_scene = _scene;
        return;
    }

    next_Scene = _scene;
    unload();
}

pub fn deinit() void {
    const ptr = &(Scenes orelse return);
    defer ptr.deinit();

    unload();
    execute() catch {};
    engine_scene.?.call(Events.deinit) catch {};

    var iterator = ptr.iterator();
    while (iterator.next()) |entry| {
        entry.value_ptr.*.deinit();
        fyr.getAllocator(.gpa).destroy(entry.value_ptr.*);
    }
}

pub fn unload() void {
    _unload = true;
}
