extends Node

const SaveData := preload("res://scripts/SaveData.gd")

const SAVE_PATH := "user://highscore.cfg"
const SAVE_VERSION := 3

var save_path := SAVE_PATH
var best_final_score := 0
var best_time_ms := 0
var has_highscore := false
var has_best_time := false


func configure(path: String) -> void:
	save_path = path


func load_data(legacy_coin_final_score_value: int) -> void:
	best_final_score = 0
	best_time_ms = 0
	has_highscore = false
	has_best_time = false
	var cfg: ConfigFile = SaveData.load_with_backup(save_path)
	if cfg == null:
		return
	var loaded_version: int = SaveData.read_version(cfg, SAVE_VERSION, "highscore.cfg")
	if loaded_version < SAVE_VERSION:
		_load_legacy_data(cfg, legacy_coin_final_score_value)
	else:
		_load_current_data(cfg)


func _load_legacy_data(cfg: ConfigFile, coin_value: int) -> void:
	var raw_score: Variant = cfg.get_value("highscore", "score", null)
	if not (raw_score is int or raw_score is float):
		if raw_score != null:
			push_warning("Save: highscore/score hat Typ %s - kein Highscore geladen" % type_string(typeof(raw_score)))
		return
	var legacy_score := SaveData.read_int(cfg, "highscore", "score", 0)
	var legacy_coins := SaveData.read_int(cfg, "highscore", "coins", 0)
	best_final_score = maxi(0, legacy_score) + legacy_coins * maxi(0, coin_value)
	has_highscore = true
	# Legacy runs had no timer. The first positive timed completion establishes this record.
	best_time_ms = 0
	has_best_time = false
	save_data()


func _load_current_data(cfg: ConfigFile) -> void:
	var raw_score: Variant = cfg.get_value("highscore", "best_final_score", null)
	if raw_score is int or raw_score is float:
		best_final_score = SaveData.read_int(cfg, "highscore", "best_final_score", 0)
		has_highscore = true
	elif raw_score != null:
		push_warning("Save: highscore/best_final_score hat Typ %s - kein Highscore geladen" % type_string(typeof(raw_score)))

	var raw_has_time: Variant = cfg.get_value("highscore", "has_best_time", false)
	if raw_has_time is bool:
		has_best_time = bool(raw_has_time)
	else:
		push_warning("Save: highscore/has_best_time hat Typ %s statt bool - keine Bestzeit geladen" % type_string(typeof(raw_has_time)))
		has_best_time = false
	best_time_ms = SaveData.read_int(cfg, "highscore", "best_time_ms", 0)
	if has_best_time and best_time_ms <= 0:
		push_warning("Save: highscore/best_time_ms muss positiv sein - keine Bestzeit geladen")
		has_best_time = false
		best_time_ms = 0
	elif not has_best_time:
		best_time_ms = 0


func submit(final_score: int, elapsed_time_ms: int) -> Dictionary:
	var submitted_score := maxi(0, final_score)
	var is_new_highscore := not has_highscore or submitted_score > best_final_score
	var is_new_best_time := elapsed_time_ms > 0 \
		and (not has_best_time or elapsed_time_ms < best_time_ms)
	if is_new_highscore:
		best_final_score = submitted_score
		has_highscore = true
	if is_new_best_time:
		best_time_ms = elapsed_time_ms
		has_best_time = true
	if is_new_highscore or is_new_best_time:
		save_data()
	return {
		"new_highscore": is_new_highscore,
		"new_best_time": is_new_best_time,
	}


func save_data() -> bool:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", SAVE_VERSION)
	cfg.set_value("highscore", "best_final_score", best_final_score)
	cfg.set_value("highscore", "best_time_ms", best_time_ms)
	cfg.set_value("highscore", "has_best_time", has_best_time)
	return SaveData.save_with_backup(cfg, save_path)


func main_menu_text() -> String:
	if not has_highscore and not has_best_time:
		return "No highscore yet"
	var score_text := "Best Score: %d" % best_final_score \
		if has_highscore else "No best score yet"
	var time_text := "Best Time: %s" % _format_time_ms(best_time_ms) \
		if has_best_time else "No best time yet"
	return "%s\n%s" % [score_text, time_text]


func result_text() -> String:
	if not has_highscore and not has_best_time:
		return "No completed run yet"
	var score_text := "Best Score: %d" % best_final_score \
		if has_highscore else "No best score yet"
	var time_text := "Best Time: %s" % _format_time_ms(best_time_ms) \
		if has_best_time else "No best time yet"
	return "%s   %s" % [score_text, time_text]


func _format_time_ms(time_ms: int) -> String:
	var total_seconds := int(maxi(0, time_ms) / 1000)
	return "%d:%02d" % [int(total_seconds / 60), total_seconds % 60]
