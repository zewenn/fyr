const std = @import("std");
const loom = @import("root.zig");
const rl = loom.rl;

var _size = loom.Vec2(860, 480);
var _temp_size = loom.Vec2(860, 480);
var is_resizable = false;

var is_alive = false;

pub var clear_color: rl.Color = rl.Color.black;
pub var use_debug_lines = false;

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

pub fn toggleDebugLines() void {
    use_debug_lines = !use_debug_lines;
}

/// FPS: frames per second
pub const fps = struct {
    var _target: i32 = 60;

    /// Set the maximum FPS the program can run at
    pub inline fn setTarget(to: anytype) void {
        _target = loom.coerceTo(i32, to) orelse 60;
        rl.setTargetFPS(_target);
    }

    /// Get the maximum FPS the program can run at
    pub inline fn getTarget() i32 {
        return _target;
    }

    /// Get the currect FPS
    pub const get = rl.getFPS();
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
    inline fn update() void {
        if (!is_alive) {
            config_flags.set(.{ .window_resizable = is_resizable });
            return;
        }
        config_flags.set(.{ .window_resizable = is_resizable });
    }

    pub inline fn enable() void {
        if (is_resizable) return;

        is_resizable = true;
        update();
    }

    pub inline fn disable() void {
        if (!is_resizable) return;
        is_resizable = false;
        update();
    }

    pub inline fn setStatus(to: bool) void {
        is_resizable = to;
        update();
    }

    pub inline fn getStatus() bool {
        is_resizable = config_flags.get(.{ .window_resizable = true });
        return is_resizable;
    }
};

pub const ConfigFlags = rl.ConfigFlags;
pub const config_flags = struct {
    pub inline fn set(flags: ConfigFlags) void {
        if (!is_alive) {
            rl.setConfigFlags(flags);
            return;
        }
        rl.setWindowState(flags);
    }

    pub inline fn get(flag: ConfigFlags) ?ConfigFlags {
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

pub const save_state = struct {
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

        rl.setWindowPosition(@intCast(pos_x), @intCast(pos_y));
        size.set(loom.Vec2(size_x, size_y));
    }
};
