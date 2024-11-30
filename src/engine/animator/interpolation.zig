const std = @import("std");
const Allocator = @import("std").mem.Allocator;

pub const Number = f32;

pub fn lerp(start: Number, end: Number, progress: Number) Number {
    return start + progress * (end - start);
}

pub fn ease_in(start: Number, end: Number, progress: Number) Number {
    return lerp(start, end, progress * progress);
}

pub fn ease_out(start: Number, end: Number, progress: Number) Number {
    return lerp(
        start,
        end,
        (1 - (1 - progress) * (1 - progress)),
    );
}

pub fn ease_in_out(start: Number, end: Number, progress: Number) Number {
    return lerp(
        start,
        end,
        if (progress < 0.5)
            progress * progress * (3 - 2 * progress)
        else
            1 - (1 - progress) * (1 - progress) * (3 - 2 * (1 - progress)),
    );
}
