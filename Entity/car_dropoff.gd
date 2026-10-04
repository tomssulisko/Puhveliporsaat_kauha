extends Area2D

## Detects the player near the car and accepts the currently expected quest item.


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body == null or not body.is_in_group("player"):
		return
	var app := get_node_or_null("/root/App")
	if app == null or not app.has_method("get_expected_delivery_item"):
		return
	if app.has_method("is_delivery_busy") and app.is_delivery_busy():
		return
	var expected: String = app.get_expected_delivery_item()
	if expected.is_empty():
		return
	if not app.has_carried_item(expected):
		return
	app.deliver_carried_item(expected)
