const std = @import("std");

const loom = @import("root.zig");
const rl = loom.rl;

pub const KeyboardKey = rl.KeyboardKey;
pub const MouseButton = rl.MouseButton;
pub const MouseCursor = rl.MouseCursor;

pub const getKeyDown = rl.isKeyPressed;
pub const getKeyDownRepeat = rl.isKeyPressedRepeat;
pub const getKeyUp = rl.isKeyReleased;
pub const getKey = rl.isKeyDown;
pub const getKeyReleased = rl.isKeyUp;
pub const getKeyPressed = rl.getKeyPressed();

pub const getMouseDown = rl.isMouseButtonPressed;
pub const getMouseUp = rl.isMouseButtonReleased;
pub const getMouse = rl.isMouseButtonDown;
pub const getMouseReleased = rl.isMouseButtonUp;
