extends Control

# Node references for UI elements
@onready var storyline_manager = $StorylineManager  # Manages storyline playback and tracks played events
@onready var storyline_canvas = $StorylineCanvas    # Canvas that displays storyline text and characters
@onready var event_list = $VBoxContainer/ScrollContainer/EventList  # Container for storyline event buttons
@onready var status_label = $VBoxContainer/StatusLabel  # Shows current status/feedback to user
@onready var refresh_button = $VBoxContainer/HBoxContainer/RefreshButton  # Reloads storyline events
@onready var clear_button = $VBoxContainer/HBoxContainer/ClearButton  # Clears status display
@onready var reset_button = $VBoxContainer/HBoxContainer/ResetButton  # Resets played events to allow replay

# Data storage
var storyline_json  # Parsed JSON data from storyline.json file
var events_data: Array = []  # Array of storyline events extracted from JSON
var event_buttons: Dictionary = {}  # Dictionary to track button references by event name

func _storyline_json_path() -> String:
	if FileAccess.file_exists("res://addons/Storyline/storyline.json"):
		return "res://addons/Storyline/storyline.json"
	return "res://addons/Storyline/storyline.json"

func _ready():
	# Initialize the storyline test scene
	# Connect button signals to their respective handler functions
	refresh_button.pressed.connect(_on_refresh_button_pressed)
	clear_button.pressed.connect(_on_clear_button_pressed)
	reset_button.pressed.connect(_on_reset_button_pressed)
	
	# Load the storyline JSON file and parse events
	storyline_json = load_json_file(_storyline_json_path())
	if storyline_json:
		parse_events()  # Extract events from JSON
		create_event_buttons()  # Create UI buttons for each event
	else:
		# Show error if JSON loading failed
		status_label.text = "Failed to load storyline.json"
		status_label.modulate = Color.RED

# Loads and parses a JSON file from the given path
# Returns the parsed JSON object or null if loading/parsing fails
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

# Extracts storyline events from the loaded JSON data
# Updates the events_data array and shows count in status label
func parse_events():
	if not storyline_json:
		return
		
	events_data = storyline_json.data["events"]
	status_label.text = "Found " + str(events_data.size()) + " storyline events"
	status_label.modulate = Color.GREEN

# Creates UI buttons for each storyline event
# Each button allows the user to trigger a specific storyline event
func create_event_buttons():
	if events_data.is_empty():
		return
		
	# Clear existing buttons and button references
	for child in event_list.get_children():
		child.queue_free()
	event_buttons.clear()
	
	# Create buttons for each event
	for event_data in events_data:
		var event_name = event_data["event"]["name"]
		var speeches = event_data["event"]["speeches"]
		
		# Create button with event name as text
		var button = Button.new()
		button.text = event_name
		button.custom_minimum_size.y = 40
		
		# Set initial color based on whether event has been played
		update_button_color(button, event_name)
		
		# Create description from first speech for tooltip
		var description = ""
		if not speeches.is_empty():
			var first_speech = speeches[0]["speech"]
			var actor = first_speech["actor"]
			var texts = first_speech["text"]
			if not texts.is_empty():
				description = "[" + actor + "] " + texts[0].substr(0, 50) + "..."
		
		# Set tooltip to show event preview
		button.tooltip_text = description
		
		# Connect button to play the specific event
		button.pressed.connect(_on_event_button_pressed.bind(event_name))
		
		# Store button reference for color updates
		event_buttons[event_name] = button
		
		# Add button to the UI
		event_list.add_child(button)

# Called when a storyline event button is pressed
# Triggers the storyline manager to play the selected event
func _on_event_button_pressed(event_name: String):
	status_label.text = "Playing: " + event_name
	status_label.modulate = Color.YELLOW
	
	# Tell the storyline manager to play this specific event
	storyline_manager.play_storyline_event(event_name)
	
	# Update button color to show it's been played
	if event_name in event_buttons:
		update_button_color(event_buttons[event_name], event_name)

# Called when a storyline finishes playing
# Updates status to show completion
func _on_storyline_finished():
	status_label.text = "Storyline finished"
	status_label.modulate = Color.GREEN

# Called when refresh button is pressed
# Reloads storyline events and recreates buttons
func _on_refresh_button_pressed():
	storyline_json = load_json_file(_storyline_json_path())
	if not storyline_json:
		status_label.text = "Failed to load storyline.json"
		status_label.modulate = Color.RED
		return
	parse_events()
	create_event_buttons()
	status_label.text = "Refreshed storyline events from JSON"
	status_label.modulate = Color.WHITE

# Called when clear button is pressed
# Clears the status display
func _on_clear_button_pressed():
	status_label.text = "Cleared status display"
	status_label.modulate = Color.WHITE

# Called when reset button is pressed
# Clears the played events list to allow replaying storylines
func _on_reset_button_pressed():
	# Clear the played events from storyline manager
	storyline_manager.events_played.clear()
	
	# Reset all button colors to show they can be played again
	for event_name in event_buttons:
		update_button_color(event_buttons[event_name], event_name)
	
	status_label.text = "Storylines reset - all events can be played again"
	status_label.modulate = Color.GREEN

# Updates button color based on whether the storyline has been played
# Green = not played, Gray = already played
func update_button_color(button: Button, event_name: String):
	if storyline_manager.events_played.has(event_name):
		# Storyline has been played - show in gray
		button.modulate = Color(0.7, 0.7, 0.7, 1.0)  # Gray color
		button.text = event_name + " (played)"
	else:
		# Storyline not played yet - show in normal color
		button.modulate = Color.WHITE
		button.text = event_name
