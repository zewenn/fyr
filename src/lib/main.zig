const std = @import("std");
const Allocator = @import("std").mem.Allocator;

pub const builtin = @import("builtin");
pub const os = std.os;
pub const target = builtin.target;
pub const BUILD_MODE = builtin.mode;

const deps = @import("./deps/export.zig");

pub const rl = deps.raylib;
pub const rgui = deps.raygui;

pub const uuid = deps.uuid;

pub const Vector2 = rl.Vector2;
pub const Vector3 = rl.Vector3;
pub const Vector4 = rl.Vector4;
pub const Rectangle = rl.Rectangle;

pub const ecs = @import("libs/ecs/export.zig");
pub const eventloop = @import("libs/eventloop/export.zig");
pub const time = @import("libs/time.zig");
pub const assets = @import("libs/assets.zig");
pub const display = @import("libs/display.zig");
pub const gui = @import("libs/gui/export.zig");

pub const Transform = ecs.components.Transform;
pub const Display = ecs.components.Display;
pub const DisplayCache = ecs.components.DisplayCache;
pub const Renderer = ecs.components.Renderer;
pub const Collider = ecs.components.Collider;
pub const ColliderBehaviour = ecs.components.ColliderBehaviour;
pub const CameraTarget = ecs.components.CameraTarget;

pub const AnimatorBehaviour = ecs.components.AnimatorBehaviour;
pub const Animator = ecs.components.Animator;
pub const Animation = ecs.components.Animation;
pub const KeyFrame = ecs.components.KeyFrame;

pub const interpolation = ecs.components.interpolation;

pub const Scene = eventloop.Scene;

const global_allocators = struct {
    pub var gpa: AllocatorScene(std.heap.GeneralPurposeAllocator(.{})) = .{};
    pub var arena: AllocatorScene(std.heap.ArenaAllocator) = .{};
    pub var page: Allocator = std.heap.page_allocator;

    pub const types = enum {
        /// Generic allocator, warns at program exit if a memory leak happened.
        gpa,
        /// Global arena allocator, everything allocated will be freed at program end.
        arena,
        /// Shorthand for `std.heap.page_allocator`.
        page,
        /// If `eventloop` has an Scene loaded, this is a shorthand for
        /// `fyr.eventloop.active_Scene.allocator()`, otherwise this is the
        /// same as arena.
        Scene,
        /// Shorthand for `std.heap.c_allocator`
        c,
        /// Shorthand for `std.heap.raw_c_allocator`
        raw_c,
    };
};

pub const SharedPointer = @import("./.types/SharedPointer.zig").SharedPointer;
pub fn SharetPtr(value: anytype) !*SharedPointer(@TypeOf(value)) {
    const ptr = try getAllocator(.gpa).create(SharedPointer(@TypeOf(value)));
    ptr.* = try SharedPointer(@TypeOf(value)).init(getAllocator(.gpa), value);
    return ptr;
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

var loop_running = false;
pub inline fn isLoopRunning() bool {
    return loop_running;
}

pub fn init() !void {
    if (BUILD_MODE == .Debug) {
        warray_lib.warray_test();
        @import("./.types/strings/export.zig").string_test() catch @panic("HealthCheck failiure!");
    }

    rl.setTraceLogLevel(.warning);

    rl.initWindow(1280, 720, "fyr");
    rl.initAudioDevice();

    time.init();
    try eventloop.init();

    display.init();

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

        eventloop.execute() catch {
            std.log.warn("eventloop.execute() failed!", .{});
        };

        rl.beginDrawing();
        {
            rl.clearBackground(rl.Color.white);
            camera.begin();
            {
                display.render();
            }
            camera.end();

            _ = rgui.guiButton(Rect(50, 50, 200, 20), "Fasza");
        }
        rl.endDrawing();
    }
}

pub fn project(_: void) void {}

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
    display.deinit();
    rl.closeWindow();

    assets.deinit();

    rl.closeAudioDevice();
}

