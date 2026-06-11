extends Area2D

func _ready() -> void:
	add_to_group("goals")

func _draw() -> void:
	draw_rect(Rect2(-3, -36, 6, 36), Color(0.5, 0.3, 0.15))
	draw_rect(Rect2(3, -36, 20, 14), Color(0.9, 0.2, 0.25))
