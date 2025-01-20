const std = @import("std");
const zap = @import("../../main.zig");

const rl = @import("raylib");
const rg = @import("raygui");

pub const GUIElement = @import("GUIElement.zig");
pub const Style = @import("Style.zig");

const raygui = struct {
    var fnptr: ?(*const fn () anyerror!void) = null;

    pub fn loadStyle(filename: []const u8) !void {
        const full_path = try zap.assets.getAssetFullPath(filename);
        defer zap.getAllocator(.gpa).free(full_path);

        const cpath = @as([*:0]const u8, try zap.getAllocator(.gpa).dupeZ(u8, full_path));
        defer zap.getAllocator(.gpa).free(std.mem.span(cpath));

        rg.guiLoadStyle(cpath);
    }
};

const string = []const u8;

var elements: [512]?GUIElement = [_]?GUIElement{null} ** 512;
var parent_indexes: [512]?usize = [_]?usize{null} ** 512;
var length: usize = 0;
var parent_indexer: usize = 0;
var current_index: usize = 0;

pub fn clear() void {
    for (elements, 0..) |elem, i| {
        if (elem == null) continue;
        const ptr = &(elements[i].?);
        ptr.destroy();
    }
    elements = [_]?GUIElement{null} ** 512;
}

fn len() usize {
    for (elements, 0..) |el, i| {
        if (el != null or i != elements.len - 1) continue;
        length = i;
        break;
    }

    return length;
}

fn current() *GUIElement {
    const ptr = &(elements[current_index]);
    if (ptr.* == null) ptr.* = GUIElement.create();

    return &(ptr.*.?);
}

pub fn ID(str: string) void {
    const ptr = current();
    ptr.id = str;
}

pub fn STYLE(style: Style) void {
    const ptr = current();
    ptr.style = style;
}

pub fn TAGS(str: string) void {
    const ptr = current();
    ptr.tags = str;
}

pub fn Element(_: void) *const fn (void) void {
    const ptr = current();
    if (parent_indexes[parent_indexer]) |pi| Blk: {
        const parent_or_null = &(elements[pi]);
        if (parent_or_null.* == null) break :Blk;

        const parent = &(parent_or_null.*.?);
        parent.children.append(.{ .element = ptr }) catch {
            std.log.warn("Out of memory! Couldn't add GUI child!", .{});
            break :Blk;
        };
    }

    if (parent_indexes[0] != null)
        parent_indexer += 1;
    parent_indexes[parent_indexer] = current_index;
    current_index += 1;
    // std.log.debug(
    //     "\n\nIN\ncurrent: {d} | parent: {d}\nparents: {any}",
    //     .{
    //         current_index,
    //         parent_indexer,
    //         parent_indexes[0..5]
    //     },
    // );

    return struct {
        pub fn c(_: void) void {
            if (parent_indexer >= 1) {
                parent_indexes[parent_indexer] = null;
                parent_indexer -= 1;
            }

            // std.log.debug(
            //     "\n\nOUT\ncurrent: {d} | parent: {d}\nparents: {any}",
            //     .{
            //         current_index,
            //         parent_indexer,
            //         parent_indexes[0..5],
            //     },
            // );
        }
    }.c;
}