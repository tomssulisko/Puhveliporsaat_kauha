extends CharacterBody2D

enum State { HANGING, ALERT_DELAY, SCREECH_WAIT, FLYING }

@export var sense_radius: float = 18.0
@export var hit_radius: float = 12.0
@export var alert_delay: float = 0.25
@export var screech_wait: float = 0.5
@export var fly_speed: float = 160.0
@export var flap_sound_interval: float = 0.35
@export var despawn_margin: float = 48.0
@export var eye_fade_in: float = 0.12
@export var eye_fade_out: float = 0.08
@export var trail_fade: float = 0.22
@export var trail_start_alpha: float = 0.55
@export var trail_interval: float = 0.08

@onready var _anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var _eyes: Sprite2D = $Eyes
@onready var _sense: Area2D = $SenseArea
@onready var _hit: Area2D = $HitArea

var _state: State = State.HANGING
var _fly_dir: Vector2 = Vector2.RIGHT
var _flap_timer: float = 0.0
var _trail_timer: float = 0.0
var _level_rect: Rect2 = Rect2()
var _fly_origin: Vector2 = Vector2.ZERO
var _eye_alpha: float = 0.0
var _eye_tween: Tween


func _ready() -> void:
	add_to_group("enemy")
	collision_layer = 0
	collision_mask = 0
	_anim.play("hang")
	# Above darksumu fog (z=100) so alert eyes cut through the mist.
	_eyes.z_index = maxi(_eyes.z_index, 110)
	_eyes.light_mask = 0
	_set_eye_alpha(0.0)
	_level_rect = _resolve_level_rect()
	var sense_shape := _sense.get_node("CollisionShape2D").shape as CircleShape2D
	if sense_shape != null:
		sense_shape.radius = sense_radius
	var hit_shape := _hit.get_node("CollisionShape2D").shape as CircleShape2D
	if hit_shape != null:
		hit_shape.radius = hit_radius
	_hit.body_entered.connect(_on_hit_body_entered)


func _physics_process(delta: float) -> void:
	match _state:
		State.HANGING:
			velocity = Vector2.ZERO
			if _is_lit():
				_begin_alert()
		State.ALERT_DELAY, State.SCREECH_WAIT:
			velocity = Vector2.ZERO
			_update_alert_trail(delta)
		State.FLYING:
			velocity = _fly_dir * fly_speed
			move_and_slide()
			_check_player_overlap()
			if _is_outside_level():
				queue_free()
				return
			_flap_timer -= delta
			if _flap_timer <= 0.0:
				_flap_timer = flap_sound_interval
				AudioManager.play_sfx_at("lepakko_lento", global_position)


func _is_lit() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return false
	var flashlight := player.get_node_or_null("Flashlight")
	if flashlight == null or not flashlight.has_method("illuminates_point"):
		return false
	if flashlight.illuminates_point(global_position):
		return true
	if flashlight.illuminates_point(_sense.global_position):
		return true
	return false


func _begin_alert() -> void:
	_state = State.ALERT_DELAY
	_show_alert_eyes()
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

	_hide_alert_eyes()
	_state = State.FLYING
	_flap_timer = 0.0
	_fly_origin = global_position
	_anim.flip_h = _fly_dir.x < 0.0


func _show_alert_eyes() -> void:
	_kill_eye_tween()
	_trail_timer = 0.0
	_eye_tween = create_tween()
	_eye_tween.tween_method(_set_eye_alpha, _eye_alpha, 1.0, eye_fade_in)
	_spawn_trail()


func _hide_alert_eyes() -> void:
	_kill_eye_tween()
	_eye_tween = create_tween()
	_eye_tween.tween_method(_set_eye_alpha, _eye_alpha, 0.0, eye_fade_out)


func _update_alert_trail(delta: float) -> void:
	if _eye_alpha < 0.2:
		return
	_trail_timer -= delta
	if _trail_timer > 0.0:
		return
	_trail_timer = trail_interval
	_spawn_trail()


func _spawn_trail() -> void:
	if _eyes == null or _eyes.texture == null:
		return
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


func _set_eye_alpha(a: float) -> void:
	_eye_alpha = clampf(a, 0.0, 1.0)
	var c := _eyes.modulate
	c.a = _eye_alpha
	_eyes.modulate = c


func _kill_eye_tween() -> void:
	if _eye_tween != null and _eye_tween.is_valid():
		_eye_tween.kill()
	_eye_tween = null


func _on_hit_body_entered(body: Node2D) -> void:
	if _state != State.FLYING:
		return
	if body.is_in_group("player"):
		_kill_player()


func _check_player_overlap() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	if global_position.distance_to(player.global_position) <= hit_radius + 10.0:
		_kill_player()


func _kill_player() -> void:
	var app := get_node_or_null("/root/App")
	if app != null and app.has_method("trigger_player_death"):
		app.trigger_player_death()


func _is_outside_level() -> bool:
	if _level_rect.size.x <= 0.0 or _level_rect.size.y <= 0.0:
		# Fallback if no tilemap: despawn after flying far from takeoff.
		return global_position.distance_to(_fly_origin) > 700.0
	# Small margin so it clears the fog edge before vanishing.
	return not _level_rect.grow(despawn_margin).has_point(global_position)


func _resolve_level_rect() -> Rect2:
	var scene := get_tree().current_scene
	if scene == null:
		return Rect2()
	var tilemap := scene.get_node_or_null("TileMapLayer") as TileMapLayer
	if tilemap == null or tilemap.tile_set == null:
		return Rect2()
	var used := tilemap.get_used_rect()
	var tile_size := Vector2(tilemap.tile_set.tile_size)
	return Rect2(Vector2(used.position) * tile_size, Vector2(used.size) * tile_size)
