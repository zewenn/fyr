const std = @import("std");
const zap = @import(".zap");

pub fn awake() !void {
    try zap.useInstance("test");
}
