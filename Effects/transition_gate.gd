extends Node2D

## Horizontal portal glow under darksumu, clipped to the level tile bounds.
## Player auto-walks into the gate before the scene changes.
@export_file("*.tscn") var target_scene: String = ""
@export var pulse_alpha_min: float = 0.4
@export var pulse_alpha_max: float = 1.0
@export var pulse_seconds: float = 1.8
@export var tilemap_path: NodePath
## Local direction the player walks when entering (RIGHT for level-1 exits).
@export var enter_direction: Vector2 = Vector2.RIGHT
@export var walk_distance: float = 90.0
@export var walk_seconds: float = 0.9

@onready var _glow_sprite: Sprite2D = $GlowSprite
@onready var _core_sprite: Sprite2D = $CoreSprite
@onready var _area: Area2D = $ExitArea

var _busy: bool = false


func _ready() -> void:
	# Below darksumu (~200) but above ground tiles.
	z_index = 50
	_glow_sprite.light_mask = 0
	_core_sprite.light_mask = 0
	_apply_level_clip()
	_offset_trigger_into_map()
	_area.body_entered.connect(_on_body_entered)
	_start_pulse()


func _offset_trigger_into_map() -> void:
	# Push the trigger zone opposite to enter_direction so it fires earlier.
	var shape_node := _area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		return
	var dir := enter_direction.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	shape_node.position = -dir * 55.0


func _apply_level_clip() -> void:
	var rect := _resolve_level_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	for sprite in [_glow_sprite, _core_sprite]:
		var mat := sprite.material as ShaderMaterial
		if mat == null:
			continue
		# Unique material instance so gates don't share uniforms.
		mat = mat.duplicate() as ShaderMaterial
		sprite.material = mat
		mat.set_shader_parameter("clip_min", rect.position)
		mat.set_shader_parameter("clip_max", rect.end)
		mat.set_shader_parameter("clip_feather", 10.0)


func _resolve_level_rect() -> Rect2:
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
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.get_node_or_null("TileMapLayer") as TileMapLayer


func _start_pulse() -> void:
	_set_pulse(pulse_alpha_max)
	var tween := create_tween()
	tween.set_loops()
	tween.tween_method(_set_pulse, pulse_alpha_max, pulse_alpha_min, pulse_seconds) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(_set_pulse, pulse_alpha_min, pulse_alpha_max, pulse_seconds) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _set_pulse(alpha: float) -> void:
	var t := inverse_lerp(pulse_alpha_min, pulse_alpha_max, alpha)
	_glow_sprite.modulate.a = alpha
	_core_sprite.modulate.a = lerpf(0.5, 1.0, t)


func _on_body_entered(body: Node2D) -> void:
	if _busy or body.name != "Player":
		return
	if target_scene.is_empty():
		push_warning("transition_gate: target_scene missing on %s" % get_path())
		return

	_busy = true
	var player := body as CharacterBody2D
	if player == null:
		_busy = false
		return

	# Remember the spot in front of the gate (before auto-walk).
	var scene := get_tree().current_scene
	if scene != null and scene.name == "Level1":
		var app := get_node_or_null("/root/App")
		if app != null and app.has_method("remember_level1_exit"):
			app.remember_level1_exit(player.global_position)

	await _walk_player_into_gate(player)

	var manager := get_node_or_null("/root/StorylineManager")
	if manager != null and manager.has_method("on_scene_about_to_change"):
		manager.on_scene_about_to_change()
	get_tree().change_scene_to_file(target_scene)


func _walk_player_into_gate(player: CharacterBody2D) -> void:
	if player.has_method("set_control_enabled"):
		player.set_control_enabled(false)
	else:
		player.set_physics_process(false)
	player.velocity = Vector2.ZERO

	var dir := enter_direction.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	# Align to gate height and walk past the glow into the dark.
	var target := Vector2(global_position.x, player.global_position.y) + dir * walk_distance

	var tween := create_tween()
	tween.tween_property(player, "global_position", target, walk_seconds) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished
