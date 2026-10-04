extends CharacterBody2D

const WALK_SPEED := 100.0
const SPRINT_MULTIPLIER := 2.0
const CARRY_OFFSET := Vector2(14, -6)
const CARRY_STACK_STEP := Vector2(10, -4)

var speed: float = WALK_SPEED
var input_direction := Vector2.ZERO
var control_enabled: bool = true

var _carry_root: Node2D


func _ready() -> void:
	add_to_group("player")
	_ensure_carry_root()
	call_deferred("_sync_carry_from_app")


func set_control_enabled(enabled: bool) -> void:
	control_enabled = enabled
	if not enabled:
		velocity = Vector2.ZERO
		input_direction = Vector2.ZERO


func get_input() -> void:
	if not control_enabled:
		velocity = Vector2.ZERO
		return
	input_direction = Input.get_vector("left", "right", "up", "down")
	var current_speed := WALK_SPEED
	if Input.is_action_pressed("sprint"):
		current_speed *= SPRINT_MULTIPLIER
	speed = current_speed
	velocity = input_direction * current_speed


func _physics_process(_delta: float) -> void:
	get_input()
	move_and_slide()


func sync_carried_items(items: Array) -> void:
	_ensure_carry_root()
	for child in _carry_root.get_children():
		child.queue_free()
	var i := 0
	for entry in items:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var tex: Texture2D = entry.get("texture") as Texture2D
		if tex == null:
			continue
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.z_index = 4
		var sc: Variant = entry.get("scale", Vector2.ONE)
		spr.scale = sc if sc is Vector2 else Vector2.ONE
		spr.position = CARRY_OFFSET + CARRY_STACK_STEP * float(i)
		_carry_root.add_child(spr)
		i += 1


func _sync_carry_from_app() -> void:
	var app := get_node_or_null("/root/App")
	if app != null and app.has_method("get_carried_items"):
		sync_carried_items(app.get_carried_items())


func _ensure_carry_root() -> void:
	if _carry_root != null and is_instance_valid(_carry_root):
		return
	_carry_root = get_node_or_null("CarriedItems") as Node2D
	if _carry_root == null:
		_carry_root = Node2D.new()
		_carry_root.name = "CarriedItems"
		add_child(_carry_root)
