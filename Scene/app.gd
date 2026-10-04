extends Node

## Where to put the player when returning to level 1.
var level1_reentry_position: Vector2 = Vector2.ZERO
var has_level1_reentry: bool = false

## After death: stay black on level-1 load, then fade in + dream dialogue.
var pending_death_dream: bool = false
var start_faded_black: bool = false

## Items currently riding with the player (persist across scenes).
## Each entry: { "id": String, "texture": Texture2D, "scale": Vector2 }
var carried_items: Array[Dictionary] = []
## Items already returned to the car.
var delivered_items: Array[String] = []

const DEATH_DREAM_EVENTS := ["deathDream1", "deathDream2", "deathDream3"]

const FOUND_EVENTS := {
	"patteri": "batteryFound",
	"jakoavain": "wrenchFound",
	"rengas": "tireFound",
}

const RETURN_EVENTS := {
	"patteri": "batteryReturn",
	"jakoavain": "wrenchReturn",
	"rengas": "tireReturn",
}

var _dying: bool = false
var _fade: CanvasLayer
var _pickup_busy: bool = false
var _deliver_busy: bool = false
## First bat graze: warning dialogue + brief invulnerability; later bats kill.
var bat_warning_done: bool = false
var _bat_invuln_until_msec: int = 0
const BAT_INVULN_MSEC := 2500


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade = preload("res://Effects/screen_fade.tscn").instantiate()
	add_child(_fade)


func has_carried_item(item_id: String) -> bool:
	for entry in carried_items:
		if String(entry.get("id", "")) == item_id:
			return true
	return false


func has_delivered_item(item_id: String) -> bool:
	return delivered_items.has(item_id)


func is_item_gone_from_world(item_id: String) -> bool:
	return has_carried_item(item_id) or has_delivered_item(item_id)


func pickup_item(item_id: String, texture: Texture2D, carry_scale: Vector2 = Vector2.ONE) -> void:
	if item_id.is_empty() or is_item_gone_from_world(item_id):
		return
	carried_items.append({
		"id": item_id,
		"texture": texture,
		"scale": carry_scale,
	})
	_sync_player_carry_visuals()
	_run_pickup_reaction(item_id)


func deliver_carried_item(item_id: String) -> bool:
	if _deliver_busy or item_id.is_empty():
		return false
	if has_delivered_item(item_id) or not has_carried_item(item_id):
		return false
	_deliver_busy = true
	_remove_carried(item_id)
	delivered_items.append(item_id)
	_sync_player_carry_visuals()
	_run_delivery_reaction(item_id)
	return true


## 0 = only level 3, 1 = only level 2, 2 = only level 4, 3 = all done.
func get_portal_stage() -> int:
	if not has_delivered_item("patteri"):
		return 0
	if not has_delivered_item("jakoavain"):
		return 1
	if not has_delivered_item("rengas"):
		return 2
	return 3


func get_expected_delivery_item() -> String:
	match get_portal_stage():
		0:
			return "patteri"
		1:
			return "jakoavain"
		2:
			return "rengas"
		_:
			return ""


func is_delivery_busy() -> bool:
	return _deliver_busy


func is_pickup_busy() -> bool:
	return _pickup_busy


func get_carried_items() -> Array[Dictionary]:
	return carried_items


func _run_pickup_reaction(item_id: String) -> void:
	if _pickup_busy:
		return
	_pickup_busy = true
	AudioManager.play_sfx("nonii")
	await get_tree().create_timer(0.55, true, false, true).timeout
	var event: String = String(FOUND_EVENTS.get(item_id, ""))
	if not event.is_empty():
		var manager := get_node_or_null("/root/StorylineManager")
		if manager != null and manager.has_method("play_storyline_event"):
			var started: bool = bool(manager.play_storyline_event(event))
			if started and manager.has_signal("storyline_finished"):
				await manager.storyline_finished
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("on_quest_item_found"):
		scene.on_quest_item_found(item_id)
	_pickup_busy = false


