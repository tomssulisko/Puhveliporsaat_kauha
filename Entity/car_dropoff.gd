extends Area2D

## Accepts the expected quest item only when the player walks up to the car.
## Stays disarmed on load so spawn/reentry near the car cannot fire return dialogue early.

@export var arm_delay: float = 0.8
@export var max_deliver_distance: float = 55.0

var _armed: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = false
	monitorable = false
	body_entered.connect(_on_body_entered)
	_arm_after_delay()


func _arm_after_delay() -> void:
	await get_tree().create_timer(arm_delay).timeout
	if not is_instance_valid(self):
		return
	_armed = true
	monitoring = true


func _on_body_entered(body: Node2D) -> void:
	if not _armed:
		return
	if body == null or not body.is_in_group("player"):
		return
	var scene := get_tree().current_scene
	if scene == null or scene.name != "Level1":
		return
	var app := get_node_or_null("/root/App")
	if app == null or not app.has_method("get_expected_delivery_item"):
		return
	if app.has_method("is_delivery_busy") and app.is_delivery_busy():
		return
	if app.has_method("is_pickup_busy") and app.is_pickup_busy():
		return
	var expected: String = app.get_expected_delivery_item()
	if expected.is_empty():
		return
	if not app.has_carried_item(expected):
		return
	var car := get_parent() as Node2D
	if car != null and body.global_position.distance_to(car.global_position) > max_deliver_distance:
		return
	app.deliver_carried_item(expected)
