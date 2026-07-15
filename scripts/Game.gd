extends Node2D

const VIEW := Vector2(960, 540)
const MAX_HEALTH := 3

const LEVELS := [
	"res://scenes/Level1.tscn",
	"res://scenes/Level2.tscn",
	"res://scenes/Level3.tscn",
	"res://scenes/Level4.tscn",
	"res://scenes/Level5.tscn",
	"res://scenes/Level6.tscn",
]

const SFX_FILES := {
	"jump": "res://assets/audio/jump.wav",
	"double_jump": "res://assets/audio/double_jump.wav",
	"coin": "res://assets/audio/coin.wav",
	"stomp": "res://assets/audio/stomp.wav",
	"hit": "res://assets/audio/hit.wav",
	"death": "res://assets/audio/death.wav",
	"level_clear": "res://assets/audio/level_clear.wav",
	"win": "res://assets/audio/win.wav",
	"click": "res://assets/audio/click.wav",
}
const MUSIC_FILE := "res://assets/audio/music.wav"
const SFX_VOICES := 8
const SAVE_PATH := "user://highscore.cfg"

# music_player.volume_db ist der Player-Pegel und addiert sich auf den Music-Bus
# (-6 dB in default_bus_layout.tres). Diese Werte sind also KEIN Gesamtausgang:
#   normal  = 0 dB Player  + (-6 dB Bus) = -6 dB gesamt
#   ducked  = -14 dB Player + (-6 dB Bus) = -20 dB gesamt (Ducking im Pause-Menü)
const MUSIC_NORMAL_DB := 0.0
const MUSIC_PAUSED_DB := -14.0

var current_level := 0
var health := MAX_HEALTH
var score := 0
var coin_count := 0
var transitioning := false
# Generation-Token für Level-Übergänge: jeder Level-Load und jede Rückkehr ins Hauptmenü
# erhöht es. Die reach_goal()-Coroutine validiert nach ihrem await dagegen, damit ein
# veralteter Übergang (Restart/Menü während "Level Cleared!") keinen Level mehr lädt.
var transition_gen := 0
var invuln_until := 0.0
var hud_label: Label
var coin_label: Label
var win_label: Label
var pause_menu: Control
var level_root: Node2D
var player: CharacterBody2D
var main_menu: Control
var in_main_menu: bool = true
var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var sfx_streams := {}
var sfx_next := 0
var best_score := 0
var best_coins := 0
var has_highscore := false
var highscore_label: Label
var took_damage_this_level := false
var took_damage_this_run := false
var keys_label: Label
var quests_menu: Control
var quests_list: VBoxContainer
var cases_menu: Control
var cases_keys_label: Label
var open_case_btn: Button
var premium_case_btn: Button
var cases_stats_label: Label
var cases_back_btn: Button
var reel_frame: Control
var reel_strip: Control
var is_spinning := false
var reel_last_tick_idx := 0

const CARD_W := 100.0
const CARD_COUNT := 40
const WIN_INDEX := 34
var skins_menu: Control
var skins_list: VBoxContainer
var skins_preview_sprite: TextureRect
var skins_preview_name: Label
var skins_preview_tier: Label
var skins_preview_equipped: Label
var skins_equip_btn: Button
var selected_skin_id := ""

# Greenglen-UI-Theme (Button-Texturen + Cinzel-Typografie), einmal in _ready() gebaut.
var ui_theme: Theme
var ui_heading_font: Font

# Greenglen-Buttons (Nine-Patch): dekorierte Metall-Enden fix, Holz-Mitte streckt.
const BTN_TEX := {
	"normal": "res://assets/ui/buttons/button_greenglen_normal.png",
	"hover": "res://assets/ui/buttons/button_greenglen_hover.png",
	"pressed": "res://assets/ui/buttons/button_greenglen_pressed.png",
	"disabled": "res://assets/ui/buttons/button_greenglen_disabled.png",
}
const UI_CREAM := Color("#FFF1C4")
const UI_BROWN := Color("#351D0E")

