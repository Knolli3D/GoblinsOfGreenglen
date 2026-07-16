extends SceneTree

# Smoke- und Verhaltens-Suite: Szenen-/Ressourcen-Invarianten (Main + alle Level,
# Player-Signale, Input-Actions, Audio, Skin-Texturen, Case-Gewichte, Quest-/Skin-IDs),
# Level-6-Zufalls-Spawns (mit festem Seed), Run-Result-Lifecycle (FAILED/COMPLETED,
# Genau-einmal-Garantie, Highscore-Policy) und Transition-Cancellation.
# Ausführen (einzeln, oder komplett über res://tests/run_all.gd):
#
#   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s res://tests/test_smoke.gd
#
# Isolation wie test_save_system.gd: _init() sorgt VOR dem Autoload-Start dafür, dass
# GOGG_TEST_SAVE_DIR gesetzt ist — echte Saves werden nie gelesen oder geschrieben.
# Zufall ist geseedet; Zeit-Waits nutzen großzügige Margen statt Frame-Zählungen.

const TestEnv := preload("res://tests/test_env.gd")
const ProgressionScript := preload("res://scripts/Progression.gd")
const AudioControllerScript := preload("res://scripts/AudioController.gd")

const PLAYER_SIGNALS := ["stomped_enemy", "hit_enemy", "fell_off", "reached_goal", "jumped", "double_jumped"]
const INPUT_ACTIONS := ["move_left", "move_right", "jump", "restart", "pause"]
# Die 1s-reach_goal()-Verzögerung plus großzügige Marge (nicht frame-sensitiv).
const TRANSITION_WAIT := 1.6

var checks := 0
var failures := 0
var save_dir := ""
var owns_save_dir := false
var game: Node2D  # Main.tscn-Instanz (Game.gd)

func _init() -> void:
	var iso: Dictionary = TestEnv.ensure_isolated("smoke")
	save_dir = iso.dir
	owns_save_dir = iso.owned
	seed(20260716)
	process_frame.connect(_run_all, CONNECT_ONE_SHOT)

func _run_all() -> void:
	var main_scene: PackedScene = load("res://scenes/Main.tscn")
	print("Main-Szene:")
	check(main_scene != null and main_scene.can_instantiate(), "Main.tscn lädt und ist instanziierbar")
	game = main_scene.instantiate() as Node2D
	check(game != null and game.get_script() != null, "Main-Root trägt Game.gd")
	_test_component_scene()

	_test_player_scene()
	_test_input_actions()
	_test_audio_resources()
	_test_skin_definitions()
	_test_quest_definitions()
	_test_levels()
	await _test_run_results()
	await _test_transition_cancellation()

	root.remove_child(game)
	game.free()
	await process_frame
	await process_frame
	await create_timer(0.1).timeout  # letzten 50ms-Click im AudioServer vollständig auslaufen lassen
	print("")
	if failures == 0:
		print("ALLE TESTS OK (%d Checks)" % checks)
		if owns_save_dir:
			TestEnv.remove_dir_recursive(save_dir)
	else:
		printerr("FEHLGESCHLAGEN: %d von %d Checks" % [failures, checks])
	quit(0 if failures == 0 else 1)

func check(cond: bool, name: String) -> void:
	checks += 1
	if cond:
		print("  ok   %s" % name)
	else:
		failures += 1
		printerr("  FAIL %s" % name)

# --- Szenen & Ressourcen -------------------------------------------------------

func _test_player_scene() -> void:
	print("Player-Szene:")
	var p: Node = (load("res://scenes/Player.tscn") as PackedScene).instantiate()
	check(p is CharacterBody2D, "Player ist CharacterBody2D")
	for sig: String in PLAYER_SIGNALS:
		check(p.has_signal(sig), "Signal '%s' vorhanden" % sig)
	p.free()

func _test_input_actions() -> void:
	print("Input-Actions:")
	for action: String in INPUT_ACTIONS:
		check(InputMap.has_action(action), "Action '%s' registriert" % action)

func _test_audio_resources() -> void:
	print("Audio-Ressourcen:")
	var sfx: Dictionary = AudioControllerScript.SFX_FILES
	for key: String in sfx:
		check(ResourceLoader.exists(sfx[key]), "SFX '%s' existiert (%s)" % [key, sfx[key]])
	check(ResourceLoader.exists(AudioControllerScript.MUSIC_FILE),
		"Musik existiert (%s)" % AudioControllerScript.MUSIC_FILE)

