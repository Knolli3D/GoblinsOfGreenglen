extends SceneTree

# Kompletter Test-Runner: führt beide Suiten (Save-System + Smoke/Verhalten) als
# isolierte Kind-Prozesse aus und beweist per Canary-Hashes, dass die echten Saves
# unter user:// unverändert bleiben. DER eine dokumentierte Befehl:
#
#   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s res://tests/run_all.gd
#
# Exit-Code 0 = alle Suiten grün UND Canary unverändert; sonst 1.
#
# Isolation: jede Suite bekommt ihr eigenes Unterverzeichnis eines frischen Temp-
# Ordners als GOGG_TEST_SAVE_DIR (vererbt an den Kind-Prozess); auch der Runner-Prozess
# selbst läuft isoliert, da sein Progression-Autoload ebenfalls mitbootet. Die echten
# Save-Dateien werden ausschließlich lesend gehasht (Canary-Beweis). Bei Erfolg wird
# der Temp-Ordner entfernt; bei Fehlschlag bleibt er zur Analyse liegen.

const TestEnv := preload("res://tests/test_env.gd")
const SaveData := preload("res://scripts/SaveData.gd")

const SUITES := [
	"res://tests/test_save_system.gd",
	"res://tests/test_campaign_progress.gd",
	"res://tests/test_smoke.gd",
]
const CANARY_FILES := [
	"highscore.cfg", "highscore.cfg.bak",
	"progression.cfg", "progression.cfg.bak",
	"campaign.cfg", "campaign.cfg.bak",
]

var base_dir := ""

func _init() -> void:
	# VOR der Autoload-Registrierung: eigenes Isolations-Verzeichnis für diesen Prozess.
	base_dir = TestEnv.make_temp_dir("runner")
	var runner_dir := base_dir.path_join("runner")
	DirAccess.make_dir_recursive_absolute(runner_dir)
	OS.set_environment(SaveData.TEST_SAVE_DIR_ENV, runner_dir)
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _run() -> void:
	var real_dir := OS.get_user_data_dir()
	var canary_before := _canary_hashes(real_dir)
	var failed := false

	for suite: String in SUITES:
		var suite_dir := base_dir.path_join(suite.get_file().get_basename())
		DirAccess.make_dir_recursive_absolute(suite_dir)
		OS.set_environment(SaveData.TEST_SAVE_DIR_ENV, suite_dir)
		print("\n================  %s  ================" % suite)
		var output: Array = []
		var code := OS.execute(OS.get_executable_path(),
			["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", suite],
			output, true)
		for chunk: String in output:
			print(chunk.strip_edges(false, true))
		print("→ %s beendet mit Exit-Code %d" % [suite.get_file(), code])
		# Godot kann bei einem Script-Parsefehler trotzdem Exit 0 liefern. Der explizite
		# Erfolgsmarker verhindert, dass ein gar nicht gestarteter Test als grün gilt.
		var suite_output := "\n".join(output)
		if code != 0 or not suite_output.contains("ALLE TESTS OK ("):
			if code == 0:
				printerr("Suite lieferte keinen Erfolgsmarker (Parse-/Startfehler möglich)")
			failed = true

	var canary_after := _canary_hashes(real_dir)
	print("\n================  Canary (echte Saves)  ================")
	if canary_before == canary_after:
		print("Canary OK: %s unverändert in %s" % [", ".join(CANARY_FILES), real_dir])
	else:
		failed = true
		printerr("CANARY VERLETZT — echte Saves wurden verändert!")
		for fname: String in CANARY_FILES:
			if canary_before[fname] != canary_after[fname]:
				printerr("  %s: %s → %s" % [fname, canary_before[fname], canary_after[fname]])

	if failed:
		printerr("\nGESAMT: FEHLGESCHLAGEN (Testdaten in %s belassen)" % base_dir)
	else:
		TestEnv.remove_dir_recursive(base_dir)
		print("\nGESAMT: OK")
	quit(1 if failed else 0)

func _canary_hashes(dir: String) -> Dictionary:
	var result := {}
	for fname: String in CANARY_FILES:
		var path := dir.path_join(fname)
		result[fname] = FileAccess.get_md5(path) if FileAccess.file_exists(path) else "<fehlt>"
	return result
