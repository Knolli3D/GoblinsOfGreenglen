extends RefCounted

# Einmalige Save-Migration nach der Umbenennung "Cloude Game" → "Goblins of Greenglen".
# Godot leitet user:// aus config/name ab, alte Saves liegen daher im alten
# app_userdata-Ordner. Wird von Progression._ready() aufgerufen (Autoload → läuft vor
# Game.gd, also bevor irgendein Save geladen wird).
#
# Regeln:
# - Existiert der aktuelle Save, wird er NIE überschrieben (das macht die Migration
#   zugleich idempotent — kein separater Marker nötig).
# - Alte Dateien werden validiert, kopiert, das Ziel verifiziert; die Quelle bleibt
#   unangetastet (kein automatisches Löschen).
# - highscore.cfg und progression.cfg werden unabhängig migriert.
# - Fehler werden nur gemeldet (push_warning), der Spielstart wird nie blockiert.
#
# Plattformen: der alte Pfad wird aus OS.get_user_data_dir() abgeleitet (Geschwister-
# Ordner im selben app_userdata-Verzeichnis) — funktioniert auf macOS, Windows und
# Linux gleichermaßen. Existiert kein alter Ordner (frische Installation oder
# abweichendes Layout, z.B. custom user dir), passiert schlicht nichts.

const OLD_APP_NAME := "Cloude Game"
const SAVE_FILES := ["highscore.cfg", "progression.cfg"]

static func migrate_old_saves() -> void:
	var new_dir := OS.get_user_data_dir()
	var old_dir := new_dir.get_base_dir().path_join(OLD_APP_NAME)
	if old_dir == new_dir:
		return
	if not DirAccess.dir_exists_absolute(old_dir):
		return
	for fname: String in SAVE_FILES:
		_migrate_file(old_dir.path_join(fname), new_dir.path_join(fname), fname)

static func _migrate_file(src: String, dst: String, fname: String) -> void:
	if FileAccess.file_exists(dst):
		return  # aktueller Save hat Vorrang — nie überschreiben
	if not FileAccess.file_exists(src):
		return
	if not _is_valid_save(src, fname):
		push_warning("Save-Migration: alte Datei '%s' ist ungültig — übersprungen" % src)
		return
	var err := DirAccess.copy_absolute(src, dst)
	if err != OK:
		push_warning("Save-Migration: Kopieren von %s fehlgeschlagen (Fehler %d)" % [fname, err])
		return
	if not _is_valid_save(dst, fname):
		# Unbrauchbares Ziel entfernen, damit ein späterer Lauf es erneut versuchen kann.
		DirAccess.remove_absolute(dst)
		push_warning("Save-Migration: Ziel-Verifikation für %s fehlgeschlagen" % fname)
		return
	print("Save-Migration: %s aus '%s' übernommen" % [fname, OLD_APP_NAME])

# Minimal-Validierung: Datei muss als ConfigFile parsen und die Kernfelder müssen die
# erwarteten Typen haben. Fehlende optionale Felder sind ok — die Load-Funktionen in
# Game.gd/Progression.gd defaulten sie ohnehin.
static func _is_valid_save(path: String, fname: String) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return false
	if fname == "highscore.cfg":
		var score: Variant = cfg.get_value("highscore", "score", null)
		var coins: Variant = cfg.get_value("highscore", "coins", null)
		return score is int and coins is int
	var keys: Variant = cfg.get_value("currency", "keys", 0)
	var owned: Variant = cfg.get_value("inventory", "owned_skins", [])
	var equipped: Variant = cfg.get_value("inventory", "equipped_skin", "")
	return keys is int and owned is Array and equipped is String
