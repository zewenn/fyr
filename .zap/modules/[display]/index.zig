const std = @import("std");

pub fn displayThisString(string: []const u8) void {
    std.log.debug("{s}", .{string});
}
