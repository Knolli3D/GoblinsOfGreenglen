extends Control

const REQUIRED_COLOR := Color("#D8C694")
const OPTIONAL_COLOR := Color("#E5B94F")
const COMPLETED_COLOR := Color("#91C96B")

var segments: Array = []


func set_segments(value: Array) -> void:
	segments = value.duplicate(true)
	queue_redraw()


func _draw() -> void:
	for segment: Dictionary in segments:
		var from_pos := segment.get("from", Vector2.ZERO) as Vector2
		var to_pos := segment.get("to", Vector2.ZERO) as Vector2
		var optional := bool(segment.get("optional", false))
		var unlocked := bool(segment.get("unlocked", false))
		var completed := bool(segment.get("completed", false))
		var color := OPTIONAL_COLOR if optional else REQUIRED_COLOR
		if completed:
			color = COMPLETED_COLOR
		elif not unlocked:
			color = Color(color.r, color.g, color.b, 0.28)
		if optional:
			draw_dashed_line(from_pos, to_pos, color, 3.0, 9.0, true, true)
		else:
			draw_line(from_pos, to_pos, color, 3.0, true)
