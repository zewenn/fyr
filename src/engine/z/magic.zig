const std = @import("std");
const Allocator = @import("std").mem.Allocator;

pub fn reshape(comptime T: type) type {
    return struct {
        pub fn array(alloc: Allocator, arr: []T, width: usize, height: usize) ![][]T {
            var matrix = try alloc.alloc([]T, height);
            for (matrix, 0..) |_, index| {
                matrix[index] = try alloc.alloc(T, width);

                for (matrix[index], 0..) |_, jndex| {
                    matrix[index][jndex] = arr[index * width + jndex];
                }
            }

            return matrix;
        }

        pub fn matrix2(alloc: Allocator, matrix: [][]T) ![]T {
            var list = std.ArrayList(T).init(alloc);
            defer list.deinit();

            for (matrix) |row| {
                for (row) |col| {
                    try list.append(col);
                }
            }

            return list.toOwnedSlice();
        }
    };
}
