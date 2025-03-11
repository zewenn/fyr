const std = @import("std");
const Allocator = @import("std").mem.Allocator;

pub fn SharedPtr(comptime T: type) type {
    return struct {
        const Self = @This();

        self_ptr: ?*Self = null,

        alloc: Allocator,
        value: ?T = null,
        ref_count: usize = 0,

        pub fn init(allocator: Allocator, val: T) !Self {
            return Self{
                .self_ptr = null,
                .value = val,
                .alloc = allocator,
            };
        }

        pub fn create(allocator: Allocator, val: T) !*Self {
            const ptr = try allocator.create(Self);

            var self = try Self.init(allocator, val);
            self.self_ptr = ptr;
            ptr.* = self;

            return ptr;
        }

        pub fn deinit(self: *Self) void {
            if (self.ref_count == 0) return;
            self.ref_count -= 1;
        }

        pub fn destroy(self: *Self) void {
            if (self.ref_count > 0) return;
            self.destroyUnsafe();
        }

        /// Destroys this object, no references will be valid after this is called
        pub fn destroyUnsafe(self: *Self) void {
            const alloc = self.alloc;

            alloc.destroy(self);
        }

        pub fn isAlive(self: *Self) bool {
            return self.value != null;
        }

        pub fn valueptr(self: *Self) ?*T {
            self.ref_count += 1;
            return &(self.value orelse return null);
        }

        pub fn this(self: *Self) *Self {
            return self.self_ptr;
        }
    };
}