func _run_delivery_reaction(item_id: String) -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("show_auttaja"):
		scene.show_auttaja()
	var event: String = String(RETURN_EVENTS.get(item_id, ""))
	var manager := get_node_or_null("/root/StorylineManager")
	if not event.is_empty() and manager != null and manager.has_method("play_storyline_event"):
		var started: bool = bool(manager.play_storyline_event(event))
		if started and manager.has_signal("storyline_finished"):
			await manager.storyline_finished
	if scene != null and scene.has_method("dismiss_auttaja"):
		await scene.dismiss_auttaja()
	if item_id == "rengas" and scene != null and scene.has_method("play_ending"):
		await scene.play_ending()
		_deliver_busy = false
		return
	if scene != null and scene.has_method("update_portal_gates"):
		scene.update_portal_gates()
	_deliver_busy = false


func _remove_carried(item_id: String) -> void:
	for i in range(carried_items.size() - 1, -1, -1):
		if String(carried_items[i].get("id", "")) == item_id:
			carried_items.remove_at(i)
			return


func _sync_player_carry_visuals() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("sync_carried_items"):
		player.sync_carried_items(carried_items)


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


func is_player_invulnerable() -> bool:
	return Time.get_ticks_msec() < _bat_invuln_until_msec


## First bat hit: near-miss dialogue + short invuln. Later bat hits kill as usual.
func handle_bat_hit() -> void:
	if _dying or is_player_invulnerable():
		return
	if not bat_warning_done:
		bat_warning_done = true
		_bat_invuln_until_msec = Time.get_ticks_msec() + BAT_INVULN_MSEC
		_run_bat_near_miss()
		return
	trigger_player_death()


func _run_bat_near_miss() -> void:
	# Let the graze land before the reaction line.
	await get_tree().create_timer(0.5, true, false, true).timeout
	var manager := get_node_or_null("/root/StorylineManager")
	if manager != null and manager.has_method("play_storyline_event"):
		var started: bool = bool(manager.play_storyline_event("batNearMiss"))
		if started and manager.has_signal("storyline_finished"):
			await manager.storyline_finished


func trigger_player_death() -> void:
	if _dying or is_player_invulnerable():
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

	_drop_carried_items_on_death()
	has_level1_reentry = false
	pending_death_dream = true
	start_faded_black = true
	_pickup_busy = false
	_deliver_busy = false

	var manager := get_node_or_null("/root/StorylineManager")
	if manager != null and manager.has_method("on_scene_about_to_change"):
		manager.on_scene_about_to_change()

	get_tree().change_scene_to_file("res://Scene/level_1.tscn")
	# Keep _dying until level-1 fade/dream starts handling recovery.
	await get_tree().process_frame


## Drop held quest items back into the world so they must be fetched again.
func _drop_carried_items_on_death() -> void:
	if carried_items.is_empty():
		return
	var dropped: Array[String] = []
	for entry in carried_items:
		var id := String(entry.get("id", ""))
		if not id.is_empty():
			dropped.append(id)
	carried_items.clear()
	_sync_player_carry_visuals()
	var manager := get_node_or_null("/root/StorylineManager")
	if manager == null or not ("events_played" in manager):
		return
	for id in dropped:
		var found_event: String = String(FOUND_EVENTS.get(id, ""))
		if found_event.is_empty():
			continue
		if manager.events_played.has(found_event):
			manager.events_played.erase(found_event)


func fade_to_black(duration: float = 0.8) -> void:
	if _fade != null and _fade.has_method("fade_to_black"):
		await _fade.fade_to_black(duration)


func fade_from_black(duration: float = 0.8) -> void:
	if _fade != null and _fade.has_method("fade_from_black"):
		await _fade.fade_from_black(duration)


func go_to_credits() -> void:
	var manager := get_node_or_null("/root/StorylineManager")
	if manager != null and manager.has_method("on_scene_about_to_change"):
		manager.on_scene_about_to_change()
	get_tree().change_scene_to_file("res://Scene/credits.tscn")
	await get_tree().process_frame
	await fade_from_black(1.0)


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
