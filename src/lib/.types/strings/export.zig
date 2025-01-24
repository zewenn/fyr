const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const assertTitle = @import("../../main.zig").assertTitle;
const assert = @import("../../main.zig").assert;

pub const String = @import("./String.zig");

pub fn string(text: []const u8) !String {
    return try String.new(std.heap.page_allocator, text);
}
