extends CanvasLayer

const _PLACEHOLDER_STORYTELLER: Resource = preload("res://addons/Storyline/Storytellers/placeholder.tres")

@onready var label = $PanelContainer/GridContainer/MarginContainer/RichTextLabel
@onready var talking_head_container: GridContainer = $PanelContainer/GridContainer
@onready var panel_container: PanelContainer = $PanelContainer
@onready var _hold_advance_indicator: StorylineHoldIndicator = $PanelContainer/IndicatorOverlay/HoldAdvanceIndicator
@export var storytellers: Array[Resource]
@export var portrait_size: Vector2 = Vector2(256, 256)
@export var portrait_left_margin: float = 16.0
@export_range(0.2, 3.0, 0.05, "suffix:s") var hold_advance_duration := 1.0

var test: AudioStreamPlayer
var current_text = ""
# Slightly slower typewriter speed for improved readability.
var typing_speed = 0.03
var sounds_to_play = 5
var writer_timer: Timer
var storyteller_instance
var teller_cache_entry: Dictionary = {}
var teller_cache: Array[Dictionary] = []
var writer_expedited = false
var text_to_render
var line_render_done = false
var sounds_playing = false
## While true, chain random clips when each ends. When typing finishes, set false so no new clips start, but the current clip may finish.
var _queue_speech_clips_while_typing: bool = true
var current_storyteller: Resource = null
var storyteller_index = 0
var sound_delay_max = 0.5
var sound_delay = 0
var audio_player
## If present as autoload under this name, volumes mirror it; otherwise speech uses full level.
var _audio_manager: Node = null
var _hold_advance_time := 0.0

signal storyline_ready
signal storyline_cancelled

func _ready():
		# Storyline UI stays hidden until StorylineManager explicitly renders a line.
		visible = false
		audio_player = AudioStreamPlayer.new()
		audio_player.bus = "SFX"
		audio_player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(audio_player)
		writer_timer = Timer.new()
		writer_timer.wait_time = typing_speed
		writer_timer.one_shot = false
		add_child(writer_timer)
		
		_audio_manager = get_tree().root.get_node_or_null("AudioManager")
		if _audio_manager and _audio_manager.has_signal("volume_changed"):
			_audio_manager.volume_changed.connect(_on_volume_changed)
		call_deferred("update_speech_volume")
		if _hold_advance_indicator != null:
			_hold_advance_indicator.visible = false
			_hold_advance_indicator.set_progress(0.0)

func _exit_tree() -> void:
	if _audio_manager and _audio_manager.has_signal("volume_changed") and _audio_manager.volume_changed.is_connected(_on_volume_changed):
		_audio_manager.volume_changed.disconnect(_on_volume_changed)

func _process(_delta):

	if sound_delay > 0:
		#print(sound_delay)
		sound_delay -= _delta
		if sound_delay <= 0:
			sound_delay = 0

	if current_storyteller and sounds_playing and not audio_player.playing and sound_delay == 0:
		if _queue_speech_clips_while_typing:
			play_next_sound()
		else:
			sounds_playing = false

	_process_hold_to_advance(_delta)

	if Input.is_action_just_pressed("storyline_expedite") and current_storyteller:
		if !writer_expedited and !line_render_done:
			if current_text.length() < text_to_render.length():
				current_text += text_to_render.substr(current_text.length())
				label.text = current_text
				writer_expedited = true
				line_render_done = true
				_queue_speech_clips_while_typing = false
			elif current_text.length() == text_to_render.length():
				continue_storyline()
		else:
			continue_storyline()
	elif Input.is_action_just_pressed("storyline_skip"):
		_reset_hold_advance()
		_queue_speech_clips_while_typing = false
		sounds_playing = false
		audio_player.stop()
		emit_signal("storyline_cancelled")
	
	

