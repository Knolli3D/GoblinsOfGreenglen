extends "res://scripts/Level.gd"

# F6 development scene: shares production movement and camera configuration.
func _ready() -> void:
	super._ready()
	var player: CharacterBody2D = $Player
	player.set("fall_limit_y", fall_limit())
	var camera := Camera2D.new()
	camera.name = "FollowCamera"
	player.add_child(camera)
	configure_camera(camera)
	camera.reset_smoothing()
	player.fell_off.connect(_reset_player)

func _reset_player() -> void:
	var player: CharacterBody2D = $Player
	player.global_position = $PlayerSpawn.global_position
	player.call("reset_movement")
	get_viewport().get_camera_2d().reset_smoothing()
