extends Node

const SaveData := preload("res://scripts/SaveData.gd")

const SAVE_PATH := "user://campaign.cfg"
const SAVE_VERSION := 1

signal level_unlocked(level_id: String)
signal region_cleared(region_id: String)
signal region_unlocked(region_id: String)
signal region_mastered(region_id: String)

var save_path := SAVE_PATH
var loaded_version := SAVE_VERSION
var catalog: RefCounted

var unlocked_region_ids: Array = []
var unlocked_level_ids: Array = []
var completed_level_ids: Array = []
var level_records: Dictionary = {}
var trial_progress: Dictionary = {}
var cleared_region_ids: Array = []
var mastered_region_ids: Array = []
var last_selected_region_id := ""
var last_selected_level_id := ""


func configure(campaign_catalog: RefCounted, path: String = SAVE_PATH) -> void:
	catalog = campaign_catalog
	save_path = path


func load_data() -> void:
	_reset_state()
	var cfg: ConfigFile = SaveData.load_with_backup(save_path)
	var changed := cfg == null
	if cfg != null:
		loaded_version = SaveData.read_version(cfg, SAVE_VERSION, "campaign.cfg")
		unlocked_region_ids = SaveData.read_array(cfg, "campaign", "unlocked_regions")
		unlocked_level_ids = SaveData.read_array(cfg, "campaign", "unlocked_levels")
		completed_level_ids = SaveData.read_array(cfg, "campaign", "completed_levels")
		last_selected_region_id = SaveData.read_string(cfg, "campaign", "last_selected_region", "")
		last_selected_level_id = SaveData.read_string(cfg, "campaign", "last_selected_level", "")
		level_records = _read_dictionary(cfg, "records", "levels")
		trial_progress = _read_dictionary(cfg, "trials", "progress")
		cleared_region_ids = SaveData.read_array(cfg, "milestones", "cleared_regions")
		mastered_region_ids = SaveData.read_array(cfg, "milestones", "mastered_regions")
	changed = _normalize_state() or changed
	var refresh := _refresh_derived_state(false)
	changed = bool(refresh.changed) or changed
	if loaded_version < SAVE_VERSION or changed:
		save_data()


func save_data() -> bool:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", SAVE_VERSION)
	cfg.set_value("campaign", "unlocked_regions", unlocked_region_ids)
	cfg.set_value("campaign", "unlocked_levels", unlocked_level_ids)
	cfg.set_value("campaign", "completed_levels", completed_level_ids)
	cfg.set_value("campaign", "last_selected_region", last_selected_region_id)
	cfg.set_value("campaign", "last_selected_level", last_selected_level_id)
	cfg.set_value("records", "levels", level_records)
	cfg.set_value("trials", "progress", trial_progress)
	cfg.set_value("milestones", "cleared_regions", cleared_region_ids)
	cfg.set_value("milestones", "mastered_regions", mastered_region_ids)
	return SaveData.save_with_backup(cfg, save_path)


func is_region_released(region_id: String) -> bool:
	return catalog != null and bool(catalog.call("is_region_released", region_id))


func is_region_unlocked(region_id: String) -> bool:
	return is_region_released(region_id) and region_id in unlocked_region_ids


func is_level_unlocked(level_id: String) -> bool:
	return level_id in unlocked_level_ids


func is_level_completed(level_id: String) -> bool:
	return level_id in completed_level_ids


func can_play_level(level_id: String) -> bool:
	if catalog == null or not is_level_unlocked(level_id):
		return false
	return bool(catalog.call("is_level_playable", level_id))


func get_level_record(level_id: String) -> Dictionary:
	if not level_records.has(level_id):
		return {"has_record": false, "score": 0, "coins": 0}
	var record := level_records[level_id] as Dictionary
	return {
		"has_record": true,
		"score": int(record.get("score", 0)),
		"coins": int(record.get("coins", 0)),
	}


func record_level_completion(level_id: String, level_score: int, level_coins: int) -> Dictionary:
	var empty_result := _empty_update_result()
	if catalog == null:
		return empty_result
	var level := catalog.call("get_level", level_id) as Dictionary
	if level.is_empty() or not bool(catalog.call("is_level_playable", level_id)):
		return empty_result
	var region_id := String(level.get("region_id", ""))
	if not is_region_unlocked(region_id) or not is_level_unlocked(level_id):
		return empty_result

	var was_completed := level_id in completed_level_ids
	if not was_completed:
		completed_level_ids.append(level_id)
	var old_record := get_level_record(level_id)
	var is_new_record: bool = not bool(old_record.has_record) \
		or level_score > int(old_record.score) \
		or (level_score == int(old_record.score) and level_coins > int(old_record.coins))
	if is_new_record:
		level_records[level_id] = {"score": level_score, "coins": level_coins}

	var update := _refresh_derived_state(true)
	update["level_completed"] = not was_completed
	update["new_record"] = is_new_record
	update["record"] = get_level_record(level_id)
	save_data()
	return update


