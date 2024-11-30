const std = @import("std");
const rl = @import("raylib");

// ======================================================

pub var size = rl.Vector2.init(0, 0);
pub var borderless = false;
pub var fullscreen = false;
pub var vsync = false;

pub fn init(title: [*:0]const u8, startSize: rl.Vector2) void {
    rl.initWindow(
        @intFromFloat(startSize.x),
        @intFromFloat(startSize.y),
        title,
    );

    size = startSize;

    rl.initAudioDevice();

    if (!rl.isAudioDeviceReady()) {
        std.log.err("Couldn't initalise audio device!", .{});
    }
}

pub fn update() void {
    size = rl.Vector2.init(
        @floatFromInt(rl.getScreenWidth()),
        @floatFromInt(rl.getScreenHeight()),
    );
}

pub fn deinit() void {
    rl.closeAudioDevice();
    rl.closeWindow();
}

pub fn resize(to: rl.Vector2) void {
    rl.setWindowSize(
        @intFromFloat(to.x),
        @intFromFloat(to.y),
    );
    size = to;
}

pub fn toggleBorderless() void {
    if (borderless) {
        resize(rl.Vector2.init(1280, 720));
    } else {
        size = rl.Vector2.init(
            @floatFromInt(rl.getScreenWidth()),
            @floatFromInt(rl.getScreenHeight()),
        );
    }
    borderless = !borderless;
    rl.toggleBorderlessWindowed();
}

pub fn toggleFullscreen() void {
    if (fullscreen) {
        resize(rl.Vector2.init(1280, 720));
    } else {
        size = rl.Vector2.init(
            @floatFromInt(rl.getScreenWidth()),
            @floatFromInt(rl.getScreenHeight()),
        );
    }
    fullscreen = !fullscreen;
    rl.toggleFullscreen();
}

pub fn toggleVsync() void {
    vsync = !vsync;

    if (vsync)
        rl.setTargetFPS(rl.getMonitorRefreshRate(rl.getCurrentMonitor()))
    else
        rl.setTargetFPS(256);
}

pub fn makeResizable() void {
    rl.setWindowState(.{ .window_resizable = true });
}
