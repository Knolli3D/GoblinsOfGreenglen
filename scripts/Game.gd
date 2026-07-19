extends Node2D

const SaveData := preload("res://scripts/SaveData.gd")
const GreenglenUI := preload("res://scripts/GreenglenUI.gd")
const AudioControllerScript := preload("res://scripts/AudioController.gd")
const HighscoreStoreScript := preload("res://scripts/HighscoreStore.gd")
const CampaignCatalogScript := preload("res://scripts/CampaignCatalog.gd")
const CampaignProgressStoreScript := preload("res://scripts/CampaignProgressStore.gd")

const MAX_HEALTH := 3
const COIN_FINAL_SCORE_VALUE := 10
const INVULNERABILITY_DURATION := 1.0

# Compatibility view for resource checks. CampaignCatalog is the source of truth.
const LEVELS := CampaignCatalogScript.REGION_1_SCENE_PATHS

# Compatibility aliases for resource validation and the future leaderboard hook.
const SFX_FILES := AudioControllerScript.SFX_FILES
const MUSIC_FILE := AudioControllerScript.MUSIC_FILE
const SAVE_PATH := HighscoreStoreScript.SAVE_PATH
const HIGHSCORE_SAVE_VERSION := HighscoreStoreScript.SAVE_VERSION

enum RunOutcome { NONE, FAILED, COMPLETED }

var current_level := 0
var current_region_id := CampaignCatalogScript.REGION_1_ID
var current_level_id := "r01_level_01"
var health := MAX_HEALTH
var score := 0
var coin_count := 0
var run_time_ms := 0
var run_time_remainder_usec := 0
var run_timer_active := false
var transitioning := false
var transition_gen := 0
var invuln_until := 0.0
var run_outcome := RunOutcome.NONE
var level_root: Node2D
var player: CharacterBody2D
var in_main_menu := true
var took_damage_this_level := false
var took_damage_this_run := false
var level_score_start := 0
var level_coins_start := 0
var campaign_catalog: RefCounted

var ui_theme: Theme
var ui_heading_font: Font
var ui_body_font: Font

@onready var audio: Node = $AudioController
@onready var highscore_store: Node = $HighscoreStore
@onready var hud: Node = $HUDController
@onready var menus: Node = $GameMenuController
@onready var quest_menu: Node = $QuestMenuController
@onready var case_menu: Node = $CaseMenuController
@onready var skin_menu: Node = $SkinMenuController
@onready var campaign_progress: Node = $CampaignProgressStore
@onready var campaign_map: Node = $CampaignMapController


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("game")
	_configure_highscore_store()
	_configure_campaign()
	var theme_bundle := GreenglenUI.build_theme_bundle()
	ui_theme = theme_bundle.theme
	ui_heading_font = theme_bundle.heading_font
	ui_body_font = theme_bundle.body_font
	hud.initialize()
	menus.initialize(ui_theme, ui_heading_font, ui_body_font)
	quest_menu.initialize(ui_theme, ui_heading_font, audio)
	case_menu.initialize(ui_theme, ui_heading_font, audio)
	skin_menu.initialize(ui_theme, ui_heading_font, audio)
	campaign_map.initialize(
		ui_theme, ui_heading_font, ui_body_font, campaign_catalog, campaign_progress, audio)
	_connect_components()
	_show_main_menu()


func _process(delta: float) -> void:
	if not _is_run_timer_counting():
		return
	_accumulate_run_time(delta)


func _configure_highscore_store() -> void:
	var save_path: String = HighscoreStoreScript.SAVE_PATH
	var test_dir := SaveData.test_save_dir()
	if test_dir != "":
		save_path = test_dir.path_join("highscore.cfg")
	highscore_store.configure(save_path)
	highscore_store.load_data(COIN_FINAL_SCORE_VALUE)


