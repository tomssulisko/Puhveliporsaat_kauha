extends CharacterBody2D

const WALK_SPEED := 100.0
const SPRINT_MULTIPLIER := 1.5
## Held against the torso / in the lap, not floating off to the side.
const CARRY_OFFSET := Vector2(0, -2)
const CARRY_STACK_STEP := Vector2(0, -5)
const MOVE_ANIM_THRESHOLD := 1.0

@export var anim_fps: float = 8.0
@export var step_distance: float = 22.0

var speed: float = WALK_SPEED
var input_direction := Vector2.ZERO
var control_enabled: bool = true

var _carry_root: Node2D
var _facing: StringName = &"eteen"
var _step_accum: float = 0.0

@onready var _anim: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	add_to_group("player")
	if _anim.sprite_frames != null:
		for anim_name in _anim.sprite_frames.get_animation_names():
			_anim.sprite_frames.set_animation_speed(anim_name, anim_fps)
	_set_idle_pose()
	_ensure_carry_root()
	call_deferred("_sync_carry_from_app")


func set_control_enabled(enabled: bool) -> void:
	control_enabled = enabled
	if not enabled:
		velocity = Vector2.ZERO
		input_direction = Vector2.ZERO
		_step_accum = 0.0
		_set_idle_pose()


func get_input() -> void:
	if not control_enabled:
		velocity = Vector2.ZERO
		return
	input_direction = Input.get_vector("left", "right", "up", "down")
	var current_speed := WALK_SPEED
	if Input.is_action_pressed("sprint"):
		current_speed *= SPRINT_MULTIPLIER
	speed = current_speed
	velocity = input_direction * current_speed


func _physics_process(delta: float) -> void:
	get_input()
	move_and_slide()
	_update_walk_animation()
	_update_footsteps(delta)


func _update_footsteps(delta: float) -> void:
	var moved := get_real_velocity().length() * delta
	if moved < 0.01:
		_step_accum = 0.0
		return
	_step_accum += moved
	if _step_accum >= step_distance:
		_step_accum = 0.0
		AudioManager.play_sfx("pelaaja_askeleet", -25.0)


func _update_walk_animation() -> void:
	if velocity.length_squared() > MOVE_ANIM_THRESHOLD * MOVE_ANIM_THRESHOLD:
		_play_walk(velocity)
	else:
		_set_idle_pose()


func _play_walk(dir: Vector2) -> void:
	_facing = _dir_to_anim(dir)
	_anim.flip_h = (_facing == &"vasen")
	var anim_name := &"oikee" if _facing == &"vasen" else _facing
	if _anim.animation != anim_name or not _anim.is_playing():
		_anim.play(anim_name)


func _set_idle_pose() -> void:
	_anim.flip_h = (_facing == &"vasen")
	var anim_name := &"oikee" if _facing == &"vasen" else _facing
	if _anim.animation != anim_name:
		_anim.animation = anim_name
	_anim.pause()
	_anim.frame = 0


func _dir_to_anim(dir: Vector2) -> StringName:
	if absf(dir.x) > absf(dir.y):
		return &"oikee" if dir.x > 0.0 else &"vasen"
	return &"eteen" if dir.y > 0.0 else &"takaa"


func sync_carried_items(items: Array) -> void:
	_ensure_carry_root()
	for child in _carry_root.get_children():
		child.queue_free()
	var i := 0
	for entry in items:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var tex: Texture2D = entry.get("texture") as Texture2D
		if tex == null:
			continue
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.z_index = 4
		var sc: Variant = entry.get("scale", Vector2.ONE)
		spr.scale = sc if sc is Vector2 else Vector2.ONE
		spr.position = CARRY_OFFSET + CARRY_STACK_STEP * float(i)
		_carry_root.add_child(spr)
		i += 1


func _sync_carry_from_app() -> void:
	var app := get_node_or_null("/root/App")
	if app != null and app.has_method("get_carried_items"):
		sync_carried_items(app.get_carried_items())


func _ensure_carry_root() -> void:
	if _carry_root != null and is_instance_valid(_carry_root):
		return
	_carry_root = get_node_or_null("CarriedItems") as Node2D
	if _carry_root == null:
		_carry_root = Node2D.new()
		_carry_root.name = "CarriedItems"
		add_child(_carry_root)
