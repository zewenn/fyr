pub const eventloop = @import("../main.zig").libs.eventloop;

pub fn register() !void {
	var scene = eventloop.get("engine") orelse return;
	// display
	try scene.on(eventloop.Events.awake, .{
		.fn_ptr = @import("../modules/[display]/index.zig").awake,
		.on_fail = .panic,
	});

	try scene.on(eventloop.Events.update, .{
		.fn_ptr = @import("../modules/[display]/index.zig").update,
		.on_fail = .panic,
	});

	try scene.on(eventloop.Events.tick, .{
		.fn_ptr = @import("../modules/[display]/index.zig").tick,
		.on_fail = .panic,
	});

	// types

}