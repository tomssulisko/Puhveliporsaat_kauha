extends CharacterBody2D

enum State { IDLE, NOTICE_DELAY, FOLLOWING }

@export var hear_walk_radius: float = 90.0
@export var hear_sprint_radius: float = 220.0
@export var follow_speed: float = 45.0
@export var follow_duration: float = 3.5
@export var notice_delay: float = 0.55
@export var step_distance: float = 22.0
@export var move_noise_threshold: float = 8.0

@onready var _sprite: Sprite2D = $Sprite2D

var _state: State = State.IDLE
var _follow_timer: float = 0.0
var _step_accum: float = 0.0


func _ready() -> void:
	add_to_group("enemy")
	collision_layer = 0
	collision_mask = 0


func _physics_process(delta: float) -> void:
	match _state:
		State.IDLE:
			velocity = Vector2.ZERO
			if _can_hear_player():
				_begin_notice()
		State.NOTICE_DELAY:
			velocity = Vector2.ZERO
		State.FOLLOWING:
			_process_follow(delta)


func _process_follow(delta: float) -> void:
	_follow_timer -= delta
	if _follow_timer <= 0.0:
		_state = State.IDLE
		velocity = Vector2.ZERO
		_step_accum = 0.0
		return

	var player := _player()
	if player == null:
		velocity = Vector2.ZERO
		return

	var dir := player.global_position - global_position
	if dir.length_squared() > 1.0:
		velocity = dir.normalized() * follow_speed
		_sprite.flip_h = dir.x < 0.0
	else:
		velocity = Vector2.ZERO
	move_and_slide()

	_step_accum += velocity.length() * delta
	if _step_accum >= step_distance:
		_step_accum = 0.0
		AudioManager.play_sfx_at("luuranko", global_position)


func _begin_notice() -> void:
	_state = State.NOTICE_DELAY
	AudioManager.play_sfx_at("luuranko", global_position)
	await get_tree().create_timer(notice_delay).timeout
	if not is_instance_valid(self):
		return
	if _state != State.NOTICE_DELAY:
		return
	_state = State.FOLLOWING
	_follow_timer = follow_duration
	_step_accum = 0.0


func _can_hear_player() -> bool:
	var player := _player()
	if player == null:
		return false
	var moving_speed := player.velocity.length()
	if moving_speed < move_noise_threshold:
		return false
	var dist := global_position.distance_to(player.global_position)
	var radius := hear_walk_radius
	# Sprint is faster than walk; player.speed is set each frame in get_input().
	if player.speed > player.WALK_SPEED * 1.25:
		radius = hear_sprint_radius
	return dist <= radius


func _player() -> CharacterBody2D:
	return get_tree().get_first_node_in_group("player") as CharacterBody2D
