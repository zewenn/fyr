const std = @import("std");
const fyr = @import("fyr");

const testing = std.testing;

test "[core] changeNumberType conversions" {
    const changeNumberType = fyr.changeNumberType;
    const expect = testing.expect;
    const x = enum(u8) { a = 0, b = 32 };

    // Check if types can be handled properly
    try expect(changeNumberType(f32, 0) != null);
    try expect(changeNumberType(i32, 0) != null);
    try expect(changeNumberType(x, 0) != null);
    try expect(changeNumberType(bool, 0) != null);
    try expect(changeNumberType(*anyopaque, 1) != null);

    // Check if the correct type is returned
    try expect(@TypeOf(changeNumberType(f32, 0).?) == f32);
    try expect(@TypeOf(changeNumberType(i32, 0).?) == i32);
    try expect(@TypeOf(changeNumberType(x, 0).?) == x);
    try expect(@TypeOf(changeNumberType(*anyopaque, 1).?) == *anyopaque);

    // Check if ints get converted correctly
    var int: usize = 32;
    const int_address: usize = @intFromPtr(&int);
    const @"comptime_int": comptime_int = 32;

    try expect(changeNumberType(isize, int).? == @as(isize, 32));
    try expect(changeNumberType(f32, int).? == @as(f32, 32.0));
    try expect(changeNumberType(x, int).? == @as(x, x.b));
    try expect(changeNumberType(bool, int).? == @as(bool, true));
    try expect(changeNumberType(*usize, int_address).? == &int);

    try expect(changeNumberType(isize, @"comptime_int").? == @as(isize, 32));
    try expect(changeNumberType(f32, @"comptime_int").? == @as(f32, 32.0));
    try expect(changeNumberType(x, @"comptime_int").? == @as(x, x.b));
    try expect(changeNumberType(bool, @"comptime_int").? == @as(bool, true));

    // Check if floats get converted correctly
    const float: f64 = 32.34;
    const @"comptime_float": comptime_float = 32.34;

    try expect(changeNumberType(isize, float).? == @as(isize, 32));
    try expect(changeNumberType(f32, float).? == @as(f32, 32.34));
    try expect(changeNumberType(x, float).? == @as(x, x.b));
    try expect(changeNumberType(bool, float).? == @as(bool, true));

    try expect(changeNumberType(isize, @"comptime_float").? == @as(isize, 32));
    try expect(changeNumberType(f32, @"comptime_float").? == @as(f32, 32.34));
    try expect(changeNumberType(x, @"comptime_float").? == @as(x, x.b));
    try expect(changeNumberType(bool, @"comptime_float").? == @as(bool, true));

    // Check if enums get converted correctly
    const @"enum": x = x.b;

    try expect(changeNumberType(isize, @"enum").? == @as(isize, 32));
    try expect(changeNumberType(f32, @"enum").? == @as(f32, 32.0));
    try expect(changeNumberType(x, @"enum").? == @as(x, x.b));
    try expect(changeNumberType(bool, @"enum").? == @as(bool, true));

    // Check if bools get converted correctly
    const boolean: bool = false;

    try expect(changeNumberType(isize, boolean).? == @as(isize, 0));
    try expect(changeNumberType(f32, boolean).? == @as(f32, 0.0));
    try expect(changeNumberType(x, boolean).? == @as(x, x.a));
    try expect(changeNumberType(bool, boolean).? == @as(bool, false));

    // Pointer
    const anyopaque_ptr_of_int: *anyopaque = @ptrCast(@alignCast(&int));

    try expect(changeNumberType(usize, &int) == int_address);
    try expect(changeNumberType(f64, &int) == @as(f64, @floatFromInt(int_address)));
    try expect(changeNumberType(bool, &int) == (int_address != 0));
    try expect(changeNumberType(x, @as(*anyopaque, @ptrFromInt(32))) == @"enum");
    try expect(changeNumberType(*usize, anyopaque_ptr_of_int) == &int);
}

test "[assets] override dev path" {
    const expect = std.testing.expect;

    fyr.useAssetPaths(.{ .debug = "test" });
    try expect(
        std.mem.eql(
            u8,
            fyr.assets.fs.paths.debug,
            "test",
        ),
    );
}
