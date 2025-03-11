const fyr = @import("../main.zig");
const rl = fyr.rl;

var _size = fyr.Vec2(860, 480);
pub var _temp_size = fyr.Vec2(860, 480);

var is_alive = false;
pub var _title: [:0]const u8 = "";

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

pub fn toggleDebugLines() void {
    use_debug_lines = !use_debug_lines;
}

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

pub fn title(to: [:0]const u8) void {
    if (is_alive) {
        rl.setWindowTitle(to);
        return;
    }
    _title = to;
}
