extends Node2D

## Scrolls the road animation so lane markings drift left (frames 12 → 1).
@export var anim_fps: float = 12.0
@export var bob_amplitude: float = 2.5
@export var bob_seconds: float = 1.6

@onready var _road: AnimatedSprite2D = $World/Pitkatie
@onready var _car: Node2D = $World/Auto
@onready var _ui: CanvasLayer = $CreditsUI


func _ready() -> void:
	_setup_road_animation()
	if _road != null:
		_road.play("scroll")
	_enable_headlights()
	_unshade_ui(_ui)
	_start_car_bob()
	AudioManager.play_ambient("sirkat", 0.0, true)
	AudioManager.play_looping_sfx("auto_ajo")


func _exit_tree() -> void:
	AudioManager.stop_looping_sfx()


func _setup_road_animation() -> void:
	if _road == null:
		return
	var frames := SpriteFrames.new()
	frames.add_animation("scroll")
	frames.set_animation_loop("scroll", true)
	frames.set_animation_speed("scroll", anim_fps)
	# Reverse order so road lines move left.
	for i in range(12, 0, -1):
		var path := "res://Texture/credits/pitkatie%d.png" % i
		if not ResourceLoader.exists(path):
			continue
		var tex := load(path) as Texture2D
		if tex != null:
			frames.add_frame("scroll", tex)
	_road.sprite_frames = frames
	_road.animation = &"scroll"
	_road.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _enable_headlights() -> void:
	if _car == null:
		return
	var lights := _car.get_node_or_null("Headlights")
	if lights == null:
		return
	lights.visible = true
	for child in lights.get_children():
		if child is Light2D:
			(child as Light2D).enabled = true


func _unshade_ui(node: Node) -> void:
	## Keep credit photos/text above the darkness (not affected by pimeys/lights).
	if node is CanvasItem:
		(node as CanvasItem).light_mask = 0
	for child in node.get_children():
		_unshade_ui(child)


func _start_car_bob() -> void:
	if _car == null:
		return
	var base_y := _car.position.y
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(_car, "position:y", base_y - bob_amplitude, bob_seconds) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_car, "position:y", base_y + bob_amplitude, bob_seconds) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
