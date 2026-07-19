extends SceneTree

const CampaignCatalogScript := preload("res://scripts/CampaignCatalog.gd")
const CampaignProgressStoreScript := preload("res://scripts/CampaignProgressStore.gd")
const TestEnv := preload("res://tests/test_env.gd")

var checks := 0
var failures := 0
var save_dir := ""
var owns_save_dir := false
var test_dir := ""


func _init() -> void:
	var iso: Dictionary = TestEnv.ensure_isolated("campaign")
	save_dir = iso.dir
	owns_save_dir = iso.owned
	test_dir = save_dir.path_join("campaign_suite")
	DirAccess.make_dir_recursive_absolute(test_dir)
	process_frame.connect(_run_all, CONNECT_ONE_SHOT)


func _run_all() -> void:
	_test_catalog()
	_test_fresh_progression_and_records()
	_test_save_normalization_and_recovery()
	_test_trial_gate_and_future_release()
	_test_bonus_mastery()
	print("")
	if failures == 0:
		print("ALLE TESTS OK (%d Checks)" % checks)
		TestEnv.remove_dir_recursive(test_dir)
		if owns_save_dir:
			TestEnv.remove_dir_recursive(save_dir)
	else:
		printerr("FEHLGESCHLAGEN: %d von %d Checks (Dateien in %s belassen)" % [
			failures, checks, test_dir])
	quit(0 if failures == 0 else 1)


func check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		printerr("  FAIL %s" % label)


func _test_catalog() -> void:
	print("Campaign-Katalog:")
	var catalog: RefCounted = CampaignCatalogScript.new()
	check((catalog.call("validate") as PackedStringArray).is_empty(), "Standard-Katalog ist valide")
	var region_ids := catalog.call("get_region_ids") as Array
	check(region_ids == ["region_01", "region_02", "region_03", "region_04", "region_05"],
		"fünf Region-IDs sind stabil und geordnet")
	var r1_main := catalog.call("get_main_level_ids", "region_01") as Array
	var r2_main := catalog.call("get_main_level_ids", "region_02") as Array
	var r2_bonus := catalog.call("get_bonus_level_ids", "region_02") as Array
	check(r1_main.size() == 6, "Region 1 enthält sechs Main-Level")
	check(r2_main.size() == 8 and r2_bonus.size() == 2, "Region 2 enthält 8 Main- und 2 Bonus-Platzhalter")
	var expected_main_counts := {
		"region_01": 6, "region_02": 8, "region_03": 10, "region_04": 12, "region_05": 14,
	}
	var counts_ok := true
	for count_region_id: String in expected_main_counts:
		var main_ids := catalog.call("get_main_level_ids", count_region_id) as Array
		if main_ids.size() != int(expected_main_counts[count_region_id]):
			counts_ok = false
	check(counts_ok, "Main-Level-Zählungen sind exakt 6/8/10/12/14")
	var expected_next := {
		"region_01": "region_02", "region_02": "region_03", "region_03": "region_04",
		"region_04": "region_05", "region_05": "",
	}
	var links_ok := true
	for link_region_id: String in expected_next:
		var linked_region := catalog.call("get_region", link_region_id) as Dictionary
		if String(linked_region.get("next_region_id", "?")) != String(expected_next[link_region_id]):
			links_ok = false
	check(links_ok, "Regionen sind sequenziell verkettet, Region 5 ohne Nachfolger")
	check(not (catalog.call("get_level", "r03_level_01") as Dictionary).is_empty() \
		and not (catalog.call("get_level", "r04_level_12") as Dictionary).is_empty() \
		and not (catalog.call("get_level", "r05_level_14") as Dictionary).is_empty(),
		"Platzhalter-IDs r03_level_01 bis r05_level_14 sind stabil adressierbar")
	var future_locked := true
	for future_number: int in [2, 3, 4, 5]:
		var future_id := "region_%02d" % future_number
		var future_entry := String((catalog.call("get_region", future_id) as Dictionary).get("entry_level_id", ""))
		if bool(catalog.call("is_region_released", future_id)) \
				or bool(catalog.call("is_level_playable", future_entry)):
			future_locked = false
	check(future_locked, "Regionen 2-5 bleiben unreleased und nicht startbar")
	var future_required_only := true
	var future_scenes_empty := true
	for future_number: int in [3, 4, 5]:
		var future_id := "region_%02d" % future_number
		for connection: Dictionary in catalog.call("get_region_connections", future_id):
			if String(connection.kind) != CampaignCatalogScript.REQUIRED_CONNECTION:
				future_required_only = false
		if not (catalog.call("get_bonus_level_ids", future_id) as Array).is_empty():
			future_required_only = false
		for future_level_id: Variant in catalog.call("get_level_ids", future_id, true):
			var future_level := catalog.call("get_level", String(future_level_id)) as Dictionary
			if String(future_level.get("scene_path", "x")) != "":
				future_scenes_empty = false
	check(future_required_only, "Regionen 3-5 nutzen ausschließlich Required-Pfade ohne Bonus-Abzweige")
	check(future_scenes_empty, "Regionen 3-5 haben durchgehend leere Szenenpfade")
	var all_r1_scenes_exist := true
	for level_id: String in r1_main:
		var level := catalog.call("get_level", level_id) as Dictionary
		all_r1_scenes_exist = all_r1_scenes_exist \
			and ResourceLoader.exists(String(level.scene_path), "PackedScene")
	check(all_r1_scenes_exist, "alle Region-1-IDs lösen echte PackedScenes auf")
	check(not bool(catalog.call("is_region_released", "region_02")), "Region 2 ist unreleased")
	check(not bool(catalog.call("is_level_playable", "r02_level_01")), "Region-2-Platzhalter ist nicht spielbar")
	var optional_count := 0
	for connection: Dictionary in catalog.call("get_region_connections", "region_02"):
		if connection.kind == CampaignCatalogScript.OPTIONAL_CONNECTION:
			optional_count += 1
	check(optional_count == 2, "Bonus-Route besitzt explizit optionale Verbindungen")
	check("r02_bonus_01" not in r2_main and "r02_bonus_01" in r2_bonus,
		"Bonus-Level zählen nie als Main-Level")

	var malformed := CampaignCatalogScript.default_regions()
	malformed[1].levels[0].id = "r01_level_01"
	malformed[1].connections[0].to = "missing_level"
	malformed[1].released = true
	var bad_catalog: RefCounted = CampaignCatalogScript.new(malformed)
	var errors := bad_catalog.call("validate") as PackedStringArray
	check(not errors.is_empty(), "Validator meldet doppelte IDs, Dangling Edges und fehlende Szenen")

	malformed = CampaignCatalogScript.default_regions()
	malformed[0].levels[0].prerequisites = ["r01_level_02"]
	var cyclic_catalog: RefCounted = CampaignCatalogScript.new(malformed)
	errors = cyclic_catalog.call("validate") as PackedStringArray
	check(_contains_text(errors, "cyclic"), "Validator erkennt zyklische Prerequisites")


