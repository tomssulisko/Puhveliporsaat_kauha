extends DirectionalLight2D

## Full MIX darkness — only flashlight beam should reveal the world.

func _ready() -> void:
	visible = true
	enabled = true
	blend_mode = Light2D.BLEND_MODE_MIX
	color = Color(0, 0, 0, 1)
	energy = 1.0
