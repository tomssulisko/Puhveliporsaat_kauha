extends Node2D

## Shared bootstrap for side maps (level 2–4).
@export var ambient_id: String = "tuuli"


func _ready() -> void:
	if ambient_id.is_empty():
		return
	AudioManager.play_ambient(ambient_id, 0.0, true)
