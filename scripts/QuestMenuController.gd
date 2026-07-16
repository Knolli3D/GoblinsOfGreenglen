extends Node

const GreenglenUI := preload("res://scripts/GreenglenUI.gd")

signal back_requested
signal keys_changed

var menu: Control
var quests_list: VBoxContainer
var audio: Node


func initialize(theme: Theme, heading_font: Font, audio_controller: Node) -> void:
	if menu != null:
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	audio = audio_controller
	var shell := GreenglenUI.build_submenu_shell(
		self, 11, "Daily Quests", "res://assets/menu_bg_quests.png", theme, heading_font)
	menu = shell.menu
	quests_list = VBoxContainer.new()
	quests_list.add_theme_constant_override("separation", 10)
	shell.box.add_child(quests_list)

	var back_button := Button.new()
	back_button.text = "Back"
	GreenglenUI.configure_button(back_button, 40)
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_button.pressed.connect(back_requested.emit)
	shell.box.add_child(back_button)


func show_menu() -> void:
	Progression.check_daily_reset()
	Progression.check_weekly_reset()
	menu.visible = true
	refresh()


func hide_menu() -> void:
	menu.visible = false


func refresh() -> void:
	for child in quests_list.get_children():
		child.queue_free()

	_add_section_header("Daily")
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

	_add_section_header("Weekly")
	for quest: Dictionary in Progression.get_weekly_quests():
		_add_quest_row(quest, "Claim %d🔑" % Progression.WEEKLY_REWARD, _on_claim_weekly)


func _add_section_header(text: String) -> void:
	var header := Label.new()
	header.text = text
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", Color(1, 0.95, 0.6))
	quests_list.add_child(header)


func _add_quest_row(quest: Dictionary, claim_text: String, claim_handler: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	quests_list.add_child(row)

	var label := Label.new()
	label.text = "%s (%d/%d)" % [quest.desc, quest.progress, quest.target]
	label.custom_minimum_size = Vector2(230, 0)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color.WHITE)
	row.add_child(label)

	var claim_button := Button.new()
	GreenglenUI.configure_button(claim_button, 32)
	if quest.claimed:
		claim_button.text = "Claimed"
		claim_button.disabled = true
	else:
		claim_button.text = claim_text
		if quest.completed:
			claim_button.pressed.connect(claim_handler.bind(quest.slot))
		else:
			claim_button.disabled = true
	row.add_child(claim_button)


func _on_claim_quest(slot: int) -> void:
	if Progression.claim_quest(slot):
		audio.play_sfx("click")
		refresh()
		keys_changed.emit()


func _on_claim_weekly(slot: int) -> void:
	if Progression.claim_weekly(slot):
		audio.play_sfx("click")
		refresh()
		keys_changed.emit()
