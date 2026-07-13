extends Node2D

const VIEW := Vector2(960, 540)
const MAX_HEALTH := 3

const LEVELS := [
	"res://scenes/Level1.tscn",
	"res://scenes/Level2.tscn",
	"res://scenes/Level3.tscn",
	"res://scenes/Level4.tscn",
	"res://scenes/Level5.tscn",
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

var current_level := 0
var health := MAX_HEALTH
var score := 0
var coin_count := 0
var transitioning := false
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
var keys_label: Label
var quests_menu: Control
var quests_list: VBoxContainer
var cases_menu: Control
var cases_keys_label: Label
var open_case_btn: Button
var skins_menu: Control
var skins_list: VBoxContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("game")
	_load_highscore()
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
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color.WHITE)
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
	layer.add_child(main_menu)

	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.12, 0.18)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_menu.add_child(bg)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.position = Vector2(VIEW.x * 0.5 - 130, VIEW.y * 0.5 - 120)
	box.custom_minimum_size = Vector2(260, 0)
	main_menu.add_child(box)

	var title := Label.new()
	title.text = "Cloude Game"
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.6))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 6)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(title)

	highscore_label = Label.new()
	highscore_label.add_theme_font_size_override("font_size", 18)
	highscore_label.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	highscore_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	highscore_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(highscore_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	box.add_child(spacer)

	var start_btn := Button.new()
	start_btn.text = "Start Game"
	start_btn.custom_minimum_size = Vector2(260, 48)
	start_btn.pressed.connect(_start_game)
	box.add_child(start_btn)

	var quests_btn := Button.new()
	quests_btn.text = "Quests"
	quests_btn.custom_minimum_size = Vector2(260, 40)
	quests_btn.pressed.connect(_show_quests_menu)
	box.add_child(quests_btn)

	var cases_btn := Button.new()
	cases_btn.text = "Cases"
	cases_btn.custom_minimum_size = Vector2(260, 40)
	cases_btn.pressed.connect(_show_cases_menu)
	box.add_child(cases_btn)

	var skins_btn := Button.new()
	skins_btn.text = "Skins"
	skins_btn.custom_minimum_size = Vector2(260, 40)
	skins_btn.pressed.connect(_show_skins_menu)
	box.add_child(skins_btn)

	var quit_btn := Button.new()
	quit_btn.text = "Quit Game"
	quit_btn.custom_minimum_size = Vector2(140, 40)
	quit_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	quit_btn.offset_left = -156
	quit_btn.offset_top = -56
	quit_btn.offset_right = -16
	quit_btn.offset_bottom = -16
	quit_btn.pressed.connect(_quit_game)
	main_menu.add_child(quit_btn)

func _show_main_menu() -> void:
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

func _start_game() -> void:
	play_sfx("click")
	in_main_menu = false
	main_menu.visible = false
	hud_label.visible = true
	coin_label.visible = true
	keys_label.visible = true
	score = 0
	coin_count = 0
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
	music_player.volume_db = -14.0 if paused else 0.0

func _restart_level_from_menu() -> void:
	play_sfx("click")
	get_tree().paused = false
	pause_menu.visible = false
	music_player.volume_db = 0.0
	score = 0
	coin_count = 0
	if not music_player.playing:
		music_player.play()
	_load_level(0)

func _build_submenu_shell(layer_index: int, title_text: String) -> Dictionary:
	var layer := CanvasLayer.new()
	layer.layer = layer_index
	add_child(layer)
	var menu := Control.new()
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.process_mode = Node.PROCESS_MODE_ALWAYS
	menu.visible = false
	layer.add_child(menu)

	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.12, 0.18)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(bg)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.position = Vector2(VIEW.x * 0.5 - 150, 60)
	box.custom_minimum_size = Vector2(300, 0)
	menu.add_child(box)

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.6))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(title)

	return {"menu": menu, "box": box}

func _build_quests_menu() -> void:
	var shell := _build_submenu_shell(11, "Daily Quests")
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
	main_menu.visible = false
	quests_menu.visible = true
	_refresh_quests_menu()

func _refresh_quests_menu() -> void:
	for child in quests_list.get_children():
		child.queue_free()
	for quest: Dictionary in Progression.get_active_quests():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		quests_list.add_child(row)

		var lbl := Label.new()
		lbl.text = "%s (%d/%d)" % [quest.desc, quest.progress, quest.target]
		lbl.custom_minimum_size = Vector2(200, 0)
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		row.add_child(lbl)

		var claim_btn := Button.new()
		claim_btn.custom_minimum_size = Vector2(90, 32)
		if quest.claimed:
			claim_btn.text = "Claimed"
			claim_btn.disabled = true
		elif quest.completed:
			claim_btn.text = "Claim"
			claim_btn.pressed.connect(_on_claim_quest.bind(quest.slot))
		else:
			claim_btn.text = "Claim"
			claim_btn.disabled = true
		row.add_child(claim_btn)

