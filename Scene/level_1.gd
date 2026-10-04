extends Node2D

const CAR_START := Vector2(-120, 587)
const CAR_STOP := Vector2(220, 587)
const PLAYER_EXIT := Vector2(280, 587)
const INTRO_DRIVE_SECONDS := 2.8

@onready var player: CharacterBody2D = $Player
@onready var auto: Node2D = $Auto
@onready var headlights: Node2D = $Auto/Headlights


func _ready() -> void:
	AudioManager.play_ambient("tuuli", 0.0, true)

	var manager := get_node_or_null("/root/StorylineManager")
	var intro_done: bool = manager != null and manager.events_played.has("carBroken")
	if intro_done:
		auto.global_position = CAR_STOP
		var app := get_node_or_null("/root/App")
		var reentry = app.consume_level1_reentry() if app != null and app.has_method("consume_level1_reentry") else null
		player.global_position = reentry if reentry is Vector2 else PLAYER_EXIT
		_set_headlights(false)
		_set_player_ambient(true)
		_set_flashlight_beam(true)
		_set_player_control(true)
	else:
		await _play_car_intro()


func _play_car_intro() -> void:
	_set_player_control(false)
	player.visible = false
	_set_player_ambient(false)
	_set_flashlight_beam(false)
	auto.global_position = CAR_START
	player.global_position = CAR_START
	_set_headlights(true)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(auto, "global_position", CAR_STOP, INTRO_DRIVE_SECONDS) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(player, "global_position", CAR_STOP, INTRO_DRIVE_SECONDS) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tween.finished

	# Small stall jolt before the car dies
	var jolt := create_tween()
	jolt.tween_property(auto, "global_position:x", CAR_STOP.x + 10.0, 0.08)
	jolt.tween_property(auto, "global_position:x", CAR_STOP.x - 4.0, 0.1)
	jolt.tween_property(auto, "global_position:x", CAR_STOP.x, 0.12)
	await jolt.finished
	_set_headlights(false)
	await get_tree().create_timer(0.35).timeout

	player.global_position = PLAYER_EXIT
	player.visible = true
	_set_player_ambient(true)
	_set_flashlight_beam(false)
	_set_player_control(true)

	await get_tree().process_frame
	var manager := get_node_or_null("/root/StorylineManager")
	if manager != null and manager.has_method("play_storyline_event"):
		manager.play_storyline_event("carBroken")
		if manager.has_signal("storyline_finished"):
			await manager.storyline_finished
	_set_flashlight_beam(true)


func _set_player_control(enabled: bool) -> void:
	if player.has_method("set_control_enabled"):
		player.set_control_enabled(enabled)
	player.set_physics_process(enabled)
	player.set_process(enabled)
	player.velocity = Vector2.ZERO


func _set_player_ambient(enabled: bool) -> void:
	var flashlight := player.get_node_or_null("Flashlight")
	if flashlight != null and flashlight.has_method("set_ambient_enabled"):
		flashlight.set_ambient_enabled(enabled)
	elif flashlight != null:
		flashlight.visible = enabled


func _set_flashlight_beam(enabled: bool) -> void:
	var flashlight := player.get_node_or_null("Flashlight")
	if flashlight != null and flashlight.has_method("set_beam_enabled"):
		flashlight.set_beam_enabled(enabled)


func _set_headlights(enabled: bool) -> void:
	if headlights == null:
		return
	headlights.visible = enabled
	for child in headlights.get_children():
		if child is Light2D:
			(child as Light2D).enabled = enabled
