extends Node2D

@export var level_width: int = 960
@export var randomize_spawns: bool = false
@export var goblin_count: int = 8
@export var coin_count: int = 10

const SPAWN_PLATFORMS_GROUP := "spawn_platforms"
const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")
const COIN_SCENE := preload("res://scenes/Coin.tscn")
const ENEMY_Y_OFFSET := -13.0
const COIN_Y_OFFSET := -35.0
const PATROL_MARGIN := 8.0
const COIN_MARGIN := 6.0
const VIEW_HEIGHT := 540.0

# Gemeinsamer Parallax-Hintergrund für alle Level. Jeder Layer ist optional — fehlt die
# Textur, wird er übersprungen, sodass Level ohne Artwork weiterhin den flachen _draw()-
# Fallback zeigen. scroll_scale < 1 = Layer scrollt langsamer als die Welt (Tiefenwirkung).
# Hinweis: Ein weiterer (vorderer) Layer würde nur sichtbare Tiefe bringen, wenn seine
# Textur einen transparenten Himmel hat — level_bg.png/level_bg_near.png sind beide opak,
# daher aktuell nur der komplette Landschafts-Layer.
const BG_LAYERS := [
	{"path": "res://assets/level_bg_near.png", "scroll_scale": 0.4},
]
var _bg_active := false

func _ready() -> void:
	_build_parallax_background()

func _build_parallax_background() -> void:
	for i in range(BG_LAYERS.size()):
		var layer_def: Dictionary = BG_LAYERS[i]
		var path: String = layer_def.path
		if not ResourceLoader.exists(path):
			continue
		var tex: Texture2D = load(path)
		if tex == null:
			continue
		var scale_factor: float = VIEW_HEIGHT / float(tex.get_height())
		var scaled_width: float = tex.get_width() * scale_factor

		var px := Parallax2D.new()
		var scroll: float = layer_def.scroll_scale
		px.scroll_scale = Vector2(scroll, 0.0)
		px.repeat_size = Vector2(scaled_width, 0.0)
		px.z_index = -20 + i

		var spr := Sprite2D.new()
		spr.texture = tex
		spr.centered = false
		spr.scale = Vector2(scale_factor, scale_factor)
		px.add_child(spr)

		add_child(px)
		_bg_active = true
	if _bg_active:
		queue_redraw()

func _draw() -> void:
	if _bg_active:
		return
	draw_rect(Rect2(0, 0, level_width, 540), Color(0.45, 0.6, 0.85))
	draw_rect(Rect2(0, 360, level_width, 180), Color(0.3, 0.35, 0.5))

func randomize_level_spawns() -> void:
	if not randomize_spawns:
		return
	var eligible: Array = []
	for p in $Platforms.get_children():
		if p.is_in_group(SPAWN_PLATFORMS_GROUP):
			eligible.append(p)
	if eligible.is_empty():
		push_warning("randomize_spawns is on but no platforms are in the '%s' group" % SPAWN_PLATFORMS_GROUP)
		return
	_spawn_enemies(eligible)
	_spawn_coins(eligible)

func _spawn_enemies(eligible: Array) -> void:
	var order: Array = eligible.duplicate()
	order.shuffle()
	for i in range(goblin_count):
		var platform: StaticBody2D = order[i % order.size()]
		var second_pass: bool = i >= order.size()
		var shape: RectangleShape2D = platform.get_node("CollisionShape2D").shape
		var half_width := shape.size.x / 2.0
		var patrol := randf_range(20.0, 40.0)
		var max_offset: float = max(half_width - patrol - PATROL_MARGIN, 0.0)
		var x := platform.position.x + randf_range(-max_offset, max_offset)
		if second_pass:
			x = platform.position.x + (max_offset if randf() < 0.5 else -max_offset) * 0.5
		var top_y := platform.position.y - shape.size.y / 2.0
		var enemy := ENEMY_SCENE.instantiate()
		enemy.position = Vector2(x, top_y + ENEMY_Y_OFFSET)
		enemy.patrol_range = patrol
		add_child(enemy)

func _spawn_coins(eligible: Array) -> void:
	for i in range(coin_count):
		var platform: StaticBody2D = eligible[i % eligible.size()]
		var shape: RectangleShape2D = platform.get_node("CollisionShape2D").shape
		var half_width := shape.size.x / 2.0
		var max_offset: float = max(half_width - COIN_MARGIN, 0.0)
		var x := platform.position.x + randf_range(-max_offset, max_offset)
		var top_y := platform.position.y - shape.size.y / 2.0
		var coin := COIN_SCENE.instantiate()
		coin.position = Vector2(x, top_y + COIN_Y_OFFSET)
		add_child(coin)