const TIER_COLORS := {
	"common": Color(0.55, 0.85, 0.55),
	"rare": Color(0.4, 0.6, 1.0),
	"epic": Color(0.8, 0.45, 0.95),
	"legendary": Color(1.0, 0.65, 0.15),
	"starter": Color(0.55, 0.8, 0.85),
	"default": Color(0.85, 0.85, 0.85),
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("game")
	_load_highscore()
	_build_ui_theme()
	_build_audio()
	_build_hud()
	_build_pause_menu()
	_build_main_menu()
	_build_quests_menu()
	_build_cases_menu()
	_build_skins_menu()
	_show_main_menu()

func _build_audio() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	if ResourceLoader.exists(MUSIC_FILE):
		var music: AudioStreamWAV = load(MUSIC_FILE)
		music.loop_mode = AudioStreamWAV.LOOP_FORWARD
		music.loop_begin = 0
		# loop_end in Frames — aus Länge berechnen (Import kann QOA-komprimieren)
		music.loop_end = int(music.get_length() * music.mix_rate)
		music_player.stream = music
	add_child(music_player)

	for i in range(SFX_VOICES):
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		sfx_players.append(p)

	for key: String in SFX_FILES:
		if ResourceLoader.exists(SFX_FILES[key]):
			sfx_streams[key] = load(SFX_FILES[key])

func play_sfx(sfx_name: String, pitch_jitter := 0.0) -> void:
	var stream: AudioStream = sfx_streams.get(sfx_name)
	if stream == null:
		return
	var p := sfx_players[sfx_next]
	sfx_next = (sfx_next + 1) % sfx_players.size()
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.stream = stream
	p.play()

# Ein wiederverwendbares Theme für alle Buttons (Greenglen-Texturen + Cinzel SemiBold).
# Wird auf die Menü-Root-Controls gesetzt und vererbt sich auf alle Button-Kinder.
func _build_ui_theme() -> void:
	var font_semibold: Font = load("res://Cinzel/static/Cinzel-SemiBold.ttf")
	ui_heading_font = load("res://Cinzel/static/Cinzel-Bold.ttf")
	# Emoji/Sonderzeichen (🔑 🪙 ▶ ★) fehlen in Cinzel → Default-Font als Fallback anhängen.
	if font_semibold is FontFile:
		(font_semibold as FontFile).fallbacks = [ThemeDB.fallback_font]
	if ui_heading_font is FontFile:
		(ui_heading_font as FontFile).fallbacks = [ThemeDB.fallback_font]

	var t := Theme.new()
	t.set_stylebox("normal", "Button", _make_button_style("normal"))
	t.set_stylebox("hover", "Button", _make_button_style("hover"))
	t.set_stylebox("pressed", "Button", _make_button_style("pressed"))
	t.set_stylebox("disabled", "Button", _make_button_style("disabled"))
	# Kein Godot-Standard-Fokusrahmen — Hover-Textur zeigt die aktive Auswahl.
	t.set_stylebox("focus", "Button", _make_button_style("hover"))

	t.set_font("font", "Button", font_semibold)
	t.set_font_size("font_size", "Button", 18)
	t.set_color("font_color", "Button", UI_CREAM)
	t.set_color("font_hover_color", "Button", Color("#FFFBEA"))
	t.set_color("font_pressed_color", "Button", Color("#FFE7A0"))
	t.set_color("font_focus_color", "Button", UI_CREAM)
	t.set_color("font_hover_pressed_color", "Button", Color("#FFE7A0"))
	t.set_color("font_disabled_color", "Button", Color(0.72, 0.66, 0.5))
	t.set_color("font_outline_color", "Button", UI_BROWN)
	t.set_constant("outline_size", "Button", 3)
	ui_theme = t

func _make_button_style(state: String) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(BTN_TEX[state])
	# Nine-Patch (Quelle 900×150): dekorierte Metall-Enden bleiben fix, Holz-Mitte streckt.
	# Die vertikalen Ränder müssen klein bleiben — die Buttons sind nur 32–48px hoch, und
	# top+bottom dürfen die Button-Höhe nicht erreichen, sonst kollabiert die Holz-Mitte
	# (das war der Bug: 30+30=60px > Button-Höhe → kein sichtbares Holz).
	sb.texture_margin_left = 85
	sb.texture_margin_right = 85
	sb.texture_margin_top = 10
	sb.texture_margin_bottom = 10
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	# Content-Margins: Text bleibt rechts der Metall-Gems/Vines, mittig auf dem Holz.
	sb.content_margin_left = 64
	sb.content_margin_right = 64
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb

# Cinzel-Bold-Titelstil für Menü-Überschriften.
func _apply_heading_style(label: Label, size: int) -> void:
	label.add_theme_font_override("font", ui_heading_font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", UI_CREAM)
	label.add_theme_color_override("font_outline_color", UI_BROWN)
	label.add_theme_constant_override("outline_size", 5)

# Einziger Ort, an dem der Musik-Pegel gesetzt wird — hält Pause/Resume/Menü/Neustart konsistent.
func _set_music_ducked(ducked: bool) -> void:
	music_player.volume_db = MUSIC_PAUSED_DB if ducked else MUSIC_NORMAL_DB

func _load_highscore() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	has_highscore = true
	best_score = cfg.get_value("highscore", "score", 0)
	best_coins = cfg.get_value("highscore", "coins", 0)

func _save_highscore() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("highscore", "score", best_score)
	cfg.set_value("highscore", "coins", best_coins)
	cfg.save(SAVE_PATH)

# true wenn der aktuelle Run ein neuer Highscore ist (und dann gespeichert wurde)
func _submit_run(run_score: int, run_coins: int) -> bool:
	var is_new := not has_highscore or run_score > best_score \
		or (run_score == best_score and run_coins > best_coins)
	if is_new:
		best_score = run_score
		best_coins = run_coins
		has_highscore = true
		_save_highscore()
	return is_new

func _build_pause_menu() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	pause_menu = Control.new()
	pause_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_menu.theme = ui_theme
	pause_menu.visible = false
	layer.add_child(pause_menu)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_menu.add_child(dim)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.position = Vector2(VIEW.x * 0.5 - 110, VIEW.y * 0.5 - 110)
	box.custom_minimum_size = Vector2(220, 0)
	pause_menu.add_child(box)

	var title := Label.new()
	title.text = "Paused"
	_apply_heading_style(title, 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(title)

	var resume_btn := Button.new()
	resume_btn.text = "Resume"
	resume_btn.custom_minimum_size = Vector2(220, 40)
	resume_btn.pressed.connect(_toggle_pause)
	box.add_child(resume_btn)

	var restart_btn := Button.new()
	restart_btn.text = "Try Again"
	restart_btn.custom_minimum_size = Vector2(220, 40)
	restart_btn.pressed.connect(_restart_level_from_menu)
	box.add_child(restart_btn)

	var exit_btn := Button.new()
	exit_btn.text = "Exit to Menu"
	exit_btn.custom_minimum_size = Vector2(220, 40)
	exit_btn.pressed.connect(_exit_to_main_menu)
	box.add_child(exit_btn)

func _build_main_menu() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 9
	add_child(layer)
	main_menu = Control.new()
	main_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	main_menu.theme = ui_theme
	layer.add_child(main_menu)

	var bg := TextureRect.new()
	bg.texture = load("res://assets/menubackground.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_menu.add_child(bg)

	# leichte Abdunklung, damit Titel/Buttons vor dem hellen Himmel lesbar bleiben
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.06, 0.1, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_menu.add_child(dim)

	# Box über die volle Breite, damit Logo/Buttons echt zentriert sind (ein breites
	# Kind würde sonst die Box-Breite aufblähen und alles aus der Mitte schieben).
	# Startet weiter oben als früher, damit das Logo (180px) samt Buttons in 540px passt.
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.position = Vector2(0, 40)
	box.custom_minimum_size = Vector2(VIEW.x, 0)
	main_menu.add_child(box)

	# Titel-Logo statt Text-Label
	var logo := TextureRect.new()
	logo.texture = load("res://assets/LOGO_menu_GoGg.png")
	logo.custom_minimum_size = Vector2(0, 180)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(logo)

	highscore_label = Label.new()
	highscore_label.add_theme_font_size_override("font_size", 18)
	highscore_label.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	highscore_label.add_theme_color_override("font_outline_color", Color.BLACK)
	highscore_label.add_theme_constant_override("outline_size", 4)
	highscore_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	highscore_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(highscore_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	box.add_child(spacer)

	var start_btn := Button.new()
	start_btn.text = "Start Game"
	start_btn.custom_minimum_size = Vector2(260, 48)
	start_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start_btn.pressed.connect(_start_game)
	box.add_child(start_btn)

	var quests_btn := Button.new()
	quests_btn.text = "Quests"
	quests_btn.custom_minimum_size = Vector2(260, 40)
	quests_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	quests_btn.pressed.connect(_show_quests_menu)
	box.add_child(quests_btn)

	var cases_btn := Button.new()
	cases_btn.text = "Cases"
	cases_btn.custom_minimum_size = Vector2(260, 40)
	cases_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cases_btn.pressed.connect(_show_cases_menu)
	box.add_child(cases_btn)

	var skins_btn := Button.new()
	skins_btn.text = "Skins"
	skins_btn.custom_minimum_size = Vector2(260, 40)
	skins_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	skins_btn.pressed.connect(_show_skins_menu)
	box.add_child(skins_btn)

	var quit_btn := Button.new()
	quit_btn.text = "Quit Game"
	quit_btn.custom_minimum_size = Vector2(140, 40)
	quit_btn.add_theme_font_size_override("font_size", 15)
	quit_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	# Breiter als die 140px-Mindestgröße (offset-getrieben), damit "Quit Game" samt
	# dekorierter Metall-Enden vollständig ins Bild passt.
	quit_btn.offset_left = -226
	quit_btn.offset_top = -58
	quit_btn.offset_right = -16
	quit_btn.offset_bottom = -16
	quit_btn.pressed.connect(_quit_game)
	main_menu.add_child(quit_btn)

func _show_main_menu() -> void:
	transition_gen += 1  # macht jede noch wartende reach_goal()-Coroutine ungültig
	transitioning = false
	invuln_until = 0.0  # Gameplay-Zustand räumen — kein Schutzfenster überlebt das Menü
	in_main_menu = true
	get_tree().paused = false
	pause_menu.visible = false
	hud_label.visible = false
	coin_label.visible = false
	keys_label.visible = false
	win_label.visible = false
	if level_root:
		level_root.queue_free()
		level_root = null
	highscore_label.text = "Best: Score %d   🪙 %d" % [best_score, best_coins] if has_highscore else "No highscore yet"
	main_menu.visible = true
	quests_menu.visible = false
	cases_menu.visible = false
	skins_menu.visible = false
	music_player.stop()
	# Ducking zurücknehmen — sonst startet die nächste Runde mit gedämpfter Musik
	# (z.B. nach "Exit to Menu" aus dem Pause-Menü).
	_set_music_ducked(false)

func _start_game() -> void:
	play_sfx("click")
	in_main_menu = false
	main_menu.visible = false
	hud_label.visible = true
	coin_label.visible = true
	keys_label.visible = true
	score = 0
	coin_count = 0
	took_damage_this_run = false
	_set_music_ducked(false)
	music_player.play()
	_load_level(0)

func _quit_game() -> void:
	get_tree().quit()

func _exit_to_main_menu() -> void:
	play_sfx("click")
	_show_main_menu()

func _toggle_pause() -> void:
	play_sfx("click")
	var paused := not get_tree().paused
	get_tree().paused = paused
	pause_menu.visible = paused
	_set_music_ducked(paused)

func _restart_level_from_menu() -> void:
	play_sfx("click")
	get_tree().paused = false
	pause_menu.visible = false
	_set_music_ducked(false)
	score = 0
	coin_count = 0
	took_damage_this_run = false
	if not music_player.playing:
		music_player.play()
	_load_level(0)

func _build_submenu_shell(layer_index: int, title_text: String, bg_path: String) -> Dictionary:
	var layer := CanvasLayer.new()
	layer.layer = layer_index
	add_child(layer)
	var menu := Control.new()
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.process_mode = Node.PROCESS_MODE_ALWAYS
	menu.theme = ui_theme
	menu.visible = false
	layer.add_child(menu)

	var bg := TextureRect.new()
	bg.texture = load(bg_path)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(bg)

	# leichte Abdunklung, damit Titel/Buttons vor dem Bild lesbar bleiben
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.06, 0.1, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(dim)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.position = Vector2(VIEW.x * 0.5 - 150, 60)
	box.custom_minimum_size = Vector2(300, 0)
	menu.add_child(box)

	var title := Label.new()
	title.text = title_text
	_apply_heading_style(title, 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(title)

	return {"menu": menu, "box": box}

func _build_quests_menu() -> void:
	var shell := _build_submenu_shell(11, "Daily Quests", "res://assets/menu_bg_quests.png")
	quests_menu = shell.menu
	quests_list = VBoxContainer.new()
	quests_list.add_theme_constant_override("separation", 10)
	shell.box.add_child(quests_list)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(300, 40)
	back_btn.pressed.connect(_hide_submenus)
	shell.box.add_child(back_btn)

func _show_quests_menu() -> void:
	play_sfx("click")
	Progression.check_daily_reset()
	Progression.check_weekly_reset()
	main_menu.visible = false
	quests_menu.visible = true
	_refresh_quests_menu()

func _add_quest_section_header(text: String) -> void:
	var header := Label.new()
	header.text = text
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", Color(1, 0.95, 0.6))
	quests_list.add_child(header)

func _add_quest_row(quest: Dictionary, claim_text: String, claim_handler: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	quests_list.add_child(row)

	var lbl := Label.new()
	lbl.text = "%s (%d/%d)" % [quest.desc, quest.progress, quest.target]
	lbl.custom_minimum_size = Vector2(230, 0)
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	row.add_child(lbl)

	var claim_btn := Button.new()
	claim_btn.custom_minimum_size = Vector2(100, 32)
	if quest.claimed:
		claim_btn.text = "Claimed"
		claim_btn.disabled = true
	else:
		claim_btn.text = claim_text
		if quest.completed:
			claim_btn.pressed.connect(claim_handler.bind(quest.slot))
		else:
			claim_btn.disabled = true
	row.add_child(claim_btn)

func _refresh_quests_menu() -> void:
	for child in quests_list.get_children():
		child.queue_free()

	_add_quest_section_header("Daily")

	var reward_line := Label.new()
	var bonus_mode: bool = Progression.daily_claims_today >= Progression.DAILY_FULL_KEY_CLAIMS
	var reward_text := "Bonus quests: 1/3 🔑 each" if bonus_mode else "1 🔑 per quest"
	if Progression.get_fragments() > 0:
		reward_text += "   Fragments: %d/%d" % [Progression.get_fragments(), Progression.FRAGMENTS_PER_KEY]
	reward_line.text = reward_text
	reward_line.add_theme_font_size_override("font_size", 13)
	reward_line.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	quests_list.add_child(reward_line)

	for quest: Dictionary in Progression.get_active_quests():
		_add_quest_row(quest, "Claim", _on_claim_quest)

	_add_quest_section_header("Weekly")
	for quest: Dictionary in Progression.get_weekly_quests():
		_add_quest_row(quest, "Claim %d🔑" % Progression.WEEKLY_REWARD, _on_claim_weekly)

func _on_claim_quest(slot: int) -> void:
	if Progression.claim_quest(slot):
		play_sfx("click")
		_refresh_quests_menu()
		_update_hud()

func _on_claim_weekly(slot: int) -> void:
	if Progression.claim_weekly(slot):
		play_sfx("click")
		_refresh_quests_menu()
		_update_hud()

func _build_cases_menu() -> void:
	var shell := _build_submenu_shell(12, "Cases", "res://assets/menu_bg_cases.png")
	cases_menu = shell.menu

	cases_keys_label = Label.new()
	cases_keys_label.add_theme_font_size_override("font_size", 20)
	cases_keys_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	cases_keys_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cases_keys_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.box.add_child(cases_keys_label)

	open_case_btn = Button.new()
	open_case_btn.text = "Open Case (1 🔑)"
	open_case_btn.custom_minimum_size = Vector2(300, 44)
	open_case_btn.add_theme_font_size_override("font_size", 16)
	open_case_btn.pressed.connect(_on_open_case_pressed.bind(false))
	shell.box.add_child(open_case_btn)

	premium_case_btn = Button.new()
	premium_case_btn.text = "Premium Case (3 🔑) — Rare+"
	premium_case_btn.custom_minimum_size = Vector2(300, 44)
	# Langes Label: kleinere Schrift, damit es zwischen die Metall-Enden passt.
	premium_case_btn.add_theme_font_size_override("font_size", 13)
	shell.box.add_child(premium_case_btn)
	premium_case_btn.pressed.connect(_on_open_case_pressed.bind(true))

	cases_stats_label = Label.new()
	cases_stats_label.add_theme_font_size_override("font_size", 14)
	cases_stats_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	cases_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cases_stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.box.add_child(cases_stats_label)

	cases_back_btn = Button.new()
	cases_back_btn.text = "Back"
	cases_back_btn.custom_minimum_size = Vector2(300, 40)
	cases_back_btn.pressed.connect(_hide_submenus)
	shell.box.add_child(cases_back_btn)

	_build_case_reel()

func _build_case_reel() -> void:
	reel_frame = Control.new()
	reel_frame.position = Vector2(VIEW.x * 0.5 - 335, 380)
	reel_frame.custom_minimum_size = Vector2(670, 120)
	reel_frame.visible = false
	cases_menu.add_child(reel_frame)

	var frame_bg := ColorRect.new()
	frame_bg.color = Color(0.06, 0.07, 0.1, 0.9)
	frame_bg.size = Vector2(670, 120)
	reel_frame.add_child(frame_bg)

	var clip := Control.new()
	clip.position = Vector2(5, 10)
	clip.size = Vector2(660, 100)
	clip.clip_contents = true
	reel_frame.add_child(clip)

	reel_strip = Control.new()
	reel_strip.size = Vector2(CARD_W * CARD_COUNT, 100)
	clip.add_child(reel_strip)

	var marker := ColorRect.new()
	marker.color = Color(1.0, 0.85, 0.2)
	marker.position = Vector2(334, 0)
	marker.size = Vector2(2, 120)
	reel_frame.add_child(marker)

func _all_skins_flat() -> Array:
	var result: Array = []
	for tier: String in Progression.SKIN_TIERS:
		for skin: Dictionary in Progression.SKIN_TIERS[tier].skins:
			var entry: Dictionary = skin.duplicate()
			entry["tier"] = tier
			result.append(entry)
	return result

func _make_reel_card(skin: Dictionary, idx: int) -> Control:
	var card := Control.new()
	card.position = Vector2(idx * CARD_W, 0)
	card.size = Vector2(CARD_W, 100)

	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.13, 0.18)
	bg.position = Vector2(2, 2)
	bg.size = Vector2(96, 96)
	card.add_child(bg)

	var art := TextureRect.new()
	art.position = Vector2(15, 4)
	art.size = Vector2(70, 84)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var texture_path: String = skin.get("texture", "")
	if texture_path != "" and ResourceLoader.exists(texture_path):
		art.texture = load(texture_path)
		art.modulate = Color.WHITE
	else:
		art.texture = load("res://assets/sprite_knight.png")
		art.modulate = skin.get("color", Color.WHITE)
	card.add_child(art)

	var stripe := ColorRect.new()
	stripe.color = TIER_COLORS.get(skin.tier, Color.WHITE)
	stripe.position = Vector2(2, 92)
	stripe.size = Vector2(96, 6)
	card.add_child(stripe)
	return card

func _show_cases_menu() -> void:
	play_sfx("click")
	main_menu.visible = false
	cases_menu.visible = true
	_refresh_cases_menu()

func _refresh_cases_menu() -> void:
	var k: int = Progression.get_keys()
	cases_keys_label.text = "🔑 %d    Shards: %d/%d" % [k, Progression.get_shards(), Progression.SHARDS_PER_KEY]
	open_case_btn.disabled = k < 1 or is_spinning
	premium_case_btn.disabled = k < Progression.PREMIUM_CASE_COST or is_spinning
	cases_back_btn.disabled = is_spinning
	var best: String = Progression.get_best_pull()
	var best_text := "—" if best == "" else best.capitalize()
	cases_stats_label.text = "Collection: %d/%d    Cases opened: %d    Best pull: %s" % [
		Progression.owned_skins.size(), Progression.get_total_skin_count(),
		Progression.get_cases_opened(), best_text,
	]

func _on_open_case_pressed(premium: bool) -> void:
	if is_spinning:
		return
	var skin := Progression.open_case(premium)
	if skin.is_empty():
		return
	_start_case_spin(skin)

func _start_case_spin(result: Dictionary) -> void:
	is_spinning = true
	play_sfx("coin", 0.05)
	open_case_btn.disabled = true
	premium_case_btn.disabled = true
	cases_back_btn.disabled = true

	for child in reel_strip.get_children():
		child.queue_free()
	var pool := _all_skins_flat()
	for i in range(CARD_COUNT):
		var card_skin: Dictionary = result if i == WIN_INDEX else pool[randi() % pool.size()]
		reel_strip.add_child(_make_reel_card(card_skin, i))

	reel_frame.visible = true
	reel_strip.position.x = 330.0 - CARD_W * 0.5
	reel_last_tick_idx = 0

	var target_x: float = 330.0 - (float(WIN_INDEX) * CARD_W + CARD_W * 0.5) + randf_range(-30.0, 30.0)
	var tw := create_tween()
	tw.tween_property(reel_strip, "position:x", target_x, 2.8) \
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.3)
	tw.tween_callback(_on_reel_finished.bind(result))

func _process(_delta: float) -> void:
	if not is_spinning or reel_strip == null:
		return
	var idx := int((330.0 - reel_strip.position.x) / CARD_W)
	if idx != reel_last_tick_idx:
		reel_last_tick_idx = idx
		play_sfx("click", 0.1)

func _on_reel_finished(result: Dictionary) -> void:
	is_spinning = false
	_spawn_skin_reveal(result)
	_refresh_cases_menu()

func _spawn_skin_reveal(skin: Dictionary) -> void:
	var lyr := CanvasLayer.new()
	lyr.layer = 21
	add_child(lyr)

	var tier: String = skin.get("tier", "common")
	var is_dup: bool = skin.get("duplicate", false)

	# Rarity-Flash hinter dem Label — Flair skaliert mit Seltenheit.
	var big_tier: bool = tier == "epic" or tier == "legendary"
	if tier == "rare" or big_tier:
		var flash := ColorRect.new()
		var flash_color: Color = TIER_COLORS.get(tier, Color.WHITE)
		var flash_alpha := 0.35
		var flash_dur := 0.5
		if tier == "epic":
			flash_alpha = 0.55
			flash_dur = 0.8
		elif tier == "legendary":
			flash_alpha = 0.65
			flash_dur = 0.9
		flash_color.a = flash_alpha
		flash.color = flash_color
		flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		lyr.add_child(flash)
		var flash_tw := create_tween()
		flash_tw.tween_property(flash, "color:a", 0.0, flash_dur).set_ease(Tween.EASE_OUT)
		play_sfx("level_clear" if tier == "rare" else "win")

	# Screen-Shake am Reel-Rahmen (Epic + Legendary)
	if big_tier and reel_frame != null:
		var base: Vector2 = reel_frame.position
		var shake_tw := create_tween()
		var amp := 8.0
		for i in range(6):
			var offset := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * amp
			shake_tw.tween_property(reel_frame, "position", base + offset, 0.04)
			amp = maxf(amp - 1.2, 2.0)
		shake_tw.tween_property(reel_frame, "position", base, 0.04)

	var lbl := Label.new()
	var text := "%s — Duplicate (+1 Shard)" % skin.name if is_dup else "New Skin: %s!" % skin.name
	if skin.get("key_from_shards", false):
		text += "\n+1 Key from Shards!"
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(VIEW.x * 0.5 - 180, VIEW.y * 0.5 - 20)
	lbl.custom_minimum_size = Vector2(360, 0)
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.add_theme_color_override("font_color", skin.color)
	lbl.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.12))
	lbl.add_theme_constant_override("outline_size", 8)
	lbl.scale = Vector2(0.6, 0.6)
	lyr.add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "scale", Vector2(1.2, 1.2), 0.3).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "position:y", lbl.position.y - 40, 0.3).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.9)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.3)
	tw.tween_callback(lyr.queue_free)

