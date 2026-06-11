extends StaticBody2D

const PLATFORM_PNG := preload("res://assets/sprite_platform.png")

func _ready() -> void:
	var shape_node := $CollisionShape2D
	if shape_node == null:
		return
	var rect_shape := shape_node.shape as RectangleShape2D
	if rect_shape == null:
		return
	var size := rect_shape.size
	var tex := PLATFORM_PNG
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.scale = Vector2(size.x / float(tex.get_width()), max(size.y + 12.0, 28.0) / float(tex.get_height()))
	sprite.position = Vector2(0, -6)
	add_child(sprite)
