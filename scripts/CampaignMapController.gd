extends Node

const GreenglenUI := preload("res://scripts/GreenglenUI.gd")
const CampaignMapPathLayer := preload("res://scripts/CampaignMapPathLayer.gd")

const VIEW := Vector2(960, 540)
const MAP_BACKGROUND_PATH := "res://assets/menu_bg_map.png"
const MAP_ORIGIN := Vector2(20, 88)
const MAP_SIZE := Vector2(650, 370)
const NODE_SIZE := Vector2(94, 42)
const MAP_LAYER := 14

# Regionsweiter Verfügbarkeits-Banner im Karten-Header (getrennt von den Location-Details).
const BANNER_AVAILABLE_COLOR := Color("#A8D87E")
const BANNER_LOCKED_COLOR := Color("#E0A87C")
const BANNER_COMING_SOON_COLOR := Color("#E5B94F")

signal level_requested(level_id: String)
signal region_requested(region_id: String)
signal back_requested

var catalog: RefCounted
var progress_store: Node
var audio: Node
var ui_theme: Theme
var heading_font: Font
var body_font: Font

var layer: CanvasLayer
var menu: Control
var map_background: TextureRect
var path_layer: Control
var region_selector: OptionButton
var region_title: Label
var region_status_banner: Label
var location_title: Label
var location_status: Label
var record_label: Label
var summary_label: Label
var play_button: Button
var back_button: Button
var node_buttons: Dictionary = {}
var current_region_id := ""
var selected_level_id := ""


func initialize(
	theme: Theme,
	heading: Font,
	body: Font,
	campaign_catalog: RefCounted,
	campaign_progress: Node,
	audio_service: Node,
) -> void:
	if menu != null:
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	ui_theme = theme
	heading_font = heading
	body_font = body
	catalog = campaign_catalog
	progress_store = campaign_progress
	audio = audio_service
	_build_map_shell()
	progress_store.level_unlocked.connect(_on_progress_changed.unbind(1))
	progress_store.region_cleared.connect(_on_progress_changed.unbind(1))
	progress_store.region_unlocked.connect(_on_progress_changed.unbind(1))
	progress_store.region_mastered.connect(_on_progress_changed.unbind(1))


func show_region(region_id: String) -> void:
	if menu == null or (catalog.call("get_region", region_id) as Dictionary).is_empty():
		return
	current_region_id = region_id
	menu.visible = true
	_refresh_region_selector()
	refresh()
	_focus_initial_control.call_deferred()


func hide_map() -> void:
	if menu != null:
		menu.visible = false


func refresh() -> void:
	if menu == null or current_region_id == "":
		return
	for button: Button in node_buttons.values():
		button.free()
	node_buttons.clear()
	var region := catalog.call("get_region", current_region_id) as Dictionary
	region_title.text = String(region.get("display_name", "Region"))
	_update_region_banner()
	_build_connections(region)
	_build_nodes(region)
	_apply_focus_neighbors(region)
	var preferred: String = progress_store.last_selected_level_id
	var preferred_level := catalog.call("get_level", preferred) as Dictionary
	if preferred_level.is_empty() or String(preferred_level.get("region_id", "")) != current_region_id:
		preferred = String(region.get("entry_level_id", ""))
	select_level(preferred, false)


func select_level(level_id: String, remember := true) -> void:
	var level := catalog.call("get_level", level_id) as Dictionary
	if level.is_empty() or String(level.get("region_id", "")) != current_region_id:
		return
	selected_level_id = level_id
	if remember:
		progress_store.set_last_selection(current_region_id, level_id)
	_update_node_styles()
	_update_details(level)


