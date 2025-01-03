const zap = @import(".zap");
const el = zap.libs.eventloop;

pub fn register() !void {

	// ----- [default] -----

	const default_instance = try el.new("default");
	{
		try default_instance.on(
			el.Events.awake,
			.{ .fn_ptr = @import("../app/[default]/index.zig").awake, .on_fail = .remove },
		);
	}
}