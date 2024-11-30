const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const uuid = @import("uuid");

const ListOptions = struct {
    /// When enabled, out of bounds indexing will always return null.
    /// The `set()` function will not set any values if they are outside the
    /// scope of the array.
    /// If this is set to false, the safetychecks will be ignored and the
    /// program will panic when you try to index out of bounds.
    allow_out_of_bounds_indexing: bool = false,

    /// When `allow_out_of_bounds_indexing` is enabled and this option is set to
    /// `true`, the program will log an error whenever the program tries to access
    /// out of bounds memory.
    show_out_of_bounds_indexing_error: bool = true,
};

pub fn mList(comptime T: type, comptime options: ListOptions) type {
    return struct {
        const Self = @This();

        slice: []?T,
        alloc: Allocator,

        fn outOfBoundsError(index: usize) void {
            std.log.err("Tried to index out of bounds. Index: {d}", .{index});
        }

        pub fn init(allocator: Allocator) !Self {
            return Self{
                .alloc = allocator,
                .slice = try allocator.alloc(?T, 0),
            };
        }

        pub fn len(self: *Self) usize {
            return @intCast(self.slice.len);
        }

        pub fn at(self: *Self, index: usize) ?T {
            if (options.allow_out_of_bounds_indexing) {
                if (self.len() <= index) {
                    outOfBoundsError(index);
                    return null;
                }
                if (index < 0) {
                    outOfBoundsError(index);
                    return null;
                }
            }

            return self.slice[index];
        }

        pub fn getPtr(self: *Self, index: usize) ?*T {
            if (options.allow_out_of_bounds_indexing) {
                if (self.len() <= index) {
                    outOfBoundsError(index);
                    return null;
                }
                if (index < 0) {
                    outOfBoundsError(index);
                    return null;
                }
            }

            if (self.at(index) == null) return null;

            const ptr: *T = &(self.slice[index].?);
            return ptr;
        }

        /// Sets the given index to a value,
        /// returns the value previously at that index.
        pub fn set(self: *Self, index: usize, value: ?T) ?T {
            if (options.allow_out_of_bounds_indexing) {
                if (self.len() <= index) {
                    outOfBoundsError(index);
                    return null;
                }
                if (index < 0) {
                    outOfBoundsError(index);
                    return null;
                }
            }

            var original: ?T = null;

            if (self.at(index)) |og| {
                original = og;
            }

            self.slice[index] = value;
            return original;
        }

        pub fn append(self: *Self, item: T) !usize {
            for (self.slice, 0..) |s_item, index| {
                if (s_item == null) {
                    _ = self.set(index, item);
                    return index;
                }
            }

            // Slice if full...
            // So we add 1 more space

            const new_slice = try self.alloc.alloc(?T, self.slice.len + 1);
            std.mem.copyForwards(?T, new_slice, self.slice);

            self.alloc.free(self.slice);

            self.slice = new_slice;
            _ = self.set(self.slice.len - 1, item);
            return self.slice.len - 1;
        }

        pub fn sync(self: *Self) !void {
            var nulls_since_last_element: usize = 0;
            for (self.slice) |item| {
                if (item != null) {
                    nulls_since_last_element = 0;
                    continue;
                }

                nulls_since_last_element += 1;
            }

            const new_slice = try self.alloc.alloc(?T, self.slice.len - nulls_since_last_element);
            std.mem.copyForwards(?T, new_slice, self.slice[0 .. self.slice.len - nulls_since_last_element]);

            self.alloc.free(self.slice);

            self.slice = new_slice;
        }

        /// Sets the element at the index
        /// to null and calls `sync()`.
        pub fn remove(self: *Self, index: usize) !void {
            _ = self.set(index, null);
            try self.sync();
        }

        pub fn removeNoSync(self: *Self, index: usize) void {
            _ = self.set(index, null);
        }

        pub fn deinit(self: *Self) void {
            self.alloc.free(self.slice);
        }
    };
}
