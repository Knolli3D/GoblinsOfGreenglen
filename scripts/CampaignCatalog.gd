extends RefCounted

const REGION_1_ID := "region_01"
const REGION_2_ID := "region_02"
const REGION_3_ID := "region_03"
const REGION_4_ID := "region_04"
const REGION_5_ID := "region_05"
const REQUIRED_CONNECTION := "required"
const OPTIONAL_CONNECTION := "optional"
const VALID_CONNECTION_KINDS := [REQUIRED_CONNECTION, OPTIONAL_CONNECTION]
const MAP_BOUNDS := Rect2(Vector2.ZERO, Vector2(650, 370))

const REGION_1_SCENE_PATHS := [
	"res://scenes/Level1.tscn",
	"res://scenes/Level2.tscn",
	"res://scenes/Level3.tscn",
	"res://scenes/Level4.tscn",
	"res://scenes/Level5.tscn",
	"res://scenes/Level6.tscn",
]

static func default_regions() -> Array:
	return [
	{
		"id": REGION_1_ID,
		"display_name": "Region 1",
		"released": true,
		"entry_level_id": "r01_level_01",
		"next_region_id": REGION_2_ID,
		"fallback_color": Color("#315845"),
		# "kind"/"level_id" machen den Trial katalog-getrieben: Game.gd zählt
		# "no_damage_level"-Trials generisch, ohne Region/Level hartzukodieren.
		"trials": [{
			"id": "r01_core_flawless_finale",
			"region_id": REGION_1_ID,
			"display_name": "Flawless Finale: clear Location 6 without taking damage",
			"target": 1,
			"required_for_clear": true,
			"required_for_mastery": false,
			"kind": "no_damage_level",
			"level_id": "r01_level_06",
		}],
		"levels": [
			_level("r01_level_01", REGION_1_ID, "Region 1 - Location 1", REGION_1_SCENE_PATHS[0], Vector2(55, 275), false, [], {"right": "r01_level_02"}),
			_level("r01_level_02", REGION_1_ID, "Region 1 - Location 2", REGION_1_SCENE_PATHS[1], Vector2(155, 205), false, ["r01_level_01"], {"left": "r01_level_01", "right": "r01_level_03"}),
			_level("r01_level_03", REGION_1_ID, "Region 1 - Location 3", REGION_1_SCENE_PATHS[2], Vector2(270, 285), false, ["r01_level_02"], {"left": "r01_level_02", "right": "r01_level_04"}),
			_level("r01_level_04", REGION_1_ID, "Region 1 - Location 4", REGION_1_SCENE_PATHS[3], Vector2(380, 185), false, ["r01_level_03"], {"left": "r01_level_03", "right": "r01_level_05"}),
			_level("r01_level_05", REGION_1_ID, "Region 1 - Location 5", REGION_1_SCENE_PATHS[4], Vector2(485, 270), false, ["r01_level_04"], {"left": "r01_level_04", "right": "r01_level_06"}),
			_level("r01_level_06", REGION_1_ID, "Region 1 - Location 6", REGION_1_SCENE_PATHS[5], Vector2(545, 115), false, ["r01_level_05"], {"left": "r01_level_05"}),
		],
		"connections": [
			_connection("r01_level_01", "r01_level_02", REQUIRED_CONNECTION),
			_connection("r01_level_02", "r01_level_03", REQUIRED_CONNECTION),
			_connection("r01_level_03", "r01_level_04", REQUIRED_CONNECTION),
			_connection("r01_level_04", "r01_level_05", REQUIRED_CONNECTION),
			_connection("r01_level_05", "r01_level_06", REQUIRED_CONNECTION),
		],
	},
	{
		"id": REGION_2_ID,
		"display_name": "Region 2",
		"released": false,
		"entry_level_id": "r02_level_01",
		"next_region_id": REGION_3_ID,
		"fallback_color": Color("#35465C"),
		"trials": [],
		"levels": [
			_level("r02_level_01", REGION_2_ID, "Region 2 - Location 1", "", Vector2(65, 280), false, [], {"right": "r02_level_02"}),
			_level("r02_level_02", REGION_2_ID, "Region 2 - Location 2", "", Vector2(160, 320), false, ["r02_level_01"], {"left": "r02_level_01", "right": "r02_level_03"}),
			_level("r02_level_03", REGION_2_ID, "Region 2 - Location 3", "", Vector2(260, 235), false, ["r02_level_02"], {"left": "r02_level_02", "right": "r02_level_04"}),
			_level("r02_level_04", REGION_2_ID, "Region 2 - Location 4", "", Vector2(155, 155), false, ["r02_level_03"], {"left": "r02_level_03", "right": "r02_level_05"}),
			_level("r02_level_05", REGION_2_ID, "Region 2 - Location 5", "", Vector2(280, 105), false, ["r02_level_04"], {"left": "r02_level_04", "right": "r02_level_06", "up": "r02_bonus_01"}),
			_level("r02_level_06", REGION_2_ID, "Region 2 - Location 6", "", Vector2(395, 165), false, ["r02_level_05"], {"left": "r02_level_05", "right": "r02_level_07"}),
			_level("r02_level_07", REGION_2_ID, "Region 2 - Location 7", "", Vector2(475, 250), false, ["r02_level_06"], {"left": "r02_level_06", "right": "r02_level_08"}),
			_level("r02_level_08", REGION_2_ID, "Region 2 - Location 8", "", Vector2(565, 175), false, ["r02_level_07"], {"left": "r02_level_07"}),
			_level("r02_bonus_01", REGION_2_ID, "Region 2 - Bonus 1", "", Vector2(390, 55), true, ["r02_level_05"], {"down": "r02_level_05", "right": "r02_bonus_02"}),
			_level("r02_bonus_02", REGION_2_ID, "Region 2 - Bonus 2", "", Vector2(525, 45), true, ["r02_bonus_01"], {"left": "r02_bonus_01"}),
		],
		"connections": [
			_connection("r02_level_01", "r02_level_02", REQUIRED_CONNECTION),
			_connection("r02_level_02", "r02_level_03", REQUIRED_CONNECTION),
			_connection("r02_level_03", "r02_level_04", REQUIRED_CONNECTION),
			_connection("r02_level_04", "r02_level_05", REQUIRED_CONNECTION),
			_connection("r02_level_05", "r02_level_06", REQUIRED_CONNECTION),
			_connection("r02_level_06", "r02_level_07", REQUIRED_CONNECTION),
			_connection("r02_level_07", "r02_level_08", REQUIRED_CONNECTION),
			_connection("r02_level_05", "r02_bonus_01", OPTIONAL_CONNECTION),
			_connection("r02_bonus_01", "r02_bonus_02", OPTIONAL_CONNECTION),
		],
	},
	_placeholder_region(3, 10, REGION_4_ID, Color("#5C4A35")),
	_placeholder_region(4, 12, REGION_5_ID, Color("#4A3555")),
	_placeholder_region(5, 14, "", Color("#5C3542")),
	]

