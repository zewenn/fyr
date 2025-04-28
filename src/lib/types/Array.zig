const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const loom = @import("../root.zig");

const coerceTo = loom.coerceTo;
const cloneToOwnedSlice = loom.cloneToOwnedSlice;

pub const ArrayOptions = struct {
    allocator: Allocator = std.heap.page_allocator,

    try_type_change: bool = true,
    on_type_change_fail: enum {
        ignore,
        panic,
    } = .panic,
};

pub fn Array(comptime T: type) type {
    return struct {
        const Self = @This();
        const Error = error{
            IncorrectElementType,
            TypeChangeFailiure,
        };

        alloc: Allocator = std.heap.page_allocator,
        items: []T,

        pub fn create(tuple: anytype) Self {
            return Self.init(tuple, .{}) catch unreachable;
        }

        pub fn init(tuple: anytype, options: ArrayOptions) !Self {
            const allocator = loom.allocators.generic();

            var list = std.ArrayList(T).init(allocator);
            defer list.deinit();

            inline for (tuple) |item| {
                const item_value = @as(
                    ?T,
                    if (T != @TypeOf(item))
                        switch (options.try_type_change) {
                            true => coerceTo(T, item) orelse switch (options.on_type_change_fail) {
                                .ignore => null,
                                .panic => {
                                    std.log.err(
                                        "[Array.init] Tuple had items of incorrect type in it. (With current options this causes a panic!)\n" ++
                                            "\t\tTry setting the options.on_type_change_fail value to .ignore to avoid this error." ++
                                            "\t\tNOTE: .ignore will just skip the incorrect values.",
                                        .{},
                                    );
                                    return Error.TypeChangeFailiure;
                                },
                            },
                            false => {
                                std.log.err(
                                    "[Array.init] Tuple had items of incorrect type in it. (With current options this causes a panic!)\n" ++
                                        "\t\tTry setting the options.try_type_change value to true to avoid this error.",
                                    .{},
                                );
                                return Error.IncorrectElementType;
                            },
                        }
                    else
                        item,
                );

                if (item_value) |c| {
                    try list.append(c);
                }
            }

            const new_slice = try list.toOwnedSlice();

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

        pub fn eqls(self: Self, other: anytype) bool {
            const K = @TypeOf(other);
            if (K == Self) {
                return std.mem.eql(T, self.items, @field(other, "items"));
            }
            if (K == []T) {
                return std.mem.eql(T, self.items, other);
            }

            return std.meta.eql(self.items, other);
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

        pub fn map(self: Self, comptime R: type, map_fn: fn (T) anyerror!R) !Array(R) {
            var arrlist = std.ArrayList(R).init(self.alloc);
            defer arrlist.deinit();

            for (self.items) |item| {
                try arrlist.append(try map_fn(item));
            }

            return Array(R){
                .items = try cloneToOwnedSlice(R, arrlist),
                .alloc = self.alloc,
            };
        }

        pub fn reduce(self: Self, comptime R: type, reduce_fn: fn (T) anyerror!R) !?R {
            var value: ?R = null;

            for (self.items) |item| {
                if (value == null) {
                    value = reduce_fn(item) catch null;
                    continue;
                }

                const val = reduce_fn(item) catch continue;

                value = value.? + val;
            }

            return value;
        }

        pub fn forEach(self: *Self, func: fn (T) anyerror!void) void {
            for (self.items) |item| {
                func(item) catch {};
            }
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

        pub fn ptrAt(self: Self, index: usize) ?*T {
            if (self.len() == 0 or index > self.lastIndex())
                return null;

            return &(self.items[index]);
        }

        pub fn set(self: Self, index: usize, value: T) void {
            const ptr = self.ptrAt(index) orelse return;
            ptr.* = value;
        }

        pub fn getFirst(self: Self) ?T {
            return self.at(0);
        }

        pub fn getLast(self: Self) ?T {
            return self.at(self.lastIndex());
        }

        pub fn getFirstPtr(self: Self) ?*T {
            return self.ptrAt(0);
        }

        pub fn getLastPtr(self: Self) ?*T {
            return self.ptrAt(self.lastIndex());
        }

        /// Caller owns the returned memory.
        pub fn slice(self: Self, from: usize, to: usize) !Self {
            const start = @min(@min(from, to), self.lastIndex());
            const end = @min(@max(from, to), self.lastIndex());

            return try Self.fromArray(self.items[start..end], self.alloc);
        }

        /// Caller owns the returned memory. Does not empty the array.
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

pub fn array(comptime T: type, tuple: anytype) Array(T) {
    return Array(T).init(tuple, .{}) catch unreachable;
}

pub fn arrayAdvanced(
    comptime T: type,
    options: ArrayOptions,
    tuple: anytype,
) Array(T) {
    return Array(T).init(
        tuple,
        options,
    ) catch unreachable;
}
