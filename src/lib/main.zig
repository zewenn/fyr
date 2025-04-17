// ^Import
// --------------------------------------------------------------------------------
const std = @import("std");
const Allocator = @import("std").mem.Allocator;
const testing = std.testing;
const builtin = @import("builtin");
const os = std.os;
const target = builtin.target;

var random: std.Random = undefined;

// ^Library Information
// --------------------------------------------------------------------------------
pub const lib_info = struct {
    pub const lib_name = "fyr";
    pub const version_str = "0.3.0";
    pub const build_mode = builtin.mode;
};

// ^Dependencie
// --------------------------------------------------------------------------------
const deps = @import("./deps/export.zig");
pub const rl = deps.raylib;
pub const rgui = deps.raygui;
pub const clay = deps.clay;
pub const uuid = deps.uuid;

// ^Module
// --------------------------------------------------------------------------------
pub const ecs = @import("libs/ecs/export.zig");
pub const eventloop = @import("libs/eventloop/export.zig");
pub const time = @import("libs/time.zig");
pub const assets = @import("libs/assets.zig");
pub const display = @import("libs/display.zig");
pub const gui = @import("libs/gui/export.zig");
pub const window = @import("libs/window.zig");
pub const input = @import("libs/input.zig");

// ^Raylib Type
// --------------------------------------------------------------------------------
pub const Vector2 = rl.Vector2;
pub const Vector3 = rl.Vector3;
pub const Vector4 = rl.Vector4;
pub const Rectangle = rl.Rectangle;
pub const Color = rl.Color;

// ^Component
// --------------------------------------------------------------------------------
pub const Transform = ecs.components.Transform;
pub const Display = ecs.components.Display;
pub const DisplayCache = ecs.components.DisplayCache;
pub const Animator = ecs.components.Animator;

// ^Behaviours
// --------------------------------------------------------------------------------
pub const Renderer = ecs.components.Renderer;
pub const RectCollider = ecs.components.RectCollider;
pub const CameraTarget = ecs.components.CameraTarget;
pub const AnimatorBehaviour = ecs.components.AnimatorBehaviour;
pub const Children = ecs.components.Children;

// ^Animator
// --------------------------------------------------------------------------------
pub const interpolation = ecs.components.interpolation;
pub const Animation = ecs.components.Animation;
pub const KeyFrame = ecs.components.KeyFrame;

// ^Allocators
// --------------------------------------------------------------------------------
fn AllocatorInstance(comptime T: type) type {
    return struct {
        interface: ?T = null,
        allocator: ?Allocator = null,
    };
}

pub inline fn getAllocator(comptime _: enum { generic, arena, page, scene, c, raw_c }) Allocator {
    @compileError("fyr.getAllocator got deprecated, use fyr.allocators instead");
}

