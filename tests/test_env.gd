extends RefCounted

# Gemeinsame Isolations-Helfer für alle Test-Suiten (tests/*.gd).
#
# ensure_isolated() muss als erste Zeile in _init() einer Suite laufen — das ist VOR der
# Autoload-Registrierung (Autoloads starten im -s-Modus erst nach _init, vor dem ersten
# Frame). Ist GOGG_TEST_SAVE_DIR bereits gesetzt (der Runner run_all.gd setzt sie und
# vererbt sie an seine Kind-Prozesse), wird sie unverändert übernommen; sonst legt die
# Suite selbst ein frisches Verzeichnis unter dem System-Temp-Ordner an ("owned" = true,
# die Suite räumt es bei Erfolg wieder ab). Progression/Game leiten ihre Save-Pfade
# daraufhin um und die Save-Migration wird übersprungen (siehe SaveData.test_save_dir) —
# echte Saves unter user:// werden von keiner Suite gelesen oder geschrieben.

const SaveData := preload("res://scripts/SaveData.gd")

static func ensure_isolated(label: String) -> Dictionary:
	var dir := SaveData.test_save_dir()
	var owned := false
	if dir == "":
		dir = make_temp_dir(label)
		OS.set_environment(SaveData.TEST_SAVE_DIR_ENV, dir)
		owned = true
	DirAccess.make_dir_recursive_absolute(dir)
	return {"dir": dir, "owned": owned}

static func make_temp_dir(label: String) -> String:
	return OS.get_temp_dir().path_join("gogg_tests_%s_%d" % [label, OS.get_process_id()])

static func remove_dir_recursive(path: String) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	for f: String in d.get_files():
		d.remove(f)
	for sub: String in d.get_directories():
		remove_dir_recursive(path.path_join(sub))
	DirAccess.remove_absolute(path)
