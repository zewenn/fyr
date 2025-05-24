const loom = @import("../../root.zig");
const Transform = loom.Transform;
const Renderer = loom.Renderer;

const interpolation = @import("./interpolation.zig");

const Self = @This();

pos_x: ?f32 = null,
pos_y: ?f32 = null,
pos_z: ?f32 = null,

rotation: ?f32 = null,

width: ?f32 = null,
height: ?f32 = null,

sprite: ?[]const u8 = null,
// tint: ?fyr.rl.Color,

pub fn interpolate(
    self: Self,
    other: Self,
    func: *const fn (f32, f32, f32) f32,
    t: f32,
) Self {
    var new = self;

    new.pos_x = calculatef32Property(
        self.pos_x,
        other.pos_x,
        func,
        t,
    );

    new.pos_y = calculatef32Property(
        self.pos_y,
        other.pos_y,
        func,
        t,
    );

    new.pos_z = calculatef32Property(
        self.pos_z,
        other.pos_z,
        func,
        t,
    );

    new.rotation = calculatef32Property(
        self.rotation,
        other.rotation,
        func,
        t,
    );

    new.width = calculatef32Property(
        self.width,
        other.width,
        func,
        t,
    );

    new.height = calculatef32Property(
        self.height,
        other.height,
        func,
        t,
    );

    new.sprite = if (func(0, 1, t) > 0.5) self.sprite else other.sprite;

    return new;
}

fn calculatef32Property(
    p1: ?f32,
    p2: ?f32,
    func: *const fn (f32, f32, f32) f32,
    t: f32,
) ?f32 {
    const p1_valid = p1 orelse return p2;
    const p2_valid = p2 orelse return p1;

    return func(p1_valid, p2_valid, t);
}

pub fn apply(self: Self, transofrm: *Transform, renderer: *Renderer) void {
    transofrm.position.x = self.pos_x orelse transofrm.position.x;
    transofrm.position.y = self.pos_y orelse transofrm.position.y;
    transofrm.position.z = self.pos_z orelse transofrm.position.z;

    transofrm.rotation = self.rotation orelse transofrm.rotation;

    transofrm.scale.x = self.width orelse transofrm.scale.x;
    transofrm.scale.y = self.height orelse transofrm.scale.y;

    renderer.img_path = self.sprite orelse renderer.img_path;
}