func _test_fresh_progression_and_records() -> void:
	print("Campaign-Fortschritt und Records:")
	var path := _path("fresh.cfg")
	var catalog: RefCounted = CampaignCatalogScript.new()
	var store: Node = _load_store(catalog, path)
	check(FileAccess.file_exists(path), "frischer Campaign-Save wird angelegt")
	check(store.get_unlocked_region_ids() == ["region_01"], "frisch ist nur Region 1 freigeschaltet")
	check(store.get_unlocked_level_ids() == ["r01_level_01"], "frisch ist nur Region-1-Level-1 freigeschaltet")
	check(not store.is_region_unlocked("region_02"), "unreleased Region 2 bleibt gesperrt")
	var absent: Dictionary = store.get_level_record("r01_level_01")
	check(not absent.has_record and absent.score == 0 and absent.coins == 0,
		"kein Record ist von einem 0/0-Record unterscheidbar")
	var locked_result: Dictionary = store.record_level_completion("r01_level_02", 99, 99)
	check(not locked_result.level_completed and not store.is_level_completed("r01_level_02"),
		"gesperrtes Level kann keinen Completion-Record erzeugen")

	var unlocked_signals := [0]
	store.level_unlocked.connect(func(_id: String) -> void: unlocked_signals[0] += 1)
	var result: Dictionary = store.record_level_completion("r01_level_01", 0, 0)
	var zero_record: Dictionary = store.get_level_record("r01_level_01")
	check(result.level_completed and result.new_record and zero_record.has_record,
		"gültiger 0/0-Abschluss erzeugt einen Record")
	check(store.is_level_unlocked("r01_level_02") and result.newly_unlocked_levels == ["r01_level_02"],
		"Abschluss schaltet den erforderlichen Nachfolger frei")
	check(unlocked_signals[0] == 1, "Level-Unlock-Signal feuert genau einmal")
	result = store.record_level_completion("r01_level_01", -1, 50)
	check(not result.new_record and store.get_level_record("r01_level_01").score == 0,
		"niedrigerer Score verliert trotz mehr Coins")
	result = store.record_level_completion("r01_level_01", 0, 2)
	check(result.new_record and store.get_level_record("r01_level_01").coins == 2,
		"gleicher Score mit mehr Coins gewinnt")
	result = store.record_level_completion("r01_level_01", 1, 0)
	check(result.new_record and store.get_level_record("r01_level_01").score == 1,
		"höherer Score gewinnt unabhängig von Coins")
	check(unlocked_signals[0] == 1, "wiederholter Abschluss emittiert keinen Unlock erneut")

	for i: int in range(1, 6):
		store.record_level_completion("r01_level_%02d" % (i + 1), i, i * 2)
	check(store.is_region_cleared("region_01"), "alle sechs Main-Level clearen Region 1")
	check(store.is_region_explored("region_01"), "Region ohne Bonus-Level gilt als explored")
	check(store.is_region_mastered("region_01"), "Region ohne zusätzliche Mastery-Anforderungen wird beim Clear gemastert")
	check(not store.is_region_unlocked("region_02"), "Clear lädt keine unreleased Region")
	var summary: Dictionary = store.get_region_summary("region_01")
	check(summary.main_completed == 6 and summary.main_total == 6 and summary.cleared,
		"Region-Summary leitet Main-Completion korrekt ab")
	store.free()

	store = _load_store(catalog, path)
	check(store.is_region_cleared("region_01") and store.get_level_record("r01_level_01").score == 1,
		"Completion und Records überleben einen Reload")
	var before_hash := FileAccess.get_md5(path)
	store.free()
	store = _load_store(catalog, path)
	check(FileAccess.get_md5(path) == before_hash, "gültiger Campaign-Save lädt idempotent")
	store.free()


