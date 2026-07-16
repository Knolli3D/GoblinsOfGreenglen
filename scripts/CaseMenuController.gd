extends Node

const GreenglenUI := preload("res://scripts/GreenglenUI.gd")

const VIEW := Vector2(960, 540)
const CARD_WIDTH := 100.0
const CARD_COUNT := 40
const WIN_INDEX := 34

signal back_requested

var menu: Control
var keys_label: Label
var open_case_button: Button
var premium_case_button: Button
var stats_label: Label
var back_button: Button
var reel_frame: Control
var reel_strip: Control
var is_spinning := false
var reel_last_tick_index := 0
var audio: Node


func initialize(theme: Theme, heading_font: Font, audio_controller: Node) -> void:
	if menu != null:
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	audio = audio_controller
	var shell := GreenglenUI.build_submenu_shell(
		self, 12, "Cases", "res://assets/menu_bg_cases.png", theme, heading_font)
	menu = shell.menu

	keys_label = Label.new()
	keys_label.add_theme_font_size_override("font_size", 20)
	keys_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	keys_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keys_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.box.add_child(keys_label)

	open_case_button = Button.new()
	open_case_button.text = "Open Case (1 🔑)"
	open_case_button.custom_minimum_size = Vector2(300, 44)
	open_case_button.add_theme_font_size_override("font_size", 16)
	open_case_button.pressed.connect(_on_open_case_pressed.bind(false))
	shell.box.add_child(open_case_button)

	premium_case_button = Button.new()
	premium_case_button.text = "Premium Case (3 🔑) — Rare+"
	premium_case_button.custom_minimum_size = Vector2(300, 44)
	premium_case_button.add_theme_font_size_override("font_size", 13)
	premium_case_button.pressed.connect(_on_open_case_pressed.bind(true))
	shell.box.add_child(premium_case_button)

	stats_label = Label.new()
	stats_label.add_theme_font_size_override("font_size", 14)
	stats_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.box.add_child(stats_label)

	back_button = Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(300, 40)
	back_button.pressed.connect(back_requested.emit)
	shell.box.add_child(back_button)
	_build_reel()


func _process(_delta: float) -> void:
	if not is_spinning or reel_strip == null:
		return
	var index := int((330.0 - reel_strip.position.x) / CARD_WIDTH)
	if index != reel_last_tick_index:
		reel_last_tick_index = index
		audio.play_sfx("click", 0.1)


func show_menu() -> void:
	menu.visible = true
	refresh()


func hide_menu() -> void:
	menu.visible = false


func refresh() -> void:
	var keys: int = Progression.get_keys()
	keys_label.text = "🔑 %d    Shards: %d/%d" % [
		keys, Progression.get_shards(), Progression.SHARDS_PER_KEY]
	open_case_button.disabled = keys < 1 or is_spinning
	premium_case_button.disabled = keys < Progression.PREMIUM_CASE_COST or is_spinning
	back_button.disabled = is_spinning
	var best: String = Progression.get_best_pull()
	var best_text := "—" if best == "" else best.capitalize()
	stats_label.text = "Collection: %d/%d    Cases opened: %d    Best pull: %s" % [
		Progression.owned_skins.size(),
		Progression.get_total_skin_count(),
		Progression.get_cases_opened(),
		best_text,
	]


func _build_reel() -> void:
	reel_frame = Control.new()
	reel_frame.position = Vector2(VIEW.x * 0.5 - 335, 380)
	reel_frame.custom_minimum_size = Vector2(670, 120)
	reel_frame.visible = false
	menu.add_child(reel_frame)

	var frame_background := ColorRect.new()
	frame_background.color = Color(0.06, 0.07, 0.1, 0.9)
	frame_background.size = Vector2(670, 120)
	reel_frame.add_child(frame_background)

	var clip := Control.new()
	clip.position = Vector2(5, 10)
	clip.size = Vector2(660, 100)
	clip.clip_contents = true
	reel_frame.add_child(clip)

	reel_strip = Control.new()
	reel_strip.size = Vector2(CARD_WIDTH * CARD_COUNT, 100)
	clip.add_child(reel_strip)

	var marker := ColorRect.new()
	marker.color = Color(1.0, 0.85, 0.2)
	marker.position = Vector2(334, 0)
	marker.size = Vector2(2, 120)
	reel_frame.add_child(marker)


