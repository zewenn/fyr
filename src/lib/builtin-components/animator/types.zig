pub const TimingFunction = *const fn (f32, f32, f32) f32;
pub const Keyframe = @import("./Keyframe.zig");
pub const Animation = @import("./Animation.zig");
pub const interpolation = @import("./interpolation.zig");

pub const Modes = enum {
    forwards,
    backwards,
};