func _build_skins_menu() -> void:
	var shell := _build_submenu_shell(13, "Skins", "res://assets/menu_bg_skins.png")
	skins_menu = shell.menu

	# Linke Spalte: scrollbare Skin-Liste
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(80, 120)
	scroll.custom_minimum_size = Vector2(340, 360)
	scroll.size = Vector2(340, 360)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	skins_menu.add_child(scroll)

	skins_list = VBoxContainer.new()
	skins_list.add_theme_constant_override("separation", 8)
	skins_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(skins_list)

	# Rechte Spalte: Preview-Panel
	var preview := VBoxContainer.new()
	preview.position = Vector2(540, 120)
	preview.custom_minimum_size = Vector2(340, 360)
	preview.add_theme_constant_override("separation", 10)
	preview.alignment = BoxContainer.ALIGNMENT_CENTER
	skins_menu.add_child(preview)

	skins_preview_sprite = TextureRect.new()
	skins_preview_sprite.custom_minimum_size = Vector2(340, 230)
	skins_preview_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	skins_preview_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.add_child(skins_preview_sprite)

	skins_preview_name = Label.new()
	skins_preview_name.add_theme_font_size_override("font_size", 24)
	skins_preview_name.add_theme_color_override("font_color", Color.WHITE)
	skins_preview_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skins_preview_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.add_child(skins_preview_name)

	skins_preview_tier = Label.new()
	skins_preview_tier.add_theme_font_size_override("font_size", 18)
	skins_preview_tier.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skins_preview_tier.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.add_child(skins_preview_tier)

	skins_preview_equipped = Label.new()
	skins_preview_equipped.text = "✓ Equipped"
	skins_preview_equipped.add_theme_font_size_override("font_size", 16)
	skins_preview_equipped.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	skins_preview_equipped.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skins_preview_equipped.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.add_child(skins_preview_equipped)

	skins_equip_btn = Button.new()
	skins_equip_btn.custom_minimum_size = Vector2(200, 40)
	skins_equip_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	skins_equip_btn.pressed.connect(_on_equip_selected)
	preview.add_child(skins_equip_btn)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(120, 40)
	back_btn.position = Vector2(80, 490)
	back_btn.pressed.connect(_hide_submenus)
	skins_menu.add_child(back_btn)

