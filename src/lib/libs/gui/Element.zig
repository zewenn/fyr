const std = @import("std");
const fyr = @import("../../main.zig");
const rl = @import("raylib");

const Style = @import("Style.zig");

const string = []const u8;

pub const ElementType = enum {
    body,
    div,
    p,
    h1,
    h2,
    h3,
    h4,
    h5,
    h6,
    button,
};

const Self = @This();

uuid: u128,

type: ElementType = .div,

id: ?string = null,
tags: ?string = null,
style: Style = .{},

rect: ?fyr.Rectangle = null,
font: ?*rl.Font = null,

parent: ?*Self = null,
children: std.ArrayList(*Self),
text: ?[*:0]const u8 = null,

pub fn create() Self {
    return Self{
        .uuid = fyr.UUIDV7(),
        .children = std.ArrayList(*Self).init(fyr.getAllocator(.gpa)),
    };
}

pub fn destroy(self: *Self) void {
    self.children.deinit();
}
