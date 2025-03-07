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
var fonts: std.ArrayList(fyr.SharedPtr(rl.Font)) = undefined;
var fonts_cache: std.ArrayList(fyr.SharedPtr(rl.Font)) = undefined;

pub fn init() !void {
    fonts = .init(fyr.getAllocator(.generic));
    fonts_cache = .init(fyr.getAllocator(.generic));

    const min_memory_size: usize = fyr.changeNumberType(usize, clay.minMemorySize()).?;
    memory = try fyr.getAllocator(.generic).alloc(u8, min_memory_size);

    const arena: clay.Arena = clay.createArenaWithCapacityAndMemory(memory);

    _ = clay.initialize(arena, .{ .h = 1280, .w = 720 }, .{});

    clay.setMeasureTextFunction({}, renderer.measureText);

    try loadFont("press_play.ttf", 1);
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
                .h = .fixed(200),
            },
        },
        .background_color = .{ 250, 250, 255, 255 },
    })({
        clay.text("Clay - UI Library", .{ .font_size = 24, .color = .{ 0, 0, 0, 255 }, .font_id = 1 });
    });

    var render_commands = clay.endLayout();

    try renderer.clayRaylibRender(&render_commands, fyr.getAllocator(.generic));
}

pub fn useDrawFn(func: *const fn () anyerror!void) void {
    drawfn = func;
}

pub fn deinit() void {
    fyr.getAllocator(.generic).free(memory);
}

pub fn loadFont(rel_path: []const u8, font_id: usize) !void {
    renderer.raylib_fonts[font_id] = (fyr.assets.font.get(rel_path, .{}) orelse return error.FontNotFound).*;
    rl.setTextureFilter(renderer.raylib_fonts[font_id].?.texture, .bilinear);
}

pub fn loadImage(comptime path: [:0]const u8) !rl.Texture2D {
    const texture = try rl.loadTextureFromImage(try rl.loadImageFromMemory(@ptrCast(std.fs.path.extension(path)), @embedFile(path)));
    rl.setTextureFilter(texture, .bilinear);
    return texture;
}
