const assets = @import("../../main.zig").libs.assets;
const std = @import("std");

pub fn deinit() !void {
    assets.deinit();
}
