const std = @import("std");
const Allocator = @import("std").mem.Allocator;

pub const Scene = @import("./Scene.zig");
const fyr = @import("../../main.zig");

var Scenes: ?std.StringHashMap(*Scene) = null;
var next_Scene: ?*Scene = null;

pub var active_scene: ?*Scene = null;
pub var open_scene: ?*Scene = null;

var unload_next_frame = false;

var tick_time: f64 = 1.0;
var last_tick: f64 = 0;
var last_update: f64 = 0;

pub fn setTickTarget(comptime target: comptime_float) void {
    tick_time = 1 / target;
}

pub const Events = enum(Scene.Target) { awake, start, update, tick, end };

const EventLoopErrors = error{
    EventLoopWasntInitalised,
    OutOfMemory,
};

pub fn init() !void {
    Scenes = std.StringHashMap(*Scene).init(
        fyr.getAllocator(.generic),
    );
}

pub fn new(comptime id: []const u8) EventLoopErrors!*Scene {
    if (Scenes == null) {
        std.log.warn("Eventloop wasn't initalised!", .{});
        return EventLoopErrors.EventLoopWasntInitalised;
    }

    const ptr = &(Scenes.?);
    const Sceneptr = try fyr.getAllocator(.generic).create(Scene);
    Sceneptr.* = Scene.init(fyr.getAllocator(.generic), id);

    if (!ptr.contains(id)) {
        try ptr.put(id, Sceneptr);
    }

    const scene_ptr = ptr.get(id).?;

    return scene_ptr;
}

pub fn remove(comptime id: []const u8) void {
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

pub fn execute() !void {
    const now = fyr.rl.getTime();

    const do_tick = last_tick + tick_time <= now;
    defer if (do_tick) {
        last_tick = now;
    };

    const scene = active_scene orelse return;

    if (scene.entities) |s|
        for (s.items) |Entity| executeEntityBehaviour(Entity, do_tick);

    try scene.call(Events.update);
    last_update = now;

    if (do_tick)
        try scene.call(Events.tick);

    if (!unload_next_frame) return;
    unload_next_frame = false;

    defer active_scene = next_Scene;

    try scene.call(Events.end);
    scene.reset();
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
        _scene.call(Events.start) catch {
            std.log.warn("OutOfMemory when calling Scene event", .{});
        };
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

    var iterator = ptr.iterator();
    while (iterator.next()) |entry| {
        entry.value_ptr.*.deinit();
        fyr.getAllocator(.generic).destroy(entry.value_ptr.*);
    }
}

pub inline fn unload() void {
    unload_next_frame = true;
}
