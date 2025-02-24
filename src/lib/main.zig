// ^Import
// --------------------------------------------------------------------------------
const std = @import("std");
const Allocator = @import("std").mem.Allocator;
const testing = std.testing;
const builtin = @import("builtin");
const os = std.os;
const target = builtin.target;

var random: std.Random = undefined;

// ^Library Inf
// --------------------------------------------------------------------------------
pub const lib_info = struct {
    pub const lib_name = "fyr";
    pub const version_str = "v0.0.1-dev";
    pub const build_mode = builtin.mode;
};

// ^Dependencie
// --------------------------------------------------------------------------------
const deps = @import("./deps/export.zig");
pub const rl = deps.raylib;
pub const rgui = deps.raygui;
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

// ^Raylib Type
// --------------------------------------------------------------------------------
pub const Vector2 = rl.Vector2;
pub const Vector3 = rl.Vector3;
pub const Vector4 = rl.Vector4;
pub const Rectangle = rl.Rectangle;

// ^Component
// --------------------------------------------------------------------------------
pub const Transform = ecs.components.Transform;
pub const Display = ecs.components.Display;
pub const DisplayCache = ecs.components.DisplayCache;
pub const Collider = ecs.components.Collider;
pub const Animator = ecs.components.Animator;

// ^Behaviours
// --------------------------------------------------------------------------------
pub const Renderer = ecs.components.Renderer;
pub const ColliderBehaviour = ecs.components.ColliderBehaviour;
pub const CameraTarget = ecs.components.CameraTarget;
pub const AnimatorBehaviour = ecs.components.AnimatorBehaviour;

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

const global_allocators = struct {
    pub var gpa: AllocatorInstance(std.heap.GeneralPurposeAllocator(.{})) = .{};
    pub var arena: AllocatorInstance(std.heap.ArenaAllocator) = .{};
    pub var page: Allocator = std.heap.page_allocator;

    pub const types = enum {
        /// Generic allocator, warns at program exit if a memory leak happened.
        gpa,
        /// Global arena allocator, everything allocated will be freed at program end.
        arena,
        /// Shorthand for `std.heap.page_allocator`.
        page,
        /// If `eventloop` has an Scene loaded, this is a shorthand for
        /// `fyr.eventloop.active_scene.allocator()`, otherwise this is the
        /// same as `arena`.
        scene,
        /// Shorthand for `std.heap.c_allocator`
        c,
        /// Shorthand for `std.heap.raw_c_allocator`
        raw_c,
    };
};

pub inline fn getAllocator(comptime T: global_allocators.types) Allocator {
    return switch (T) {
        .gpa => global_allocators.gpa.allocator orelse Blk: {
            global_allocators.gpa.interface = std.heap.GeneralPurposeAllocator(.{}){};
            global_allocators.gpa.allocator = global_allocators.gpa.interface.?.allocator();

            break :Blk global_allocators.gpa.allocator.?;
        },
        .arena => global_allocators.arena.allocator orelse Blk: {
            global_allocators.arena.interface = std.heap.ArenaAllocator.init(getAllocator(.gpa));
            global_allocators.arena.allocator = global_allocators.arena.interface.?.allocator();

            break :Blk global_allocators.arena.allocator.?;
        },
        .page => global_allocators.page,
        .scene => Blk: {
            const active_Scene = eventloop.active_scene orelse break :Blk getAllocator(.arena);
            break :Blk active_Scene.allocator();
        },
        .c => std.heap.c_allocator,
        .raw_c => std.heap.raw_c_allocator,
    };
}

// ^Fyr Types
// --------------------------------------------------------------------------------
pub const Scene = eventloop.Scene;

pub const SharedPtr = @import("./.types/SharedPointer.zig").SharedPtr;
pub fn sharedPtr(value: anytype) !*SharedPtr(@TypeOf(value)) {
    return try SharedPtr(@TypeOf(value)).create(getAllocator(.gpa), value);
}

const warray_lib = @import("./.types/WrappedArray.zig");
pub const WrappedArray = warray_lib.WrappedArray;
pub const WrappedArrayOptions = warray_lib.WrappedArrayOptions;
pub const array = warray_lib.array;
pub const arrayAdvanced = warray_lib.arrayAdvanced;

pub const String = @import("./.types/strings/export.zig").String;
pub const string = @import("./.types/strings/export.zig").string;

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
pub const winSize = window.size.set;

/// Shorthand for window.title()
pub const title = window.title;