func add_region_trial_progress(trial_id: String, amount: int = 1) -> Dictionary:
	var empty_result := _empty_update_result()
	if catalog == null or amount <= 0:
		return empty_result
	var trial := catalog.call("get_trial", trial_id) as Dictionary
	if trial.is_empty():
		return empty_result
	var target := int(trial.get("target", 0))
	if target <= 0:
		return empty_result
	var old_value := int(trial_progress.get(trial_id, 0))
	var new_value := mini(old_value + amount, target)
	if new_value == old_value:
		return empty_result
	trial_progress[trial_id] = new_value
	var update := _refresh_derived_state(true)
	update["trial_completed"] = old_value < target and new_value >= target
	save_data()
	return update


func is_trial_completed(trial_id: String) -> bool:
	if catalog == null:
		return false
	var trial := catalog.call("get_trial", trial_id) as Dictionary
	return not trial.is_empty() \
		and int(trial_progress.get(trial_id, 0)) >= int(trial.get("target", 1))


func is_region_cleared(region_id: String) -> bool:
	if catalog == null:
		return false
	for level_id: String in catalog.call("get_main_level_ids", region_id):
		if level_id not in completed_level_ids:
			return false
	for trial_id: String in catalog.call("get_required_trial_ids", region_id):
		if not is_trial_completed(trial_id):
			return false
	return not (catalog.call("get_main_level_ids", region_id) as Array).is_empty()


func is_region_explored(region_id: String) -> bool:
	if catalog == null:
		return false
	var bonus_ids := catalog.call("get_bonus_level_ids", region_id) as Array
	for level_id: String in bonus_ids:
		if level_id not in completed_level_ids:
			return false
	# A region without bonus levels has nothing left to explore.
	return true


func is_region_mastered(region_id: String) -> bool:
	if not is_region_cleared(region_id) or not is_region_explored(region_id):
		return false
	for trial_id: String in catalog.call("get_mastery_trial_ids", region_id):
		if not is_trial_completed(trial_id):
			return false
	return true


func get_region_summary(region_id: String) -> Dictionary:
	if catalog == null:
		return {}
	var main_ids := catalog.call("get_main_level_ids", region_id) as Array
	var bonus_ids := catalog.call("get_bonus_level_ids", region_id) as Array
	var required_trials := catalog.call("get_required_trial_ids", region_id) as Array
	var mastery_trials := catalog.call("get_mastery_trial_ids", region_id) as Array
	return {
		"region_id": region_id,
		"released": is_region_released(region_id),
		"unlocked": is_region_unlocked(region_id),
		"main_completed": _count_completed(main_ids),
		"main_total": main_ids.size(),
		"bonus_completed": _count_completed(bonus_ids),
		"bonus_total": bonus_ids.size(),
		"core_trials_completed": _count_completed_trials(required_trials),
		"core_trials_total": required_trials.size(),
		"mastery_trials_completed": _count_completed_trials(mastery_trials),
		"mastery_trials_total": mastery_trials.size(),
		"cleared": is_region_cleared(region_id),
		"explored": is_region_explored(region_id),
		"mastered": is_region_mastered(region_id),
	}


func set_last_selection(region_id: String, level_id: String) -> void:
	var level := catalog.call("get_level", level_id) as Dictionary if catalog != null else {}
	if level.is_empty() or String(level.get("region_id", "")) != region_id:
		return
	last_selected_region_id = region_id
	last_selected_level_id = level_id
	save_data()


func get_unlocked_region_ids() -> Array:
	return unlocked_region_ids.duplicate()


func get_unlocked_level_ids() -> Array:
	return unlocked_level_ids.duplicate()


func get_completed_level_ids() -> Array:
	return completed_level_ids.duplicate()


func _reset_state() -> void:
	loaded_version = SAVE_VERSION
	unlocked_region_ids = []
	unlocked_level_ids = []
	completed_level_ids = []
	level_records = {}
	trial_progress = {}
	cleared_region_ids = []
	mastered_region_ids = []
	last_selected_region_id = ""
	last_selected_level_id = ""


