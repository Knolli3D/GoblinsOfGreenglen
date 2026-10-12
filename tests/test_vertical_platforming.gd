extends SceneTree

const TestEnv := preload("res://tests/test_env.gd")
var isolation: Dictionary
var checks := 0
var failures := 0
var wall_kicks := 0
var falls := 0

func _init() -> void:
	isolation = TestEnv.ensure_isolated("vertical")
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + label)
	else:
		print("OK: " + label)

func frames(count: int) -> void:
	for index in range(count):
		await physics_frame
		await process_frame

func tap_jump() -> void:
	Input.action_press("jump")
	await frames(1)
	Input.action_release("jump")
	await frames(1)

func release_inputs() -> void:
	for action: String in ["jump", "move_left", "move_right"]:
		Input.action_release(action)

func _run() -> void:
	await _bounds()
	await _walls()
	await _checkpoints()
	release_inputs()
	if failures == 0:
		print("ALLE TESTS OK (%d Checks)" % checks)
		if isolation.owned:
			TestEnv.remove_dir_recursive(isolation.dir)
	else:
		printerr("%d of %d vertical checks failed" % [failures, checks])
	quit(0 if failures == 0 else 1)

func _bounds() -> void:
	var level: Node2D = load("res://scenes/Level1.tscn").instantiate()
	root.add_child(level)
	check(level.camera_bounds() == Rect2(0,0,960,540), "legacy camera bounds unchanged")
	check(level.fall_limit() == 700.0, "legacy fall boundary unchanged")
	level.queue_free()
	await frames(2)
	level = load("res://scenes/prototypes/FoothillScramble.tscn").instantiate()
	root.add_child(level)
	check(level.camera_bounds() == Rect2(0,0,1200,1620), "authored vertical bounds")
	check(level.fall_limit() == 1780.0, "fall boundary follows authored level bottom")
	var camera := Camera2D.new()
	level.add_child(camera)
	level.configure_camera(camera)
	check(camera.position_smoothing_enabled and camera.limit_bottom == 1620, "vertical camera follows authored bounds smoothly")
	check(not camera.limit_smoothed, "camera limits stay hard")
	check(level.find_children("Goblin*", "CharacterBody2D").size() == 4, "Foothill has four authored goblins")
	check(level.find_children("Coin*", "Area2D").size() == 6, "Foothill has six authored coins")
	level.queue_free()
	await frames(2)

func _walls() -> void:
	var lab: Node2D = load("res://scenes/prototypes/WallJumpLab.tscn").instantiate()
	root.add_child(lab)
	await frames(5)
	var player: CharacterBody2D = lab.get_node("Player")
	player.wall_jumped.connect(func(): wall_kicks += 1)
	Input.action_press("move_right")
	await tap_jump()
	await frames(27)
	check(player.is_wall_sliding, "falling against tagged wall enters slide")
	check(player.velocity.y <= 120.01, "wall slide caps falling speed")
	await tap_jump()
	check(wall_kicks == 1 and player.velocity.x < 0 and player.velocity.y < 0, "jump emits one wall kick away and upward")
	check(player.jumps_remaining == 1, "kick preserves one double jump")
	check(player.wall_lock_left > 0 and player.locked_wall_id != 0, "same wall regrab lock is active")
	Input.action_release("move_right")
	Input.action_press("move_left")
	await tap_jump()
	check(player.jumps_remaining == 0 and player.velocity.y < -350, "double jump remains usable after kick")
	var found_left := false
	for index in range(70):
		await frames(1)
		if player.is_wall_sliding and player.wall_normal.x > 0:
			found_left = true
			break
	check(found_left, "other wall is climbable after kick")
	var before := wall_kicks
	await tap_jump()
	check(wall_kicks == before + 1 and player.velocity.x > 0, "opposite wall supports chained kick")
	release_inputs()
	# Real contact followed by stepping away exercises wall coyote grace.
	player.position = Vector2(524,100)
	player.reset_movement()
	player.jumps_remaining = 0
	Input.action_press("move_right")
	await frames(5)
	check(player.is_wall_sliding, "coyote fixture establishes real wall contact")
	player.locked_wall_id = player.wall_id
	player.wall_lock_left = 0.25
	await frames(2)
	check(not player.is_wall_sliding, "same wall cannot regrab during lockout")
	player.wall_lock_left = 0.0
	await frames(2)
	Input.action_release("move_right")
	Input.action_press("move_left")
	await frames(2)
	before = wall_kicks
	await tap_jump()
	check(wall_kicks == before + 1, "wall coyote permits kick just after leaving")
	release_inputs()
	# Queue a press shortly before contact, with no ordinary jumps available.
	player.position = Vector2(518,100)
	player.reset_movement()
	player.velocity.y = 50
	player.jumps_remaining = 0
	await frames(2)
	Input.action_press("move_right")
	before = wall_kicks
	await tap_jump()
	await frames(6)
	check(wall_kicks == before + 1, "buffered press fires on entering wall slide")
	release_inputs()
	player.position = Vector2(764,300)
	player.reset_movement()
	player.jumps_remaining = 0
	Input.action_press("move_right")
	await frames(6)
	before = wall_kicks
	await tap_jump()
	check(not player.is_wall_sliding and wall_kicks == before, "ordinary wall never grants wall jumps")
	release_inputs()
	player.position = Vector2(480,455)
	player.reset_movement()
	player.locked_wall_id = 123
	player.wall_lock_left = 0.25
	await frames(5)
	check(player.is_on_floor() and player.locked_wall_id == 0, "landing clears wall lock")
	player.fell_off.connect(func(): falls += 1)
	player.reset_movement()
	player.fall_limit_y = 1800
	player.position = Vector2(100,1780)
	await frames(1)
	check(falls == 0, "player can descend past old 700px limit in tall levels")
	player.position.y = 1810
	await frames(1)
	check(falls == 1, "player emits fall at authored limit")
	check(player.wall_coyote_left == 0 and player.jump_buffer_left == 0, "fall reset clears pending wall and jump state")
	lab.queue_free()
	await frames(2)

