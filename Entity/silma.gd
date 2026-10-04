extends CharacterBody2D

enum State { IDLE, CHASING, HIDING }

@export var detect_radius: float = 130.0
@export var reactivate_radius: float = 220.0
@export var hit_radius: float = 14.0
@export var chase_speed_start: float = 55.0
@export var chase_speed_max: float = 110.0
@export var chase_accel: float = 28.0
@export var growl_interval_min: float = 2.8
@export var growl_interval_max: float = 5.5
@export var glint_interval_min: float = 2.5
@export var glint_interval_max: float = 9.0
@export var glint_fade_in: float = 0.4
@export var glint_hold: float = 0.35
@export var glint_fade_out: float = 0.55
@export var hide_fade_out: float = 0.5
@export var step_distance: float = 26.0
@export var body_flash_duration: float = 0.28
@export var trail_spacing: float = 10.0
@export var trail_fade: float = 0.22
@export var trail_start_alpha: float = 0.65

@onready var _eyes: Sprite2D = $Eyes
@onready var _body: Sprite2D = $BodyFlash
@onready var _hit: Area2D = $HitArea

var _state: State = State.IDLE
var _eye_alpha: float = 0.0
var _glint_tween: Tween
var _glint_timer: float = 0.0
var _growl_timer: float = 0.0
var _step_accum: float = 0.0
var _trail_accum: float = 0.0
var _current_speed: float = 0.0
var _hiding_locked: bool = false


func _ready() -> void:
	add_to_group("enemy")
	collision_layer = 0
	collision_mask = 0
	_set_eye_alpha(0.0)
	_body.modulate.a = 0.0
	_glint_timer = randf_range(glint_interval_min, glint_interval_max)
	var hit_shape := _hit.get_node("CollisionShape2D").shape as CircleShape2D
	if hit_shape != null:
		hit_shape.radius = hit_radius
	_hit.body_entered.connect(_on_hit_body_entered)


func _physics_process(delta: float) -> void:
	match _state:
		State.IDLE:
			velocity = Vector2.ZERO
			_process_idle(delta)
		State.CHASING:
			_process_chase(delta)
		State.HIDING:
			velocity = Vector2.ZERO
			_process_hiding(delta)


func _process_idle(delta: float) -> void:
	# Light only scares when eyes are actually showing (or mid-glint).
	if _eye_alpha > 0.05 and _is_lit():
		_begin_hide()
		return

	var player := _player()
	if player != null and global_position.distance_to(player.global_position) <= detect_radius:
		# Don't aggro while the flashlight is on them.
		if not _is_lit():
			_begin_chase()
		return

	_glint_timer -= delta
	if _glint_timer <= 0.0 and (_glint_tween == null or not _glint_tween.is_running()):
		_play_glint()
		_glint_timer = randf_range(glint_interval_min, glint_interval_max)


func _process_chase(delta: float) -> void:
	if _is_lit():
		_begin_hide()
		return

	var player := _player()
	if player == null:
		velocity = Vector2.ZERO
		return

	_current_speed = minf(_current_speed + chase_accel * delta, chase_speed_max)
	var dir := (player.global_position - global_position)
	if dir.length_squared() > 0.001:
		dir = dir.normalized()
		velocity = dir * _current_speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()

	var moved := velocity.length() * delta
	_step_accum += moved
	if _step_accum >= step_distance:
		_step_accum = 0.0
		AudioManager.play_sfx_at("silma_askeleet", global_position)

	_trail_accum += moved
	if _trail_accum >= trail_spacing:
		_trail_accum = 0.0
		_spawn_trail()

	_growl_timer -= delta
	if _growl_timer <= 0.0:
		_growl_timer = randf_range(growl_interval_min, growl_interval_max)
		AudioManager.play_sfx_at("silmat", global_position)

	_check_player_overlap()


func _process_hiding(_delta: float) -> void:
	if _hiding_locked:
		return
	if _is_lit():
		return
	var player := _player()
	if player == null:
		return
	if global_position.distance_to(player.global_position) >= reactivate_radius:
		_state = State.IDLE
		_glint_timer = randf_range(0.8, 2.0)
		_set_eye_alpha(0.0)


func _begin_chase() -> void:
	_kill_glint_tween()
	_state = State.CHASING
	_current_speed = chase_speed_start
	_step_accum = 0.0
	_trail_accum = 0.0
	_growl_timer = randf_range(growl_interval_min, growl_interval_max)
	_set_eye_alpha(1.0)
	AudioManager.play_sfx_at("silmat", global_position)


func _spawn_trail() -> void:
	var ghost := Sprite2D.new()
	ghost.texture = _eyes.texture
	ghost.texture_filter = _eyes.texture_filter
	ghost.scale = _eyes.scale
	ghost.z_index = _eyes.z_index
	ghost.light_mask = 0
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	ghost.material = mat
	ghost.global_position = _eyes.global_position
	var c := _eyes.modulate
	c.a = trail_start_alpha * _eye_alpha
	ghost.modulate = c
	var parent := get_parent()
	if parent == null:
		ghost.queue_free()
		return
	parent.add_child(ghost)
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, trail_fade)
	tw.tween_callback(ghost.queue_free)


func _begin_hide() -> void:
	if _state == State.HIDING:
		return
	_state = State.HIDING
	_hiding_locked = true
	_kill_glint_tween()
	velocity = Vector2.ZERO
	_current_speed = 0.0
	_step_accum = 0.0
	_trail_accum = 0.0
	AudioManager.play_sfx_at("silma_katoaa", global_position)
	_flash_body()

	_glint_tween = create_tween()
	_glint_tween.tween_method(_set_eye_alpha, _eye_alpha, 0.0, hide_fade_out)
	await _glint_tween.finished
	if not is_instance_valid(self):
		return
	_set_eye_alpha(0.0)
	# Stay invisible at this spot until player is far and light is off.
	await get_tree().create_timer(0.35).timeout
	if not is_instance_valid(self):
		return
	_hiding_locked = false


func _play_glint() -> void:
	_kill_glint_tween()
	_glint_tween = create_tween()
	_glint_tween.tween_method(_set_eye_alpha, 0.0, 1.0, glint_fade_in)
	_glint_tween.tween_interval(glint_hold)
	_glint_tween.tween_method(_set_eye_alpha, 1.0, 0.0, glint_fade_out)


func _flash_body() -> void:
	_body.modulate.a = 0.85
	var tw := create_tween()
	tw.tween_property(_body, "modulate:a", 0.0, body_flash_duration)


func _set_eye_alpha(a: float) -> void:
	_eye_alpha = clampf(a, 0.0, 1.0)
	var c := _eyes.modulate
	c.a = _eye_alpha
	_eyes.modulate = c


func _kill_glint_tween() -> void:
	if _glint_tween != null and _glint_tween.is_valid():
		_glint_tween.kill()
	_glint_tween = null


func _is_lit() -> bool:
	var player := _player()
	if player == null:
		return false
	var flashlight := player.get_node_or_null("Flashlight")
	if flashlight == null or not flashlight.has_method("illuminates_point"):
		return false
	return flashlight.illuminates_point(global_position)


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


func _on_hit_body_entered(body: Node2D) -> void:
	if _state != State.CHASING:
		return
	if body.is_in_group("player"):
		_kill_player()


func _check_player_overlap() -> void:
	var player := _player()
	if player == null:
		return
	if global_position.distance_to(player.global_position) <= hit_radius + 10.0:
		_kill_player()


func _kill_player() -> void:
	var app := get_node_or_null("/root/App")
	if app != null and app.has_method("trigger_player_death"):
		app.trigger_player_death()
