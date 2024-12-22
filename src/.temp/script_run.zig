const sc = @import("../engine/scenes.m.zig");

pub fn register() !void {
	try sc.register("default", sc.Script{
		.eAwake = @import("../app/[default]/index.zig").awake,
	});	try sc.register("default", sc.Script{
	});
}