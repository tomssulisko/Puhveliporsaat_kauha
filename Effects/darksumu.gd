extends Sprite2D

@export var base_speed: float = 0.18
@export var speed_variation: float = 0.12

var _angular_velocity: float = 0.0


func setup(clockwise: bool) -> void:
	var speed := base_speed + randf_range(-speed_variation, speed_variation)
	_angular_velocity = speed if clockwise else -speed
	rotation = randf() * TAU


func _process(delta: float) -> void:
	rotation += _angular_velocity * delta
