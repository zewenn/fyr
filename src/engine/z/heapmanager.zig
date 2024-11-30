const std = @import("std");
const Allocator = @import("std").mem.Allocator;

pub fn HeapManager(comptime T: type, comptime freeId: ?*const fn (Allocator, *T) anyerror!void) type {
    return struct {
        var array: std.ArrayList(*T) = undefined;
        pub var alloc: Allocator = undefined;
        var initalised = false;

        pub fn init(allocator: Allocator) void {
            initalised = true;
            alloc = allocator;

            array = std.ArrayList(*T).init(alloc);
        }

        pub fn deinit() void {
            for (array.items) |it| {
                alloc.destroy(it);
            }
            array.deinit();
        }

        pub fn append(item: T) !void {
            if (!initalised) @panic("Manager was not initalised!");
            const ptr = try alloc.create(T);
            ptr.* = item;

            try array.append(ptr);
        }

        pub fn appendReturn(item: T) !*T {
            if (!initalised) @panic("Manager was not initalised!");
            const ptr = try alloc.create(T);
            ptr.* = item;

            try array.append(ptr);
            return array.items[len() - 1];
        }

        pub fn remove(item: *T) void {
            if (!initalised) @panic("Manager was not initalised!");
            for (array.items, 0..) |it, index| {
                if (!std.meta.eql(item.*, it.*)) continue;
                alloc.destroy(it);
                _ = array.swapRemove(index);
                return;
            }
        }

        pub fn removeFreeId(item: *T) void {
            if (!initalised) @panic("Manager was not initalised!");
            for (array.items, 0..) |it, index| {
                if (!std.meta.eql(item.*, it.*)) continue;

                if (freeId) |func| {
                    func(alloc, item) catch {
                        std.log.err("An error occured in removeFreeId", .{});
                    };
                }

                alloc.destroy(it);
                _ = array.swapRemove(index);
                return;
            }
        }

        /// Caller owns the returned memory!
        pub fn items() ![]*T {
            if (!initalised) @panic("Manager was not initalised!");
            var copy = try array.clone();

            return copy.toOwnedSlice();
        }

        pub fn free(memory: anytype) void {
            alloc.free(memory);
        }

        pub fn len() usize {
            if (!initalised) @panic("Manager was not initalised!");
            return array.items.len;
        }
    };
}
