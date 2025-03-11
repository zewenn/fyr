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

    // Check if the correct type is returned
    try expect(@TypeOf(changeNumberType(f32, 0).?) == f32);
    try expect(@TypeOf(changeNumberType(i32, 0).?) == i32);
    try expect(@TypeOf(changeNumberType(x, 0).?) == x);
    try expect(@TypeOf(changeNumberType(bool, 0).?) == bool);

    // Check if ints get converted correctly
    const int: usize = 32;
    const compint: comptime_int = 32;

    try expect(changeNumberType(isize, int).? == @as(isize, 32));
    try expect(changeNumberType(f32, int).? == @as(f32, 32.0));
    try expect(changeNumberType(x, int).? == @as(x, x.b));
    try expect(changeNumberType(bool, int).? == @as(bool, true));

    try expect(changeNumberType(isize, compint).? == @as(isize, 32));
    try expect(changeNumberType(f32, compint).? == @as(f32, 32.0));
    try expect(changeNumberType(x, compint).? == @as(x, x.b));
    try expect(changeNumberType(bool, compint).? == @as(bool, true));

    // Check if floats get converted correctly
    const float: f64 = 32.34;
    const compfloat: comptime_float = 32.34;

    try expect(changeNumberType(isize, float).? == @as(isize, 32));
    try expect(changeNumberType(f32, float).? == @as(f32, 32.34));
    try expect(changeNumberType(x, float).? == @as(x, x.b));
    try expect(changeNumberType(bool, float).? == @as(bool, true));

    try expect(changeNumberType(isize, compfloat).? == @as(isize, 32));
    try expect(changeNumberType(f32, compfloat).? == @as(f32, 32.34));
    try expect(changeNumberType(x, compfloat).? == @as(x, x.b));
    try expect(changeNumberType(bool, compfloat).? == @as(bool, true));

    // Check if enums get converted correctly
    const enm: x = x.b;

    try expect(changeNumberType(isize, enm).? == @as(isize, 32));
    try expect(changeNumberType(f32, enm).? == @as(f32, 32.0));
    try expect(changeNumberType(x, enm).? == @as(x, x.b));
    try expect(changeNumberType(bool, enm).? == @as(bool, true));

    // Check if bools get converted correctly
    const bo_l: bool = false;

    try expect(changeNumberType(isize, bo_l).? == @as(isize, 0));
    try expect(changeNumberType(f32, bo_l).? == @as(f32, 0.0));
    try expect(changeNumberType(x, bo_l).? == @as(x, x.a));
    try expect(changeNumberType(bool, bo_l).? == @as(bool, false));
}

test "[assets] override dev path" {
    const expect = std.testing.expect;

    fyr.useDebugAssetPath("test");
    try expect(
        std.mem.eql(
            u8,
            fyr.assets.fs.debug,
            "test",
        ),
    );
}
