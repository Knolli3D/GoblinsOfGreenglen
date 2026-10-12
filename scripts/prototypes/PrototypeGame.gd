extends "res://scripts/Game.gd"

# Development-only harness. No campaign, quest, or highscore submissions.
@export var prototype_level: PackedScene

func _ready() -> void:
	super._ready()
	_start_new_run()

func _configure_highscore_store() -> void:
	highscore_store.configure(OS.get_temp_dir().path_join("gogg_prototype_highscore.cfg"))

func _configure_campaign() -> void:
	campaign_catalog = CampaignCatalogScript.new()
	campaign_progress.configure(campaign_catalog,
		OS.get_temp_dir().path_join("gogg_prototype_campaign_%d.cfg" % OS.get_process_id()))
	# In-memory defaults only: do not load or save campaign progress.

func _show_main_menu() -> void:
	super._show_main_menu()
	# Keep the development session away from account progression menus.
	for button: Node in menus.main_menu.find_children("*", "Button", true, false):
		if button.text in ["Map", "Quests", "Cases", "Skins", "Credits"]:
			button.hide()


func _record_quest(_stat: String) -> void:
	pass

func _start_game() -> void:
	_start_new_run()

func _start_new_run() -> void:
	if prototype_level == null:
		return
	get_tree().paused = false
	in_main_menu = false
	menus.hide_main_menu()
	menus.hide_result()
	menus.set_pause_visible(false)
	campaign_map.hide_map()
	_set_music_ducked(false)
	_begin_fresh_run()
	audio.play_gameplay_music()
	current_region_id = "region_02"
	current_level_id = "r02_level_01"
	current_level = 0
	_mount_level(prototype_level)

func reach_goal() -> void:
	if in_main_menu or transitioning or run_outcome != RunOutcome.NONE:
		return
	_finish_run(RunOutcome.COMPLETED)

func _finish_run(outcome: RunOutcome) -> void:
	if in_main_menu or outcome == RunOutcome.NONE or run_outcome != RunOutcome.NONE:
		return
	run_outcome = outcome
	run_timer_active = false
	transition_gen += 1
	transitioning = false
	audio.stop_music()
	play_sfx("win" if outcome == RunOutcome.COMPLETED else "death")
	_show_run_result(outcome)
