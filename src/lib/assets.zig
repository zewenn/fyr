const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const loom = @import("./root.zig");
const SharedPtr = loom.SharedPtr;
const sharedPtr = loom.sharedPtr;

const builtin = @import("builtin");

const Image = loom.rl.Image;
const Texture = loom.rl.Texture;
const Wave = loom.rl.Wave;
const Sound = loom.rl.Sound;
const Font = loom.rl.Font;

pub const files = struct {
    pub const paths = struct {
        pub var debug: []const u8 = "src" ++ std.fs.path.sep_str ++ "assets";
        pub var release: []const u8 = "assets";

        pub fn use(comptime config: struct {
            debug: ?[]const u8 = null,
            release: ?[]const u8 = null,
        }) void {
            if (config.debug) |d|
                debug = d;

            if (config.release) |r|
                release = r;
        }
    };

    pub fn getBase() ![]const u8 {
        const exepath = switch (builtin.mode) {
            .Debug => try std.fs.cwd().realpathAlloc(loom.allocators.generic(), "."),
            else => try std.fs.selfExeDirPathAlloc(loom.allocators.generic()),
        };
        defer loom.allocators.generic().free(exepath);

        const path = try std.fmt.allocPrint(loom.allocators.generic(), "{s}{s}{s}", .{
            exepath, std.fs.path.sep_str, switch (builtin.mode) {
                .Debug => paths.debug,
                else => paths.release,
            },
        });

        return path;
    }

    pub fn getFilePath(rel_path: []const u8) ![]const u8 {
        const basepath = try files.getBase();
        defer loom.allocators.generic().free(basepath);

        return try std.fmt.allocPrint(loom.allocators.generic(), "{s}{s}{s}", .{ basepath, std.fs.path.sep_str, rel_path });
    }

    pub fn getFileExt(rel_path: []const u8) ![]const u8 {
        const index = std.mem.lastIndexOf(u8, rel_path, ".") orelse 0;
        const buf = try loom.allocators.generic().alloc(u8, rel_path.len - index);
        std.mem.copyForwards(u8, buf, rel_path[index..]);

        return buf;
    }

    pub fn getData(pth: []const u8) ![]const u8 {
        const real_path = try getFilePath(pth);
        defer loom.allocators.generic().free(real_path);

        const reader = try std.fs.openFileAbsolute(real_path, .{});
        defer reader.close();

        return reader.readToEndAlloc(loom.allocators.generic(), 8 * 1024 * 1024 * 512);
    }
};

fn AssetCache(
    comptime T: type,
    comptime parsefn: *const fn (data: []const u8, filetype: []const u8, mod: anytype) anyerror!T,
    comptime releasefn: *const fn (data: T) void,
) type {
    return struct {
        const HashMapType = std.AutoHashMap(u64, *SharedPtr(T));
        var hash_map: ?HashMapType = null;

        fn hashMap() *HashMapType {
            return &(hash_map orelse Blk: {
                hash_map = HashMapType.init(loom.allocators.generic());
                break :Blk hash_map.?;
            });
        }

        pub fn deinit() void {
            const hmap = hashMap();
            var iter = hmap.iterator();

            while (iter.next()) |entry| {
                const value = entry.value_ptr.*;
                if (value.*.value) |v|
                    releasefn(v);
                value.destroyUnsafe();
            }

            hmap.deinit();
        }

        fn hash(str: []const u8, mod: u64) u64 {
            const RANDOM_PRIME: comptime_int = 37;
            const MAX: comptime_int = std.math.maxInt(u63);
            const POWER_MAX: comptime_int = std.math.maxInt(u32);
            var power: u64 = 1;

            const STRING_SUM: u64 = Blk: {
                var hash_value: u64 = 0;

                for (str) |char| {
                    hash_value = (hash_value + (char - @min(char, '0') + 1) * power) % MAX;
                    power = (RANDOM_PRIME * power) % POWER_MAX;
                }

                break :Blk hash_value;
            };

            return STRING_SUM + mod * RANDOM_PRIME;
        }

        fn parseModAndGetHash(rel_path: []const u8, modifiers: anytype) u64 {
            const mods = loom.array(f32, modifiers);
            defer mods.deinit();

            const mod = (mods.at(0) orelse 1) * (mods.at(1) orelse 1) * 7;

            return hash(rel_path, loom.coerceTo(u64, mod) orelse 0);
        }

        pub fn store(rel_path: []const u8, modifiers: anytype) !void {
            const hmap = hashMap();
            const HASH = parseModAndGetHash(rel_path, modifiers);
            if (hmap.contains(HASH)) return;

            const data = try files.getData(rel_path);
            defer loom.allocators.generic().free(data);

            const filetype = try files.getFileExt(rel_path);
            defer loom.allocators.generic().free(filetype);

            const parsed: T = try parsefn(data, filetype, modifiers);

            try hmap.put(HASH, try sharedPtr(parsed));
        }

        pub fn release(rel_path: []const u8, modifiers: anytype) void {
            const path_hash = parseModAndGetHash(rel_path, modifiers);
            const hmap = hashMap();

            const sptr = hmap.get(path_hash) orelse return;

            if (sptr.ref_count > 0) {
                sptr.deinit();
                return;
            }

            if (sptr.value) |v|
                releasefn(v);
            sptr.destroy();
            _ = hmap.remove(path_hash);
        }

        pub fn releasePtr(ptr: *T) void {
            const hmap = hashMap();

            const entry: HashMapType.Entry = Blk: {
                var iter = hmap.iterator();
                while (iter.next()) |entry| {
                    const value_ptr = entry.value_ptr.*.valueptr();
                    defer entry.value_ptr.*.deinit();

                    if (loom.coerceTo(usize, value_ptr) != loom.coerceTo(usize, ptr)) continue;
                    break :Blk entry;
                }
                break :Blk null;
            } orelse return;

            const shared_pointer = entry.value_ptr.*;
            const entry_hash = entry.key_ptr.*;

            if (shared_pointer.ref_count > 0) {
                shared_pointer.deinit();
                return;
            }

            if (shared_pointer.value) |v|
                releasefn(v);
            shared_pointer.destroy();
            _ = hmap.remove(entry_hash);
        }

        pub fn get(rel_path: []const u8, modifiers: anytype) ?*T {
            const HASH = parseModAndGetHash(rel_path, modifiers);

            const hmap = hashMap();

            const res1 = hmap.get(HASH);
            if (res1) |r1| return r1.valueptr();

            store(rel_path, modifiers) catch return null;
            return if (hmap.get(HASH)) |r| r.valueptr() else null;
        }
    };
}

