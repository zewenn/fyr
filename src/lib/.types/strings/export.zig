const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const assertTitle = @import("../../main.zig").assertTitle;
const assert = @import("../../main.zig").assert;

pub const String = @import("./String.zig");

pub fn string(text: []const u8) !String {
    return try String.new(std.heap.page_allocator, text);
}

pub fn string_test() !void {
    assertTitle("string_test");

    // Init
    var empty = String.init(std.heap.page_allocator);
    defer empty.deinit();

    assert("empty length is 0", empty.len() == 0);
    assert(
        "empty content is \"\" ",
        std.mem.eql(u8, empty.buf(), ""),
    );

    // New
    var myString = try String.new(std.heap.page_allocator, "Hello");
    defer myString.deinit();

    assert("myString length is 5", myString.len() == 5);
    assert(
        "myString content is \"Hello\"",
        std.mem.eql(u8, myString.buf(), "Hello"),
    );

    // Buffer
    var myBuffer: [16]u8 = [_]u8{0} ** 16;
    myString.copyToBuffer(&myBuffer, 20);

    assert(
        "myString copied to buffer",
        std.mem.eql(u8, myBuffer[0..5], myString.buf()),
    );

    // Slice
    var sliced = try myString.slice(5, 2);
    defer sliced.deinit();

    assert(
        "sliced == myString[2..5]",
        std.mem.eql(u8, sliced.buf(), myString.buf()[2..5]),
    );

    // Owned Slice
    const myOwnedSlice = try myString.toOwnedSlice();
    defer myString.alloc.free(myOwnedSlice);

    assert(
        "ownedSlice == myString",
        std.mem.eql(u8, myOwnedSlice, myString.buf()),
    );

    // Lowercase
    var lower = try myString.toLower();
    defer lower.deinit();

    assert(
        "lower content is \"hello\"",
        std.mem.eql(u8, lower.buf(), "hello"),
    );

    // Uppercase
    var upper = try myString.toUpper();
    defer upper.deinit();

    assert(
        "upper content is \"HELLO\"",
        std.mem.eql(u8, upper.buf(), "HELLO"),
    );

    // First-Last
    assert("getFirst() == 'H'", myString.getFirst() == 'H');
    assert("getLast() == 'o'", myString.getLast() == 'o');

    // Concat
    var concatted = try myString.concat(sliced);
    defer concatted.deinit();

    assert(
        "concat content is \"Hellollo\"",
        std.mem.eql(u8, concatted.buf(), "Hellollo"),
    );

    // Eql
    assert("myString != lower", !myString.eql(lower));

    // EqlSlice
    assert("myString == \"Hello\"", myString.eqlSlice("Hello"));
}
