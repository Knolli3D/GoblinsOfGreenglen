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
	var sfx: Dictionary = game.SFX_FILES
	for key: String in sfx:
		check(ResourceLoader.exists(sfx[key]), "SFX '%s' existiert (%s)" % [key, sfx[key]])
	check(ResourceLoader.exists(game.MUSIC_FILE), "Musik existiert (%s)" % game.MUSIC_FILE)

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

	# — FAILED —
	game._start_game()
	check(game.level_root != null and game.current_level == 0, "Run startet in Level 1")
	game.score = 7
	game.coin_count = 3
	game._finish_run(RO.FAILED)
	check(game.run_outcome == RO.FAILED, "Outcome = FAILED")
	check(game.run_result_menu.visible, "Result-Menü sichtbar")
	check(game.result_title_label.text == "Run Over", "Titel 'Run Over'")
	check(game.result_score_value.text == "7" and game.result_coins_value.text == "3", "Score/Coins angezeigt")
	check(game.result_record_label.text == "", "keine Record-Zeile bei FAILED")
	check(not game.has_highscore, "FAILED submittet keinen Highscore")
	check(not FileAccess.file_exists(save_dir.path_join("highscore.cfg")), "highscore.cfg wurde nicht geschrieben")
	check(not game.hud_label.visible and not game.message_label.visible, "HUD/Message hinter dem Result versteckt")
	check(game.level_root.process_mode == Node.PROCESS_MODE_DISABLED, "Level deaktiviert")
	check(game.result_run_again_btn.has_focus(), "'Run Again' hat Tastatur-Fokus")

	# Wiederholte Fatal-Signale / nachlaufende Callbacks → No-Ops
	game._finish_run(RO.FAILED)
	game._finish_run(RO.COMPLETED)
	game.damage_player()
	game.fell_off_world()
	check(game.run_outcome == RO.FAILED, "wiederholtes _finish_run ändert Outcome nicht")
	check(game.health == int(game.MAX_HEALTH), "nachlaufender Schaden wird ignoriert")
	check(not game.has_highscore, "auch nachträglich kein Highscore-Submit")

	# Escape öffnet KEIN Pause-Menü über dem Result
	var pause_ev := InputEventAction.new()
	pause_ev.action = "pause"
	pause_ev.pressed = true
	game._unhandled_input(pause_ev)
	check(not paused and not game.pause_menu.visible, "Escape öffnet kein Pause-Menü über dem Result")

	# R vom FAILED-Result → zentraler Clean-Run
	var restart_ev := InputEventAction.new()
	restart_ev.action = "restart"
	restart_ev.pressed = true
	game._unhandled_input(restart_ev)
	check(game.run_outcome == RO.NONE and not game.run_result_menu.visible, "R räumt das Result auf")
	check(game.score == 0 and game.coin_count == 0 and game.health == int(game.MAX_HEALTH), "Clean-Run: Score/Coins/Health zurückgesetzt")
	check(game.current_level == 0 and not game.transitioning and game.invuln_until == 0.0, "Clean-Run: Level 1, keine Transition, keine Invulnerability")
	check(not game.took_damage_this_run and not game.took_damage_this_level, "Clean-Run: Schadens-Tracking zurückgesetzt")
	check(game.hud_label.visible, "HUD wieder sichtbar")

	# — COMPLETED (mit erzwungenen Weeklies für die Genau-einmal-Prüfung) —
	prog.weekly_ids = ["w_finish_runs", "w_no_damage_run"]
	prog.weekly_progress = [0, 0]
	prog.weekly_completed = [false, false]
	prog.weekly_claimed = [false, false]
	game.current_level = game.LEVELS.size() - 1  # als liefe Level 6
	game.score = 10
	game.coin_count = 5
	game.took_damage_this_run = false
	game.reach_goal()  # letztes Level → synchroner _finish_run(COMPLETED)
	check(game.run_outcome == RO.COMPLETED, "Outcome = COMPLETED")
	check(game.result_title_label.text == "Run Complete", "Titel 'Run Complete'")
	check(game.result_record_label.text == "New Highscore!", "erster Abschluss zeigt 'New Highscore!'")
	check(game.has_highscore and game.best_score == 10 and game.best_coins == 5, "_submit_run() gespeichert (10/5)")
	check(FileAccess.file_exists(save_dir.path_join("highscore.cfg")), "highscore.cfg geschrieben")
	check(int(prog.weekly_progress[0]) == 1, "finish_run-Progress genau 1x")
	check(int(prog.weekly_progress[1]) == 1, "no_damage_run-Progress vergeben (schadensfrei)")

	# Doppelte Goal-Signale / _finish_run-Aufrufe → keine Doppelvergabe
	game.reach_goal()
	game._finish_run(RO.COMPLETED)
	game._finish_run(RO.FAILED)
	check(int(prog.weekly_progress[0]) == 1 and int(prog.weekly_progress[1]) == 1, "Quest-Progress bleibt bei 1 (keine Doppelvergabe)")
	check(game.best_score == 10 and game.best_coins == 5, "kein doppelter Highscore-Submit")
	check(game.run_outcome == RO.COMPLETED, "Outcome bleibt COMPLETED")

	# Run Again vom COMPLETED-Result (Maus-Pfad = Button-Handler)
	game._restart_level_from_menu()
	check(game.run_outcome == RO.NONE and game.current_level == 0, "'Run Again' startet Clean-Run")

	# Vergleichssemantik: schlechterer abgeschlossener Run ändert den Bestwert nicht
	game.current_level = game.LEVELS.size() - 1
	game.score = 9
	game.coin_count = 99
	game.reach_goal()
	check(game.best_score == 10 and game.best_coins == 5, "niedrigerer Score schlägt Best nicht (trotz mehr Coins)")
	check(game.result_record_label.text == "", "keine Record-Zeile ohne neuen Rekord")
	check(game.result_best_label.text.begins_with("Best Run"), "stabile Best-Run-Zeile")

	# damage_player während FAILED-Run: kein Schaden, aber Weekly no_damage bleibt korrekt —
	# hier nur: Pause-Menü "Try Again" nutzt denselben Clean-Run-Pfad
	game._restart_level_from_menu()
	game._toggle_pause()
	check(paused and game.pause_menu.visible, "Pause-Menü öffnet im Lauf")
	game._restart_level_from_menu()
	check(not paused and not game.pause_menu.visible and game.current_level == 0, "'Try Again' hebt Pause auf und startet Clean-Run")

	# Main Menu vom Result aus
	game.current_level = game.LEVELS.size() - 1
	game.reach_goal()
	game._exit_to_main_menu()
	check(game.in_main_menu and game.level_root == null, "'Main Menu' räumt Gameplay auf")
	check(not game.run_result_menu.visible and game.run_outcome == RO.NONE, "Result-Zustand im Menü zurückgesetzt")
	check(game.highscore_label.text.begins_with("Best:"), "Hauptmenü zeigt aktualisierten Bestwert")
	await create_timer(0.05).timeout  # queue_free des Levels abwickeln

# --- Transition-Cancellation ------------------------------------------------------

func _test_transition_cancellation() -> void:
	print("Transition-Cancellation:")
	# a) Normaler verzögerter Übergang
	game._start_game()
	game.reach_goal()
	check(game.transitioning and game.message_label.visible and game.message_label.text == "Level Cleared!",
		"Level-Clear-Meldung während der Transition")
	await create_timer(TRANSITION_WAIT).timeout
	check(game.current_level == 1, "normaler Übergang lädt Level 2")

	# b) Restart während Transition pending
	game.reach_goal()
	game._start_new_run()
	await create_timer(TRANSITION_WAIT).timeout
	check(game.current_level == 0, "Restart macht wartenden Übergang ungültig")

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
	check(game.run_result_menu.visible and game.run_outcome == game.RunOutcome.FAILED,
		"Result bleibt nach abgelaufenem Timer bestehen")
	game._exit_to_main_menu()
