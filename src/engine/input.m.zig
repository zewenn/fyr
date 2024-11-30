const std = @import("std");
const rl = @import("raylib");

pub var input_mode: enum {
    KeyboardAndMouse,
    Keyboard,
} = .KeyboardAndMouse;

pub var mouse_position: rl.Vector2 = rl.Vector2.init(0, 0);

pub var ui_mode: bool = false;

pub fn update() void {
    if (mouse_position.distance(rl.getMousePosition()) > 5) {
        mouse_position = rl.getMousePosition();
        input_mode = .KeyboardAndMouse;
        return;
    }

    if (rl.isKeyDown(.key_left) or
        rl.isKeyDown(.key_right) or
        rl.isKeyDown(.key_up) or
        rl.isKeyDown(.key_down))
    {
        input_mode = .Keyboard;
    }
}



