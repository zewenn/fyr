const std = @import("std");
const fyr = @import("../../main.zig");

const clay = @import("zclay");

const rl = @import("raylib");
const rg = @import("raygui");

const renderer = @import("clay_rl_backend.zig");

pub const raygui = struct {
    var fnptr: ?(*const fn () anyerror!void) = null;

    pub fn loadStyle(filename: []const u8) !void {
        const full_path = try fyr.assets.fs.getFilePath(filename);
        defer fyr.getAllocator(.generic).free(full_path);

        const cpath = @as([:0]const u8, try fyr.getAllocator(.generic).dupeZ(u8, full_path));
        defer fyr.getAllocator(.generic).free(std.mem.span(cpath));

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

var memory: []u8 = undefined;
var drawfn: ?*const fn () anyerror!void = null;

const FontEntry = struct {
    const Self = @This();

    name: []const u8,
    id: u16,

    pub fn init(name: []const u8, id: anytype) Self {
        return .{
            .name = name,
            .id = fyr.changeNumberType(u16, id) orelse 0,
        };
    }
};

var fonts: std.ArrayList(FontEntry) = undefined;
var fonts_cache: std.ArrayList(FontEntry) = undefined;
var font_index: usize = 1;

pub fn init() !void {
    fonts = .init(fyr.getAllocator(.generic));
    fonts_cache = .init(fyr.getAllocator(.generic));

    const min_memory_size: usize = fyr.changeNumberType(usize, clay.minMemorySize()).?;
    memory = try fyr.getAllocator(.generic).alloc(u8, min_memory_size);

    const arena: clay.Arena = clay.createArenaWithCapacityAndMemory(memory);

    _ = clay.initialize(arena, .{ .h = 1280, .w = 720 }, .{});

    clay.setMeasureTextFunction({}, renderer.measureText);

    renderer.raylib_fonts[0] = try rl.getFontDefault();
}

pub fn update() !void {
    const mouse_position = rl.getMousePosition();

    clay.setPointerState(.{
        .x = mouse_position.x,
        .y = mouse_position.y,
    }, rl.isMouseButtonDown(.left));

    clay.beginLayout();
    if (drawfn) |dfn|
        dfn() catch std.log.warn("failed to execute draw function", .{});

    clay.UI()(.{
        .id = .ID("test"),
        .layout = .{
            .sizing = .{
                .w = .fixed(300),
                .h = .fit,
            },
            .padding = .all(10),
        },
        .background_color = .{ 250, 250, 255, 255 },
    })({
        clay.text("Clay - UI Library", .{
            .font_size = 12,
            .letter_spacing = 1,
            .color = .{ 0, 0, 0, 255 },
            .font_id = fontID("press_play.ttf"),
        });
    });

    var render_commands = clay.endLayout();

    try renderer.clayRaylibRender(&render_commands, fyr.getAllocator(.generic));

    var cache_clone = try fonts_cache.clone();
    defer cache_clone.deinit();

    for (cache_clone.items, 0..) |cached, index| {
        const included = Blk: {
            for (fonts.items) |current| {
                if (cached.id == current.id) break :Blk true;
            }
            break :Blk false;
        };

        if (included) continue;

        fyr.assets.font.release(cached.name, .{});
        _ = fonts_cache.swapRemove(index);
    }

    fonts_cache.deinit();
    fonts_cache = try fonts.clone();
    fonts.clearAndFree();
}

pub fn useDrawFn(func: *const fn () anyerror!void) void {
    drawfn = func;
}

pub fn deinit() void {
    for (fonts.items) |entry| {
        fyr.assets.font.release(entry.name, .{});
    }

    fonts_cache.deinit();
    fonts.deinit();

    fyr.getAllocator(.generic).free(memory);
}

fn loadFont(rel_path: []const u8) !void {
    renderer.raylib_fonts[font_index] = (fyr.assets.font.get(rel_path, .{}) orelse return error.FontNotFound).*;
    rl.setTextureFilter(renderer.raylib_fonts[font_index].?.texture, .bilinear);
}

/// Get the corresponding font id for a file path
pub fn fontID(rel_path: []const u8) u16 {
    for (fonts.items) |font_entry| {
        if (!std.mem.eql(u8, font_entry.name, rel_path)) continue;
        if (renderer.raylib_fonts[font_entry.id] == null) continue;
        return font_entry.id;
    }

    for (fonts_cache.items) |font_entry| {
        if (!std.mem.eql(u8, font_entry.name, rel_path)) continue;
        if (renderer.raylib_fonts[font_entry.id] == null) continue;

        fonts.append(font_entry) catch return 0;
        return font_entry.id;
    }

    font_index += 1;
    if (font_index >= 10) {
        font_index = 1;
    }

    const font_entry: FontEntry = .init(rel_path, font_index);
    loadFont(rel_path) catch return 0;
    fonts.append(font_entry) catch return 0;

    return font_entry.id;
}

pub fn loadImage(comptime path: [:0]const u8) !rl.Texture2D {
    const texture = try rl.loadTextureFromImage(try rl.loadImageFromMemory(@ptrCast(std.fs.path.extension(path)), @embedFile(path)));
    rl.setTextureFilter(texture, .bilinear);
    return texture;
}