pub const allocators = struct {
    pub var AI_generic: AllocatorInstance(std.heap.DebugAllocator(.{})) = .{};
    pub var AI_arena: AllocatorInstance(std.heap.ArenaAllocator) = .{};

    /// Generic allocator, warns at program exit if a memory leak happened.
    /// In the Debug and ReleaseFast modes this is a `DebugAllocator`,
    /// otherwise it is equivalent to the `std.heap.smp_allocator`
    pub inline fn generic() Allocator {
        return AI_generic.allocator orelse Blk: {
            switch (lib_info.build_mode) {
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
        const active_Scene = eventloop.active_scene orelse return arena();
        return active_Scene.allocator();
    }
};

// ^Fyr Types
// --------------------------------------------------------------------------------
pub const Scene = eventloop.Scene;

pub const SharedPtr = @import("./.types/SharedPointer.zig").SharedPtr;
pub fn sharedPtr(value: anytype) !*SharedPtr(@TypeOf(value)) {
    return try SharedPtr(@TypeOf(value)).create(allocators.generic(), value);
}

const array_lib = @import("./.types/Array.zig");
pub const Array = array_lib.Array;
pub const ArrayOptions = array_lib.ArrayOptions;
pub const array = array_lib.array;
pub const arrayAdvanced = array_lib.arrayAdvanced;

const string_lib = @import("./.types/strings/export.zig");
pub const String = string_lib.String;
pub const string = string_lib.string;

pub const Entity = ecs.Entity;
pub const Behaviour = ecs.Behaviour;

// ^Camera2D
// --------------------------------------------------------------------------------
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

// ^Loop info
// --------------------------------------------------------------------------------
var loop_running = false;
pub inline fn isLoopRunning() bool {
    return loop_running;
}

// ^Block-based control flow and shorthands
// --------------------------------------------------------------------------------
pub fn project(_: void) *const fn (void) void {
    normal_control_flow.init() catch panic("couldn't initalise window!", .{});

    return struct {
        pub fn callback(_: void) void {
            normal_control_flow.loop();
            normal_control_flow.deinit();
        }
    }.callback;
}

/// Shorthand for window.size.set()
pub const windowSize = window.size.set;

/// Shorthand for window.title()
pub const title = window.title;

/// Shorthand for assets.files.paths.use()
pub const useAssetPaths = assets.files.paths.use;

/// Sets the Scene with the given ID as the active Scene, unloading the current one.
pub const useScene = eventloop.setActive;

/// Created
pub inline fn scene(comptime id: []const u8) *const fn (void) void {
    if (eventloop.open_scene != null) {
        std.log.warn("Opening a scene without closing the current open scene is dangerous, and can lead to unwanted results.", .{});
        eventloop.open_scene = null;
    }

    eventloop.open_scene = eventloop.new(id) catch Blk: {
        std.log.err("failed to create scene \"" ++ id ++ "\"!", .{});
        break :Blk null;
    };

    return struct {
        pub fn callback(_: void) void {
            eventloop.open_scene = null;
        }
    }.callback;
}

/// Set the default entities of the last created scene
/// If an entity fn returns an error it will be ignored!
pub fn entities(tuple: anytype) void {
    const scene_ptr = activeOrOpenScene() catch {
        std.log.err("no scene was loaded or found, entities cannot be added!", .{});
        return;
    };

    const list = arrayAdvanced(
        *Entity,
        .{ .on_type_change_fail = .ignore },
        tuple,
    );
    defer list.deinit();

    for (list.items) |ptr| {
        scene_ptr.addEntity(ptr) catch {
            std.log.err("failed to add entity to scene!", .{});
            continue;
        };
    }
}

pub inline fn entity(id: []const u8, component_tuple: anytype) !*Entity {
    return try (try activeOrOpenScene()).newEntity(id, component_tuple);
}

pub fn scripts(tuple: anytype) void {
    const scene_ptr = activeOrOpenScene() catch {
        std.log.err("no scene was loaded or found, scripts cannot be added!", .{});
        return;
    };

    inline for (tuple) |item| {
        scene_ptr.newScript(item) catch {
            std.log.err("failed to add script to scene!", .{});
        };
    }
}

pub inline fn activeScene() !*Scene {
    return eventloop.active_scene orelse error.NoScenesPresent;
}

pub inline fn activeOrOpenScene() !*Scene {
    return eventloop.active_scene orelse (eventloop.open_scene orelse error.NoScenesPresent);
}

// ^Normal control flow
// --------------------------------------------------------------------------------
pub const normal_control_flow = struct {
    pub fn init() !void {
        var seed: u64 = undefined;
        std.posix.getrandom(std.mem.asBytes(&seed)) catch {
            seed = coerceTo(u64, rl.getTime()).?;
        };
        var x = std.Random.DefaultPrng.init(seed);
        random = x.random();

        rl.setTraceLogLevel(.warning);

        window.init();

        time.init();
        try eventloop.init();

        try gui.init();
        display.init();

        try eventloop.setActive("engine");
    }

    pub fn loop() void {
        if (eventloop.active_scene == null) {
            try useScene("default");
        }

        while (!window.shouldClose()) {
            if (!loop_running)
                loop_running = true;

            camera.offset = Vec2(
                tof32(rl.getScreenWidth()) / 2,
                tof32(rl.getScreenHeight()) / 2,
            );

            time.update();

            display.reset();

            eventloop.execute() catch {
                std.log.warn("eventloop.execute() failed!", .{});
            };

            if (input.getKeyDown(.f3) and
                input.getKey(.left_alt) and
                lib_info.build_mode == .Debug)
                window.toggleDebugLines();

            {
                rl.beginDrawing();
                defer rl.endDrawing();

                window.clearBackground();
                {
                    camera.begin();
                    defer camera.end();

                    display.render();
                }

                gui.raygui.callDrawFn();
                gui.update() catch {
                    std.log.warn("gui update failed", .{});
                };

                if (window.use_debug_lines)
                    rl.drawFPS(10, 10);
            }
        }
    }

    pub fn deinit() void {
        eventloop.deinit();

        display.deinit();
        gui.deinit();

        assets.deinit();

        window.deinit();

        if (allocators.AI_arena.interface) |*intf| {
            intf.deinit();
        }

        if (allocators.AI_generic.interface) |*intf| {
            const state = intf.deinit();
            switch (state) {
                .ok => logInfo("GA exit without memory leaks!", .{}),
                .leak => logInfo("GA exit with memory leak(s)!", .{}),
            }
        }
    }
};

// ^Changing between number(int, float), enum, and boolean types
// --------------------------------------------------------------------------------

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
            .int, .comptime_int => @as(TypeTarget, @intCast(value)),
            .float, .comptime_float => @as(TypeTarget, @intFromFloat(@round(value))),
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
                "cannot change type of \"{any}\" to type \"{any}\" (fyr.changeType())",
                .{ value, TypeTarget },
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
pub fn toisize(value: anytype) isize {
    return coerceTo(isize, value) orelse 0;
}

/// Shorthand for coerceTo
pub fn tousize(value: anytype) usize {
    return coerceTo(usize, value) orelse 0;
}

// ^Raylib Shortcuts
// --------------------------------------------------------------------------------
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

pub fn cloneToOwnedSlice(comptime T: type, list: std.ArrayList(T)) ![]T {
    var cloned = try list.clone();
    return try cloned.toOwnedSlice();
}

// ^Utilities
// --------------------------------------------------------------------------------
pub const CacheCast = Behaviour.CacheCast;
pub const asBehaviour = Behaviour.from;

pub fn UUIDV7() u128 {
    return uuid.v7.new();
}

pub fn panic(comptime fmt: []const u8, args: anytype) noreturn {
    std.log.err(fmt ++ "\n", args);
    @panic("ENGINE PANIC!");
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

pub fn randColor() rl.Color {
    return rl.Color.init(
        random.int(u8),
        random.int(u8),
        random.int(u8),
        random.int(u8),
    );
}

pub const setTickTarget = eventloop.setTickTarget;

// ^Logging
// --------------------------------------------------------------------------------
pub const LogLevel = enum(u4) {
    const Self = @This();

    debug,
    info,
    warn,
    err,
    fatal,
    none,

    pub inline fn toString(self: Self) []const u8 {
        if (self == .none) return "";

        return "(" ++ switch (self) {
            .debug => "debug",
            .info => "info",
            .warn => "warning",
            .err => "error",
            .fatal => "fatal",
            else => "LOG_ERROR",
        } ++ ") ";
    }
};

pub var log_level: LogLevel = switch (lib_info.build_mode) {
    .Debug => .debug,
    .ReleaseFast => .err,
    else => .none,
};

pub fn log(comptime level: LogLevel, comptime fmt: []const u8, args: anytype) void {
    if (@intFromEnum(log_level) > @intFromEnum(level)) return;
    std.debug.print(level.toString() ++ fmt ++ "\n", args);
}

pub fn logDebug(comptime fmt: []const u8, args: anytype) void {
    log(.debug, fmt, args);
}

pub fn logInfo(comptime fmt: []const u8, args: anytype) void {
    log(.info, fmt, args);
}

pub fn logWarn(comptime fmt: []const u8, args: anytype) void {
    log(.warn, fmt, args);
}

pub fn logError(comptime fmt: []const u8, args: anytype) void {
    log(.err, fmt, args);
}

pub fn logFatal(comptime fmt: []const u8, args: anytype) noreturn {
    log(.fatal, fmt, args);
    @panic("FATAL ERROR!");
}
