extends Node2D

@export var tilemap_path: NodePath
@export var manual_rect: Rect2 = Rect2()
@export var wall_thickness: float = 80.0
@export var story_event: String = "edgeRefuse"

var _walls: Array[StaticBody2D] = []
var _story_played := false


func _ready() -> void:
	var rect := _resolve_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	_build_walls(rect)


func _physics_process(_delta: float) -> void:
	if _story_played:
		return
	var player := get_parent().get_node_or_null("Player") as CharacterBody2D
	if player == null:
		return
	# Skip while portal auto-walk (or any forced move) has control locked.
	if player.get("control_enabled") == false:
		return
	for i in player.get_slide_collision_count():
		var collider := player.get_slide_collision(i).get_collider()
		if collider is StaticBody2D and _walls.has(collider):
			_try_play_story()
			return


func _resolve_rect() -> Rect2:
	var tilemap := _find_tilemap()
	if tilemap != null and tilemap.tile_set != null:
		var used := tilemap.get_used_rect()
		var tile_size := Vector2(tilemap.tile_set.tile_size)
		return Rect2(Vector2(used.position) * tile_size, Vector2(used.size) * tile_size)
	return manual_rect


func _find_tilemap() -> TileMapLayer:
	if not tilemap_path.is_empty():
		var from_path := get_node_or_null(tilemap_path) as TileMapLayer
		if from_path != null:
			return from_path
	return get_parent().get_node_or_null("TileMapLayer") as TileMapLayer


func _build_walls(rect: Rect2) -> void:
	var left := rect.position.x
	var top := rect.position.y
	var right := rect.end.x
	var bottom := rect.end.y
	var t := wall_thickness
	var mid_x := left + rect.size.x * 0.5
	var mid_y := top + rect.size.y * 0.5

	_add_static_wall(Vector2(mid_x, top - t * 0.5), Vector2(rect.size.x + t * 2.0, t))
	_add_static_wall(Vector2(mid_x, bottom + t * 0.5), Vector2(rect.size.x + t * 2.0, t))
	_add_static_wall(Vector2(left - t * 0.5, mid_y), Vector2(t, rect.size.y))
	_add_static_wall(Vector2(right + t * 0.5, mid_y), Vector2(t, rect.size.y))


func _add_static_wall(center: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = center
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)
	add_child(body)
	_walls.append(body)


func _try_play_story() -> void:
	if story_event.is_empty():
		return
	var manager := get_node_or_null("/root/StorylineManager")
	if manager == null or not manager.has_method("play_storyline_event"):
		return
	if manager.play_storyline_event(story_event):
		_story_played = true
	elif manager.get("events_played") is Array and manager.events_played.has(story_event):
		_story_played = true
