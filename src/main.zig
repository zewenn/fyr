const std = @import("std");

const os = @import("std").os;
const fs = @import("std").fs;

const e = @import("./engine/engine.m.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    e.setTraceLogLevel(.log_error);

    e.window.init(
        "OverLife - v0.0.0-a1",
        e.Vec2(
            1440,
            720,
        ),
    );
    defer e.window.deinit();

    e.window.makeResizable();

    try e.init(allocator);
    defer e.deinit();

    if (e.builtin.mode != .Debug) {
        e.zlib.debug.debugDisplay = false;
    }

    e.setTargetFPS(256);
    e.setExitKey(.key_kp_7);

    while (!e.windowShouldClose()) {
        if (e.isKeyPressed(.key_f11)) {
            e.window.toggleBorderless();
        }
        if (e.builtin.mode == .Debug) {
            if (e.isKeyPressed(.key_f3)) {
                e.zlib.debug.debugDisplay = !e.zlib.debug.debugDisplay;
            }
        }
        e.update() catch {};
    }
}