pub const image = AssetCache(
    Image,
    struct {
        pub fn callback(data: []const u8, filetype: []const u8, modifiers: anytype) !Image {
            const mods = loom.array(i32, modifiers);
            defer mods.deinit();

            const str: [:0]const u8 = loom.allocators.generic().dupeZ(u8, filetype) catch ".png";
            defer loom.allocators.generic().free(str);

            if (mods.at(0) == 0) mods.set(0, 1);
            if (mods.at(1) == 0) mods.set(1, 1);

            var img = try loom.rl.loadImageFromMemory(str, data);
            loom.rl.imageResizeNN(&img, mods.at(0) orelse 0, mods.at(1) orelse 0);

            return img;
        }
    }.callback,
    struct {
        pub fn callback(data: Image) void {
            loom.rl.unloadImage(data);
        }
    }.callback,
);

pub const texture = AssetCache(
    Texture,
    struct {
        pub fn callback(data: []const u8, filetype: []const u8, modifiers: anytype) !Texture {
            const mods = loom.array(i32, modifiers);
            defer mods.deinit();

            const str: [:0]const u8 = loom.allocators.generic().dupeZ(u8, filetype) catch ".png";
            defer loom.allocators.generic().free(str);

            var img = try loom.rl.loadImageFromMemory(str, data);
            defer loom.rl.unloadImage(img);

            if (mods.at(0) == 0) mods.set(0, 1);
            if (mods.at(1) == 0) mods.set(1, 1);

            loom.rl.imageResizeNN(&img, mods.at(0) orelse 0, mods.at(1) orelse 0);

            const txtr = try loom.rl.loadTextureFromImage(img);
            return txtr;
        }
    }.callback,
    struct {
        pub fn callback(data: Texture) void {
            loom.rl.unloadTexture(data);
        }
    }.callback,
);

pub const font = AssetCache(
    Font,
    struct {
        pub fn callback(data: []const u8, filetype: []const u8, mod: anytype) !Font {
            const str: [:0]const u8 = loom.allocators.generic().dupeZ(u8, filetype) catch ".png";
            defer loom.allocators.generic().free(str);

            var fchars = loom.array(i32, mod);
            defer fchars.deinit();

            var font_chars_base = [_]i32{
                48, 49, 50, 51, 52, 53, 54, 55, 56, 57, // 0-9
                65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, // A-Z
                97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, // a-z
                33, 34, 35, 36,  37,  38,  39,  40,  41,  42,  43,  44,  45,  46,  47,  58,  59,  60,  61,  62,  63,  64,  91,  92,  93,  94,
                95, 96, 123, 124, 125, 126, // !, ", #, $, %, &, ', (, ), *, +, ,, -, ., /, :, ;, <, =, >, ?, @, [, \, ], ^, _, `, {, |, }, ~
            };

            const font_chars: []i32 = if (fchars.len() == 0) &font_chars_base else fchars.items;

            const fnt = try loom.rl.loadFontFromMemory(str, data, loom.toi32(font_chars.len), font_chars);
            return fnt;
        }
    }.callback,
    struct {
        pub fn callback(data: Font) void {
            loom.rl.unloadFont(data);
        }
    }.callback,
);

pub fn deinit() void {
    texture.deinit();
    image.deinit();
    font.deinit();
}