func _test_save_normalization_and_recovery() -> void:
	print("Campaign-Save-Normalisierung:")
	var catalog: RefCounted = CampaignCatalogScript.new()
	var malformed_path := _path("malformed.cfg")
	_write_cfg(malformed_path, {
		"meta": {"version": 1},
		"campaign": {
			"unlocked_regions": ["ghost", "region_02"],
			"unlocked_levels": "broken",
			"completed_levels": ["ghost_level", 42],
			"last_selected_region": 99,
			"last_selected_level": "ghost_level",
		},
		"records": {"levels": ["broken"]},
		"trials": {"progress": "broken"},
		"milestones": {"cleared_regions": ["ghost"], "mastered_regions": "broken"},
	})
	var store: Node = _load_store(catalog, malformed_path)
	check(store.get_unlocked_region_ids() == ["region_01"], "kaputte Unlocks fallen auf sichere Region-1-Defaults")
	check(store.get_unlocked_level_ids() == ["r01_level_01"], "kaputte Level-Unlocks fallen auf Entry-Level zurück")
	check(store.get_completed_level_ids().is_empty(), "unbekannte/falsch getypte Completion-IDs werden entfernt")
	check(not store.get_level_record("r01_level_01").has_record, "kaputtes Record-Containerfeld wird isoliert verworfen")
	store.free()

	var recovery_path := _path("recover.cfg")
	_write_cfg(recovery_path + ".bak", {
		"meta": {"version": 1},
		"campaign": {
			"unlocked_regions": ["region_01"],
			"unlocked_levels": ["r01_level_01", "r01_level_02"],
			"completed_levels": ["r01_level_01"],
		},
		"records": {"levels": {"r01_level_01": {"score": 4, "coins": 3}}},
	})
	var file := FileAccess.open(recovery_path, FileAccess.WRITE)
	file.store_string("[broken")
	file.close()
	store = _load_store(catalog, recovery_path)
	check(store.is_level_completed("r01_level_01") and store.get_level_record("r01_level_01").score == 4,
		"korrupter Haupt-Save wird aus .bak wiederhergestellt")
	var repaired := ConfigFile.new()
	check(repaired.load(recovery_path) == OK, "Campaign-Haupt-Save ist nach Recovery wieder parsebar")
	store.free()


