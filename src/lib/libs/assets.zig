const std = @import("std");
const Allocator = @import("std").mem.Allocator;
const fs = std.fs;

const zap = @import("../main.zig");
const rl = @import("raylib");

/// 512 MB
const MAX_FILE_SIZE: comptime_int = 1024 * 1024 * 512;
var ASSETS_PATH_DEBUG: []const u8 = "./src/assets/";

// ------------------------------------- Caches -------------------------------------

const ImageCache = std.AutoHashMap(usize, *zap.SharedPointer(rl.Image));
pub var image_cache: ?ImageCache = null;

const TextureCache = std.AutoHashMap(usize, *zap.SharedPointer(rl.Texture));
pub var texture_cache: ?TextureCache = null;

const AudioCache = std.AutoHashMap(usize, *zap.SharedPointer(rl.Sound));
pub var audio_cache: ?AudioCache = null;

// ------------------------------------- Funcs --------------------------------------

pub fn deinit() void {
    Img: {
        const ic = &(image_cache orelse break :Img);
        defer ic.deinit();

        var it = ic.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.deinit();
            zap.getAllocator(.gpa).destroy(entry.value_ptr.*);
        }
    }
    Texture: {
        const tc = &(texture_cache orelse break :Texture);
        defer tc.deinit();

        var it = tc.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.deinit();
            zap.getAllocator(.gpa).destroy(entry.value_ptr.*);
        }
    }
    Audio: {
        const ac = &(audio_cache orelse break :Audio);
        defer ac.deinit();

        var it = ac.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.deinit();
            zap.getAllocator(.gpa).destroy(entry.value_ptr.*);
        }
    }
}

inline fn calculateHash(rel_path: []const u8, size: zap.Vector2, rotation: f32) usize {
    var res: usize = 0;
    for (rel_path, 0..) |char, index| {
        res += char * index;
    }

    res += zap.changeType(usize, size.x).? * 128;
    res += (zap.changeType(usize, size.y).? * 2 + 1) * 3;
    res += zap.changeType(usize, rotation).? * 700;
    return res;
}

fn loadFromFile(rel_path: []const u8) ![]const u8 {
    const full_path = try getAssetFullPath(rel_path);
    defer zap.getAllocator(.gpa).free(full_path);

    const file = fs.openFileAbsolute(full_path, .{}) catch zap.panic("Asset {s} couldn't be found!", .{rel_path});
    defer file.close();

    return try file.readToEndAlloc(zap.getAllocator(.gpa), MAX_FILE_SIZE);
}

pub fn getAssetFullPath(rel_path: []const u8) ![]const u8 {
    const path = switch (zap.BUILD_MODE) {
        .Debug => try fs.path.join(zap.getAllocator(.gpa), &[_][]const u8{
            ASSETS_PATH_DEBUG,
            rel_path,
        }),
        else => Blk: {
            const base_path = try fs.selfExeDirPathAlloc(zap.getAllocator(.gpa));
            defer zap.getAllocator(.gpa).free(base_path);

            break :Blk try fs.path.join(zap.getAllocator(.gpa), &[_][]const u8{
                base_path,
                "assets/",
                rel_path,
            });
        },
    };
    defer zap.getAllocator(.gpa).free(path);

    return try fs.realpathAlloc(zap.getAllocator(.gpa), path);
}

pub inline fn overrideDevPath(comptime path: []const u8) void {
    ASSETS_PATH_DEBUG = path;
}