func _configure_campaign() -> void:
	campaign_catalog = CampaignCatalogScript.new()
	var errors: PackedStringArray = campaign_catalog.call("validate")
	for error: String in errors:
		push_error("Campaign catalog: %s" % error)
	var campaign_path: String = CampaignProgressStoreScript.SAVE_PATH
	var test_dir := SaveData.test_save_dir()
	if test_dir != "":
		campaign_path = test_dir.path_join("campaign.cfg")
	campaign_progress.configure(campaign_catalog, campaign_path)
	campaign_progress.load_data()


func _connect_components() -> void:
	menus.start_requested.connect(_start_game)
	menus.resume_requested.connect(_toggle_pause)
	menus.restart_requested.connect(_restart_level_from_menu)
	menus.main_menu_requested.connect(_exit_to_main_menu)
	menus.map_requested.connect(_show_campaign_map_menu)
	menus.quests_requested.connect(_show_quests_menu)
	menus.cases_requested.connect(_show_cases_menu)
	menus.skins_requested.connect(_show_skins_menu)
	menus.quit_requested.connect(_quit_game)
	quest_menu.back_requested.connect(_hide_submenus)
	quest_menu.keys_changed.connect(_update_hud)
	case_menu.back_requested.connect(_hide_submenus)
	skin_menu.back_requested.connect(_hide_submenus)
	campaign_map.level_requested.connect(_start_campaign_level)
	campaign_map.back_requested.connect(_show_main_menu)


func play_sfx(sfx_name: String, pitch_jitter := 0.0) -> void:
	audio.play_sfx(sfx_name, pitch_jitter)


func _set_music_ducked(ducked: bool) -> void:
	audio.set_music_ducked(ducked)


# Kept as the single future online-leaderboard hook. Persistence lives in HighscoreStore.
func _submit_run(final_score: int, elapsed_time_ms: int) -> Dictionary:
	return highscore_store.submit(final_score, elapsed_time_ms)


func calculate_final_score(combat_score: int, coins: int) -> int:
	return maxi(0, combat_score) + coins * COIN_FINAL_SCORE_VALUE


func format_run_time(time_ms: int) -> String:
	var total_seconds := int(maxi(0, time_ms) / 1000)
	return "%d:%02d" % [int(total_seconds / 60), total_seconds % 60]


func _begin_fresh_run() -> void:
	score = 0
	coin_count = 0
	took_damage_this_run = false
	run_time_ms = 0
	run_time_remainder_usec = 0
	run_timer_active = true


func _is_run_timer_counting() -> bool:
	return run_timer_active \
		and not in_main_menu \
		and run_outcome == RunOutcome.NONE \
		and not transitioning \
		and not get_tree().paused \
		and level_root != null \
		and level_root.process_mode != Node.PROCESS_MODE_DISABLED


func _accumulate_run_time(delta: float) -> void:
	var delta_usec := maxi(0, roundi(delta * 1000000.0))
	var accumulated_usec := run_time_remainder_usec + delta_usec
	var previous_seconds := int(run_time_ms / 1000)
	run_time_ms += int(accumulated_usec / 1000)
	run_time_remainder_usec = accumulated_usec % 1000
	if int(run_time_ms / 1000) != previous_seconds:
		hud.update_run_time(format_run_time(run_time_ms))


func _show_main_menu() -> void:
	transition_gen += 1
	transitioning = false
	invuln_until = 0.0
	run_outcome = RunOutcome.NONE
	run_timer_active = false
	in_main_menu = true
	get_tree().paused = false
	menus.set_pause_visible(false)
	menus.hide_result()
	campaign_map.hide_map()
	hud.hide_gameplay()
	hud.hide_message()
	_stop_player_damage_blink()
	if level_root:
		level_root.queue_free()
		level_root = null
	menus.show_main_menu(highscore_store.main_menu_text())
	quest_menu.hide_menu()
	case_menu.hide_menu()
	skin_menu.hide_menu()
	audio.stop_music()
	_set_music_ducked(false)


