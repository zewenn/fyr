const std = @import("std");
const loom = @import("root.zig");
const rl = loom.rl;

var _size = loom.Vec2(860, 480);
var _temp_size = loom.Vec2(860, 480);
var is_resizable = false;

var is_alive = false;

pub var clear_color: rl.Color = rl.Color.black;
pub var use_debug_mode = false;

pub fn init() void {
    defer is_alive = true;
    const start_size = size.get();

    rl.initWindow(
        loom.toi32(start_size.x),
        loom.toi32(start_size.y),
        title.get(),
    );
    rl.initAudioDevice();
}

pub fn deinit() void {
    defer is_alive = false;

    rl.closeAudioDevice();
    rl.closeWindow();
}

pub fn clearBackground() void {
    rl.clearBackground(clear_color);
}

pub const shouldClose = rl.windowShouldClose;

pub fn toggleDebugMode() void {
    use_debug_mode = !use_debug_mode;
    loom.clay.setDebugModeEnabled(use_debug_mode);
}

/// FPS: frames per second
pub const fpsTarget = struct {
    var state: i32 = 60;

    /// Set the maximum FPS the program can run at
    pub inline fn set(to: anytype) void {
        state = loom.coerceTo(i32, to) orelse 60;
        rl.setTargetFPS(state);
    }

    /// Get the maximum FPS the program can run at
    pub inline fn get() i32 {
        return state;
    }

    /// Get the currect FPS
    pub const getCurrent = rl.getFPS();
};

pub const size = struct {
    inline fn update() void {
        _size = loom.Vec2(rl.getScreenWidth(), rl.getScreenHeight());
    }

    pub inline fn set(to: loom.Vector2) void {
        if (is_alive) {
            rl.setWindowSize(
                loom.toi32(to.x),
                loom.toi32(to.y),
            );
            update();
            return;
        }
        _temp_size = to;
    }

    pub inline fn get() loom.Vector2 {
        if (!is_alive) return _temp_size;
        update();
        return _size;
    }
};

pub const resizing = struct {
    pub fn toggle() void {
        set(!is_resizable);
    }

    pub inline fn enable() void {
        set(true);
    }

    pub inline fn disable() void {
        set(false);
    }

    pub inline fn set(to: bool) void {
        if (to == is_resizable) return;

        is_resizable = to;
        config_flags.set(.{ .window_resizable = true }, is_resizable);
    }

    pub inline fn get() bool {
        return is_resizable;
    }
};

pub const borderless = struct {
    var state: bool = false;

    pub fn enable() void {
        set(true);
    }

    pub fn disable() void {
        set(false);
    }

    pub fn toggle() void {
        set(!state);
    }

    pub fn set(to: bool) void {
        if (state == to) return;

        rl.toggleBorderlessWindowed();
        state = !state;
    }

    pub fn get() bool {
        return state;
    }
};

pub const fullscreen = struct {
    var state: bool = false;

    pub fn enable() void {
        set(true);
    }

    pub fn disable() void {
        set(false);
    }

    pub fn toggle() void {
        set(!state);
    }

    pub fn set(to: bool) void {
        if (state == to) return;

        rl.toggleFullscreen();
        state = !state;
    }

    pub fn get() bool {
        return state;
    }
};

pub const vsync = struct {
    var state: bool = false;
    var before: i32 = 60;

    pub fn enable() void {
        set(true);
    }

    pub fn disable() void {
        set(false);
    }

    pub fn toggle() void {
        set(!state);
    }

    pub fn set(to: bool) void {
        if (state == to) return;

        if (to) {
            before = fpsTarget.get();
            fpsTarget.set(rl.getMonitorRefreshRate(rl.getCurrentMonitor()));

            std.log.info("fps target: {d}", .{rl.getMonitorRefreshRate(rl.getCurrentMonitor())});
        } else {
            fpsTarget.set(before);
        }

        state = !state;
    }

    pub fn get() bool {
        return state;
    }
};

pub const ConfigFlags = rl.ConfigFlags;
pub const config_flags = struct {
    pub fn set(flags: ConfigFlags, enable: bool) void {
        if (!is_alive) {
            if (enable) rl.setConfigFlags(flags);
            return;
        }

        if (enable) {
            rl.clearWindowState(flags);
            return;
        }

        rl.setWindowState(flags);
    }

    pub fn get(flag: ConfigFlags) bool {
        return rl.isWindowState(flag);
    }
};

pub const title = struct {
    var current_title: [:0]const u8 = "[loom] Untitled Project";

    pub fn set(to: [:0]const u8) void {
        if (is_alive) {
            rl.setWindowTitle(to);
            return;
        }
        current_title = to;
    }

    pub fn get() [:0]const u8 {
        return current_title;
    }
};

