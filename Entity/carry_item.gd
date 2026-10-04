extends Area2D

## World pickup — on touch, sticks to the player and persists via App.
@export var item_id: String = ""
@export var item_texture: Texture2D
@export var carry_scale: Vector2 = Vector2(1, 1)

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = false
	if item_texture != null:
		_sprite.texture = item_texture
	_sprite.scale = carry_scale
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var app := get_node_or_null("/root/App")
	if app != null and app.has_method("is_item_gone_from_world") and app.is_item_gone_from_world(item_id):
		queue_free()
		return

	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body == null or not body.is_in_group("player"):
		return
	if item_id.is_empty():
		return
	var app := get_node_or_null("/root/App")
	if app == null or not app.has_method("pickup_item"):
		return
	if app.has_method("is_item_gone_from_world") and app.is_item_gone_from_world(item_id):
		queue_free()
		return
	# Disable further picks before async dialogue starts.
	set_deferred("monitoring", false)
	app.pickup_item(item_id, item_texture, carry_scale)
	queue_free()
