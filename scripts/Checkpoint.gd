@tool
extends Area2D

signal activated(checkpoint: Area2D, body: Node2D)
var active := false

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("checkpoints")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not active and body.is_in_group("player"):
		activated.emit(self, body)

func activate() -> void:
	active = true
	queue_redraw()

func _draw() -> void:
	var tint := Color("#ffd77a") if active else Color("#b8efd0")
	draw_line(Vector2(0, 0), Vector2(0, -58), Color("#453e3a"), 5)
	draw_colored_polygon(PackedVector2Array([Vector2(2,-58), Vector2(32,-48), Vector2(2,-36)]), tint)
	draw_arc(Vector2(0,-8), 23, PI, TAU, 20, tint, 2)
