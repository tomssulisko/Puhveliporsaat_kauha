extends Node

## Where to put the player when returning to level 1.
var level1_reentry_position: Vector2 = Vector2.ZERO
var has_level1_reentry: bool = false

## After death: stay black on level-1 load, then fade in + dream dialogue.
var pending_death_dream: bool = false
var start_faded_black: bool = false

const DEATH_DREAM_EVENTS := ["deathDream1", "deathDream2", "deathDream3"]

var _dying: bool = false
var _fade: CanvasLayer


func _ready() -> void:
	_fade = preload("res://Effects/screen_fade.tscn").instantiate()
	add_child(_fade)


func remember_level1_exit(player_global: Vector2, exit_dir: Vector2 = Vector2.RIGHT) -> void:
	# Nudge back into the map opposite the exit walk, so reentry does not auto-walk again.
	var dir := exit_dir.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	level1_reentry_position = player_global - dir * 90.0
	has_level1_reentry = true


func consume_level1_reentry() -> Variant:
	if not has_level1_reentry:
		return null
	has_level1_reentry = false
	return level1_reentry_position


func trigger_player_death() -> void:
	if _dying:
		return
	_dying = true
	await _run_death_sequence()


func _run_death_sequence() -> void:
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player != null:
		if player.has_method("set_control_enabled"):
			player.set_control_enabled(false)
		player.velocity = Vector2.ZERO
		player.set_physics_process(false)

	AudioManager.play_sfx("kuolema")
	if _fade != null and _fade.has_method("fade_to_black"):
		await _fade.fade_to_black(0.85)
	else:
		await get_tree().create_timer(0.85).timeout

	has_level1_reentry = false
	pending_death_dream = true
	start_faded_black = true

	var manager := get_node_or_null("/root/StorylineManager")
	if manager != null and manager.has_method("on_scene_about_to_change"):
		manager.on_scene_about_to_change()

	get_tree().change_scene_to_file("res://Scene/level_1.tscn")
	# Keep _dying until level-1 fade/dream starts handling recovery.
	await get_tree().process_frame


func prepare_level1_after_death() -> void:
	if start_faded_black and _fade != null and _fade.has_method("set_alpha"):
		_fade.set_alpha(1.0)


func finish_level1_after_death() -> void:
	_dying = false
	if start_faded_black:
		start_faded_black = false
		# Beat of pure black between death fade-out and return fade-in.
		await get_tree().create_timer(1.0).timeout
		if _fade != null and _fade.has_method("fade_from_black"):
			await _fade.fade_from_black(0.9)

	if pending_death_dream:
		pending_death_dream = false
		var manager := get_node_or_null("/root/StorylineManager")
		if manager != null and manager.has_method("play_storyline_event"):
			var event: String = DEATH_DREAM_EVENTS[randi() % DEATH_DREAM_EVENTS.size()]
			manager.play_storyline_event(event, true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quit"):
		get_tree().quit()