var _regions: Array = []
var _regions_by_id: Dictionary = {}
var _levels_by_id: Dictionary = {}
var _trials_by_id: Dictionary = {}


func _init(regions: Array = []) -> void:
	_regions = (default_regions() if regions.is_empty() else regions).duplicate(true)
	_rebuild_indexes()


static func _level(
	level_id: String,
	region_id: String,
	display_name: String,
	scene_path: String,
	map_position: Vector2,
	is_bonus: bool,
	prerequisites: Array,
	focus_neighbors: Dictionary,
) -> Dictionary:
	return {
		"id": level_id,
		"region_id": region_id,
		"display_name": display_name,
		"scene_path": scene_path,
		"map_position": map_position,
		"is_bonus": is_bonus,
		"prerequisites": prerequisites,
		"focus_neighbors": focus_neighbors,
	}


static func _connection(from_id: String, to_id: String, kind: String) -> Dictionary:
	return {"from": from_id, "to": to_id, "kind": kind}


# Serpentinen-Raster für unveröffentlichte Platzhalter-Regionen: 5 Spalten pro Zeile,
# Zeilen wachsen von unten nach oben, alle Positionen bleiben in MAP_BOUNDS.
const PLACEHOLDER_COLUMNS := 5
const PLACEHOLDER_ORIGIN := Vector2(40, 300)
const PLACEHOLDER_COLUMN_STEP := 120.0
const PLACEHOLDER_ROW_STEP := 115.0