# Alle im Menü wählbaren Skins: virtueller Default Knight (id "") + besessene Skins.
# Der Default steht bewusst nicht in SKIN_TIERS/owned_skins (keine Case-/Collection-Zählung).
func _selectable_skins() -> Array:
	var entries: Array = [Progression.get_default_skin()]
	entries.append_array(Progression.get_owned_skins())
	return entries

func _show_skins_menu() -> void:
	play_sfx("click")
	main_menu.visible = false
	skins_menu.visible = true
	# Default-Auswahl: ausgerüsteter Skin; unbekannte id fällt auf den Default Knight zurück
	selected_skin_id = Progression.equipped_skin
	if selected_skin_id != "":
		var owns_selected := false
		for skin: Dictionary in Progression.get_owned_skins():
			if skin.id == selected_skin_id:
				owns_selected = true
				break
		if not owns_selected:
			selected_skin_id = ""
	_refresh_skins_menu()

func _refresh_skins_menu() -> void:
	for child in skins_list.get_children():
		child.queue_free()
	for skin: Dictionary in _selectable_skins():
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(320, 36)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 16)
		var prefix := "▶ " if skin.id == selected_skin_id else "    "
		btn.text = "%s%s" % [prefix, skin.name]
		btn.add_theme_color_override("font_color", TIER_COLORS.get(skin.tier, Color.WHITE))
		btn.pressed.connect(_on_select_skin.bind(skin.id))
		skins_list.add_child(btn)
	_update_skin_preview()

