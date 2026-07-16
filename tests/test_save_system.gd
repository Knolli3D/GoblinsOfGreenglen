extends SceneTree

# Test-Harness für das versionierte Save-System (SaveData.gd + Progression.gd + Game.gd).
# Headless ausführen (einzeln, oder komplett über res://tests/run_all.gd):
#
#   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s res://tests/test_save_system.gd
#
# Vollständig isoliert: _init() setzt (falls der Runner sie nicht schon vererbt hat)
# GOGG_TEST_SAVE_DIR auf ein frisches Temp-Verzeichnis, BEVOR die Autoloads starten —
# dadurch liest/schreibt auch das mitbootende Progression-Autoload nur dort und die
# Save-Migration wird übersprungen. Die Testdateien der Suite selbst liegen in einem
# eigenen Unterordner; Progression.save_path / Game.highscore_path werden pro Test
# umgebogen. Echte Saves unter user:// werden nie berührt.
# Exit-Code 0 = alle Checks ok, 1 = mindestens ein Check fehlgeschlagen.
# WARNING-Zeilen im Output sind erwartet: die Tests füttern absichtlich kaputte Saves.

const ProgressionScript := preload("res://scripts/Progression.gd")
const SaveData := preload("res://scripts/SaveData.gd")
const TestEnv := preload("res://tests/test_env.gd")

var checks := 0
var failures := 0
var today: String = Time.get_date_string_from_system()
var this_week: int = int((Time.get_unix_time_from_system() / 86400.0 + 3.0) / 7.0)
# Isoliertes Basis-Verzeichnis (GOGG_TEST_SAVE_DIR) + eigener Unterordner dieser Suite.
var save_dir := ""
var owns_save_dir := false
var test_dir := ""
# Game.gd referenziert das Autoload "Progression" und kompiliert deshalb erst, wenn die
# Autoloads registriert sind — das passiert im -s-Modus NACH _init(), vor dem ersten
# Frame. Daher kein preload, sondern Laden zur Laufzeit in _run_all().
var game_script: GDScript

func _init() -> void:
	var iso: Dictionary = TestEnv.ensure_isolated("save")
	save_dir = iso.dir
	owns_save_dir = iso.owned
	test_dir = save_dir.path_join("save_suite")
	seed(20260716)  # deterministische Quest-Rolls (shuffle) in den Testinstanzen
	process_frame.connect(_run_all, CONNECT_ONE_SHOT)

func _run_all() -> void:
	_reset_test_dir()
	_test_fresh_install()
	_test_valid_current_save()
	_test_unversioned_v1_upgrade()
	_test_missing_fields()
	_test_wrong_types()
	_test_negative_currencies()
	_test_unknown_quest_ids()
	_test_all_quests_invalid_reroll()
	_test_mismatched_quest_arrays()
	_test_weekly_normalization()
	_test_skin_inventory()
	_test_equipped_not_owned()
	_test_starter_skin_survives()
	_test_best_pull_invalid()
	_test_corrupt_main_with_backup()
	_test_corrupt_main_without_backup()
	_test_write_failure()
	_test_idempotent_cycles()
	game_script = ResourceLoader.load("res://scripts/Game.gd", "GDScript", ResourceLoader.CACHE_MODE_IGNORE)
	check(game_script != null and game_script.can_instantiate(), "Game.gd kompiliert (Autoloads registriert)")
	if game_script != null and game_script.can_instantiate():
		_test_highscore()
	print("")
	if failures == 0:
		print("ALLE TESTS OK (%d Checks)" % checks)
		TestEnv.remove_dir_recursive(test_dir)
		if owns_save_dir:
			TestEnv.remove_dir_recursive(save_dir)
	else:
		printerr("FEHLGESCHLAGEN: %d von %d Checks (Dateien in %s belassen)" % [failures, checks, test_dir])
	quit(0 if failures == 0 else 1)

# --- Infrastruktur -----------------------------------------------------------

func check(cond: bool, name: String) -> void:
	checks += 1
	if cond:
		print("  ok   %s" % name)
	else:
		failures += 1
		printerr("  FAIL %s" % name)

