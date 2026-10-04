extends Node2D

## Skull helper by the car — fades in with a soft light orb, fades out after dialogue.

@export var anim_fps: float = 5.0
@export var fade_in_sec: float = 0.75
@export var fade_out_sec: float = 0.7
@export var light_energy_base: float = 0.7
@export var light_scale_base: float = 0.38

@onready var _anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var _light: PointLight2D = $Light

var _alpha: float = 0.0
var _tween: Tween
var _visible_state: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("auttaja")
	if _anim.sprite_frames != null and _anim.sprite_frames.has_animation("auttaja"):
		_anim.sprite_frames.set_animation_speed("auttaja", anim_fps)
		_anim.play("auttaja")
	_set_alpha(0.0)
	visible = false
	if _light != null:
		_light.enabled = false


func is_showing() -> bool:
	return _visible_state


func appear(duration: float = -1.0) -> void:
	var fade := fade_in_sec if duration < 0.0 else duration
	_kill_tween()
	visible = true
	_visible_state = true
	if _light != null:
		_light.enabled = true
	if _anim != null and not _anim.is_playing():
		_anim.play("auttaja")
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_method(_set_alpha, _alpha, 1.0, fade) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await _tween.finished


func disappear(duration: float = -1.0) -> void:
	if not _visible_state and _alpha <= 0.01:
		return
	var fade := fade_out_sec if duration < 0.0 else duration
	_kill_tween()
	_visible_state = false
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_method(_set_alpha, _alpha, 0.0, fade) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await _tween.finished
	if _alpha <= 0.01:
		visible = false
		if _light != null:
			_light.enabled = false


func _set_alpha(a: float) -> void:
	_alpha = clampf(a, 0.0, 1.0)
	if _anim != null:
		var c := _anim.modulate
		c.a = _alpha
		_anim.modulate = c
	if _light != null:
		_light.energy = light_energy_base * _alpha
		_light.texture_scale = light_scale_base * lerpf(0.7, 1.0, _alpha)
		_light.color.a = _alpha


func _kill_tween() -> void:
	if _tween != null and is_instance_valid(_tween):
		_tween.kill()
	_tween = null