func _on_select_skin(id: String) -> void:
	play_sfx("click")
	selected_skin_id = id
	_refresh_skins_menu()

func _update_skin_preview() -> void:
	var selected := {}
	for skin: Dictionary in _selectable_skins():
		if skin.id == selected_skin_id:
			selected = skin
			break
	if selected.is_empty():
		return
	var texture_path: String = selected.get("texture", "")
	if texture_path != "" and ResourceLoader.exists(texture_path):
		skins_preview_sprite.texture = load(texture_path)
		skins_preview_sprite.modulate = Color.WHITE
	else:
		skins_preview_sprite.texture = load("res://assets/sprite_knight.png")
		skins_preview_sprite.modulate = selected.get("color", Color.WHITE)
	skins_preview_name.text = selected.name
	skins_preview_tier.text = String(selected.tier).capitalize()
	skins_preview_tier.add_theme_color_override("font_color", TIER_COLORS.get(selected.tier, Color.WHITE))
	var is_equipped: bool = selected.id == Progression.equipped_skin
	skins_preview_equipped.visible = is_equipped
	skins_equip_btn.visible = true
	skins_equip_btn.text = "Equipped" if is_equipped else "Equip"
	skins_equip_btn.disabled = is_equipped

func _on_equip_selected() -> void:
	play_sfx("click")
	Progression.equip_skin(selected_skin_id)
	_refresh_skins_menu()

