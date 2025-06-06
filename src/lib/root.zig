const std = @import("std");
const builtin = @import("builtin");
const Allocator = @import("std").mem.Allocator;

pub const rl = @import("raylib");
pub const clay = @import("zclay");
pub const uuid = @import("uuid");
pub const window = @import("window.zig");

pub const arrays = @import("./types/Array.zig");
pub const Array = arrays.Array;
pub const array = arrays.array;
pub const arrayAdvanced = arrays.arrayAdvanced;

var seed: u64 = undefined;
var xoshiro: std.Random.Xoshiro256 = .init(0);
pub var random: std.Random = xoshiro.random();

pub const SharedPtr = @import("./types/SharedPointer.zig").SharedPtr;
pub fn sharedPtr(value: anytype) !*SharedPtr(@TypeOf(value)) {
    return try SharedPtr(@TypeOf(value)).create(allocators.generic(), value);
}

pub const Vector2 = rl.Vector2;
pub const Vector3 = rl.Vector3;
pub const Vector4 = rl.Vector4;
pub const Rectangle = rl.Rectangle;
pub const Color = rl.Color;

pub const Dimensions = clay.Dimensions;

pub const Transform = @import("builtin-components/Transform.zig");
pub const Renderer = @import("builtin-components/Renderer.zig");
pub const RectCollider = @import("builtin-components/collision.zig").RectCollider;
pub const RectangleCollider = @import("builtin-components/collision.zig").RectangleCollider;
pub const CameraTarget = @import("builtin-components/camera.zig").CameraTarget;
pub const Animator = @import("builtin-components/animator/Animator.zig");
pub const Animation = @import("builtin-components/animator/Animation.zig");
pub const Keyframe = @import("builtin-components/animator/Keyframe.zig");
pub const interpolation = @import("builtin-components/animator/interpolation.zig");

pub var camera: rl.Camera2D = .{
    .offset = Vec2(0, 0),
    .target = Vec2(0, 0),
    .zoom = 1,
    .rotation = 0,
};

pub fn screenToWorldPos(pos: Vector2) Vector2 {
    return rl.getScreenToWorld2D(pos, camera);
}

pub fn worldToScreenPos(pos: Vector2) Vector2 {
    return rl.getWorldToScreen2D(pos, camera);
}

pub const ecs = struct {
    pub const Behaviour = @import("./ecs/Behaviour.zig");
    pub const Entity = @import("./ecs/Entity.zig");
    pub const Prefab = @import("./ecs/Prefab.zig");
};

pub const eventloop = @import("eventloop/eventloop.zig");
pub const assets = @import("assets.zig");
pub const display = @import("display.zig");
pub const time = @import("time.zig");
pub const input = @import("input.zig");
pub const ui = @import("ui/ui.zig");

pub const useAssetPaths = assets.files.paths.use;
var running = true;

pub fn quit() void {
    running = false;
}

pub fn project(_: void) *const fn (void) void {
    rl.setTraceLogLevel(.warning);

    time.init();

    window.init();
    window.restore_state.load() catch {
        std.log.err("failed to load window state", .{});
    };

    // Switcheroo to make sure vsync actually gets set :D
    window.vsync.set(!window.vsync.get());
    window.vsync.set(!window.vsync.get());

    display.init();
    ui.init() catch @panic("UI INIT FAILED");
    eventloop.init(allocators.arena());

    std.posix.getrandom(std.mem.asBytes(&seed)) catch {
        seed = coerceTo(u64, rl.getTime()).?;
    };
    xoshiro = std.Random.DefaultPrng.init(seed);
    random = xoshiro.random();

    return struct {
        pub fn callback(_: void) void {
            eventloop.setActive("default") catch {
                std.log.info("no default scene", .{});
            };

            while (!window.shouldClose() and running) {
                if (input.getKeyDown(.enter) and input.getKey(.left_alt))
                    window.toggleDebugMode();

                camera.offset = Vec2(
                    tof32(rl.getScreenWidth()) / 2,
                    tof32(rl.getScreenHeight()) / 2,
                );

                time.update();
                display.reset();

                const mouse_position = rl.getMousePosition();
                clay.setPointerState(.{
                    .x = mouse_position.x,
                    .y = mouse_position.y,
                }, rl.isMouseButtonDown(.left));

                const scroll = rl.getMouseWheelMoveV();
                clay.updateScrollContainers(true, .{ .x = scroll.x, .y = scroll.y }, time.deltaTime());

                clay.beginLayout();

                eventloop.execute();
                defer eventloop.loadNext() catch {
                    std.log.debug("failed to load next scene!", .{});
                };

                rl.beginDrawing();
                defer rl.endDrawing();

                window.clearBackground();
                {
                    camera.begin();
                    defer camera.end();

                    display.render();
                }

                ui.update() catch {
                    std.log.err("UI update failed", .{});
                };

                if (window.use_debug_mode)
                    rl.drawFPS(10, 10);
            }

            eventloop.deinit();
            ui.deinit();
            display.deinit();

            window.restore_state.save() catch {
                std.log.err("failed to save window state", .{});
            };

            assets.deinit();

            window.deinit();
        }
    }.callback;
}