func render_storyline(_storyteller: String, text: String):
	# Stop any previous audio and sounds
	sounds_playing = false
	audio_player.stop()
	_reset_hold_advance()
	
	# Normal rendering logic
	writer_expedited = false
	line_render_done = false
	_queue_speech_clips_while_typing = true
	text_to_render = text
	writer_timer.wait_time = typing_speed
	current_text = ""
	
	# Initialize the new storyteller and play sounds
	var storyteller = find_resource_by_name(_storyteller)
	init_storyteller(storyteller)
	
	# Set the storyteller and start playing sounds
	current_storyteller = storyteller
	storyteller_index = 0
	sounds_playing = true

	# Update volume settings before playing sounds
	update_speech_volume()
	
	# Play the first sound
	print("first sound")
	play_next_sound()

	# Typing animation setup
	if writer_timer.is_connected("timeout", _on_typewrite_timeout):
		writer_timer.disconnect("timeout", _on_typewrite_timeout)
	writer_timer.connect("timeout", _on_typewrite_timeout.bind(writer_timer))
	writer_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	writer_timer.start()

func init_storyteller(storyteller):
	var talking_head
	var teller = teller_cache.filter(func(entry): return entry.teller_name == storyteller.teller_name)
	var teller_entry = null
	
	# Hide all currently active portraits to avoid overlap
	for entry in teller_cache:
		entry.instance.visible = false

	if teller.size() == 0:
		# If the storyteller is not in the cache, create a new instance
		if storyteller.scene != null:
			teller_entry = { "teller_name": storyteller.teller_name, "instance": storyteller.scene.instantiate() }
			teller_cache.append(teller_entry)
			talking_head = teller_entry.instance
			talking_head_container.add_child(talking_head)
		else:
			# If no scene available, create a fallback visual indicator
			print("Warning: No scene available for storyteller '", storyteller.teller_name, "', creating fallback")
			talking_head = create_fallback_portrait(storyteller.teller_name)
			talking_head_container.add_child(talking_head)
	else:
		# If the storyteller is in the cache, reuse the instance
		talking_head = teller[0].instance
	
	# Ensure the current storyteller portrait is visible and positioned correctly
	if talking_head:
		talking_head.visible = true
		position_talking_head(talking_head)
		talking_head.process_mode = Node.PROCESS_MODE_ALWAYS
		if talking_head.has_method("play"):
			talking_head.play("default")  # Play the default animation (if applicable)

func position_talking_head(talking_head: Node) -> void:
	var top_left = get_portrait_top_left()
	if talking_head is Control:
		(talking_head as Control).global_position = top_left
		return
	if talking_head is Node2D:
		var node2d := talking_head as Node2D
		var target_position: Vector2 = top_left
		# AnimatedSprite2D is usually centered, so adjust to keep the portrait inside the target box.
		if has_property(node2d, "centered") and node2d.get("centered"):
			target_position += portrait_size * 0.5
		node2d.global_position = target_position

func get_portrait_top_left() -> Vector2:
	var panel_pos = panel_container.global_position
	var panel_size = panel_container.size
	var x = panel_pos.x - portrait_size.x - portrait_left_margin
	var y = panel_pos.y + panel_size.y - portrait_size.y
	return Vector2(x, y)

func has_property(target: Object, property_name: String) -> bool:
	for property_info in target.get_property_list():
		if property_info.get("name") == property_name:
			return true
	return false

# Creates a fallback portrait when no scene is available
func create_fallback_portrait(_teller_name: String) -> Node:
	var fallback = ColorRect.new()
	fallback.size = Vector2(64, 64)
	fallback.color = Color(1.0, 0.5, 0.5, 0.8)  # Red tint to indicate missing
	
	var fallback_label = Label.new()
	fallback_label.text = "?"
	fallback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fallback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fallback_label.size = Vector2(64, 64)
	fallback.add_child(fallback_label)
	
	return fallback