func _start_game() -> void:
	play_sfx("click")
	in_main_menu = false
	menus.hide_main_menu()
	hud.show_gameplay()
	_begin_fresh_run()
	_set_music_ducked(false)
	audio.start_music()
	_load_level(0)


func _show_campaign_map_menu() -> void:
	play_sfx("click")
	show_campaign_map()


# Production entry point: opens the map on the last valid selection, else Region 1.
func show_campaign_map() -> void:
	_open_campaign_map(_resolve_map_region_id())


# Compatibility wrapper for development/tests that open a specific region directly.
func show_campaign_map_preview(region_id := CampaignCatalogScript.REGION_1_ID) -> void:
	_open_campaign_map(region_id)


func _resolve_map_region_id() -> String:
	var last_region := String(campaign_progress.last_selected_region_id)
	if last_region != "" \
			and not (campaign_catalog.call("get_region", last_region) as Dictionary).is_empty():
		return last_region
	return CampaignCatalogScript.REGION_1_ID


func _open_campaign_map(region_id: String) -> void:
	transition_gen += 1
	transitioning = false
	invuln_until = 0.0
	run_outcome = RunOutcome.NONE
	run_timer_active = false
	in_main_menu = true
	get_tree().paused = false
	menus.hide_main_menu()
	menus.set_pause_visible(false)
	menus.hide_result()
	hud.hide_gameplay()
	hud.hide_message()
	quest_menu.hide_menu()
	case_menu.hide_menu()
	skin_menu.hide_menu()
	_stop_player_damage_blink()
	if level_root:
		level_root.queue_free()
		level_root = null
	audio.stop_music()
	_set_music_ducked(false)
	campaign_map.show_region(region_id)


func _start_campaign_level(level_id: String) -> void:
	if not campaign_progress.can_play_level(level_id):
		return
	in_main_menu = false
	campaign_map.hide_map()
	menus.hide_main_menu()
	hud.show_gameplay()
	_begin_fresh_run()
	_set_music_ducked(false)
	audio.start_music()
	_load_level_by_id(level_id)


func _quit_game() -> void:
	get_tree().quit()


func _exit_to_main_menu() -> void:
	play_sfx("click")
	_show_main_menu()


func _toggle_pause() -> void:
	play_sfx("click")
	var paused := not get_tree().paused
	get_tree().paused = paused
	if paused:
		_stop_player_damage_blink()
	menus.set_pause_visible(paused)
	_set_music_ducked(paused)


func _restart_level_from_menu() -> void:
	play_sfx("click")
	_start_new_run()


func _start_new_run() -> void:
	get_tree().paused = false
	menus.set_pause_visible(false)
	_set_music_ducked(false)
	_begin_fresh_run()
	if not audio.is_music_playing():
		audio.start_music()
	_load_level(0)


func _show_quests_menu() -> void:
	play_sfx("click")
	menus.hide_main_menu()
	quest_menu.show_menu()


func _show_cases_menu() -> void:
	play_sfx("click")
	menus.hide_main_menu()
	case_menu.show_menu()


func _show_skins_menu() -> void:
	play_sfx("click")
	menus.hide_main_menu()
	skin_menu.show_menu()


func _hide_submenus() -> void:
	play_sfx("click")
	quest_menu.hide_menu()
	case_menu.hide_menu()
	skin_menu.hide_menu()
	menus.show_main_menu(highscore_store.main_menu_text())


func _update_hud() -> void:
	hud.update_status(
		current_level + 1,
		health,
		MAX_HEALTH,
		score,
		coin_count,
		Progression.get_keys(),
		format_run_time(run_time_ms),
	)


func coin_collected() -> void:
	coin_count += 1
	play_sfx("coin", 0.06)
	Progression.add_quest_progress("coin")
	_update_hud()


func _load_level(index: int) -> void:
	var main_level_ids := campaign_catalog.call(
		"get_main_level_ids", CampaignCatalogScript.REGION_1_ID) as Array
	if index < 0 or index >= main_level_ids.size():
		push_warning("Campaign: invalid Region 1 level index %d" % index)
		return
	_load_level_by_id(String(main_level_ids[index]))


func _load_level_by_id(level_id: String) -> void:
	var level_definition := campaign_catalog.call("get_level", level_id) as Dictionary
	if level_definition.is_empty() or not campaign_progress.can_play_level(level_id):
		push_warning("Campaign: level '%s' is unknown, locked, or unavailable" % level_id)
		return
	var scene_path := String(level_definition.get("scene_path", ""))
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_warning("Campaign: level '%s' has no loadable scene" % level_id)
		return
	transition_gen += 1
	_stop_player_damage_blink()
	if level_root:
		level_root.queue_free()
	current_region_id = String(level_definition.get("region_id", ""))
	current_level_id = level_id
	current_level = int(campaign_catalog.call("get_main_level_index", level_id))
	health = MAX_HEALTH
	transitioning = false
	took_damage_this_level = false
	invuln_until = 0.0
	run_outcome = RunOutcome.NONE
	hud.hide_message()
	menus.hide_result()
	hud.show_gameplay()

	level_root = packed.instantiate() as Node2D
	level_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(level_root)
	level_root.call("randomize_level_spawns")

	var spawn_marker := level_root.find_child("PlayerSpawn", true, false) as Marker2D
	var spawn_position := Vector2(60, 460)
	if spawn_marker:
		spawn_position = spawn_marker.position

	player = preload("res://scenes/Player.tscn").instantiate() as CharacterBody2D
	player.position = spawn_position
	level_root.add_child(player)
	player.stomped_enemy.connect(_on_player_stomped_enemy)
	player.hit_enemy.connect(damage_player)
	player.fell_off.connect(fell_off_world)
	player.reached_goal.connect(reach_goal)
	player.jumped.connect(play_sfx.bind("jump", 0.04))
	player.double_jumped.connect(play_sfx.bind("double_jump", 0.04))
	player.double_jumped.connect(Progression.add_quest_progress.bind("double_jump"))
	player.call("apply_skin", Progression.get_equipped_skin())

	var camera := Camera2D.new()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = level_root.level_width
	camera.limit_bottom = 540
	player.add_child(camera)
	level_score_start = score
	level_coins_start = coin_count
	_update_hud()


func _on_player_stomped_enemy(enemy: CharacterBody2D) -> void:
	if enemy == null or not enemy.has_method("is_enemy") or not enemy.is_enemy():
		return
	var position := enemy.position
	enemy.call("kill")
	enemy_killed()
	play_sfx("stomp", 0.08)
	Progression.add_quest_progress("stomp")
	hud.spawn_pow(position)


func enemy_killed() -> void:
	score += 1
	_update_hud()


func damage_player() -> void:
	if in_main_menu or run_outcome != RunOutcome.NONE or transitioning:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now < invuln_until:
		return
	invuln_until = now + INVULNERABILITY_DURATION
	health -= 1
	score -= 1
	took_damage_this_level = true
	took_damage_this_run = true
	_update_hud()
	if health <= 0:
		_finish_run(RunOutcome.FAILED)
	else:
		_start_player_damage_blink()
		play_sfx("hit")
		player.velocity.y = 0


func fell_off_world() -> void:
	if in_main_menu or run_outcome != RunOutcome.NONE or transitioning:
		return
	health -= 1
	score -= 1
	took_damage_this_level = true
	took_damage_this_run = true
	_update_hud()
	if health <= 0:
		_finish_run(RunOutcome.FAILED)
	else:
		play_sfx("hit")
		var spawn_marker := level_root.find_child("PlayerSpawn", true, false) as Marker2D
		if spawn_marker:
			player.position = spawn_marker.position
			player.velocity = Vector2.ZERO
			invuln_until = Time.get_ticks_msec() / 1000.0 + INVULNERABILITY_DURATION
			_start_player_damage_blink()


func _start_player_damage_blink() -> void:
	if is_instance_valid(player) and player.has_method("start_damage_blink"):
		player.call("start_damage_blink", INVULNERABILITY_DURATION)


func _stop_player_damage_blink() -> void:
	if is_instance_valid(player) and player.has_method("stop_damage_blink"):
		player.call("stop_damage_blink")


func reach_goal() -> void:
	if in_main_menu or transitioning or run_outcome != RunOutcome.NONE:
		return
	transitioning = true
	campaign_progress.record_level_completion(
		current_level_id,
		score - level_score_start,
		coin_count - level_coins_start,
	)
	if not took_damage_this_level:
		_award_no_damage_level_trials(current_level_id)
		Progression.add_quest_progress("no_damage_goal")
	Progression.add_quest_progress("level_clear")
	var next_level_id := String(campaign_catalog.call("get_next_main_level_id", current_level_id))
	if next_level_id != "":
		play_sfx("level_clear")
		_show_message("Level Cleared!")
		var generation := transition_gen
		await get_tree().create_timer(1.0, false).timeout
		if generation != transition_gen or in_main_menu:
			return
		_load_level_by_id(next_level_id)
	else:
		_finish_run(RunOutcome.COMPLETED)


# Katalog-getriebene Trials: "no_damage_level"-Trials zählen genau dann, wenn ihr
# referenziertes Level ohne Schaden abgeschlossen wurde. Idempotent — der Store klemmt
# den Fortschritt auf das Trial-Target und emittiert nur echte Zustandsübergänge.
func _award_no_damage_level_trials(level_id: String) -> void:
	var region := campaign_catalog.call("get_region", current_region_id) as Dictionary
	for trial: Dictionary in region.get("trials", []):
		if String(trial.get("kind", "")) == "no_damage_level" \
				and String(trial.get("level_id", "")) == level_id:
			campaign_progress.add_region_trial_progress(String(trial.get("id", "")))


func _finish_run(outcome: RunOutcome) -> void:
	if in_main_menu or outcome == RunOutcome.NONE or run_outcome != RunOutcome.NONE:
		return
	run_outcome = outcome
	run_timer_active = false
	transition_gen += 1
	transitioning = false
	audio.stop_music()
	var record_result := {
		"new_highscore": false,
		"new_best_time": false,
	}
	if outcome == RunOutcome.COMPLETED:
		Progression.add_quest_progress("finish_run")
		if not took_damage_this_run:
			Progression.add_quest_progress("no_damage_run")
		play_sfx("win")
		record_result = _submit_run(calculate_final_score(score, coin_count), run_time_ms)
	else:
		play_sfx("death")
	_show_run_result(outcome, record_result)


func _show_run_result(outcome: RunOutcome, record_result := {}) -> void:
	_stop_player_damage_blink()
	hud.hide_message()
	hud.hide_gameplay()
	menus.show_result(
		outcome == RunOutcome.COMPLETED,
		calculate_final_score(score, coin_count),
		format_run_time(run_time_ms),
		highscore_store.result_text(),
		bool(record_result.get("new_highscore", false)),
		bool(record_result.get("new_best_time", false)),
	)
	if level_root:
		level_root.process_mode = Node.PROCESS_MODE_DISABLED


func _show_message(text: String) -> void:
	if run_outcome != RunOutcome.NONE:
		return
	hud.show_message(text)
	if level_root:
		level_root.process_mode = Node.PROCESS_MODE_DISABLED


func _unhandled_input(event: InputEvent) -> void:
	if in_main_menu:
		return
	if event.is_action_pressed("pause"):
		if run_outcome == RunOutcome.NONE:
			_toggle_pause()
		return
	if event.is_action_pressed("restart"):
		_start_new_run()
