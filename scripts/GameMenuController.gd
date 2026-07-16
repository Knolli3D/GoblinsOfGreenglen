extends Node

const GreenglenUI := preload("res://scripts/GreenglenUI.gd")

const VIEW := Vector2(960, 540)
const RESULT_COMPLETED_ACCENT := Color(1.0, 0.65, 0.15)
const RESULT_FAILED_ACCENT := Color(0.9, 0.45, 0.32)

signal start_requested
signal resume_requested
signal restart_requested
signal main_menu_requested
signal quests_requested
signal cases_requested
signal skins_requested
signal quit_requested

var main_menu: Control
var highscore_label: Label
var pause_menu: Control
var run_result_menu: Control
var result_title_label: Label
var result_score_value: Label
var result_coins_value: Label
var result_best_label: Label
var result_record_label: Label
var result_run_again_btn: Button

var ui_theme: Theme
var heading_font: Font
var body_font: Font


func initialize(theme: Theme, heading: Font, body: Font) -> void:
	if main_menu != null:
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	ui_theme = theme
	heading_font = heading
	body_font = body
	_build_run_result_menu()
	_build_main_menu()
	_build_pause_menu()


func show_main_menu(best_text: String) -> void:
	highscore_label.text = best_text
	main_menu.visible = true


func hide_main_menu() -> void:
	main_menu.visible = false


func set_pause_visible(visible: bool) -> void:
	pause_menu.visible = visible


func hide_result() -> void:
	run_result_menu.visible = false


func show_result(
	completed: bool,
	run_score: int,
	run_coins: int,
	best_text: String,
	is_new_highscore: bool,
) -> void:
	result_title_label.text = "Run Complete" if completed else "Run Over"
	result_title_label.add_theme_color_override(
		"font_color", RESULT_COMPLETED_ACCENT if completed else RESULT_FAILED_ACCENT)
	result_score_value.text = str(run_score)
	result_coins_value.text = str(run_coins)
	result_best_label.text = best_text
	result_record_label.text = "New Highscore!" if completed and is_new_highscore else ""
	pause_menu.visible = false
	run_result_menu.visible = true
	result_run_again_btn.grab_focus()


func _build_pause_menu() -> void:
	var layer := CanvasLayer.new()
	layer.name = "PauseLayer"
	layer.layer = 10
	add_child(layer)

	pause_menu = Control.new()
	pause_menu.name = "PauseMenu"
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
	box.position = Vector2(VIEW.x * 0.5 - 120, VIEW.y * 0.5 - 110)
	box.custom_minimum_size = Vector2(240, 0)
	pause_menu.add_child(box)

	var title := Label.new()
	title.text = "Paused"
	GreenglenUI.apply_heading_style(title, heading_font, 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(title)

	var resume_button := Button.new()
	resume_button.text = "Resume"
	GreenglenUI.configure_button(resume_button, 40)
	resume_button.pressed.connect(resume_requested.emit)
	box.add_child(resume_button)

	var restart_button := Button.new()
	restart_button.text = "Try Again"
	GreenglenUI.configure_button(restart_button, 40)
	restart_button.pressed.connect(restart_requested.emit)
	box.add_child(restart_button)

	var exit_button := Button.new()
	exit_button.text = "Exit to Menu"
	GreenglenUI.configure_button(exit_button, 40)
	exit_button.pressed.connect(main_menu_requested.emit)
	box.add_child(exit_button)


func _build_run_result_menu() -> void:
	var layer := CanvasLayer.new()
	layer.name = "RunResultLayer"
	layer.layer = 8
	add_child(layer)

	run_result_menu = Control.new()
	run_result_menu.name = "RunResultMenu"
	run_result_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	run_result_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	run_result_menu.theme = ui_theme
	run_result_menu.visible = false
	layer.add_child(run_result_menu)

	var dim := ColorRect.new()
	dim.color = Color(0.025, 0.035, 0.04, 0.68)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	run_result_menu.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	run_result_menu.add_child(center)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(460, 0)
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	result_title_label = Label.new()
	GreenglenUI.apply_heading_style(result_title_label, heading_font, 44)
	result_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(result_title_label)

	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 36)
	box.add_child(stats)
	result_score_value = _add_result_stat(stats, "FINAL SCORE", GreenglenUI.UI_CREAM)
	result_coins_value = _add_result_stat(stats, "COINS", Color("#F4D35E"))

	result_best_label = Label.new()
	result_best_label.add_theme_font_override("font", body_font)
	result_best_label.add_theme_font_size_override("font_size", 18)
	result_best_label.add_theme_color_override("font_color", Color(0.72, 0.84, 0.92))
	result_best_label.add_theme_color_override("font_outline_color", GreenglenUI.UI_BROWN)
	result_best_label.add_theme_constant_override("outline_size", 3)
	result_best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_best_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(result_best_label)

	result_record_label = Label.new()
	result_record_label.custom_minimum_size.y = 28
	result_record_label.add_theme_font_override("font", heading_font)
	result_record_label.add_theme_font_size_override("font_size", 21)
	result_record_label.add_theme_color_override("font_color", GreenglenUI.TIER_COLORS.legendary)
	result_record_label.add_theme_color_override("font_outline_color", GreenglenUI.UI_BROWN)
	result_record_label.add_theme_constant_override("outline_size", 4)
	result_record_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_record_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(result_record_label)

	result_run_again_btn = Button.new()
	result_run_again_btn.text = "Run Again"
	GreenglenUI.configure_button(result_run_again_btn, 46)
	result_run_again_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	result_run_again_btn.pressed.connect(restart_requested.emit)
	box.add_child(result_run_again_btn)

	var main_menu_button := Button.new()
	main_menu_button.text = "Main Menu"
	GreenglenUI.configure_button(main_menu_button, 46)
	main_menu_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	main_menu_button.pressed.connect(main_menu_requested.emit)
	box.add_child(main_menu_button)


