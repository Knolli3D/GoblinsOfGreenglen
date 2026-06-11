extends CharacterBody2D

signal stomped_enemy(enemy: CharacterBody2D)
signal hit_enemy
signal fell_off
signal reached_goal

const GRAVITY := 1400.0
const MOVE_SPEED := 220.0
const JUMP_VELOCITY := -520.0
const DOUBLE_JUMP_VELOCITY := -460.0
const MAX_JUMPS := 2

var jumps_remaining := 0

func _ready() -> void:
	add_to_group("player")
	var sprite := $Sprite2D
	if sprite and sprite.texture:
		sprite.scale = Vector2.ONE * (52.0 / float(sprite.texture.get_height()))
		sprite.position = Vector2(0, -2)

func _physics_process(delta: float) -> void:
	if is_on_floor():
		jumps_remaining = MAX_JUMPS

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if Input.is_action_just_pressed("jump") and jumps_remaining > 0:
		velocity.y = JUMP_VELOCITY if jumps_remaining == MAX_JUMPS else DOUBLE_JUMP_VELOCITY
		jumps_remaining -= 1

	var dir := 0.0
	if Input.is_action_pressed("move_left"):
		dir -= 1.0
	if Input.is_action_pressed("move_right"):
		dir += 1.0
	velocity.x = dir * MOVE_SPEED

	move_and_slide()

	if position.y > 700:
		fell_off.emit()
		return

	for n: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy: CharacterBody2D = n as CharacterBody2D
		if enemy == null or not enemy.has_method("is_enemy") or not enemy.is_enemy():
			continue
		var dx: float = abs(position.x - enemy.position.x)
		var dy: float = abs(position.y - enemy.position.y)
		if dx < 25.0 and dy < 35.0:
			if position.y + 22.0 < enemy.position.y:
				stomped_enemy.emit(enemy)
				velocity.y = DOUBLE_JUMP_VELOCITY
				jumps_remaining = MAX_JUMPS
			else:
				hit_enemy.emit()
			return

	var space := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(24, 36)
	query.shape = shape
	query.transform = Transform2D(0, position)
	query.collision_mask = 8
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hits := space.intersect_shape(query, 4)
	for h: Dictionary in hits:
		var col: Object = h.get("collider")
		if col and col.is_in_group("goals"):
			reached_goal.emit()
			return
