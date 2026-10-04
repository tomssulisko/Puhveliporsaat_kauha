extends Node2D

## Shared bootstrap for side maps (level 2–4).
@export var ambient_id: String = "tuuli"
@export var arrival_walk_distance: float = 160.0
@export var arrival_walk_seconds: float = 0.95
@export var arrival_start_offset: float = 45.0
@export var arrival_gate_grace: float = 0.45

@onready var player: CharacterBody2D = $Player


func _ready() -> void:
	# Lock before gates arm themselves (they defer monitoring one frame).
	for g in _all_gates():
		if g.has_method("set_gate_enabled"):
			g.set_gate_enabled(false)
	if not ambient_id.is_empty():
		AudioManager.play_ambient(ambient_id, 0.0, true)
	await _play_arrival_from_gate()


func _play_arrival_from_gate() -> void:
	var gate := _find_arrival_gate()
	if gate == null or player == null:
		for g in _all_gates():
			if g.has_method("set_gate_enabled"):
				g.set_gate_enabled(true)
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

	await get_tree().create_timer(arrival_gate_grace).timeout
	for g in _all_gates():
		if g.has_method("set_gate_enabled"):
			g.set_gate_enabled(true)


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
