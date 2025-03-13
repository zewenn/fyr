const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const fyr = @import("../main.zig");
const SharedPtr = fyr.SharedPtr;
const sharedPtr = fyr.sharedPtr;

const Image = fyr.rl.Image;
const Texture = fyr.rl.Texture;
const Wave = fyr.rl.Wave;
const Sound = fyr.rl.Sound;
const Font = fyr.rl.Font;

pub const fs = struct {
    pub const paths = struct {
        pub var debug: []const u8 = "src" ++ std.fs.path.sep_str ++ "assets";
        pub var release: []const u8 = "assets";
    };

    pub fn getBase() ![]const u8 {
        const exepath = switch (fyr.lib_info.build_mode) {
            .Debug => try std.fs.cwd().realpathAlloc(fyr.getAllocator(.generic), "."),
            else => try std.fs.selfExeDirPathAlloc(fyr.getAllocator(.generic)),
        };
        defer fyr.getAllocator(.generic).free(exepath);

        const path = try std.fmt.allocPrint(fyr.getAllocator(.generic), "{s}{s}{s}", .{
            exepath, std.fs.path.sep_str, switch (fyr.lib_info.build_mode) {
                .Debug => paths.debug,
                else => paths.release,
            },
        });

        return path;
    }

    pub fn getFilePath(rel_path: []const u8) ![]const u8 {
        const basepath = try fs.getBase();
        defer fyr.getAllocator(.generic).free(basepath);

        return try std.fmt.allocPrint(fyr.getAllocator(.generic), "{s}{s}{s}", .{ basepath, std.fs.path.sep_str, rel_path });
    }

    pub fn getFileExt(rel_path: []const u8) ![]const u8 {
        const index = std.mem.lastIndexOf(u8, rel_path, ".") orelse 0;
        const buf = try fyr.getAllocator(.generic).alloc(u8, rel_path.len - index);
        std.mem.copyForwards(u8, buf, rel_path[index..]);

        return buf;
    }

    pub fn getData(pth: []const u8) ![]const u8 {
        const real_path = try getFilePath(pth);
        defer fyr.getAllocator(.generic).free(real_path);

        const reader = try std.fs.openFileAbsolute(real_path, .{});
        defer reader.close();

        return reader.readToEndAlloc(fyr.getAllocator(.generic), 8 * 1024 * 1024 * 512);
    }
};

