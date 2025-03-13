const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const fyr = @import("../../../../main.zig");
const t = @import("./types.zig");

const tof32 = fyr.tof32;
const changeType = fyr.coerceTo;

const Self = @This();
const MAX_FRAMES: comptime_float = 10;

name: []const u8,
uuid: u128,

keys: ?[]i32 = null,
keysArrayList: ?std.ArrayList(i32) = null,
keyframes: ?std.AutoHashMap(i32, t.KeyFrame) = null,
unregistered_keyframes: ?std.ArrayList(t.KeyFrame) = null,

/// Length of the entire animation, in seconds.
length: f64 = 0,
timing_function: t.TimingFunction = t.interpolation.lerp,

current_index: usize = 0,
next_index: usize = 0,

current_percent: i32 = 0,

playing: bool = false,
loop: bool = false,
mode: t.Modes = .forwards,

start_time: f64 = 0,

alloc: Allocator,

pub fn init(name: []const u8, length: anytype, timing_function: t.TimingFunction) Self {
    return Self{
        .name = name,
        .uuid = fyr.UUIDV7(),
        .alloc = fyr.allocators.scene(),
        .length = length,
        .timing_function = timing_function,
    };
}

pub fn create(name: []const u8, length: anytype, timing_function: t.TimingFunction, keyframe_tuple: anytype) !Self {
    const keyframes = fyr.array(t.KeyFrame, keyframe_tuple);
    defer keyframes.deinit();

    var self = Self.init(name, length, timing_function);
    for (keyframes.items) |kf| {
        _ = self.append(kf);
    }
    self.close();

    return self;
}

pub fn deinit(self: *Self) void {
    self.playing = false;

    if (self.keyframes) |*skf|
        skf.deinit();

    if (self.unregistered_keyframes) |sukf|
        sukf.deinit();
}

pub fn sortKeys(self: *Self) void {
    const keys_slice = self.keys orelse return;

    switch (self.mode) {
        .forwards => std.sort.insertion(
            i32,
            keys_slice,
            {},
            std.sort.asc(i32),
        ),
        .backwards => std.sort.insertion(
            i32,
            keys_slice,
            {},
            std.sort.desc(i32),
        ),
    }
}

fn makeKeysArrayList(self: *Self) *std.ArrayList(i32) {
    return &(self.keysArrayList orelse Blk: {
        self.keysArrayList = std.ArrayList(i32).init(self.alloc);
        break :Blk self.keysArrayList.?;
    });
}

fn makeKeySliceAndSort(self: *Self) !void {
    const array_list = self.makeKeysArrayList();

    self.keys = try fyr.cloneToOwnedSlice(i32, array_list.*);
    self.sortKeys();
}

pub fn chain(self: *Self, percent: f32, keyframe: t.KeyFrame) *Self {
    const self_keyframes = &(self.keyframes orelse Blk: {
        self.keyframes = std.AutoHashMap(f32, t.KeyFrame).init(self.alloc);
        break :Blk self.keyframes.?;
    });

    if (self_keyframes.getPtr(percent)) |queried_keyframe| {
        std.log.warn("Overriding existing keyframe at percent {d:.2}", .{percent});
        queried_keyframe.* = keyframe;
        return;
    }

    const array_list = self.makeKeysArrayList();

    self_keyframes.put(fyr.toi32(percent), keyframe) catch return self;
    array_list.append(percent) catch return self;

    return self;
}

pub fn append(self: *Self, keyframe: t.KeyFrame) *Self {
    const unregistered_keyframes = &(self.unregistered_keyframes orelse Blk: {
        self.unregistered_keyframes = std.ArrayList(t.KeyFrame).init(self.alloc);
        break :Blk self.unregistered_keyframes.?;
    });

    unregistered_keyframes.append(keyframe) catch return self;

    return self;
}

pub fn close(self: *Self) void {
    const unregistered_keyframes = &(self.unregistered_keyframes orelse return);
    if (self.keys != null) {
        std.log.warn("Animation.close() cannot be used with .chain()!", .{});
        return;
    }

    const keyframes = &(self.keyframes orelse Blk: {
        self.keyframes = std.AutoHashMap(i32, t.KeyFrame).init(self.alloc);
        break :Blk self.keyframes.?;
    });

    const keysArrayList = self.makeKeysArrayList();

    const keyframe_percent_distance: f32 = MAX_FRAMES / tof32(unregistered_keyframes.items.len - 1);
    for (unregistered_keyframes.items, 0..) |keyframe, index| {
        const percent = fyr.toi32(@min(tof32(index) * keyframe_percent_distance, MAX_FRAMES));

        keyframes.put(fyr.toi32(percent), keyframe) catch {
            std.log.warn("Couldn't add percent-keyframe pair!", .{});
        };

        keysArrayList.append(percent) catch {
            std.log.warn("Couldn't add number to keys", .{});
        };
    }

    self.makeKeySliceAndSort() catch return;
}

pub fn next(self: *Self) ?t.KeyFrame {
    const keyframes = &(self.keyframes orelse return null);
    const keys = self.keys orelse return null;

    for (keys) |percent| {
        if (self.current_percent >= percent) continue;

        self.next_index = fyr.coerceTo(usize, percent) orelse 0;
        return keyframes.get(fyr.toi32(percent));
    }

    return null;
}

pub fn current(self: *Self) ?t.KeyFrame {
    const keyframes = &(self.keyframes orelse return null);
    const keys = self.keys orelse return null;

    var last: i32 = 0;

    for (keys) |percent| {
        if (self.current_percent < percent) {
            break;
        }

        last = percent;
        continue;
    }

    return keyframes.get(fyr.toi32(last));
}

pub fn incrementCurrentPercent(self: *Self, increment_to: i32) void {
    self.current_percent = increment_to;

    if (increment_to >= MAX_FRAMES) {
        if (self.loop) {
            self.current_percent = 0;
            return;
        }

        self.current_percent = MAX_FRAMES;
        self.playing = false;
    }
}
