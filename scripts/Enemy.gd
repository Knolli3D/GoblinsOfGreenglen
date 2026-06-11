extends CharacterBody2D

const GRAVITY := 1400.0
const SPEED := 60.0

@export var patrol_range: float = 60.0
var origin_x: float = 0.0
var dir := 1.0
var dead := false

func _ready() -> void:
	origin_x = position.x
	add_to_group("enemies")
	var sprite := $Sprite2D
	if sprite and sprite.texture:
		sprite.scale = Vector2.ONE * (40.0 / float(sprite.texture.get_height()))
		sprite.position = Vector2(0, -2)

func is_enemy() -> bool:
	return not dead

func kill() -> void:
	if dead:
		return
	dead = true
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2.ZERO
	rotation = PI
	set_physics_process(false)
	hide()
	var t := get_tree().create_timer(0.5)
	t.timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	velocity.y += GRAVITY * delta
	if dead:
		move_and_slide()
		return
	if is_on_floor():
		velocity.y = 0
	if position.x > origin_x + patrol_range:
		dir = -1.0
	elif position.x < origin_x - patrol_range:
		dir = 1.0
	velocity.x = dir * SPEED
	move_and_slide()