# Erzeugt eine unveröffentlichte Platzhalter-Region: generische Namen, leere Szenenpfade,
# ein serpentinenförmiger Required-Pfad ohne Bonus-Abzweige, Fokus-Nachbarn aus dem Raster.
static func _placeholder_region(
	region_number: int,
	main_count: int,
	next_region_id: String,
	fallback_color: Color,
) -> Dictionary:
	var region_id := "region_%02d" % region_number
	var cells: Array = []
	var grid: Dictionary = {}
	for i: int in main_count:
		@warning_ignore("integer_division")
		var row := i / PLACEHOLDER_COLUMNS
		var offset := i % PLACEHOLDER_COLUMNS
		var col := offset if row % 2 == 0 else PLACEHOLDER_COLUMNS - 1 - offset
		cells.append(Vector2i(col, row))
		grid[Vector2i(col, row)] = "r%02d_level_%02d" % [region_number, i + 1]
	var directions := {
		"left": Vector2i(-1, 0), "right": Vector2i(1, 0),
		"up": Vector2i(0, 1), "down": Vector2i(0, -1),
	}
	var levels: Array = []
	var connections: Array = []
	for i: int in main_count:
		var cell: Vector2i = cells[i]
		var level_id := String(grid[cell])
		var neighbors: Dictionary = {}
		for direction: String in directions:
			var neighbor_id: Variant = grid.get(cell + directions[direction])
			if neighbor_id != null:
				neighbors[direction] = String(neighbor_id)
		var previous_id := "r%02d_level_%02d" % [region_number, i]
		var prerequisites: Array = [] if i == 0 else [previous_id]
		levels.append(_level(
			level_id,
			region_id,
			"Region %d - Location %d" % [region_number, i + 1],
			"",
			PLACEHOLDER_ORIGIN + Vector2(cell.x * PLACEHOLDER_COLUMN_STEP, -cell.y * PLACEHOLDER_ROW_STEP),
			false,
			prerequisites,
			neighbors,
		))
		if i > 0:
			connections.append(_connection(previous_id, level_id, REQUIRED_CONNECTION))
	return {
		"id": region_id,
		"display_name": "Region %d" % region_number,
		"released": false,
		"entry_level_id": "r%02d_level_01" % region_number,
		"next_region_id": next_region_id,
		"fallback_color": fallback_color,
		"trials": [],
		"levels": levels,
		"connections": connections,
	}


func get_regions() -> Array:
	return _regions.duplicate(true)


func get_region(region_id: String) -> Dictionary:
	return _regions_by_id.get(region_id, {}).duplicate(true)


func get_level(level_id: String) -> Dictionary:
	return _levels_by_id.get(level_id, {}).duplicate(true)


func get_trial(trial_id: String) -> Dictionary:
	return _trials_by_id.get(trial_id, {}).duplicate(true)


func get_region_ids() -> Array:
	var ids: Array = []
	for region: Dictionary in _regions:
		ids.append(String(region.get("id", "")))
	return ids


func get_level_ids(region_id: String, include_bonus := true) -> Array:
	var ids: Array = []
	var region := _regions_by_id.get(region_id, {}) as Dictionary
	for level: Dictionary in region.get("levels", []):
		if include_bonus or not bool(level.get("is_bonus", false)):
			ids.append(String(level.get("id", "")))
	return ids


func get_main_level_ids(region_id: String) -> Array:
	return get_level_ids(region_id, false)


func get_bonus_level_ids(region_id: String) -> Array:
	var ids: Array = []
	var region := _regions_by_id.get(region_id, {}) as Dictionary
	for level: Dictionary in region.get("levels", []):
		if bool(level.get("is_bonus", false)):
			ids.append(String(level.get("id", "")))
	return ids


func get_region_connections(region_id: String) -> Array:
	var region := _regions_by_id.get(region_id, {}) as Dictionary
	return (region.get("connections", []) as Array).duplicate(true)


func get_required_trial_ids(region_id: String) -> Array:
	return _trial_ids_with_flag(region_id, "required_for_clear")


func get_mastery_trial_ids(region_id: String) -> Array:
	return _trial_ids_with_flag(region_id, "required_for_mastery")


func get_successor_ids(level_id: String) -> Array:
	var level := _levels_by_id.get(level_id, {}) as Dictionary
	var region_id := String(level.get("region_id", ""))
	var result: Array = []
	for connection: Dictionary in get_region_connections(region_id):
		if String(connection.get("from", "")) == level_id:
			result.append(String(connection.get("to", "")))
	return result


func get_next_main_level_id(level_id: String) -> String:
	var level := _levels_by_id.get(level_id, {}) as Dictionary
	var region_id := String(level.get("region_id", ""))
	for connection: Dictionary in get_region_connections(region_id):
		if String(connection.get("from", "")) != level_id \
				or String(connection.get("kind", "")) != REQUIRED_CONNECTION:
			continue
		var target_id := String(connection.get("to", ""))
		var target := _levels_by_id.get(target_id, {}) as Dictionary
		if not bool(target.get("is_bonus", false)):
			return target_id
	return ""


func get_main_level_index(level_id: String) -> int:
	var level := _levels_by_id.get(level_id, {}) as Dictionary
	if level.is_empty():
		return -1
	return get_main_level_ids(String(level.get("region_id", ""))).find(level_id)