func _test_component_scene() -> void:
	print("Main-Komponenten:")
	var expected := [
		"AudioController",
		"HighscoreStore",
		"HUDController",
		"GameMenuController",
		"QuestMenuController",
		"CaseMenuController",
		"SkinMenuController",
		"CampaignProgressStore",
		"CampaignMapController",
	]
	for component_name: String in expected:
		check(game.has_node(component_name), "%s ist in Main.tscn deklariert" % component_name)
	check(game.get_node("AudioController").has_method("play_sfx"), "AudioController hat explizite SFX-API")
	check(game.get_node("HighscoreStore").has_method("submit"), "HighscoreStore hat Submit-API")
	check(game.get_node("HUDController").has_method("update_status"), "HUDController hat Snapshot-API")
	check(game.get_node("CampaignProgressStore").has_method("record_level_completion"),
		"CampaignProgressStore hat Completion-API")
	check(game.get_node("CampaignMapController").has_method("show_region"),
		"CampaignMapController hat Präsentations-API")

func _test_skin_definitions() -> void:
	print("Skin-Definitionen:")
	var ids: Array = []
	var textures_ok := true
	var ids_unique := true
	var regular_total := 0
	for tier: String in ProgressionScript.SKIN_TIERS:
		var tier_def: Dictionary = ProgressionScript.SKIN_TIERS[tier]
		regular_total += int(tier_def.weight)
		for skin: Dictionary in tier_def.skins:
			if skin.id in ids:
				ids_unique = false
			ids.append(skin.id)
			var tex: String = skin.get("texture", "")
			if tex != "" and not ResourceLoader.exists(tex):
				textures_ok = false
				printerr("       fehlende Textur: %s (%s)" % [tex, skin.id])
	check(ids_unique, "alle Skin-IDs eindeutig (%d Skins)" % ids.size())
	check(textures_ok, "alle Skin-Texturen existieren")
	check(not ProgressionScript.SKIN_TIERS.has("common"), "Common-Tier ist entfernt")
	check("bronze_knight" not in ids and "silver_knight" not in ids,
		"Bronze/Silver sind nicht mehr im Skin-Katalog")
	check(regular_total == 100, "reguläre Case-Gewichte summieren auf 100 (ist %d)" % regular_total)
	var premium_total := 0
	for tier: String in ProgressionScript.PREMIUM_WEIGHTS:
		premium_total += int(ProgressionScript.PREMIUM_WEIGHTS[tier])
		check(ProgressionScript.SKIN_TIERS.has(tier), "Premium-Tier '%s' existiert in SKIN_TIERS" % tier)
	check(premium_total == 100, "Premium-Case-Gewichte summieren auf 100 (ist %d)" % premium_total)
	for id: String in ProgressionScript.STARTER_SKINS:
		check(id in ids, "Starter-Skin '%s' ist in SKIN_TIERS definiert" % id)

func _test_quest_definitions() -> void:
	print("Quest-Definitionen:")
	for pool_info: Array in [["QUEST_POOL", ProgressionScript.QUEST_POOL], ["WEEKLY_POOL", ProgressionScript.WEEKLY_POOL]]:
		var pool_name: String = pool_info[0]
		var pool: Array = pool_info[1]
		var ids: Array = []
		var valid := true
		for q: Dictionary in pool:
			if not (q.get("id", "") is String) or q.get("id", "") == "" \
				or not (q.get("stat", "") is String) or q.get("stat", "") == "" \
				or int(q.get("target", 0)) <= 0 or q.get("desc", "") == "":
				valid = false
			ids.append(q.id)
		var unique_ids := ids.duplicate()
		check(valid, "%s: alle Definitionen vollständig (id/desc/stat/target)" % pool_name)
		var deduped: Array = []
		for id: Variant in unique_ids:
			if id not in deduped:
				deduped.append(id)
		check(deduped.size() == ids.size(), "%s: alle Quest-IDs eindeutig (%d)" % [pool_name, ids.size()])

# --- Level-Invarianten ----------------------------------------------------------

