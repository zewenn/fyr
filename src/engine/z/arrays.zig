const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const math = @import("math.zig");

pub fn Array(comptime T: type, comptime len: usize, comptime val: [len]T) type {
    return struct {
        const Self = @This();

        pub inline fn this() [len]T {
            return val;
        }

        pub fn index(elem: T) ?usize {
            for (val, 0..len) |item, i| {
                if (elem == item) return i;
                if (@as(*anyopaque, @ptrCast(@constCast(&elem))) == @as(*anyopaque, @ptrCast(@constCast(&item)))) {
                    return i;
                }
            }
            return null;
        }

        pub fn at(i: usize) T {
            return val[i];
        }
    };
}

pub fn toManyItemPointerSentinel(alloc: Allocator, m: []const u8) ![*:0]const u8 {
    return @as([*:0]const u8, try alloc.dupeZ(u8, m));
}

pub fn freeManyItemPointerSentinel(alloc: Allocator, m: [*:0]const u8) void {
    alloc.free(std.mem.span(m));
}

pub fn NumberToString(alloc: Allocator, number: anytype) ![]u8 {
    const int_number: i128 = @intFromFloat(math.to_f128(number).?);

    var arr = std.ArrayList(u8).init(alloc);
    defer arr.deinit();

    var pow: i128 = 0;
    while (true) : (pow += 1) {
        const current: i128 = @divTrunc(
            int_number,
            std.math.pow(i128, 10, pow),
        );
        const next: i128 = @divTrunc(
            int_number,
            std.math.pow(i128, 10, pow + 1),
        ) * 10;

        const value: i128 = current - next;

        try arr.insert(0, @as(u8, @intCast(value)) + '0');

        if (next <= 0) break;
    }

    return arr.toOwnedSlice();
}

pub const Direction = enum { up, down, left, right };

pub fn searchMatrixForNext(
    comptime T: type,
    comptime W: usize,
    comptime H: usize,
    matrix: [H][W]?T,
    towards: Direction,
    x: usize,
    y: usize,
) [2]usize {
    // Creating the constants used...
    if (matrix.len == 0) return [2]usize{ 0, 0 };

    const matrix_width = W;
    const matrix_height = H;

    // We will need to extract a slice to search in
    // -> with vertical directions this will be `matrix[y + 1 ..]`
    // -> the tricky part is the horizontal slices, as `matrix[0..][x + 1..]`

    var x_min: usize = 0;
    var x_max: usize = 0;
    var y_min: usize = 0;
    var y_max: usize = 0;

    switch (towards) {
        .up => {
            x_min = 0;
            x_max = matrix_width;
            y_min = 0;
            y_max = if (y == 0) 0 else y;
        },
        .down => {
            x_min = 0;
            x_max = matrix_width;
            y_min = y + 1;
            y_max = matrix_height;
        },
        .left => {
            x_min = 0;
            x_max = if (x == 0) 0 else x;
            y_min = 0;
            y_max = matrix_height;
        },
        .right => {
            x_min = x + 1;
            x_max = matrix_width;
            y_min = 0;
            y_max = matrix_height;
        },
    }

    var closest: [2]usize = undefined;
    var closest_distance: f128 = 0;

    // how many directional matrix slices to look through
    // 0 is the starting middle slice
    // each increment increases the look scope by 1 towards both ends
    for (0..@min(matrix_width, matrix_height)) |scope| {
        const scope_x = switch (towards) {
            .up, .down => scope,
            .left, .right => matrix_width,
        };
        const scope_y = switch (towards) {
            .up, .down => matrix_height,
            .left, .right => scope,
        };

        for (y_min..y_max) |y_range_index| {
            if (y_range_index < (y - @min(y, scope_y)) or
                y_range_index > (y + @min(y_max - @min(y_max, y), scope_y)))
            {
                continue;
            }

            for (x_min..x_max) |x_range_index| {
                if (x_range_index < (x - @min(x, scope_x)) or
                    x_range_index > (x + @min(x_max - @min(x_max, x), scope_x)))
                {
                    continue;
                }

                if (matrix[y_range_index][x_range_index] != null) {
                    const dist = math.getPointDistance(x, y, x_range_index, y_range_index);
                    if (closest_distance == 0 or dist < closest_distance) {
                        closest = [2]usize{ x_range_index, y_range_index };
                        closest_distance = math.getPointDistance(x, y, x_range_index, y_range_index);
                        continue;
                    }
                }
            }
        }
    }

    if (closest_distance != 0) return closest;
    return [2]usize{ x, y };
}

pub fn searchSliceMatrixForNext(
    comptime T: type,
    matrix: [][]?T,
    towards: Direction,
    x: usize,
    y: usize,
) [2]usize {
    // Creating the constants used...
    if (matrix.len == 0) return [2]usize{ 0, 0 };

    const matrix_width = matrix[0].len;
    const matrix_height = matrix.len;

    // We will need to extract a slice to search in
    // -> with vertical directions this will be `matrix[y + 1 ..]`
    // -> the tricky part is the horizontal slices, as `matrix[0..][x + 1..]`

    var x_min: usize = 0;
    var x_max: usize = 0;
    var y_min: usize = 0;
    var y_max: usize = 0;

    switch (towards) {
        .up => {
            x_min = 0;
            x_max = matrix_width;
            y_min = 0;
            y_max = if (y == 0) 0 else y;
        },
        .down => {
            x_min = 0;
            x_max = matrix_width;
            y_min = y + 1;
            y_max = matrix_height;
        },
        .left => {
            x_min = 0;
            x_max = if (x == 0) 0 else x;
            y_min = 0;
            y_max = matrix_height;
        },
        .right => {
            x_min = x + 1;
            x_max = matrix_width;
            y_min = 0;
            y_max = matrix_height;
        },
    }

    var closest: [2]usize = undefined;
    var closest_distance: f128 = 0;

    // how many directional matrix slices to look through
    // 0 is the starting middle slice
    // each increment increases the look scope by 1 towards both ends
    for (0..@min(matrix_width, matrix_height)) |scope| {
        const scope_x = switch (towards) {
            .up, .down => scope,
            .left, .right => matrix_width,
        };
        const scope_y = switch (towards) {
            .up, .down => matrix_height,
            .left, .right => scope,
        };

        for (y_min..y_max) |y_range_index| {
            if (y_range_index < (y - @min(y, scope_y)) or
                y_range_index > (y + @min(y_max - @min(y_max, y), scope_y)))
            {
                continue;
            }

            for (x_min..x_max) |x_range_index| {
                if (x_range_index < (x - @min(x, scope_x)) or
                    x_range_index > (x + @min(x_max - @min(x_max, x), scope_x)))
                {
                    continue;
                }

                if (matrix[y_range_index][x_range_index] != null) {
                    const dist = math.getPointDistance(x, y, x_range_index, y_range_index);
                    if (closest_distance == 0 or dist < closest_distance) {
                        closest = [2]usize{ x_range_index, y_range_index };
                        closest_distance = math.getPointDistance(x, y, x_range_index, y_range_index);
                        continue;
                    }
                }
            }
        }
    }

    if (closest_distance != 0) return closest;
    return [2]usize{ x, y };
}

pub fn cloneToOwnedSlice(comptime T: type, list: std.ArrayList(T)) ![]T {
    var clone = try list.clone();
    defer clone.deinit();

    return try clone.toOwnedSlice();
}
