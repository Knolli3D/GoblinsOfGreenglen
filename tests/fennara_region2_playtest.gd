extends RefCounted
# Run with Fennara runtime_script against Region2Playtest.tscn.
# Uses actual InputMap controls; no teleporting or forced completion.
var kick_count := 0

func game(ctx: Variant) -> Node:
	return ctx.get_scene_root().get_node("Game")

func verify(ctx: Variant, condition: bool, label: String) -> bool:
	ctx.log(label, {"passed": condition})
	if not condition:
		ctx.release_all_inputs()
		ctx.error(label)
	return condition

func walk_to(ctx: Variant, target_x: float, seconds: float = 2.0) -> void:
	for step in range(int(seconds / 0.025)):
		var player: CharacterBody2D = game(ctx).player
		var distance: float = target_x - player.position.x
		ctx.release_all_actions()
		if absf(distance) < 5.0 or game(ctx).run_outcome != 0:
			break
		ctx.press_action("move_right" if distance > 0 else "move_left")
		await ctx.wait(0.025)
	ctx.release_all_actions()

# Jump-only zig-zag: hold right only until the first crag catches, then just tap jump
# whenever attached. Each kick carries the player to the opposite crag; the last one
# exits the shaft top onto solid ground.
func climb(ctx: Variant, exit_y: float) -> void:
	ctx.press_action("move_right")
	await ctx.tap_action("jump", 0.03)
	for step in range(40):
		if game(ctx).player.is_wall_sliding:
			break
		await ctx.wait(0.02)
	ctx.release_all_actions()
	var kicks_here := 0
	for step in range(210):
		var player: CharacterBody2D = game(ctx).player
		if player.position.y < exit_y or game(ctx).run_outcome != 0:
			break
		if kicks_here > 0 and player.is_on_floor():
			break
		if player.is_wall_sliding:
			await ctx.tap_action("jump", 0.025)
			if game(ctx).player.velocity.y < -400:
				kick_count += 1
				kicks_here += 1
		await ctx.wait(0.04)
	ctx.release_all_actions()


func run(ctx: Variant) -> void:
	await ctx.restart_scene()
	kick_count = 0
	ctx.press_action("move_right")
	await ctx.wait(0.54)
	await ctx.tap_action("jump",0.03)
	await ctx.wait(0.45)
	await ctx.tap_action("jump",0.03)
	await ctx.wait(0.79)
	ctx.release_all_actions()
	await ctx.wait(0.25)
	if not verify(ctx, game(ctx).player.position.x > 480 and game(ctx).health == 3, "Double-jump gap cleared"):
		return
	await walk_to(ctx, 635)
	await climb(ctx, 880)
	await walk_to(ctx, 770)
	await ctx.wait(0.6)
	if not verify(ctx, is_instance_valid(game(ctx).active_checkpoint), "Midway checkpoint reached"):
		return
	await ctx.capture("foothill-midway")
	await walk_to(ctx, 805)
	ctx.press_action("move_right")
	await ctx.tap_action("jump",0.03)
	await walk_to(ctx, 1000, 2.5)
	await ctx.wait(0.2)
	await climb(ctx, 300)
	await walk_to(ctx, 1160)
	await ctx.wait(0.7)
	if not verify(ctx, game(ctx).run_outcome == 2, "Foothill completed by gameplay"):
		return
	ctx.log("Route summary", {"wall_kicks":kick_count, "health":game(ctx).health, "coins":game(ctx).coin_count, "damage":game(ctx).took_damage_this_level})
	verify(ctx, game(ctx).campaign_progress.completed_level_ids.is_empty() and not game(ctx).highscore_store.has_highscore, "Prototype awards no campaign progress or records")
	await ctx.capture("foothill-complete")
	# InputMap uses logical keycodes; physical-only events do not match it.
	ctx.press_key(82, {"physical":false})
	await ctx.wait(0.06)
	ctx.release_key(82, {"physical":false})
	await ctx.wait(0.15)
	verify(ctx, game(ctx).run_outcome == 0 and game(ctx).health == 3 and not is_instance_valid(game(ctx).active_checkpoint) and not game(ctx).took_damage_this_level, "R restarts a fresh prototype attempt")
	ctx.release_all_inputs()