func _normalize_state() -> bool:
	if catalog == null:
		return false
	var changed := false
	var region_ids := catalog.call("get_region_ids") as Array
	var released_region_ids: Array = []
	var released_level_ids: Array = []
	var level_ids: Array = []
	var trial_ids: Array = []
	for region_id: String in region_ids:
		if bool(catalog.call("is_region_released", region_id)):
			released_region_ids.append(region_id)
			released_level_ids.append_array(catalog.call("get_level_ids", region_id, true))
		level_ids.append_array(catalog.call("get_level_ids", region_id, true))
		for trial: Dictionary in (catalog.call("get_region", region_id) as Dictionary).get("trials", []):
			trial_ids.append(String(trial.get("id", "")))

	var normalized := _ordered_valid_ids(unlocked_region_ids, released_region_ids)
	changed = normalized != unlocked_region_ids or changed
	unlocked_region_ids = normalized
	normalized = _ordered_valid_ids(unlocked_level_ids, released_level_ids)
	changed = normalized != unlocked_level_ids or changed
	unlocked_level_ids = normalized
	normalized = _ordered_valid_ids(completed_level_ids, level_ids)
	changed = normalized != completed_level_ids or changed
	completed_level_ids = normalized
	normalized = _ordered_valid_ids(cleared_region_ids, region_ids)
	changed = normalized != cleared_region_ids or changed
	cleared_region_ids = normalized
	normalized = _ordered_valid_ids(mastered_region_ids, region_ids)
	changed = normalized != mastered_region_ids or changed
	mastered_region_ids = normalized

	var normalized_records: Dictionary = {}
	for level_id: String in level_ids:
		if not level_records.has(level_id) or level_id not in completed_level_ids:
			continue
		var raw: Variant = level_records[level_id]
		if not (raw is Dictionary):
			continue
		var record := raw as Dictionary
		normalized_records[level_id] = {
			"score": _coerce_record_int(record.get("score", 0)),
			"coins": _coerce_nonnegative_int(record.get("coins", 0)),
		}
	changed = normalized_records != level_records or changed
	level_records = normalized_records

	var normalized_trials: Dictionary = {}
	for trial_id: String in trial_ids:
		if not trial_progress.has(trial_id):
			continue
		var trial := catalog.call("get_trial", trial_id) as Dictionary
		var target := int(trial.get("target", 0))
		normalized_trials[trial_id] = clampi(_coerce_nonnegative_int(trial_progress[trial_id]), 0, target)
	changed = normalized_trials != trial_progress or changed
	trial_progress = normalized_trials

	if last_selected_region_id != "" and last_selected_region_id not in region_ids:
		last_selected_region_id = ""
		changed = true
	if last_selected_level_id != "" and last_selected_level_id not in level_ids:
		last_selected_level_id = ""
		changed = true
	elif last_selected_level_id != "":
		var selected := catalog.call("get_level", last_selected_level_id) as Dictionary
		if String(selected.get("region_id", "")) != last_selected_region_id:
			last_selected_level_id = ""
			changed = true
	return changed


