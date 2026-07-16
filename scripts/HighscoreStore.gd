extends Node

const SaveData := preload("res://scripts/SaveData.gd")

const SAVE_PATH := "user://highscore.cfg"
const SAVE_VERSION := 2

var save_path := SAVE_PATH
var best_score := 0
var best_coins := 0
var has_highscore := false


func configure(path: String) -> void:
	save_path = path


func load_data() -> void:
	best_score = 0
	best_coins = 0
	has_highscore = false
	var cfg: ConfigFile = SaveData.load_with_backup(save_path)
	if cfg == null:
		return
	var loaded_version: int = SaveData.read_version(cfg, SAVE_VERSION, "highscore.cfg")
	var raw_score: Variant = cfg.get_value("highscore", "score", null)
	if not (raw_score is int or raw_score is float):
		if raw_score != null:
			push_warning("Save: highscore/score hat Typ %s - kein Highscore geladen" % type_string(typeof(raw_score)))
		return
	best_score = SaveData.read_int(cfg, "highscore", "score", 0)
	best_coins = SaveData.read_int(cfg, "highscore", "coins", 0)
	has_highscore = true
	if loaded_version < SAVE_VERSION:
		save_data()


func submit(run_score: int, run_coins: int) -> bool:
	var is_new := not has_highscore or run_score > best_score \
		or (run_score == best_score and run_coins > best_coins)
	if is_new:
		best_score = run_score
		best_coins = run_coins
		has_highscore = true
		save_data()
	return is_new


func save_data() -> bool:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", SAVE_VERSION)
	cfg.set_value("highscore", "score", best_score)
	cfg.set_value("highscore", "coins", best_coins)
	return SaveData.save_with_backup(cfg, save_path)


func main_menu_text() -> String:
	return "Best: Score %d   🪙 %d" % [best_score, best_coins] if has_highscore else "No highscore yet"


func result_text() -> String:
	return "Best Run   Score %d   Coins %d" % [best_score, best_coins] if has_highscore else "No completed run yet"
