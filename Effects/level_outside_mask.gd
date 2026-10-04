extends Node2D

## Solid black bars just outside the tilemap so portal glow cannot leak off-map.
@export var tilemap_path: NodePath
@export var cover_depth: float = 240.0
@export var cover_z_index: int = 80


func _ready() -> void:
	z_index = cover_z_index
	var rect := _resolve_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	_build_covers(rect)


func _resolve_rect() -> Rect2:
	var tilemap := _find_tilemap()
	if tilemap != null and tilemap.tile_set != null:
		var used := tilemap.get_used_rect()
		var tile_size := Vector2(tilemap.tile_set.tile_size)
		return Rect2(Vector2(used.position) * tile_size, Vector2(used.size) * tile_size)
	return Rect2()


func _find_tilemap() -> TileMapLayer:
	if not tilemap_path.is_empty():
		var from_path := get_node_or_null(tilemap_path) as TileMapLayer
		if from_path != null:
			return from_path
	return get_parent().get_node_or_null("TileMapLayer") as TileMapLayer


func _build_covers(rect: Rect2) -> void:
	var d := cover_depth
	var left := rect.position.x
	var top := rect.position.y
	var right := rect.end.x
	var bottom := rect.end.y
	var mid_x := left + rect.size.x * 0.5
	var mid_y := top + rect.size.y * 0.5

	# Overlap corners so no gaps.
	_add_bar(Vector2(mid_x, top - d * 0.5), Vector2(rect.size.x + d * 2.0, d))
	_add_bar(Vector2(mid_x, bottom + d * 0.5), Vector2(rect.size.x + d * 2.0, d))
	_add_bar(Vector2(left - d * 0.5, mid_y), Vector2(d, rect.size.y))
	_add_bar(Vector2(right + d * 0.5, mid_y), Vector2(d, rect.size.y))


func _add_bar(center: Vector2, size: Vector2) -> void:
	var poly := Polygon2D.new()
	poly.color = Color(0, 0, 0, 1)
	poly.light_mask = 0
	poly.z_as_relative = false
	poly.z_index = cover_z_index
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	poly.polygon = PackedVector2Array([
		Vector2(-hx, -hy),
		Vector2(hx, -hy),
		Vector2(hx, hy),
		Vector2(-hx, hy),
	])
	poly.position = center
	add_child(poly)
