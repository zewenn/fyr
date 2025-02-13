const std = @import("std");
const fyr = @import("../../main.zig");

const rl = @import("raylib");
const rg = @import("raygui");

pub const Element = @import("Element.zig");
pub const Style = @import("Style.zig");

const renderer = @import("./renderer.zig");

pub const raygui = struct {
    var fnptr: ?(*const fn () anyerror!void) = null;

    pub fn loadStyle(filename: []const u8) !void {
        const full_path = try fyr.assets.fs.getFilePath(filename);
        defer fyr.getAllocator(.gpa).free(full_path);

        const cpath = @as([*:0]const u8, try fyr.getAllocator(.gpa).dupeZ(u8, full_path));
        defer fyr.getAllocator(.gpa).free(std.mem.span(cpath));

        rg.guiLoadStyle(cpath);
    }

    pub fn setRayGuiFunction(ptr: *const fn () anyerror!void) void {
        fnptr = ptr;
    }

    pub fn callDrawFn() void {
        (fnptr orelse return)() catch {
            std.log.warn("Failed to call raygui fn", .{});
            return;
        };
    }
};

pub fn render() void {
    renderer.render(&elements) catch {
        std.log.err("gui render failed", .{});
    };
}

const string = []const u8;
var _arena: ?std.heap.ArenaAllocator = null;
var _alloc: ?std.mem.Allocator = null;

var elements: [512]?Element = [_]?Element{null} ** 512;
var parent_indexes: [512]?usize = [_]?usize{null} ** 512;
var length: usize = 0;
var parent_index: usize = 0;
var current_index: usize = 0;

pub fn init() void {
    _arena = std.heap.ArenaAllocator.init(fyr.getAllocator(.gpa));
    _alloc = _arena.?.allocator();
}

pub fn deinit() void {
    reset();
    arena().deinit();
}

pub fn arena() *std.heap.ArenaAllocator {
    return &(_arena orelse fyr.panic("UI arena allocator wasn't initalised!", .{}));
}

pub fn alloc() std.mem.Allocator {
    return _alloc orelse fyr.panic("UI arena allocator wasn't initalised!", .{});
}

pub fn reset() void {
    _ = arena().reset(.free_all);

    for (elements, 0..) |elem, i| {
        if (elem == null) continue;
        const ptr = &(elements[i].?);

        if (ptr.style.font.family) |ff|
            fyr.assets.font.release(ff, .{});

        ptr.destroy();
    }
    elements = [_]?Element{null} ** 512;
    parent_indexes = [_]?usize{null} ** 512;

    current_index = 0;
    parent_index = 0;

    for (elements, 0..) |elem, i| {
        if (elem == null) continue;
        const ptr = &(elements[i].?);

        if (ptr.style.font.family) |ff|
            fyr.assets.font.release(ff, .{});
    }
}

pub fn sceneUnload() void {
    reset();
}

fn len() usize {
    for (elements, 0..) |el, i| {
        if (el != null or i != elements.len - 1) continue;
        length = i;
        break;
    }

    return length;
}

fn current() *Element {
    const ptr = &(elements[current_index]);
    if (ptr.* == null) ptr.* = Element.create();

    return &(ptr.*.?);
}

pub fn id(str: string) void {
    const ptr = current();
    ptr.id = str;
}

pub fn style(_style: Style) void {
    const ptr = current();
    ptr.style = _style;
}

pub fn tags(str: string) void {
    const ptr = current();
    ptr.tags = str;
}

pub fn elementType(T: Element.ElementType) void {
    const ptr = current();
    ptr.type = T;
}

pub fn text(comptime fmt: []const u8, args: anytype) void {
    const ptr = &(elements[parent_indexes[parent_index] orelse 511] orelse current().*);
    const t: [*:0]const u8 = std.fmt.allocPrintZ(alloc(), fmt, args) catch AllocFail: {
        std.log.err("Failed to allocate formatted text!", .{});
        break :AllocFail "";
    };
    ptr.text = t;
}

pub fn element(_: void) *const fn (void) void {
    const ptr = current();
    if (parent_indexes[parent_index]) |pi| Blk: {
        const parent_or_null = &(elements[pi]);
        if (parent_or_null.* == null) break :Blk;

        const parent = &(parent_or_null.*.?);
        ptr.parent = parent;
        parent.children.append(ptr) catch {
            std.log.warn("Out of memory! Couldn't add GUI child!", .{});
            break :Blk;
        };
    }

    if (parent_indexes[0] != null)
        parent_index += 1;

    parent_indexes[parent_index] = current_index;
    current_index += 1;

    return struct {
        pub fn c(_: void) void {
            if (parent_index >= 1) {
                parent_indexes[parent_index] = null;
                parent_index -= 1;
            }
        }
    }.c;
}