func _test_levels() -> void:
	for i: int in range(game.LEVELS.size()):
		var path: String = game.LEVELS[i]
		print("Level %d (%s):" % [i + 1, path.get_file()])
		var packed: PackedScene = load(path)
		check(packed != null and packed.can_instantiate(), "Szene lädt")
		var level := packed.instantiate() as Node2D
		root.add_child(level)
		check(level.find_child("PlayerSpawn", true, false) is Marker2D, "PlayerSpawn vorhanden")
		var has_platforms: bool = level.has_node("Platforms") and level.get_node("Platforms").get_child_count() > 0
		check(has_platforms, "Platforms-Container mit Plattformen vorhanden")
		check(int(level.level_width) > 0, "level_width positiv (%d)" % int(level.level_width))
		var goals := get_nodes_in_group("goals")
		check(goals.size() >= 1, "gültiges Goal nach Szenen-Eintritt (%d)" % goals.size())
		if i == game.LEVELS.size() - 1:
			_test_level6_randomization(level)
		level.free()

func _test_level6_randomization(level: Node2D) -> void:
	check(bool(level.randomize_spawns), "randomize_spawns aktiviert")
	var eligible: Array = []
	for p: Node in level.get_node("Platforms").get_children():
		if p.is_in_group("spawn_platforms"):
			eligible.append(p)
	check(not eligible.is_empty(), "spawn_platforms markiert (%d)" % eligible.size())

	seed(424242)  # deterministische Platzierung für diesen Testlauf
	level.randomize_level_spawns()
	var enemies := get_nodes_in_group("enemies")
	check(enemies.size() == int(level.goblin_count), "Gegneranzahl == goblin_count (%d/%d)" % [enemies.size(), int(level.goblin_count)])
	var coins := _count_script_instances(level, "Coin.gd")
	check(coins == int(level.coin_count), "Coin-Anzahl == coin_count (%d/%d)" % [coins, int(level.coin_count)])

	# Jeder Gegner muss auf einer MARKIERTEN Plattform stehen (Spannweite + Y-Offset) —
	# damit steht keiner auf der unmarkierten Start-/Ziel-Plattform.
	var y_offset: float = level.ENEMY_Y_OFFSET
	var misplaced := 0
	for e: Node2D in enemies:
		if not _on_any_platform(e.position, eligible, y_offset):
			misplaced += 1
	check(misplaced == 0, "alle Gegner stehen auf spawn_platforms (%d daneben)" % misplaced)

	var spawn := level.find_child("PlayerSpawn", true, false) as Marker2D
	var start_platform := _platform_below(level, spawn.position)
	check(start_platform != null and not start_platform.is_in_group("spawn_platforms"),
		"Start-Plattform ist nicht als spawn_platform markiert")
	var goal := get_first_node_in_group("goals") as Node2D
	var goal_platform := _platform_below(level, goal.position)
	check(goal_platform != null and not goal_platform.is_in_group("spawn_platforms"),
		"Ziel-Plattform ist nicht als spawn_platform markiert")

func _count_script_instances(parent: Node, script_suffix: String) -> int:
	var n := 0
	for c: Node in parent.get_children():
		var s: Script = c.get_script()
		if s != null and s.resource_path.ends_with(script_suffix):
			n += 1
	return n

func _on_any_platform(pos: Vector2, platforms: Array, y_offset: float) -> bool:
	for p: StaticBody2D in platforms:
		var shape: RectangleShape2D = p.get_node("CollisionShape2D").shape
		var half_width := shape.size.x / 2.0
		var top := p.position.y - shape.size.y / 2.0
		if absf(pos.x - p.position.x) <= half_width + 0.01 and absf(pos.y - (top + y_offset)) <= 0.5:
			return true
	return false

# Nächste Plattform, deren X-Spanne pos enthält und deren Oberkante auf/unter pos liegt.
func _platform_below(level: Node2D, pos: Vector2) -> StaticBody2D:
	var best: StaticBody2D = null
	var best_dy := INF
	for p: Node in level.get_node("Platforms").get_children():
		var body := p as StaticBody2D
		if body == null:
			continue
		var shape: RectangleShape2D = body.get_node("CollisionShape2D").shape
		if absf(pos.x - body.position.x) > shape.size.x / 2.0:
			continue
		var dy := (body.position.y - shape.size.y / 2.0) - pos.y
		if dy >= -1.0 and dy < best_dy:
			best_dy = dy
			best = body
	return best

# --- Run-Result-Lifecycle -------------------------------------------------------

