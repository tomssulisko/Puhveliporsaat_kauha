extends CharacterBody2D

enum State { HANGING, ALERT_DELAY, SCREECH_WAIT, FLYING }

@export var sense_radius: float = 18.0
@export var alert_delay: float = 0.25
@export var screech_wait: float = 0.5
@export var fly_speed: float = 160.0
@export var flap_sound_interval: float = 0.35

@onready var _anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var _sense: Area2D = $SenseArea

var _state: State = State.HANGING
var _fly_dir: Vector2 = Vector2.RIGHT
var _flap_timer: float = 0.0


func _ready() -> void:
	add_to_group("enemy")
	collision_layer = 0
	collision_mask = 0
	_anim.play("hang")
	# Keep sense shape in sync with export.
	var shape := _sense.get_node("CollisionShape2D").shape as CircleShape2D
	if shape != null:
		shape.radius = sense_radius


func _physics_process(delta: float) -> void:
	match _state:
		State.HANGING:
			if _is_lit():
				_begin_alert()
		State.FLYING:
			velocity = _fly_dir * fly_speed
			move_and_slide()
			_flap_timer -= delta
			if _flap_timer <= 0.0:
				_flap_timer = flap_sound_interval
				AudioManager.play_sfx_at("lepakko_lento", global_position)
		_:
			velocity = Vector2.ZERO


func _is_lit() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return false
	var flashlight := player.get_node_or_null("Flashlight")
	if flashlight == null or not flashlight.has_method("illuminates_point"):
		return false
	# Check bat body + a couple of sense offsets so thin cone still hits.
	if flashlight.illuminates_point(global_position):
		return true
	if flashlight.illuminates_point(_sense.global_position):
		return true
	return false


func _begin_alert() -> void:
	_state = State.ALERT_DELAY
	await get_tree().create_timer(alert_delay).timeout
	if not is_instance_valid(self):
		return

	_anim.play("fly")
	AudioManager.play_sfx_at("lepakko", global_position)
	_state = State.SCREECH_WAIT

	await get_tree().create_timer(screech_wait).timeout
	if not is_instance_valid(self):
		return

	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		_fly_dir = (player.global_position - global_position).normalized()
	else:
		_fly_dir = Vector2.RIGHT
	if _fly_dir == Vector2.ZERO:
		_fly_dir = Vector2.RIGHT

	_state = State.FLYING
	_flap_timer = 0.0
	# Face flight direction roughly (flip if going left).
	_anim.flip_h = _fly_dir.x < 0.0