func _build_map_shell() -> void:
	layer = CanvasLayer.new()
	layer.name = "CampaignMapLayer"
	layer.layer = MAP_LAYER
	add_child(layer)

	menu = Control.new()
	menu.name = "CampaignMap"
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.process_mode = Node.PROCESS_MODE_ALWAYS
	menu.theme = ui_theme
	menu.visible = false
	layer.add_child(menu)

	map_background = TextureRect.new()
	map_background.name = "MapBackground"
	if ResourceLoader.exists(MAP_BACKGROUND_PATH, "Texture2D"):
		map_background.texture = load(MAP_BACKGROUND_PATH)
	else:
		# Textureless the map falls back to the dim overlay backdrop below.
		push_warning("Campaign map background missing: %s" % MAP_BACKGROUND_PATH)
	map_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	map_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(map_background)

	var dim := ColorRect.new()
	dim.color = Color(0.025, 0.045, 0.04, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(dim)

	region_title = Label.new()
	region_title.position = Vector2(24, 18)
	region_title.size = Vector2(620, 48)
	GreenglenUI.apply_heading_style(region_title, heading_font, 34)
	region_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(region_title)

	region_status_banner = _detail_label(14, BANNER_AVAILABLE_COLOR)
	region_status_banner.name = "RegionStatusBanner"
	region_status_banner.position = Vector2(24, 58)
	region_status_banner.size = Vector2(620, 40)
	region_status_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu.add_child(region_status_banner)

	region_selector = OptionButton.new()
	# The themed OptionButton is wider than its content minimum because of the
	# decorative texture ends. Center that full footprint over the detail pane.
	region_selector.position = Vector2(674, 24)
	region_selector.custom_minimum_size = Vector2(230, 38)
	region_selector.alignment = HORIZONTAL_ALIGNMENT_CENTER
	region_selector.add_theme_font_override("font", body_font)
	region_selector.add_theme_font_size_override("font_size", 16)
	region_selector.item_selected.connect(_on_region_selected)
	menu.add_child(region_selector)

	path_layer = CampaignMapPathLayer.new()
	path_layer.name = "MapGraph"
	path_layer.position = MAP_ORIGIN
	path_layer.size = MAP_SIZE
	path_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(path_layer)

	var side := VBoxContainer.new()
	side.name = "MapDetails"
	side.position = Vector2(704, 88)
	side.custom_minimum_size = Vector2(226, 0)
	side.add_theme_constant_override("separation", 12)
	menu.add_child(side)

	location_title = Label.new()
	location_title.custom_minimum_size = Vector2(226, 54)
	location_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	location_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	location_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	location_title.add_theme_font_override("font", heading_font)
	location_title.add_theme_font_size_override("font_size", 20)
	location_title.add_theme_color_override("font_color", GreenglenUI.UI_CREAM)
	location_title.add_theme_color_override("font_outline_color", GreenglenUI.UI_BROWN)
	location_title.add_theme_constant_override("outline_size", 3)
	side.add_child(location_title)

	location_status = _detail_label(18, Color("#E5B94F"))
	side.add_child(location_status)
	record_label = _detail_label(15, Color("#D8E2D0"))
	record_label.custom_minimum_size.y = 44
	record_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(record_label)
	summary_label = _detail_label(14, Color("#C6D6C3"))
	summary_label.custom_minimum_size.y = 76
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(summary_label)

	play_button = Button.new()
	play_button.text = "Play"
	GreenglenUI.configure_button(play_button, 36)
	play_button.pressed.connect(_on_play_pressed)
	side.add_child(play_button)

	back_button = Button.new()
	back_button.text = "Back"
	GreenglenUI.configure_button(back_button, 36)
	back_button.pressed.connect(_on_back_pressed)
	side.add_child(back_button)


# Drei getrennte Regions-Zustände: Available (released + freigeschaltet), Locked
# (Vorgängerregion noch nicht cleared — mit deren offenen Anforderungen) und Coming Soon
# (Vorgänger erfüllt, Region aber unveröffentlicht). Vollständig katalog-/store-getrieben.
func _update_region_banner() -> void:
	if progress_store.is_region_unlocked(current_region_id):
		region_status_banner.text = "Available"
		region_status_banner.add_theme_color_override("font_color", BANNER_AVAILABLE_COLOR)
		return
	var previous_id := String(catalog.call("get_previous_region_id", current_region_id))
	if previous_id != "" and not progress_store.is_region_cleared(previous_id):
		region_status_banner.text = _locked_requirement_text(previous_id)
		region_status_banner.add_theme_color_override("font_color", BANNER_LOCKED_COLOR)
		return
	region_status_banner.text = "Coming Soon"
	region_status_banner.add_theme_color_override("font_color", BANNER_COMING_SOON_COLOR)


# Offene Anforderungen der Vorgängerregion: Main-Level-Fortschritt plus die Display-Namen
# noch offener Core Trials. Regionen ohne definierte Trials nennen automatisch nur die
# Main-Level — es wird nie ein fiktiver Trial-Name erfunden.
func _locked_requirement_text(previous_region_id: String) -> String:
	var previous := catalog.call("get_region", previous_region_id) as Dictionary
	var summary: Dictionary = progress_store.get_region_summary(previous_region_id)
	var requirements := PackedStringArray()
	if int(summary.get("main_completed", 0)) < int(summary.get("main_total", 0)):
		requirements.append("main levels %d/%d" % [
			int(summary.get("main_completed", 0)), int(summary.get("main_total", 0))])
	for trial_id: String in catalog.call("get_required_trial_ids", previous_region_id):
		if not progress_store.is_trial_completed(trial_id):
			var trial := catalog.call("get_trial", trial_id) as Dictionary
			requirements.append(String(trial.get("display_name", trial_id)))
	if requirements.is_empty():
		requirements.append("remaining requirements")
	return "Locked - Clear %s first: %s" % [
		String(previous.get("display_name", "the previous region")), ", ".join(requirements)]


func _build_connections(region: Dictionary) -> void:
	var segments: Array = []
	for connection: Dictionary in region.get("connections", []):
		var from_id := String(connection.get("from", ""))
		var to_id := String(connection.get("to", ""))
		var from_level := catalog.call("get_level", from_id) as Dictionary
		var to_level := catalog.call("get_level", to_id) as Dictionary
		segments.append({
			"from": (from_level.get("map_position", Vector2.ZERO) as Vector2) + NODE_SIZE * 0.5,
			"to": (to_level.get("map_position", Vector2.ZERO) as Vector2) + NODE_SIZE * 0.5,
			"optional": String(connection.get("kind", "")) == "optional",
			"unlocked": progress_store.is_level_unlocked(to_id),
			"completed": progress_store.is_level_completed(from_id) \
				and progress_store.is_level_completed(to_id),
		})
	path_layer.set_segments(segments)


func _build_nodes(region: Dictionary) -> void:
	for level: Dictionary in region.get("levels", []):
		var level_id := String(level.get("id", ""))
		var button := Button.new()
		button.name = "MapNode_%s" % level_id
		button.text = _map_label(level)
		button.position = level.get("map_position", Vector2.ZERO)
		button.size = NODE_SIZE
		button.custom_minimum_size = NODE_SIZE
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.add_theme_font_override("font", body_font)
		button.add_theme_font_size_override("font_size", 13)
		button.pressed.connect(select_level.bind(level_id, true))
		path_layer.add_child(button)
		node_buttons[level_id] = button
	_update_node_styles()


func _apply_focus_neighbors(region: Dictionary) -> void:
	for level: Dictionary in region.get("levels", []):
		var level_id := String(level.get("id", ""))
		var button := node_buttons.get(level_id) as Button
		if button == null:
			continue
		var neighbors := level.get("focus_neighbors", {}) as Dictionary
		for direction: String in ["left", "right", "up", "down"]:
			var neighbor_id := String(neighbors.get(direction, ""))
			var neighbor := node_buttons.get(neighbor_id) as Button
			if neighbor == null:
				continue
			button.set("focus_neighbor_%s" % direction, button.get_path_to(neighbor))


func _update_node_styles() -> void:
	for level_id: String in node_buttons:
		var button := node_buttons[level_id] as Button
		var level := catalog.call("get_level", level_id) as Dictionary
		var released: bool = progress_store.is_region_released(String(level.get("region_id", "")))
		var unlocked: bool = progress_store.is_level_unlocked(level_id)
		var completed: bool = progress_store.is_level_completed(level_id)
		var bonus := bool(level.get("is_bonus", false))
		var base := Color("#694A2B")
		var border := Color("#D8C694")
		if bonus:
			base = Color("#5B3F62")
			border = Color("#E5B94F")
		if completed:
			base = Color("#3F6A3F")
			border = Color("#A8D87E")
		elif not released or not unlocked:
			base = Color("#34383A")
			border = Color("#77736B")
		button.modulate = Color.WHITE if released else Color(0.72, 0.72, 0.72)
		button.add_theme_stylebox_override("normal", _node_style(base, border, 2))
		button.add_theme_stylebox_override("hover", _node_style(base.lightened(0.12), border, 2))
		button.add_theme_stylebox_override("pressed", _node_style(base.darkened(0.12), border, 2))
		button.add_theme_stylebox_override("focus", _node_style(base.lightened(0.08), Color("#FFF1C4"), 3))
		button.add_theme_color_override("font_color", GreenglenUI.UI_CREAM)
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_color_override("font_focus_color", Color.WHITE)
		if level_id == selected_level_id:
			button.add_theme_stylebox_override("normal", _node_style(base.lightened(0.08), Color("#FFF1C4"), 3))


func _update_details(level: Dictionary) -> void:
	var level_id := String(level.get("id", ""))
	var region_id := String(level.get("region_id", ""))
	var released: bool = progress_store.is_region_released(region_id)
	var unlocked: bool = progress_store.is_level_unlocked(level_id)
	var completed: bool = progress_store.is_level_completed(level_id)
	location_title.text = String(level.get("display_name", "Location"))
	if not released:
		location_status.text = "Coming Soon"
	elif completed:
		location_status.text = "Completed"
	elif unlocked:
		location_status.text = "Available"
	else:
		location_status.text = "Locked"
	if bool(level.get("is_bonus", false)):
		location_status.text += "  -  Bonus"
	var record: Dictionary = progress_store.get_level_record(level_id)
	record_label.text = "Best: Score %d  Coins %d" % [record.score, record.coins] \
		if bool(record.has_record) else "No completed record"
	var summary: Dictionary = progress_store.get_region_summary(region_id)
	summary_label.text = "Main %d/%d\nBonus %d/%d\nCore Trials %d/%d" % [
		summary.get("main_completed", 0), summary.get("main_total", 0),
		summary.get("bonus_completed", 0), summary.get("bonus_total", 0),
		summary.get("core_trials_completed", 0), summary.get("core_trials_total", 0),
	]
	play_button.disabled = not progress_store.can_play_level(level_id)


func _refresh_region_selector() -> void:
	region_selector.clear()
	var selected_index := 0
	var index := 0
	for region: Dictionary in catalog.call("get_regions"):
		var region_id := String(region.get("id", ""))
		var suffix := "" if bool(region.get("released", false)) else " - Coming Soon"
		region_selector.add_item(String(region.get("display_name", "Region")) + suffix)
		region_selector.set_item_metadata(index, region_id)
		if region_id == current_region_id:
			selected_index = index
		index += 1
	region_selector.select(selected_index)


func _focus_initial_control() -> void:
	var button := node_buttons.get(selected_level_id) as Button
	if button != null and progress_store.is_region_released(current_region_id):
		button.grab_focus()
	else:
		back_button.grab_focus()


func _on_region_selected(index: int) -> void:
	var region_id := String(region_selector.get_item_metadata(index))
	if region_id == current_region_id:
		return
	_play_click()
	region_requested.emit(region_id)
	show_region(region_id)


func _on_play_pressed() -> void:
	if not progress_store.can_play_level(selected_level_id):
		return
	_play_click()
	level_requested.emit(selected_level_id)


func _on_back_pressed() -> void:
	_play_click()
	hide_map()
	back_requested.emit()


func _on_progress_changed() -> void:
	if menu != null and menu.visible:
		refresh()


func _play_click() -> void:
	if audio != null:
		audio.play_sfx("click")


func _detail_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", body_font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", GreenglenUI.UI_BROWN)
	label.add_theme_constant_override("outline_size", 2)
	return label


func _node_style(color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(6)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


func _map_label(level: Dictionary) -> String:
	var display_name := String(level.get("display_name", "Location"))
	var parts := display_name.split(" - ")
	return parts[parts.size() - 1]
