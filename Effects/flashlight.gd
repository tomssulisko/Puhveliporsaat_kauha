extends Node2D

@export var follow_speed: float = 10.0


func _process(delta: float) -> void:
	var target_angle := global_position.angle_to_point(get_global_mouse_position())
	rotation = lerp_angle(rotation, target_angle, 1.0 - exp(-follow_speed * delta))