pub fn scene(id: []const u8) *const fn (void) void {
    eventloop.addScene(Scene.init(allocators.generic(), id)) catch @panic("Scene creation failed");

    return struct {
        pub fn callback(_: void) void {
            eventloop.close();
        }
    }.callback;
}

pub fn prefabs(prefab_tuple: anytype) void {
    comptime {
        for (prefab_tuple) |entity| {
            std.debug.assert(@TypeOf(entity) == Prefab);
        }
    }

    const selected_scene = eventloop.active_scene orelse eventloop.open_scene orelse return;
    selected_scene.addPrefabs(prefab_tuple) catch {
        std.log.err("couldn't add prefabs", .{});
    };
}

pub fn summon(entities: []const *Entity) !void {
    const ascene = eventloop.active_scene orelse return;

    for (entities) |entity| try ascene.addEntity(entity);
}

pub const allocators = struct {
    fn AllocatorInstance(comptime T: type) type {
        return struct {
            interface: ?T = null,
            allocator: ?Allocator = null,
        };
    }

    pub var AI_generic: AllocatorInstance(std.heap.DebugAllocator(.{})) = .{};
    pub var AI_arena: AllocatorInstance(std.heap.ArenaAllocator) = .{};
    pub var AI_scene: AllocatorInstance(std.heap.ArenaAllocator) = .{};

    /// Generic allocator, warns at program exit if a memory leak happened.
    /// In the Debug and ReleaseFast modes this is a `DebugAllocator`,
    /// otherwise it is equivalent to the `std.heap.smp_allocator`
    pub inline fn generic() Allocator {
        return AI_generic.allocator orelse Blk: {
            switch (builtin.mode) {
                .Debug, .ReleaseFast => {
                    AI_generic.interface = std.heap.DebugAllocator(.{}){};
                    AI_generic.allocator = AI_generic.interface.?.allocator();
                },
                else => AI_generic.allocator = std.heap.smp_allocator,
            }
            break :Blk AI_generic.allocator.?;
        };
    }

    /// Global arena allocator, everything allocated will be freed at program exit.
    pub inline fn arena() Allocator {
        return AI_arena.allocator orelse Blk: {
            AI_arena.interface = std.heap.ArenaAllocator.init(generic());
            AI_arena.allocator = AI_arena.interface.?.allocator();

            break :Blk AI_arena.allocator.?;
        };
    }

    /// If `eventloop` has an Scene loaded, this is a shorthand for
    /// `fyr.eventloop.active_scene.allocator()`, otherwise this is the
    /// same as `arena`.
    pub inline fn scene() Allocator {
        return AI_scene.allocator orelse Blk: {
            AI_scene.interface = std.heap.ArenaAllocator.init(generic());
            AI_scene.allocator = AI_scene.interface.?.allocator();

            break :Blk AI_scene.allocator.?;
        };
    }
};

pub const Behaviour = ecs.Behaviour;
pub const Entity = ecs.Entity;
pub const Prefab = ecs.Prefab;
pub const Scene = eventloop.Scene;

pub const UUIDv7 = uuid.v7.new;

