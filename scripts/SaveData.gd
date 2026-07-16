extends RefCounted

# Gemeinsame Save-Helfer für highscore.cfg und progression.cfg:
# - getypte Reads mit Feld-Defaults — ein einzelnes kaputtes Feld resettet nie den
#   restlichen Save, es fällt nur selbst auf seinen Default zurück (mit push_warning).
# - Schema-Versionierung über [meta] version; fehlt die Sektion, gilt die Datei als
#   Version 1 (= unversioniertes Original-Schema, bleibt dauerhaft ladbar).
# - Backup-Strategie: vor jedem Überschreiben wird die bestehende Datei — sofern sie
#   noch als ConfigFile parst — nach <pfad>.bak kopiert. Ist der Haupt-Save beim Laden
#   unlesbar, wird das Backup geladen und der Haupt-Save daraus wiederhergestellt.
# - ConfigFile.save()-Rückgabewerte werden geprüft; Fehler nur als push_warning
#   (gleiche Philosophie wie SaveMigration.gd: der Spielstart wird nie blockiert).
#
# Verwendet von Game.gd (_load_highscore/_save_highscore) und Progression.gd (_load/_save).
# Die inhaltliche Normalisierung (Quest-Arrays, Skin-Inventar) bleibt bewusst bei den
# Besitzern der Definitionen (QUEST_POOL/WEEKLY_POOL/SKIN_TIERS in Progression.gd).

const UNVERSIONED := 1

# --- Test-Isolation ----------------------------------------------------------

# Nur für automatisierte Tests: Ist diese Umgebungsvariable gesetzt (vom Test-Runner
# bzw. den Test-Suiten in tests/, VOR der Autoload-Registrierung), leiten Progression
# und Game ihre Save-Pfade in dieses Verzeichnis um und die Save-Migration wird
# übersprungen — die echten Saves unter user:// werden dann weder gelesen noch
# geschrieben. Ohne die Variable ist das Produktionsverhalten exakt unverändert.
const TEST_SAVE_DIR_ENV := "GOGG_TEST_SAVE_DIR"

static func test_save_dir() -> String:
	return OS.get_environment(TEST_SAVE_DIR_ENV)

# --- Laden & Backup-Recovery -------------------------------------------------

# Lädt path; ist die Datei unlesbar/korrupt, wird <path>.bak versucht und bei Erfolg
# der Haupt-Save daraus repariert (Self-Healing). null = weder Save noch Backup
# lesbar — Aufrufer behält seine Defaults (frische Installation verhält sich genauso).
static func load_with_backup(path: String) -> ConfigFile:
	var cfg := ConfigFile.new()
	var err := cfg.load(path)
	if err == OK:
		return cfg
	if FileAccess.file_exists(path):
		push_warning("Save: '%s' unlesbar (Fehler %d) — versuche Backup" % [path, err])
	var bak_path := path + ".bak"
	var bak := ConfigFile.new()
	if bak.load(bak_path) != OK:
		if FileAccess.file_exists(bak_path):
			push_warning("Save: Backup '%s' ebenfalls unlesbar" % bak_path)
		return null
	push_warning("Save: '%s' aus Backup wiederhergestellt" % path)
	var copy_err := DirAccess.copy_absolute(bak_path, path)
	if copy_err != OK:
		push_warning("Save: Reparatur von '%s' aus Backup fehlgeschlagen (Fehler %d)" % [path, copy_err])
	return bak

# Sichert die bestehende (parsebare) Datei nach .bak und schreibt dann cfg.
# false = Schreiben fehlgeschlagen; der Zustand im Speicher bleibt gültig, der letzte
# gute Stand liegt weiterhin auf der Platte (Haupt-Save oder .bak).
static func save_with_backup(cfg: ConfigFile, path: String) -> bool:
	_backup_existing(path)
	var err := cfg.save(path)
	if err != OK:
		push_warning("Save: Schreiben von '%s' fehlgeschlagen (Fehler %d)" % [path, err])
		return false
	return true

static func _backup_existing(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var probe := ConfigFile.new()
	if probe.load(path) != OK:
		return  # kaputte Datei nicht als "letzter guter Stand" sichern
	var err := DirAccess.copy_absolute(path, path + ".bak")
	if err != OK:
		push_warning("Save: Backup von '%s' fehlgeschlagen (Fehler %d)" % [path, err])

# --- Versionierung -----------------------------------------------------------

# Liest [meta] version; fehlend/ungültig = UNVERSIONED (Original-Schema von vor der
# Versionierung). Neuere Versionen als `current` (Downgrade der Spielversion) werden
# gewarnt, aber best-effort weitergeladen — getypte Reads fangen Unbekanntes ab.
static func read_version(cfg: ConfigFile, current: int, label: String) -> int:
	var v: Variant = cfg.get_value("meta", "version", UNVERSIONED)
	if not (v is int) or int(v) < UNVERSIONED:
		push_warning("Save: %s hat ungültige Versionsangabe — als Version %d behandelt" % [label, UNVERSIONED])
		return UNVERSIONED
	if int(v) > current:
		push_warning("Save: %s hat Version %d, unterstützt ist %d — lade best-effort" % [label, v, current])
	return int(v)

# --- Getypte Reads -----------------------------------------------------------

static func read_int(cfg: ConfigFile, section: String, key: String, default: int, min_value: int = 0) -> int:
	return to_int(cfg.get_value(section, key, default), default, min_value, "%s/%s" % [section, key])

static func read_string(cfg: ConfigFile, section: String, key: String, default: String) -> String:
	var v: Variant = cfg.get_value(section, key, default)
	if v is String:
		return v
	if v is StringName:
		return String(v)
	push_warning("Save: %s/%s hat Typ %s statt String — Default \"%s\"" % [section, key, type_string(typeof(v)), default])
	return default

# Container-Check: Nicht-Arrays werden zu [] — die Element-Validierung übernimmt der
# Aufrufer (z.B. Progression._normalize_quest_block), da nur er die Semantik kennt.
static func read_array(cfg: ConfigFile, section: String, key: String) -> Array:
	var v: Variant = cfg.get_value(section, key, [])
	if v is Array:
		return v
	push_warning("Save: %s/%s hat Typ %s statt Array — leeres Array" % [section, key, type_string(typeof(v))])
	return []

# --- Element-Koercion (indexsichere Reads für parallele Quest-Arrays) ---------

static func to_int(v: Variant, default: int, min_value: int, label: String = "") -> int:
	if v is int:
		return maxi(int(v), min_value)
	if v is float and is_finite(v):
		return maxi(int(v), min_value)
	if label != "":
		push_warning("Save: %s hat Typ %s statt int — Default %d" % [label, type_string(typeof(v)), default])
	return maxi(default, min_value)

# Liest arr[idx] als int; fehlender Index oder falscher Typ ergibt den Default.
static func int_at(arr: Array, idx: int, default: int, min_value: int = 0) -> int:
	if idx < 0 or idx >= arr.size():
		return maxi(default, min_value)
	return to_int(arr[idx], default, min_value)

# Liest arr[idx] als bool; Zahlen werden als != 0 interpretiert, Rest ergibt den Default.
static func bool_at(arr: Array, idx: int, default: bool) -> bool:
	if idx < 0 or idx >= arr.size():
		return default
	var v: Variant = arr[idx]
	if v is bool:
		return v
	if v is int:
		return int(v) != 0
	return default