fn AssetType(comptime T: type, parsefn: *const fn (data: []const u8, filetype: []const u8, mod: anytype) anyerror!T, releasefn: *const fn (data: T) void) type {
    return struct {
        const HashMapType = std.AutoHashMap(u64, *SharedPtr(T));
        var hash_map: ?HashMapType = null;

        fn hashMap() *HashMapType {
            return &(hash_map orelse Blk: {
                hash_map = HashMapType.init(fyr.getAllocator(.generic));
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
            const RANDOM_PRIME: comptime_int = 3;
            const STRING_SUM: u64 = Blk: {
                var res: u64 = 0;

                for (str) |char| {
                    res = res * RANDOM_PRIME + char;
                }

                break :Blk res;
            };

            return STRING_SUM + mod * RANDOM_PRIME;
        }

        fn parseModAndGetHash(rel_path: []const u8, modifiers: anytype) u64 {
            const mods = fyr.array(f32, modifiers);
            defer mods.deinit();

            const mod = (mods.at(0) orelse 1) * (mods.at(1) orelse 1) * 7;

            return hash(rel_path, fyr.coerceTo(u64, mod) orelse 0);
        }

        pub fn store(rel_path: []const u8, modifiers: anytype) !void {
            const hmap = hashMap();
            const HASH = parseModAndGetHash(rel_path, modifiers);
            if (hmap.contains(HASH)) return;

            const data = try fs.getData(rel_path);
            defer fyr.getAllocator(.generic).free(data);

            const filetype = try fs.getFileExt(rel_path);
            defer fyr.getAllocator(.generic).free(filetype);

            const parsed: T = try parsefn(data, filetype, modifiers);

            try hmap.put(HASH, try sharedPtr(parsed));
        }

        pub fn release(rel_path: []const u8, modifiers: anytype) void {
            const HASH = parseModAndGetHash(rel_path, modifiers);
            const hmap = hashMap();

            const sptr = hmap.get(HASH) orelse return;

            if (sptr.ref_count > 0) {
                sptr.deinit();
                return;
            }

            if (sptr.value) |v|
                releasefn(v);
            sptr.destroy();
            _ = hmap.remove(HASH);
        }

        pub fn releasePtr(ptr: *T) void {
            const hmap = hashMap();

            const entry: HashMapType.Entry = Blk: {
                var iter = hmap.iterator();
                while (iter.next()) |entry| {
                    const value_ptr = entry.value_ptr.*.valueptr();
                    defer entry.value_ptr.*.deinit();

                    if (fyr.coerceTo(usize, value_ptr) != fyr.coerceTo(usize, ptr)) continue;
                    break :Blk entry;
                }
                break :Blk null;
            } orelse return;

            const sptr = entry.value_ptr.*;
            const HASH = entry.key_ptr.*;

            if (sptr.ref_count > 0) {
                sptr.deinit();
                return;
            }

            if (sptr.value) |v|
                releasefn(v);
            sptr.destroy();
            _ = hmap.remove(HASH);
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

pub const image = AssetType(
    Image,
    struct {
        pub fn callback(data: []const u8, filetype: []const u8, modifiers: anytype) !Image {
            const mods = fyr.array(i32, modifiers);
            defer mods.deinit();

            const str: [:0]const u8 = fyr.getAllocator(.generic).dupeZ(u8, filetype) catch ".png";
            defer fyr.getAllocator(.generic).free(str);

            var img = try fyr.rl.loadImageFromMemory(str, data);
            fyr.rl.imageResizeNN(&img, mods.at(0) orelse 0, mods.at(1) orelse 0);

            return img;
        }
    }.callback,
    struct {
        pub fn callback(data: Image) void {
            fyr.rl.unloadImage(data);
        }
    }.callback,
);

pub const texture = AssetType(
    Texture,
    struct {
        pub fn callback(data: []const u8, filetype: []const u8, modifiers: anytype) !Texture {
            const mods = fyr.array(i32, modifiers);
            defer mods.deinit();

            const str: [:0]const u8 = fyr.getAllocator(.generic).dupeZ(u8, filetype) catch ".png";
            defer fyr.getAllocator(.generic).free(str);

            var img = try fyr.rl.loadImageFromMemory(str, data);
            defer fyr.rl.unloadImage(img);

            fyr.rl.imageResizeNN(&img, mods.at(0) orelse 0, mods.at(1) orelse 0);

            const txtr = try fyr.rl.loadTextureFromImage(img);
            return txtr;
        }
    }.callback,
    struct {
        pub fn callback(data: Texture) void {
            fyr.rl.unloadTexture(data);
        }
    }.callback,
);

pub const font = AssetType(
    Font,
    struct {
        pub fn callback(data: []const u8, filetype: []const u8, mod: anytype) !Font {
            const str: [:0]const u8 = fyr.getAllocator(.generic).dupeZ(u8, filetype) catch ".png";
            defer fyr.getAllocator(.generic).free(str);

            var fchars = fyr.array(i32, mod);
            defer fchars.deinit();

            var font_chars_base = [_]i32{
                48, 49, 50, 51, 52, 53, 54, 55, 56, 57, // 0-9
                65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, // A-Z
                97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, // a-z
                33, 34, 35, 36,  37,  38,  39,  40,  41,  42,  43,  44,  45,  46,  47,  58,  59,  60,  61,  62,  63,  64,  91,  92,  93,  94,
                95, 96, 123, 124, 125, 126, // !, ", #, $, %, &, ', (, ), *, +, ,, -, ., /, :, ;, <, =, >, ?, @, [, \, ], ^, _, `, {, |, }, ~
            };

            const font_chars: []i32 = if (fchars.len() == 0) &font_chars_base else fchars.items;

            const fnt = try fyr.rl.loadFontFromMemory(str, data, fyr.toi32(font_chars.len), font_chars);
            return fnt;
        }
    }.callback,
    struct {
        pub fn callback(data: Font) void {
            fyr.rl.unloadFont(data);
        }
    }.callback,
);

pub fn deinit() void {
    texture.deinit();
    image.deinit();
    font.deinit();
}