func _add_result_stat(parent: HBoxContainer, caption: String, value_color: Color) -> Label:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(170, 0)
	column.add_theme_constant_override("separation", 2)
	parent.add_child(column)

	var caption_label := Label.new()
	caption_label.text = caption
	caption_label.add_theme_font_override("font", body_font)
	caption_label.add_theme_font_size_override("font_size", 15)
	caption_label.add_theme_color_override("font_color", Color(0.72, 0.76, 0.72))
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(caption_label)

	var value_label := Label.new()
	value_label.add_theme_font_override("font", heading_font)
	value_label.add_theme_font_size_override("font_size", 34)
	value_label.add_theme_color_override("font_color", value_color)
	value_label.add_theme_color_override("font_outline_color", GreenglenUI.UI_BROWN)
	value_label.add_theme_constant_override("outline_size", 4)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(value_label)
	return value_label


func _build_main_menu() -> void:
	var layer := CanvasLayer.new()
	layer.name = "MainMenuLayer"
	layer.layer = 9
	add_child(layer)

	main_menu = Control.new()
	main_menu.name = "MainMenu"
	main_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	main_menu.theme = ui_theme
	layer.add_child(main_menu)

	var background := TextureRect.new()
	background.texture = load("res://assets/menubackground.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_menu.add_child(background)

	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.06, 0.1, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_menu.add_child(dim)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.position = Vector2(0, 40)
	box.custom_minimum_size = Vector2(VIEW.x, 0)
	main_menu.add_child(box)

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

	_add_main_button(box, "Start Game", 48, start_requested.emit)
	_add_main_button(box, "Quests", 40, quests_requested.emit)
	_add_main_button(box, "Cases", 40, cases_requested.emit)
	_add_main_button(box, "Skins", 40, skins_requested.emit)

	var quit_button := Button.new()
	quit_button.text = "Quit Game"
	GreenglenUI.configure_button(quit_button, 40)
	quit_button.add_theme_font_size_override("font_size", 15)
	quit_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	quit_button.offset_left = -256
	quit_button.offset_top = -56
	quit_button.offset_right = -16
	quit_button.offset_bottom = -16
	quit_button.pressed.connect(quit_requested.emit)
	main_menu.add_child(quit_button)


func _add_main_button(parent: VBoxContainer, text: String, height: float, handler: Callable) -> void:
	var button := Button.new()
	button.text = text
	GreenglenUI.configure_button(button, height)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(handler)
	parent.add_child(button)