pub const get = struct {
    fn storeImage(
        ic: *std.AutoHashMap(usize, *zap.SharedPointer(rl.Image)),
        hash: usize,
        rel_path: []const u8,
        size: zap.Vector2,
        rotation: f32,
    ) !*zap.SharedPointer(rl.Image) {
        const data = try loadFromFile(rel_path);
        defer zap.getAllocator(.gpa).free(data);

        var img = rl.loadImageFromMemory(".png", data);
        rl.imageResizeNN(
            &img,
            zap.toi32(size.x),
            zap.toi32(size.y),
        );
        rl.imageRotate(
            &img,
            zap.toi32(rotation),
        );

        try ic.put(hash, try zap.SharetPtr(img));
        return ic.get(hash).?;
    }

    pub fn image(rel_path: []const u8, size: zap.Vector2, rotation: f32) !?*rl.Image {
        const ic = &(image_cache orelse Blk: {
            image_cache = std.AutoHashMap(usize, *zap.SharedPointer(rl.Image)).init(zap.getAllocator(.gpa));
            break :Blk image_cache.?;
        });
        const hash = calculateHash(rel_path, size, rotation);

        var stored = ic.get(hash) orelse try storeImage(ic, hash, rel_path, size, rotation);
        if (!stored.isAlive()) {
            zap.getAllocator(.gpa).destroy(stored);
            stored = try storeImage(ic, hash, rel_path, size, rotation);
        }

        return stored.ptr() orelse error.AlreadyFreed;
    }

    fn storeTexture(
        tc: *std.AutoHashMap(usize, *zap.SharedPointer(rl.Texture)),
        hash: usize,
        img: rl.Image,
    ) !*zap.SharedPointer(rl.Texture) {
        const t = rl.loadTextureFromImage(img);

        try tc.put(hash, try zap.SharetPtr(t));
        return tc.get(hash).?;
    }

    pub fn texture(rel_path: []const u8, img: rl.Image, rotation: f32) !*rl.Texture {
        const tc = &(texture_cache orelse Blk: {
            texture_cache = std.AutoHashMap(usize, *zap.SharedPointer(rl.Texture)).init(zap.getAllocator(.gpa));
            break :Blk texture_cache.?;
        });
        const hash = calculateHash(rel_path, zap.Vec2(img.width, img.height), rotation);

        var stored = tc.get(hash) orelse try storeTexture(tc, hash, img);
        if (!stored.isAlive()) {
            zap.getAllocator(.gpa).destroy(stored);
            stored = try storeTexture(tc, hash, img);
        }

        return stored.ptr() orelse error.AlreadyFreed;
    }

    pub fn audio(rel_path: []const u8) !*rl.Sound {
        const ac = &(audio_cache orelse Blk: {
            audio_cache = AudioCache.init(zap.getAllocator(.gpa));
            break :Blk audio_cache.?;
        });
        const hash = calculateHash(rel_path, zap.Vec2(1, 1), 0);

        var stored = ac.get(hash) orelse Blk: {
            const data = try loadFromFile(rel_path);
            defer zap.getAllocator(.gpa).free(data);

            const wave = rl.loadWaveFromMemory(".mp3", data);
            defer rl.unloadWave(wave);

            const sound = rl.loadSoundFromWave(wave);

            try ac.put(hash, try zap.SharetPtr(sound));
            break :Blk ac.get(hash).?;
        };

        return stored.ptr() orelse error.AlreadyFreed;
    }
};

pub const rmref = struct {
    pub fn image(rel_path: []const u8, size: zap.Vector2, rotation: f32) void {
        const ic = &(image_cache orelse return);
        const hash = calculateHash(rel_path, size, rotation);
        const sptr = ic.get(hash) orelse return;

        if (!sptr.isAlive()) return;

        if (sptr.ref_count == 1) {
            const img = sptr.ptr().?;

            rl.unloadImage(img.*);

            sptr.deinit();
            zap.getAllocator(.gpa).destroy(sptr);
            _ = ic.remove(hash);
            return;
        }
        sptr.rmref();
    }

    pub fn texture(rel_path: []const u8, img: rl.Image, rotation: f32) void {
        const tc = &(texture_cache orelse return);
        const hash = calculateHash(rel_path, zap.Vec2(img.width, img.height), rotation);
        const sptr = tc.get(hash) orelse return;

        if (!sptr.isAlive()) return;

        if (sptr.ref_count == 1) {
            const txtr = sptr.ptr().?;

            rl.unloadTexture(txtr.*);

            sptr.deinit();
            zap.getAllocator(.gpa).destroy(sptr);
            _ = tc.remove(hash);
            return;
        }
        sptr.rmref();
    }
};