/// ## `restore_state`
/// Restore state handles window position and size saving and loading.
///
/// **This feature is enabled by default!**
///
/// You can toggle this setting via `.enable()` and `.disable()`.
pub const restore_state = struct {
    var use: bool = true;

    pub fn enable() void {
        use = true;
    }

    pub fn disable() void {
        use = false;
    }

    pub fn save() !void {
        if (!use) return;

        const exepath = try std.fs.selfExeDirPathAlloc(loom.allocators.generic());
        defer loom.allocators.generic().free(exepath);

        const path = try std.fmt.allocPrint(loom.allocators.generic(), "{s}{s}{s}", .{ exepath, std.fs.path.sep_str, ".loom.winstate" });
        defer loom.allocators.generic().free(path);

        var file = try std.fs.createFileAbsolute(path, .{});
        defer file.close();

        const win_size = size.get();
        const win_size_x: u16 = @bitCast(@as(i16, @intFromFloat(@min(
            @as(f32, @floatFromInt(std.math.maxInt(i16))),
            @round(win_size.x),
        ))));
        const win_size_y: u16 = @bitCast(@as(i16, @intFromFloat(@min(
            @as(f32, @floatFromInt(std.math.maxInt(i16))),
            @round(win_size.y),
        ))));

        const win_pos = rl.getWindowPosition();
        const win_pos_x: u16 = @bitCast(@as(i16, @intFromFloat(@min(
            @as(f32, @floatFromInt(std.math.maxInt(i16))),
            @round(win_pos.x),
        ))));
        const win_pos_y: u16 = @bitCast(@as(i16, @intFromFloat(@min(
            @as(f32, @floatFromInt(std.math.maxInt(i16))),
            @round(win_pos.y),
        ))));

        const writer = file.writer();

        try writer.writeByte(loom.coerceTo(u8, win_pos_x >> 8) orelse 0);
        try writer.writeByte(loom.coerceTo(u8, (win_pos_x << 8) >> 8) orelse 0);
        try writer.writeByte(loom.coerceTo(u8, win_pos_y >> 8) orelse 0);
        try writer.writeByte(loom.coerceTo(u8, (win_pos_y << 8) >> 8) orelse 0);
        try writer.writeByte(loom.coerceTo(u8, win_size_x >> 8) orelse 0);
        try writer.writeByte(loom.coerceTo(u8, (win_size_x << 8) >> 8) orelse 0);
        try writer.writeByte(loom.coerceTo(u8, win_size_y >> 8) orelse 0);
        try writer.writeByte(loom.coerceTo(u8, (win_size_y << 8) >> 8) orelse 0);

        // 8th bit - fullsceen - 0b0000_0001
        // 7th bit - borderless - 0b0000_0010
        var config_flags_bits: u8 = 0b0000_0000;
        if (fullscreen.get()) config_flags_bits |= 0b0000_0001;
        if (borderless.get()) config_flags_bits |= 0b0000_0010;

        try writer.writeByte(config_flags_bits);
    }

    pub fn load() !void {
        if (!use) return;

        const exepath = try std.fs.selfExeDirPathAlloc(loom.allocators.generic());
        defer loom.allocators.generic().free(exepath);

        const path = try std.fmt.allocPrint(loom.allocators.generic(), "{s}{s}{s}", .{ exepath, std.fs.path.sep_str, ".loom.winstate" });
        defer loom.allocators.generic().free(path);

        var file = try std.fs.openFileAbsolute(path, .{ .mode = .read_only });
        defer file.close();

        var reader = file.reader();

        const pos_x_str = [_]u8{ try reader.readByte(), try reader.readByte() };
        const pos_x: i16 = @bitCast(@as(u16, @intCast((loom.tou16(pos_x_str[0]) << 8) + loom.tou16(pos_x_str[1]))));

        const pos_y_str = [_]u8{ try reader.readByte(), try reader.readByte() };
        const pos_y: i16 = @bitCast(@as(u16, @intCast((loom.tou16(pos_y_str[0]) << 8) + loom.tou16(pos_y_str[1]))));

        const size_x_str = [_]u8{ try reader.readByte(), try reader.readByte() };
        const size_x: i16 = @bitCast(@as(u16, @intCast((loom.tou16(size_x_str[0]) << 8) + loom.tou16(size_x_str[1]))));

        const size_y_str = [_]u8{ try reader.readByte(), try reader.readByte() };
        const size_y: i16 = @bitCast(@as(u16, @intCast((loom.tou16(size_y_str[0]) << 8) + loom.tou16(size_y_str[1]))));

        const config_flag_bits = try reader.readByte();

        rl.setWindowPosition(@intCast(pos_x), @intCast(pos_y));
        size.set(loom.Vec2(size_x, size_y));

        if (config_flag_bits & 0b0000_0001 > 0) fullscreen.enable();
        if (config_flag_bits & 0b0000_0010 > 0) borderless.enable();
    }
};
