const std = @import("std");
const Allocator = @import("std").mem.Allocator;

pub fn SharedPointer(comptime T: type) type {
    return struct {
        const Self = @This();

        alloc: Allocator,
        ref_count: usize = 0,
        _ptr: ?*T,

        pub fn init(alloc: Allocator, value: T) !Self {
            const p = try alloc.create(T);
            p.* = value;

            return Self{
                .alloc = alloc,
                ._ptr = p,
            };
        }

        pub fn ptr(self: *Self) ?*T {
            if (self._ptr != null)
                self.ref_count += 1;
            return self._ptr;
        }

        pub fn isAlive(self: *Self) bool {
            return self._ptr != null;
        }

        pub fn rmref(self: *Self) void {
            self.ref_count -= if (self.ref_count > 0) 1 else 0;
            if (self.ref_count > 0) return;

            self.deinit();
        }

        pub fn deinit(self: *Self) void {
            const p = self._ptr orelse return;
            self.alloc.destroy(p);
            self._ptr = null;
        }
    };
}
