const std = @import("std");
const Allocator = @import("std").mem.Allocator;
const fs = std.fs;

const fyr = @import("../main.zig");
const rl = @import("raylib");

/// 512 MB
const MAX_FILE_SIZE: comptime_int = 1024 * 1024 * 512;
pub var ASSETS_PATH_DEBUG: []const u8 = "./src/assets/";

// ------------------------------------- Caches -------------------------------------

const ImageCache = std.AutoHashMap(usize, *fyr.SharedPointer(rl.Image));
pub var image_cache: ?ImageCache = null;

const TextureCache = std.AutoHashMap(usize, *fyr.SharedPointer(rl.Texture));
pub var texture_cache: ?TextureCache = null;

const AudioCache = std.AutoHashMap(usize, *fyr.SharedPointer(rl.Sound));
pub var audio_cache: ?AudioCache = null;

const FontCache = std.AutoHashMap(usize, *fyr.SharedPointer(rl.Font));
pub var font_cache: ?FontCache = null;

// ------------------------------------- Funcs --------------------------------------

pub fn deinit() void {
    Img: {
        const ic = &(image_cache orelse break :Img);
        defer ic.deinit();

        var it = ic.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.deinit();
            fyr.getAllocator(.gpa).destroy(entry.value_ptr.*);
        }
    }
    Texture: {
        const tc = &(texture_cache orelse break :Texture);
        defer tc.deinit();

        var it = tc.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.deinit();
            fyr.getAllocator(.gpa).destroy(entry.value_ptr.*);
        }
    }
    Audio: {
        const ac = &(audio_cache orelse break :Audio);
        defer ac.deinit();

        var it = ac.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.deinit();
            fyr.getAllocator(.gpa).destroy(entry.value_ptr.*);
        }
    }
    Font: {
        const fc = &(font_cache orelse break :Font);
        defer fc.deinit();

        var it = fc.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.deinit();
            fyr.getAllocator(.gpa).destroy(entry.value_ptr.*);
        }
    }
}

inline fn calculateHash(rel_path: []const u8, size: fyr.Vector2, rotation: f32) usize {
    var res: usize = 0;
    for (rel_path, 0..) |char, index| {
        res += char * index;
    }

    res += fyr.changeNumberType(usize, size.x).? * 128;
    res += (fyr.changeNumberType(usize, size.y).? * 2 + 1) * 3;
    res += fyr.changeNumberType(usize, rotation).? * 700;
    return res;
}

fn loadFromFile(rel_path: []const u8) ![]const u8 {
    const full_path = try getAssetFullPath(rel_path);
    defer fyr.getAllocator(.gpa).free(full_path);

    const file = fs.openFileAbsolute(full_path, .{}) catch fyr.panic("Asset {s} couldn't be found!", .{rel_path});
    defer file.close();

    return try file.readToEndAlloc(fyr.getAllocator(.gpa), MAX_FILE_SIZE);
}

pub fn getAssetFullPath(rel_path: []const u8) ![]const u8 {
    const path = switch (fyr.lib_info.build_mode) {
        .Debug => try fs.path.join(fyr.getAllocator(.gpa), &[_][]const u8{
            ASSETS_PATH_DEBUG,
            rel_path,
        }),
        else => Blk: {
            const base_path = try fs.selfExeDirPathAlloc(fyr.getAllocator(.gpa));
            defer fyr.getAllocator(.gpa).free(base_path);

            break :Blk try fs.path.join(fyr.getAllocator(.gpa), &[_][]const u8{
                base_path,
                "assets/",
                rel_path,
            });
        },
    };
    defer fyr.getAllocator(.gpa).free(path);

    return try fs.realpathAlloc(fyr.getAllocator(.gpa), path);
}

pub inline fn overrideDevPath(comptime path: []const u8) void {
    ASSETS_PATH_DEBUG = path;
}

