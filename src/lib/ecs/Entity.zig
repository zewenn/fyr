const UUID = @import("uuid");
const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const Behaviour = @import("./Behaviour.zig");

const Self = @This();

id: []const u8,
uuid: u128,

prepared_components: std.ArrayList(*Behaviour),
components: std.ArrayList(*Behaviour),
alloc: Allocator,
remove_next_frame: bool = false,
end_dispatched: bool = false,

pub fn init(allocator: Allocator, id: []const u8) Self {
    return Self{
        .id = id,
        .uuid = UUID.v7.new(),
        .prepared_components = .init(allocator),
        .components = .init(allocator),
        .alloc = allocator,
    };
}

pub fn create(allocator: Allocator, id: []const u8) !*Self {
    const ptr = try allocator.create(Self);
    ptr.* = Self.init(allocator, id);

    return ptr;
}

pub fn deinit(self: *Self) void {
    for (self.components.items) |item| {
        if (!self.end_dispatched)
            item.callSafe(.end, self);
        self.alloc.destroy(item);
    }
    self.components.deinit();

    for (self.prepared_components.items) |item| {
        if (!self.end_dispatched)
            item.callSafe(.end, self);
        self.alloc.destroy(item);
    }
    self.prepared_components.deinit();
}

pub fn addPreparedComponents(self: *Self, dispatch_events: bool) !void {
    if (self.prepared_components.items.len == 0) return;

    for (self.prepared_components.items) |component| {
        try self.components.append(component);
    }

    if (dispatch_events) for (self.prepared_components.items) |item| {
        item.callSafe(.awake, self);
        item.callSafe(.start, self);
    };

    self.prepared_components.clearAndFree();
}

pub fn destroy(self: *Self) void {
    self.deinit();
    self.alloc.destroy(self);
}

pub fn addComponent(self: *Self, component: anytype) !void {
    const ptr = try self.alloc.create(Behaviour);
    ptr.* = try Behaviour.init(component);

    try self.prepared_components.append(ptr);
}

pub fn addComponents(self: *Self, components: anytype) !void {
    inline for (components) |component| {
        try self.addComponent(component);
    }
}

pub fn getComponent(self: *Self, comptime T: type) ?*T {
    for (self.components.items) |component| {
        if (component.isType(T)) return component.castBack(T);
    }
    return null;
}

fn UnsafeReult(comptime T: type) type {
    return struct {
        initalised: bool = false,
        result: ?*T,

        pub fn init(from: *Behaviour) UnsafeReult(T) {
            return UnsafeReult(T){
                .initalised = from.initalised,
                .result = from.castBack(T),
            };
        }

        pub fn unwrap(self: UnsafeReult(T)) !*T {
            return self.result orelse err: {
                std.log.err("Unwrap failed: {any}", .{T});
                break :err error.ComponentNotFound;
            };
        }
    };
}

/// This function can return uninitalised components.
/// A component gets initalised when `Awake` is called, but this method can access it before the event is dispatched. **Use with care.**
pub fn getComponentUnsafe(self: *Self, comptime T: type) UnsafeReult(T) {
    for (self.components.items) |component| {
        if (component.isType(T)) return UnsafeReult(T).init(component);
    }
    for (self.prepared_components.items) |component| {
        if (component.isType(T)) return UnsafeReult(T).init(component);
    }
    return UnsafeReult(T){ .result = null };
}

pub fn pullComponent(self: *Self, comptime T: type) !*T {
    return self.getComponent(T) orelse err: {
        std.log.err("[{s}@{x}] Missing component: {any}", .{ self.id, self.uuid, T });
        break :err error.ComponentNotFound;
    };
}

pub fn getComponents(self: *Self, comptime T: type) ![]*T {
    var list = std.ArrayList(*T).init(self.alloc);

    for (self.components.items) |component| {
        if (!component.isType(T)) continue;
        try list.append(component.castBack(T) orelse continue);
    }

    return list.toOwnedSlice();
}

pub fn removeComponent(self: *Self, comptime T: type) void {
    for (self.components.items, 0..) |component, index| {
        if (!component.isType(T)) continue;

        _ = self.components.swapRemove(index);
        return;
    }
}

pub fn removeComponents(self: *Self, comptime T: type) void {
    for (self.components.items, 0..) |component, index| {
        if (!component.isType(T)) continue;

        _ = self.components.swapRemove(index);
    }
}

pub fn dispatchEvent(self: *Self, event: Behaviour.Events) void {
    if (event == .end) self.end_dispatched = true;

    for (self.components.items) |item| {
        item.callSafe(event, self);
    }
}
