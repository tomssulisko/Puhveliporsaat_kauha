extends Area2D

## World pickup — on touch, sticks to the player and persists via App.
@export var item_id: String = ""
@export var item_texture: Texture2D
@export var carry_scale: Vector2 = Vector2(1, 1)
@export var outline_color: Color = Color(1.0, 0.95, 0.15, 1.0)
## Thin 1px rim.
@export var outline_px: float = 1.0
## Spawned at a level-1 death spot; stays present even while original map spawn is suppressed.
@export var is_death_drop: bool = false

## Cardinal-only offsets = thin 1px rim without chunky diagonal corners.
const OUTLINE_DIRS := [
	Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1),
]

@onready var _sprite: Sprite2D = $Sprite2D

var _outline_sprites: Array[Sprite2D] = []
var _outline_lit: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = false
	if item_texture != null:
		_sprite.texture = item_texture
	_sprite.scale = carry_scale
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.z_index = maxi(_sprite.z_index, 3)
	_build_outline_sprites()

	var app := get_node_or_null("/root/App")
	if not is_death_drop and app != null and app.has_method("is_item_gone_from_world") and app.is_item_gone_from_world(item_id):
		queue_free()
		return

	body_entered.connect(_on_body_entered)


func _process(_delta: float) -> void:
	var lit := _is_lit_by_flashlight()
	if lit == _outline_lit:
		return
	_set_outline_lit(lit)


func _build_outline_sprites() -> void:
	_outline_sprites.clear()
	if _sprite.texture == null:
		return

	var silhouette := _make_silhouette_texture(_sprite.texture, outline_color)
	if silhouette == null:
		return

	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED

	for dir in OUTLINE_DIRS:
		var outline := Sprite2D.new()
		outline.texture = silhouette
		outline.centered = _sprite.centered
		outline.offset = _sprite.offset
		outline.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		outline.show_behind_parent = true
		outline.position = dir * outline_px
		outline.material = mat
		outline.light_mask = 0
		outline.visible = false
		_sprite.add_child(outline)
		_outline_sprites.append(outline)


func _make_silhouette_texture(src: Texture2D, color: Color) -> Texture2D:
	var img := src.get_image()
	if img == null or img.is_empty():
		return null
	img = img.duplicate()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		for x in w:
			var px := img.get_pixel(x, y)
			if px.a > 0.5:
				img.set_pixel(x, y, color)
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	var tex := ImageTexture.create_from_image(img)
	return tex


func _set_outline_lit(lit: bool) -> void:
	_outline_lit = lit
	for outline in _outline_sprites:
		if is_instance_valid(outline):
			outline.visible = lit


func _is_lit_by_flashlight() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return false
	var flashlight := player.get_node_or_null("Flashlight")
	if flashlight == null:
		return false
	if flashlight.has_method("illuminates_for_pickup"):
		return bool(flashlight.illuminates_for_pickup(global_position))
	if flashlight.has_method("illuminates_point"):
		return bool(flashlight.illuminates_point(global_position))
	return false


func _on_body_entered(body: Node2D) -> void:
	if body == null or not body.is_in_group("player"):
		return
	if item_id.is_empty():
		return
	var app := get_node_or_null("/root/App")
	if app == null or not app.has_method("pickup_item"):
		return
	if not is_death_drop and app.has_method("is_item_gone_from_world") and app.is_item_gone_from_world(item_id):
		queue_free()
		return
	if is_death_drop and (app.has_carried_item(item_id) or app.has_delivered_item(item_id)):
		queue_free()
		return
	set_deferred("monitoring", false)
	app.pickup_item(item_id, item_texture, carry_scale)
	queue_free()