/// Can be used to set the path of the `assets/` directory. This is the path
/// which will be used as the base of all asset requests. For Scene:
/// `assets.get.image(`*- assetDebugPath gets inserted here -*`<subpath>)`.
pub inline fn useDebugAssetPath(comptime path: []const u8) void {
    if (lib_info.build_mode != .Debug) return;
    assets.fs.debug = path;
}

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
    const list = arrayAdvanced(
        *Entity,
        .{ .on_type_change_fail = .ignore },
        tuple,
    );
    defer list.deinit();

    const scene_ptr = activeOrOpenScene() catch {
        std.log.err("no scene was loaded or found, entities cannot be added!", .{});
        return;
    };

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
            seed = changeNumberType(u64, rl.getTime()).?;
        };
        var x = std.rand.DefaultPrng.init(seed);
        random = x.random();

        rl.setTraceLogLevel(.warning);

        window.init();

        time.init();
        try eventloop.init();

        display.init();
        gui.init();

        try eventloop.setActive("engine");
    }

    pub fn loop() void {
        if (eventloop.active_scene == null) {
            try useScene("default");
        }

        while (!rl.windowShouldClose()) {
            if (!loop_running)
                loop_running = true;

            camera.offset = Vec2(
                tof32(rl.getScreenWidth()) / 2,
                tof32(rl.getScreenHeight()) / 2,
            );

            time.update();

            display.reset();
            gui.reset();

            eventloop.execute() catch {
                std.log.warn("eventloop.execute() failed!", .{});
            };

            if (rl.isKeyPressed(.f3) and lib_info.build_mode == .Debug) {
                window.toggleDebugLines();
            }

            rl.beginDrawing();
            {
                window.clearBackground();
                camera.begin();
                {
                    display.render();
                }
                camera.end();

                gui.raygui.callDrawFn();
                gui.render();

                if (window.use_debug_lines)
                    rl.drawFPS(10, 10);
            }
            rl.endDrawing();
        }
    }

    pub fn deinit() void {
        defer if (global_allocators.gpa.interface) |*intf| {
            const state = intf.deinit();
            switch (state) {
                .ok => std.log.info("GPA exited without memory leaks!", .{}),
                .leak => std.log.warn("GPA exited with a memory leak!", .{}),
            }
        };

        defer if (global_allocators.arena.interface) |*intf| {
            intf.deinit();
        };

        eventloop.deinit();

        gui.deinit();
        display.deinit();

        assets.deinit();

        window.deinit();
    }
};

// ^Changing between number(int, float), enum, and boolean types
// --------------------------------------------------------------------------------
pub inline fn changeNumberType(comptime TypeTarget: type, value: anytype) ?TypeTarget {
    const value_info = @typeInfo(@TypeOf(value));
    return switch (@typeInfo(TypeTarget)) {
        .Int, .ComptimeInt => switch (value_info) {
            .Int, .ComptimeInt => @as(TypeTarget, @intCast(value)),
            .Float, .ComptimeFloat => @as(TypeTarget, @intFromFloat(@round(value))),
            .Bool => @as(TypeTarget, @intFromBool(value)),
            .Enum => @as(TypeTarget, @intFromEnum(value)),
            else => null,
        },
        .Float, .ComptimeFloat => switch (value_info) {
            .Int, .ComptimeInt => @as(TypeTarget, @floatFromInt(value)),
            .Float, .ComptimeFloat => @as(TypeTarget, @floatCast(value)),
            .Bool => @as(TypeTarget, @floatFromInt(@intFromBool(value))),
            .Enum => @as(TypeTarget, @floatFromInt(@intFromEnum(value))),
            else => null,
        },
        .Bool => switch (value_info) {
            .Int, .ComptimeInt => value != 0,
            .Float, .ComptimeFloat => @as(isize, @intFromFloat(@round(value))) != 0,
            .Bool => value,
            .Enum => @as(isize, @intFromEnum(value)) != 0,
            else => null,
        },
        .Enum => switch (value_info) {
            .Int, .ComptimeInt => @enumFromInt(value),
            .Float, .ComptimeFloat => @enumFromInt(@as(isize, @intFromFloat(@round(value)))),
            .Bool => @enumFromInt(@intFromBool(value)),
            .Enum => @enumFromInt(@as(isize, @intFromEnum(value))),
            else => null,
        },
        else => Catch: {
            std.log.warn(
                "cannot change type of \"{any}\" to type \"{any}\"! (fyr.changeType())",
                .{ value, TypeTarget },
            );
            break :Catch null;
        },
    };
}

/// Shorthand for changeNumberType
pub inline fn tof32(value: anytype) f32 {
    return changeNumberType(f32, value) orelse 0;
}

/// Shorthand for changeNumberType
pub fn toi32(value: anytype) i32 {
    return changeNumberType(i32, value) orelse 0;
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
    defer cloned.deinit();

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
    std.debug.print(fmt ++ "\n", args);
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

pub fn randColor() rl.Color {
    return rl.Color.init(
        random.int(u8),
        random.int(u8),
        random.int(u8),
        random.int(u8),
    );
}
