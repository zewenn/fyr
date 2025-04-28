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
