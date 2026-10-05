extends Node2D

@export var anim_fps_min: float = 4.0
@export var anim_fps_max: float = 9.0

@onready var _anim: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	if _anim == null or _anim.sprite_frames == null:
		return
	# Each instance needs its own frames resource so FPS doesn't sync across candles.
	_anim.sprite_frames = _anim.sprite_frames.duplicate()
	var fps := randf_range(anim_fps_min, anim_fps_max)
	_anim.sprite_frames.set_animation_speed("burn", fps)
	_anim.play("burn")
	var frame_count := _anim.sprite_frames.get_frame_count("burn")
	if frame_count > 0:
		_anim.frame = randi() % frame_count
