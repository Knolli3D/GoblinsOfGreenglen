extends Node

const VIEW := Vector2(960, 540)

var hud_label: Label
var timer_label: Label
var coin_label: Label
var keys_label: Label
var message_label: Label
var canvas_layer: CanvasLayer


func initialize() -> void:
	if canvas_layer != null:
		return
	canvas_layer = CanvasLayer.new()
	canvas_layer.name = "HUDLayer"
	add_child(canvas_layer)

	hud_label = Label.new()
	hud_label.name = "Status"
	hud_label.position = Vector2(16, 12)
	hud_label.add_theme_font_size_override("font_size", 22)
	hud_label.add_theme_color_override("font_color", Color.WHITE)
	hud_label.add_theme_color_override("font_outline_color", Color.BLACK)
	hud_label.add_theme_constant_override("outline_size", 4)
	hud_label.visible = false
	canvas_layer.add_child(hud_label)

	timer_label = Label.new()
	timer_label.name = "RunTimer"
	timer_label.position = Vector2(VIEW.x * 0.5 - 55, 12)
	timer_label.custom_minimum_size = Vector2(110, 0)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 22)
	timer_label.add_theme_color_override("font_color", Color(0.86, 0.94, 1.0))
	timer_label.add_theme_color_override("font_outline_color", Color.BLACK)
	timer_label.add_theme_constant_override("outline_size", 4)
	timer_label.visible = false
	canvas_layer.add_child(timer_label)

	coin_label = Label.new()
	coin_label.name = "Coins"
	coin_label.position = Vector2(VIEW.x - 120, 12)
	coin_label.add_theme_font_size_override("font_size", 22)
	coin_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2))
	coin_label.add_theme_color_override("font_outline_color", Color(0.3, 0.2, 0.0))
	coin_label.add_theme_constant_override("outline_size", 4)
	coin_label.visible = false
	canvas_layer.add_child(coin_label)

	keys_label = Label.new()
	keys_label.name = "Keys"
	keys_label.position = Vector2(VIEW.x - 120, 36)
	keys_label.add_theme_font_size_override("font_size", 18)
	keys_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	keys_label.add_theme_color_override("font_outline_color", Color(0.0, 0.15, 0.3))
	keys_label.add_theme_constant_override("outline_size", 4)
	keys_label.visible = false
	canvas_layer.add_child(keys_label)

	message_label = Label.new()
	message_label.name = "Message"
	message_label.position = Vector2(VIEW.x * 0.5 - 180, VIEW.y * 0.5 - 30)
	message_label.add_theme_font_size_override("font_size", 36)
	message_label.add_theme_color_override("font_color", Color(1, 0.95, 0.4))
	message_label.add_theme_color_override("font_outline_color", Color.BLACK)
	message_label.add_theme_constant_override("outline_size", 6)
	message_label.visible = false
	canvas_layer.add_child(message_label)


func update_status(
	level_number: int,
	health: int,
	max_health: int,
	score: int,
	coins: int,
	keys: int,
	run_time_text: String,
) -> void:
	var hearts := ""
	for i in range(max_health):
		hearts += "♥ " if i < health else "♡ "
	hud_label.text = "Level %d   %s   Score: %d" % [level_number, hearts, score]
	coin_label.text = "🪙 %d" % coins
	keys_label.text = "🔑 %d" % keys
	timer_label.text = run_time_text


func update_run_time(run_time_text: String) -> void:
	timer_label.text = run_time_text


func show_gameplay() -> void:
	hud_label.visible = true
	timer_label.visible = true
	coin_label.visible = true
	keys_label.visible = true


func hide_gameplay() -> void:
	hud_label.visible = false
	timer_label.visible = false
	coin_label.visible = false
	keys_label.visible = false


func show_message(text: String) -> void:
	message_label.text = text
	message_label.visible = true


func hide_message() -> void:
	message_label.visible = false


func spawn_pow(world_position: Vector2) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var label := Label.new()
	label.text = "POW!"
	var screen_position: Vector2 = get_viewport().get_canvas_transform() * world_position
	label.position = screen_position + Vector2(-36, -60)
	label.add_theme_font_size_override("font_size", 38)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.12))
	label.add_theme_constant_override("outline_size", 8)
	layer.add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position", screen_position + Vector2(-36, -120), 0.35).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "scale", Vector2(1.5, 1.5), 0.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.25)
	tween.tween_callback(layer.queue_free)