func _hide_submenus() -> void:
	play_sfx("click")
	quests_menu.visible = false
	cases_menu.visible = false
	skins_menu.visible = false
	main_menu.visible = true

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	hud_label = Label.new()
	hud_label.position = Vector2(16, 12)
	hud_label.add_theme_font_size_override("font_size", 22)
	hud_label.add_theme_color_override("font_color", Color.WHITE)
	hud_label.add_theme_color_override("font_outline_color", Color.BLACK)
	hud_label.add_theme_constant_override("outline_size", 4)
	hud_label.visible = false
	layer.add_child(hud_label)

	coin_label = Label.new()
	coin_label.position = Vector2(VIEW.x - 120, 12)
	coin_label.add_theme_font_size_override("font_size", 22)
	coin_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2))
	coin_label.add_theme_color_override("font_outline_color", Color(0.3, 0.2, 0.0))
	coin_label.add_theme_constant_override("outline_size", 4)
	coin_label.visible = false
	layer.add_child(coin_label)

	keys_label = Label.new()
	keys_label.position = Vector2(VIEW.x - 120, 36)
	keys_label.add_theme_font_size_override("font_size", 18)
	keys_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	keys_label.add_theme_color_override("font_outline_color", Color(0.0, 0.15, 0.3))
	keys_label.add_theme_constant_override("outline_size", 4)
	keys_label.visible = false
	layer.add_child(keys_label)

	win_label = Label.new()
	win_label.position = Vector2(VIEW.x * 0.5 - 180, VIEW.y * 0.5 - 30)
	win_label.add_theme_font_size_override("font_size", 36)
	win_label.add_theme_color_override("font_color", Color(1, 0.95, 0.4))
	win_label.add_theme_color_override("font_outline_color", Color.BLACK)
	win_label.add_theme_constant_override("outline_size", 6)
	win_label.visible = false
	layer.add_child(win_label)

