const std = @import("std");
const Allocator = @import("std").mem.Allocator;
const z = @import("./z/z.m.zig");

pub const EngineEvents = enum {
    Awake,
    Init,
    Update,
    NextFrame,
    Deinit,
};

const map_fn_type = *const fn () anyerror!void;
const map_fn_struct_type = struct {
    unsafe_func: map_fn_type,
    fail_count: u8 = 0,
};
const map_type = std.AutoHashMap(EngineEvents, std.ArrayListAligned(map_fn_struct_type, null));

var event_map: map_type = undefined;
var alloc: Allocator = undefined;

pub fn init(allocator: Allocator) void {
    event_map = map_type.init(allocator);
    alloc = allocator;
}

pub fn deinit() void {
    var iterator = event_map.keyIterator();

    while (iterator.next()) |item| {
        const arr = event_map.get(item.*);
        if (arr != null) arr.?.deinit();

        _ = event_map.remove(item.*);
    }
    event_map.deinit();
}

pub fn clear() void {
    var kIt = event_map.keyIterator();

    while (kIt.next()) |item| {
        const arr = event_map.get(item.*);
        if (arr != null) arr.?.deinit();

        _ = event_map.remove(item.*);
    }
    event_map.clearAndFree();
}

pub fn on(comptime id: EngineEvents, func: map_fn_type) !void {
    const data = event_map.getPtr(id);

    if (data) |d| {
        try d.append(map_fn_struct_type{
            .unsafe_func = func,
        });
        return;
    }

    var new_array = std.ArrayList(map_fn_struct_type).init(alloc);
    try new_array.append(map_fn_struct_type{ .unsafe_func = func });
    try event_map.put(id, new_array);
}

pub fn call(comptime id: EngineEvents) void {
    const data = event_map.getPtr(id) orelse return;

    for (data.items, 0..) |*func_struct, index| {
        if (func_struct.fail_count >= 3) {
            _ = data.swapRemove(index);
            std.log.err("CRITICAL EVENT FAIL: REMOVING FUNCTION", .{});
            break;
        }

        func_struct.unsafe_func() catch {
            func_struct.fail_count += 1;
            std.log.err("Event function failiure: {any}", .{func_struct.unsafe_func});
        };
    }
}

pub fn delete(comptime id: EngineEvents) !void {
    const arr = event_map.getPtr(id);
    if (arr) |arrayList| {
        arrayList.deinit();
    }

    _ = event_map.remove(id);
}