func play_next_sound():
	if not current_storyteller or current_storyteller.sounds.size() == 0:
		sounds_playing = false
		return

	# Randomly select a sound index
	var random_index = randi() % current_storyteller.sounds.size()
	var clip = current_storyteller.sounds[random_index]
	
	# Debug information
	print("DEBUG: Playing sound for storyteller: ", current_storyteller.teller_name)
	print("DEBUG: Sound array size: ", current_storyteller.sounds.size())
	print("DEBUG: Selected index: ", random_index)
	print("DEBUG: Clip is null: ", clip == null)
	if clip != null:
		print("DEBUG: Clip resource path: ", clip.resource_path)
		print("DEBUG: Clip resource name: ", clip.resource_name)
	
	# Check if the sound clip is valid and try to load it directly if it's null
	if clip == null:
		print("Warning: Sound clip is null for storyteller '", current_storyteller.teller_name, "', trying to load directly")
		# Try to load the sound file directly by constructing the path
		var sound_paths = get_sound_paths_for_storyteller(current_storyteller.teller_name)
		if sound_paths.size() > random_index:
			clip = load(sound_paths[random_index])
			print("DEBUG: Loaded sound directly from: ", sound_paths[random_index])
	
	# If still null, use placeholder
	if clip == null:
		print("Warning: Could not load sound for storyteller '", current_storyteller.teller_name, "', using placeholder")
		clip = load("res://addons/Storyline/puhe/placeholder1.wav")
		if clip == null:
			sounds_playing = false
			return
	
	audio_player.stream = clip
	update_speech_volume()  # Apply current volume settings
	audio_player.play()
	sound_delay = sound_delay_max
	
	#audio_player.connect("finished", _on_audio_finished)


# Called when a sound finishes playing
func _on_audio_finished():
	# If there are more sounds to play for the current storyteller, play the next one
	#if sounds_playing:
		#play_next_sound()
	pass

		
func find_resource_by_name(id: String) -> Resource:
	for storyteller in storytellers:
		if storyteller and storyteller.id == id:
			return storyteller
	
	print("Warning: Storyteller '", id, "' not found, using placeholder")
	return _PLACEHOLDER_STORYTELLER

# Helper function to get sound file paths for each storyteller
func get_sound_paths_for_storyteller(teller_name: String) -> Array[String]:
	match teller_name:
		"gramps1", "gramps2", "gramps3", "gramps4":
			return [
				"res://addons/Storyline/puhe/majakkamies/SFX majakkamies 1.wav",
				"res://addons/Storyline/puhe/majakkamies/SFX majakkamies 2.wav",
				"res://addons/Storyline/puhe/majakkamies/SFX majakkamies 3.wav",
				"res://addons/Storyline/puhe/majakkamies/SFX majakkamies 4.wav",
				"res://addons/Storyline/puhe/majakkamies/SFX majakkamies 5.wav",
			]
		"mummo":
			return [
				"res://addons/Storyline/puhe/mummo/SFX mummo1.wav",
				"res://addons/Storyline/puhe/mummo/SFX mummo2.wav",
				"res://addons/Storyline/puhe/mummo/SFX mummo3.wav",
				"res://addons/Storyline/puhe/mummo/SFX mummo4.wav",
				"res://addons/Storyline/puhe/mummo/SFX mummo5.wav",
				"res://addons/Storyline/puhe/mummo/SFX mummo6.wav",
			]
		"peikko":
			return [
				"res://addons/Storyline/puhe/peikko1.wav",
				"res://addons/Storyline/puhe/peikko2.wav",
				"res://addons/Storyline/puhe/peikko3.wav", 
				"res://addons/Storyline/puhe/peikko4.wav",
				"res://addons/Storyline/puhe/peikko5.wav"
			]
		"syojatar":
			return [
				"res://addons/Storyline/puhe/syojatar1.wav",
				"res://addons/Storyline/puhe/syojatar2.wav",
				"res://addons/Storyline/puhe/syojatar3.wav",
				"res://addons/Storyline/puhe/syojatar4.wav", 
				"res://addons/Storyline/puhe/syojatar5.wav"
			]
		"narrator":
			return [
				"res://addons/Storyline/puhe/placeholder1.wav",
				"res://addons/Storyline/puhe/placeholder2.wav",
				"res://addons/Storyline/puhe/placeholder3.wav",
			]
		"pirate":
			return [
				"res://addons/Storyline/puhe/merirosvo/SFX merirosvo 1.wav",
				"res://addons/Storyline/puhe/merirosvo/SFX merirosvo 2.wav",
				"res://addons/Storyline/puhe/merirosvo/SFX merirosvo 3.wav",
				"res://addons/Storyline/puhe/merirosvo/SFX merirosvo 4.wav",
				"res://addons/Storyline/puhe/merirosvo/SFX merirosvo 5.wav",
			]
		"monster":
			return [
				"res://addons/Storyline/puhe/MatalaHirviö/MatalaHirviö-01.wav",
				"res://addons/Storyline/puhe/MatalaHirviö/MatalaHirviö-02.wav",
				"res://addons/Storyline/puhe/MatalaHirviö/MatalaHirviö-03.wav",
				"res://addons/Storyline/puhe/MatalaHirviö/MatalaHirviö-04.wav",
				"res://addons/Storyline/puhe/MatalaHirviö/MatalaHirviö-05.wav",
			]
		"hulluJonne":
			return [
				"res://addons/Storyline/puhe/Merihirviö/SFX merihirviö 1.wav",
				"res://addons/Storyline/puhe/Merihirviö/SFX merihirviö 2.wav",
				"res://addons/Storyline/puhe/Merihirviö/SFX merihirviö 3.wav",
				"res://addons/Storyline/puhe/Merihirviö/SFX merihirviö 4.wav",
				"res://addons/Storyline/puhe/Merihirviö/SFX merihirviö 5.wav",
			]
		"auttaja":
			return [
				"res://addons/Storyline/puhe/auttaja/auttaja1.wav",
				"res://addons/Storyline/puhe/auttaja/auttaja2.wav",
				"res://addons/Storyline/puhe/auttaja/auttaja3.wav",
			]
		"pelaaja":
			return [
				"res://addons/Storyline/puhe/pelaaja/pelaaja1.wav",
				"res://addons/Storyline/puhe/pelaaja/pelaaja2.wav",
				"res://addons/Storyline/puhe/pelaaja/pelaaja3.wav",
			]
		_:
			return []

