const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const json = std.json;

pub fn save(allocator: Allocator, value: anytype, path: []const u8) !void {
    const allocated = try json.stringifyAlloc(
        allocator,
        value,
        .{ .whitespace = .indent_4 },
    );
    defer allocator.free(allocated);

    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    try file.writeAll("");
    _ = try file.write(allocated);
}

pub fn load(comptime T: type, allocator: Allocator, path: []const u8) ?T {
    const file = std.fs.cwd().openFile(path, .{}) catch return null;
    defer file.close();

    const contents = file.readToEndAlloc(allocator, 1024000000) catch return null;
    defer allocator.free(contents);
    errdefer allocator.free(contents);

    return json.parseFromSliceLeaky(T, allocator, contents, .{ .allocate = .alloc_always }) catch null;
}
