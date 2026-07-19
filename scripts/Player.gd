extends CharacterBody2D

signal stomped_enemy(enemy: CharacterBody2D)
signal hit_enemy
signal fell_off
signal reached_goal
signal jumped
signal double_jumped

const GRAVITY := 1400.0
const MOVE_SPEED := 220.0
const JUMP_VELOCITY := -520.0
const DOUBLE_JUMP_VELOCITY := -460.0
const MAX_JUMPS := 2
const STOMP_TOP_TOLERANCE := 2.0
const STOMP_MIN_HORIZONTAL_OVERLAP := 4.0

var jumps_remaining := 0
var jump_animation_enabled := true
var run_animation_enabled := false

func _ready() -> void:
	add_to_group("player")
	var sprite := $Sprite2D
	if sprite and sprite.texture:
		sprite.scale = Vector2.ONE * (52.0 / float(sprite.texture.get_height()))
		sprite.position = Vector2(0, -2)
	var jump_sprite := $JumpSprite as AnimatedSprite2D
	var jump_texture := jump_sprite.sprite_frames.get_frame_texture(&"jump", 0)
	if jump_texture:
		jump_sprite.scale = Vector2.ONE * (52.0 / float(jump_texture.get_height()))
	jump_sprite.position = Vector2(0, -2)
	jump_sprite.visible = false
	var run_sprite := $RunSprite as AnimatedSprite2D
	var run_texture := run_sprite.sprite_frames.get_frame_texture(&"run", 0)
	if run_texture:
		run_sprite.scale = Vector2.ONE * (52.0 / float(run_texture.get_height()))
	run_sprite.position = Vector2(0, -2)
	run_sprite.visible = false

func apply_skin(skin: Dictionary) -> void:
	var sprite := $Sprite2D
	var skin_id := String(skin.get("id", ""))
	jump_animation_enabled = skin_id == ""
	run_animation_enabled = skin_id == "princess_blue"
	_show_static_sprite()
	var texture_path: String = skin.get("texture", "")
	if texture_path != "" and ResourceLoader.exists(texture_path):
		sprite.texture = load(texture_path)
		sprite.modulate = Color.WHITE
	else:
		sprite.modulate = skin.get("color", Color.WHITE)
	if sprite.texture:
		sprite.scale = Vector2.ONE * (52.0 / float(sprite.texture.get_height()))
		sprite.position = Vector2(0, -2)

func _physics_process(delta: float) -> void:
	if is_on_floor():
		jumps_remaining = MAX_JUMPS

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if Input.is_action_just_pressed("jump") and jumps_remaining > 0:
		if jumps_remaining == MAX_JUMPS:
			velocity.y = JUMP_VELOCITY
			jumped.emit()
		else:
			velocity.y = DOUBLE_JUMP_VELOCITY
			double_jumped.emit()
		_play_jump_animation()
		jumps_remaining -= 1

	var dir := 0.0
	if Input.is_action_pressed("move_left"):
		dir -= 1.0
	if Input.is_action_pressed("move_right"):
		dir += 1.0
	velocity.x = dir * MOVE_SPEED

	var previous_global_position := global_position
	var was_descending := velocity.y > 0.0
	move_and_slide()
	if ($JumpSprite as AnimatedSprite2D).visible and is_on_floor():
		_show_static_sprite()
	_update_run_animation(dir)

	if position.y > 700:
		fell_off.emit()
		return

	if _handle_enemy_interaction(previous_global_position, was_descending):
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

func _play_jump_animation() -> void:
	if not jump_animation_enabled:
		return
	var jump_sprite := $JumpSprite as AnimatedSprite2D
	($Sprite2D as Sprite2D).visible = false
	($RunSprite as AnimatedSprite2D).visible = false
	jump_sprite.visible = true
	jump_sprite.stop()
	jump_sprite.frame = 0
	jump_sprite.play(&"jump")

func _show_static_sprite() -> void:
	var jump_sprite := $JumpSprite as AnimatedSprite2D
	jump_sprite.stop()
	jump_sprite.visible = false
	var run_sprite := $RunSprite as AnimatedSprite2D
	run_sprite.stop()
	run_sprite.visible = false
	($Sprite2D as Sprite2D).visible = true

func _update_run_animation(direction: float) -> void:
	var run_sprite := $RunSprite as AnimatedSprite2D
	if not run_animation_enabled or not is_on_floor() or is_zero_approx(direction):
		if run_sprite.visible:
			_show_static_sprite()
		return
	if ($JumpSprite as AnimatedSprite2D).visible:
		return
	($Sprite2D as Sprite2D).visible = false
	run_sprite.visible = true
	if not run_sprite.is_playing():
		run_sprite.play(&"run")

