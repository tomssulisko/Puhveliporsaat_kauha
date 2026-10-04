extends CharacterBody2D

const WALK_SPEED := 100.0
const SPRINT_MULTIPLIER := 2.0

var speed: float = WALK_SPEED
var input_direction := Vector2.ZERO


func get_input() -> void:
	input_direction = Input.get_vector("left", "right", "up", "down")
	var current_speed := WALK_SPEED
	if Input.is_action_pressed("sprint"):
		current_speed *= SPRINT_MULTIPLIER
	speed = current_speed
	velocity = input_direction * current_speed


func _physics_process(_delta: float) -> void:
	get_input()
	move_and_slide()
