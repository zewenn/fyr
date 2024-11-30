const rl = @import("raylib");
const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const z = @import("./z/z.m.zig");
const entities = @import("./engine.m.zig").entities;
const events = @import("./events.m.zig");
const GUI = @import("./gui/gui.m.zig");

pub const Script = struct {
    const fn_type: type = *const fn () anyerror!void;
    const fn_type_safe: type = *const fn () void;
    const Self = @This();

    eAwake: ?fn_type = null,
    eInit: ?fn_type = null,
    eUpdate: ?fn_type = null,
    eDeinit: ?fn_type = null,
};

const map_fn_type = *const fn () anyerror!void;
const String = []const u8;
const map_type = std.StringHashMap(std.ArrayList(Script));

pub var current: ?[]const u8 = null;

var script_map: map_type = undefined;
var alloc: Allocator = undefined;

pub fn init(allocator: Allocator) void {
    script_map = map_type.init(allocator);
    alloc = allocator;
}

pub fn deinit() void {
    var iterator = script_map.keyIterator();

    while (iterator.next()) |item| {
        const arr = script_map.get(item.*);
        if (arr != null) arr.?.deinit();

        _ = script_map.remove(item.*);
    }
    script_map.deinit();
}

pub fn clear() void {
    var kIt = script_map.keyIterator();

    while (kIt.next()) |item| {
        const arr = script_map.get(item.*);
        if (arr != null) arr.?.deinit();

        _ = script_map.remove(item.*);
    }
    script_map.clearAndFree();
}

pub fn register(comptime id: String, script: Script) !void {
    const data = script_map.getPtr(id);

    if (data) |_data| {
        try _data.append(script);
        return;
    }

    var new_array = std.ArrayList(Script).init(alloc);
    try new_array.append(script);
    try script_map.put(id, new_array);
}

pub fn load(comptime id: String) !void {
    if (current) |_| {
        events.call(.Deinit);
    }

    current = id;

    events.clear();
    try GUI.clear();
    entities.clear();

    const data = script_map.get(id);

    if (data == null) {
        return;
    }

    for (data.?.items) |script| {
        if (script.eAwake) |e| {
            try events.on(.Awake, e);
        }
        if (script.eInit) |e| {
            try events.on(.Init, e);
        }
        if (script.eUpdate) |e| {
            try events.on(.Update, e);
        }
        if (script.eDeinit) |e| {
            try events.on(.Deinit, e);
        }
    }

    events.call(.Awake);
    events.call(.Init);
}

pub fn delete(comptime id: String) !void {
    _ = script_map.remove(id);
}
