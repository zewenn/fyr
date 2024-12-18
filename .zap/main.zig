const std = @import("std");
const Allocator = @import("std").mem.Allocator;

pub const libs = @import("./.codegen/libs.zig");
const engine = @import("./.codegen/modules.zig");

pub const Vector2 = libs.raylib.Vector2;
pub const Vector3 = libs.raylib.Vector3;
pub const Vector4 = libs.raylib.Vector4;
pub const Rectangle = libs.raylib.Rectangle;

const global_allocators = struct {
    pub var gpa: AllocatorInstance(std.heap.GeneralPurposeAllocator(.{})) = .{};
    pub var arena: AllocatorInstance(std.heap.ArenaAllocator) = .{};
    pub var page: Allocator = std.heap.page_allocator;

    pub const types = enum {
        gpa,
        arena,
        page,
    };
};

pub const WrappedArray = libs.WrappedArray.WrappedArray;
pub const WrappedArrayOptions = libs.WrappedArray.WrappedArrayOptions;
pub const array = libs.WrappedArray.array;
pub const arrayAdvanced = libs.WrappedArray.arrayAdvanced;

pub const String = libs.strings.String;
pub const string = libs.strings.string;

pub fn init() !void {
    libs.WrappedArray.ENG_HealthCheck();

    libs.raylib.initWindow(1280, 720, ".zap");

    try libs.eventloop.init();
    try engine.register();

    try libs.eventloop.setActive(0);
}

pub fn loop() !void {
    while (!libs.raylib.windowShouldClose()) {
        libs.eventloop.execute() catch {
            std.log.warn("eventloop.execute() failed!", .{});
        };
    }
}

pub fn deinit() void {
    libs.eventloop.deinit();
    libs.raylib.closeWindow();

    if (global_allocators.gpa.interface) |*intf| {
        const state = intf.deinit();
        switch (state) {
            .ok => std.log.info("GPA exited without memory leaks!", .{}),
            .leak => std.log.warn("GPA exited with a memory leak!", .{}),
        }
    }
    if (global_allocators.arena.interface) |*intf| {
        intf.deinit();
    }
}

pub fn changeType(comptime T: type, value: anytype) ?T {
    return switch (@typeInfo(T)) {
        .Int, .ComptimeInt => switch (@typeInfo(@TypeOf(value))) {
            .Int, .ComptimeInt => @as(T, @intCast(value)),
            .Float, .ComptimeFloat => @as(T, @intFromFloat(@round(value))),
            .Bool => @as(T, @intFromBool(value)),
            .Enum => @as(T, @intFromEnum(value)),
            else => null,
        },
        .Float, .ComptimeFloat => switch (@typeInfo(@TypeOf(value))) {
            .Int, .ComptimeInt => @as(T, @floatFromInt(value)),
            .Float, .ComptimeFloat => @as(T, @floatCast(value)),
            .Bool => @as(T, @floatFromInt(@intFromBool(value))),
            .Enum => @as(T, @floatFromInt(@intFromEnum(value))),
            else => null,
        },
        .Bool => switch (@typeInfo(@TypeOf(value))) {
            .Int, .ComptimeInt => value != 0,
            .Float, .ComptimeFloat => @as(isize, @intFromFloat(@round(value))) != 0,
            .Bool => value,
            .Enum => @as(isize, @intFromEnum(value)) != 0,
            else => null,
        },
        .Enum => switch (@typeInfo(@TypeOf(value))) {
            .Int, .ComptimeInt => @enumFromInt(value),
            .Float, .ComptimeFloat => @enumFromInt(@as(isize, @intFromFloat(@round(value)))),
            .Bool => @enumFromInt(@intFromBool(value)),
            .Enum => @enumFromInt(@as(isize, @intFromEnum(value))),
            else => null,
        },
        else => Catch: {
            std.log.warn(
                "cannot change type of \"{any}\" to type \"{any}\"! (zap.changeType())",
                .{ value, T },
            );
            break :Catch null;
        },
    };
}

pub fn tof32(value: anytype) f32 {
    return changeType(f32, value) orelse 0;
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

pub fn AllocatorInstance(comptime T: type) type {
    return struct {
        interface: ?T = null,
        allocator: ?Allocator = null,
    };
}

pub fn getAllocator(comptime T: global_allocators.types) Allocator {
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
    std.debug.print("\ntest: {s}", .{formatted});
}
