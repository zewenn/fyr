const UUID = @import("uuid");
const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const Behaviour = @import("./Behaviour.zig");

const Self = @This();

id: []const u8,
uuid: u128,
components: std.ArrayList(*Behaviour),
alloc: Allocator,
remove_next_frame: bool = false,

pub fn init(allocator: Allocator, id: []const u8) Self {
    return Self{
        .id = id,
        .uuid = UUID.v7.new(),
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
        item.callSafe(.end, self);
        self.alloc.destroy(item);
    }
    self.components.deinit();
}

pub fn destroy(self: *Self) void {
    self.deinit();
    self.alloc.destroy(self);
}

pub fn addComponent(self: *Self, component: anytype) !void {
    const ptr = try self.alloc.create(Behaviour);
    ptr.* = try Behaviour.init(component);

    try self.components.append(ptr);
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

        self.components.swapRemove(index);
        return;
    }
}

pub fn removeComponents(self: *Self, comptime T: type) void {
    for (self.components.items, 0..) |component, index| {
        if (!component.isType(T)) continue;

        self.components.swapRemove(index);
    }
}

pub fn dispatchEvent(self: *Self, event: Behaviour.Events) void {
    for (self.components.items) |item| {
        item.callSafe(event, self);
    }
}