func _checkpoints() -> void:
	var scene: Node2D = load("res://scenes/prototypes/CheckpointPlaytest.tscn").instantiate()
	root.add_child(scene)
	await frames(3)
	var game: Node = scene.get_node("Game")
	game.player.set_physics_process(false)
	var checkpoint: Area2D = game.level_root.get_node("Checkpoint")
	var original_spawn: Vector2 = game.respawn_position
	check(game.active_checkpoint == null, "attempt begins without checkpoint")
	check(not game.activate_checkpoint(checkpoint, game.level_root.get_node("Enemy")), "non-player cannot activate checkpoint")
	game.transitioning = true
	check(not game.activate_checkpoint(checkpoint, game.player), "transition rejects checkpoint activation")
	game.transitioning = false
	var foreign_checkpoint: Area2D = load("res://scenes/Checkpoint.tscn").instantiate()
	root.add_child(foreign_checkpoint)
	check(not game.activate_checkpoint(foreign_checkpoint, game.player), "foreign-level checkpoint is rejected")
	foreign_checkpoint.queue_free()
	game.damage_player()
	check(game.player.global_position == original_spawn and game.health == 2, "hit before checkpoint respawns at level start")
	game.invuln_until = 0
	check(game.activate_checkpoint(checkpoint, game.player), "checkpoint activation accepted for current player")
	check(game.took_damage_this_level and game.took_damage_this_run, "checkpoint does not erase previous damage")
	check(not game.activate_checkpoint(checkpoint, game.player), "checkpoint activation is idempotent")
	var respawn: Vector2 = game.respawn_position
	game.player.global_position += Vector2(150,-100)
	game.player.wall_lock_left = 1
	game.damage_player()
	check(game.health == 1 and game.score == -2, "checkpoint hit preserves damage and score policy")
	check(game.player.global_position == respawn and game.player.velocity == Vector2.ZERO, "hit respawns at checkpoint with zero velocity")
	check(game.player.wall_lock_left == 0, "respawn clears wall movement state")
	var health_before: int = game.health
	game.damage_player()
	check(game.health == health_before, "invulnerability prevents duplicate enemy damage")
	game.fell_off_world()
	check(game.run_outcome == 1, "fatal fall finishes attempt")
	check(not game.activate_checkpoint(checkpoint, game.player), "finished attempt rejects checkpoint signals")
	game._start_new_run()
	check(not game.activate_checkpoint(checkpoint, game.player), "old queued checkpoint cannot affect new attempt")
	await frames(3)
	game.player.set_physics_process(false)
	check(game.active_checkpoint == null and not game.took_damage_this_level, "retry resets checkpoint and damage state")
	check(game.respawn_position == original_spawn, "retry restores initial spawn")
	checkpoint = game.level_root.get_node("Checkpoint")
	game.activate_checkpoint(checkpoint, game.player)
	game.fell_off_world()
	check(game.health == 2 and game.player.global_position == respawn, "nonfatal fall uses checkpoint")
	check(game.took_damage_this_level, "fall prevents no-damage trial")
	game._show_main_menu()
	check(game.active_checkpoint == null, "menu clears active checkpoint")
	check(not game.activate_checkpoint(checkpoint, game.player), "menu rejects late checkpoint callbacks")
	check(game.campaign_progress.completed_level_ids.is_empty(), "prototype does not submit campaign progress")
	check(not game.highscore_store.has_highscore, "prototype does not submit highscore")
	scene.queue_free()
	await frames(3)
