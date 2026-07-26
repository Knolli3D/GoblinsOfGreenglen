extends Node

const GreenglenUI := preload("res://scripts/GreenglenUI.gd")

const CREDITS_FILE := "res://assets/credits.json"
const CREDITS_LAYER := 15

signal back_requested

var menu: Control
var credits_list: VBoxContainer
var heading_font: Font
var body_font: Font


func initialize(theme: Theme, heading: Font, body: Font) -> void:
	if menu != null:
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	heading_font = heading
	body_font = body
	var shell := GreenglenUI.build_submenu_shell(
		self, CREDITS_LAYER, "Credits", "res://assets/menubackground.png", theme, heading_font)
	menu = shell.menu
	credits_list = VBoxContainer.new()
	credits_list.name = "CreditsList"
	credits_list.add_theme_constant_override("separation", 10)
	shell.box.add_child(credits_list)

	var back_button := Button.new()
	back_button.text = "Back"
	GreenglenUI.configure_button(back_button, 40)
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_button.pressed.connect(back_requested.emit)
	shell.box.add_child(back_button)


func show_menu() -> void:
	if menu == null:
		return
	_refresh_credits()
	menu.visible = true


func hide_menu() -> void:
	if menu != null:
		menu.visible = false


func _refresh_credits() -> void:
	for child: Node in credits_list.get_children():
		child.free()
	var data := _load_credits()
	var sections: Array = data.get("sections", [])
	for section_value: Variant in sections:
		if section_value is Dictionary:
			_add_section(section_value)
	if credits_list.get_child_count() == 0:
		_add_message("Credits are not available.")


func _load_credits() -> Dictionary:
	var file := FileAccess.open(CREDITS_FILE, FileAccess.READ)
	if file == null:
		push_warning("Credits file is missing: %s" % CREDITS_FILE)
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		push_warning("Credits file contains invalid JSON: %s" % CREDITS_FILE)
		return {}
	return json.data as Dictionary


func _add_section(section: Dictionary) -> void:
	var title := Label.new()
	title.text = String(section.get("heading", "Credits"))
	title.add_theme_font_override("font", heading_font)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", GreenglenUI.TIER_COLORS.legendary)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits_list.add_child(title)
	var entries: Array = section.get("entries", [])
	for entry_value: Variant in entries:
		if entry_value is Dictionary:
			_add_entry(entry_value)


func _add_entry(entry: Dictionary) -> void:
	var title := String(entry.get("title", "Untitled"))
	var artist := String(entry.get("artist", ""))
	var source := String(entry.get("source", ""))
	var usage := String(entry.get("usage", ""))
	var lines: Array[String] = [title]
	if artist != "":
		lines.append("by %s" % artist)
	if source != "":
		lines.append(source)
	if usage != "":
		lines.append(usage)
	var label := Label.new()
	label.text = "\n".join(lines)
	label.add_theme_font_override("font", body_font)
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", GreenglenUI.UI_CREAM)
	label.add_theme_color_override("font_outline_color", GreenglenUI.UI_BROWN)
	label.add_theme_constant_override("outline_size", 2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits_list.add_child(label)


func _add_message(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", body_font)
	label.add_theme_font_size_override("font_size", 17)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits_list.add_child(label)
