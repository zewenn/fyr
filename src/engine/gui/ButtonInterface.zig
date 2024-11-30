const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const GUIElement = @import("GUIElement.zig");

button_id: []const u8,
callback_fn: *const fn () anyerror!void,
element_ptr: ?*GUIElement = null,
