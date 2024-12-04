const zap = @import(".zap");

pub fn main() !void {
    zap.libs.raylib.initWindow(1280, 710, "Test");

    while (true) {
        if (!zap.libs.raylib.windowShouldClose()) continue;
        break;
    }
}
