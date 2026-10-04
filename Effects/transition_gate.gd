extends Node2D

## Narrow additive portal slit drawn ABOVE darksumu (z > fog).
@export_file("*.tscn") var target_scene: String = ""
@export var pulse_alpha_min: float = 0.4
@export var pulse_alpha_max: float = 1.0
@export var pulse_seconds: float = 1.8

@onready var _glow_sprite: Sprite2D = $GlowSprite
@onready var _core_sprite: Sprite2D = $CoreSprite
@onready var _area: Area2D = $ExitArea


func _ready() -> void:
	# Fog border is z=100 with children z=100 (relative → ~200). Stay above that.
	z_index = 300
	_glow_sprite.z_as_relative = false
	_core_sprite.z_as_relative = false
	_glow_sprite.z_index = 301
	_core_sprite.z_index = 302
	_glow_sprite.light_mask = 0
	_core_sprite.light_mask = 0

	_area.body_entered.connect(_on_body_entered)
	_start_pulse()


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
	if body.name != "Player":
		return
	if target_scene.is_empty():
		push_warning("transition_gate: target_scene missing on %s" % get_path())
		return

	var scene := get_tree().current_scene
	if scene != null and scene.name == "Level1":
		var app := get_node_or_null("/root/App")
		if app != null and app.has_method("remember_level1_exit"):
			app.remember_level1_exit(body.global_position)

	var manager := get_node_or_null("/root/StorylineManager")
	if manager != null and manager.has_method("on_scene_about_to_change"):
		manager.on_scene_about_to_change()
	get_tree().change_scene_to_file(target_scene)
