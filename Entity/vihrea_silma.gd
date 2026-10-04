extends Node2D

## Ambient green eye glint — fades in/out, snaps off when the beam could reach them.
signal finished

@export var fade_in: float = 0.55
@export var fade_out: float = 0.7
@export var scare_fade: float = 0.12

@onready var _eyes: Sprite2D = $Eyes

var _alpha: float = 0.0
var _tween: Tween
var _active: bool = false
var _busy: bool = false


func _ready() -> void:
	_set_alpha(0.0)
	visible = false
	set_process(false)


func is_busy() -> bool:
	return _busy


func appear_at(world_pos: Vector2, hold_seconds: float) -> void:
	if _busy:
		return
	_busy = true
	_active = true
	global_position = world_pos
	visible = true
	set_process(true)
	_kill_tween()
	_tween = create_tween()
	_tween.tween_method(_set_alpha, 0.0, 1.0, fade_in)
	_tween.tween_interval(hold_seconds)
	_tween.tween_method(_set_alpha, 1.0, 0.0, fade_out)
	_tween.tween_callback(_finish)


func _process(_delta: float) -> void:
	if not _active:
		return
	if _alpha > 0.02 and _in_beam_reach():
		_scare_off()


func _scare_off() -> void:
	if not _active:
		return
	_active = false
	_kill_tween()
	_tween = create_tween()
	_tween.tween_method(_set_alpha, _alpha, 0.0, scare_fade)
	_tween.tween_callback(_finish)


func _finish() -> void:
	_active = false
	_busy = false
	_set_alpha(0.0)
	visible = false
	set_process(false)
	_kill_tween()
	finished.emit()


func _set_alpha(a: float) -> void:
	_alpha = clampf(a, 0.0, 1.0)
	var c := _eyes.modulate
	c.a = _alpha
	_eyes.modulate = c


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _in_beam_reach() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return false
	var flashlight := player.get_node_or_null("Flashlight")
	if flashlight == null:
		return false
	if flashlight.has_method("is_beam_enabled") and not flashlight.is_beam_enabled():
		return false
	var reach: float = float(flashlight.get("beam_range")) if flashlight.get("beam_range") != null else 155.0
	return global_position.distance_to(flashlight.global_position) <= reach
