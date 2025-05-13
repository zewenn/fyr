pub fn lerp(a: f32, b: f32, t: f32) f32 {
    return a * (1 - t) + b * t;
}
