const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const SMALL_LARGE_ASCII_OFFSET = 32;
const Self = @This();

inner_buffer: ?[]u8 = null,
alloc: Allocator,

/// Creates a new String with the given contents
pub fn new(allocator: Allocator, content: []const u8) !Self {
    var s = Self{
        .alloc = allocator,
    };
    return try s.concatWithBuffer(content);
}

/// Creates a new String with an uninitalised buffer (`null`).
pub fn init(allocator: Allocator) Self {
    return Self{
        .alloc = allocator,
    };
}

pub fn deinit(self: *Self) void {
    if (self.inner_buffer == null) return;
    self.alloc.free(self.inner_buffer.?);
}

/// Shorthand for:
/// ```zig
/// (self.buffer orelse "").len
/// ```
pub fn len(self: Self) usize {
    return (self.inner_buffer orelse "").len;
}

/// Shorthand for:
/// ```zig
/// self.buffer orelse ""
/// ```
pub fn buf(self: Self) []const u8 {
    return self.inner_buffer orelse "";
}

/// Copies `self.buf()` into the `target` buffer
pub fn copyToBuffer(self: *Self, target: []u8, length: usize) void {
    const min_length = @min(self.len(), target.len);
    const final_length = @min(min_length, length);

    std.mem.copyForwards(u8, target[0..final_length], self.buf()[0..final_length]);
}

/// Converts the String into a heap allocated slice;
/// Calller owns the returned memory!
pub fn toOwnedSlice(self: *Self) ![]const u8 {
    const newbuf = try self.alloc.alloc(u8, self.len());
    if (self.inner_buffer) |b| {
        std.mem.copyForwards(u8, newbuf, b);
    }

    return newbuf;
}

/// Duplicates the String
pub fn clone(self: *Self) !Self {
    return try Self.new(self.alloc, self.buf());
}

/// Shorthand for:
/// ```zig
/// self.buf()[index]
/// ```
/// Also implements a safeguard for outofbounds indexing;
/// if `index >= self.len()` the **function returns null**
pub fn at(self: *Self, index: usize) ?u8 {
    if (index >= self.len()) return null;
    return self.buf()[index];
}

/// Shorthand for:
/// ```zig
/// self.buf()[0]
/// ```
/// Also implements a safeguard for outofbounds indexing;
/// if `self.len() == 0` the **function returns 0**
pub fn getFirst(self: *Self) u8 {
    if (self.len() == 0) return 0;
    return self.buf()[0];
}

/// Shorthand for:
/// ```zig
/// self.buf()[self.len() - 1]
/// ```
/// Also implements a safeguard for outofbounds indexing;
/// if `self.len() == 0` the **function returns 0**
pub fn getLast(self: *Self) u8 {
    if (self.len() == 0) return 0;
    return self.buf()[self.len() - 1];
}

/// Turns all lowercase ASCII letters to uppercase.
pub fn toLower(self: *Self) !Self {
    if (self.len() == 0) return Self.init(self.alloc);

    var new_string = try self.clone();

    if (new_string.inner_buffer) |*buff| {
        for (buff.*) |*char| {
            if (char.* < 65 or char.* > 90) continue;
            char.* = char.* + SMALL_LARGE_ASCII_OFFSET;
        }
    }

    return new_string;
}

/// Turns all uppercase ASCII letters to lowercase.
pub fn toUpper(self: *Self) !Self {
    if (self.len() == 0) return Self.init(self.alloc);

    var new_string = try self.clone();

    if (new_string.inner_buffer) |*buff| {
        for (buff.*) |*char| {
            if (char.* < 97 or char.* > 122) continue;
            char.* = char.* - SMALL_LARGE_ASCII_OFFSET;
        }
    }

    return new_string;
}

pub fn concatWithBuffer(self: *Self, other: []const u8) !Self {
    const newbuf = try self.alloc.alloc(u8, self.len() + other.len);

    if (self.inner_buffer) |b| {
        std.mem.copyForwards(u8, newbuf[0..self.len()], b);
    }

    std.mem.copyForwards(u8, newbuf[self.len() .. self.len() + other.len], other);

    return Self{
        .alloc = self.alloc,
        .inner_buffer = newbuf,
    };
}

pub fn concat(self: *Self, other: Self) !Self {
    const newbuf = try self.alloc.alloc(u8, self.len() + other.len());

    if (self.inner_buffer) |b| {
        std.mem.copyForwards(u8, newbuf[0..self.len()], b);
    }

    std.mem.copyForwards(u8, newbuf[self.len() .. self.len() + other.len()], other.buf());

    return Self{
        .alloc = self.alloc,
        .inner_buffer = newbuf,
    };
}

pub fn slice(self: *Self, start: usize, end: usize) !Self {
    const r_start = @min(@min(start, end), self.len() - 1);
    const r_end = @min(@max(start, end), self.len());

    return try Self.new(
        self.alloc,
        self.buf()[r_start..r_end],
    );
}

pub fn eql(self: *Self, other: Self) bool {
    return std.mem.eql(u8, self.buf(), other.buf());
}

pub fn eqlSlice(self: *Self, string_slice: []const u8) bool {
    return std.mem.eql(u8, self.buf(), string_slice);
}
