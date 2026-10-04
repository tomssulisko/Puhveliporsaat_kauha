extends Node2D

## Portal glow under darksumu. Outside black mask clips any leak past the map.
## Player auto-walks into the gate before the scene changes.
@export_file("*.tscn") var target_scene: String = ""
@export var pulse_alpha_min: float = 0.1
@export var pulse_alpha_max: float = 0.2
@export var pulse_seconds: float = 1.8
@export var tilemap_path: NodePath
## Local direction the player walks when exiting through this gate.
@export var enter_direction: Vector2 = Vector2.RIGHT
@export var walk_distance: float = 90.0
@export var walk_seconds: float = 0.9

@onready var _glow_sprite: Sprite2D = $GlowSprite
@onready var _core_sprite: Sprite2D = $CoreSprite
@onready var _area: Area2D = $ExitArea

var _busy: bool = false


func _ready() -> void:
	# Above ground, below outside mask (80) and darksumu fog (100).
	z_index = 55
	_glow_sprite.light_mask = 0
	_core_sprite.light_mask = 0
	_ensure_unshaded(_glow_sprite)
	_ensure_unshaded(_core_sprite)
	_offset_trigger_into_map()
	_area.body_entered.connect(_on_body_entered)
	_start_pulse()
	# Stay inert one frame so side-level arrival can lock gates before arming.
	_area.monitoring = false
	call_deferred("_arm_gate_if_allowed")


func _ensure_unshaded(sprite: Sprite2D) -> void:
	var mat := sprite.material as CanvasItemMaterial
	if mat == null:
		mat = CanvasItemMaterial.new()
		sprite.material = mat
	else:
		mat = mat.duplicate() as CanvasItemMaterial
		sprite.material = mat
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD


func _arm_gate_if_allowed() -> void:
	if _busy:
		return
	if _area != null:
		_area.monitoring = true


## World-space direction used when walking out through this gate.
func get_exit_direction() -> Vector2:
	var local := enter_direction
	if local == Vector2.ZERO:
		local = Vector2.RIGHT
	var world := global_transform.basis_xform(local)
	if world.length_squared() < 0.0001:
		return Vector2.RIGHT
	return world.normalized()


func set_gate_enabled(enabled: bool) -> void:
	_busy = not enabled
	if _area != null:
		_area.monitoring = enabled


func _offset_trigger_into_map() -> void:
	var shape_node := _area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		return
	var dir := get_exit_direction()
	shape_node.position = global_transform.basis_xform_inv(-dir * 55.0)


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
	_core_sprite.modulate.a = lerpf(0.12, 0.24, t)


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

	var scene := get_tree().current_scene
	if scene != null and scene.name == "Level1":
		var app := get_node_or_null("/root/App")
		if app != null and app.has_method("remember_level1_exit"):
			app.remember_level1_exit(player.global_position, get_exit_direction())

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

	var dir := get_exit_direction()
	var target := player.global_position + dir * walk_distance
	if absf(dir.x) >= absf(dir.y):
		target.y = global_position.y
		target.x = global_position.x + dir.x * walk_distance
	else:
		target.x = global_position.x
		target.y = global_position.y + dir.y * walk_distance

	var tween := create_tween()
	tween.tween_property(player, "global_position", target, walk_seconds) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished
