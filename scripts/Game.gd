extends Node2D

const SaveData := preload("res://scripts/SaveData.gd")
const GreenglenUI := preload("res://scripts/GreenglenUI.gd")
const AudioControllerScript := preload("res://scripts/AudioController.gd")
const HighscoreStoreScript := preload("res://scripts/HighscoreStore.gd")
const CampaignCatalogScript := preload("res://scripts/CampaignCatalog.gd")
const CampaignProgressStoreScript := preload("res://scripts/CampaignProgressStore.gd")

const MAX_HEALTH := 3

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


func _configure_highscore_store() -> void:
	var save_path: String = HighscoreStoreScript.SAVE_PATH
	var test_dir := SaveData.test_save_dir()
	if test_dir != "":
		save_path = test_dir.path_join("highscore.cfg")
	highscore_store.configure(save_path)
	highscore_store.load_data()


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
func _submit_run(run_score: int, run_coins: int) -> bool:
	return highscore_store.submit(run_score, run_coins)


func _show_main_menu() -> void:
	transition_gen += 1
	transitioning = false
	invuln_until = 0.0
	run_outcome = RunOutcome.NONE
	in_main_menu = true
	get_tree().paused = false
	menus.set_pause_visible(false)
	menus.hide_result()
	campaign_map.hide_map()
	hud.hide_gameplay()
	hud.hide_message()
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
	score = 0
	coin_count = 0
	took_damage_this_run = false
	_set_music_ducked(false)
	audio.start_music()
	_load_level(0)


func show_campaign_map_preview(region_id := CampaignCatalogScript.REGION_1_ID) -> void:
	transition_gen += 1
	transitioning = false
	invuln_until = 0.0
	run_outcome = RunOutcome.NONE
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
	score = 0
	coin_count = 0
	took_damage_this_run = false
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
	menus.set_pause_visible(paused)
	_set_music_ducked(paused)


func _restart_level_from_menu() -> void:
	play_sfx("click")
	_start_new_run()


func _start_new_run() -> void:
	get_tree().paused = false
	menus.set_pause_visible(false)
	_set_music_ducked(false)
	score = 0
	coin_count = 0
	took_damage_this_run = false
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
	invuln_until = now + 1.0
	health -= 1
	score -= 1
	took_damage_this_level = true
	took_damage_this_run = true
	_update_hud()
	if health <= 0:
		_finish_run(RunOutcome.FAILED)
	else:
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
			invuln_until = Time.get_ticks_msec() / 1000.0 + 1.0


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


func _finish_run(outcome: RunOutcome) -> void:
	if in_main_menu or outcome == RunOutcome.NONE or run_outcome != RunOutcome.NONE:
		return
	run_outcome = outcome
	transition_gen += 1
	transitioning = false
	audio.stop_music()
	var is_new_highscore := false
	if outcome == RunOutcome.COMPLETED:
		Progression.add_quest_progress("finish_run")
		if not took_damage_this_run:
			Progression.add_quest_progress("no_damage_run")
		play_sfx("win")
		is_new_highscore = _submit_run(score, coin_count)
	else:
		play_sfx("death")
	_show_run_result(outcome, is_new_highscore)


func _show_run_result(outcome: RunOutcome, is_new_highscore := false) -> void:
	hud.hide_message()
	hud.hide_gameplay()
	menus.show_result(
		outcome == RunOutcome.COMPLETED,
		score,
		coin_count,
		highscore_store.result_text(),
		is_new_highscore,
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
