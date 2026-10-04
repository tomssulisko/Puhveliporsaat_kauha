extends CharacterBody2D

enum State { IDLE, NOTICE_DELAY, FOLLOWING }

@export var hear_walk_radius: float = 90.0
@export var hear_sprint_radius: float = 220.0
@export var follow_speed: float = 45.0
@export var follow_duration: float = 3.5
@export var notice_delay: float = 0.55
@export var step_distance: float = 22.0
@export var hit_radius: float = 14.0
@export var move_noise_threshold: float = 8.0
@export var anim_fps: float = 6.0

@onready var _anim: AnimatedSprite2D = $AnimatedSprite2D

var _state: State = State.IDLE
var _follow_timer: float = 0.0
var _step_accum: float = 0.0
var _facing: StringName = &"eteen"
static var _tire_altar_done: bool = false


func _ready() -> void:
	add_to_group("enemy")
	collision_layer = 0
	collision_mask = 0
	if _anim.sprite_frames != null:
		for anim_name in _anim.sprite_frames.get_animation_names():
			_anim.sprite_frames.set_animation_speed(anim_name, anim_fps)
	_set_idle_pose()


func _physics_process(delta: float) -> void:
	_try_tire_altar_on_light()
	match _state:
		State.IDLE:
			velocity = Vector2.ZERO
			_set_idle_pose()
			if _can_hear_player():
				_begin_notice()
		State.NOTICE_DELAY:
			velocity = Vector2.ZERO
			_set_idle_pose()
		State.FOLLOWING:
			_process_follow(delta)


func _process_follow(delta: float) -> void:
	_follow_timer -= delta
	if _follow_timer <= 0.0:
		_state = State.IDLE
		velocity = Vector2.ZERO
		_step_accum = 0.0
		_set_idle_pose()
		return

	var player := _player()
	if player == null:
		velocity = Vector2.ZERO
		_set_idle_pose()
		return

	var dir := player.global_position - global_position
	if dir.length_squared() > 1.0:
		velocity = dir.normalized() * follow_speed
		_play_walk(dir)
	else:
		velocity = Vector2.ZERO
		_set_idle_pose()
	move_and_slide()
	_check_player_hit()

	_step_accum += velocity.length() * delta
	if _step_accum >= step_distance:
		_step_accum = 0.0
		AudioManager.play_sfx_at("luuranko", global_position)


func _check_player_hit() -> void:
	if _state != State.FOLLOWING:
		return
	var player := _player()
	if player == null:
		return
	if global_position.distance_to(player.global_position) <= hit_radius:
		_kill_player()


func _kill_player() -> void:
	var app := get_node_or_null("/root/App")
	if app != null and app.has_method("trigger_player_death"):
		app.trigger_player_death()


func _play_walk(dir: Vector2) -> void:
	_facing = _dir_to_anim(dir)
	if _anim.animation != _facing or not _anim.is_playing():
		_anim.play(_facing)


func _set_idle_pose() -> void:
	if _anim.animation != _facing:
		_anim.animation = _facing
	_anim.pause()
	_anim.frame = 0


func _dir_to_anim(dir: Vector2) -> StringName:
	if absf(dir.x) > absf(dir.y):
		return &"oikee" if dir.x > 0.0 else &"vasen"
	return &"eteen" if dir.y > 0.0 else &"takaa"


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


func _try_tire_altar_on_light() -> void:
	if _tire_altar_done:
		return
	if not _is_lit():
		return
	var manager := get_node_or_null("/root/StorylineManager")
	if manager == null or not manager.has_method("play_storyline_event"):
		return
	if bool(manager.play_storyline_event("tireAltar")):
		_tire_altar_done = true


func _is_lit() -> bool:
	var player := _player()
	if player == null:
		return false
	var flashlight := player.get_node_or_null("Flashlight")
	if flashlight == null or not flashlight.has_method("illuminates_point"):
		return false
	return bool(flashlight.illuminates_point(global_position))


func _player() -> CharacterBody2D:
	return get_tree().get_first_node_in_group("player") as CharacterBody2D