func _test_run_results() -> void:
	print("Run-Results (FAILED/COMPLETED):")
	root.add_child(game)  # _ready: Menüs, Audio, isolierter Highscore
	var RO: Dictionary = game.RunOutcome
	var prog: Node = root.get_node("/root/Progression")
	check(game.menus.main_menu.theme == game.ui_theme, "Main-Menü nutzt das gemeinsame Theme")
	check(game.quest_menu.menu.theme == game.ui_theme and game.case_menu.menu.theme == game.ui_theme \
		and game.skin_menu.menu.theme == game.ui_theme, "Submenüs teilen dieselbe Theme-Instanz")
	check(game.menus.start_requested.get_connections().size() == 1,
		"Start-Signal ist genau einmal mit dem Coordinator verbunden")
	check(game.quest_menu.keys_changed.get_connections().size() == 1,
		"Quest-Key-Signal ist genau einmal verbunden")
	check(game.campaign_map.level_requested.get_connections().size() == 1 \
		and game.campaign_map.back_requested.get_connections().size() == 1,
		"Campaign-Map-Intents sind genau einmal verbunden")
	check(_direct_canvas_layers(game.menus) == 3, "GameMenuController besitzt genau 3 CanvasLayers")
	check(_direct_canvas_layers(game.hud) == 1, "HUDController besitzt genau 1 CanvasLayer")
	check(_direct_canvas_layers(game.quest_menu) == 1 and _direct_canvas_layers(game.case_menu) == 1 \
		and _direct_canvas_layers(game.skin_menu) == 1, "jedes Submenü besitzt genau 1 CanvasLayer")
	await _test_campaign_map_shell()
	await _test_meta_menus(prog)

	# — FAILED via tödlichem Gegnerkontakt —
	game.menus.start_requested.emit()
	check(game.level_root != null and game.current_level == 0 \
		and game.current_region_id == "region_01" and game.current_level_id == "r01_level_01",
		"Run startet mit stabilen IDs in Region 1 Level 1")
	var player_sprite := game.player.find_child("Sprite2D", true, false) as Sprite2D
	check(player_sprite != null and player_sprite.texture.resource_path.ends_with("sprite_princess_blue.png"),
		"ausgerüsteter Skin wird beim Levelstart angewendet")
	game.health = 1
	game.score = 8
	game.coin_count = 3
	game.damage_player()
	check(game.run_outcome == RO.FAILED and game.health == 0 and game.score == 7,
		"tödlicher Gegnerkontakt endet den Run genau einmal")
	check(game.menus.run_result_menu.visible, "Result-Menü sichtbar")
	check(game.menus.result_title_label.text == "Run Over", "Titel 'Run Over'")
	check(game.menus.result_score_value.text == "7" and game.menus.result_coins_value.text == "3", "Score/Coins angezeigt")
	check(game.menus.result_record_label.text == "", "keine Record-Zeile bei FAILED")
	game.menus.show_result(false, 7, 3, "No completed run yet", true)
	check(game.menus.result_record_label.text == "",
		"FAILED unterdrückt Record-Text auch bei fehlerhaftem true-Flag")
	check(not game.highscore_store.has_highscore, "FAILED submittet keinen Highscore")
	check(not FileAccess.file_exists(save_dir.path_join("highscore.cfg")), "highscore.cfg wurde nicht geschrieben")
	check(game.campaign_progress.get_completed_level_ids().is_empty(),
		"FAILED erzeugt keinen Campaign-Completion-Record")
	check(not game.hud.hud_label.visible and not game.hud.message_label.visible, "HUD/Message hinter dem Result versteckt")
	check(game.level_root.process_mode == Node.PROCESS_MODE_DISABLED, "Level deaktiviert")
	check(game.menus.run_result_menu.process_mode == Node.PROCESS_MODE_ALWAYS,
		"Result-Menü bleibt bei deaktiviertem Level interaktiv")
	check(game.menus.result_run_again_btn.has_focus(), "'Run Again' hat Tastatur-Fokus")

	# Wiederholte Fatal-Signale / nachlaufende Callbacks → No-Ops
	var failed_health: int = game.health
	game._finish_run(RO.FAILED)
	game._finish_run(RO.COMPLETED)
	game.damage_player()
	game.fell_off_world()
	check(game.run_outcome == RO.FAILED, "wiederholtes _finish_run ändert Outcome nicht")
	check(game.health == failed_health, "nachlaufender Schaden wird ignoriert")
	check(not game.highscore_store.has_highscore, "auch nachträglich kein Highscore-Submit")

	# Escape öffnet KEIN Pause-Menü über dem Result
	var pause_ev := InputEventAction.new()
	pause_ev.action = "pause"
	pause_ev.pressed = true
	game._unhandled_input(pause_ev)
	check(not paused and not game.menus.pause_menu.visible, "Escape öffnet kein Pause-Menü über dem Result")

	# R vom FAILED-Result → zentraler Clean-Run
	var restart_ev := InputEventAction.new()
	restart_ev.action = "restart"
	restart_ev.pressed = true
	game._unhandled_input(restart_ev)
	check(game.run_outcome == RO.NONE and not game.menus.run_result_menu.visible, "R räumt das Result auf")
	check(game.score == 0 and game.coin_count == 0 and game.health == int(game.MAX_HEALTH), "Clean-Run: Score/Coins/Health zurückgesetzt")
	check(game.current_level == 0 and not game.transitioning and game.invuln_until == 0.0, "Clean-Run: Level 1, keine Transition, keine Invulnerability")
	check(not game.took_damage_this_run and not game.took_damage_this_level, "Clean-Run: Schadens-Tracking zurückgesetzt")
	check(game.hud.hud_label.visible, "HUD wieder sichtbar")

	# FAILED via tödlichem Fall → derselbe Screen, Maus-Run-Again und sauberer Run
	game.health = 1
	game.score = 5
	game.coin_count = 2
	game.fell_off_world()
	check(game.run_outcome == RO.FAILED and game.menus.result_title_label.text == "Run Over",
		"tödlicher Fall nutzt denselben Run-Over-Screen")
	game.menus.result_run_again_btn.pressed.emit()
	check(game.run_outcome == RO.NONE and game.current_level == 0 and game.health == int(game.MAX_HEALTH) \
		and game.score == 0 and game.coin_count == 0 and game.invuln_until == 0.0,
		"FAILED Run-Again-Button startet einen Clean-Run")

	# FAILED → Main Menu über den echten Button; nachlaufende Gameplay-Callbacks bleiben No-Ops
	game.health = 1
	game.damage_player()
	var result_main_menu := _find_button_by_text(game.menus.run_result_menu, "Main Menu")
	check(result_main_menu != null, "Result-Main-Menu-Button vorhanden")
	if result_main_menu != null:
		result_main_menu.pressed.emit()
	check(game.in_main_menu and game.level_root == null and not game.menus.run_result_menu.visible,
		"FAILED Main Menu räumt Result und Gameplay auf")
	var menu_health: int = game.health
	var menu_score: int = game.score
	var menu_generation: int = game.transition_gen
	game.damage_player()
	game.fell_off_world()
	game.reach_goal()
	game._finish_run(RO.FAILED)
	check(game.in_main_menu and game.health == menu_health and game.score == menu_score \
		and game.transition_gen == menu_generation and not game.transitioning \
		and not game.menus.run_result_menu.visible,
		"nachlaufende Gameplay-Callbacks können im Hauptmenü kein Result öffnen")

	# — COMPLETED (mit erzwungenen Weeklies für die Genau-einmal-Prüfung) —
	game.menus.start_requested.emit()
	prog.weekly_ids = ["w_finish_runs", "w_no_damage_run"]
	prog.weekly_progress = [0, 0]
	prog.weekly_completed = [false, false]
	prog.weekly_claimed = [false, false]
	game.current_level = game.LEVELS.size() - 1  # als liefe Level 6
	game.current_level_id = "r01_level_06"
	game.score = 10
	game.coin_count = 5
	game.took_damage_this_run = false
	game.reach_goal()  # letztes Level → synchroner _finish_run(COMPLETED)
	check(game.run_outcome == RO.COMPLETED, "Outcome = COMPLETED")
	check(game.menus.result_title_label.text == "Run Complete", "Titel 'Run Complete'")
	check(game.menus.result_record_label.text == "New Highscore!", "erster Abschluss zeigt 'New Highscore!'")
	check(game.highscore_store.has_highscore and game.highscore_store.best_score == 10 \
		and game.highscore_store.best_coins == 5, "_submit_run() gespeichert (10/5)")
	check(FileAccess.file_exists(save_dir.path_join("highscore.cfg")), "highscore.cfg geschrieben")
	check(int(prog.weekly_progress[0]) == 1, "finish_run-Progress genau 1x")
	check(int(prog.weekly_progress[1]) == 1, "no_damage_run-Progress vergeben (schadensfrei)")

	# Doppelte Goal-Signale / _finish_run-Aufrufe → keine Doppelvergabe
	game.reach_goal()
	game._finish_run(RO.COMPLETED)
	game._finish_run(RO.FAILED)
	check(int(prog.weekly_progress[0]) == 1 and int(prog.weekly_progress[1]) == 1, "Quest-Progress bleibt bei 1 (keine Doppelvergabe)")
	check(game.highscore_store.best_score == 10 and game.highscore_store.best_coins == 5,
		"kein doppelter Highscore-Submit")
	check(game.run_outcome == RO.COMPLETED, "Outcome bleibt COMPLETED")

	# Run Again vom COMPLETED-Result über den echten Button
	game.menus.result_run_again_btn.pressed.emit()
	check(game.run_outcome == RO.NONE and game.current_level == 0, "'Run Again' startet Clean-Run")

	# Vergleichssemantik: schlechterer abgeschlossener Run ändert den Bestwert nicht
	game.current_level = game.LEVELS.size() - 1
	game.current_level_id = "r01_level_06"
	game.score = 9
	game.coin_count = 99
	game.reach_goal()
	check(game.highscore_store.best_score == 10 and game.highscore_store.best_coins == 5,
		"niedrigerer Score schlägt Best nicht (trotz mehr Coins)")
	check(game.menus.result_record_label.text == "", "keine Record-Zeile ohne neuen Rekord")
	check(game.menus.result_best_label.text.begins_with("Best Run"), "stabile Best-Run-Zeile")
	game._unhandled_input(restart_ev)
	check(game.run_outcome == RO.NONE and game.current_level == 0 and game.score == 0 \
		and game.coin_count == 0 and game.health == int(game.MAX_HEALTH),
		"R startet auch vom COMPLETED-Result einen Clean-Run")

	# Pause-Menü "Try Again" nach echtem Schaden nutzt denselben Clean-Run-Pfad
	game.damage_player()
	check(game.health == int(game.MAX_HEALTH) - 1 and game.took_damage_this_run,
		"nicht-tödlicher Schaden setzt Zustand vor Pause-Try-Again")
	game._toggle_pause()
	check(paused and game.menus.pause_menu.visible, "Pause-Menü öffnet im Lauf")
	var try_again := _find_button_by_text(game.menus.pause_menu, "Try Again")
	check(try_again != null, "Pause-Try-Again-Button vorhanden")
	if try_again != null:
		try_again.pressed.emit()
	check(not paused and not game.menus.pause_menu.visible and game.current_level == 0 \
		and game.health == int(game.MAX_HEALTH) and not game.took_damage_this_run \
		and game.invuln_until == 0.0,
		"Pause-Try-Again hebt Pause auf und startet Clean-Run")

	# Main Menu vom Result aus
	game.current_level = game.LEVELS.size() - 1
	game.current_level_id = "r01_level_06"
	game.reach_goal()
	result_main_menu = _find_button_by_text(game.menus.run_result_menu, "Main Menu")
	if result_main_menu != null:
		result_main_menu.pressed.emit()
	check(game.in_main_menu and game.level_root == null, "'Main Menu' räumt Gameplay auf")
	check(not game.menus.run_result_menu.visible and game.run_outcome == RO.NONE,
		"Result-Zustand im Menü zurückgesetzt")
	check(game.menus.highscore_label.text.begins_with("Best:"), "Hauptmenü zeigt aktualisierten Bestwert")
	await create_timer(0.05).timeout  # queue_free des Levels abwickeln

