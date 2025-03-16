const std = @import("std");
const fyr = @import("fyr");

const testing = std.testing;
const expect = testing.expect;

test "[core] coerceTo conversions" {
    const coerceTo = fyr.coerceTo;
    const x = enum(u8) { a = 0, b = 32 };

    // Check if types can be handled properly
    try expect(coerceTo(f32, 0) != null);
    try expect(coerceTo(i32, 0) != null);
    try expect(coerceTo(x, 0) != null);
    try expect(coerceTo(bool, 0) != null);
    try expect(coerceTo(*anyopaque, 1) != null);

    // Check if the correct type is returned
    try expect(@TypeOf(coerceTo(f32, 0).?) == f32);
    try expect(@TypeOf(coerceTo(i32, 0).?) == i32);
    try expect(@TypeOf(coerceTo(x, 0).?) == x);
    try expect(@TypeOf(coerceTo(*anyopaque, 1).?) == *anyopaque);

    // Check if ints get converted correctly
    var int: usize = 32;
    const int_address: usize = @intFromPtr(&int);
    const @"comptime_int": comptime_int = 32;

    try expect(coerceTo(isize, int).? == @as(isize, 32));
    try expect(coerceTo(f32, int).? == @as(f32, 32.0));
    try expect(coerceTo(x, int).? == @as(x, x.b));
    try expect(coerceTo(bool, int).? == @as(bool, true));
    try expect(coerceTo(*usize, int_address).? == &int);

    try expect(coerceTo(isize, @"comptime_int").? == @as(isize, 32));
    try expect(coerceTo(f32, @"comptime_int").? == @as(f32, 32.0));
    try expect(coerceTo(x, @"comptime_int").? == @as(x, x.b));
    try expect(coerceTo(bool, @"comptime_int").? == @as(bool, true));

    // Check if floats get converted correctly
    const float: f64 = 32.34;
    const @"comptime_float": comptime_float = 32.34;

    try expect(coerceTo(isize, float).? == @as(isize, 32));
    try expect(coerceTo(f32, float).? == @as(f32, 32.34));
    try expect(coerceTo(x, float).? == @as(x, x.b));
    try expect(coerceTo(bool, float).? == @as(bool, true));

    try expect(coerceTo(isize, @"comptime_float").? == @as(isize, 32));
    try expect(coerceTo(f32, @"comptime_float").? == @as(f32, 32.34));
    try expect(coerceTo(x, @"comptime_float").? == @as(x, x.b));
    try expect(coerceTo(bool, @"comptime_float").? == @as(bool, true));

    // Check if enums get converted correctly
    const @"enum": x = x.b;

    try expect(coerceTo(isize, @"enum").? == @as(isize, 32));
    try expect(coerceTo(f32, @"enum").? == @as(f32, 32.0));
    try expect(coerceTo(x, @"enum").? == @as(x, x.b));
    try expect(coerceTo(bool, @"enum").? == @as(bool, true));

    // Check if bools get converted correctly
    const boolean: bool = false;

    try expect(coerceTo(isize, boolean).? == @as(isize, 0));
    try expect(coerceTo(f32, boolean).? == @as(f32, 0.0));
    try expect(coerceTo(x, boolean).? == @as(x, x.a));
    try expect(coerceTo(bool, boolean).? == @as(bool, false));

    // Pointer
    const anyopaque_ptr_of_int: *anyopaque = @ptrCast(@alignCast(&int));

    try expect(coerceTo(usize, &int) == int_address);
    try expect(coerceTo(f64, &int) == @as(f64, @floatFromInt(int_address)));
    try expect(coerceTo(bool, &int) == (int_address != 0));
    try expect(coerceTo(x, @as(*anyopaque, @ptrFromInt(32))) == @"enum");
    try expect(coerceTo(*usize, anyopaque_ptr_of_int) == &int);
}

test "[assets] override dev path" {
    fyr.useAssetPaths(.{ .debug = "test" });
    try expect(
        std.mem.eql(
            u8,
            fyr.assets.fs.paths.debug,
            "test",
        ),
    );
}

var run_counter: u8 = 0;
test "Array(T)" {
    var test_array_elements = [_]u8{ 10, 12, 13 };
    var test_array = fyr.array(u8, .{ 10, 12, 13 });
    defer test_array.deinit();

    try expect(std.mem.eql(u8, test_array.items, &test_array_elements));
    try expect(test_array.eqls(@as([]u8, &test_array_elements)));
    try expect(test_array.eqls(test_array));

    // Clone
    var clone = try test_array.clone();
    defer clone.deinit();

    try (expect(std.mem.eql(u8, test_array.items, clone.items)));

    // Reverse
    var reverse = try test_array.reverse();
    defer reverse.deinit();

    var reverse_reversed = try reverse.reverse();
    defer reverse_reversed.deinit();

    try expect(std.mem.eql(u8, test_array.items, reverse_reversed.items));

    // Map
    var doubled = try test_array.map(u8, struct {
        pub fn callback(elem: u8) !u8 {
            return elem * 2;
        }
    }.callback);
    defer doubled.deinit();
    var doubled_elements = [_]u8{ 20, 24, 26 };
    try expect(std.mem.eql(u8, doubled.items, &doubled_elements));

    // Reduce
    const sum: ?u8 = try test_array.reduce(u8, struct {
        pub fn callback(value: u8) !u8 {
            return value;
        }
    }.callback);
    try expect(sum == 10 + 12 + 13);

    // Foreach
    test_array.forEach(struct {
        pub fn callback(_: u8) !void {
            run_counter += 1;
        }
    }.callback);
    try expect(run_counter == 3);

    // Len
    try expect(test_array.len() == 3);
    try expect(test_array.len() == test_array.items.len);
    // Last index
    try expect(test_array.lastIndex() == 2);

    // At
    try expect(test_array.at(0) == test_array.items[0]);
    try expect(test_array.at(0) == 10);

    // PtrAt
    try expect(test_array.ptrAt(0) == &(test_array.items[0]));

    test_array.set(1, 24);
    try expect(test_array.at(1) == 24);

    // GetFirst / GetLast
    try expect(test_array.getFirst() == 10);
    try expect(test_array.getLast() == 13);

    // GetFirstPtr / GetLastPtr
    try expect(test_array.getFirstPtr() == &(test_array.items[0]));
    try expect(test_array.getLastPtr() == &(test_array.items[2]));

    // Slice
    var slice = try test_array.slice(0, 2);
    defer slice.deinit();

    try expect(slice.at(0) == 10);
    try expect(slice.len() == 2);

    // ToOwnedSlice
    const owned = try test_array.toOwnedSlice();
    defer test_array.alloc.free(owned);

    try expect(owned.len == test_array.len());
    try expect(owned[0] == test_array.at(0));

    // ToArrayList
    const array_list = try test_array.toArrayList();
    defer array_list.deinit();

    try expect(array_list.getLastOrNull() == test_array.getLast());
    try expect(array_list.items.len == test_array.len());
}
