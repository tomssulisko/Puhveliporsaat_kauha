extends Node

signal storyline_finished

var storyline_control: CanvasLayer = null
var player: CharacterBody2D = null
#@onready var sub_viewport_container = $"../player/Camera2D/SubViewportContainer"

var storyline_queue: Array = []
var storyline_json
# { name: String, played: boolean }
var events_played: Array[String] = []
var _paused_tree_for_storyline := false
var _storyline_active := false

func _storyline_json_path() -> String:
	if FileAccess.file_exists("res://addons/Storyline/storyline.json"):
		return "res://addons/Storyline/storyline.json"
	return "res://addons/Storyline/storyline.json"

func _ready():
	storyline_json = load_json_file(_storyline_json_path())
	print("DEBUG: StorylineManager autoload ready")
	print("DEBUG: JSON loaded: ", storyline_json != null)

func on_scene_about_to_change() -> void:
	storyline_queue.clear()
	if storyline_control != null and is_instance_valid(storyline_control):
		storyline_control.visible = false
	storyline_control = null
	if _paused_tree_for_storyline:
		get_tree().paused = false
		_paused_tree_for_storyline = false


func play_storyline_event(event):
	print("DEBUG: play_storyline_event called with: ", event)
	
	if not _ensure_storyline_control():
		return false
	
	if events_played.has(event):
		print("DEBUG: Event already played: ", event)
		return false
		
	var story_data = find_event_by_name(event)
	if story_data.size() > 0:
		print("DEBUG: Found story data for event: ", event)
		# Pause gameplay while dialogue runs; only unpause on our exit if we paused here
		# (e.g. level victory already paused the tree — do not unpause when dialogue ends).
		if not get_tree().paused:
			get_tree().paused = true
			_paused_tree_for_storyline = true
		else:
			_paused_tree_for_storyline = false
		_storyline_active = true
		events_played.append(event)
		for entry in story_data["speeches"]:
			#print(entry.speech.actor)
			var texts = entry.speech.text
			for text in texts:
				storyline_queue.append({ "actor": entry.speech.actor, "text": text })
		render_storyline()
		return true
	else:
		print("ERROR: No story data found for event: ", event)
		return false

func load_json_file(path: String) -> JSON:
	var file = FileAccess.open(path, FileAccess.READ)
	
	if file:
		var json_string = file.get_as_text()
		file.close()
		var json_parser = JSON.new()
		var json_result = json_parser.parse(json_string)
		if json_result == OK:
			return json_parser
		else:
			print("Failed to parse JSON: ", json_parser.get_error_message())
	else:
		print("File does not exist: ", path)
	return null

func find_event_by_name(event_name: String) -> Dictionary:
	if storyline_json == null:
		return {}
	var events = storyline_json.data["events"]
	for event in events:
		if event["event"]["name"] == event_name:
			return event["event"]
	return {}

func _ensure_storyline_control() -> bool:
	if storyline_control != null and not is_instance_valid(storyline_control):
		storyline_control = null

	if storyline_control != null:
		return true

	print("DEBUG: Searching for storyline canvas...")
	var current_scene := get_tree().current_scene
	if current_scene == null:
		print("ERROR: No current scene found!")
		return false

	storyline_control = current_scene.get_node_or_null("StorylineCanvas")
	if storyline_control == null:
		storyline_control = find_storyline_canvas_recursive(current_scene)
	if storyline_control == null:
		print("ERROR: Could not find storyline canvas!")
		return false

	if not storyline_control.is_connected("storyline_ready", _on_storyline_ready):
		storyline_control.connect("storyline_ready", _on_storyline_ready)
	if not storyline_control.is_connected("storyline_cancelled", _on_storyline_cancelled):
		storyline_control.connect("storyline_cancelled", _on_storyline_cancelled)
	print("DEBUG: Storyline canvas found and connected")
	return true


func render_storyline():
	if not _ensure_storyline_control():
		print("ERROR: Storyline control is null in render_storyline")
		return
		
	var storyline = null
	if !storyline_queue.is_empty():
		storyline = storyline_queue.pop_front()
	if storyline == null:
		return
	print("DEBUG: Rendering storyline: ", storyline.actor, " - ", storyline.text)
	storyline_control.visible = true
	storyline_control.render_storyline(storyline.actor, storyline.text)

func _on_storyline_cancelled():
	storyline_queue.clear()
	if storyline_control != null and is_instance_valid(storyline_control):
		storyline_control.visible = false
	if _paused_tree_for_storyline:
		get_tree().paused = false
		_paused_tree_for_storyline = false
	_finish_storyline()

func hide_storyline_control():
	if storyline_control != null and is_instance_valid(storyline_control):
		storyline_control.visible = false

func find_storyline_canvas_recursive(node: Node) -> CanvasLayer:
	# Check if this node is the StorylineCanvas
	if node.name == "StorylineCanvas" and node is CanvasLayer:
		return node
	
	# Search in children
	for child in node.get_children():
		var result = find_storyline_canvas_recursive(child)
		if result:
			return result
	
	return null

func _on_storyline_ready():
	if !storyline_queue.is_empty():
		print("Queue not empty, rendering next line.")
		render_storyline()
	else:
		if storyline_control != null and is_instance_valid(storyline_control):
			storyline_control.visible = false
		if _paused_tree_for_storyline:
			get_tree().paused = false
			_paused_tree_for_storyline = false
		_finish_storyline()


func _finish_storyline() -> void:
	if not _storyline_active:
		return
	_storyline_active = false
	storyline_finished.emit()