func _test_trial_gate_and_future_release() -> void:
	print("Core Trials und Future Release:")
	var regions := CampaignCatalogScript.default_regions()
	regions[0].trials = [{
		"id": "r01_core_trial",
		"region_id": "region_01",
		"display_name": "Placeholder Core Trial",
		"target": 2,
		"required_for_clear": true,
		"required_for_mastery": false,
	}]
	_make_region_playable(regions[1])
	var catalog: RefCounted = CampaignCatalogScript.new(regions)
	check((catalog.call("validate") as PackedStringArray).is_empty(), "synthetischer Release-Katalog ist valide")
	var path := _path("future_release.cfg")
	var store: Node = _load_store(catalog, path)
	for i: int in range(6):
		store.record_level_completion("r01_level_%02d" % (i + 1), i, i)
	check(not store.is_region_cleared("region_01"), "fehlender Core Trial blockiert Region Clear")
	check(not store.is_region_unlocked("region_02"), "fehlender Core Trial blockiert nächste Region")
	store.add_region_trial_progress("r01_core_trial")
	check(not store.is_region_cleared("region_01"), "Teilfortschritt erfüllt Core Trial nicht")
	var update: Dictionary = store.add_region_trial_progress("r01_core_trial")
	check(update.trial_completed and store.is_region_cleared("region_01"), "voller Core Trial cleart Region")
	check(store.is_region_unlocked("region_02") and store.is_level_unlocked("r02_level_01"),
		"bereits released Folgeregion und Entry-Level werden freigeschaltet")
	store.free()

	regions = CampaignCatalogScript.default_regions()
	var old_catalog: RefCounted = CampaignCatalogScript.new(regions)
	path = _path("release_later.cfg")
	store = _load_store(old_catalog, path)
	for i: int in range(6):
		store.record_level_completion("r01_level_%02d" % (i + 1), i, i)
	check(not store.is_region_unlocked("region_02"), "unreleased Region bleibt vor Update gesperrt")
	store.free()
	regions = CampaignCatalogScript.default_regions()
	_make_region_playable(regions[1])
	var released_catalog: RefCounted = CampaignCatalogScript.new(regions)
	store = _load_store(released_catalog, path)
	check(store.is_region_unlocked("region_02") and store.is_level_unlocked("r02_level_01"),
		"später veröffentlichte Region erkennt alte Clear-Voraussetzungen automatisch")
	store.free()


func _test_bonus_mastery() -> void:
	print("Bonus und Completionist-Mastery:")
	var regions := CampaignCatalogScript.default_regions()
	_make_region_playable(regions[1])
	regions[1].trials = [{
		"id": "r02_mastery_trial",
		"region_id": "region_02",
		"display_name": "Placeholder Mastery Trial",
		"target": 1,
		"required_for_clear": false,
		"required_for_mastery": true,
	}]
	var catalog: RefCounted = CampaignCatalogScript.new(regions)
	var store: Node = _load_store(catalog, _path("mastery.cfg"))
	for i: int in range(6):
		store.record_level_completion("r01_level_%02d" % (i + 1), i, i)
	for i: int in range(8):
		store.record_level_completion("r02_level_%02d" % (i + 1), i, i)
	check(store.is_region_cleared("region_02"), "alle Region-2-Main-Level reichen für Region Clear")
	check(not store.is_region_explored("region_02"), "offene Bonus-Level verhindern explored")
	check(not store.is_region_mastered("region_02"), "Bonus und Mastery Trial blockieren Mastered")
	store.record_level_completion("r02_bonus_01", 3, 1)
	check(not store.is_region_explored("region_02"), "erste Bonus-Stufe allein reicht nicht")
	var mastery_signals := [0]
	store.region_mastered.connect(func(_id: String) -> void: mastery_signals[0] += 1)
	store.record_level_completion("r02_bonus_02", 4, 2)
	check(store.is_region_explored("region_02") and not store.is_region_mastered("region_02"),
		"alle Bonus-Level erfüllen explored, Mastery Trial bleibt separat")
	store.add_region_trial_progress("r02_mastery_trial")
	check(store.is_region_mastered("region_02") and mastery_signals[0] == 1,
		"Bonus plus Mastery Trial emittieren Mastered genau einmal")
	store.add_region_trial_progress("r02_mastery_trial")
	store.record_level_completion("r02_bonus_02", 5, 2)
	check(mastery_signals[0] == 1, "wiederholte Updates emittieren Mastered nicht erneut")
	store.free()


func _load_store(catalog: RefCounted, path: String) -> Node:
	var store: Node = CampaignProgressStoreScript.new()
	store.configure(catalog, path)
	store.load_data()
	return store


func _make_region_playable(region: Dictionary) -> void:
	region.released = true
	for level: Dictionary in region.levels:
		level.scene_path = "res://scenes/Level1.tscn"


func _path(filename: String) -> String:
	return test_dir.path_join(filename)


func _write_cfg(path: String, sections: Dictionary) -> void:
	var cfg := ConfigFile.new()
	for section: String in sections:
		for key: String in sections[section]:
			cfg.set_value(section, key, sections[section][key])
	cfg.save(path)


func _contains_text(values: PackedStringArray, needle: String) -> bool:
	for value: String in values:
		if value.to_lower().contains(needle.to_lower()):
			return true
	return false