func _on_claim_quest(slot: int) -> void:
	if Progression.claim_quest(slot):
		play_sfx("click")
		_refresh_quests_menu()
		_update_hud()

func _build_cases_menu() -> void:
	var shell := _build_submenu_shell(12, "Cases")
	cases_menu = shell.menu

	cases_keys_label = Label.new()
	cases_keys_label.add_theme_font_size_override("font_size", 20)
	cases_keys_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	cases_keys_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cases_keys_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.box.add_child(cases_keys_label)

	open_case_btn = Button.new()
	open_case_btn.text = "Open Case"
	open_case_btn.custom_minimum_size = Vector2(300, 44)
	open_case_btn.pressed.connect(_on_open_case_pressed)
	shell.box.add_child(open_case_btn)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(300, 40)
	back_btn.pressed.connect(_hide_submenus)
	shell.box.add_child(back_btn)

func _show_cases_menu() -> void:
	play_sfx("click")
	main_menu.visible = false
	cases_menu.visible = true
	_refresh_cases_menu()

func _refresh_cases_menu() -> void:
	var keys := Progression.get_keys()
	cases_keys_label.text = "🔑 %d" % keys
	open_case_btn.disabled = keys <= 0

func _on_open_case_pressed() -> void:
	var skin := Progression.open_case()
	if skin.is_empty():
		return
	play_sfx("coin", 0.05)
	_spawn_skin_reveal(skin)
	_refresh_cases_menu()

func _spawn_skin_reveal(skin: Dictionary) -> void:
	var lyr := CanvasLayer.new()
	lyr.layer = 21
	add_child(lyr)
	var lbl := Label.new()
	lbl.text = "New Skin: %s!" % skin.name
	lbl.position = Vector2(VIEW.x * 0.5 - 140, VIEW.y * 0.5 - 20)
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.add_theme_color_override("font_color", skin.color)
	lbl.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.12))
	lbl.add_theme_constant_override("outline_size", 8)
	lbl.scale = Vector2(0.6, 0.6)
	lyr.add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "scale", Vector2(1.2, 1.2), 0.3).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "position:y", lbl.position.y - 40, 0.3).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.6)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.3)
	tw.tween_callback(lyr.queue_free)

func _build_skins_menu() -> void:
	var shell := _build_submenu_shell(13, "Skins")
	skins_menu = shell.menu
	skins_list = VBoxContainer.new()
	skins_list.add_theme_constant_override("separation", 10)
	shell.box.add_child(skins_list)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(300, 40)
	back_btn.pressed.connect(_hide_submenus)
	shell.box.add_child(back_btn)

func _show_skins_menu() -> void:
	play_sfx("click")
	main_menu.visible = false
	skins_menu.visible = true
	_refresh_skins_menu()

func _refresh_skins_menu() -> void:
	for child in skins_list.get_children():
		child.queue_free()
	var owned := Progression.get_owned_skins()
	if owned.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No skins yet — open a case!"
		empty_lbl.add_theme_font_size_override("font_size", 16)
		empty_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		skins_list.add_child(empty_lbl)
		return
	for skin: Dictionary in owned:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		skins_list.add_child(row)

		var swatch := ColorRect.new()
		swatch.color = skin.color
		swatch.custom_minimum_size = Vector2(24, 24)
		row.add_child(swatch)

		var lbl := Label.new()
		lbl.text = skin.name
		lbl.custom_minimum_size = Vector2(160, 0)
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		row.add_child(lbl)

		var equip_btn := Button.new()
		equip_btn.custom_minimum_size = Vector2(100, 32)
		if skin.id == Progression.equipped_skin:
			equip_btn.text = "Equipped"
			equip_btn.disabled = true
		else:
			equip_btn.text = "Equip"
			equip_btn.pressed.connect(_on_equip_skin.bind(skin.id))
		row.add_child(equip_btn)

func _on_equip_skin(id: String) -> void:
	play_sfx("click")
	Progression.equip_skin(id)
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
	if level_root:
		level_root.queue_free()
	current_level = idx
	health = MAX_HEALTH
	transitioning = false
	took_damage_this_level = false
	win_label.visible = false

	var packed: PackedScene = load(LEVELS[idx])
	level_root = packed.instantiate() as Node2D
	level_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(level_root)

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
	player.call("apply_skin", Progression.get_equipped_skin())

	var cam := Camera2D.new()
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = level_root.level_width
	cam.limit_bottom = 540
	player.add_child(cam)

	_update_hud()

func _on_player_stomped_enemy(enemy: CharacterBody2D) -> void:
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
	if current_level + 1 < LEVELS.size():
		play_sfx("level_clear")
		_show_message("Level Cleared!")
		await get_tree().create_timer(1.0).timeout
		_load_level(current_level + 1)
	else:
		Progression.add_quest_progress("finish_run")
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
		music_player.volume_db = 0.0
		if not music_player.playing:
			music_player.play()
		score = 0
		coin_count = 0
		_load_level(0)
