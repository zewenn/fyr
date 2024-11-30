const std = @import("std");
const rl = @import("raylib");
const Allocator = @import("std").mem.Allocator;
const z = @import("./z/z.m.zig");

pub const Image = rl.Image;
pub const Sound = rl.Sound;
pub const Wave = rl.Wave;
pub const Font = rl.Font;

const json = std.json;

const saveloader = @import("saveloader.zig");

const filenames = @import("../.temp/filenames.zig").Filenames;
var files: [filenames.len][]const u8 = undefined;

var image_map: std.StringHashMap(Image) = undefined;
var wave_map: std.StringHashMap(Wave) = undefined;
var font_map: std.StringHashMap(Font) = undefined;
var json_map: std.StringHashMap([]const u8) = undefined;
var lvldat_map: std.StringHashMap([]const u8) = undefined;

var alloc: Allocator = undefined;

pub inline fn compile(allocator: Allocator) !void {
    var content_arr: std.ArrayListAligned([]const u8, null) = undefined;
    content_arr = std.ArrayList([]const u8).init(allocator);
    defer content_arr.deinit();

    inline for (filenames) |filename| {
        try content_arr.append(@embedFile("../assets/" ++ filename));
    }

    const x2 = content_arr.toOwnedSlice() catch unreachable;
    defer allocator.free(x2);

    std.mem.copyForwards([]const u8, &files, x2);
}

pub fn init(allocator: Allocator) !void {
    std.log.info("ASSETS: Loading...", .{});
    alloc = allocator;
    image_map = std.StringHashMap(Image).init(alloc);
    wave_map = std.StringHashMap(Wave).init(alloc);
    font_map = std.StringHashMap(Font).init(alloc);
    json_map = std.StringHashMap([]const u8).init(alloc);
    lvldat_map = std.StringHashMap([]const u8).init(alloc);

    for (filenames, files) |name, data| {
        // Images
        if (std.mem.eql(u8, name[name.len - 3 .. name.len], "png")) {
            const img = rl.loadImageFromMemory(".png", data);
            try image_map.put(name, img);
        }
        if (std.mem.eql(u8, name[name.len - 3 .. name.len], "jpg")) {
            const img = rl.loadImageFromMemory(".jpg", data);
            try image_map.put(name, img);
        }

        // Audio
        if (std.mem.eql(u8, name[name.len - 3 .. name.len], "mp3")) {
            const wave = rl.loadWaveFromMemory(".mp3", data);
            try wave_map.put(name, wave);
        }
        if (std.mem.eql(u8, name[name.len - 3 .. name.len], "wav")) {
            const wave = rl.loadWaveFromMemory(".wav", data);
            try wave_map.put(name, wave);
        }

        // JSON
        if (std.mem.eql(u8, name[name.len - 4 .. name.len], "json")) {
            try json_map.put(name, data);
        }

        // LVLDAT
        if (std.mem.eql(u8, name[name.len - 6 .. name.len], "lvldat")) {
            try lvldat_map.put(name, data);
        }

        // Fonts
        if (std.mem.eql(u8, name[name.len - 3 .. name.len], "ttf")) {
            var fontChars = [_]i32{
                48, 49, 50, 51, 52, 53, 54, 55, 56, 57, // 0-9
                65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, // A-Z
                97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, // a-z
                33, 34, 35, 36,  37,  38,  39,  40,  41,  42,  43,  44,  45,  46,  47,  58,  59,  60,  61,  62,  63,  64,  91,  92,  93,  94,
                95, 96, 123, 124, 125, 126, // !, ", #, $, %, &, ', (, ), *, +, ,, -, ., /, :, ;, <, =, >, ?, @, [, \, ], ^, _, `, {, |, }, ~
            };

            const font = rl.loadFontFromMemory(".ttf", data, 256, &fontChars);
            try font_map.put(name, font);
        }
    }
    std.log.info("ASSETS: Loaded", .{});
}

pub const get = struct {
    fn errorPrint(T: []const u8, name: []const u8) void {
        std.log.err("{s} with the name of \"{s}\" does not exist!", .{ T, name });
    }

    pub fn image(name: []const u8) ?rl.Image {
        if (image_map.getPtr(name)) |img| {
            return rl.imageCopy(img.*);
        }

        errorPrint("Image", name);
        return rl.imageCopy(image_map.get("sprites/missingno.png").?);
    }

    pub fn wave(name: []const u8) ?rl.Sound {
        if (wave_map.get(name)) |wav| {
            const sound = rl.loadSoundFromWave(wav);
            return sound;
        }

        errorPrint("Wave", name);
        return null;
    }

    pub fn font(name: []const u8) ?rl.Font {
        if (font_map.get(name)) |fnt| {
            return fnt;
        }

        errorPrint("Font", name);
        return null;
    }

    pub fn JSON(T: type, allocator: Allocator, name: []const u8) ?T {
        const json_contents = json_map.get(name) orelse {
            errorPrint("JSON", name);
            return null;
        };

        return try json.parseFromSliceLeaky(
            T,
            allocator,
            json_contents,
            .{ .allocate = .alloc_always },
        );
    }

    pub fn lvldat(allocator: Allocator, name: []const u8) !?[]const u8 {
        const leveldata: []const u8 = lvldat_map.get(name) orelse return null;

        const string = try allocator.alloc(u8, leveldata.len);
        std.mem.copyForwards(u8, string, leveldata);

        return leveldata;
    }
};

pub fn deinit() void {
    var kIt = image_map.keyIterator();
    while (kIt.next()) |key| {
        if (image_map.get(key.*)) |image| {
            rl.unloadImage(image);
        }
    }
    image_map.deinit();

    var wkIt = wave_map.keyIterator();
    while (wkIt.next()) |key| {
        if (wave_map.get(key.*)) |wave| {
            rl.unloadWave(wave);
        }
    }
    wave_map.deinit();

    var fIt = font_map.keyIterator();
    while (fIt.next()) |key| {
        if (font_map.get(key.*)) |font| {
            rl.unloadFont(font);
        }
    }
    font_map.deinit();

    json_map.deinit();
    lvldat_map.deinit();
}