func _test_campaign_map_shell() -> void:
	print("Campaign-Map-Shell:")
	check(not game.campaign_map.menu.visible, "Map-Shell ist im normalen Main-Menü verborgen")
	check(game.campaign_map.menu.theme == game.ui_theme, "Map-Shell nutzt das gemeinsame Theme")
	check(_direct_canvas_layers(game.campaign_map) == 1, "CampaignMapController besitzt genau 1 CanvasLayer")
	game.campaign_map.initialize(
		game.ui_theme, game.ui_heading_font, game.ui_body_font,
		game.campaign_catalog, game.campaign_progress, game.audio,
	)
	check(_direct_canvas_layers(game.campaign_map) == 1,
		"wiederholtes Initialize dupliziert den Map-Layer nicht")
	check(game.campaign_map.menu.process_mode == Node.PROCESS_MODE_ALWAYS,
		"Map-Shell verarbeitet Input unabhängig vom Gameplay")
	game.show_campaign_map_preview("region_01")
	await process_frame
	check(game.campaign_map.menu.visible and not game.menus.main_menu.visible,
		"öffentliche Preview-API zeigt Region 1 ohne Main-Menü-Überlagerung")
	check(game.campaign_map.node_buttons.size() == 6, "Region 1 rendert sechs kataloggetriebene Nodes")
	check(game.campaign_map.path_layer.segments.size() == 5 \
		and _count_optional_segments(game.campaign_map.path_layer.segments) == 0,
		"Region 1 rendert fünf solide Main-Verbindungen")
	check(game.campaign_map.selected_level_id == "r01_level_01" \
		and not game.campaign_map.play_button.disabled,
		"Entry-Level ist deterministisch ausgewählt und spielbar")
	var entry_button := game.campaign_map.node_buttons["r01_level_01"] as Button
	check(entry_button.has_focus(), "Entry-Level erhält initialen Tastatur-Fokus")
	var locked_button := game.campaign_map.node_buttons["r01_level_02"] as Button
	locked_button.pressed.emit()
	check(game.campaign_map.selected_level_id == "r01_level_02" \
		and game.campaign_map.play_button.disabled,
		"Mauswahl kann Locked-Details ansehen, aber nicht starten")
	game.campaign_map.select_level("r01_level_01", false)
	game.campaign_map.refresh()
	game.campaign_map.refresh()
	check(game.campaign_map.node_buttons.size() == 6 and _direct_canvas_layers(game.campaign_map) == 1,
		"wiederholtes Refresh dupliziert weder Nodes noch CanvasLayer")

	var requested := [0]
	game.campaign_map.level_requested.connect(func(_id: String) -> void: requested[0] += 1)
	game.campaign_map.show_region("region_02")
	await process_frame
	check(game.campaign_map.node_buttons.size() == 10, "unreleased Region 2 rendert 8 Main- und 2 Bonus-Nodes")
	check(_count_optional_segments(game.campaign_map.path_layer.segments) == 2,
		"Region-2-Bonuspfad bleibt semantisch dotted/optional")
	check(_count_locked_segments(game.campaign_map.path_layer.segments) \
		== game.campaign_map.path_layer.segments.size(),
		"unreleased Pfade bleiben über Unlock-State gedimmt")
	check(game.campaign_map.location_status.text.begins_with("Coming Soon") \
		and game.campaign_map.play_button.disabled,
		"unreleased Region zeigt Coming Soon und deaktiviert Play")
	game.campaign_map.play_button.pressed.emit()
	check(requested[0] == 0, "unreleased Node kann keinen Level-Request emittieren")
	game.campaign_map.back_button.pressed.emit()
	check(not game.campaign_map.menu.visible and game.menus.main_menu.visible,
		"Back räumt Map-Shell auf und kehrt ins normale Main-Menü zurück")

func _test_meta_menus(prog: Node) -> void:
	print("Menü-Komponenten:")
	game.menus.quests_requested.emit()
	check(game.quest_menu.menu.visible and not game.menus.main_menu.visible,
		"Quest-Intent öffnet nur das Quest-Menü")
	check(game.quest_menu.quests_list.get_child_count() > 0, "Quest-Menü rendert Daily/Weekly-Inhalt")
	game.quest_menu.back_requested.emit()
	check(game.menus.main_menu.visible and not game.quest_menu.menu.visible,
		"Quest-Back-Intent kehrt ins Hauptmenü zurück")

	prog.keys = 1
	var cases_before: int = prog.get_cases_opened()
	game.menus.cases_requested.emit()
	check(game.case_menu.menu.visible and not game.menus.main_menu.visible,
		"Case-Intent öffnet nur das Cases-Menü")
	game.case_menu._on_open_case_pressed(false)
	check(game.case_menu.is_spinning, "regulärer Case-Spin startet")
	check(game.case_menu.open_case_button.disabled and game.case_menu.premium_case_button.disabled \
		and game.case_menu.back_button.disabled, "Case-Navigation ist während des Spins gesperrt")
	await create_timer(3.6).timeout
	check(not game.case_menu.is_spinning and prog.get_cases_opened() == cases_before + 1,
		"Case-Spin endet und vergibt genau einen Reward")
	game.case_menu.back_requested.emit()
	check(game.menus.main_menu.visible and not game.case_menu.menu.visible,
		"Case-Back-Intent kehrt ins Hauptmenü zurück")

	game.menus.skins_requested.emit()
	check(game.skin_menu.menu.visible and game.skin_menu.skins_list.get_child_count() >= 2,
		"Skin-Intent öffnet Liste mit Default und Starter")
	check(_all_buttons_centered(game), "alle Button-Texte sind horizontal zentriert")
	var button_style := game.ui_theme.get_stylebox("normal", "Button") as StyleBoxTexture
	check(is_equal_approx(button_style.content_margin_top, button_style.content_margin_bottom),
		"Button-Content ist vertikal symmetrisch zentriert")
	game.skin_menu._on_select_skin("princess_blue")
	check(game.skin_menu.preview_name.text == "Sapphire Princess", "Skin-Auswahl aktualisiert Preview")
	game.skin_menu._on_equip_selected()
	check(prog.equipped_skin == "princess_blue", "separater Equip-Befehl persistiert den Starter-Skin")
	game.skin_menu.back_requested.emit()
	check(game.menus.main_menu.visible and not game.skin_menu.menu.visible,
		"Skin-Back-Intent kehrt ins Hauptmenü zurück")

# --- Transition-Cancellation ------------------------------------------------------

func _test_transition_cancellation() -> void:
	print("Transition-Cancellation:")
	# a) Normaler verzögerter Übergang
	game._start_game()
	game.score = 3
	game.coin_count = 2
	game.reach_goal()
	check(game.transitioning and game.hud.message_label.visible and game.hud.message_label.text == "Level Cleared!",
		"Level-Clear-Meldung während der Transition")
	await create_timer(TRANSITION_WAIT).timeout
	check(game.current_level == 1 and game.current_level_id == "r01_level_02",
		"normaler Übergang lädt Level 2 über stabile ID")
	var level_1_record: Dictionary = game.campaign_progress.get_level_record("r01_level_01")
	check(level_1_record.has_record and level_1_record.score == 3 and level_1_record.coins == 2,
		"Goal speichert Region-1-Level-1 genau mit lokalen Werten")

	# b) Restart während Transition pending
	game.score = 5
	game.coin_count = 3
	game.reach_goal()
	game._start_new_run()
	await create_timer(TRANSITION_WAIT).timeout
	check(game.current_level == 0, "Restart macht wartenden Übergang ungültig")
	var level_2_record: Dictionary = game.campaign_progress.get_level_record("r01_level_02")
	check(level_2_record.has_record and level_2_record.score == 2 and level_2_record.coins == 1,
		"per-Level-Record verwendet Deltas statt kumulativer Run-Werte")

	# c) Exit zum Hauptmenü während Transition pending
	game.reach_goal()
	game._exit_to_main_menu()
	await create_timer(TRANSITION_WAIT).timeout
	check(game.in_main_menu and game.level_root == null, "Menü-Exit macht wartenden Übergang ungültig")

	# d) Run-Ende (FAILED) während Transition pending
	game._start_game()
	game.reach_goal()
	game._finish_run(game.RunOutcome.FAILED)
	await create_timer(TRANSITION_WAIT).timeout
	check(game.current_level == 0, "kein veralteter Übergang nach Run-Ende")
	check(game.menus.run_result_menu.visible and game.run_outcome == game.RunOutcome.FAILED,
		"Result bleibt nach abgelaufenem Timer bestehen")
	check(game.menus.start_requested.get_connections().size() == 1 \
		and game.menus.restart_requested.get_connections().size() == 1 \
		and game.menus.main_menu_requested.get_connections().size() == 1,
		"Menü-Signale bleiben nach wiederholten Level-Loads einfach verbunden")
	check(_direct_canvas_layers(game.menus) == 3 and _direct_canvas_layers(game.hud) == 1,
		"Level-Loads duplizieren keine persistenten UI-Layer")
	game._exit_to_main_menu()
	await create_timer(0.05).timeout  # letzten queue_free-Lifecycle vor Suite-Ende abwickeln

func _direct_canvas_layers(owner: Node) -> int:
	var count := 0
	for child: Node in owner.get_children():
		if child is CanvasLayer:
			count += 1
	return count

func _all_buttons_centered(node: Node) -> bool:
	if node is Button and (node as Button).alignment != HORIZONTAL_ALIGNMENT_CENTER:
		return false
	for child: Node in node.get_children():
		if not _all_buttons_centered(child):
			return false
	return true

func _find_button_by_text(node: Node, button_text: String) -> Button:
	if node is Button and (node as Button).text == button_text:
		return node as Button
	for child: Node in node.get_children():
		var found := _find_button_by_text(child, button_text)
		if found != null:
			return found
	return null

func _count_optional_segments(segments: Array) -> int:
	var count := 0
	for segment: Dictionary in segments:
		if bool(segment.get("optional", false)):
			count += 1
	return count

func _count_locked_segments(segments: Array) -> int:
	var count := 0
	for segment: Dictionary in segments:
		if not bool(segment.get("unlocked", false)):
			count += 1
	return count