func _on_typewrite_timeout(timer):
	if current_text.length() < text_to_render.length():
		current_text += text_to_render[current_text.length()]
		label.text = current_text
	else:
		timer.stop()
		_queue_speech_clips_while_typing = false
		label.text = label.text + "\n[color='yellow'][ press space or enter to continue ][/color]"

func continue_storyline():
	_reset_hold_advance()
	# Stop the current audio and any ongoing sounds
	_queue_speech_clips_while_typing = false
	sounds_playing = false
	audio_player.stop()
	emit_signal("storyline_ready")


func _is_line_fully_revealed() -> bool:
	if current_storyteller == null or text_to_render.is_empty():
		return false
	if current_text.length() < text_to_render.length():
		return false
	return writer_timer.is_stopped() or line_render_done or writer_expedited


func _process_hold_to_advance(delta: float) -> void:
	if not _is_line_fully_revealed():
		_reset_hold_advance()
		return

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_hold_advance_time += delta
		var progress := clampf(_hold_advance_time / hold_advance_duration, 0.0, 1.0)
		if _hold_advance_indicator != null:
			_hold_advance_indicator.set_progress(progress)
		if _hold_advance_time >= hold_advance_duration:
			continue_storyline()
	else:
		if _hold_advance_time > 0.0:
			_reset_hold_advance()


func _reset_hold_advance() -> void:
	_hold_advance_time = 0.0
	if _hold_advance_indicator != null:
		_hold_advance_indicator.set_progress(0.0)

# Update speech volume; mirrors AudioManager when that autoload exists.
func update_speech_volume():
	if not audio_player:
		return
	var master_volume := 100.0
	var fx_volume := 100.0
	if _audio_manager:
		master_volume = float(_audio_manager.masterVolume)
		fx_volume = float(_audio_manager.fxVolume)
	var master_multiplier = master_volume / 100.0
	var fx_multiplier = fx_volume / 100.0
	var speech_volume_db = -60 + (60 * fx_multiplier * master_multiplier)
	audio_player.volume_db = speech_volume_db

func _on_volume_changed():
	update_speech_volume()
