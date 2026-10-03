extends Node2D

@export var follow_speed: float = 10.0

@onready var soft_light: PointLight2D = $SoftLight
@onready var beam: PointLight2D = $Beam

var _beam_enabled: bool = true


func _ready() -> void:
	set_beam_enabled(_beam_enabled)


func _process(delta: float) -> void:
	if not _beam_enabled:
		return
	var target_angle := global_position.angle_to_point(get_global_mouse_position())
	rotation = lerp_angle(rotation, target_angle, 1.0 - exp(-follow_speed * delta))


func set_beam_enabled(enabled: bool) -> void:
	_beam_enabled = enabled
	if beam != null:
		beam.enabled = enabled
	set_process(enabled)
	if not enabled:
		rotation = 0.0


func set_ambient_enabled(enabled: bool) -> void:
	visible = enabled
	if soft_light != null:
		soft_light.enabled = enabled