fn boundcheckMinMax(comptime T: type, value2: anytype) T {
    if (std.math.maxInt(T) < value2) {
        return std.math.maxInt(T);
    }
    if (std.math.minInt(T) > value2) {
        return std.math.minInt(T);
    }

    return @intCast(value2);
}

/// # coerceTo
/// The quick way to change types for ints, floats, booleans, enums and pointers.
/// Currently:
/// - `int`, `comptime_int` can be cast to:
///     - other `int` types (e.g. `i32` -> `i64`)
///     - `float`
///     - `bool`
///     - `enum`
///     - `pointer` (this case the input integer is taken as the address)
/// - `float`, `comptime_float` can be cast to:
///     - `int`
///     - other `float` types
///     - `bool`
///     - `enum`
/// - `bool` can be cast to:
///     - `int`
///     - `float`
///     - `bool`
///     - `enum`
/// - `enum` can be cast to:
///     - `int`
///     - `float`
///     - `bool`
///     - other `enum` types
/// - `pointer` can be cast to:
///     - `int`, the address will become the int's value
///     - other `pointer` types (e.g. `*anyopaque` -> `*i32`)
pub inline fn coerceTo(comptime TypeTarget: type, value: anytype) ?TypeTarget {
    const value_info = @typeInfo(@TypeOf(value));

    return switch (@typeInfo(TypeTarget)) {
        .int, .comptime_int => switch (value_info) {
            .int, .comptime_int => @intCast(
                boundcheckMinMax(TypeTarget, value),
            ),
            .float, .comptime_float => @intCast(
                boundcheckMinMax(TypeTarget, @as(i128, @intFromFloat(@max(std.math.minInt(i128), @min(std.math.maxInt(i128), @round(value)))))),
            ),
            .bool => @as(TypeTarget, @intFromBool(value)),
            .@"enum" => @as(TypeTarget, @intFromEnum(value)),
            .pointer => @intFromPtr(value),
            else => null,
        },
        .float, .comptime_float => switch (value_info) {
            .int, .comptime_int => @as(TypeTarget, @floatFromInt(value)),
            .float, .comptime_float => @as(TypeTarget, @floatCast(value)),
            .bool => @as(TypeTarget, @floatFromInt(@intFromBool(value))),
            .@"enum" => @as(TypeTarget, @floatFromInt(@intFromEnum(value))),
            .pointer => @as(TypeTarget, @floatFromInt(@as(usize, @intFromPtr(value)))),
            else => null,
        },
        .bool => switch (value_info) {
            .int, .comptime_int => value != 0,
            .float, .comptime_float => @as(isize, @intFromFloat(@round(value))) != 0,
            .bool => value,
            .@"enum" => @as(isize, @intFromEnum(value)) != 0,
            .pointer => @as(usize, @intFromPtr(value)) != 0,
            else => null,
        },
        .@"enum" => switch (value_info) {
            .int, .comptime_int => @enumFromInt(value),
            .float, .comptime_float => @enumFromInt(@as(isize, @intFromFloat(@round(value)))),
            .bool => @enumFromInt(@intFromBool(value)),
            .@"enum" => @enumFromInt(@as(isize, @intFromEnum(value))),
            .pointer => @enumFromInt(@as(usize, @intFromPtr(value))),
            else => null,
        },
        .pointer => switch (value_info) {
            .int, .comptime_int => @ptrCast(@alignCast(@as(*anyopaque, @ptrFromInt(value)))),
            .float, .comptime_float => @compileError("Cannot convert float to pointer address"),
            .bool => @compileError("Cannot convert bool to pointer address"),
            .@"enum" => @compileError("Cannot convert enum to pointer address"),
            .pointer => @ptrCast(@alignCast(value)),
            else => null,
        },
        else => Catch: {
            std.log.warn(
                "cannot change type of \"{any}\" to type \"{any}\"",
                .{ @TypeOf(value), TypeTarget },
            );
            break :Catch null;
        },
    };
}

/// Shorthand for coerceTo
pub inline fn tof32(value: anytype) f32 {
    return coerceTo(f32, value) orelse 0;
}

/// Shorthand for coerceTo
pub inline fn tof64(value: anytype) f64 {
    return coerceTo(f64, value) orelse 0;
}

