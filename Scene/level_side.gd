extends Node2D

## Shared bootstrap for side maps (level 2–4).
@export var ambient_id: String = "tuuli"
@export var quest_item_id: String = ""
@export var arrival_walk_distance: float = 160.0
@export var arrival_walk_seconds: float = 0.95
@export var arrival_start_offset: float = 45.0
@export var gate_fade_seconds: float = 0.8

@onready var player: CharacterBody2D = $Player


func _ready() -> void:
	_ensure_storyline_canvas()
	# Lock before gates arm themselves (they defer monitoring one frame).
	for g in _all_gates():
		if g.has_method("set_gate_enabled"):
			g.set_gate_enabled(false)
	if not ambient_id.is_empty():
		AudioManager.play_ambient(ambient_id, 0.0, true)
	await _play_arrival_from_gate()


func _ensure_storyline_canvas() -> void:
	if get_node_or_null("StorylineCanvas") != null:
		return
	var canvas := preload("res://addons/Storyline/storyline_canvas.tscn").instantiate()
	canvas.name = "StorylineCanvas"
	add_child(canvas)


func _play_arrival_from_gate() -> void:
	var gate := _find_arrival_gate()
	if gate == null or player == null:
		_sync_exit_gate(false)
		return

	# Walk from the portal toward the level interior so we never re-trigger exit.
	var into_map := _direction_into_map(gate)
	if into_map == Vector2.ZERO:
		into_map = Vector2.RIGHT

	if player.has_method("set_control_enabled"):
		player.set_control_enabled(false)
	player.velocity = Vector2.ZERO

	var start := gate.global_position - into_map * arrival_start_offset
	var end := gate.global_position + into_map * arrival_walk_distance
	if absf(into_map.x) >= absf(into_map.y):
		start.y = gate.global_position.y
		end.y = gate.global_position.y
	else:
		start.x = gate.global_position.x
		end.x = gate.global_position.x

	player.global_position = start

	var tween := create_tween()
	tween.tween_property(player, "global_position", end, arrival_walk_seconds) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished

	if player.has_method("set_control_enabled"):
		player.set_control_enabled(true)

	# Close behind the player until the quest item is found (or reopen if already held).
	_sync_exit_gate(true)


func on_quest_item_found(item_id: String) -> void:
	if item_id.is_empty() or item_id != _resolve_quest_item_id():
		return
	_set_exit_gate_open(true, true)


func _sync_exit_gate(animate: bool) -> void:
	_set_exit_gate_open(_has_quest_item(), animate)


func _set_exit_gate_open(open: bool, animate: bool) -> void:
	for g in _all_gates():
		if g.has_method("set_gate_open"):
			g.set_gate_open(open, animate, gate_fade_seconds)
		elif g.has_method("set_gate_enabled"):
			g.set_gate_enabled(open)


func _has_quest_item() -> bool:
	var id := _resolve_quest_item_id()
	if id.is_empty():
		return true
	var app := get_node_or_null("/root/App")
	if app == null:
		return false
	if app.has_method("is_item_gone_from_world"):
		return app.is_item_gone_from_world(id)
	return false


func _resolve_quest_item_id() -> String:
	if not quest_item_id.is_empty():
		return quest_item_id
	for child in get_children():
		if child == null:
			continue
		var id: Variant = child.get("item_id")
		if id is String and not String(id).is_empty():
			return String(id)
	return ""


func _direction_into_map(gate: Node2D) -> Vector2:
	# Prefer opposite of the gate's exit walk — that should face the playable area.
	if gate.has_method("get_exit_direction"):
		var exit_dir: Vector2 = gate.get_exit_direction()
		if exit_dir != Vector2.ZERO:
			var toward_map := -exit_dir
			# If that still points off the tilemap, fall back to map center.
			var rect := _level_rect()
			if rect.size.x > 0.0 and rect.size.y > 0.0:
				var test_point := gate.global_position + toward_map * 80.0
				if rect.has_point(test_point):
					return toward_map
				var to_center := rect.get_center() - gate.global_position
				if to_center.length_squared() > 0.001:
					return to_center.normalized()
			return toward_map

	var rect2 := _level_rect()
	if rect2.size.x > 0.0 and rect2.size.y > 0.0:
		var to_c := rect2.get_center() - gate.global_position
		if to_c.length_squared() > 0.001:
			return to_c.normalized()
	return Vector2.RIGHT


func _level_rect() -> Rect2:
	var tilemap := get_node_or_null("TileMapLayer") as TileMapLayer
	if tilemap == null or tilemap.tile_set == null:
		return Rect2()
	var used := tilemap.get_used_rect()
	var tile_size := Vector2(tilemap.tile_set.tile_size)
	return Rect2(Vector2(used.position) * tile_size, Vector2(used.size) * tile_size)


func _find_arrival_gate() -> Node2D:
	for child in get_children():
		if not child.has_method("get_exit_direction"):
			continue
		var target: Variant = child.get("target_scene")
		if target is String and String(target).contains("level_1"):
			return child as Node2D
	for child in get_children():
		if child.has_method("get_exit_direction"):
			return child as Node2D
	return null


func _all_gates() -> Array[Node]:
	var out: Array[Node] = []
	for child in get_children():
		if child.has_method("set_gate_enabled") or child.has_method("get_exit_direction"):
			out.append(child)
	return out
