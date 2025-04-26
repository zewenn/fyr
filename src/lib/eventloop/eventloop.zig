const std = @import("std");
const Allocator = @import("std").mem.Allocator;

pub const Scene = @import("./Scene.zig");
const Error = error{
    NotInitalised,
    SceneNotFound,
};

var scenes: ?std.ArrayList(*Scene) = null;
pub var active_scene: ?*Scene = null;
pub var open_scene: ?*Scene = null;
var alloc = std.heap.smp_allocator;

pub fn init(allocator: Allocator) void {
    scenes = .init(allocator);
    alloc = allocator;
}

pub fn deinit() void {
    const s = scenes orelse return;
    for (s.items) |scene| {
        scene.deinit();
        alloc.destroy(scene);
    }
    s.deinit();
}

pub fn addScene(scene: Scene) !void {
    const scenes_ptr = &(scenes orelse return Error.NotInitalised);
    const ptr = try alloc.create(Scene);
    ptr.* = scene;

    try scenes_ptr.append(ptr);
    open_scene = ptr;
}

pub fn setActive(id: []const u8) !void {
    const scenes_ptr = &(scenes orelse return Error.NotInitalised);
    for (scenes_ptr.items) |scene| {
        if (!std.mem.eql(u8, scene.id, id)) continue;

        if (active_scene) |ascene| {
            ascene.unload();
        }

        active_scene = scene;
        try scene.load();
        return;
    }
    return Error.SceneNotFound;
}

pub fn close() void {
    open_scene = null;
}