func _update_hud() -> void:
	var hearts := ""
	for i in range(MAX_HEALTH):
		hearts += "♥ " if i < health else "♡ "
	hud_label.text = "Level %d   %s   Score: %d" % [current_level + 1, hearts, score]
	coin_label.text = "🪙 %d" % coin_count
	keys_label.text = "🔑 %d" % Progression.get_keys()

func coin_collected() -> void:
	coin_count += 1
	play_sfx("coin", 0.06)
	Progression.add_quest_progress("coin")
	_update_hud()

func _load_level(idx: int) -> void:
	transition_gen += 1  # macht jede noch wartende reach_goal()-Coroutine ungültig
	if level_root:
		level_root.queue_free()
	current_level = idx
	health = MAX_HEALTH
	transitioning = false
	took_damage_this_level = false
	# Kein vererbter Schutz aus dem vorherigen Level/Run. Bewusst KEINE Spawn-Protection:
	# PlayerSpawn liegt in allen Leveln abseits der Gegner (Level 6 markiert die Start-
	# Plattform nicht als spawn_platform). Falls später gewünscht, hier eine benannte
	# Konstante (z.B. SPAWN_PROTECTION := 1.0) statt eines geerbten Timers verwenden.
	invuln_until = 0.0
	win_label.visible = false

	var packed: PackedScene = load(LEVELS[idx])
	level_root = packed.instantiate() as Node2D
	level_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(level_root)
	level_root.call("randomize_level_spawns")

	var spawn_marker := level_root.find_child("PlayerSpawn", true, false) as Marker2D
	var spawn_pos := Vector2(60, 460)
	if spawn_marker:
		spawn_pos = spawn_marker.position

	player = preload("res://scenes/Player.tscn").instantiate() as CharacterBody2D
	player.position = spawn_pos
	level_root.add_child(player)

	player.stomped_enemy.connect(_on_player_stomped_enemy)
	player.hit_enemy.connect(damage_player)
	player.fell_off.connect(fell_off_world)
	player.reached_goal.connect(reach_goal)
	player.jumped.connect(play_sfx.bind("jump", 0.04))
	player.double_jumped.connect(play_sfx.bind("double_jump", 0.04))
	player.double_jumped.connect(Progression.add_quest_progress.bind("double_jump"))
	player.call("apply_skin", Progression.get_equipped_skin())

	var cam := Camera2D.new()
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = level_root.level_width
	cam.limit_bottom = 540
	player.add_child(cam)

	_update_hud()