func get_previous_region_id(region_id: String) -> String:
	for region: Dictionary in _regions:
		if String(region.get("next_region_id", "")) == region_id:
			return String(region.get("id", ""))
	return ""


func is_region_released(region_id: String) -> bool:
	return bool((_regions_by_id.get(region_id, {}) as Dictionary).get("released", false))


func is_level_playable(level_id: String) -> bool:
	var level := _levels_by_id.get(level_id, {}) as Dictionary
	if level.is_empty() or not is_region_released(String(level.get("region_id", ""))):
		return false
	var path := String(level.get("scene_path", ""))
	return path != "" and ResourceLoader.exists(path, "PackedScene")


func prerequisites_met(level_id: String, completed_level_ids: Array) -> bool:
	var level := _levels_by_id.get(level_id, {}) as Dictionary
	if level.is_empty():
		return false
	for prerequisite: Variant in level.get("prerequisites", []):
		if String(prerequisite) not in completed_level_ids:
			return false
	return true


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var region_ids: Dictionary = {}
	var level_ids: Dictionary = {}
	var trial_ids: Dictionary = {}

	for region_value: Variant in _regions:
		if not (region_value is Dictionary):
			errors.append("Region definition is not a Dictionary")
			continue
		var region := region_value as Dictionary
		var region_id := String(region.get("id", ""))
		if region_id == "" or region_ids.has(region_id):
			errors.append("Duplicate or empty region id: %s" % region_id)
			continue
		region_ids[region_id] = true
		for trial_value: Variant in region.get("trials", []):
			if not (trial_value is Dictionary):
				errors.append("Region %s has a non-Dictionary trial" % region_id)
				continue
			var trial := trial_value as Dictionary
			var trial_id := String(trial.get("id", ""))
			if trial_id == "" or trial_ids.has(trial_id):
				errors.append("Duplicate or empty trial id: %s" % trial_id)
			else:
				trial_ids[trial_id] = region_id
		for level_value: Variant in region.get("levels", []):
			if not (level_value is Dictionary):
				errors.append("Region %s has a non-Dictionary level" % region_id)
				continue
			var level := level_value as Dictionary
			var level_id := String(level.get("id", ""))
			if level_id == "" or level_ids.has(level_id):
				errors.append("Duplicate or empty level id: %s" % level_id)
				continue
			level_ids[level_id] = region_id
			if String(level.get("region_id", "")) != region_id:
				errors.append("Level %s references the wrong region" % level_id)
			var pos: Variant = level.get("map_position", null)
			if not (pos is Vector2) or not is_finite((pos as Vector2).x) \
					or not is_finite((pos as Vector2).y) or not MAP_BOUNDS.has_point(pos):
				errors.append("Level %s has an invalid map position" % level_id)
			var path := String(level.get("scene_path", ""))
			if bool(region.get("released", false)) and (path == "" or not ResourceLoader.exists(path, "PackedScene")):
				errors.append("Released level %s has no loadable PackedScene" % level_id)

	for region_value: Variant in _regions:
		if not (region_value is Dictionary):
			continue
		var region := region_value as Dictionary
		var region_id := String(region.get("id", ""))
		var entry_id := String(region.get("entry_level_id", ""))
		if not level_ids.has(entry_id) or level_ids.get(entry_id) != region_id:
			errors.append("Region %s has an invalid entry level" % region_id)
		var next_region_id := String(region.get("next_region_id", ""))
		if next_region_id != "" and not region_ids.has(next_region_id):
			errors.append("Region %s references unknown next region %s" % [region_id, next_region_id])
		for level_value: Variant in region.get("levels", []):
			if not (level_value is Dictionary):
				continue
			var level := level_value as Dictionary
			var level_id := String(level.get("id", ""))
			for prerequisite: Variant in level.get("prerequisites", []):
				if not level_ids.has(String(prerequisite)):
					errors.append("Level %s has dangling prerequisite %s" % [level_id, prerequisite])
			for neighbor: Variant in (level.get("focus_neighbors", {}) as Dictionary).values():
				if not level_ids.has(String(neighbor)):
					errors.append("Level %s has dangling focus neighbor %s" % [level_id, neighbor])
		for connection_value: Variant in region.get("connections", []):
			if not (connection_value is Dictionary):
				errors.append("Region %s has a non-Dictionary connection" % region_id)
				continue
			var connection := connection_value as Dictionary
			var from_id := String(connection.get("from", ""))
			var to_id := String(connection.get("to", ""))
			var kind := String(connection.get("kind", ""))
			if not level_ids.has(from_id) or not level_ids.has(to_id):
				errors.append("Region %s has a dangling connection %s -> %s" % [region_id, from_id, to_id])
			elif level_ids[from_id] != region_id or level_ids[to_id] != region_id:
				errors.append("Region %s has a cross-region level connection" % region_id)
			if kind not in VALID_CONNECTION_KINDS:
				errors.append("Connection %s -> %s has invalid kind %s" % [from_id, to_id, kind])
			var target := _levels_by_id.get(to_id, {}) as Dictionary
			if bool(target.get("is_bonus", false)) and kind != OPTIONAL_CONNECTION:
				errors.append("Bonus level %s must use an optional connection" % to_id)
		for trial_value: Variant in region.get("trials", []):
			if not (trial_value is Dictionary):
				continue
			var trial := trial_value as Dictionary
			var trial_id := String(trial.get("id", ""))
			if int(trial.get("target", 0)) <= 0:
				errors.append("Trial %s has a non-positive target" % trial_id)
			if String(trial.get("region_id", "")) != region_id:
				errors.append("Trial %s references the wrong region" % trial_id)
			var trial_level_id := String(trial.get("level_id", ""))
			if trial_level_id != "" \
					and (not level_ids.has(trial_level_id) or level_ids[trial_level_id] != region_id):
				errors.append("Trial %s references unknown level %s" % [trial_id, trial_level_id])
		_validate_reachability(region, errors)
		_validate_prerequisite_cycles(region, errors)
	return errors