pub inline fn changeType(comptime T: type, value: anytype) ?T {
    const value_info = @typeInfo(@TypeOf(value));
    return switch (@typeInfo(T)) {
        .Int, .ComptimeInt => switch (value_info) {
            .Int, .ComptimeInt => @as(T, @intCast(value)),
            .Float, .ComptimeFloat => @as(T, @intFromFloat(@round(value))),
            .Bool => @as(T, @intFromBool(value)),
            .Enum => @as(T, @intFromEnum(value)),
            else => null,
        },
        .Float, .ComptimeFloat => switch (value_info) {
            .Int, .ComptimeInt => @as(T, @floatFromInt(value)),
            .Float, .ComptimeFloat => @as(T, @floatCast(value)),
            .Bool => @as(T, @floatFromInt(@intFromBool(value))),
            .Enum => @as(T, @floatFromInt(@intFromEnum(value))),
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
                .{ value, T },
            );
            break :Catch null;
        },
    };
}

pub inline fn tof32(value: anytype) f32 {
    return changeType(f32, value) orelse 0;
}

pub fn toi32(value: anytype) i32 {
    return changeType(i32, value) orelse 0;
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

pub fn cloneToOwnedSlice(comptime T: type, list: std.ArrayList(T)) ![]T {
    var cloned = try list.clone();
    defer cloned.deinit();

    return try cloned.toOwnedSlice();
}

pub fn AllocatorScene(comptime T: type) type {
    return struct {
        interface: ?T = null,
        allocator: ?Allocator = null,
    };
}

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
        .Scene => Blk: {
            const active_Scene = eventloop.active_scene orelse break :Blk getAllocator(.arena);
            break :Blk active_Scene.allocator();
        },
        .c => std.heap.c_allocator,
        .raw_c => std.heap.raw_c_allocator,
    };
}

pub fn assert(title: []const u8, statement: bool) void {
    if (statement) {
        logTest("\"\x1b[2m{s}\x1b[0m\" \x1b[32m\x1b[1mpassed\x1b[0m successfully", .{title});
        return;
    }

    logTest("\"\x1b[2m{s}\x1b[0m\" \x1b[31m\x1b[1mfailed\x1b[0m", .{title});
    @panic("ASSERTON FAILIURE");
}

pub fn assertTitle(text: []const u8) void {
    logTest("\n\n\n[ASSERT SECTION] {s}\n", .{text});
}

pub fn logTest(comptime text: []const u8, fmt: anytype) void {
    const formatted = std.fmt.allocPrint(getAllocator(.gpa), text, fmt) catch "";
    defer getAllocator(.gpa).free(formatted);
    std.debug.print("test: {s}\n", .{formatted});
}

/// Can be used to set the path of the `assets/` directory. This is the path
/// which will be used as the base of all asset requests. For Scene:
/// `assets.get.image(`*- assetDebugPath gets inserted here -*`<subpath>)`.
pub inline fn useAssetDebugPath(comptime path: []const u8) void {
    if (BUILD_MODE != .Debug) return;
    assets.overrideDevPath(path);
}

/// Sets the Scene with the given ID as the active Scene, unloading the current one.
pub const useScene = eventloop.setActive;

/// Create a new Scene
pub const scene = eventloop.new;

pub inline fn activeScene() *Scene {
    return eventloop.active_scene orelse panic("No scene loaded!", .{});
}

/// Creates a new Entity with the given identifier and component tuple.
///
/// This function calls the `newEntity` method on the singleton Scene and returns a pointer to the newly created Entity.
///
/// - Parameters:
///   - id: A constant byte slice representing the identifier for the new Entity.
///   - component_tuple: A tuple containing the components for the new Entity.
/// - Returns: A pointer to the newly created `Entity` Scene.
/// - Throws: An error if the Entity creation fails.
pub inline fn newEntity(id: []const u8, component_tuple: anytype) !*Entity {
    return try activeScene().newEntity(id, component_tuple);
}

pub const CacheCast = Behaviour.CacheCast;

pub fn UUIDV7() u128 {
    return uuid.v7.new();
}

pub fn panic(comptime fmt: []const u8, args: anytype) noreturn {
    std.debug.print(fmt ++ "\n", args);
    @panic("ENGINE PANIC!");
}

pub fn newVec2() Vector2 {
    return Vec2(0, 0);
}
