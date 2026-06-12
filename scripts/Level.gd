extends Node2D

@export var level_width: int = 960

func _draw() -> void:
	draw_rect(Rect2(0, 0, level_width, 540), Color(0.45, 0.6, 0.85))
	draw_rect(Rect2(0, 360, level_width, 180), Color(0.3, 0.35, 0.5))
