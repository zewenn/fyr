const sc = @import("../engine/scenes.m.zig");

pub fn register() !void {
	try sc.register("game", sc.Script{
		.eAwake = @import("../app/[game]/spells.zig").awake,
		.eInit = @import("../app/[game]/spells.zig").init,
		.eUpdate = @import("../app/[game]/spells.zig").update,
		.eDeinit = @import("../app/[game]/spells.zig").deinit,
	});	try sc.register("game", sc.Script{
		.eAwake = @import("../app/[game]/projectiles.zig").awake,
		.eInit = @import("../app/[game]/projectiles.zig").init,
		.eUpdate = @import("../app/[game]/projectiles.zig").update,
		.eDeinit = @import("../app/[game]/projectiles.zig").deinit,
	});	try sc.register("game", sc.Script{
		.eAwake = @import("../app/[game]/dashing.zig").awake,
		.eInit = @import("../app/[game]/dashing.zig").init,
		.eUpdate = @import("../app/[game]/dashing.zig").update,
		.eDeinit = @import("../app/[game]/dashing.zig").deinit,
	});	try sc.register("game", sc.Script{
		.eAwake = @import("../app/[game]/inventory.zig").awake,
		.eInit = @import("../app/[game]/inventory.zig").init,
		.eUpdate = @import("../app/[game]/inventory.zig").update,
		.eDeinit = @import("../app/[game]/inventory.zig").deinit,
	});	try sc.register("game", sc.Script{
		.eAwake = @import("../app/[game]/balancing.zig").awake,
		.eInit = @import("../app/[game]/balancing.zig").init,
		.eUpdate = @import("../app/[game]/balancing.zig").update,
		.eDeinit = @import("../app/[game]/balancing.zig").deinit,
	});	try sc.register("game", sc.Script{
		.eAwake = @import("../app/[game]/enemies.zig").awake,
		.eInit = @import("../app/[game]/enemies.zig").init,
		.eUpdate = @import("../app/[game]/enemies.zig").update,
		.eDeinit = @import("../app/[game]/enemies.zig").deinit,
	});	try sc.register("game", sc.Script{
		.eAwake = @import("../app/[game]/levels.zig").awake,
		.eInit = @import("../app/[game]/levels.zig").init,
		.eUpdate = @import("../app/[game]/levels.zig").update,
		.eDeinit = @import("../app/[game]/levels.zig").deinit,
	});	try sc.register("game", sc.Script{
		.eAwake = @import("../app/[game]/weapons.zig").awake,
		.eInit = @import("../app/[game]/weapons.zig").init,
		.eUpdate = @import("../app/[game]/weapons.zig").update,
		.eDeinit = @import("../app/[game]/weapons.zig").deinit,
	});	try sc.register("game", sc.Script{
		.eAwake = @import("../app/[game]/items.zig").awake,
		.eInit = @import("../app/[game]/items.zig").init,
		.eUpdate = @import("../app/[game]/items.zig").update,
		.eDeinit = @import("../app/[game]/items.zig").deinit,
	});	try sc.register("game", sc.Script{
		.eAwake = @import("../app/[game]/effect_display.zig").awake,
		.eInit = @import("../app/[game]/effect_display.zig").init,
		.eUpdate = @import("../app/[game]/effect_display.zig").update,
		.eDeinit = @import("../app/[game]/effect_display.zig").deinit,
	});	try sc.register("game", sc.Script{
		.eAwake = @import("../app/[game]/player.zig").awake,
		.eInit = @import("../app/[game]/player.zig").init,
		.eUpdate = @import("../app/[game]/player.zig").update,
		.eDeinit = @import("../app/[game]/player.zig").deinit,
	});	try sc.register("game", sc.Script{
		.eAwake = @import("../app/[game]/quickspawn.zig").awake,
		.eInit = @import("../app/[game]/quickspawn.zig").init,
		.eUpdate = @import("../app/[game]/quickspawn.zig").update,
		.eDeinit = @import("../app/[game]/quickspawn.zig").deinit,
	});	try sc.register("default", sc.Script{
		.eAwake = @import("../app/[default]/main.zig").awake,
		.eInit = @import("../app/[default]/main.zig").init,
		.eUpdate = @import("../app/[default]/main.zig").update,
		.eDeinit = @import("../app/[default]/main.zig").deinit,
	});
}