pub const get = struct {
    fn EntityImage(
        ic: *std.AutoHashMap(usize, *fyr.SharedPointer(rl.Image)),
        hash: usize,
        rel_path: []const u8,
        size: fyr.Vector2,
        rotation: f32,
    ) !*fyr.SharedPointer(rl.Image) {
        const data = try loadFromFile(rel_path);
        defer fyr.getAllocator(.gpa).free(data);

        var img = rl.loadImageFromMemory(".png", data);
        rl.imageResizeNN(
            &img,
            fyr.toi32(size.x),
            fyr.toi32(size.y),
        );
        rl.imageRotate(
            &img,
            fyr.toi32(rotation),
        );

        try ic.put(hash, try fyr.SharetPtr(img));
        return ic.get(hash).?;
    }

    pub fn image(rel_path: []const u8, size: fyr.Vector2, rotation: f32) !?*rl.Image {
        const ic = &(image_cache orelse Blk: {
            image_cache = std.AutoHashMap(usize, *fyr.SharedPointer(rl.Image)).init(fyr.getAllocator(.gpa));
            break :Blk image_cache.?;
        });
        const hash = calculateHash(rel_path, size, rotation);

        var Entityd = ic.get(hash) orelse try EntityImage(ic, hash, rel_path, size, rotation);
        if (!Entityd.isAlive()) {
            fyr.getAllocator(.gpa).destroy(Entityd);
            Entityd = try EntityImage(ic, hash, rel_path, size, rotation);
        }

        return Entityd.ptr() orelse error.AlreadyFreed;
    }

    fn EntityTexture(
        tc: *std.AutoHashMap(usize, *fyr.SharedPointer(rl.Texture)),
        hash: usize,
        img: rl.Image,
    ) !*fyr.SharedPointer(rl.Texture) {
        const t = rl.loadTextureFromImage(img);

        try tc.put(hash, try fyr.SharetPtr(t));
        return tc.get(hash).?;
    }

    pub fn texture(rel_path: []const u8, img: rl.Image, rotation: f32) !*rl.Texture {
        const tc = &(texture_cache orelse Blk: {
            texture_cache = std.AutoHashMap(usize, *fyr.SharedPointer(rl.Texture)).init(fyr.getAllocator(.gpa));
            break :Blk texture_cache.?;
        });
        const hash = calculateHash(rel_path, fyr.Vec2(img.width, img.height), rotation);

        var Entityd = tc.get(hash) orelse try EntityTexture(tc, hash, img);
        if (!Entityd.isAlive()) {
            fyr.getAllocator(.gpa).destroy(Entityd);
            Entityd = try EntityTexture(tc, hash, img);
        }

        return Entityd.ptr() orelse error.AlreadyFreed;
    }

    pub fn audio(rel_path: []const u8) !*rl.Sound {
        const ac = &(audio_cache orelse Blk: {
            audio_cache = AudioCache.init(fyr.getAllocator(.gpa));
            break :Blk audio_cache.?;
        });
        const hash = calculateHash(rel_path, fyr.Vec2(1, 1), 0);

        var Entityd = ac.get(hash) orelse Blk: {
            const data = try loadFromFile(rel_path);
            defer fyr.getAllocator(.gpa).free(data);

            const wave = rl.loadWaveFromMemory(".mp3", data);
            defer rl.unloadWave(wave);

            const sound = rl.loadSoundFromWave(wave);

            try ac.put(hash, try fyr.SharetPtr(sound));
            break :Blk ac.get(hash).?;
        };

        return Entityd.ptr() orelse error.AlreadyFreed;
    }

    pub fn font(rel_path: []const u8) !*rl.Font {
        const fc = &(font_cache orelse Blk: {
            audio_cache = AudioCache.init(fyr.getAllocator(.gpa));
            break :Blk audio_cache.?;
        });
        const hash = calculateHash(rel_path, fyr.Vec2(1, 1), 0);

        var Entityd = fc.get(hash) orelse Blk: {
            const data = try loadFromFile(rel_path);
            defer fyr.getAllocator(.gpa).free(data);

            const f = rl.loadFontFromMemory(".ttf", data);

            try fc.put(hash, try fyr.SharetPtr(f));
            break :Blk fc.get(hash).?;
        };

        return Entityd.ptr() orelse error.AlreadyFreed;
    }
};

pub const rmref = struct {
    pub fn image(rel_path: []const u8, size: fyr.Vector2, rotation: f32) void {
        const ic = &(image_cache orelse return);
        const hash = calculateHash(rel_path, size, rotation);
        const sptr = ic.get(hash) orelse return;

        if (!sptr.isAlive()) return;

        if (sptr.ref_count == 1) {
            const img = sptr.ptr().?;

            rl.unloadImage(img.*);

            sptr.deinit();
            fyr.getAllocator(.gpa).destroy(sptr);
            _ = ic.remove(hash);
            return;
        }
        sptr.rmref();
    }

    pub fn texture(rel_path: []const u8, img: rl.Image, rotation: f32) void {
        const tc = &(texture_cache orelse return);
        const hash = calculateHash(rel_path, fyr.Vec2(img.width, img.height), rotation);
        const sptr = tc.get(hash) orelse return;

        if (!sptr.isAlive()) return;

        if (sptr.ref_count == 1) {
            const txtr = sptr.ptr().?;

            rl.unloadTexture(txtr.*);

            sptr.deinit();
            fyr.getAllocator(.gpa).destroy(sptr);
            _ = tc.remove(hash);
            return;
        }
        sptr.rmref();
    }
};
