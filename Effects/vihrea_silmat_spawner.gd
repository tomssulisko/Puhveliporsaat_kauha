extends Node2D

## Spawns ambient green eyes at random map spots; never starts inside the beam.
@export var eye_scene: PackedScene
@export var tilemap_path: NodePath = NodePath("../TileMapLayer")
@export var max_visible: int = 3
@export var pool_size: int = 5
@export var spawn_interval_min: float = 1.8
@export var spawn_interval_max: float = 4.5
@export var hold_min: float = 1.2
@export var hold_max: float = 3.5
@export var edge_margin: float = 48.0
## Extra padding beyond flashlight beam_range before an eye may spawn.
@export var reach_padding: float = 20.0
@export var spawn_attempts: int = 12

var _pool: Array[Node2D] = []
var _timer: float = 0.0
var _rect: Rect2 = Rect2()


func _ready() -> void:
	_rect = _level_rect()
	if eye_scene == null:
		eye_scene = load("res://Entity/vihrea_silma.tscn") as PackedScene
	for i in pool_size:
		var eye := eye_scene.instantiate() as Node2D
		add_child(eye)
		_pool.append(eye)
	_timer = randf_range(0.4, 1.2)
	set_process(_rect.size.x > 0.0)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = randf_range(spawn_interval_min, spawn_interval_max)
	if _visible_count() >= max_visible:
		return
	_try_spawn()


func _try_spawn() -> void:
	var eye := _free_eye()
	if eye == null:
		return
	var pos := _pick_spawn_point()
	if pos == Vector2.INF:
		return
	var hold := randf_range(hold_min, hold_max)
	if eye.has_method("appear_at"):
		eye.appear_at(pos, hold)


func _free_eye() -> Node2D:
	for eye in _pool:
		if eye != null and eye.has_method("is_busy") and not eye.is_busy():
			return eye
	return null


func _visible_count() -> int:
	var n := 0
	for eye in _pool:
		if eye != null and eye.has_method("is_busy") and eye.is_busy():
			n += 1
	return n


func _pick_spawn_point() -> Vector2:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var flashlight: Node = null
	if player != null:
		flashlight = player.get_node_or_null("Flashlight")
	var min_dist := 155.0 + reach_padding
	var origin := Vector2.ZERO
	if flashlight != null:
		origin = flashlight.global_position
		var br: Variant = flashlight.get("beam_range")
		if br != null:
			min_dist = float(br) + reach_padding
	elif player != null:
		origin = player.global_position

	var area := _rect.grow(-edge_margin)
	if area.size.x <= 8.0 or area.size.y <= 8.0:
		area = _rect

	for _i in spawn_attempts:
		var p := Vector2(
			randf_range(area.position.x, area.end.x),
			randf_range(area.position.y, area.end.y)
		)
		if player != null and p.distance_to(origin) < min_dist:
			continue
		return p
	return Vector2.INF


func _level_rect() -> Rect2:
	var tilemap := get_node_or_null(tilemap_path) as TileMapLayer
	if tilemap == null and get_parent() != null:
		tilemap = get_parent().get_node_or_null("TileMapLayer") as TileMapLayer
	if tilemap == null or tilemap.tile_set == null:
		return Rect2()
	var used := tilemap.get_used_rect()
	var tile_size := Vector2(tilemap.tile_set.tile_size)
	return Rect2(Vector2(used.position) * tile_size, Vector2(used.size) * tile_size)
