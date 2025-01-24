const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const fyr = @import("../main.zig");

const assertTitle = fyr.assertTitle;
const assert = fyr.assert;

const changeType = fyr.changeNumberType;
const cloneToOwnedSlice = fyr.cloneToOwnedSlice;

pub const WrappedArrayOptions = struct {
    allocator: Allocator = std.heap.page_allocator,

    try_type_change: bool = true,
    on_type_change_fail: enum {
        ignore,
        panic,
    } = .panic,
};

pub fn WrappedArray(comptime T: type) type {
    return struct {
        const Self = @This();

        alloc: Allocator = std.heap.page_allocator,
        items: []T,

        pub fn init(tuple: anytype, options: WrappedArrayOptions) !Self {
            const allocator = options.allocator;

            var arrlist = std.ArrayList(T).init(allocator);
            defer arrlist.deinit();

            inline for (tuple) |item| {
                const item_value = @as(
                    ?T,
                    if (T != @TypeOf(item))
                        switch (options.try_type_change) {
                            true => changeType(T, item) orelse switch (options.on_type_change_fail) {
                                .ignore => null,
                                .panic => @panic("Tuple had items of incorrect type in it. (With current options this causes a panic!)"),
                            },
                            false => @panic("Tuple had items of incorrect type in it. (With current options this causes a panic!)"),
                        }
                    else
                        item,
                );

                if (item_value) |c| {
                    try arrlist.append(c);
                }
            }

            const new_slice = try arrlist.toOwnedSlice();

            return Self{
                .alloc = allocator,
                .items = new_slice,
            };
        }

        pub fn fromArray(arr: []T, alloc: ?Allocator) !Self {
            const allocator = alloc orelse std.heap.page_allocator;

            const new = try allocator.alloc(T, arr.len);
            std.mem.copyForwards(T, new, arr);

            return Self{
                .items = new,
                .alloc = allocator,
            };
        }

        pub fn fromArrayList(arr: std.ArrayList(T)) !Self {
            const allocator = arr.allocator;

            return Self{
                .items = try cloneToOwnedSlice(T, arr),
                .alloc = allocator,
            };
        }

        pub fn clone(self: Self) !Self {
            const new = try self.alloc.alloc(T, self.items.len);
            std.mem.copyForwards(T, new, self.items);

            return Self{
                .items = new,
                .alloc = self.alloc,
            };
        }

        pub fn reverse(self: Self) !Self {
            const new = try self.alloc.alloc(T, self.items.len);

            for (0..self.items.len) |jndex| {
                const index = self.items.len - 1 - jndex;

                new[jndex] = self.items[index];
            }

            return Self{
                .items = new,
                .alloc = self.alloc,
            };
        }

        pub fn map(self: Self, comptime R: type, map_fn: fn (T) anyerror!R) !WrappedArray(R) {
            var arrlist = std.ArrayList(R).init(self.alloc);
            defer arrlist.deinit();

            for (self.items) |item| {
                try arrlist.append(try map_fn(item));
            }

            return WrappedArray(R){
                .items = try cloneToOwnedSlice(R, arrlist),
                .alloc = self.alloc,
            };
        }

        pub fn len(self: Self) usize {
            return self.items.len;
        }

        pub fn lastIndex(self: Self) usize {
            return self.len() - 1;
        }

        pub fn at(self: Self, index: usize) ?T {
            if (self.len() == 0 or index > self.lastIndex())
                return null;

            return self.items[index];
        }

        pub fn atPtr(self: Self, index: usize) ?*T {
            if (self.len() == 0 or index > self.lastIndex())
                return null;

            return &(self.items[index]);
        }

        pub fn set(self: Self, index: usize, value: T) void {
            const ptr = self.atPtr(index) orelse return;
            ptr.* = value;
        }

        pub fn getFirst(self: Self) ?T {
            return self.at(0);
        }

        pub fn getLast(self: Self) ?T {
            return self.at(self.lastIndex());
        }

        /// Warning: This will allocate a new slice!
        pub fn slice(self: Self, from: usize, to: usize) !Self {
            const start = @min(@min(from, to), self.lastIndex());
            const end = @min(@max(from, to), self.lastIndex());

            return try Self.fromArray(self.items[start..end], self.alloc);
        }

        /// Caller owns the returned memory!
        pub fn toOwnedSlice(self: Self) ![]T {
            const new_slice = try self.alloc.alloc(T, self.len());
            std.mem.copyForwards(T, new_slice, self.items);

            return new_slice;
        }

        pub fn toArrayList(self: Self) !std.ArrayList(T) {
            var list = std.ArrayList(T).init(self.alloc);
            try list.resize(self.len());

            @memcpy(list.items, self.items);

            return list;
        }

        pub fn deinit(self: Self) void {
            self.alloc.free(self.items);
        }
    };
}

pub fn array(comptime T: type, tuple: anytype) WrappedArray(T) {
    return WrappedArray(T).init(tuple, .{}) catch unreachable;
}

pub fn arrayAdvanced(
    comptime T: type,
    options: WrappedArrayOptions,
    tuple: anytype,
) WrappedArray(T) {
    return WrappedArray(T).init(
        tuple,
        options,
    ) catch unreachable;
}
