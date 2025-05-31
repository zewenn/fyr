const std = @import("std");
const loom = @import("../root.zig");

const clay = @import("zclay");

const rl = @import("raylib");
const rg = @import("raygui");

const renderer = @import("clay_rl_backend.zig");

/// Opens a new clay element with the given config.
pub fn new(config: clay.ElementDeclaration) *const fn (void) void {
    clay.cdefs.Clay__OpenElement();
    clay.cdefs.Clay__ConfigureOpenElement(config);

    return struct {
        pub fn callback(_: void) void {
            clay.cdefs.Clay__CloseElement();
        }
    }.callback;
}

pub const text = clay.text;

var memory: []u8 = undefined;

const FontEntry = struct {
    const Self = @This();

    name: []const u8,
    id: u16,

    pub fn init(name: []const u8, id: anytype) Self {
        return .{
            .name = name,
            .id = loom.coerceTo(u16, id) orelse 0,
        };
    }
};

var fonts: std.ArrayList(FontEntry) = undefined;
var fonts_cache: std.ArrayList(FontEntry) = undefined;
var font_index: usize = 1;

pub fn init() !void {
    fonts = .init(loom.allocators.generic());
    fonts_cache = .init(loom.allocators.generic());

    const min_memory_size: usize = loom.coerceTo(usize, clay.minMemorySize()).?;
    memory = try loom.allocators.generic().alloc(u8, min_memory_size);

    const arena: clay.Arena = clay.createArenaWithCapacityAndMemory(memory);

    _ = clay.initialize(arena, .{ .h = 1280, .w = 720 }, .{});
    clay.setMeasureTextFunction(void, {}, renderer.measureText);

    renderer.raylib_fonts[0] = try rl.getFontDefault();
}

pub fn update() !void {
    const win_size = loom.window.size.get();
    clay.setLayoutDimensions(.{
        .w = win_size.x,
        .h = win_size.y,
    });

    var render_commands = clay.endLayout();

    try renderer.clayRaylibRender(&render_commands, loom.allocators.generic());

    var cache_clone = try fonts_cache.clone();
    defer cache_clone.deinit();

    for (cache_clone.items, 0..) |cached, index| {
        if (included: {
            for (fonts.items) |current| {
                if (cached.id == current.id) break :included true;
            }
            break :included false;
        })
            continue;

        loom.assets.font.release(cached.name, .{});
        _ = fonts_cache.swapRemove(index);
    }

    fonts_cache.deinit();
    fonts_cache = try fonts.clone();
    fonts.clearAndFree();
}

pub fn deinit() void {
    for (fonts.items) |entry| {
        loom.assets.font.release(entry.name, .{});
    }

    fonts_cache.deinit();
    fonts.deinit();

    loom.allocators.generic().free(memory);
}

fn loadFont(rel_path: []const u8) !void {
    renderer.raylib_fonts[font_index] = (loom.assets.font.get(rel_path, .{}) orelse return error.FontNotFound).*;
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

pub fn color(r: f32, g: f32, b: f32, a: f32) clay.Color {
    return .{ r, g, b, a };
}

pub fn rgba(r: f32, g: f32, b: f32, a: f32) clay.Color {
    return Color.finalise(.{
        .red = r,
        .green = g,
        .blue = b,
        .alpha = a,
    });
}

pub fn rgb(r: f32, g: f32, b: f32) clay.Color {
    return Color.finalise(.{
        .red = r,
        .green = g,
        .blue = b,
    });
}

pub const Color = struct {
    red: f32 = 0,
    green: f32 = 0,
    blue: f32 = 0,
    alpha: f32 = 255,

    pub fn finalise(self: Color) [4]f32 {
        return [4]f32{ self.red, self.green, self.blue, self.alpha };
    }

    pub const white: clay.Color = finalise(.{ .red = 255, .green = 255, .blue = 255 });
    pub const black: clay.Color = finalise(.{});
};

pub fn loadImage(comptime path: [:0]const u8) !rl.Texture2D {
    const texture = try rl.loadTextureFromImage(try rl.loadImageFromMemory(@ptrCast(std.fs.path.extension(path)), @embedFile(path)));
    rl.setTextureFilter(texture, .bilinear);
    return texture;
}