func _refresh_derived_state(emit_events: bool) -> Dictionary:
	var before_regions := unlocked_region_ids.duplicate()
	var before_levels := unlocked_level_ids.duplicate()
	var before_cleared := cleared_region_ids.duplicate()
	var before_mastered := mastered_region_ids.duplicate()
	var region_ids := catalog.call("get_region_ids") as Array

	for region_id: String in region_ids:
		if bool(catalog.call("is_region_released", region_id)):
			if region_id not in unlocked_region_ids:
				unlocked_region_ids.append(region_id)
			break

	var changed_loop := true
	while changed_loop:
		changed_loop = false
		for region_id: String in unlocked_region_ids.duplicate():
			if not bool(catalog.call("is_region_released", region_id)):
				continue
			var region := catalog.call("get_region", region_id) as Dictionary
			var entry_id := String(region.get("entry_level_id", ""))
			if entry_id != "" and entry_id not in unlocked_level_ids:
				unlocked_level_ids.append(entry_id)
				changed_loop = true
		for level_id: String in completed_level_ids:
			for successor_id: String in catalog.call("get_successor_ids", level_id):
				var successor := catalog.call("get_level", successor_id) as Dictionary
				var successor_region := String(successor.get("region_id", ""))
				if successor_region in unlocked_region_ids \
						and bool(catalog.call("is_region_released", successor_region)) \
						and bool(catalog.call("prerequisites_met", successor_id, completed_level_ids)) \
						and successor_id not in unlocked_level_ids:
					unlocked_level_ids.append(successor_id)
					changed_loop = true
		for region_id: String in region_ids:
			if not is_region_cleared(region_id):
				continue
			if region_id not in cleared_region_ids:
				cleared_region_ids.append(region_id)
				changed_loop = true
			var region := catalog.call("get_region", region_id) as Dictionary
			var next_region_id := String(region.get("next_region_id", ""))
			if next_region_id != "" and bool(catalog.call("is_region_released", next_region_id)) \
					and next_region_id not in unlocked_region_ids:
				unlocked_region_ids.append(next_region_id)
				changed_loop = true
			if is_region_mastered(region_id) and region_id not in mastered_region_ids:
				mastered_region_ids.append(region_id)
				changed_loop = true

	_order_state_arrays()
	var new_regions := _array_difference(unlocked_region_ids, before_regions)
	var new_levels := _array_difference(unlocked_level_ids, before_levels)
	var new_cleared := _array_difference(cleared_region_ids, before_cleared)
	var new_mastered := _array_difference(mastered_region_ids, before_mastered)
	if emit_events:
		for level_id: String in new_levels:
			level_unlocked.emit(level_id)
		for region_id: String in new_cleared:
			region_cleared.emit(region_id)
		for region_id: String in new_regions:
			region_unlocked.emit(region_id)
		for region_id: String in new_mastered:
			region_mastered.emit(region_id)
	return {
		"changed": not new_regions.is_empty() or not new_levels.is_empty() \
			or not new_cleared.is_empty() or not new_mastered.is_empty(),
		"newly_unlocked_regions": new_regions,
		"newly_unlocked_levels": new_levels,
		"newly_cleared_regions": new_cleared,
		"newly_mastered_regions": new_mastered,
	}


func _order_state_arrays() -> void:
	var region_ids := catalog.call("get_region_ids") as Array
	var level_ids: Array = []
	for region_id: String in region_ids:
		level_ids.append_array(catalog.call("get_level_ids", region_id, true))
	unlocked_region_ids = _ordered_valid_ids(unlocked_region_ids, region_ids)
	unlocked_level_ids = _ordered_valid_ids(unlocked_level_ids, level_ids)
	completed_level_ids = _ordered_valid_ids(completed_level_ids, level_ids)
	cleared_region_ids = _ordered_valid_ids(cleared_region_ids, region_ids)
	mastered_region_ids = _ordered_valid_ids(mastered_region_ids, region_ids)


func _empty_update_result() -> Dictionary:
	return {
		"changed": false,
		"level_completed": false,
		"new_record": false,
		"trial_completed": false,
		"newly_unlocked_regions": [],
		"newly_unlocked_levels": [],
		"newly_cleared_regions": [],
		"newly_mastered_regions": [],
	}


func _read_dictionary(cfg: ConfigFile, section: String, key: String) -> Dictionary:
	var value: Variant = cfg.get_value(section, key, {})
	if value is Dictionary:
		return value
	push_warning("Save: %s/%s hat Typ %s statt Dictionary - leeres Dictionary" % [
		section, key, type_string(typeof(value))])
	return {}


func _ordered_valid_ids(values: Array, valid_ids: Array) -> Array:
	var requested: Dictionary = {}
	for value: Variant in values:
		if value is String or value is StringName:
			requested[String(value)] = true
	var result: Array = []
	for valid_id: String in valid_ids:
		if requested.has(valid_id):
			result.append(valid_id)
	return result


func _array_difference(values: Array, previous: Array) -> Array:
	var result: Array = []
	for value: Variant in values:
		if value not in previous:
			result.append(value)
	return result


func _count_completed(ids: Array) -> int:
	var count := 0
	for id: String in ids:
		if id in completed_level_ids:
			count += 1
	return count


func _count_completed_trials(ids: Array) -> int:
	var count := 0
	for id: String in ids:
		if is_trial_completed(id):
			count += 1
	return count


func _coerce_record_int(value: Variant) -> int:
	if value is int:
		return int(value)
	if value is float and is_finite(value):
		return int(value)
	return 0


func _coerce_nonnegative_int(value: Variant) -> int:
	return maxi(_coerce_record_int(value), 0)
