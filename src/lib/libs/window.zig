const fyr = @import("../main.zig");
const rl = fyr.rl;

var _size = fyr.Vec2(860, 480);
var _temp_size = fyr.Vec2(860, 480);
var _resizable = false;
var _title: [:0]const u8 = "";

var is_alive = false;

pub var clear_color: rl.Color = rl.Color.black;
pub var use_debug_lines = false;

pub fn init() void {
    defer is_alive = true;
    const start_size = size.get();

    rl.initWindow(
        fyr.toi32(start_size.x),
        fyr.toi32(start_size.y),
        _title,
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
        _target = fyr.coerceTo(i32, to) orelse 60;
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
        _size = fyr.Vec2(rl.getScreenWidth(), rl.getScreenHeight());
    }

    pub inline fn set(to: fyr.Vector2) void {
        if (is_alive) {
            rl.setWindowSize(
                fyr.toi32(to.x),
                fyr.toi32(to.y),
            );
            update();
            return;
        }
        _temp_size = to;
    }

    pub inline fn get() fyr.Vector2 {
        if (!is_alive) return _temp_size;
        update();
        return _size;
    }
};

pub const resizing = struct {
    inline fn update() void {
        if (!is_alive) {
            config_flags.set(.{ .window_resizable = _resizable });
            return;
        }
        config_flags.set(.{ .window_resizable = _resizable });
    }

    pub inline fn enable() void {
        if (_resizable) return;

        _resizable = true;
        update();
    }

    pub inline fn disable() void {
        if (!_resizable) return;
        _resizable = false;
        update();
    }

    pub inline fn set(to: bool) void {
        _resizable = to;
        update();
    }

    pub inline fn get() bool {
        _resizable = config_flags.get(.{ .window_resizable = true });
        return _resizable;
    }
};

pub const ConfigFlags = rl.ConfigFlags;
pub const config_flags = struct {
    pub inline fn set(flag: ConfigFlags) void {
        if (!is_alive) {
            rl.setConfigFlags(flag);
            return;
        }
        rl.setWindowState(flag);
    }

    pub inline fn get(flag: ConfigFlags) ?ConfigFlags {
        return rl.isWindowState(flag);
    }
};

pub fn title(to: [:0]const u8) void {
    if (is_alive) {
        rl.setWindowTitle(to);
        return;
    }
    _title = to;
}