/// Shorthand for coerceTo
pub fn toi32(value: anytype) i32 {
    return coerceTo(i32, value) orelse 0;
}

/// Shorthand for coerceTo
pub fn tou32(value: anytype) u32 {
    return coerceTo(u32, value) orelse 0;
}

/// Shorthand for coerceTo
pub fn toisize(value: anytype) isize {
    return coerceTo(isize, value) orelse 0;
}

/// Shorthand for coerceTo
pub fn tousize(value: anytype) usize {
    return coerceTo(usize, value) orelse 0;
}

/// Shorthand for coerceTo
pub fn tou16(value: anytype) u16 {
    return coerceTo(u16, value) orelse 0;
}

/// Shorthand for coerceTo
pub fn toi16(value: anytype) i16 {
    return coerceTo(i16, value) orelse 0;
}

/// Shorthand for coerceTo
pub fn tou8(value: anytype) u8 {
    return coerceTo(u8, value) orelse 0;
}

/// Shorthand for coerceTo
pub fn toi8(value: anytype) i8 {
    return coerceTo(i8, value) orelse 0;
}

test coerceTo {
    const expect = std.testing.expect;
    const x = enum(u8) { a = 0, b = 32 };

    // Check if types can be handled properly
    try expect(coerceTo(f32, 0) != null);
    try expect(coerceTo(i32, 0) != null);
    try expect(coerceTo(x, 0) != null);
    try expect(coerceTo(bool, 0) != null);
    try expect(coerceTo(*anyopaque, 1) != null);

    // Check if the correct type is returned
    try expect(@TypeOf(coerceTo(f32, 0).?) == f32);
    try expect(@TypeOf(coerceTo(i32, 0).?) == i32);
    try expect(@TypeOf(coerceTo(x, 0).?) == x);
    try expect(@TypeOf(coerceTo(*anyopaque, 1).?) == *anyopaque);

    // Check if ints get converted correctly
    var int: usize = 32;
    const int_address: usize = @intFromPtr(&int);
    const @"comptime_int": comptime_int = 32;

    try expect(coerceTo(usize, -1).? == @as(usize, 0));
    try expect(coerceTo(u8, std.math.maxInt(u128)).? == @as(u8, 255));
    try expect(coerceTo(isize, int).? == @as(isize, 32));
    try expect(coerceTo(f32, int).? == @as(f32, 32.0));
    try expect(coerceTo(x, int).? == @as(x, x.b));
    try expect(coerceTo(bool, int).? == @as(bool, true));
    try expect(coerceTo(*usize, int_address).? == &int);

    try expect(coerceTo(isize, @"comptime_int").? == @as(isize, 32));
    try expect(coerceTo(f32, @"comptime_int").? == @as(f32, 32.0));
    try expect(coerceTo(x, @"comptime_int").? == @as(x, x.b));
    try expect(coerceTo(bool, @"comptime_int").? == @as(bool, true));

    // Check if floats get converted correctly
    const float: f64 = 32.34;
    const @"comptime_float": comptime_float = 32.34;

    try expect(coerceTo(isize, float).? == @as(isize, 32));
    try expect(coerceTo(u8, std.math.floatMax(f128)).? == @as(u8, 255));
    try expect(coerceTo(f32, float).? == @as(f32, 32.34));
    try expect(coerceTo(x, float).? == @as(x, x.b));
    try expect(coerceTo(bool, float).? == @as(bool, true));

    try expect(coerceTo(isize, @"comptime_float").? == @as(isize, 32));
    try expect(coerceTo(f32, @"comptime_float").? == @as(f32, 32.34));
    try expect(coerceTo(x, @"comptime_float").? == @as(x, x.b));
    try expect(coerceTo(bool, @"comptime_float").? == @as(bool, true));

    // Check if enums get converted correctly
    const @"enum": x = x.b;

    try expect(coerceTo(isize, @"enum").? == @as(isize, 32));
    try expect(coerceTo(f32, @"enum").? == @as(f32, 32.0));
    try expect(coerceTo(x, @"enum").? == @as(x, x.b));
    try expect(coerceTo(bool, @"enum").? == @as(bool, true));

    // Check if bools get converted correctly
    const boolean: bool = false;

    try expect(coerceTo(isize, boolean).? == @as(isize, 0));
    try expect(coerceTo(f32, boolean).? == @as(f32, 0.0));
    try expect(coerceTo(x, boolean).? == @as(x, x.a));
    try expect(coerceTo(bool, boolean).? == @as(bool, false));

    // Pointer
    const anyopaque_ptr_of_int: *anyopaque = @ptrCast(@alignCast(&int));

    try expect(coerceTo(usize, &int) == int_address);
    try expect(coerceTo(f64, &int) == @as(f64, @floatFromInt(int_address)));
    try expect(coerceTo(bool, &int) == (int_address != 0));
    try expect(coerceTo(x, @as(*anyopaque, @ptrFromInt(32))) == @"enum");
    try expect(coerceTo(*usize, anyopaque_ptr_of_int) == &int);
}