func _on_open_case_pressed(premium: bool) -> void:
	if is_spinning:
		return
	var skin: Dictionary = Progression.open_case(premium)
	if skin.is_empty():
		return
	_start_spin(skin)


func _start_spin(result: Dictionary) -> void:
	is_spinning = true
	audio.play_sfx("coin", 0.05)
	open_case_button.disabled = true
	premium_case_button.disabled = true
	back_button.disabled = true

	for child in reel_strip.get_children():
		child.queue_free()
	var pool := _all_skins_flat()
	for i in range(CARD_COUNT):
		var card_skin: Dictionary = result if i == WIN_INDEX else pool[randi() % pool.size()]
		reel_strip.add_child(_make_reel_card(card_skin, i))

	reel_frame.visible = true
	reel_strip.position.x = 330.0 - CARD_WIDTH * 0.5
	reel_last_tick_index = 0

	var target_x: float = 330.0 - (float(WIN_INDEX) * CARD_WIDTH + CARD_WIDTH * 0.5) \
		+ randf_range(-30.0, 30.0)
	var tween := create_tween()
	tween.tween_property(reel_strip, "position:x", target_x, 2.8) \
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.3)
	tween.tween_callback(_on_reel_finished.bind(result))


func _on_reel_finished(result: Dictionary) -> void:
	is_spinning = false
	_spawn_skin_reveal(result)
	refresh()


func _all_skins_flat() -> Array:
	var result: Array = []
	for tier: String in Progression.SKIN_TIERS:
		for skin: Dictionary in Progression.SKIN_TIERS[tier].skins:
			var entry: Dictionary = skin.duplicate()
			entry["tier"] = tier
			result.append(entry)
	return result


func _make_reel_card(skin: Dictionary, index: int) -> Control:
	var card := Control.new()
	card.position = Vector2(index * CARD_WIDTH, 0)
	card.size = Vector2(CARD_WIDTH, 100)

	var background := ColorRect.new()
	background.color = Color(0.12, 0.13, 0.18)
	background.position = Vector2(2, 2)
	background.size = Vector2(96, 96)
	card.add_child(background)

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
	stripe.color = GreenglenUI.TIER_COLORS.get(skin.tier, Color.WHITE)
	stripe.position = Vector2(2, 92)
	stripe.size = Vector2(96, 6)
	card.add_child(stripe)
	return card


func _spawn_skin_reveal(skin: Dictionary) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 21
	add_child(layer)

	var tier: String = skin.get("tier", "common")
	var duplicate: bool = skin.get("duplicate", false)
	var big_tier: bool = tier == "epic" or tier == "legendary"
	if tier == "rare" or big_tier:
		var flash := ColorRect.new()
		var flash_color: Color = GreenglenUI.TIER_COLORS.get(tier, Color.WHITE)
		var flash_alpha := 0.35
		var flash_duration := 0.5
		if tier == "epic":
			flash_alpha = 0.55
			flash_duration = 0.8
		elif tier == "legendary":
			flash_alpha = 0.65
			flash_duration = 0.9
		flash_color.a = flash_alpha
		flash.color = flash_color
		flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.add_child(flash)
		var flash_tween := create_tween()
		flash_tween.tween_property(flash, "color:a", 0.0, flash_duration).set_ease(Tween.EASE_OUT)
		audio.play_sfx("level_clear" if tier == "rare" else "win")

	if big_tier and reel_frame != null:
		var base: Vector2 = reel_frame.position
		var shake_tween := create_tween()
		var amplitude := 8.0
		for i in range(6):
			var offset := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * amplitude
			shake_tween.tween_property(reel_frame, "position", base + offset, 0.04)
			amplitude = maxf(amplitude - 1.2, 2.0)
		shake_tween.tween_property(reel_frame, "position", base, 0.04)

	var label := Label.new()
	var text := "%s — Duplicate (+1 Shard)" % skin.name if duplicate else "New Skin: %s!" % skin.name
	if skin.get("key_from_shards", false):
		text += "\n+1 Key from Shards!"
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(VIEW.x * 0.5 - 180, VIEW.y * 0.5 - 20)
	label.custom_minimum_size = Vector2(360, 0)
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", skin.color)
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.12))
	label.add_theme_constant_override("outline_size", 8)
	label.scale = Vector2(0.6, 0.6)
	layer.add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "scale", Vector2(1.2, 1.2), 0.3).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "position:y", label.position.y - 40, 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.9)
	tween.tween_property(label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(layer.queue_free)
