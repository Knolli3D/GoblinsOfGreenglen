extends Area2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	var game: Node = get_tree().get_first_node_in_group("game")
	if game:
		game.call("coin_collected")
	call_deferred("queue_free")

func _draw() -> void:
	draw_circle(Vector2.ZERO, 12.0, Color(1.0, 0.86, 0.2))
	draw_arc(Vector2.ZERO, 7.0, 0.0, TAU, 32, Color(0.88, 0.58, 0.1), 2.5)
