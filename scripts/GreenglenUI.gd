extends RefCounted

const VIEW := Vector2(960, 540)

const BTN_TEX := {
	"normal": "res://assets/ui/buttons/button_greenglen_normal.png",
	"hover": "res://assets/ui/buttons/button_greenglen_hover.png",
	"pressed": "res://assets/ui/buttons/button_greenglen_pressed.png",
	"disabled": "res://assets/ui/buttons/button_greenglen_disabled.png",
}

const UI_CREAM := Color("#FFF1C4")
const UI_BROWN := Color("#351D0E")
const BUTTON_ASPECT_RATIO := 6.0
const BUTTON_CONTENT_SIDE_MARGIN := 32.0

const TIER_COLORS := {
	"common": Color(0.55, 0.85, 0.55),
	"rare": Color(0.4, 0.6, 1.0),
	"epic": Color(0.8, 0.45, 0.95),
	"legendary": Color(1.0, 0.65, 0.15),
	"starter": Color(0.55, 0.8, 0.85),
	"default": Color(0.85, 0.85, 0.85),
}


static func build_theme_bundle() -> Dictionary:
	var body_font: Font = load("res://Cinzel/static/Cinzel-SemiBold.ttf")
	var heading_font: Font = load("res://Cinzel/static/Cinzel-Bold.ttf")
	if body_font is FontFile:
		(body_font as FontFile).fallbacks = [ThemeDB.fallback_font]
	if heading_font is FontFile:
		(heading_font as FontFile).fallbacks = [ThemeDB.fallback_font]

	var theme := Theme.new()
	theme.set_stylebox("normal", "Button", _make_button_style("normal"))
	theme.set_stylebox("hover", "Button", _make_button_style("hover"))
	theme.set_stylebox("pressed", "Button", _make_button_style("pressed"))
	theme.set_stylebox("disabled", "Button", _make_button_style("disabled"))
	theme.set_stylebox("focus", "Button", _make_button_style("hover"))
	theme.set_font("font", "Button", body_font)
	theme.set_font_size("font_size", "Button", 18)
	theme.set_color("font_color", "Button", UI_CREAM)
	theme.set_color("font_hover_color", "Button", Color("#FFFBEA"))
	theme.set_color("font_pressed_color", "Button", Color("#FFE7A0"))
	theme.set_color("font_focus_color", "Button", UI_CREAM)
	theme.set_color("font_hover_pressed_color", "Button", Color("#FFE7A0"))
	theme.set_color("font_disabled_color", "Button", Color(0.72, 0.66, 0.5))
	theme.set_color("font_outline_color", "Button", UI_BROWN)
	theme.set_constant("outline_size", "Button", 3)
	return {
		"theme": theme,
		"heading_font": heading_font,
		"body_font": body_font,
	}


static func apply_heading_style(label: Label, heading_font: Font, size: int) -> void:
	label.add_theme_font_override("font", heading_font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", UI_CREAM)
	label.add_theme_color_override("font_outline_color", UI_BROWN)
	label.add_theme_constant_override("outline_size", 5)


static func button_size(height: float) -> Vector2:
	return Vector2(height * BUTTON_ASPECT_RATIO, height)


static func configure_button(button: Button, height: float) -> void:
	button.custom_minimum_size = button_size(height)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER


static func build_submenu_shell(
	owner: Node,
	layer_index: int,
	title_text: String,
	bg_path: String,
	theme: Theme,
	heading_font: Font,
) -> Dictionary:
	var layer := CanvasLayer.new()
	layer.name = "%sLayer" % title_text.replace(" ", "")
	layer.layer = layer_index
	owner.add_child(layer)

	var menu := Control.new()
	menu.name = "%sMenu" % title_text.replace(" ", "")
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.process_mode = Node.PROCESS_MODE_ALWAYS
	menu.theme = theme
	menu.visible = false
	layer.add_child(menu)

	var bg := TextureRect.new()
	bg.texture = load(bg_path)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(bg)

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
	apply_heading_style(title, heading_font, 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(title)

	return {"menu": menu, "box": box, "layer": layer}


static func _make_button_style(state: String) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load(BTN_TEX[state])
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.content_margin_left = BUTTON_CONTENT_SIDE_MARGIN
	style.content_margin_right = BUTTON_CONTENT_SIDE_MARGIN
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style