func _rebuild_indexes() -> void:
	_regions_by_id.clear()
	_levels_by_id.clear()
	_trials_by_id.clear()
	for region_value: Variant in _regions:
		if not (region_value is Dictionary):
			continue
		var region := region_value as Dictionary
		var region_id := String(region.get("id", ""))
		if region_id != "" and not _regions_by_id.has(region_id):
			_regions_by_id[region_id] = region
		for level_value: Variant in region.get("levels", []):
			if level_value is Dictionary:
				var level := level_value as Dictionary
				var level_id := String(level.get("id", ""))
				if level_id != "" and not _levels_by_id.has(level_id):
					_levels_by_id[level_id] = level
		for trial_value: Variant in region.get("trials", []):
			if trial_value is Dictionary:
				var trial := trial_value as Dictionary
				var trial_id := String(trial.get("id", ""))
				if trial_id != "" and not _trials_by_id.has(trial_id):
					_trials_by_id[trial_id] = trial


func _trial_ids_with_flag(region_id: String, flag: String) -> Array:
	var result: Array = []
	var region := _regions_by_id.get(region_id, {}) as Dictionary
	for trial: Dictionary in region.get("trials", []):
		if bool(trial.get(flag, false)):
			result.append(String(trial.get("id", "")))
	return result


func _validate_reachability(region: Dictionary, errors: PackedStringArray) -> void:
	var region_id := String(region.get("id", ""))
	var entry_id := String(region.get("entry_level_id", ""))
	var reachable: Dictionary = {entry_id: true}
	var changed := true
	while changed:
		changed = false
		for connection: Dictionary in region.get("connections", []):
			var from_id := String(connection.get("from", ""))
			var to_id := String(connection.get("to", ""))
			if reachable.has(from_id) and not reachable.has(to_id):
				reachable[to_id] = true
				changed = true
	for level: Dictionary in region.get("levels", []):
		var level_id := String(level.get("id", ""))
		if not bool(level.get("is_bonus", false)) and not reachable.has(level_id):
			errors.append("Required level %s in %s is unreachable" % [level_id, region_id])


func _validate_prerequisite_cycles(region: Dictionary, errors: PackedStringArray) -> void:
	var visiting: Dictionary = {}
	var visited: Dictionary = {}
	for level: Dictionary in region.get("levels", []):
		var level_id := String(level.get("id", ""))
		if _has_prerequisite_cycle(level_id, visiting, visited):
			errors.append("Region %s has a cyclic prerequisite graph" % String(region.get("id", "")))
			return


func _has_prerequisite_cycle(level_id: String, visiting: Dictionary, visited: Dictionary) -> bool:
	if visiting.has(level_id):
		return true
	if visited.has(level_id):
		return false
	visiting[level_id] = true
	var level := _levels_by_id.get(level_id, {}) as Dictionary
	for prerequisite: Variant in level.get("prerequisites", []):
		if _has_prerequisite_cycle(String(prerequisite), visiting, visited):
			return true
	visiting.erase(level_id)
	visited[level_id] = true
	return false
