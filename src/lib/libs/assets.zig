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
    pub var debug: []const u8 = "src/assets";
    pub var release: []const u8 = "assets";

    pub fn getBase() ![]const u8 {
        const exepath = switch (fyr.lib_info.build_mode) {
            .Debug => try std.fs.cwd().realpathAlloc(fyr.getAllocator(.gpa), "."),
            else => try std.fs.selfExeDirPathAlloc(fyr.getAllocator(.gpa)),
        };
        defer fyr.getAllocator(.gpa).free(exepath);

        return try std.fs.path.join(fyr.getAllocator(.gpa), switch (fyr.lib_info.build_mode) {
            .Debug => @constCast(&[_][]const u8{ exepath, debug }),
            else => @constCast(&[_][]const u8{ exepath, release }),
        });
    }

    pub fn getFilePath(rel_path: []const u8) ![]const u8 {
        const basepath = try fs.getBase();
        defer fyr.getAllocator(.gpa).free(basepath);

        return try std.fs.path.join(
            fyr.getAllocator(.gpa),
            @constCast(&[_][]const u8{ basepath, rel_path }),
        );
    }

    pub fn getFileExt(rel_path: []const u8) []const u8 {
        const index = std.mem.lastIndexOf(u8, rel_path, ".") orelse 0;
        return rel_path[index..];
    }

    pub fn getData(pth: []const u8) ![]const u8 {
        const real_path = try getFilePath(pth);
        defer fyr.getAllocator(.gpa).free(real_path);

        const reader = try std.fs.openFileAbsolute(real_path, .{});
        defer reader.close();

        return reader.readToEndAlloc(fyr.getAllocator(.gpa), 8 * 1024 * 1024 * 512);
    }
};

fn AssetType(comptime T: type, parsefn: fn (data: []const u8, filetype: []const u8, mod: anytype) T, releasefn: fn (data: T) void) type {
    return struct {
        const HashMapType = std.AutoHashMap(u64, *SharedPtr(T));
        var hash_map: ?HashMapType = null;

        fn hashMap() *HashMapType {
            return &(hash_map orelse Blk: {
                hash_map = HashMapType.init(fyr.getAllocator(.gpa));
                break :Blk hash_map.?;
            });
        }

        pub fn deinit() void {
            const hmap = hashMap();
            var iter = hmap.iterator();

            while (iter.next()) |entry| {
                const value = entry.value_ptr.*;
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

            return STRING_SUM * mod * RANDOM_PRIME;
        }

        fn parseModAndGetHash(rel_path: []const u8, modifiers: anytype) u64 {
            const mods = fyr.array(f32, modifiers);
            defer mods.deinit();

            const mod = (mods.at(0) orelse 1) * (mods.at(1) orelse 1) * 7;

            return hash(rel_path, fyr.changeNumberType(u64, mod) orelse 0);
        }

        pub fn store(rel_path: []const u8, modifiers: anytype) !void {
            const hmap = hashMap();
            const HASH = parseModAndGetHash(rel_path, modifiers);
            if (hmap.contains(HASH)) return;

            const data = try fs.getData(rel_path);
            defer fyr.getAllocator(.gpa).free(data);

            const filetype = fs.getFileExt(rel_path);

            const parsed: T = parsefn(data, filetype, modifiers);

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
        pub fn callback(data: []const u8, filetype: []const u8, modifiers: anytype) Image {
            const mods = fyr.array(i32, modifiers);
            defer mods.deinit();

            const str: [*:0]const u8 = fyr.getAllocator(.gpa).dupeZ(u8, filetype) catch ".png";
            defer fyr.getAllocator(.gpa).free(std.mem.span(str));

            var img = fyr.rl.loadImageFromMemory(str, data);
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
        pub fn callback(data: []const u8, filetype: []const u8, modifiers: anytype) Texture {
            const mods = fyr.array(i32, modifiers);
            defer mods.deinit();

            const str: [*:0]const u8 = fyr.getAllocator(.gpa).dupeZ(u8, filetype) catch ".png";
            defer fyr.getAllocator(.gpa).free(std.mem.span(str));

            var img = fyr.rl.loadImageFromMemory(str, data);
            defer fyr.rl.unloadImage(img);

            fyr.rl.imageResizeNN(&img, mods.at(0) orelse 0, mods.at(1) orelse 0);

            const txtr = fyr.rl.loadTextureFromImage(img);
            return txtr;
        }
    }.callback,
    struct {
        pub fn callback(data: Texture) void {
            fyr.rl.unloadTexture(data);
        }
    }.callback,
);

pub fn deinit() void {
    texture.deinit();
    image.deinit();
}
