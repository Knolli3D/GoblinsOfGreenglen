extends Node

const GreenglenUI := preload("res://scripts/GreenglenUI.gd")

signal back_requested

var menu: Control
var skins_list: VBoxContainer
var preview_sprite: TextureRect
var preview_name: Label
var preview_tier: Label
var preview_equipped: Label
var equip_button: Button
var selected_skin_id := ""
var audio: Node


func initialize(theme: Theme, heading_font: Font, audio_controller: Node) -> void:
	if menu != null:
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	audio = audio_controller
	var shell := GreenglenUI.build_submenu_shell(
		self, 13, "Skins", "res://assets/menu_bg_skins.png", theme, heading_font)
	menu = shell.menu

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(80, 120)
	scroll.custom_minimum_size = Vector2(340, 360)
	scroll.size = Vector2(340, 360)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu.add_child(scroll)

	skins_list = VBoxContainer.new()
	skins_list.add_theme_constant_override("separation", 8)
	skins_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(skins_list)

	var preview := VBoxContainer.new()
	preview.position = Vector2(540, 120)
	preview.custom_minimum_size = Vector2(340, 360)
	preview.add_theme_constant_override("separation", 10)
	preview.alignment = BoxContainer.ALIGNMENT_CENTER
	menu.add_child(preview)

	preview_sprite = TextureRect.new()
	preview_sprite.custom_minimum_size = Vector2(340, 230)
	preview_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.add_child(preview_sprite)

	preview_name = Label.new()
	preview_name.add_theme_font_size_override("font_size", 24)
	preview_name.add_theme_color_override("font_color", Color.WHITE)
	preview_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.add_child(preview_name)

	preview_tier = Label.new()
	preview_tier.add_theme_font_size_override("font_size", 18)
	preview_tier.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_tier.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.add_child(preview_tier)

	preview_equipped = Label.new()
	preview_equipped.text = "✓ Equipped"
	preview_equipped.add_theme_font_size_override("font_size", 16)
	preview_equipped.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	preview_equipped.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_equipped.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.add_child(preview_equipped)

	equip_button = Button.new()
	equip_button.custom_minimum_size = Vector2(200, 40)
	equip_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	equip_button.pressed.connect(_on_equip_selected)
	preview.add_child(equip_button)

	var back_button := Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(120, 40)
	back_button.position = Vector2(80, 490)
	back_button.pressed.connect(back_requested.emit)
	menu.add_child(back_button)


func show_menu() -> void:
	menu.visible = true
	selected_skin_id = Progression.equipped_skin
	if selected_skin_id != "" and not _owns_skin(selected_skin_id):
		selected_skin_id = ""
	refresh()


func hide_menu() -> void:
	menu.visible = false


func refresh() -> void:
	for child in skins_list.get_children():
		child.queue_free()
	for skin: Dictionary in selectable_skins():
		var button := Button.new()
		button.custom_minimum_size = Vector2(320, 36)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 16)
		var prefix := "▶ " if skin.id == selected_skin_id else "    "
		button.text = "%s%s" % [prefix, skin.name]
		button.add_theme_color_override("font_color", GreenglenUI.TIER_COLORS.get(skin.tier, Color.WHITE))
		button.pressed.connect(_on_select_skin.bind(skin.id))
		skins_list.add_child(button)
	_update_preview()


func selectable_skins() -> Array:
	var entries: Array = [Progression.get_default_skin()]
	entries.append_array(Progression.get_owned_skins())
	return entries


func _owns_skin(id: String) -> bool:
	for skin: Dictionary in Progression.get_owned_skins():
		if skin.id == id:
			return true
	return false


func _on_select_skin(id: String) -> void:
	audio.play_sfx("click")
	selected_skin_id = id
	refresh()


func _update_preview() -> void:
	var selected := {}
	for skin: Dictionary in selectable_skins():
		if skin.id == selected_skin_id:
			selected = skin
			break
	if selected.is_empty():
		return
	var texture_path: String = selected.get("texture", "")
	if texture_path != "" and ResourceLoader.exists(texture_path):
		preview_sprite.texture = load(texture_path)
		preview_sprite.modulate = Color.WHITE
	else:
		preview_sprite.texture = load("res://assets/sprite_knight.png")
		preview_sprite.modulate = selected.get("color", Color.WHITE)
	preview_name.text = selected.name
	preview_tier.text = String(selected.tier).capitalize()
	preview_tier.add_theme_color_override(
		"font_color", GreenglenUI.TIER_COLORS.get(selected.tier, Color.WHITE))
	var is_equipped: bool = selected.id == Progression.equipped_skin
	preview_equipped.visible = is_equipped
	equip_button.visible = true
	equip_button.text = "Equipped" if is_equipped else "Equip"
	equip_button.disabled = is_equipped


func _on_equip_selected() -> void:
	audio.play_sfx("click")
	Progression.equip_skin(selected_skin_id)
	refresh()
