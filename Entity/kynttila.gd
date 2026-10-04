extends Node2D

@export var anim_fps: float = 6.0
@export var light_energy_base: float = 0.85
@export var light_energy_amp: float = 0.18
@export var light_scale_base: float = 0.275
@export var light_scale_amp: float = 0.04
@export var flicker_speed: float = 1.15
@export var flicker_speed_b: float = 1.85

@onready var _anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var _light: PointLight2D = $Light

var _t: float = 0.0
var _phase: float = 0.0


func _ready() -> void:
	_phase = randf() * TAU
	_t = randf() * 10.0
	if _anim.sprite_frames != null and _anim.sprite_frames.has_animation("burn"):
		_anim.sprite_frames.set_animation_speed("burn", anim_fps)
		_anim.play("burn")
	_apply_light(0.0)


func _process(delta: float) -> void:
	_t += delta
	_apply_light(delta)


func _apply_light(_delta: float) -> void:
	if _light == null:
		return
	# Slow dual-sine fluctuation so the glow breathes instead of strobing.
	var a := sin(_t * flicker_speed + _phase)
	var b := sin(_t * flicker_speed_b + _phase * 1.7)
	var wave := 0.65 * a + 0.35 * b
	_light.energy = light_energy_base + light_energy_amp * wave
	var s := light_scale_base + light_scale_amp * wave
	_light.texture_scale = s