func _reset_test_dir() -> void:
	DirAccess.make_dir_recursive_absolute(test_dir)
	var d := DirAccess.open(test_dir)
	if d != null:
		for f: String in d.get_files():
			d.remove(f)

func _path(fname: String) -> String:
	return test_dir.path_join(fname)

func _write_cfg(path: String, sections: Dictionary) -> void:
	var cfg := ConfigFile.new()
	for section: String in sections:
		for key: String in sections[section]:
			cfg.set_value(section, key, sections[section][key])
	cfg.save(path)

func _write_raw(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()

# Instanziert Progression ohne Autoload/Szenenbaum und fährt den echten Lade-Pfad.
# Aufrufer muss .free() aufrufen (Node, kein RefCounted).
func _load_progression(path: String) -> Node:
	var p: Node = ProgressionScript.new()
	p.save_path = path
	p.load_and_validate()
	return p

# Gültiger Save im aktuellen Format (heutiges Datum/aktuelle Woche, damit die
# Reset-Checks nichts umwerfen).
func _valid_sections(versioned: bool) -> Dictionary:
	var d := {
		"currency": {"keys": 5, "key_fragments": 2, "dup_shards": 4},
		"stats": {"cases_opened": 11, "best_pull": "epic"},
		"quests": {
			"last_reset": today,
			"daily_claims_today": 3,
			"active_ids": ["stomp_goblins", "collect_coins", "coin_hunter"],
			"progress": [3, 15, 7],
			"completed": [false, true, false],
			"claimed": [false, true, false],
			"week_id": this_week,
			"weekly_ids": ["w_stomp", "w_coins"],
			"weekly_progress": [10, 100],
			"weekly_completed": [false, true],
			"weekly_claimed": [false, false],
		},
		"inventory": {
			"owned_skins": ["princess_blue", "gold_knight", "black_knight"],
			"equipped_skin": "black_knight",
		},
	}
	if versioned:
		d["meta"] = {"version": ProgressionScript.SAVE_VERSION}
	return d

# --- Progression-Szenarien ---------------------------------------------------

func _test_fresh_install() -> void:
	print("Fresh Install:")
	var path := _path("fresh.cfg")
	var p := _load_progression(path)
	check(p.keys == 0 and p.key_fragments == 0 and p.dup_shards == 0, "Währungen starten bei 0")
	check(p.owned_skins == ProgressionScript.STARTER_SKINS, "Starter-Skins vorhanden")
	check(p.equipped_skin == "", "Default Knight ausgerüstet")
	check(p.active_ids.size() == ProgressionScript.DAILY_SLOTS, "3 Daily-Quests gerollt")
	check(p.progress.size() == p.active_ids.size() and p.claimed.size() == p.active_ids.size(), "Quest-Arrays passen zu active_ids")
	check(p.weekly_ids.size() == ProgressionScript.WEEKLY_SLOTS, "2 Weeklies gerollt")
	check(p.get_active_quests().size() == ProgressionScript.DAILY_SLOTS, "Quest-Menü-Daten ohne Crash")
	var cfg := ConfigFile.new()
	check(cfg.load(path) == OK and cfg.get_value("meta", "version", -1) == ProgressionScript.SAVE_VERSION, "neuer Save trägt Version %d" % ProgressionScript.SAVE_VERSION)
	p.free()

func _test_valid_current_save() -> void:
	print("Gültiger aktueller Save (v2):")
	var path := _path("valid_v2.cfg")
	_write_cfg(path, _valid_sections(true))
	var before := FileAccess.get_file_as_string(path)
	var p := _load_progression(path)
	check(p.keys == 5 and p.key_fragments == 2 and p.dup_shards == 4, "Währungen unverändert")
	check(p.active_ids == ["stomp_goblins", "collect_coins", "coin_hunter"], "Quest-IDs unverändert")
	check(p.progress == [3, 15, 7] and p.claimed == [false, true, false], "Quest-Fortschritt unverändert")
	check(p.owned_skins == ["princess_blue", "gold_knight", "black_knight"], "Inventar unverändert")
	check(p.equipped_skin == "black_knight", "equipped_skin unverändert")
	check(FileAccess.get_file_as_string(path) == before, "gültiger Save wird nicht neu geschrieben")
	p.free()

func _test_unversioned_v1_upgrade() -> void:
	print("Unversionierter Alt-Save (v1) → Upgrade:")
	var path := _path("legacy_v1.cfg")
	_write_cfg(path, _valid_sections(false))
	var p := _load_progression(path)
	check(p.loaded_version == SaveData.UNVERSIONED, "als Version 1 erkannt")
	check(p.keys == 5 and p.cases_opened == 11 and p.best_pull == "epic", "Daten erhalten")
	check(p.equipped_skin == "black_knight", "equipped_skin erhalten")
	var cfg := ConfigFile.new()
	check(cfg.load(path) == OK and cfg.get_value("meta", "version", -1) == ProgressionScript.SAVE_VERSION, "Datei auf v2 gehoben")
	var bak := ConfigFile.new()
	check(bak.load(path + ".bak") == OK and not bak.has_section("meta"), "v1-Stand liegt als .bak")
	p.free()
	# Idempotenz: zweiter Lauf ändert nichts mehr
	var after_first := FileAccess.get_file_as_string(path)
	var p2 := _load_progression(path)
	check(FileAccess.get_file_as_string(path) == after_first, "Upgrade ist idempotent")
	p2.free()

func _test_missing_fields() -> void:
	print("Fehlende Felder:")
	var path := _path("sparse.cfg")
	_write_cfg(path, {"currency": {"keys": 3}})
	var p := _load_progression(path)
	check(p.keys == 3, "vorhandenes Feld bleibt erhalten (kein Komplett-Reset)")
	check(p.active_ids.size() == ProgressionScript.DAILY_SLOTS, "fehlende Quests neu gerollt")
	check(p.owned_skins == ProgressionScript.STARTER_SKINS, "Starter-Skins ergänzt")
	p.free()

func _test_wrong_types() -> void:
	print("Falsche Feld-Typen:")
	var path := _path("types.cfg")
	var s := _valid_sections(true)
	s.currency.keys = "banana"
	s.quests.active_ids = "kein array"
	s.quests.progress = 42
	s.inventory.equipped_skin = 7
	s.stats.best_pull = 3.5
	_write_cfg(path, s)
	var p := _load_progression(path)
	check(p.keys == 0, "keys: String → Default 0")
	check(p.active_ids.size() == ProgressionScript.DAILY_SLOTS, "active_ids: kaputt → Reroll")
	check(p.equipped_skin == "", "equipped_skin: int → Default Knight")
	check(p.best_pull == "", "best_pull: float → zurückgesetzt")
	check(p.key_fragments == 2 and p.owned_skins.size() == 3, "intakte Nachbarfelder unangetastet")
	p.free()

func _test_negative_currencies() -> void:
	print("Negative Währungen/Zähler:")
	var path := _path("negative.cfg")
	var s := _valid_sections(true)
	s.currency = {"keys": -5, "key_fragments": -1, "dup_shards": -3}
	s.stats.cases_opened = -2
	s.quests.daily_claims_today = -4
	s.quests.week_id = -100
	_write_cfg(path, s)
	var p := _load_progression(path)
	check(p.keys == 0 and p.key_fragments == 0 and p.dup_shards == 0, "Währungen auf 0 geklemmt")
	check(p.cases_opened == 0 and p.daily_claims_today == 0, "Zähler auf 0 geklemmt")
	check(p.week_id == this_week, "negative week_id → Weekly-Reset auf aktuelle Woche")
	p.free()

func _test_unknown_quest_ids() -> void:
	print("Unbekannte Quest-IDs:")
	var path := _path("badquests.cfg")
	var s := _valid_sections(true)
	s.quests.active_ids = ["stomp_goblins", "fake_quest", "coin_hunter"]
	s.quests.progress = [3, 999, 7]
	s.quests.completed = [false, true, false]
	s.quests.claimed = [false, true, false]
	_write_cfg(path, s)
	var p := _load_progression(path)
	check(p.active_ids == ["stomp_goblins", "coin_hunter"], "unbekannte ID entfernt")
	check(p.progress == [3, 7], "Slot-Daten wandern mit ihrer ID mit")
	check(p.completed == [false, false] and p.claimed == [false, false], "parallele Arrays ausgerichtet")
	check(p.get_active_quests().size() == 2, "Quest-Menü-Daten ohne Crash")
	p.free()

func _test_all_quests_invalid_reroll() -> void:
	print("Alle Quest-IDs ungültig → sicherer Reroll:")
	var path := _path("allbad.cfg")
	var s := _valid_sections(true)
	s.quests.active_ids = ["ghost_a", "ghost_b", "ghost_c"]
	s.quests.daily_claims_today = 4
	_write_cfg(path, s)
	var p := _load_progression(path)
	check(p.active_ids.size() == ProgressionScript.DAILY_SLOTS, "frische Quests gerollt")
	check(p.progress == [0, 0, 0] and p.claimed == [false, false, false], "Fortschritt zurückgesetzt")
	check(p.daily_claims_today == 4, "daily_claims_today bleibt erhalten (kein Claim-Reset)")
	p.free()

func _test_mismatched_quest_arrays() -> void:
	print("Zu kurze/zu lange Quest-Arrays:")
	var path := _path("mismatch.cfg")
	var s := _valid_sections(true)
	s.quests.active_ids = ["stomp_goblins", "collect_coins", "double_jumps"]
	s.quests.progress = [99]
	s.quests.completed = []
	s.quests.claimed = [true, true, true, true, true]
	_write_cfg(path, s)
	var p := _load_progression(path)
	check(p.progress.size() == 3 and p.completed.size() == 3 and p.claimed.size() == 3, "Arrays auf active_ids-Länge normalisiert")
	check(p.progress == [5, 0, 0], "progress geklemmt auf Target (5) bzw. gedefaultet")
	check(p.completed == [true, false, false], "completed folgt aus progress >= target")
	check(p.claimed == [true, false, false], "claimed nur wo completed")
	p.free()

func _test_weekly_normalization() -> void:
	print("Weekly-Normalisierung:")
	var path := _path("weekly.cfg")
	var s := _valid_sections(true)
	s.quests.weekly_ids = ["w_stomp", "w_ghost"]
	s.quests.weekly_progress = [200, 1]
	s.quests.weekly_completed = ["ja", false]
	s.quests.weekly_claimed = [true]
	_write_cfg(path, s)
	var p := _load_progression(path)
	check(p.weekly_ids == ["w_stomp"], "unbekannte Weekly-ID entfernt")
	check(p.weekly_progress == [50], "Weekly-progress auf Target (50) geklemmt")
	check(p.weekly_completed == [true] and p.weekly_claimed == [true], "completed aus progress abgeleitet, claimed erhalten")
	p.free()
	# leere Weekly-Liste in der aktuellen Woche → Reroll
	var path2 := _path("weekly_empty.cfg")
	var s2 := _valid_sections(true)
	s2.quests.weekly_ids = ["nope_1", "nope_2"]
	_write_cfg(path2, s2)
	var p2 := _load_progression(path2)
	check(p2.weekly_ids.size() == ProgressionScript.WEEKLY_SLOTS, "alle Weeklies ungültig → Reroll in aktueller Woche")
	p2.free()

func _test_skin_inventory() -> void:
	print("Skin-Inventar (Duplikate + unbekannte IDs):")
	var path := _path("skins.cfg")
	var s := _valid_sections(true)
	s.inventory.owned_skins = ["gold_knight", "gold_knight", "fake_skin", 42, "princess_blue"]
	s.inventory.equipped_skin = "gold_knight"
	_write_cfg(path, s)
	var p := _load_progression(path)
	check(p.owned_skins == ["gold_knight", "princess_blue"], "dedupliziert, Unbekanntes/falsche Typen entfernt")
	check(p.equipped_skin == "gold_knight", "gültiger equipped_skin bleibt")
	check(p.get_owned_skins().size() == 2, "Skins-Menü-Daten ohne Crash")
	check(p.get_equipped_skin().id == "gold_knight", "get_equipped_skin liefert Artwork-Eintrag")
	p.free()

func _test_equipped_not_owned() -> void:
	print("Equipped-Skin nicht besessen:")
	var path := _path("equipped.cfg")
	var s := _valid_sections(true)
	s.inventory.owned_skins = ["princess_blue"]
	s.inventory.equipped_skin = "black_knight"
	_write_cfg(path, s)
	var p := _load_progression(path)
	check(p.equipped_skin == "", "Fallback auf Default Knight")
	check(p.get_equipped_skin().id == "" and p.get_equipped_skin().tier == "default", "get_equipped_skin liefert Default")
	p.free()

func _test_starter_skin_survives() -> void:
	print("Equippter Starter-Skin überlebt kaputtes Inventar:")
	var path := _path("starter.cfg")
	var s := _valid_sections(true)
	s.inventory.owned_skins = ["fake_skin"]
	s.inventory.equipped_skin = "princess_blue"
	_write_cfg(path, s)
	var p := _load_progression(path)
	check("princess_blue" in p.owned_skins, "Starter-Skin garantiert")
	check(p.equipped_skin == "princess_blue", "equippter Starter-Skin bleibt ausgerüstet")
	p.free()

func _test_best_pull_invalid() -> void:
	print("Ungültiger best_pull-Tier:")
	var path := _path("bestpull.cfg")
	var s := _valid_sections(true)
	s.stats.best_pull = "mythic"
	_write_cfg(path, s)
	var p := _load_progression(path)
	check(p.best_pull == "", "unbekannter Tier zurückgesetzt")
	check(p.cases_opened == 11, "Nachbarfeld cases_opened bleibt")
	p.free()

func _test_corrupt_main_with_backup() -> void:
	print("Korrupter Haupt-Save + gültiges Backup:")
	var path := _path("recover.cfg")
	_write_cfg(path + ".bak", _valid_sections(true))
	_write_raw(path, "[kaputt\nkeys = \"nicht zu Ende")
	var p := _load_progression(path)
	check(p.keys == 5 and p.equipped_skin == "black_knight", "Daten aus Backup wiederhergestellt")
	var cfg := ConfigFile.new()
	check(cfg.load(path) == OK, "Haupt-Save aus Backup repariert (Self-Healing)")
	p.free()

func _test_corrupt_main_without_backup() -> void:
	print("Korrupter Haupt-Save ohne Backup:")
	var path := _path("corrupt_only.cfg")
	_write_raw(path, "%%% definitiv kein configfile %%%")
	var p := _load_progression(path)
	check(p.keys == 0 and p.owned_skins == ProgressionScript.STARTER_SKINS, "Defaults ohne Crash")
	check(p.active_ids.size() == ProgressionScript.DAILY_SLOTS, "Quests frisch gerollt")
	p.free()

func _test_write_failure() -> void:
	print("Schreibfehler (Verzeichnis fehlt):")
	var p: Node = ProgressionScript.new()
	p.save_path = _path("gibt_es_nicht/sub/prog.cfg")
	p.load_and_validate()
	var ok: bool = p._save()
	check(ok == false, "_save() meldet Fehlschlag statt zu crashen")
	check(p.owned_skins == ProgressionScript.STARTER_SKINS, "Zustand im Speicher bleibt gültig")
	p.free()

func _test_idempotent_cycles() -> void:
	print("Wiederholte Load/Save-Zyklen:")
	var path := _path("cycles.cfg")
	_write_cfg(path, _valid_sections(false))  # v1 → erster Lauf schreibt Upgrade
	var p1 := _load_progression(path)
	p1.free()
	var after_first := FileAccess.get_file_as_string(path)
	for i in range(3):
		var p := _load_progression(path)
		p._save()  # zusätzlich erzwungener Save
		p.free()
	check(FileAccess.get_file_as_string(path) == after_first, "Datei-Inhalt nach 3 weiteren Zyklen byte-identisch")
	var bak := ConfigFile.new()
	check(bak.load(path + ".bak") == OK, "Backup existiert und parst")
	p1 = null

# --- Highscore-Szenarien -----------------------------------------------------

func _make_game(path: String) -> Node2D:
	var g: Node2D = game_script.new()
	g.highscore_path = path
	g._load_highscore()
	return g

func _test_highscore() -> void:
	print("Highscore:")
	# frisch — keine Datei
	var g := _make_game(_path("hs_fresh.cfg"))
	check(not g.has_highscore, "frisch: kein Highscore")
	g.free()
	# unversionierter v1-Save → laden + Upgrade
	var v1_path := _path("hs_v1.cfg")
	_write_cfg(v1_path, {"highscore": {"score": 12, "coins": 30}})
	g = _make_game(v1_path)
	check(g.has_highscore and g.best_score == 12 and g.best_coins == 30, "v1 geladen")
	var cfg := ConfigFile.new()
	var hs_version: int = game_script.HIGHSCORE_SAVE_VERSION
	check(cfg.load(v1_path) == OK and cfg.get_value("meta", "version", -1) == hs_version, "v1 → v2 gehoben")
	var bak := ConfigFile.new()
	check(bak.load(v1_path + ".bak") == OK and not bak.has_section("meta"), "v1-Stand als .bak gesichert")
	# Vergleichs-Semantik unverändert: höherer Score gewinnt, Gleichstand → mehr Coins
	check(g._submit_run(12, 30) == false, "gleicher Run ist kein neuer Rekord")
	check(g._submit_run(11, 99) == false, "weniger Score verliert trotz mehr Coins")
	check(g._submit_run(12, 31) == true, "Gleichstand + mehr Coins gewinnt")
	check(g._submit_run(13, 0) == true, "höherer Score gewinnt immer")
	g.free()
	# negative Werte werden geklemmt
	var neg_path := _path("hs_neg.cfg")
	_write_cfg(neg_path, {"highscore": {"score": -7, "coins": -1}})
	g = _make_game(neg_path)
	check(g.has_highscore and g.best_score == 0 and g.best_coins == 0, "negative Werte → 0")
	g.free()
	# falscher score-Typ → kein Highscore, aber kein Crash
	var bad_path := _path("hs_bad.cfg")
	_write_cfg(bad_path, {"highscore": {"score": "viele", "coins": 5}})
	g = _make_game(bad_path)
	check(not g.has_highscore, "unbrauchbarer score → als 'kein Highscore' behandelt")
	g.free()
	# kaputtes coins-Feld verwirft den gültigen Score nicht
	var coin_path := _path("hs_coins.cfg")
	_write_cfg(coin_path, {"highscore": {"score": 8, "coins": "viele"}})
	g = _make_game(coin_path)
	check(g.has_highscore and g.best_score == 8 and g.best_coins == 0, "score bleibt trotz kaputtem coins-Feld")
	g.free()
	# korrupter Haupt-Save + gültiges Backup
	var rec_path := _path("hs_recover.cfg")
	_write_cfg(rec_path + ".bak", {"meta": {"version": 2}, "highscore": {"score": 21, "coins": 9}})
	_write_raw(rec_path, "[kaputt")
	g = _make_game(rec_path)
	check(g.has_highscore and g.best_score == 21 and g.best_coins == 9, "aus Backup wiederhergestellt")
	check(cfg.load(rec_path) == OK, "Haupt-Save repariert")
	g.free()
	# Schreibfehler
	g = game_script.new()
	g.highscore_path = _path("gibt_es_nicht/hs.cfg")
	g.best_score = 3
	g.has_highscore = true
	g._save_highscore()
	check(g.best_score == 3, "Schreibfehler crasht nicht, Zustand bleibt")
	g.free()
