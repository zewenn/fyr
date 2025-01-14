const std = @import("std");
const Allocator = @import("std").mem.Allocator;
const fs = std.fs;

const zap = @import("../../main.zig");

/// 512 MB
const MAX_FILE_SIZE: comptime_int = 1024 * 1024 * 512;

// ------------------------------------- Caches -------------------------------------

const ImageCache = std.AutoHashMap(usize, *zap.SharedPointer(zap.rl.Image));
pub var image_cache: ?ImageCache = null;

const TextureCache = std.AutoHashMap(usize, *zap.SharedPointer(zap.rl.Texture));
pub var texture_cache: ?TextureCache = null;

const AudioCache = std.AutoHashMap(usize, *zap.SharedPointer(zap.rl.Sound));
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
    res += zap.changeType(usize, rotation).? * 7;
    return res;
}

fn loadFromFile(rel_path: []const u8) ![]const u8 {
    const file = switch (zap.BUILD_MODE) {
        .Debug => Blk: {
            const full_path = try fs.path.join(zap.getAllocator(.gpa), &[_][]const u8{
                "./src/assets/",
                rel_path,
            });
            defer zap.getAllocator(.gpa).free(full_path);

            break :Blk fs.cwd().openFile(full_path, .{}) catch zap.panic("Asset {s} couldn't be found!", .{rel_path});
        },
        else => Blk: {
            const base_path = try fs.selfExeDirPathAlloc(zap.getAllocator(.gpa));
            defer zap.getAllocator(.gpa).free(base_path);

            const full_path = try fs.path.join(zap.getAllocator(.gpa), &[_][]const u8{
                base_path,
                "assets/",
                rel_path,
            });
            defer zap.getAllocator(.gpa).free(full_path);

            break :Blk fs.openFileAbsolute(full_path, .{}) catch zap.panic("Asset {s} couldn't be found!", .{rel_path});
        },
    };
    defer file.close();

    return try file.readToEndAlloc(zap.getAllocator(.gpa), MAX_FILE_SIZE);
}

pub const get = struct {
    pub fn image(rel_path: []const u8, size: zap.Vector2, rotation: f32) !?*zap.rl.Image {
        const ic = &(image_cache orelse Blk: {
            image_cache = std.AutoHashMap(usize, *zap.SharedPointer(zap.rl.Image)).init(zap.getAllocator(.gpa));
            break :Blk image_cache.?;
        });
        const hash = calculateHash(rel_path, size, rotation);

        var stored = ic.get(hash) orelse Blk: {
            const data = try loadFromFile(rel_path);
            defer zap.getAllocator(.gpa).free(data);

            var img = zap.rl.loadImageFromMemory(".png", data);
            zap.rl.imageResizeNN(
                &img,
                zap.toi32(size.x),
                zap.toi32(size.y),
            );
            zap.rl.imageRotate(
                &img,
                zap.toi32(rotation),
            );

            try ic.put(hash, try zap.SharetPtr(img));
            break :Blk ic.get(hash).?;
        };

        return stored.ptr() orelse error.AlreadyFreed;
    }

    pub fn texture(rel_path: []const u8, img: zap.rl.Image, rotation: f32) !*zap.rl.Texture {
        const tc = &(texture_cache orelse Blk: {
            texture_cache = std.AutoHashMap(usize, *zap.SharedPointer(zap.rl.Texture)).init(zap.getAllocator(.gpa));
            break :Blk texture_cache.?;
        });
        const hash = calculateHash(rel_path, zap.Vec2(img.width, img.height), rotation);

        var stored = tc.get(hash) orelse Blk: {
            const t = zap.rl.loadTextureFromImage(img);

            try tc.put(hash, try zap.SharetPtr(t));
            break :Blk tc.get(hash).?;
        };

        return stored.ptr() orelse error.AlreadyFreed;
    }

    pub fn audio(rel_path: []const u8) !*zap.rl.Sound {
        const ac = &(audio_cache orelse Blk: {
            audio_cache = AudioCache.init(zap.getAllocator(.gpa));
            break :Blk audio_cache.?;
        });
        const hash = calculateHash(rel_path, zap.Vec2(1, 1), 0);

        var stored = ac.get(hash) orelse Blk: {
            const data = try loadFromFile(rel_path);
            defer zap.getAllocator(.gpa).free(data);

            const wave = zap.rl.loadWaveFromMemory(".mp3", data);
            defer zap.rl.unloadWave(wave);

            const sound = zap.rl.loadSoundFromWave(wave);

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
            defer sptr.rmref();

            zap.rl.unloadImage(img.*);
        }
        sptr.rmref();
    }

    pub fn texture(rel_path: []const u8, img: zap.rl.Image, rotation: f32) void {
        const tc = &(texture_cache orelse return);
        const hash = calculateHash(rel_path, zap.Vec2(img.width, img.height), rotation);
        const sptr = tc.get(hash) orelse return;

        if (!sptr.isAlive()) return;

        if (sptr.ref_count == 1) {
            const txtr = sptr.ptr().?;
            defer sptr.rmref();

            zap.rl.unloadTexture(txtr.*);
        }
        sptr.rmref();
    }
};
