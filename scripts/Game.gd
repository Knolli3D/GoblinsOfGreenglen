extends Node2D

const VIEW := Vector2(960, 540)
const MAX_HEALTH := 3

const LEVELS := [
	"res://scenes/Level1.tscn",
	"res://scenes/Level2.tscn",
	"res://scenes/Level3.tscn",
]

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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("game")
	_build_hud()
	_build_pause_menu()
	_build_main_menu()
	_show_main_menu()

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

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	box.add_child(spacer)

	var start_btn := Button.new()
	start_btn.text = "Start Game"
	start_btn.custom_minimum_size = Vector2(260, 48)
	start_btn.pressed.connect(_start_game)
	box.add_child(start_btn)

	var quit_btn := Button.new()
	quit_btn.text = "Quit Game"
	quit_btn.custom_minimum_size = Vector2(260, 48)
	quit_btn.pressed.connect(_quit_game)
	box.add_child(quit_btn)

func _show_main_menu() -> void:
	in_main_menu = true
	get_tree().paused = false
	pause_menu.visible = false
	hud_label.visible = false
	coin_label.visible = false
	win_label.visible = false
	if level_root:
		level_root.queue_free()
		level_root = null
	main_menu.visible = true

func _start_game() -> void:
	in_main_menu = false
	main_menu.visible = false
	hud_label.visible = true
	coin_label.visible = true
	score = 0
	coin_count = 0
	_load_level(0)

func _quit_game() -> void:
	get_tree().quit()

func _exit_to_main_menu() -> void:
	_show_main_menu()

func _toggle_pause() -> void:
	var paused := not get_tree().paused
	get_tree().paused = paused
	pause_menu.visible = paused

func _restart_level_from_menu() -> void:
	get_tree().paused = false
	pause_menu.visible = false
	score = 0
	coin_count = 0
	_load_level(0)

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

func coin_collected() -> void:
	coin_count += 1
	_update_hud()

func _load_level(idx: int) -> void:
	if level_root:
		level_root.queue_free()
	current_level = idx
	health = MAX_HEALTH
	transitioning = false
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

	_update_hud()

func _on_player_stomped_enemy(enemy: CharacterBody2D) -> void:
	var pos := enemy.position
	enemy.call("kill")
	enemy_killed()
	_spawn_pow(pos)

func _spawn_pow(pos: Vector2) -> void:
	var lyr := CanvasLayer.new()
	lyr.layer = 20
	add_child(lyr)
	var lbl := Label.new()
	lbl.text = "POW!"
	lbl.position = pos + Vector2(-36, -60)
	lbl.add_theme_font_size_override("font_size", 38)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.12))
	lbl.add_theme_constant_override("outline_size", 8)
	lyr.add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "position", pos + Vector2(-36, -120), 0.35).set_ease(Tween.EASE_OUT)
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
	_update_hud()
	if health <= 0:
		_show_message("Ouch!\nPress R to retry")
	else:
		player.velocity.y = 0

func fell_off_world() -> void:
	if win_label.visible:
		return
	health -= 1
	score -= 1
	_update_hud()
	if health <= 0:
		_show_message("Ouch!\nPress R to retry")
	else:
		var spawn_marker := level_root.find_child("PlayerSpawn", true, false) as Marker2D
		if spawn_marker:
			player.position = spawn_marker.position
		player.velocity = Vector2.ZERO
		invuln_until = Time.get_ticks_msec() / 1000.0 + 1.0

func reach_goal() -> void:
	if transitioning:
		return
	transitioning = true
	if current_level + 1 < LEVELS.size():
		_show_message("Level Cleared!")
		await get_tree().create_timer(1.0).timeout
		_load_level(current_level + 1)
	else:
		_show_message("You Win!\nCoins: %d   Score: %d\nPress R to replay" % [coin_count, score])

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
		score = 0
		coin_count = 0
		_load_level(0)
