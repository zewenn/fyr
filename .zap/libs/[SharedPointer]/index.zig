const std = @import("std");
const Allocator = @import("std").mem.Allocator;

pub fn SharedPointer(comptime T: type) type {
    return struct {
        const Self = @This();

        alloc: Allocator,
        ref_count: usize = 0,
        ptr: ?*T,

        pub fn init(alloc: Allocator, value: T) !Self {
            const p = try alloc.create(T);
            p.* = value;

            return Self{
                .alloc = alloc,
                .ptr = p,
            };
        }

        pub fn incr(self: *Self) void {
            if (self.ptr != null)
                self.ref_count += 1;
        }

        pub fn rmref(self: *Self) void {
            self.ref_count -= if (self.ref_count > 0) 1 else 0;
            if (self.ref_count > 0) return;

            self.deinit();
        }

        pub fn deinit(self: *Self) void {
            const p = self.ptr orelse return;
            self.alloc.destroy(p);
            self.ptr = null;
        }
    };
}
