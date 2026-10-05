extends Node2D

const CAR_START := Vector2(-120, 587)
const CAR_STOP := Vector2(220, 587)
const CAR_EXIT := Vector2(720, 587)
## Exit spawn beside the car (closer than Auttaja so it's clear who drove).
const PLAYER_EXIT := Vector2(249, 603)
const INTRO_DRIVE_SECONDS := 2.8
const ENDING_DRIVE_SECONDS := 3.4
const AUTTAJA_DISMISS_DELAY := 0.55

@onready var player: CharacterBody2D = $Player
@onready var auto: Node2D = $Auto
@onready var headlights: Node2D = $Auto/Headlights
@onready var auttaja: Node2D = $Auttaja


func _ready() -> void:
	# Keep portals inert until progression decides which one is open.
	for gate in [$TransitionLevel2, $TransitionLevel3, $TransitionLevel4]:
		if gate == null:
			continue
		gate.visible = false
		if gate.has_method("set_gate_open"):
			gate.set_gate_open(false, false, 0.75, false)
		elif gate.has_method("set_gate_enabled"):
			gate.set_gate_enabled(false)

	var app := get_node_or_null("/root/App")
	var from_death: bool = app != null and bool(app.get("pending_death_dream"))
	if from_death and app.has_method("prepare_level1_after_death"):
		app.prepare_level1_after_death()

	var manager := get_node_or_null("/root/StorylineManager")
	var intro_done: bool = manager != null and manager.events_played.has("carBroken")
	if intro_done or from_death:
		AudioManager.play_ambient("tuuli", 0.0, true)
		auto.global_position = CAR_STOP
		var reentry: Variant = null
		if not from_death and app != null and app.has_method("consume_level1_reentry"):
			reentry = app.consume_level1_reentry()
		player.global_position = reentry if reentry is Vector2 else PLAYER_EXIT
		_set_headlights(false)
		_set_player_ambient(true)
		_set_flashlight_beam(true)
		_set_player_control(true)
		if app != null and app.has_method("spawn_level1_death_drops"):
			app.spawn_level1_death_drops(self)
		var returning_with_item := reentry is Vector2 and _player_has_carried_item(app)
		if returning_with_item:
			await _seal_return_portal()
			show_auttaja()
		else:
			update_portal_gates()
		if from_death and app != null and app.has_method("finish_level1_after_death"):
			await app.finish_level1_after_death()
	else:
		await _play_car_intro()
		update_portal_gates()


func _play_car_intro() -> void:
	_set_player_control(false)
	player.visible = false
	_set_player_ambient(false)
	_set_flashlight_beam(false)
	auto.global_position = CAR_START
	player.global_position = CAR_START
	_set_headlights(true)
	AudioManager.play_looping_sfx("auto_ajo")

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
	AudioManager.stop_looping_sfx()
	AudioManager.play_sfx("fart")
	_set_headlights(false)
	await get_tree().create_timer(0.2).timeout
	AudioManager.play_ambient("tuuli", 0.0, true, 1.8)
	await get_tree().create_timer(0.35).timeout

	player.global_position = PLAYER_EXIT
	player.visible = true
	_set_player_ambient(true)
	_set_flashlight_beam(false)
	_set_player_control(true)

	await get_tree().process_frame
	show_auttaja()
	var manager := get_node_or_null("/root/StorylineManager")
	if manager != null and manager.has_method("play_storyline_event"):
		manager.play_storyline_event("carBroken")
		if manager.has_signal("storyline_finished"):
			await manager.storyline_finished
	await dismiss_auttaja()
	_set_flashlight_beam(true)


func show_auttaja() -> void:
	if auttaja != null and auttaja.has_method("appear"):
		auttaja.appear()


func dismiss_auttaja() -> void:
	await get_tree().create_timer(AUTTAJA_DISMISS_DELAY).timeout
	if auttaja != null and auttaja.has_method("disappear"):
		await auttaja.disappear()


func _player_has_carried_item(app: Node) -> bool:
	if app == null:
		return false
	if app.has_method("get_carried_items"):
		return not app.get_carried_items().is_empty()
	return false


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


func update_portal_gates() -> void:
	var app := get_node_or_null("/root/App")
	var stage := 0
	if app != null and app.has_method("get_portal_stage"):
		stage = int(app.get_portal_stage())
	_set_portal_active($TransitionLevel3, stage == 0)
	_set_portal_active($TransitionLevel2, stage == 1)
	_set_portal_active($TransitionLevel4, stage == 2)


## Close the portal the player just came through (with reitin_avaus SFX).
func _seal_return_portal() -> void:
	var app := get_node_or_null("/root/App")
	var stage := 0
	if app != null and app.has_method("get_portal_stage"):
		stage = int(app.get_portal_stage())
	var gates: Array[Node] = [$TransitionLevel3, $TransitionLevel2, $TransitionLevel4]
	for i in range(gates.size()):
		var gate := gates[i]
		if gate == null:
			continue
		if i == stage and stage < 3:
			gate.visible = true
			if gate.has_method("set_gate_open"):
				# Force open silently, then close with fade + sound.
				gate.set_gate_open(true, false, 0.75, false)
				await get_tree().create_timer(0.35).timeout
				gate.set_gate_open(false, true, 0.85, true)
		else:
			gate.visible = false
			if gate.has_method("set_gate_open"):
				gate.set_gate_open(false, false, 0.75, false)
			elif gate.has_method("set_gate_enabled"):
				gate.set_gate_enabled(false)


func _set_portal_active(gate: Node, active: bool) -> void:
	if gate == null:
		return
	gate.visible = active
	if gate.has_method("set_gate_open"):
		gate.set_gate_open(active, true)
	elif gate.has_method("set_gate_enabled"):
		gate.set_gate_enabled(active)


## After the last item (tire) is returned: enter car, lights on, drive off, credits.
func play_ending() -> void:
	_set_player_control(false)
	for gate in [$TransitionLevel2, $TransitionLevel3, $TransitionLevel4]:
		_set_portal_active(gate, false)

	var board_pos := auto.global_position + Vector2(18, 0)
	if player.global_position.distance_to(board_pos) > 12.0:
		var walk := create_tween()
		walk.tween_property(player, "global_position", board_pos, 0.55) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await walk.finished

	player.visible = false
	_set_player_ambient(false)
	_set_flashlight_beam(false)
	await get_tree().create_timer(0.35).timeout

	_set_headlights(true)
	await get_tree().create_timer(0.45).timeout

	AudioManager.play_sfx("auto_ajo")
	var drive := create_tween()
	drive.tween_property(auto, "global_position", CAR_EXIT, ENDING_DRIVE_SECONDS) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	await get_tree().create_timer(ENDING_DRIVE_SECONDS * 0.4).timeout
	var app := get_node_or_null("/root/App")
	if app != null and app.has_method("fade_to_black"):
		await app.fade_to_black(1.2)
	if drive.is_running():
		await drive.finished

	await get_tree().create_timer(0.35).timeout
	if app != null and app.has_method("go_to_credits"):
		await app.go_to_credits()