pub fn Vec2(x: anytype, y: anytype) Vector2 {
    return Vector2{
        .x = tof32(x),
        .y = tof32(y),
    };
}

pub fn Vec3(x: anytype, y: anytype, z: anytype) Vector3 {
    return Vector3{
        .x = tof32(x),
        .y = tof32(y),
        .z = tof32(z),
    };
}

pub fn Vec4(x: anytype, y: anytype, z: anytype, w: anytype) Vector4 {
    return Vector4{
        .x = tof32(x),
        .y = tof32(y),
        .z = tof32(z),
        .w = tof32(w),
    };
}

pub fn Rect(x: anytype, y: anytype, width: anytype, height: anytype) Rectangle {
    return Rectangle{
        .x = tof32(x),
        .y = tof32(y),
        .width = tof32(width),
        .height = tof32(height),
    };
}

pub fn vec(comptime values: []const f32) switch (values.len) {
    0, 1, 2 => Vector2,
    3 => Vector3,
    else => Vector4,
} {
    return switch (values.len) {
        0, 1, 2 => Vec2(if (values.len >= 1) values[0] else 0, if (values.len >= 2) values[1] else 0),
        3 => Vec3(values[0], values[1], values[2]),
        else => Vec4(values[0], values[1], values[2], values[3]),
    };
}

pub fn vec2() Vector2 {
    return Vec2(0, 0);
}

pub fn vec3() Vector3 {
    return Vec3(0, 0, 0);
}

pub fn vec4() Vector4 {
    return Vec4(0, 0, 0, 0);
}

pub fn rect() Rectangle {
    return Rect(0, 0, 0, 0);
}

pub fn vec2ToVec3(v2: Vector2) Vector3 {
    return Vec3(v2.x, v2.y, 0);
}

pub fn vec3ToVec2(v3: Vector3) Vector2 {
    return Vec2(v3.x, v3.y);
}

pub fn vec2ToDims(vector: Vector2) Dimensions {
    return .{
        .w = vector.x,
        .h = vector.y,
    };
}

pub fn vec3ToDims(vector: Vector3) Dimensions {
    return .{
        .w = vector.x,
        .h = vector.y,
    };
}

pub fn dimsToVec2(dims: Dimensions) Vector2 {
    return .{
        .x = dims.w,
        .y = dims.h,
    };
}

pub fn OptionalToError(comptime Optional: type) type {
    const typeinfo = @typeInfo(Optional);

    return switch (typeinfo) {
        .optional => |T| {
            return anyerror!T.child;
        },
        else => @compileError("expected optional type"),
    };
}

pub fn ensureComponent(value: anytype) OptionalToError(@TypeOf(value)) {
    return value orelse err: {
        std.log.err("Component didn't load: {any}", .{@TypeOf(value)});
        break :err error.ComponentDidntLoad;
    };
}

pub fn randColor() rl.Color {
    return rl.Color.init(
        random.int(u8),
        random.int(u8),
        random.int(u8),
        random.int(u8),
    );
}

pub fn cloneToOwnedSlice(comptime T: type, list: std.ArrayList(T)) ![]T {
    var cloned = try list.clone();
    return try cloned.toOwnedSlice();
}
