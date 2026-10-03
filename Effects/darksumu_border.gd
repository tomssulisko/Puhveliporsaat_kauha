extends Node2D

@export var fog_scene: PackedScene
@export var spacing: float = 50.0
@export var tilemap_path: NodePath
@export var manual_rect: Rect2 = Rect2()


func _ready() -> void:
	if fog_scene == null:
		return

	var rect := _resolve_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return

	_spawn_along_rect(rect)


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


func _spawn_along_rect(rect: Rect2) -> void:
	var left := rect.position.x
	var top := rect.position.y
	var right := rect.end.x
	var bottom := rect.end.y
	var perimeter := 2.0 * (rect.size.x + rect.size.y)
	var count := maxi(1, int(round(perimeter / spacing)))

	for i in count:
		var fog := fog_scene.instantiate() as Node2D
		fog.position = _point_on_rect_perimeter(left, top, right, bottom, float(i) / float(count))
		if fog.has_method("setup"):
			fog.setup(i % 2 == 0)
		add_child(fog)


func _point_on_rect_perimeter(left: float, top: float, right: float, bottom: float, t: float) -> Vector2:
	var width := right - left
	var height := bottom - top
	var dist := t * 2.0 * (width + height)

	if dist <= width:
		return Vector2(left + dist, top)
	dist -= width
	if dist <= height:
		return Vector2(right, top + dist)
	dist -= height
	if dist <= width:
		return Vector2(right - dist, bottom)
	dist -= width
	return Vector2(left, bottom - dist)
