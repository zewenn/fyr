const std = @import("std");
const Allocator = @import("std").mem.Allocator;
const fs = std.fs;

const zap = @import("../../main.zig");

/// 512 MB
const MAX_FILE_SIZE: comptime_int = std.math.pow(usize, 1024, 2) * 512;

// ------------------------------------- Caches -------------------------------------

const ImageCache = std.AutoHashMap(usize, *zap.SharedPointer(zap.rl.Image));
pub var image_cache: ?ImageCache = null;

const TextureCache = std.StringHashMap(zap.SharedPointer(zap.rl.Texture));
pub var texture_cache: ?TextureCache = null;

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
}

inline fn calculateHash(comptime rel_path: []const u8, size: zap.Vector2) usize {
    var res: usize = 0;
    inline for (rel_path, 0..) |char, index| {
        res += char * index;
    }

    res += zap.changeType(usize, size.x).? * 128;
    res += (zap.changeType(usize, size.y).? * 2 + 1) * 3;
    return res;
}

fn loadFromFile(comptime rel_path: []const u8) ![]const u8 {
    const file = switch (zap.BUILD_MODE) {
        .Debug => try fs.cwd().openFile(rel_path, .{}),
        else => Blk: {
            const base_path = try fs.selfExeDirPathAlloc(zap.getAllocator(.gpa));
            defer zap.getAllocator(.gpa).free(base_path);

            const full_path = try fs.path.join(zap.getAllocator(.gpa), [_][]const u8{
                base_path,
                rel_path,
            });
            defer zap.getAllocator(.gpa).free(full_path);

            break :Blk try fs.openFileAbsolute(full_path, .{});
        },
    };
    defer file.close();

    return try file.readToEndAlloc(zap.getAllocator(.gpa), MAX_FILE_SIZE);
}

pub const get = struct {
    pub fn image(comptime rel_path: []const u8, size: zap.Vector2) !*zap.SharedPointer(zap.rl.Image) {
        const ic = &(image_cache orelse Blk: {
            image_cache = std.AutoHashMap(usize, *zap.SharedPointer(zap.rl.Image)).init(zap.getAllocator(.gpa));
            break :Blk image_cache.?;
        });
        const hash = calculateHash(rel_path, size);

        var stored = ic.get(hash) orelse Blk: {
            const data = try loadFromFile(rel_path);
            defer zap.getAllocator(.gpa).free(data);

            const img = zap.rl.loadImageFromMemory(".png", data);

            try ic.put(hash, try zap.SharetPtr(img));
            break :Blk ic.get(hash).?;
        };

        stored.incr();
        return stored;
    }
};