func _handle_enemy_interaction(previous_player_position: Vector2, was_descending: bool) -> bool:
	var player_collider := $CollisionShape2D as CollisionShape2D
	var player_half_extents := _rectangle_half_extents(player_collider)
	var current_player_center := player_collider.global_position
	var previous_player_center := current_player_center + previous_player_position - global_position

	for n: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy := n as CharacterBody2D
		if enemy == null or not enemy.has_method("is_enemy") or not enemy.is_enemy():
			continue

		var enemy_collider := enemy.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if enemy_collider == null or not enemy_collider.shape is RectangleShape2D:
			continue

		var previous_enemy_position := enemy.global_position
		if enemy.has_method("get_previous_global_position"):
			previous_enemy_position = enemy.call("get_previous_global_position")
		var enemy_half_extents := _rectangle_half_extents(enemy_collider)
		var current_enemy_center := enemy_collider.global_position
		var previous_enemy_center := current_enemy_center + previous_enemy_position - enemy.global_position

		if _is_stomp(
			previous_player_center,
			current_player_center,
			player_half_extents,
			previous_enemy_center,
			current_enemy_center,
			enemy_half_extents,
			was_descending
		):
			stomped_enemy.emit(enemy)
			velocity.y = DOUBLE_JUMP_VELOCITY
			jumps_remaining = MAX_JUMPS
			return true

		if _swept_rectangles_intersect(
			previous_player_center,
			current_player_center,
			player_half_extents,
			previous_enemy_center,
			current_enemy_center,
			enemy_half_extents
		):
			hit_enemy.emit()
			return true

	return false

func _rectangle_half_extents(collider: CollisionShape2D) -> Vector2:
	var rectangle := collider.shape as RectangleShape2D
	var collider_scale := collider.global_transform.get_scale().abs()
	return rectangle.size * collider_scale * 0.5

func _is_stomp(
	previous_player_center: Vector2,
	current_player_center: Vector2,
	player_half_extents: Vector2,
	previous_enemy_center: Vector2,
	current_enemy_center: Vector2,
	enemy_half_extents: Vector2,
	was_descending: bool
) -> bool:
	if not was_descending:
		return false

	var previous_feet_y := previous_player_center.y + player_half_extents.y
	var current_feet_y := current_player_center.y + player_half_extents.y
	var previous_enemy_top_y := previous_enemy_center.y - enemy_half_extents.y
	var current_enemy_top_y := current_enemy_center.y - enemy_half_extents.y
	var previous_top_distance := previous_feet_y - previous_enemy_top_y
	var current_top_distance := current_feet_y - current_enemy_top_y
	var relative_vertical_motion := current_top_distance - previous_top_distance

	if previous_top_distance > STOMP_TOP_TOLERANCE:
		return false
	if current_top_distance < -STOMP_TOP_TOLERANCE:
		return false
	if relative_vertical_motion <= 0.0:
		return false

	var crossing_ratio := clampf(-previous_top_distance / relative_vertical_motion, 0.0, 1.0)
	var player_crossing_x := lerpf(previous_player_center.x, current_player_center.x, crossing_ratio)
	var enemy_crossing_x := lerpf(previous_enemy_center.x, current_enemy_center.x, crossing_ratio)
	var horizontal_overlap: float = player_half_extents.x + enemy_half_extents.x \
		- abs(player_crossing_x - enemy_crossing_x)
	return horizontal_overlap >= STOMP_MIN_HORIZONTAL_OVERLAP

func _swept_rectangles_intersect(
	previous_player_center: Vector2,
	current_player_center: Vector2,
	player_half_extents: Vector2,
	previous_enemy_center: Vector2,
	current_enemy_center: Vector2,
	enemy_half_extents: Vector2
) -> bool:
	var previous_relative_center := previous_player_center - previous_enemy_center
	var current_relative_center := current_player_center - current_enemy_center
	var combined_half_extents := player_half_extents + enemy_half_extents
	var x_interval := _swept_axis_interval(
		previous_relative_center.x,
		current_relative_center.x,
		combined_half_extents.x
	)
	var y_interval := _swept_axis_interval(
		previous_relative_center.y,
		current_relative_center.y,
		combined_half_extents.y
	)
	var entry_time := maxf(0.0, maxf(x_interval.x, y_interval.x))
	var exit_time := minf(1.0, minf(x_interval.y, y_interval.y))
	return entry_time <= exit_time

func _swept_axis_interval(previous_offset: float, current_offset: float, half_extent: float) -> Vector2:
	var motion := current_offset - previous_offset
	if is_zero_approx(motion):
		return Vector2(0.0, 1.0) if abs(previous_offset) <= half_extent else Vector2(1.0, 0.0)
	var first_contact := (-half_extent - previous_offset) / motion
	var last_contact := (half_extent - previous_offset) / motion
	return Vector2(minf(first_contact, last_contact), maxf(first_contact, last_contact))
