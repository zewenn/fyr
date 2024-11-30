const loadusize = @import("../engine.m.zig").loadusize;
const zlib = @import("../z/z.m.zig");
pub const ButtonInterface = @import("ButtonInterface.zig");

pub const BUTTON_MATRIX_WIDTH: usize = 16;
pub const BUTTON_MATRIX_HEIGHT: usize = 10;
pub const BUTTON_MATRIX_DEPTH: usize = 6;

pub const ButtonMatrix2D = [BUTTON_MATRIX_HEIGHT][BUTTON_MATRIX_WIDTH]?ButtonInterface;
pub const ButtonMatrix3D = [BUTTON_MATRIX_DEPTH]ButtonMatrix2D;

pub var matrix: ButtonMatrix3D = undefined;
pub var current_layer: usize = 0;

pub fn clear() void {
    matrix = [_][BUTTON_MATRIX_HEIGHT][BUTTON_MATRIX_WIDTH]?ButtonInterface{
        [_][BUTTON_MATRIX_WIDTH]?ButtonInterface{
            [_]?ButtonInterface{null} ** BUTTON_MATRIX_WIDTH,
        } ** BUTTON_MATRIX_HEIGHT,
    } ** BUTTON_MATRIX_DEPTH;
}

/// # NEVER USE 0 AS A LAYER GOT IT?
/// Btw you cannot set it to 0 this way, just by using `resetLayer()`
/// If you try it will be clamped to 1
pub fn setLayer(to: anytype) void {
    const final_to = zlib.math.clamp(usize, loadusize(to), 1, 5);
    current_layer = loadusize(final_to);
}

pub fn incrementLayer(by: anytype) void {
    const clamped = zlib.math.clamp(i32, by, -5, 5);
    const calculated: i32 = @as(i32, @intCast(current_layer)) + clamped;
    const calculated_clamped = zlib.math.clamp(i32, calculated, 1, 5);

    setLayer(calculated_clamped);
}

pub fn resetLayer() void {
    current_layer = 0;
}

pub fn getLayer(layer: anytype) ButtonMatrix2D {
    return matrix[loadusize(layer)];
}

pub fn getCurrentLayer() ButtonMatrix2D {
    return matrix[current_layer];
}

pub fn set(plane: anytype, row: anytype, col: anytype, to: ButtonInterface) void {
    const z = loadusize(plane);
    const y = loadusize(row);
    const x = loadusize(col);

    matrix[z][y][x] = to;
}

pub fn get(plane: anytype, row: anytype, col: anytype) ?ButtonInterface {
    const z = loadusize(plane);
    const y = loadusize(row);
    const x = loadusize(col);

    return matrix[z][y][x];
}

pub fn getPtr(plane: anytype, row: anytype, col: anytype) ?*ButtonInterface {
    const z = loadusize(plane);
    const y = loadusize(row);
    const x = loadusize(col);

    if (matrix[z][y][x] == null) return null;

    return &(matrix[z][y][x].?);
}
