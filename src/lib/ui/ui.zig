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

const TextureCache = struct {
    name: []const u8,

    texture: *rl.Texture2D,
    size: loom.Vector2,
    refs: usize,
};

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

var textures: std.ArrayList(TextureCache) = undefined;
var fonts: std.ArrayList(FontEntry) = undefined;
var fonts_cache: std.ArrayList(FontEntry) = undefined;
var font_index: usize = 1;

pub fn init() !void {
    fonts = .init(loom.allocators.generic());
    fonts_cache = .init(loom.allocators.generic());
    textures = .init(loom.allocators.generic());

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

    for (textures.items) |*texture| {
        if (texture.refs == 0) loom.assets.texture.release(texture.name, .{ 1, 1 });
        texture.refs = 0;
    }
}

pub fn deinit() void {
    for (fonts.items) |entry| {
        loom.assets.font.release(entry.name, .{});
    }

    for (textures.items) |texture| {
        loom.assets.texture.release(texture.name, .{ texture.size.x, texture.size.y });
    }

    fonts_cache.deinit();
    fonts.deinit();
    textures.deinit();

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

pub fn opacity(colour: clay.Color, target: f32) clay.Color {
    return .{ colour[0], colour[1], colour[2], target };
}

pub fn dim(colour: clay.Color, by: f32) clay.Color {
    return .{ @max(0, colour[0] - by), @max(0, colour[1] - by), @max(0, colour[2] - by), colour[3] };
}

/// Parses a hex color code (0xRRGGBBAA) into 4 f32 components (0-255).
///
/// Args:
///   hex_color: The 32-bit unsigned integer representing the hex color.
///              Expected format is 0xRRGGBBAA.
///
/// Returns:
///   A struct containing the red, green, blue, and alpha components as f32.
///   Each component will be in the range of 0.0 to 255.0.
pub fn hex(hex_colour: u32) [4]f32 {

    // RR GG BB AA
    //

    const r = loom.tof32((hex_colour >> 24) & 0xFF);
    const g = loom.tof32((hex_colour >> 16) & 0xFF);
    const b = loom.tof32((hex_colour >> 8) & 0xFF);
    const a = loom.tof32(hex_colour & 0xFF);

    return .{ r, g, b, a };
}

test hex {
    const color1 = 0xFF0080FF; // Red: 255, Green: 0, Blue: 128, Alpha: 255
    const parsed_color1 = hex(color1);
    try std.testing.expectEqualF32(parsed_color1.r, 255.0);
    try std.testing.expectEqualF32(parsed_color1.g, 0.0);
    try std.testing.expectEqualF32(parsed_color1.b, 128.0);
    try std.testing.expectEqualF32(parsed_color1.a, 255.0);

    const color2 = 0x00FF0080; // Red: 0, Green: 255, Blue: 0, Alpha: 128
    const parsed_color2 = hex(color2);
    try std.testing.expectEqualF32(parsed_color2.r, 0.0);
    try std.testing.expectEqualF32(parsed_color2.g, 255.0);
    try std.testing.expectEqualF32(parsed_color2.b, 0.0);
    try std.testing.expectEqualF32(parsed_color2.a, 128.0);

    const color3 = 0x12345678;
    const parsed_color3 = hex(color3);
    try std.testing.expectEqualF32(parsed_color3.r, 18.0);
    try std.testing.expectEqualF32(parsed_color3.g, 52.0);
    try std.testing.expectEqualF32(parsed_color3.b, 86.0);
    try std.testing.expectEqualF32(parsed_color3.a, 120.0);
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

pub fn image(path: []const u8, size: loom.Vector2) !clay.ImageElementConfig {
    for (textures.items) |*texture| {
        if (!std.mem.eql(u8, path, texture.name)) continue;

        texture.refs += 1;
        return clay.ImageElementConfig{
            .image_data = texture.texture,
            .source_dimensions = loom.vec2ToDims(texture.size),
        };
    }

    const entry: TextureCache = .{
        .name = path,
        .refs = 1,
        .size = size,
        .texture = loom.assets.texture.get(path, .{ size.x, size.y }) orelse return error.NoImageFound,
    };

    try textures.append(entry);

    return clay.ImageElementConfig{
        .image_data = entry.texture,
        .source_dimensions = loom.vec2ToDims(size),
    };
}
