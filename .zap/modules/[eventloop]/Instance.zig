const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const zap = @import("../../main.zig");

const EventActions = std.ArrayList(Action);
const EventMapType = std.AutoHashMap(EventEnumTarget, EventActions);
const Action = @import("Action.zig");
pub const EventEnumTarget = isize;

const Self = @This();

alloc: Allocator,
event_map: ?EventMapType,

pub fn init(allocator: Allocator) Self {
    return Self{
        .alloc = allocator,
        .event_map = EventMapType.init(allocator),
    };
}

pub fn deinit(self: *Self) void {
    const emap = &(self.event_map orelse return);

    var entries = emap.iterator();
    while (entries.next()) |entry| {
        entry.value_ptr.deinit();
    }

    emap.clearAndFree();
    emap.deinit();
}

fn makeGet(self: *Self, event: anytype) !*EventActions {
    const emap: *EventMapType = &(self.event_map orelse @panic("event_map wasn't initalised! Call eventloop.init()!"));

    const key = zap.changeType(EventEnumTarget, event) orelse -1;

    if (!emap.contains(key)) {
        try emap.put(key, EventActions.init(self.alloc));
    }

    return emap.getPtr(key).?;
}

pub fn on(self: *Self, event: anytype, action: Action) !void {
    const ptr = try self.makeGet(event);

    try ptr.append(action);
}

pub fn call(self: *Self, event: anytype) !void {
    const ptr = try self.makeGet(event);

    const items = try zap.cloneToOwnedSlice(Action, ptr.*);
    defer ptr.allocator.free(items);

    for (items) |action| {
        action.fn_ptr() catch switch (action.on_fail) {
            .ignore => {
                std.log.warn("Ignored function failiure!", .{});
            },
            .remove => {
                std.log.warn("Removed function failiure!", .{});
                for (ptr.items, 0..) |item, index| {
                    if (!std.meta.eql(item, action)) continue;

                    _ = ptr.swapRemove(index);
                    break;
                }
            },
            .panic => @panic("Critical eventloop action failiure!"),
        };
    }
}
