const std = @import("std");
const builtin = @import("builtin");
const Allocator = @import("std").mem.Allocator;

pub const rl = @import("raylib");
pub const uuid = @import("uuid");

pub const ecs = struct {
    pub const Behaviour = @import("./ecs/Behaviour.zig");
    pub const Entity = @import("./ecs/Entity.zig");
    pub const Prefab = @import("./ecs/Prefab.zig");
};

test ecs {
    const TestComponent = struct {
        pub var counter: usize = 0;

        pub fn Awake(entity: *ecs.Entity) !void {
            counter += 1;
            std.log.debug("{s} Awake", .{entity.id});
        }

        pub fn Start(entity: *ecs.Entity) !void {
            counter += 1;
            std.log.debug("{s} Start", .{entity.id});
        }

        pub fn Update(entity: *ecs.Entity) !void {
            counter += 1;
            std.log.debug("{s} Update", .{entity.id});
        }

        pub fn Tick(entity: *ecs.Entity) !void {
            counter += 1;
            std.log.debug("{s} Tick", .{entity.id});
        }

        pub fn End(entity: *ecs.Entity) !void {
            counter += 1;
            std.log.debug("{s} End", .{entity.id});
        }
    };

    const Player = ecs.Prefab.new("Player", .{
        TestComponent{},
    });

    var player = try Player.makeInstance(std.testing.allocator);
    defer player.destroy();

    player.dispatchEvent(.awake);
    player.dispatchEvent(.start);
    player.dispatchEvent(.update);
    player.dispatchEvent(.tick);
    player.dispatchEvent(.end);

    try std.testing.expect(TestComponent.counter == 5);
}

pub const eventloop = @import("eventloop/eventloop.zig");

pub fn project(_: void) *const fn (void) anyerror!void {
    eventloop.init(allocators.arena());

    return struct {
        pub fn callback(_: void) !void {
            try eventloop.setActive("default");
            eventloop.deinit();
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

pub const allocators = struct {
    fn AllocatorInstance(comptime T: type) type {
        return struct {
            interface: ?T = null,
            allocator: ?Allocator = null,
        };
    }

    pub var AI_generic: AllocatorInstance(std.heap.DebugAllocator(.{})) = .{};
    pub var AI_arena: AllocatorInstance(std.heap.ArenaAllocator) = .{};

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
    pub inline fn scene() noreturn {
        @panic("Not Implemented");
    }
};

pub const Behaviour = ecs.Behaviour;
pub const Entity = ecs.Entity;
pub const Prefab = ecs.Prefab;
pub const Scene = eventloop.Scene;

pub const UUIDv7 = uuid.v7.new;

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
