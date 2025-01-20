const std = @import("std");
const zap = @import("../../main.zig");
const rl = @import("raylib");

const Style = @import("Style.zig");

const string = []const u8;

pub const ChildTag = enum {
    element,
    text,
};

pub const Child = union(ChildTag) {
    element: *Self,
    text: string,
};

const Self = @This();

uuid: u128,

id: ?string = null,
tags: ?string = null,
style: ?Style = null,

children: std.ArrayList(Child),

pub fn create() Self {
    return Self{
        .uuid = zap.UUIDV7(),
        .children = std.ArrayList(Child).init(zap.getAllocator(.gpa)),
    };
}

pub fn destroy(self: *Self) void {
    self.children.deinit();
}