func _on_player_stomped_enemy(enemy: CharacterBody2D) -> void:
	if enemy == null or not enemy.has_method("is_enemy") or not enemy.is_enemy():
		return
	var pos := enemy.position
	enemy.call("kill")
	enemy_killed()
	play_sfx("stomp", 0.08)
	Progression.add_quest_progress("stomp")
	_spawn_pow(pos)

func _spawn_pow(pos: Vector2) -> void:
	var lyr := CanvasLayer.new()
	lyr.layer = 20
	add_child(lyr)
	var lbl := Label.new()
	lbl.text = "POW!"
	var screen_pos: Vector2 = get_viewport().get_canvas_transform() * pos
	lbl.position = screen_pos + Vector2(-36, -60)
	lbl.add_theme_font_size_override("font_size", 38)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.12))
	lbl.add_theme_constant_override("outline_size", 8)
	lyr.add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "position", screen_pos + Vector2(-36, -120), 0.35).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "scale", Vector2(1.5, 1.5), 0.2).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.25)
	tw.tween_callback(lyr.queue_free)

func enemy_killed() -> void:
	score += 1
	_update_hud()

func damage_player() -> void:
	if win_label.visible:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now < invuln_until:
		return
	invuln_until = now + 1.0
	health -= 1
	score -= 1
	took_damage_this_level = true
	took_damage_this_run = true
	_update_hud()
	if health <= 0:
		play_sfx("death")
		music_player.stop()
		_show_message("Ouch!\nPress R to retry")
	else:
		play_sfx("hit")
		player.velocity.y = 0

func fell_off_world() -> void:
	if win_label.visible:
		return
	health -= 1
	score -= 1
	took_damage_this_level = true
	took_damage_this_run = true
	_update_hud()
	if health <= 0:
		play_sfx("death")
		music_player.stop()
		_show_message("Ouch!\nPress R to retry")
	else:
		play_sfx("hit")
		var spawn_marker := level_root.find_child("PlayerSpawn", true, false) as Marker2D
		if spawn_marker:
			player.position = spawn_marker.position
		player.velocity = Vector2.ZERO
		invuln_until = Time.get_ticks_msec() / 1000.0 + 1.0

func reach_goal() -> void:
	if transitioning:
		return
	transitioning = true
	if not took_damage_this_level:
		Progression.add_quest_progress("no_damage_goal")
	Progression.add_quest_progress("level_clear")
	if current_level + 1 < LEVELS.size():
		play_sfx("level_clear")
		_show_message("Level Cleared!")
		# Nächstes Level und Token VOR dem await festhalten — danach kann sich beides
		# durch Restart/Menü geändert haben.
		var next_level := current_level + 1
		var my_gen := transition_gen
		# process_always=false: Pause friert den 1s-Timer ein — der Übergang läuft nur
		# bei laufendem Spiel weiter (kein Levelwechsel hinter dem Pause-Menü).
		await get_tree().create_timer(1.0, false).timeout
		# Veraltet, wenn inzwischen ein Level geladen oder das Hauptmenü geöffnet wurde
		# (beides erhöht transition_gen — deckt R, Try Again, Exit to Menu, neuen Run ab).
		if my_gen != transition_gen or in_main_menu:
			return
		_load_level(next_level)
	else:
		Progression.add_quest_progress("finish_run")
		if not took_damage_this_run:
			Progression.add_quest_progress("no_damage_run")
		play_sfx("win")
		music_player.stop()
		var record_line := "★ New Highscore! ★" if _submit_run(score, coin_count) \
			else "Best: Score %d   🪙 %d" % [best_score, best_coins]
		_show_message("You Win!\nCoins: %d   Score: %d\n%s\nPress R to replay" % [coin_count, score, record_line])

func _show_message(msg: String) -> void:
	win_label.text = msg
	win_label.visible = true
	if level_root:
		level_root.process_mode = Node.PROCESS_MODE_DISABLED

func _unhandled_input(event: InputEvent) -> void:
	if in_main_menu:
		return
	if event.is_action_pressed("pause"):
		_toggle_pause()
		return
	if event.is_action_pressed("restart"):
		get_tree().paused = false
		pause_menu.visible = false
		_set_music_ducked(false)
		if not music_player.playing:
			music_player.play()
		score = 0
		coin_count = 0
		took_damage_this_run = false
		_load_level(0)
